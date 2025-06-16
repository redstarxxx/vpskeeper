#!/usr/bin/env bash

#=======================================================
# VPSKeeper 工具函数库
# 功能: 工具函数 + 数据处理 + 通用进程管理
# 合并: tools.sh + dataTools.sh
#=======================================================

#=======================================================
# 通用进程管理函数 (兼容各种系统环境)
# 解决 pgrep/pkill 在某些系统中不存在的问题
#=======================================================

# 通用进程查找函数 - 兼容没有 pgrep 的系统
universal_pgrep() {
    local pattern="$1"
    local show_args="${2:-false}"  # 是否显示完整命令行参数

    if [ -z "$pattern" ]; then
        return 1
    fi

    # 优先使用 pgrep (如果可用)
    if command -v pgrep >/dev/null 2>&1; then
        if [ "$show_args" = "true" ]; then
            pgrep -af "$pattern" 2>/dev/null | grep -v grep
        else
            pgrep -f "$pattern" 2>/dev/null
        fi
    else
        # 回退到 ps + grep 方案
        # 检测 ps 命令的可用选项
        if ps x >/dev/null 2>&1; then
            # 支持 ps x (显示所有用户进程)
            if [ "$show_args" = "true" ]; then
                ps x | grep "$pattern" | grep -v grep
            else
                ps x | grep "$pattern" | grep -v grep | awk '{print $1}'
            fi
        elif ps aux >/dev/null 2>&1; then
            # 支持 ps aux
            if [ "$show_args" = "true" ]; then
                ps aux | grep "$pattern" | grep -v grep
            else
                ps aux | grep "$pattern" | grep -v grep | awk '{print $2}'
            fi
        else
            # 最基本的 ps 命令
            if [ "$show_args" = "true" ]; then
                ps | grep "$pattern" | grep -v grep
            else
                ps | grep "$pattern" | grep -v grep | awk '{print $1}'
            fi
        fi
    fi
}

# 通用进程终止函数 - 兼容没有 pkill 的系统
universal_pkill() {
    local pattern="$1"
    local signal="${2:-TERM}"  # 默认使用 TERM 信号
    local max_attempts="${3:-7}"  # 最大尝试次数

    if [ -z "$pattern" ]; then
        echo "错误: 进程模式不能为空"
        return 1
    fi

    local attempt=1
    while [ $attempt -le $max_attempts ]; do
        # 检查是否还有匹配的进程
        local pids=$(universal_pgrep "$pattern")
        if [ -z "$pids" ]; then
            # 没有找到进程，退出循环
            break
        fi

        # 优先使用 pkill (如果可用)
        if command -v pkill >/dev/null 2>&1; then
            pkill -"$signal" "$pattern" >/dev/null 2>&1
        else
            # 回退到 kill + pid 方案
            for pid in $pids; do
                if [ -n "$pid" ] && [ "$pid" -gt 0 ] 2>/dev/null; then
                    kill -"$signal" "$pid" >/dev/null 2>&1
                fi
            done
        fi

        # 等待一段时间让进程有机会退出
        sleep 0.5

        # 如果是第5次尝试，使用 KILL 信号强制终止
        if [ $attempt -eq 5 ] && [ "$signal" != "KILL" ]; then
            signal="KILL"
        fi

        attempt=$((attempt + 1))
    done

    # 最终检查是否还有残留进程
    local remaining_pids=$(universal_pgrep "$pattern")
    if [ -n "$remaining_pids" ]; then
        echo "警告: 仍有进程未能终止: $remaining_pids"
        return 1
    fi

    return 0
}

# 检查进程是否存在
universal_process_exists() {
    local pattern="$1"
    local pids=$(universal_pgrep "$pattern")
    [ -n "$pids" ]
}

# 获取进程数量
universal_process_count() {
    local pattern="$1"
    local pids=$(universal_pgrep "$pattern")
    if [ -n "$pids" ]; then
        echo "$pids" | wc -l
    else
        echo "0"
    fi
}

#=======================================================
# 时间和验证函数
#=======================================================

# 检查时间格式是否正确
validate_time_format() {
    local time=$1
    local regex='^([01]?[0-9]|2[0-3]):([0-5]?[0-9])$'
    if [[ $time =~ $regex ]]; then
        echo "valid"
    else
        echo "invalid"
    fi
}

