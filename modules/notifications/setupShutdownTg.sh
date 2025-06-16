#!/usr/bin/env bash


# 设置关机通知
SetupShutdown_TG() {
    if [ ! -z "${shutdown_pid:-}" ] && pgrep -a '' | grep -Eq "^\s*$shutdown_pid\s" > /dev/null; then
        tips="$Err PID(${GR}$shutdown_pid${NC}) 正在发送中,请稍后..."
        return 1
    fi
    if [[ -z "${TelgramBotToken}" || -z "${ChatID_1}" ]]; then
        tips="$Err 参数丢失, 请设置后再执行 (先执行 ${GR}0${NC} 选项)."
        return 1
    fi
    cat <<EOF > $FolderPath/tg_shutdown.sh
#!/bin/bash

$(declare -f Checkpara)

FolderPath="$FolderPath"
if [ ! -d "\$FolderPath" ]; then
    mkdir -p "\$FolderPath"
fi
ConfigFile="$ConfigFile"
source \$ConfigFile &>/dev/null
Checkpara "hostname_show" "$hostname_show"

current_date_send=\$(date +"%Y.%m.%d %T")
message="\$hostname_show \$(id -nu) 正在执行关机...❗️"$'\n'
message+="服务器时间: \$current_date_send"

# curl -s -X POST "https://api.telegram.org/bot\$TelgramBotToken/sendMessage" \
#             -d chat_id="\$ChatID_1" -d text="\$message"
\$FolderPath/send_tg.sh "\$TelgramBotToken" "\$ChatID_1" "\$message"
EOF
    chmod +x $FolderPath/tg_shutdown.sh
    if command -v systemd &>/dev/null; then
        cat <<EOF > /etc/systemd/system/tg_shutdown.service
[Unit]
Description=tg_shutdown
DefaultDependencies=no
Before=shutdown.target

[Service]
Type=oneshot
ExecStart=$FolderPath/tg_shutdown.sh
TimeoutStartSec=0

[Install]
WantedBy=shutdown.target
EOF
        systemctl enable tg_shutdown.service > /dev/null
    elif cat /proc/version 2>/dev/null | grep -q -E -i "openwrt"; then
        cat <<EOF > /etc/init.d/tg_shutdown.sh
#!/bin/sh /etc/rc.common

$(declare -f Checkpara)

STOP=15

FolderPath="$FolderPath"
if [ ! -d "\$FolderPath" ]; then
    mkdir -p "\$FolderPath"
fi
ConfigFile="$ConfigFile"
source \$ConfigFile &>/dev/null
Checkpara "hostname_show" "$hostname_show"

stop() {
    current_date_send=\$(date +"%Y.%m.%d %T")
    message="\$hostname_show \$(id -nu) 正在执行关机...❗️"$'\n'
    message+="服务器时间: \$current_date_send"

    # curl -s -X POST "https://api.telegram.org/bot\$TelgramBotToken/sendMessage" \
    #     -d chat_id="\$ChatID_1" -d text="\$message"
    \$FolderPath/send_tg.sh "\$TelgramBotToken" "\$ChatID_1" "\$message"
}
EOF
        chmod +x /etc/init.d/tg_shutdown.sh
        /etc/init.d/tg_shutdown.sh enable
    else
        tips="$Err 系统未检测到 \"systemd\" 程序, 无法设置关机通知."
        return 1
    fi
    if [ "$mute" == "false" ]; then
        send_time=$(echo $(date +%s%N) | cut -c 16-)
        $FolderPath/send_tg.sh "$TelgramBotToken" "$ChatID_1" "设置成功: 关机 通知⚙️"$'\n'"主机名: $hostname_show"$'\n'"当 关机 时将收到通知💡" "shutdown" "$send_time" &
        (sleep 15 && $FolderPath/del_lm_tg.sh "$TelgramBotToken" "$ChatID_1" "shutdown" "$send_time") &
        sleep 1
        # getpid "send_tg.sh"
        # shutdown_pid="$tg_pid"
        shutdown_pid=$(getpid "send_tg.sh")
    fi
    tips="$Tip 关机 通知已经设置成功, 当开机时发出通知."
}
