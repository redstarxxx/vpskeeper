#!/usr/bin/env bash


# 清空所有*.log文件
DELLOGFILE() {
    # rm -f ${FolderPath}/*.log
    LogFiles=( $(find ${FolderPath} -name "*.log") )
    # printf '%s\n' "${LogFiles[@]}"
    # rm -f "${LogFiles[@]}"
    logn=1
    divline
    echo -e "${REB}删除记录:${NC}"
    for file in "${LogFiles[@]}"; do
        # echo -e " ${REB}$logn${NC} \t$file"
        if ((logn % 2 == 0)); then
            echo -e " ${REB}$logn \t$file${NC}"
        else
            echo -e " ${RE}$logn \t$file${NC}"
        fi
        ((logn++))
    done
    echo -e " ${REB}A${NC} \t${REB}清空所有 *log 文件!${NC}"
    divline
    read -e -p "请输入要 [清空] 的文件序号 : " lognum
    if [ "$lognum" == "A" ] || [ "$lognum" == "a" ]; then
        for file in "${LogFiles[@]}"; do > "$file"; done
        tips="$Tip 已经清空所有 *log 文件!"
    else
        if [[ -z "${LogFiles[$((lognum-1))]}" ]] || [ -z "$lognum" ]; then
            tips="$Tip 输入有误 或 未找到对应的文件!"
        else
            > "${LogFiles[$((lognum-1))]}"
            tips="$Tip 已经清空文件: ${LogFiles[$((lognum-1))]}"
        fi
    fi
}

# 查看*.log文件
VIEWLOG() {
    LogFiles=( $(find ${FolderPath} -name "*.log") )
    logn=1
    divline
    echo -e "${GRB}查看log:${NC}"
    for file in "${LogFiles[@]}"; do
        # echo -e " ${GR}$logn${NC} \t$file"
        if ((logn % 2 == 0)); then
            echo -e " ${GR}$logn \t$file${NC}"
        else
            echo -e " $logn \t$file"
        fi
        ((logn++))
    done
    divline
    read -e -p "请输入要 [查看] 的文件序号 : " lognum
    if [[ "$lognum" =~ ^[0-9]+$ ]]; then
        if [[ -z "${LogFiles[$((lognum-1))]}" ]] || [ "$lognum" -eq 0 ]; then
            tips="$Tip 输入有误 或 未找到对应的文件!"
        else
            divline
            echo -e "${GR}${LogFiles[$((lognum-1))]} 内容如下:${NC}"
            cat ${LogFiles[$((lognum-1))]}
            divline
            Pause
        fi
    else
        tips="$Tip 必须输入对应的数字序号!"
    fi
}

# 查看*.service文件
VIEWSERVICE() {
    if ! command -v systemd &>/dev/null; then
        tips="$Err 系统未检测到 \"systemd\" 程序, 无法设置关机通知."
        return 1
    fi
    ServiceFiles=( $(find /etc/systemd/system -name "tg_*") )
    servicen=1
    divline
    echo -e "${GRB}查看service:${NC}"
    for file in "${ServiceFiles[@]}"; do
        # echo -e " ${GR}$servicen${NC} \t$file"
        if ((servicen % 2 == 0)); then
            echo -e " ${GR}$servicen \t$file${NC}"
        else
            echo -e " $servicen \t$file"
        fi
        ((servicen++))
    done
    divline
    read -e -p "请输入要 [查看] 的文件序号 : " servicenum
    if [[ "$servicenum" =~ ^[0-9]+$ ]]; then
        if [[ -z "${ServiceFiles[$((servicenum-1))]}" ]] || [ "$servicenum" -eq 0 ]; then
            tips="$Tip 输入有误 或 未找到对应的文件!"
        else
            divline
            echo -e "${GR}${ServiceFiles[$((servicenum-1))]} 内容如下:${NC}"
            cat ${ServiceFiles[$((servicenum-1))]}
            divline
            Pause
        fi
    else
        tips="$Tip 必须输入对应的数字序号!"
    fi
}