# 发送Telegram消息的函数
send_telegram_message() {
    curl -s -X POST "${ProxyURL}https://api.telegram.org/bot$TelgramBotToken/sendMessage" \
        -d chat_id="$ChatID_1" -d text="$1" > /dev/null
}

# 检查文件是否存在并显示内容（调试用）
ShowContents() {
    if [ -f "$1" ]; then
        cat "$1"
        echo -e "$Inf 上述内容已经写入: $1"
        echo "-------------------------------------------"
    else
        echo -e "$Err 文件不存在: $1"
    fi
}

# 百分比转换进度条
create_progress_bar() {
    local percentage=$1
    local start_symbol=""
    local used_symbol="▇"
    local free_symbol="▁"
    local progress_bar=""
    local used_count
    local bar_width=10

    if [[ $percentage -ge 1 && $percentage -le 100 ]]; then
        used_count=$((percentage * bar_width / 100))
        for ((i=0; i<used_count; i++)); do
            progress_bar="${progress_bar}${used_symbol}"
        done
        for ((i=used_count; i<bar_width; i++)); do
            progress_bar="${progress_bar}${free_symbol}"
        done
        echo "${start_symbol}${progress_bar}"
    else
        echo "错误: 参数无效, 必须为 1-100 之间的值."
        return 1
    fi
}

# 比例和进度条计算
ratioandprogress() {
    lto=false
    gtoh=false
    if [ ! -z "$3" ]; then
        ratio=$3
    elif $(awk -v used="$1" -v total="$2" 'BEGIN { printf "%d", ( used >= 0 && total >= 0 ) }'); then
        ratio=$(awk -v used="$1" -v total="$2" 'BEGIN { printf "%.3f", ( used / total ) * 100 }')
    else
        echo "错误: $1 或 $2 小于 0 ."
        progress="Err 参数有误."
        return 1
    fi

    if $(awk -v v1="$ratio" 'BEGIN { exit !(v1 > 0 && v1 < 1) }'); then
        ratio=1
        lto=true
    elif $(awk -v v1="$ratio" 'BEGIN { exit !(v1 > 100) }'); then
        ratio=100
        gtoh=true
    fi

    ratio=$(awk -v v1="$ratio" 'BEGIN { printf "%.0f", v1 }')
    progress=$(create_progress_bar "$ratio")
    return_code=$?

    if [ $return_code -eq 1 ]; then
        progress="🚫"
        ratio=""
    else
        if [ "$lto" == "true" ]; then
            ratio="🔽"
        elif [ "$gtoh" == "true" ]; then
            ratio="🔼"
        else
            ratio="${ratio}%"
        fi
    fi
}

# 删除变量后面的B
Remove_B() {
    local var="$1"
    echo "${var%B}"
}

# 字节转换函数 (MB单位)
Bytes_M_TGK() {
    bitvalue="$1"
    if awk -v bitvalue="$bitvalue" 'BEGIN { exit !(bitvalue >= (1024 * 1024)) }'; then
        bitvalue=$(awk -v value="$bitvalue" 'BEGIN { printf "%.1fTB", value / (1024 * 1024) }')
    elif awk -v bitvalue="$bitvalue" 'BEGIN { exit !(bitvalue >= 1024) }'; then
        bitvalue=$(awk -v value="$bitvalue" 'BEGIN { printf "%.1fGB", value / 1024 }')
    elif awk -v bitvalue="$bitvalue" 'BEGIN { exit !(bitvalue < 1) }'; then
        bitvalue=$(awk -v value="$bitvalue" 'BEGIN { printf "%.1fKB", value * 1024 }')
    else
        bitvalue=$(awk -v value="$bitvalue" 'BEGIN { printf "%.1fMB", value }')
    fi
    echo "$bitvalue"
}

