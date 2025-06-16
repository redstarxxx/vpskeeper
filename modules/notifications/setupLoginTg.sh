#!/usr/bin/env bash



# 设置登陆通知
SetupLogin_TG() {
    if [ ! -z "${login_pid:-}" ] && pgrep -a '' | grep -Eq "^\s*$login_pid\s" > /dev/null; then
        tips="$Err PID(${GR}$login_pid${NC}) 正在发送中,请稍后..."
        return 1
    fi
    if [[ -z "${TelgramBotToken}" || -z "${ChatID_1}" ]]; then
        tips="$Err 参数丢失, 请设置后再执行 (先执行 ${GR}0${NC} 选项)."
        return 1
    fi
    cat <<EOF > $FolderPath/tg_login.sh
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
message="\$hostname_show \$(id -nu) 用户登陆成功❗️"$'\n'
message+="服务器时间: \$current_date_send"

# curl -s -X POST "https://api.telegram.org/bot\$TelgramBotToken/sendMessage" \
#             -d chat_id="\$ChatID_1" -d text="\$message"
\$FolderPath/send_tg.sh "\$TelgramBotToken" "\$ChatID_1" "\$message"
EOF
    chmod +x $FolderPath/tg_login.sh
    if [ -f /etc/bash.bashrc ] && [ "$release" != "openwrt" ]; then
        if ! grep -q "bash $FolderPath/tg_login.sh > /dev/null 2>&1 &" /etc/bash.bashrc; then
            echo "bash $FolderPath/tg_login.sh > /dev/null 2>&1 &" >> /etc/bash.bashrc
        fi
        if [ "$mute" == "false" ]; then
            send_time=$(echo $(date +%s%N) | cut -c 16-)
            $FolderPath/send_tg.sh "$TelgramBotToken" "$ChatID_1" "设置成功: 登陆 通知⚙️"$'\n'"主机名: $hostname_show"$'\n'"当 登陆 时将收到通知💡" "login" "$send_time" &
            (sleep 15 && $FolderPath/del_lm_tg.sh "$TelgramBotToken" "$ChatID_1" "login" "$send_time") &
            sleep 1
            # getpid "send_tg.sh"
            # login_pid="$tg_pid"
            login_pid=$(getpid "send_tg.sh")
        fi
        tips="$Tip 登陆 通知已经设置成功, 当登陆时发出通知."
    elif [ -f /etc/profile ]; then
        if ! grep -q "bash $FolderPath/tg_login.sh > /dev/null 2>&1 &" /etc/profile; then
            echo "bash $FolderPath/tg_login.sh > /dev/null 2>&1 &" >> /etc/profile
        fi
        if [ "$mute" == "false" ]; then
            send_time=$(echo $(date +%s%N) | cut -c 16-)
            $FolderPath/send_tg.sh "$TelgramBotToken" "$ChatID_1" "设置成功: 登陆 通知⚙️"$'\n'"主机名: $hostname_show"$'\n'"当 登陆 时将收到通知💡 " "login" "$send_time" &
            (sleep 15 && $FolderPath/del_lm_tg.sh "$TelgramBotToken" "$ChatID_1" "login" "$send_time") &
            sleep 1
            # getpid "send_tg.sh"
            # login_pid="$tg_pid"
            login_pid=$(getpid "send_tg.sh")
        fi
        tips="$Tip 登陆 通知已经设置成功, 当登陆时发出通知."
    else
        tips="$Err 未检测到对应文件, 无法设置登陆通知."
    fi
}
