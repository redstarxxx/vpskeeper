#!/usr/bin/env bash


# 设置磁盘报警
SetupDISK_TG() {
    if [ ! -z "${disk_pid:-}" ] && pgrep -a '' | grep -Eq "^\s*$disk_pid\s" > /dev/null; then
        tips="$Err PID(${GR}$disk_pid${NC}) 正在发送中,请稍后..."
        return 1
    fi
    if [[ -z "${TelgramBotToken}" || -z "${ChatID_1}" ]]; then
        tips="$Err 参数丢失, 请设置后再执行 (先执行 ${GR}0${NC} 选项)."
        return 1
    fi
    if [ "$autorun" == "false" ]; then
        read -e -p "请输入 磁盘报警阈值 % (回车跳过修改): " threshold
    else
        if [ ! -z "$DISKThreshold" ]; then
            threshold=$DISKThreshold
        else
            threshold=$DISKThreshold_de
        fi
    fi
    if [ -z "$threshold" ]; then
        tips="$Tip 输入为空, 跳过操作."
        return 1
    fi
    threshold="${threshold//%/}"
    if [[ ! $threshold =~ ^([1-9][0-9]?|100)$ ]]; then
        echo -e "$Err ${REB}输入无效${NC}, 报警阈值 必须是数字 (1-100) 的整数, 跳过操作."
        return 1
    fi
    writeini "DISKThreshold" "$threshold"
    DISKThreshold=$threshold
    if [ "$CPUTools" == "sar" ] || [ "$CPUTools" == "top_sar" ]; then
        if ! command -v sar &>/dev/null; then
            echo "正在安装缺失的依赖 sar, 一个检测 CPU 的专业工具."
            if [ -x "$(command -v apt)" ]; then
                apt -y install sysstat
            elif [ -x "$(command -v yum)" ]; then
                yum -y install sysstat
            else
                echo -e "$Err 未知的包管理器, 无法安装依赖. 请手动安装所需依赖后再运行脚本."
            fi
        fi
    fi
    cat <<EOF > "$FolderPath/tg_disk.sh"
#!/bin/bash

CPUTools="$CPUTools"
DISKThreshold="$DISKThreshold"

$(declare -f CheckCPU_$CPUTools)
$(declare -f GetInfo_now)
$(declare -f create_progress_bar)
$(declare -f ratioandprogress)
$(declare -f Checkpara)

FolderPath="$FolderPath"
if [ ! -d "\$FolderPath" ]; then
    mkdir -p "\$FolderPath"
fi
ConfigFile="$ConfigFile"
source \$ConfigFile &>/dev/null
Checkpara "hostname_show" "$hostname_show"

progress=""
ratio=""
count=0
SleepTime=900
while true; do
    GetInfo_now

    DISKThreshold_com=\$(awk 'BEGIN {printf "%.0f\n", '\$DISKThreshold' * 100}')
    disk_use_ratio_com=\$(awk 'BEGIN {printf "%.0f\n", '\$disk_use_ratio' * 100}')
    echo "Threshold: \$DISKThreshold_com   usage: \$disk_use_ratio_com  # 这里数值是乘100的结果"
    if (( disk_use_ratio_com >= \$DISKThreshold_com )); then
        (( count++ ))
    else
        count=0
    fi
    echo "count: \$count   # 当 count 为 3 时将触发警报."
    if (( count >= 3 )); then

        # 获取并计算其它参数
        CheckCPU_\$CPUTools

        echo "前: cpu: \$cpu_usage_ratio mem: \$mem_use_ratio swap: \$swap_use_ratio disk: \$disk_use_ratio"
        ratioandprogress "0" "0" "\$cpu_usage_ratio"
        cpu_usage_progress=\$progress
        cpu_usage_ratio=\$ratio

        ratioandprogress "0" "0" "\$mem_use_ratio"
        mem_use_progress=\$progress
        mem_use_ratio=\$ratio

        ratioandprogress "0" "0" "\$swap_use_ratio"
        swap_use_progress=\$progress
        swap_use_ratio=\$ratio

        ratioandprogress "0" "0" "\$disk_use_ratio"
        disk_use_progress=\$progress
        disk_use_ratio=\$ratio
        echo "后: cpu: \$cpu_usage_ratio mem: \$mem_use_ratio swap: \$swap_use_ratio disk: \$disk_use_ratio"

        current_date_send=\$(date +"%Y.%m.%d %T")
        message="磁盘 使用率超过阈值 > \$DISKThreshold%❗️"$'\n'
        message+="主机名: \$hostname_show"$'\n'
        message+="CPU: \$cpu_usage_progress \$cpu_usage_ratio"$'\n'
        message+="内存: \$mem_use_progress \$mem_use_ratio"$'\n'
        message+="交换: \$swap_use_progress \$swap_use_ratio"$'\n'
        message+="磁盘: \$disk_use_progress \$disk_use_ratio"$'\n'
        message+="使用率排行:"$'\n'
        message+="🟠  \$cpu_h1"$'\n'
        message+="🟠  \$cpu_h2"$'\n'
        message+="检测工具: \$CPUTools 休眠: \$((SleepTime / 60))分钟"$'\n'
        message+="服务器时间: \$current_date_send"
        # curl -s -X POST "https://api.telegram.org/bot\$TelgramBotToken/sendMessage" \
        #     -d chat_id="\$ChatID_1" -d text="\$message" > /dev/null
        \$FolderPath/send_tg.sh "\$TelgramBotToken" "\$ChatID_1" "\$message"
        echo "报警信息已发出..."
        count=0  # 发送警告后重置计数器
        sleep \$SleepTime   # 发送后等待SleepTime分钟后再检测
    fi
    sleep 3
done
EOF
    chmod +x $FolderPath/tg_disk.sh
    killpid "tg_disk.sh"
    nohup $FolderPath/tg_disk.sh > $FolderPath/tg_disk.log 2>&1 &
    delcrontab "$FolderPath/tg_disk.sh"
    addcrontab "@reboot nohup $FolderPath/tg_disk.sh > $FolderPath/tg_disk.log 2>&1 &"
    if [ "$mute" == "false" ]; then
        send_time=$(echo $(date +%s%N) | cut -c 16-)
        $FolderPath/send_tg.sh "$TelgramBotToken" "$ChatID_1" "设置成功: 磁盘 报警通知⚙️"'
'"主机名: $hostname_show"'
'"磁盘: ${disk_total}B     已使用: ${disk_used}B"'
'"当磁盘使用达 $DISKThreshold % 时将收到通知💡" "disk" "$send_time" &
        (sleep 15 && $FolderPath/del_lm_tg.sh "$TelgramBotToken" "$ChatID_1" "disk" "$send_time") &
        sleep 1
        # getpid "send_tg.sh"
        # disk_pid="$tg_pid"
        disk_pid=$(getpid "send_tg.sh")
    fi
    tips="$Tip 磁盘 通知已经设置成功, 当 磁盘 使用率达 ${GR}$DISKThreshold${NC} % 时发出通知."
}
