#!/usr/bin/env bash



SetAutoUpdate() {
    if [ ! -z "${autoud_pid:-}" ] && pgrep -a '' | grep -Eq "^\s*$autoud_pid\s" > /dev/null; then
        tips="$Err PID(${GR}$autoud_pid${NC}) 正在发送中,请稍后..."
        return 1
    fi
    if [[ -z "${TelgramBotToken}" || -z "${ChatID_1}" ]]; then
        tips="$Err 参数丢失, 请设置后再执行 (先执行 ${GR}0${NC} 选项)."
        return 1
    fi
    if [ "$autorun" == "false" ]; then
        echo -e "输入定时更新时间, 格式如: 23:34 (即每天 ${GR}23${NC} 时 ${GR}34${NC} 分)"
        echo -en "请输入定时模式  (回车默认: ${GR}$AutoUpdateTime_de${NC} ): "
        read -er input_time
    else
        if [ -z "$AutoUpdateTime" ]; then
            input_time=""
        else
            input_time=$AutoUpdateTime
        fi
    fi
    if [ -z "$input_time" ]; then
        echo
        input_time="$AutoUpdateTime_de"
    fi
    if [ $(validate_time_format "$input_time") = "invalid" ]; then
        tips="$Err 输入格式不正确，请确保输入的时间格式为 'HH:MM'"
        return 1
    fi
    writeini "AutoUpdateTime" "$input_time"
    hour_ud=${input_time%%:*}
    minute_ud=${input_time#*:}

    minute_ud_next=$((minute_ud + 1))
    hour_ud_next=$hour_ud

    if [ $minute_ud_next -eq 60 ]; then
        minute_ud_next=0
        hour_ud_next=$((hour + 1))
        if [ $hour_ud_next -eq 24 ]; then
            hour_ud_next=0
        fi
    fi
    if [ ${#hour_ud} -eq 1 ]; then
    hour_ud="0${hour_ud}"
    fi
    if [ ${#minute_ud} -eq 1 ]; then
        minute_ud="0${minute_ud}"
    fi
    if [ ${#hour_ud_next} -eq 1 ]; then
    hour_ud_next="0${hour_ud_next}"
    fi
    if [ ${#minute_ud_next} -eq 1 ]; then
        minute_ud_next="0${minute_ud_next}"
    fi
    cront="$minute_ud $hour_ud * * *"
    cront_next="$minute_ud_next $hour_ud_next * * *"
    echo -e "$Tip 自动更新时间：$hour_ud 时 $minute_ud 分."
    cat <<EOF > "$FolderPath/tg_autoud.sh"
#!/bin/bash

# VPSKeeper 自动更新脚本
# 功能：下载最新安装脚本并执行完整更新

retry=0
max_retries=3
mirror_retries=2

# 创建临时目录
TEMP_DIR="/tmp/vpskeeper_autoupdate_\$(date +%Y%m%d_%H%M%S)"
mkdir -p "\$TEMP_DIR"

# 下载函数，接受下载链接作为参数
download_file() {
    wget -O "\$TEMP_DIR/vpskeeper.sh" "\$1"
}

echo "VPSKeeper 自动更新开始..."
echo "时间: \$(date)"

# 尝试从原始地址下载最新安装脚本
while [ \$retry -lt \$max_retries ]; do
    download_file "https://raw.githubusercontent.com/redstarxxx/vpskeeper/main/vpskeeper.sh"
    if [ -s "\$TEMP_DIR/vpskeeper.sh" ]; then
        echo "下载最新安装脚本成功"
        break
    else
        echo "下载失败，尝试重新下载..."
        ((retry++))
    fi
done

# 如果原始地址下载失败，则尝试从备用镜像地址下载
if [ ! -s "\$TEMP_DIR/vpskeeper.sh" ]; then
    echo "尝试从备用镜像地址下载..."
    retry=0
    while [ \$retry -lt \$mirror_retries ]; do
        download_file "https://mirror.ghproxy.com/https://raw.githubusercontent.com/redstarxxx/vpskeeper/main/vpskeeper.sh"
        if [ -s "\$TEMP_DIR/vpskeeper.sh" ]; then
            echo "备用镜像下载成功"
            break
        else
            echo "备用镜像下载失败，尝试重新下载..."
            ((retry++))
        fi
    done
fi

# 检查是否下载成功
if [ ! -s "\$TEMP_DIR/vpskeeper.sh" ]; then
    echo "下载失败，无法获取最新安装脚本"
    rm -rf "\$TEMP_DIR"
    exit 1
fi

# 设置执行权限
chmod +x "\$TEMP_DIR/vpskeeper.sh"

echo "开始执行完整更新..."

# 执行完整更新（静默模式，自动选择更新选项）
# 使用 expect 或者直接调用更新功能
cd "\$TEMP_DIR"

# 创建自动更新脚本
cat > "\$TEMP_DIR/auto_update.sh" << 'INNER_EOF'
#!/bin/bash
# 自动执行更新选项
echo "2" | ./vpskeeper.sh
INNER_EOF

chmod +x "\$TEMP_DIR/auto_update.sh"

# 执行自动更新
if bash "\$TEMP_DIR/auto_update.sh"; then
    echo "VPSKeeper 自动更新完成"
    echo "所有文件已更新到最新版本"
else
    echo "自动更新过程中出现错误"
fi

# 清理临时文件
rm -rf "\$TEMP_DIR"

echo "自动更新结束: \$(date)"
EOF
    chmod +x $FolderPath/tg_autoud.sh
    delcrontab "$FolderPath/tg_autoud.sh"
    addcrontab "$cront bash $FolderPath/tg_autoud.sh > $FolderPath/tg_autoud.log 2>&1 &"
    if [ "$autorun" == "false" ]; then
        echo -e "如果开启 ${REB}静音模式${NC} 更新时你将不会收到提醒通知, 是否要开启静音模式?"
        read -e -p "请输入你的选择 回车.(默认开启)   N.不开启: " choice
    else
        choice=""
    fi
    if [ "$choice" == "N" ] || [ "$choice" == "n" ]; then
        delcrontab "$FolderPath/vpskeeper.sh"
        addcrontab "$cront_next bash $FolderPath/vpskeeper.sh \"auto\" 2>&1 &"
        mute_mode="更新时通知"
    else
        delcrontab "$FolderPath/vpskeeper.sh"
        addcrontab "$cront_next bash $FolderPath/vpskeeper.sh \"auto\" \"mute\" 2>&1 &"
        mute_mode="静音模式"
    fi
    if [ "$mute" == "false" ]; then
        send_time=$(echo $(date +%s%N) | cut -c 16-)
        $FolderPath/send_tg.sh "$TelgramBotToken" "$ChatID_1" "自动更新脚本设置成功 ⚙️"$'\n'"主机名: $hostname_show"$'\n'"更新时间: 每天 $hour_ud 时 $minute_ud 分"$'\n'"通知模式: $mute_mode" "autoud" "$send_time" &
        (sleep 15 && $FolderPath/del_lm_tg.sh "$TelgramBotToken" "$ChatID_1" "autoud" "$send_time") &
        sleep 1
        # getpid "send_tg.sh"
        # autoud_pid="$tg_pid"
        autoud_pid=$(getpid "send_tg.sh")
    fi
    tips="$Tip 自动更新设置成功, 更新时间: 每天 $hour_ud 时 $minute_ud 分, 通知模式: ${GR}$mute_mode${NC}"
}
