#!/usr/bin/env bash


# 设置Dokcer通知
SetupDocker_TG() {
    if [ ! -z "${docker_pid:-}" ] && pgrep -a '' | grep -Eq "^\s*$docker_pid\s" > /dev/null; then
        tips="$Err PID(${GR}$docker_pid${NC}) 正在发送中,请稍后..."
        return 1
    fi
    if ! command -v docker &>/dev/null; then
        tips="$Err 未检测到 \"Docker\" 程序."
        return 1
    fi
    if [[ -z "${TelgramBotToken}" || -z "${ChatID_1}" ]]; then
        tips="$Err 参数丢失, 请设置后再执行 (先执行 ${GR}0${NC} 选项)."
        return 1
    fi
    cat <<EOF > $FolderPath/tg_docker.sh
#!/bin/bash

$(declare -f Checkpara)

FolderPath="$FolderPath"
if [ ! -d "\$FolderPath" ]; then
    mkdir -p "\$FolderPath"
fi
ConfigFile="$ConfigFile"
source \$ConfigFile &>/dev/null
Checkpara "hostname_show" "$hostname_show"

old_message=""
while true; do
    # new_message=\$(docker ps --format '{{.Names}}' | tr '\n' "\n" | sed 's/|$//')
    new_message=\$(docker ps --format '{{.Names}}' | awk '{print NR". " \$0}')
    if [ "\$new_message" != "\$old_message" ]; then
        current_date_send=\$(date +"%Y.%m.%d %T")
        old_message=\$new_message
        message="DOCKER 列表变更❗️"$'\n'
        message+="主机名: \$hostname_show"$'\n'
        message+="───────────────"$'\n'
        message+="\$new_message"$'\n'
        message+="服务器时间: \$current_date_send"
        # curl -s -X POST "https://api.telegram.org/bot\$TelgramBotToken/sendMessage" \
        #     -d chat_id="\$ChatID_1" -d text="\$message"
        \$FolderPath/send_tg.sh "\$TelgramBotToken" "\$ChatID_1" "\$message"
    fi
    sleep 10
done
EOF
    chmod +x $FolderPath/tg_docker.sh
    killpid "tg_docker.sh"
    nohup $FolderPath/tg_docker.sh > $FolderPath/tg_docker.log 2>&1 &
    delcrontab "$FolderPath/tg_docker.sh"
    addcrontab "@reboot nohup $FolderPath/tg_docker.sh > $FolderPath/tg_docker.log 2>&1 &"
    if [ "$mute" == "false" ]; then
        send_time=$(echo $(date +%s%N) | cut -c 16-)
        $FolderPath/send_tg.sh "$TelgramBotToken" "$ChatID_1" "设置成功: Docker 变更通知⚙️"$'\n'"主机名: $hostname_show"$'\n'"当 Docker 列表变更时将收到通知💡" "docker" "$send_time" &
        (sleep 15 && $FolderPath/del_lm_tg.sh "$TelgramBotToken" "$ChatID_1" "docker" "$send_time") &
        sleep 1
        # getpid "send_tg.sh"
        # docker_pid="$tg_pid"
        docker_pid=$(getpid "send_tg.sh")
    fi
    tips="$Tip Docker 通知已经设置成功, 当 Dokcer 挂载发生变化时发出通知."
}