# 字节转换函数 (KB单位)
Bytes_K_TGM() {
    bitvalue="$1"
    if awk -v bitvalue="$bitvalue" 'BEGIN { exit !(bitvalue >= (1024 * 1024 * 1024)) }'; then
        bitvalue=$(awk -v value="$bitvalue" 'BEGIN { printf "%.1fTB", value / (1024 * 1024 * 1024) }')
    elif awk -v bitvalue="$bitvalue" 'BEGIN { exit !(bitvalue >= (1024 * 1024)) }'; then
        bitvalue=$(awk -v value="$bitvalue" 'BEGIN { printf "%.1fGB", value / (1024 * 1024) }')
    elif awk -v bitvalue="$bitvalue" 'BEGIN { exit !(bitvalue >= 1024) }'; then
        bitvalue=$(awk -v value="$bitvalue" 'BEGIN { printf "%.1fMB", value / 1024 }')
    else
        bitvalue=$(awk -v value="$bitvalue" 'BEGIN { printf "%.1fKB", value }')
    fi
    echo "$bitvalue"
}

# 字节转换函数 (二进制单位)
Bytes_K_TGMi() {
    bitvalue="$1"
    if awk -v bitvalue="$bitvalue" 'BEGIN { exit !(bitvalue >= (1024 * 1024 * 1024)) }'; then
        bitvalue=$(awk -v value="$bitvalue" 'BEGIN { printf "%.1fTiB", value / (1024 * 1024 * 1024) }')
    elif awk -v bitvalue="$bitvalue" 'BEGIN { exit !(bitvalue >= (1024 * 1024)) }'; then
        bitvalue=$(awk -v value="$bitvalue" 'BEGIN { printf "%.1fGiB", value / (1024 * 1024) }')
    elif awk -v bitvalue="$bitvalue" 'BEGIN { exit !(bitvalue >= 1024) }'; then
        bitvalue=$(awk -v value="$bitvalue" 'BEGIN { printf "%.1fMiB", value / 1024 }')
    else
        bitvalue=$(awk -v value="$bitvalue" 'BEGIN { printf "%.1fKiB", value }')
    fi
    echo "$bitvalue"
}

# 比特转换函数 (二进制单位)
Bit_K_TGMi() {
    bitvalue="$1"
    if awk -v bitvalue="$bitvalue" 'BEGIN { exit !(bitvalue >= (1024 * 1024 * 1024)) }'; then
        bitvalue=$(awk -v value="$bitvalue" 'BEGIN { printf "%.1fTibit", value / (1024 * 1024 * 1024) }')
    elif awk -v bitvalue="$bitvalue" 'BEGIN { exit !(bitvalue >= (1024 * 1024)) }'; then
        bitvalue=$(awk -v value="$bitvalue" 'BEGIN { printf "%.1fGibit", value / (1024 * 1024) }')
    elif awk -v bitvalue="$bitvalue" 'BEGIN { exit !(bitvalue >= 1024) }'; then
        bitvalue=$(awk -v value="$bitvalue" 'BEGIN { printf "%.1fMibit", value / 1024 }')
    else
        bitvalue=$(awk -v value="$bitvalue" 'BEGIN { printf "%.1fKibit", value }')
    fi
    echo "$bitvalue"
}

# 字节转换函数 (Byte单位)
Bytes_B_TGMK() {
    bitvalue="$1"
    if awk -v bitvalue="$bitvalue" 'BEGIN { exit !(bitvalue >= (1024 * 1024 * 1024 * 1024)) }'; then
        bitvalue=$(awk -v value="$bitvalue" 'BEGIN { printf "%.1fTB", value / (1024 * 1024 * 1024 * 1024) }')
    elif awk -v bitvalue="$bitvalue" 'BEGIN { exit !(bitvalue >= (1024 * 1024 * 1024)) }'; then
        bitvalue=$(awk -v value="$bitvalue" 'BEGIN { printf "%.1fGB", value / (1024 * 1024 * 1024) }')
    elif awk -v bitvalue="$bitvalue" 'BEGIN { exit !(bitvalue >= 1024 * 1024) }'; then
        bitvalue=$(awk -v value="$bitvalue" 'BEGIN { printf "%.1fMB", value / (1024 * 1024) }')
    elif awk -v bitvalue="$bitvalue" 'BEGIN { exit !(bitvalue >= 1024) }'; then
        bitvalue=$(awk -v value="$bitvalue" 'BEGIN { printf "%.1fKB", value / 1024 }')
    else
        bitvalue="${bitvalue}B"
    fi
    echo "$bitvalue"
}