# 跟踪查看*.log文件
T_VIEWLOG() {
    LogFiles=( $(find ${FolderPath} -name "*.log") )
    logn=1
    divline
    echo -e "${GRB}跟踪log:${NC}"
    for file in "${LogFiles[@]}"; do
        # echo -e " ${GR}$logn${NC} \t$file"
        if ((logn % 2 == 0)); then
            echo -e " $logn \t$file"
        else
            echo -e " ${GR}$logn \t$file${NC}"
        fi
        ((logn++))
    done
    divline
    echo -e "${RE}注意${NC}:  ${REB}按任意键中止${NC}"
    read -e -p "请输入要 [查看] 的文件序号 : " lognum
    if [[ "$lognum" =~ ^[0-9]+$ ]]; then
        if [[ -z "${LogFiles[$((lognum-1))]}" ]] || [ "$lognum" -eq 0 ]; then
            tips="$Tip 输入有误 或 未找到对应的文件!"
        else
            stty intr ^- # 禁用 CTRL+C
            divline
            echo -e "${GR}${LogFiles[$((lognum-1))]} 内容如下:${NC}"
            tail -f ${LogFiles[$((lognum-1))]} &
            tail_pid=$!
            read -n 1 -s -r -p ""
            stty intr ^C # 恢复 CTRL+C
            # stty sane # 重置终端设置为默认值
            kill -2 $tail_pid 2>/dev/null
            killpid "tail"
            # pkill -f tail
            # kill $(ps | grep '[t]ail' | awk '{print $1}') 2>/dev/null
            # pgrep -f tail | xargs kill -9 2>/dev/null
            if universal_process_exists "tail"; then
                echo -e "中止失败!! 请执行以下指令中止!"
                if command -v pkill >/dev/null 2>&1; then
                    echo -e "中止指令1: ${REB}pkill -f tail${NC}"
                fi
                echo -e "中止指令2: ${REB}kill $(ps | grep '[t]ail' | awk '{print $1}') 2>/dev/null${NC}"
            fi
            divline
            Pause
        fi
    else
        tips="$Tip 必须输入对应的数字序号!"
    fi
}

