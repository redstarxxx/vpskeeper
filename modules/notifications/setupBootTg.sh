#!/usr/bin/env bash



# 设置开机通知
SetupBoot_TG() {
    if [ ! -z "${boot_pid:-}" ] && pgrep -a '' | grep -Eq "^\s*$boot_pid\s" > /dev/null; then
        tips="$Err PID(${GR}$boot_pid${NC}) 正在发送中,请稍后..."
        return 1
    fi
    if [[ -z "${TelgramBotToken}" || -z "${ChatID_1}" ]]; then
        tips="$Err 参数丢失, 请设置后再执行 (先执行 ${GR}0${NC} 选项)."
        return 1
    fi
    cat <<EOF > $FolderPath/tg_boot.sh
#!/bin/bash

$(declare -f Checkpara)

FolderPath="$FolderPath"
if [ ! -d "\$FolderPath" ]; then
    mkdir -p "\$FolderPath"
fi
ConfigFile="$ConfigFile"
source \$ConfigFile &>/dev/null
# if [ -z \$hostname_show ]; then
#     hostname_show=$hostname_show
# fi
Checkpara "hostname_show" "$hostname_show"

current_date_send=\$(date +"%Y.%m.%d %T")
message="\$hostname_show 已启动❗️"$'\n'
message+="服务器时间: \$current_date_send"

# curl -s -X POST "https://api.telegram.org/bot\$TelgramBotToken/sendMessage" \
#     -d chat_id="\$ChatID_1" -d text="\$message"
\$FolderPath/send_tg.sh "\$TelgramBotToken" "\$ChatID_1" "\$message"
EOF
    chmod +x $FolderPath/tg_boot.sh

    # 检测系统类型并选择合适的启动方式
    if command -v systemctl >/dev/null 2>&1 && [ -d /etc/systemd/system ]; then
        # 使用 systemd
        cat <<EOF > /etc/systemd/system/tg_boot.service
[Unit]
Description=Run tg_boot.sh script at boot time
After=network.target

[Service]
Type=oneshot
ExecStart=$FolderPath/tg_boot.sh
RemainAfterExit=true

[Install]
WantedBy=multi-user.target
EOF
        systemctl enable tg_boot.service > /dev/null 2>&1
        systemctl daemon-reload > /dev/null 2>&1
    elif cat /proc/version 2>/dev/null | grep -q -E -i "openwrt"; then
        cat <<EOF > /etc/init.d/tg_boot.sh
#!/bin/sh /etc/rc.common

$(declare -f Checkpara)

START=99
STOP=15

FolderPath="$FolderPath"
if [ ! -d "\$FolderPath" ]; then
    mkdir -p "\$FolderPath"
fi
ConfigFile="$ConfigFile"
source \$ConfigFile &>/dev/null
Checkpara "hostname_show" "$hostname_show"

start() {
    current_date_send=\$(date +"%Y.%m.%d %T")
    message="\$hostname_show 已启动❗️"$'\n'
    message+="服务器时间: \$current_date_send"

    # curl -s -X POST "https://api.telegram.org/bot\$TelgramBotToken/sendMessage" \
    #     -d chat_id="\$ChatID_1" -d text="\$message"
    \$FolderPath/send_tg.sh "\$TelgramBotToken" "\$ChatID_1" "\$message"
}
EOF
        chmod +x /etc/init.d/tg_boot.sh
        /etc/init.d/tg_boot.sh enable
    else
        # 回退到 crontab @reboot 方式
        echo "警告: 未检测到 systemd 或 OpenWRT，使用 crontab @reboot 方式"
        delcrontab "$FolderPath/tg_boot.sh"
        addcrontab "@reboot sleep 30 && $FolderPath/tg_boot.sh"
    fi
    if [ "$mute" == "false" ]; then
        send_time=$(echo $(date +%s%N) | cut -c 16-)
        $FolderPath/send_tg.sh "$TelgramBotToken" "$ChatID_1" "设置成功: 开机 通知⚙️"$'\n'"主机名: $hostname_show"$'\n'"当 开机 时将收到通知💡" "boot" "$send_time" &
        (sleep 15 && $FolderPath/del_lm_tg.sh "$TelgramBotToken" "$ChatID_1" "boot" "$send_time") &
        sleep 1
        # getpid "send_tg.sh"
        # boot_pid="$tg_pid"
        boot_pid=$(getpid "send_tg.sh")
    fi
    tips="$Tip 开机 通知已经设置成功, 当开机时发出通知."

}