# 流量单位转换为MB
TG_M_removeXB() {
    bitvalue="$1"
    if [[ $bitvalue == *MB ]]; then
        bitvalue=${bitvalue%MB}
        bitvalue=$(awk -v value=$bitvalue 'BEGIN { printf "%.1f", value }')
    elif [[ $bitvalue == *GB ]]; then
        bitvalue=${bitvalue%GB}
        bitvalue=$(awk -v value=$bitvalue 'BEGIN { printf "%.1f", value * 1024 }')
    elif [[ $bitvalue == *TB ]]; then
        bitvalue=${bitvalue%TB}
        bitvalue=$(awk -v value=$bitvalue 'BEGIN { printf "%.1f", value * 1024 * 1024 }')
    fi
    echo "$bitvalue"
}

# 数组去重处理
unique_array() {
    local array_in=("$@")
    local array_out=()
    array_out=($(printf "%s\n" "${array_in[@]}" | awk '!a[$0]++'))
    echo "${array_out[*]}"
}

# 数组去重处理 (别名，保持向后兼容)
redup_array() {
    local array_in=("$@")
    local array_out=()
    array_out=($(printf "%s\n" "${array_in[@]}" | awk '!a[$0]++'))
    echo "${array_out[@]}"
}

# 去除数组@及其后面
clear_array() {
    local array_in=("$@")
    local array_clear=""
    local array_out=()
    for ((i=0; i<${#array_in[@]}; i++)); do
        array_clear=${array_in[$i]%@*}
        array_clear=${array_clear%:*}
        array_out[$i]="$array_clear"
    done
    echo "${array_out[@]}"
}

# 将'.'转换成'_'
dtu_array() {
    local array_in=("$@")
    local -a array_out=()
    for item in "${array_in[@]}"; do
        local new_item="${item//./_}"
        array_out+=("$new_item")
    done
    echo "${array_out[@]}"
}

# 将字串与变量结合组成新的变量
caav() {
    local parameter="$1"
    local string="$2"
    local variable="$3"
    local value="$4"
    local new_variable="${string}_${variable}"
    declare "$new_variable"="$value"

    if [ "$parameter" == "-n" ]; then
        echo "$new_variable"
    fi
    if [ "$parameter" == "-v" ]; then
        echo "${!new_variable}"
    fi
}

# 检查进程状态 (使用通用进程查找函数)
Checkprocess() {
    local process_name="$1"
    local prefix_name="${process_name%%.*}"
    local fullname="$FolderPath/$process_name"
    local menu_tag=""

    if [ -f "$fullname" ] && crontab -l | grep -q "$fullname"; then
        if universal_process_exists "$fullname"; then
            menu_tag="$SETTAG"
        else
            menu_tag="$UNSETTAG"
        fi
    else
        menu_tag="$UNSETTAG"
    fi
    echo "$menu_tag"
}

# 检查参数
Checkpara() {
    local para=$1
    local default_value=$2
    local value
    eval value=\$$para

    if [ -z "$value" ]; then
        eval $para=\"$default_value\"
    fi
}

# 数组加入分隔符
sep_array() {
    local -n array_in=$1
    local separator=$2
    local array_out=""
    for ((i = 0; i < ${#array_in[@]}; i++)); do
        array_out+="${array_in[$i]}"
        if ((i < ${#array_in[@]} - 1)); then
            array_out+="$separator"
        fi
    done
    echo "$array_out"
}

# 获取进程PID (使用通用进程查找函数)
getpid() {
    local process_name="$1"
    if [ -z "$process_name" ]; then
        return 1
    fi

    # 使用通用进程查找函数
    local pids=$(universal_pgrep "$process_name")
    if [ -n "$pids" ]; then
        # 返回第一个PID
        echo "$pids" | head -1
    else
        echo ""
    fi
}

# 杀掉进程 (使用通用进程终止函数)
killpid() {
    local process_name="$1"
    if [ -z "$process_name" ]; then
        echo "错误: 进程名不能为空"
        return 1
    fi

    # 使用通用进程终止函数
    if universal_pkill "$process_name"; then
        # 成功终止所有进程
        return 0
    else
        # 仍有进程未能终止
        tips="$Err 中止失败, 请检查!"
        return 1
    fi
}

# 网速测试函数
T_NETSPEED() {
    echo -e "${GRB}实时网速监控${NC} (按 Ctrl+C 退出)"
    divline
    local prev_rx=0
    local prev_tx=0
    local interface=""

    # 获取主要网络接口
    interface=$(ip route | grep default | awk '{print $5}' | head -1)
    if [ -z "$interface" ]; then
        interface="eth0"
    fi

    while true; do
        local rx_bytes=$(cat /sys/class/net/$interface/statistics/rx_bytes 2>/dev/null || echo 0)
        local tx_bytes=$(cat /sys/class/net/$interface/statistics/tx_bytes 2>/dev/null || echo 0)

        if [ $prev_rx -ne 0 ] && [ $prev_tx -ne 0 ]; then
            local rx_speed=$((rx_bytes - prev_rx))
            local tx_speed=$((tx_bytes - prev_tx))

            local rx_speed_mb=$(awk "BEGIN {printf \"%.2f\", $rx_speed/1024/1024}")
            local tx_speed_mb=$(awk "BEGIN {printf \"%.2f\", $tx_speed/1024/1024}")

            printf "\r接口: %s | 下载: %s MB/s | 上传: %s MB/s" "$interface" "$rx_speed_mb" "$tx_speed_mb"
        fi

        prev_rx=$rx_bytes
        prev_tx=$tx_bytes
        sleep 1
    done
}

# 修改主机名
ModifyHostname() {
    echo -e "${GRB}修改主机名${NC}"
    echo -e "当前主机名: ${GR}$(hostname)${NC}"
    echo ""
    read -e -p "请输入新的主机名: " new_hostname

    if [ -n "$new_hostname" ]; then
        hostnamectl set-hostname "$new_hostname" 2>/dev/null || {
            echo "$new_hostname" > /etc/hostname
        }
        writeini "hostname_show" "$new_hostname"
        echo -e "${GR}主机名已修改为: $new_hostname${NC}"
        echo -e "${YE}重启后生效${NC}"
    else
        echo -e "${RE}主机名不能为空${NC}"
    fi
}

# 分割线
divline() {
    echo "----------------------------------------"
}

#=======================================================
# 文件夹操作函数 (来自 tools.sh)
#=======================================================

# 删除文件夹
DELFOLDER() {
    if [ ! -z "$delfolder_pid" ] && universal_process_exists "$delfolder_pid"; then
        tips="$Err PID(${GR}$delfolder_pid${NC}) 正在发送中,请稍后..."
        return 1
    fi
    echo -e "${GRB}删除前${NC}:"
    ls -la "$FolderPath"
    divline
    echo -e "$Tip 确认删除 ${GR}$FolderPath${NC} 文件夹及其所有内容?"
    read -e -p "输入 [${GR}YES${NC}] 确认删除, 其他任意键取消: " confirm
    if [ "$confirm" == "YES" ]; then
        send_time=$(echo $(date +%s%N) | cut -c 16-)
        current_date_send=$(date +"%Y.%m.%d %T")
        message="已删除脚本文件夹 🗑️"$'\n'
        message+="主机名: $hostname_show"$'\n'
        message+="服务器时间: $current_date_send"
        $FolderPath/send_tg.sh "$TelgramBotToken" "$ChatID_1" "$message" "delfolder" "$send_time" &
        (sleep 15 && $FolderPath/del_lm_tg.sh "$TelgramBotToken" "$ChatID_1" "delfolder" "$send_time") &
        sleep 1
        delfolder_pid=$(getpid "send_tg.sh")

        rm -rf "$FolderPath"
        echo -e "${GRB}删除后${NC}:"
        ls -la "$FolderPath" 2>/dev/null || echo "文件夹已删除"
        divline
        tips="$Tip 文件夹已删除."
    else
        tips="$Tip 已取消删除操作."
    fi
}

#=======================================================
# Crontab 管理函数 (来自 tools.sh)
#=======================================================

# 添加crontab任务
addcrontab() {
    local task="$1"
    if [ -n "$task" ]; then
        (crontab -l 2>/dev/null; echo "$task") | crontab -
    fi
}

# 删除crontab任务
delcrontab() {
    local task="$1"
    if [ -n "$task" ]; then
        crontab -l 2>/dev/null | grep -v "$task" | crontab -
    fi
}