# 实时网速
T_NETSPEED() {
    # interfaces_re_0=$(ip -br link | awk '$2 == "UP" {print $1}' | grep -v "lo")
    # output=$(ip -br link)
    IFS=$'\n'
    count=1
    choice_array=()
    interfaces_re=()
    show_interfaces_re=()
    # for line in $output; do
    for line in ${interfaces_all[@]}; do
        columns_1="$line"
        # columns_1=$(echo "$line" | awk '{print $1}')
        # columns_1=${columns_1[$i]%@*}
        # columns_1=${columns_1%:*}
        columns_1_array+=("$columns_1")
        columns_2="$line"
        # columns_2=$(printf "%s\t\tUP" "$line")
        # columns_2=$(echo "$line" | awk '{print $1"\t"UP}')
        # columns_2=${columns_2[$i]%@*}
        # columns_2=${columns_2%:*}
        # columns_2=$(echo "$line" | awk '{print $1"\t"$2}')
        # if [[ $interfaces_re_0 =~ $columns_1 ]]; then
        if [[ $interfaces_up =~ $columns_1 ]]; then
            printf "${GR}%d. %s${NC}\n" "$count" "$columns_2"
        else
            printf "${GR}%d. ${NC}%s\n" "$count" "$columns_1"
        fi
        ((count++))
    done
    echo -e "请输入对应的编号进行统计测速"
    echo -en "例如: ${GR}1${NC} 或 ${GR}2${NC} 或 ${GR}1,2 (合计)${NC} 或 ${GR}回车 (自动检测活跃接口) ${NC}: "
    read -er choice
    # if [[ $choice == *0* ]]; then
    #     tips="$Err 接口编号中没有 0 选项"
    #     return 1
    # fi
    if [ ! -z "$choice" ]; then
        # choice="${choice//[, ]/}"
        # for (( i=0; i<${#choice}; i++ )); do
        # char="${choice:$i:1}"
        # if [[ "$char" =~ [0-9] ]]; then
        #     choice_array+=("$char")
        # fi
        # done
        # # echo "解析后的接口编号数组: ${choice_array[@]}"
        # for item in "${choice_array[@]}"; do
        #     index=$((item - 1))
        #     if [ -z "${columns_1_array[index]}" ]; then
        #         tips="$Err 错误: 输入的编号 $item 无效或超出范围."
        #         return 1
        #     else
        #         interfaces_re+=("${columns_1_array[index]}")
        #     fi
        # done

        if [ "$choice" == "0" ]; then
            tips="$Err 输入错误, 没有0选择."
            return 1
        fi

        if ! [[ "$choice" =~ ^[0-9,]+$ ]]; then
            tips="$Err 输入的选项无效, 请输入有效的数字选项或使用逗号分隔多个数字选项."
            return 1
        fi

        choice="${choice//[, ]/,}"  # 将所有逗号后的空格替换成单逗号
        IFS=',' read -ra choice_array <<< "$choice"  # 使用逗号作为分隔符将输入拆分成数组

        for item in "${choice_array[@]}"; do
            if [ "$item" -eq 0 ] || [ "$item" -gt "${#interfaces_all[@]}" ]; then
                tips="$Err 输入错误, 输入的选项 $item 无效或超出范围。"
                return 1
            fi
            index=$((item - 1))
            interfaces_re+=("${columns_1_array[index]}")
        done

        # for ((i = 0; i < ${#interfaces_re[@]}; i++)); do
        #     show_interfaces_re+="${interfaces_re[$i]}"
        #     if ((i < ${#interfaces_re[@]} - 1)); then
        #         show_interfaces_re+=","
        #     fi
        # done
        show_interfaces_re=$(sep_array interfaces_re ",")
        # echo "确认选择接口: interfaces_re: ${interfaces_re[@]}  show_interfaces_re: $show_interfaces_re"
        # Pause
    else
        echo
        # interfaces_all=$(ip -br link | awk '{print $1}' | tr '\n' ' ')
        active_interfaces=()
        echo "检查网络接口流量情况..."
        for interface in ${interfaces_all[@]}
        do
        clean_interface=${interface%%@*}
        stats=$(ip -s link show $clean_interface)
        rx_packets=$(echo "$stats" | awk '/RX:/{getline; print $2}')
        tx_packets=$(echo "$stats" | awk '/TX:/{getline; print $2}')
        if [ "$rx_packets" -gt 0 ] || [ "$tx_packets" -gt 0 ]; then
            echo "接口: $clean_interface 活跃, 接收: $rx_packets 包, 发送: $tx_packets 包."
            active_interfaces+=($clean_interface)
        else
            echo "接口: $clean_interface 不活跃."
        fi
        done
        interfaces_re=("${active_interfaces[@]}")
        # for ((i = 0; i < ${#interfaces_re[@]}; i++)); do
        #     show_interfaces_re+="${interfaces_re[$i]}"
        #     if ((i < ${#interfaces_re[@]} - 1)); then
        #         show_interfaces_re+=","
        #     fi
        # done
        show_interfaces_re=$(sep_array interfaces_re ",")
        # echo "确认选择接口: interfaces_re: $interfaces_re  show_interfaces_re: $show_interfaces_re"
        # Pause
        echo -e "$Tip 检测到活动的接口: $show_interfaces_re"
    fi
    echo -en "请输入统计间隔时间 (回车默认 ${GR}2${NC} 秒) : "
    read -er inputtt
    if [ -z "$inputtt" ]; then
        echo
        nstt=2
    else
        if [[ $inputtt =~ ^[0-9]+(\.[0-9])?$ ]]; then
            nstt=$inputtt
        else
            tips="输入有误."
            return
        fi
    fi
    if [ "$ss_s" == "st" ]; then
        echo -en "显示 TCP/UDP 连接数 (${RE}连接数过多时不建议开启${NC}) (y/${GR}N${NC}) : "
        read -er input_tu
        if [ ! "$input_tu" == "y" ] && [ ! "$input_tu" == "Y" ]; then
            echo
            tu_show="false"
        else
            tu_show="true"
        fi
    fi
    # if [ ! -f $FolderPath/tg_interface_re.sh ]; then
        cat <<EOF > $FolderPath/tg_interface_re.sh
#!/bin/bash

GR="\033[32m" && RE="\033[31m" && GRB="\033[42;37m" && REB="\033[41;37m" && NC="\033[0m"
Inf="\${GR}[信息]\${NC}:"
Err="\${RE}[错误]\${NC}:"
Tip="\${GR}[提示]\${NC}:"

$(declare -f CLS)
$(declare -f Remove_B)
$(declare -f Bytes_K_TGM)

FolderPath="$FolderPath"
if [ ! -d "\$FolderPath" ]; then
    mkdir -p "\$FolderPath"
fi

ss_tag=""
if [ "$ss_s" == "st" ]; then
    ss_tag="st"
    $(declare -f Bytes_K_TGMi)
    $(declare -f Bit_K_TGMi)
fi

# 统计接口网速（只统所有接口）
# interfaces=(\$(ip -br link | awk '{print \$1}' | tr '\n' ' '))

# 统计接口网速（只统计 UP 接口）
# interfaces_up=\$(ip -br link | awk '\$2 == "UP" {print \$1}' | grep -v "lo")
# interfaces=(\$(ip -br link | awk '{print \$1}' | tr '\n' ' '))

# 去重并且保持原有顺序，分割字符串为数组
IFS=',' read -ra interfaces_r <<< "$(echo "$show_interfaces_re" | awk -v RS=, '!a[$1]++ {if (NR>1) printf ",%s", $0; else printf "%s", $0}')"

for ((i=0; i<\${#interfaces_r[@]}; i++)); do
    interface=\${interfaces_r[\$i]%@*}
    interface=\${interface%:*}
    interfaces_r[\$i]=\$interface
done
for ((i = 0; i < \${#interfaces_r[@]}; i++)); do
    show_interfaces+="\${interfaces_r[\$i]}"
    if ((i < \${#interfaces_r[@]} - 1)); then
        show_interfaces+=","
    fi
done

TT=$nstt
tu_show=$tu_show
duration=0
CLEAR_TAG=1
CLEAR_TAG_OLD=\$CLEAR_TAG

avg_count=0
max_rx_speed_kb=0
# min_rx_speed_kb=9999999999999
min_rx_speed_kb=2147483647
total_rx_speed_kb=0
avg_rx_speed_kb=0
max_tx_speed_kb=0
# min_tx_speed_kb=9999999999999
min_tx_speed_kb=2147483647
total_tx_speed_kb=0
avg_tx_speed_kb=0

# 定义数组
declare -A sp_prev_rx_bytes
declare -A sp_prev_tx_bytes
declare -A sp_current_rx_bytes
declare -A sp_current_tx_bytes

CLS
echo " 实时网速计算中..."
echo " =================================================="
while true; do

    # 获取tt秒前数据
    sp_ov_prev_rx_bytes=0
    sp_ov_prev_tx_bytes=0
    for interface in "\${interfaces_r[@]}"; do
        interface_nodot=\${interface//./_}
        sp_prev_rx_bytes[\$interface_nodot]=\$(ip -s link show \$interface | awk '/RX:/ { getline; print \$1 }')
        sp_prev_tx_bytes[\$interface_nodot]=\$(ip -s link show \$interface | awk '/TX:/ { getline; print \$1 }')
        sp_ov_prev_rx_bytes=\$((sp_ov_prev_rx_bytes + sp_prev_rx_bytes[\$interface_nodot]))
        sp_ov_prev_tx_bytes=\$((sp_ov_prev_tx_bytes + sp_prev_tx_bytes[\$interface_nodot]))
    done

    # 等待TT秒
    end_time=\$(date +%s%N)
    if [ ! -z "\$start_time" ]; then
        time_diff=\$((end_time - start_time))
        time_diff_ms=\$((time_diff / 1000000))

        # 输出执行FOR所花费时间
        # echo "上一个 FOR循环 所执行时间 \$time_diff_ms 毫秒."

        # duration=\$(awk "BEGIN {print \$time_diff_ms/1000}")
        duration=\$(awk 'BEGIN { printf "%.3f", '"\$time_diff_ms"' / 1000 }')
        sleep_time=\$(awk -v v1="\$TT" -v v2="\$duration" 'BEGIN { printf "%.3f", v1 - v2 }')
    else
        sleep_time=\$TT
    fi
    sleep_time=\$(awk "BEGIN {print (\$sleep_time < 0 ? 0 : \$sleep_time)}")
    echo " =================================================="
    # se_state=\$(awk 'BEGIN {if ('"\$sleep_time"' <= 0) print "\${REB}不正常\${NC}"; else print "\${GRB}正常\${NC}"}')
    sleep_time_show=\$(awk -v v1="\$sleep_time" 'BEGIN { printf "%.3f", v1 }')
    se_state=\$(awk -v reb="\${REB}" -v grb="\${GRB}" -v nc="\${NC}" 'BEGIN {if ('"\$TT"' < '"\$duration"') print reb "不正常" nc; else print grb "正常" nc}')
    echo -e " 间隔: \$sleep_time_show 秒    时差: \$duration 秒     状态: \$se_state"
    # echo -e "统计接口: \$show_interfaces"
    echo
    date +"%Y.%m.%d %T"
    echo -e "\${RE}按任意键退出\${NC}"
    sleep \$sleep_time
    start_time=\$(date +%s%N)

    # 获取TT秒后数据
    sp_ov_current_rx_bytes=0
    sp_ov_current_tx_bytes=0
    for interface in "\${interfaces_r[@]}"; do
        interface_nodot=\${interface//./_}
        sp_current_rx_bytes[\$interface_nodot]=\$(ip -s link show \$interface | awk '/RX:/ { getline; print \$1 }')
        sp_current_tx_bytes[\$interface_nodot]=\$(ip -s link show \$interface | awk '/TX:/ { getline; print \$1 }')
        sp_ov_current_rx_bytes=\$((sp_ov_current_rx_bytes + sp_current_rx_bytes[\$interface_nodot]))
        sp_ov_current_tx_bytes=\$((sp_ov_current_tx_bytes + sp_current_tx_bytes[\$interface_nodot]))
    done

    # 计算网速
    sp_ov_rx_diff_speed=\$((sp_ov_current_rx_bytes - sp_ov_prev_rx_bytes))
    sp_ov_tx_diff_speed=\$((sp_ov_current_tx_bytes - sp_ov_prev_tx_bytes))
    # rx_speed=\$(awk "BEGIN { speed = \$sp_ov_rx_diff_speed / (\$TT * 1024); if (speed >= 1024) { printf \"%.1fMB\", speed/1024 } else { printf \"%.1fKB\", speed } }")
    # tx_speed=\$(awk "BEGIN { speed = \$sp_ov_tx_diff_speed / (\$TT * 1024); if (speed >= 1024) { printf \"%.1fMB\", speed/1024 } else { printf \"%.1fKB\", speed } }")

    ((avg_count++))

    rx_speed_kb=\$(awk -v v1="\$sp_ov_rx_diff_speed" -v t1="\$TT" 'BEGIN { printf "%.1f", v1 / (t1 * 1024) }')

    if (( \$(awk 'BEGIN {print ('\$rx_speed_kb' > '\$max_rx_speed_kb') ? "1" : "0"}') )); then
        max_rx_speed_kb=\$rx_speed_kb
    fi
    if (( \$(awk 'BEGIN {print ('\$rx_speed_kb' < '\$min_rx_speed_kb') ? "1" : "0"}') )); then
        min_rx_speed_kb=\$rx_speed_kb
    fi

    total_rx_speed_kb=\$(awk 'BEGIN {print "'\$total_rx_speed_kb'" + "'\$rx_speed_kb'"}')
    avg_rx_speed_kb=\$(awk 'BEGIN {printf "%.1f", "'\$total_rx_speed_kb'" / "'\$avg_count'"}')

    rx_speed=\$(Bytes_K_TGM "\$rx_speed_kb")
    max_rx_speed=\$(Bytes_K_TGM "\$max_rx_speed_kb")
    min_rx_speed=\$(Bytes_K_TGM "\$min_rx_speed_kb")
    avg_rx_speed=\$(Bytes_K_TGM "\$avg_rx_speed_kb")

    if [ "\$ss_tag" == "st" ]; then

        rx_speedi=\$(Bytes_K_TGMi "\$rx_speed_kb")
        max_rx_speedi=\$(Bytes_K_TGMi "\$max_rx_speed_kb")
        min_rx_speedi=\$(Bytes_K_TGMi "\$min_rx_speed_kb")
        avg_rx_speedi=\$(Bytes_K_TGMi "\$avg_rx_speed_kb")
        rx_speedb=\$(Bit_K_TGMi "\$(awk 'BEGIN {printf "%.1f", "'\$rx_speed_kb'" * 8}')")
        max_rx_speedb=\$(Bit_K_TGMi "\$(awk 'BEGIN {printf "%.1f", "'\$max_rx_speed_kb'" * 8}')")
        min_rx_speedb=\$(Bit_K_TGMi "\$(awk 'BEGIN {printf "%.1f", "'\$min_rx_speed_kb'" * 8}')")
        avg_rx_speedb=\$(Bit_K_TGMi "\$(awk 'BEGIN {printf "%.1f", "'\$avg_rx_speed_kb'" * 8}')")

    else
        rx_speed=\$(Bytes_K_TGM "\$rx_speed_kb")
        max_rx_speed=\$(Bytes_K_TGM "\$max_rx_speed_kb")
        min_rx_speed=\$(Bytes_K_TGM "\$min_rx_speed_kb")
        avg_rx_speed=\$(Bytes_K_TGM "\$avg_rx_speed_kb")
    fi

    tx_speed_kb=\$(awk -v v1="\$sp_ov_tx_diff_speed" -v t1="\$TT" 'BEGIN { printf "%.1f", v1 / (t1 * 1024) }')

    if (( \$(awk 'BEGIN {print ('\$tx_speed_kb' > '\$max_tx_speed_kb') ? "1" : "0"}') )); then
        max_tx_speed_kb=\$tx_speed_kb
    fi
    if (( \$(awk 'BEGIN {print ('\$tx_speed_kb' < '\$min_tx_speed_kb') ? "1" : "0"}') )); then
        min_tx_speed_kb=\$tx_speed_kb
    fi

    total_tx_speed_kb=\$(awk 'BEGIN {print "'\$total_tx_speed_kb'" + "'\$tx_speed_kb'"}')
    avg_tx_speed_kb=\$(awk 'BEGIN {printf "%.1f", "'\$total_tx_speed_kb'" / "'\$avg_count'"}')

    if [ "\$ss_tag" == "st" ]; then

        tx_speedi=\$(Bytes_K_TGMi "\$tx_speed_kb")
        max_tx_speedi=\$(Bytes_K_TGMi "\$max_tx_speed_kb")
        min_tx_speedi=\$(Bytes_K_TGMi "\$min_tx_speed_kb")
        avg_tx_speedi=\$(Bytes_K_TGMi "\$avg_tx_speed_kb")
        tx_speedb=\$(Bit_K_TGMi "\$(awk 'BEGIN {printf "%.1f", "'\$tx_speed_kb'" * 8}')")
        max_tx_speedb=\$(Bit_K_TGMi "\$(awk 'BEGIN {printf "%.1f", "'\$max_tx_speed_kb'" * 8}')")
        min_tx_speedb=\$(Bit_K_TGMi "\$(awk 'BEGIN {printf "%.1f", "'\$min_tx_speed_kb'" * 8}')")
        avg_tx_speedb=\$(Bit_K_TGMi "\$(awk 'BEGIN {printf "%.1f", "'\$avg_tx_speed_kb'" * 8}')")

        # 实时TCP/UDP连接数
        tut_errtips=""
        tuu_errtips=""
        if [ "\$tu_show" == "true" ]; then
            # 获取tcp开头的行数，并将Foreign Address为本地IP地址和外部地址的连接数进行统计
            if command -v ss &>/dev/null; then
                # tcp_connections=\$(ss -t | tail -n +2)
                # tcp_connections=\$(ss -t | tail -n +2 | sed -e 's/\[\(::ffff:\)\?//g' -e 's/\]//g')
                tcp_connections=\$(ss -at | tail -n +2 | sed -e 's/\[\(::ffff:\)\?//g' -e 's/\]//g' | grep -v 'LISTEN' | grep -v '0.0.0.0:*' | grep -v '\[::\]:*' | grep -v '*:*' | grep -v 'localhost')
                tut_tool="ss"
                tcp_ip_location=5
            elif command -v netstat &>/dev/null; then
                # tcp_connections=\$(netstat -ant | grep '^tcp' | grep -v '0.0.0.0:*' | grep -v '\[::\]:*')
                # tcp_connections=\$(netstat -ant | grep '^tcp' | grep -v 'LISTEN')
                tcp_connections=\$(netstat -ant | grep '^tcp' | grep -v 'LISTEN' | sed -e 's/\(::ffff:\)\?//g' | grep -v '0.0.0.0:*' | grep -v '\[::\]:*' | grep -v ':::*' | grep -v 'localhost')
                tut_tool="netstat"
                tcp_ip_location=5
            else
                tut_errtips="\${RE}TCP 连接数获取失败!\${NC}"
            fi

            if command -v ss &>/dev/null; then
                # udp_connections=\$(ss -u | tail -n +2)
                # udp_connections=\$(ss -u | tail -n +2 | sed -e 's/\[\(::ffff:\)\?//g' -e 's/\]//g') # 注意 udp_ip_location 为4还是5?
                udp_connections=\$(ss -au | tail -n +2 | sed -e 's/\[\(::ffff:\)\?//g' -e 's/\]//g' | grep -v 'LISTEN' | grep -v '0.0.0.0:*' | grep -v '\[::\]:*' | grep -v '*:*' | grep -v 'localhost')
                tuu_tool="ss"
                udp_ip_location=5
            elif command -v netstat &>/dev/null; then
                # udp_connections=\$(netstat -anu | grep '^udp' | grep -v '0.0.0.0:*' | grep -v '\[::\]:*')
                # udp_connections=\$(netstat -anu | grep '^udp' | grep -v 'LISTEN')
                udp_connections=\$(netstat -anu | grep '^udp' | grep -v 'LISTEN' | sed -e 's/\(::ffff:\)\?//g' | grep -v '0.0.0.0:*' | grep -v '\[::\]:*' | grep -v ':::*' | grep -v 'localhost')
                tuu_tool="netstat"
                udp_ip_location=5
            else
                tuu_errtips="\${RE}UDP 连接数获取失败!\${NC}"
            fi

            tcp_local_connections=0
            tcp_external_connections=0
            tcp_external_details=()
            tcp_total=0
            tcp_num_estab_local=0
            tcp_num_estab_external=0

            udp_local_connections=0
            udp_external_connections=0
            udp_external_details=()
            udp_total=0
            # udp_num_estab_local=0
            # udp_num_estab_external=0

            # tcp_num_estab=\$(grep -c -E 'ESTABLISHED|ESTAB' <<< "\$tcp_connections")
            # udp_num_estab=\$(grep -c -E 'ESTABLISHED|ESTAB' <<< "\$udp_connections")

            # 定义本地IP地址范围
            local_ip_ranges=("0.0.0.0" "127.0.0.1" "[::" "fc" "fd" "fe" "localhost" "192.168" "10." "172.16" "172.17" "172.18" "172.19" "172.20" "172.21" "172.22" "172.23" "172.24" "172.25" "172.26" "172.27" "172.28" "172.29" "172.30" "172.31")

            if [[ ! -z "\$tcp_connections" ]]; then
                while IFS= read -r line; do
                    foreign_address=\$(echo \$line | awk -v var=\$tcp_ip_location '{print \$var}')
                    is_local=0
                    for ip_range in "\${local_ip_ranges[@]}"; do
                        if [[ \$foreign_address == \$ip_range* ]]; then
                            is_local=1
                            break
                        fi
                    done
                    if [[ \$is_local -eq 1 ]]; then
                        ((tcp_local_connections++))
                        if [[ \$line =~ ESTABLISHED|ESTAB ]]; then
                            ((tcp_num_estab_local++))
                        fi
                    else
                        ((tcp_external_connections++))
                        if [[ \$line =~ ESTABLISHED|ESTAB ]]; then
                            ((tcp_num_estab_external++))
                        fi
                        tcp_external_details+=("\$line")
                    fi
                    ((tcp_total++))
                done <<< "\$tcp_connections"
            fi
            if [[ ! -z "\$udp_connections" ]]; then
                while IFS= read -r line; do
                    if [[ \$line =~ ESTABLISHED|ESTAB ]]; then
                        ((udp_num_estab++))
                    fi
                    foreign_address=\$(echo \$line | awk -v var=\$udp_ip_location '{print \$var}')
                    is_local=0
                    for ip_range in "\${local_ip_ranges[@]}"; do
                        if [[ \$foreign_address == \$ip_range* ]]; then
                            is_local=1
                            break
                        fi
                    done
                    if [[ \$is_local -eq 1 ]]; then
                        ((udp_local_connections++))
                        # if [[ \$line =~ ESTABLISHED|ESTAB ]]; then
                        #     ((udp_num_estab_local++))
                        # fi
                    else
                        ((udp_external_connections++))
                        # if [[ \$line =~ ESTABLISHED|ESTAB ]]; then
                        #     ((udp_num_estab_external++))
                        # fi
                        udp_external_details+=("\$line")
                    fi
                    ((udp_total++))
                done <<< "\$udp_connections"
            fi
            tcp_num_unusual_local=\$((tcp_local_connections - tcp_num_estab_local))
            tcp_num_unusual_external=\$((tcp_external_connections - tcp_num_estab_external))
            # udp_num_unusual_local=\$((udp_local_connections - udp_num_estab_local))
            # udp_num_unusual_external=\$((udp_external_connections - udp_num_estab_external))
        fi
    else
        tx_speed=\$(Bytes_K_TGM "\$tx_speed_kb")
        max_tx_speed=\$(Bytes_K_TGM "\$max_tx_speed_kb")
        min_tx_speed=\$(Bytes_K_TGM "\$min_tx_speed_kb")
        avg_tx_speed=\$(Bytes_K_TGM "\$avg_tx_speed_kb")
    fi

    # rx_speed=\$(awk -v v1="\$sp_ov_rx_diff_speed" -v t1="\$TT" \
    #     'BEGIN {
    #         speed = v1 / (t1 * 1024)
    #         if (speed >= (1024 * 1024)) {
    #             printf "%.1fGB", speed/(1024 * 1024)
    #         } else if (speed >= 1024) {
    #             printf "%.1fMB", speed/1024
    #         } else {
    #             printf "%.1fKB", speed
    #         }
    #     }')
    # tx_speed=\$(awk -v v1="\$sp_ov_tx_diff_speed" -v t1="\$TT" \
    #     'BEGIN {
    #         speed = v1 / (t1 * 1024)
    #         if (speed >= (1024 * 1024)) {
    #             printf "%.1fGB", speed/(1024 * 1024)
    #         } else if (speed >= 1024) {
    #             printf "%.1fMB", speed/1024
    #         } else {
    #             printf "%.1fKB", speed
    #         }
    #     }')

    if [ \$CLEAR_TAG -eq 1 ]; then
        echo -e "DATE: \$(date +"%Y-%m-%d %H:%M:%S")" > \$FolderPath/interface_re.txt
        CLEAR_TAG=\$((CLEAR_TAG_OLD + 1))
        CLS
        echo -e " \${GRB}实时网速\${NC}                                 (\${TT}s)"
        echo " =================================================="
    else
        echo -e "DATE: \$(date +"%Y-%m-%d %H:%M:%S")" >> \$FolderPath/interface_re.txt
    fi

    if [ "\$ss_tag" == "st" ]; then
        echo -e "   接收: \${GR}\${rx_speedi}\${NC} /s   ( \${GR}\${rx_speedb}\${NC} /s )"
        echo -e "   发送: \${GR}\${tx_speedi}\${NC} /s   ( \${GR}\${tx_speedb}\${NC} /s )"
        echo " =================================================="
        echo -e " 统计接口: \$show_interfaces"
        echo " =================================================="

        echo -e " \${GRB}下\${NC}"
        echo -e "   MAX: \${GR}\$max_rx_speedi\${NC} /s   ( \${GR}\$max_rx_speedb\${NC} /s )"
        echo -e "   MIN: \${GR}\$min_rx_speedi\${NC} /s   ( \${GR}\$min_rx_speedb\${NC} /s )"
        echo -e "   AVG: \${GR}\$avg_rx_speedi\${NC} /s   ( \${GR}\$avg_rx_speedb\${NC} /s )"
        echo " --------------------------------------------------"
        echo -e " \${GRB}上\${NC}"
        echo -e "   MAX: \${GR}\$max_tx_speedi\${NC} /s   ( \${GR}\$max_tx_speedb\${NC} /s )"
        echo -e "   MIN: \${GR}\$min_tx_speedi\${NC} /s   ( \${GR}\$min_tx_speedb\${NC} /s )"
        echo -e "   AVG: \${GR}\$avg_tx_speedi\${NC} /s   ( \${GR}\$avg_tx_speedb\${NC} /s )"

        # 实时TCP/UDP连接数输出结果
        if [ "\$tu_show" == "true" ]; then
            echo " =================================================="
            # echo -e " \${GRB}TCP\${NC} 内网连接(\$tut_tool): \${GR}\$tcp_local_connections\${NC}  / \$tcp_total \$tut_errtips"
            # echo -e " \${GRB}TCP\${NC} 外网连接(\$tut_tool): \${GR}\$tcp_external_connections\${NC}  / \$tcp_total \$tut_errtips"
            echo -e " \${GRB}TCP\${NC} 内网连接(\$tut_tool): \${GR}\$tcp_num_estab_local\${NC}  / \${RE}\$tcp_num_unusual_local\${NC}  / \$tcp_total \$tut_errtips"
            echo -e " \${GRB}TCP\${NC} 外网连接(\$tut_tool): \${GR}\$tcp_num_estab_external\${NC}  / \${RE}\$tcp_num_unusual_external\${NC}  / \$tcp_total \$tut_errtips"
            # if [[ \$tcp_external_connections -gt 0 ]]; then
            #     echo "   TCP外部连接详情:"
            #     for detail in "\${tcp_external_details[@]}"; do
            #         echo "\$detail"
            #     done
            # fi
            echo " --------------------------------------------------"
            # echo -e " \${GRB}UDP\${NC} 内网连接(\$tuu_tool): \${GR}\$udp_local_connections\${NC}  / \$udp_total \$tuu_errtips"
            # echo -e " \${GRB}UDP\${NC} 外网连接(\$tuu_tool): \${GR}\$udp_external_connections\${NC}  / \$udp_total \$tuu_errtips"
            echo -e " \${GRB}UDP\${NC} 内网连接(\$tuu_tool): \${GR}\$udp_local_connections\${NC}  / \$udp_total \$tuu_errtips"
            echo -e " \${GRB}UDP\${NC} 外网连接(\$tuu_tool): \${GR}\$udp_external_connections\${NC}  / \$udp_total \$tuu_errtips"
            # if [[ \$udp_external_connections -gt 0 ]]; then
            #     echo "   UDP外部连接详情:"
            #     for detail in "\${udp_external_details[@]}"; do
            #         echo "\$detail"
            #     done
            # fi
            echo " --------------------------------------------------"
            echo -e " 数值说明: \${GR}正常连接\${NC}  / \${RE}非正常连接(TCP)\${NC}  / 总连接"
        fi
        echo "接收: \$rx_speedi  发送: \$tx_speedi" >> \$FolderPath/interface_re.txt
        echo "==============================================" >> \$FolderPath/interface_re.txt
    else
        rx_speed=\$(Remove_B "\$rx_speed")
        tx_speed=\$(Remove_B "\$tx_speed")
        max_rx_speed=\$(Remove_B "\$max_rx_speed")
        min_rx_speed=\$(Remove_B "\$min_rx_speed")
        avg_rx_speed=\$(Remove_B "\$avg_rx_speed")
        max_tx_speed=\$(Remove_B "\$max_tx_speed")
        min_tx_speed=\$(Remove_B "\$min_tx_speed")
        avg_tx_speed=\$(Remove_B "\$avg_tx_speed")

        echo -e " 接收: \${GR}\${rx_speed}\${NC} /s         发送: \${GR}\${tx_speed}\${NC} /s"
        echo " =================================================="
        echo -e " 统计接口: \$show_interfaces"
        echo " =================================================="

        echo -e " \${GRB}下\${NC} MAX: \${GR}\$max_rx_speed\${NC} /s   MIN: \${GR}\$min_rx_speed\${NC} /s   AVG: \${GR}\$avg_rx_speed\${NC} /s"
        echo " --------------------------------------------------"
        echo -e " \${GRB}上\${NC} MAX: \${GR}\$max_tx_speed\${NC} /s   MIN: \${GR}\$min_tx_speed\${NC} /s   AVG: \${GR}\$avg_tx_speed\${NC} /s"

        echo "接收: \$rx_speed  发送: \$tx_speed" >> \$FolderPath/interface_re.txt
        echo "==============================================" >> \$FolderPath/interface_re.txt
    fi

    CLEAR_TAG=\$((\$CLEAR_TAG - 1))
done
EOF
        chmod +x $FolderPath/tg_interface_re.sh
    # fi
    CLS
    echo -e "${RE}注意${NC}:  ${REB}按任意键中止${NC}"
    stty intr ^- # 禁用 CTRL+C
    divline
    bash $FolderPath/tg_interface_re.sh &
    tg_interface_re_pid=$!
    read -n 1 -s -r -p ""
    stty intr ^C # 恢复 CTRL+C
    # stty sane # 重置终端设置为默认值
    kill -2 $tg_interface_re_pid 2>/dev/null
    killpid "tg_interface_re"
    # pkill -f tg_interface_re
    # kill $(ps | grep '[t]g_interface_re' | awk '{print $1}') 2>/dev/null
    # pgrep -f tg_interface_re | xargs kill -9 2>/dev/null
    if universal_process_exists "tg_interface_re"; then
        echo -e "中止失败!! 请执行以下指令中止!"
        if command -v pkill >/dev/null 2>&1; then
            echo -e "中止指令1: ${REB}pkill -f tg_interface_re${NC}"
        fi
        echo -e "中止指令2: ${REB}kill $(ps | grep '[t]g_interface_re' | awk '{print $1}') 2>/dev/null${NC}"
    fi
    divline
}
