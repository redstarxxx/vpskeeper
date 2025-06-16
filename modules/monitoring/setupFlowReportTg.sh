#!/usr/bin/env bash


SetFlowReport_TG() {
    if [ ! -z "${flrp_pid:-}" ] && pgrep -a '' | grep -Eq "^\s*$flrp_pid\s" > /dev/null; then
        tips="$Err PID(${GR}$flrp_pid${NC}) 正在发送中,请稍后..."
        return 1
    fi
    if [[ -z "${TelgramBotToken}" || -z "${ChatID_1}" ]]; then
        tips="$Err 参数丢失, 请设置后再执行 (先执行 ${GR}0${NC} 选项)."
        return 1
    fi
    if [ "$autorun" == "false" ]; then
        echo -e "$Tip 输入流量报告时间, 格式如: 22:34 (即每天 ${GR}22${NC} 时 ${GR}34${NC} 分)"
        read -e -p "请输入定时模式  (回车默认: $ReportTime_de ): " input_time
    else
        if [ -z "$ReportTime" ]; then
            input_time=""
        else
            input_time=$ReportTime
        fi
    fi
    if [ -z "$input_time" ]; then
        input_time="$ReportTime_de"
    fi
    if [ $(validate_time_format "$input_time") = "invalid" ]; then
        tips="$Err 输入格式不正确，请确保输入的时间格式为 'HH:MM'"
        return 1
    fi
    writeini "ReportTime" "$input_time"
    hour_rp=${input_time%%:*}
    minute_rp=${input_time#*:}
    if [ ${#hour_rp} -eq 1 ]; then
    hour_rp="0${hour_rp}"
    fi
    if [ ${#minute_rp} -eq 1 ]; then
        minute_rp="0${minute_rp}"
    fi
    echo -e "$Tip 流量报告时间: $hour_rp 时 $minute_rp 分."
    cronrp="$minute_rp $hour_rp * * *"

    if [ "$autorun" == "false" ]; then
        # interfaces_RP_0=$(ip -br link | awk '$2 == "UP" {print $1}' | grep -v "lo")
        # output=$(ip -br link)
        IFS=$'\n'
        count=1
        choice_array=()
        interfaces_RP=()
        w_interfaces_RP=()
        # for line in $output; do
        for line in ${interfaces_all[@]}; do
            columns_1="$line"
            # columns_1=$(echo "$line" | awk '{print $1}')
            # columns_1=${columns_1[$i]%@*}
            # columns_1=${columns_1%:*}
            columns_1_array+=("$columns_1")
            columns_2="$line"
            # columns_2=$(printf "%s\t\tUP" "$line")
            # columns_2=$(echo "$line" | awk '{print $1"\t"$2}')
            # columns_2=${columns_2[$i]%@*}
            # columns_2=${columns_2%:*}
            # if [[ $interfaces_RP_0 =~ $columns_1 ]]; then
            if [[ $interfaces_up =~ $columns_1 ]]; then
                printf "${GR}%d. %s${NC}\n" "$count" "$columns_2"
            else
                printf "${GR}%d. ${NC}%s\n" "$count" "$columns_1"
            fi
            ((count++))
        done
        echo -e "请选择编号进行报告, 例如报告1项和2项可输入: ${GR}1,2${NC} 或 ${GR}回车自动检测${NC}活跃接口:"
        read -e -p "请输入统计接口编号: " choice
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
            #         interfaces_RP+=("${columns_1_array[index]}")
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
                interfaces_RP+=("${columns_1_array[index]}")
            done

            # for ((i = 0; i < ${#interfaces_RP[@]}; i++)); do
            #     w_interfaces_RP+="${interfaces_RP[$i]}"
            #     if ((i < ${#interfaces_RP[@]} - 1)); then
            #         w_interfaces_RP+=","
            #     fi
            # done
            w_interfaces_RP=$(sep_array interfaces_RP ",")
            # echo "确认选择接口: $w_interfaces_RP"
            writeini "interfaces_RP" "$w_interfaces_RP"
        else
            # IFS=',' read -ra interfaces_RP_de <<< "$interfaces_RP_de"
            # IFS=',' read -ra interfaces <<< "$(echo "$interfaces_RP_de" | tr ',' '\n' | sort -u | tr '\n' ',')"
            # IFS=',' read -ra interfaces <<< "$(echo "$interfaces_RP_de" | awk -v RS=, '!a[$1]++ {if (NR>1) printf ",%s", $0; else printf "%s", $0}')"
            # interfaces_RP=("${interfaces_RP_de[@]}")
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
            interfaces_RP=("${active_interfaces[@]}")
            # for ((i = 0; i < ${#interfaces_RP[@]}; i++)); do
            #     w_interfaces_RP+="${interfaces_RP[$i]}"
            #     if ((i < ${#interfaces_RP[@]} - 1)); then
            #         w_interfaces_RP+=","
            #     fi
            # done
            w_interfaces_RP=$(sep_array interfaces_RP ",")
            echo -e "$Tip 检测到活动的接口: $w_interfaces_RP"
            # echo "确认选择接口: $w_interfaces_RP"
            writeini "interfaces_RP" "$w_interfaces_RP"
        fi
    else
        if [ ! -z "${interfaces_RP+x}" ]; then
            interfaces_RP=("${interfaces_RP[@]}")
        else
            interfaces_RP=("${interfaces_RP_de[@]}")
        fi
        echo "interfaces_RP: $interfaces_RP"
    fi
    interfaces_RP=($(unique_array "${interfaces_RP[@]}")) # 去重处理
    show_interfaces_RP=$(sep_array interfaces_RP ",") # 加入分隔符
    if [ "$autorun" == "false" ]; then
        read -e -p "请选择统计模式: 1.接口合计发送  2.接口单独发送 (回车默认为单独发送): " mode
        if [ "$mode" == "1" ]; then
            StatisticsMode_RP="OV"
        elif [ "$mode" == "2" ]; then
            StatisticsMode_RP="SE"
        else
            StatisticsMode_RP=$StatisticsMode_RP_de
        fi
        writeini "StatisticsMode_RP" "$StatisticsMode_RP"
    else
        if [ ! -z "$StatisticsMode_RP" ]; then
            StatisticsMode_RP=$StatisticsMode_RP
        else
            StatisticsMode_RP=$StatisticsMode_RP_de
        fi
    fi
    echo "统计模式为: $StatisticsMode_RP"

    source $ConfigFile
    FlowThresholdMAX_UB=$FlowThresholdMAX
    FlowThresholdMAX_U=$(Remove_B "$FlowThresholdMAX_UB")
    if [[ $FlowThresholdMAX == *MB ]]; then
        FlowThresholdMAX=${FlowThresholdMAX%MB}
        FlowThresholdMAX=$(awk -v value=$FlowThresholdMAX 'BEGIN { printf "%.1f", value }')
    elif [[ $FlowThresholdMAX == *GB ]]; then
        FlowThresholdMAX=${FlowThresholdMAX%GB}
        FlowThresholdMAX=$(awk -v value=$FlowThresholdMAX 'BEGIN { printf "%.1f", value * 1024 }')
    elif [[ $FlowThresholdMAX == *TB ]]; then
        FlowThresholdMAX=${FlowThresholdMAX%TB}
        FlowThresholdMAX=$(awk -v value=$FlowThresholdMAX 'BEGIN { printf "%.1f", value * 1024 * 1024 }')
    fi
    cat <<EOF > "$FolderPath/tg_flrp.sh"
#!/bin/bash

$(declare -f create_progress_bar)
$(declare -f ratioandprogress)
progress=""
ratio=""
$(declare -f Bytes_B_TGMK)
$(declare -f TG_M_removeXB)
$(declare -f Remove_B)
$(declare -f Checkpara)

FolderPath="$FolderPath"
if [ ! -d "\$FolderPath" ]; then
    mkdir -p "\$FolderPath"
fi
ConfigFile="$ConfigFile"
source \$ConfigFile &>/dev/null
Checkpara "hostname_show" "$hostname_show"
Checkpara "ProxyURL" "$ProxyURL"
Checkpara "StatisticsMode_RP" "$StatisticsMode_RP"
Checkpara "SendUptime" "$SendUptime"
Checkpara "SendIP" "$SendIP"
Checkpara "GetIP46" "$GetIP46"
Checkpara "GetIPURL" "$GetIPURL"
Checkpara "SendPrice" "$SendPrice"
Checkpara "GetPriceType" "$GetPriceType"
Checkpara "FlowThreshold" "$FlowThreshold"
Checkpara "FlowThresholdMAX" "$FlowThresholdMAX"
Checkpara "interfaces_RP" "$interfaces_RP"

FlowThreshold_U=\$(Remove_B "\$FlowThreshold")
FlowThreshold=\$(TG_M_removeXB "\$FlowThreshold")
FlowThresholdMAX_U=\$(Remove_B "\$FlowThresholdMAX")
FlowThresholdMAX=\$(TG_M_removeXB "\$FlowThresholdMAX")

if [ "\$SendUptime" == "true" ]; then
    SendUptime="true"
else
    SendUptime="false"
fi
if [ "\$SendIP" == "true" ]; then
    SendIP="true"
else
    SendIP="false"
fi

THRESHOLD_BYTES_MAX=\$(awk "BEGIN {print \$FlowThresholdMAX * 1024 * 1024}")
THRESHOLD_BYTES_MAX=\$(printf "%.0f" \$THRESHOLD_BYTES_MAX)
echo "==================================================================="
echo "THRESHOLD_BYTES_MAX: \$THRESHOLD_BYTES_MAX"

interfaces=()
# interfaces=\$(ip -br link | awk '\$2 == "UP" {print \$1}' | grep -v "lo")
# interfaces_all=\$(ip -br link | awk '{print \$1}' | tr '\n' ' ')
# IFS=',' read -ra interfaces <<< "\$interfaces_RP"
# 去重并且分割字符串为数组
# IFS=',' read -ra interfaces <<< "\$(echo "\$interfaces_RP" | tr ',' '\n' | sort -u | tr '\n' ',')"
# 去重并且保持原有顺序，分割字符串为数组
# IFS=',' read -ra interfaces <<< "$(echo "$interfaces_RP" | awk -v RS=, '!a[$1]++ {if (NR>1) printf ",%s", $0; else printf "%s", $0}')"
IFS=',' read -ra interfaces <<< "\$(echo "\$interfaces_RP" | awk -v RS=, '!a[\$1]++ {if (NR>1) printf ",%s", \$0; else printf "%s", \$0}')"

echo "统计接口: \${interfaces[@]}"
for ((i = 0; i < \${#interfaces[@]}; i++)); do
    echo "\$((i+1)): \${interfaces[i]}"
done
for ((i = 0; i < \${#interfaces[@]}; i++)); do
    show_interfaces+="\${interfaces[\$i]}"
    if ((i < \${#interfaces[@]} - 1)); then
        show_interfaces+=","
    fi
done

# 如果接口名称中包含 '@' 或 ':'，则仅保留 '@' 或 ':' 之前的部分
for ((i=0; i<\${#interfaces[@]}; i++)); do
    interface=\${interfaces[\$i]%@*}
    interface=\${interface%:*}
    interfaces[\$i]=\$interface
done
echo "纺计接口(处理后): \${interfaces[@]}"

# 定义数组
declare -A prev_rx_bytes
declare -A prev_tx_bytes
declare -A tt_prev_rx_bytes_T
declare -A tt_prev_tx_bytes_T
declare -A prev_day_rx_bytes
declare -A prev_day_tx_bytes
declare -A prev_month_rx_bytes
declare -A prev_month_tx_bytes
declare -A prev_year_rx_bytes
declare -A prev_year_tx_bytes
declare -A current_rx_bytes
declare -A current_tx_bytes
declare -A INTERFACE_RT_RX_B
declare -A INTERFACE_RT_TX_B

source \$ConfigFile &>/dev/null
for interface in "\${interfaces[@]}"; do
    interface_nodot=\${interface//./_}
    INTERFACE_RT_RX_B[\$interface_nodot]=\${INTERFACE_RT_RX_B[\$interface_nodot]}
    echo "读取: INTERFACE_RT_RX_B[\$interface_nodot]: \${INTERFACE_RT_RX_B[\$interface_nodot]}"
    INTERFACE_RT_TX_B[\$interface_nodot]=\${INTERFACE_RT_TX_B[\$interface_nodot]}
    echo "读取: INTERFACE_RT_TX_B[\$interface_nodot]: \${INTERFACE_RT_TX_B[\$interface_nodot]}"
done

# test_hour="01"
# test_minute="47"

tt=60
duration=0
tt_prev=false
year_rp=false
month_rp=false
day_rp=false
day_sendtag=true
month_sendtag=true
year_sendtag=true

echo "runing..."
while true; do

    source \$ConfigFile &>/dev/null
    Checkpara "hostname_show" "$hostname_show"
    Checkpara "ProxyURL" "$ProxyURL"
    Checkpara "StatisticsMode_RP" "$StatisticsMode_RP"
    Checkpara "SendUptime" "$SendUptime"
    Checkpara "SendIP" "$SendIP"
    Checkpara "GetIP46" "$GetIP46"
    Checkpara "GetIPURL" "$GetIPURL"
    Checkpara "SendPrice" "$SendPrice"
    Checkpara "GetPriceType" "$GetPriceType"
    Checkpara "FlowThreshold" "$FlowThreshold"
    Checkpara "FlowThresholdMAX" "$FlowThresholdMAX"

    FlowThreshold_U=\$(Remove_B "\$FlowThreshold")
    FlowThreshold=\$(TG_M_removeXB "\$FlowThreshold")
    FlowThresholdMAX_U=\$(Remove_B "\$FlowThresholdMAX")
    FlowThresholdMAX=\$(TG_M_removeXB "\$FlowThresholdMAX")

    # 获取tt秒前数据
    ov_prev_rx_bytes=0
    ov_prev_tx_bytes=0
    for interface in "\${interfaces[@]}"; do
        interface_nodot=\${interface//./_}
        prev_rx_bytes[\$interface_nodot]=\$(ip -s link show \$interface | awk '/RX:/ { getline; print \$1 }')
        prev_tx_bytes[\$interface_nodot]=\$(ip -s link show \$interface | awk '/TX:/ { getline; print \$1 }')
        ov_prev_rx_bytes=\$((ov_prev_rx_bytes + prev_rx_bytes[\$interface_nodot]))
        ov_prev_tx_bytes=\$((ov_prev_tx_bytes + prev_tx_bytes[\$interface_nodot]))
    done

    if ! \$tt_prev; then
        if \$day_sendtag; then
            for interface in "\${interfaces[@]}"; do
                interface_nodot=\${interface//./_}
                echo "\$interface 发送前只执行一次 tt_prev_day_sendtag."
                prev_day_rx_bytes[\$interface_nodot]=\${prev_rx_bytes[\$interface_nodot]}
                prev_day_tx_bytes[\$interface_nodot]=\${prev_tx_bytes[\$interface_nodot]}
            done
            ov_prev_day_rx_bytes=\$ov_prev_rx_bytes
            ov_prev_day_tx_bytes=\$ov_prev_tx_bytes
        fi
        if \$month_sendtag; then
            for interface in "\${interfaces[@]}"; do
                interface_nodot=\${interface//./_}
                echo "\$interface 发送前只执行一次 tt_prev_month_sendtag."
                prev_month_rx_bytes[\$interface_nodot]=\${prev_rx_bytes[\$interface_nodot]}
                prev_month_tx_bytes[\$interface_nodot]=\${prev_tx_bytes[\$interface_nodot]}
            done
            ov_prev_month_rx_bytes=\$ov_prev_rx_bytes
            ov_prev_month_tx_bytes=\$ov_prev_tx_bytes
        fi
        if \$year_sendtag; then
            for interface in "\${interfaces[@]}"; do
                interface_nodot=\${interface//./_}
                echo "\$interface 发送前只执行一次 tt_prev_year_sendtag."
                prev_year_rx_bytes[\$interface_nodot]=\${prev_rx_bytes[\$interface_nodot]}
                prev_year_tx_bytes[\$interface_nodot]=\${prev_tx_bytes[\$interface_nodot]}
            done
            ov_prev_year_rx_bytes=\$ov_prev_rx_bytes
            ov_prev_year_tx_bytes=\$ov_prev_tx_bytes
        fi
    else
        if \$day_sendtag; then
            for interface in "\${interfaces[@]}"; do
                interface_nodot=\${interface//./_}
                echo "\$interface 发送前只执行一次 day_sendtag."
                prev_day_rx_bytes[\$interface_nodot]=\${tt_prev_rx_bytes_T[\$interface_nodot]}
                prev_day_tx_bytes[\$interface_nodot]=\${tt_prev_tx_bytes_T[\$interface_nodot]}
            done
            ov_prev_day_rx_bytes=\$tt_ov_prev_rx_bytes_T
            ov_prev_day_tx_bytes=\$tt_ov_prev_tx_bytes_T
        fi
        if \$month_sendtag; then
            for interface in "\${interfaces[@]}"; do
                interface_nodot=\${interface//./_}
                echo "\$interface 发送前只执行一次 month_sendtag."
                prev_month_rx_bytes[\$interface_nodot]=\${tt_prev_rx_bytes_T[\$interface_nodot]}
                prev_month_tx_bytes[\$interface_nodot]=\${tt_prev_tx_bytes_T[\$interface_nodot]}
            done
            ov_prev_month_rx_bytes=\$tt_ov_prev_rx_bytes_T
            ov_prev_month_tx_bytes=\$tt_ov_prev_tx_bytes_T
        fi
        if \$year_sendtag; then
            for interface in "\${interfaces[@]}"; do
                interface_nodot=\${interface//./_}
                echo "\$interface 发送前只执行一次 year_sendtag."
                prev_year_rx_bytes[\$interface_nodot]=\${tt_prev_rx_bytes_T[\$interface_nodot]}
                prev_year_tx_bytes[\$interface_nodot]=\${tt_prev_tx_bytes_T[\$interface_nodot]}
            done
            ov_prev_year_rx_bytes=\$tt_ov_prev_rx_bytes_T
            ov_prev_year_tx_bytes=\$tt_ov_prev_tx_bytes_T
        fi
    fi
    day_sendtag=false
    month_sendtag=false
    year_sendtag=false

    # 等待tt秒
    end_time=\$(date +%s%N)
    if [ ! -z "\$start_time" ]; then
        time_diff=\$((end_time - start_time))
        time_diff_ms=\$((time_diff / 1000000))

        # 输出执行FOR所花费时间
        echo "上一个 FOR循环 所执行时间 \$time_diff_ms 毫秒."

        duration=\$(awk "BEGIN {print \$time_diff_ms/1000}")
        sleep_time=\$(awk -v v1=\$tt -v v2=\$duration 'BEGIN { printf "%.3f", v1 - v2 }')
    else
        sleep_time=\$tt
    fi
    sleep_time=\$(awk "BEGIN {print (\$sleep_time < 0 ? 0 : \$sleep_time)}")
    echo "sleep_time: \$sleep_time   duration: \$duration"
    sleep \$sleep_time
    start_time=\$(date +%s%N)

    # 获取tt秒后数据
    ov_current_rx_bytes=0
    ov_current_tx_bytes=0
    for interface in "\${interfaces[@]}"; do
        interface_nodot=\${interface//./_}
        current_rx_bytes[\$interface_nodot]=\$(ip -s link show \$interface | awk '/RX:/ { getline; print \$1 }')
        current_tx_bytes[\$interface_nodot]=\$(ip -s link show \$interface | awk '/TX:/ { getline; print \$1 }')
        ov_current_rx_bytes=\$((ov_current_rx_bytes + current_rx_bytes[\$interface_nodot]))
        ov_current_tx_bytes=\$((ov_current_tx_bytes + current_tx_bytes[\$interface_nodot]))
    done

    for interface in "\${interfaces[@]}"; do
        interface_nodot=\${interface//./_}
        tt_prev_rx_bytes_T[\$interface_nodot]=\${current_rx_bytes[\$interface_nodot]}
        tt_prev_tx_bytes_T[\$interface_nodot]=\${current_tx_bytes[\$interface_nodot]}
    done
    tt_ov_prev_rx_bytes_T=\$ov_current_rx_bytes
    tt_ov_prev_tx_bytes_T=\$ov_current_tx_bytes
    tt_prev=true

    nline=1
    # 获取当前时间的小时和分钟
    current_year=\$(date +"%Y")
    current_month=\$(date +"%m")
    current_day=\$(date +"%d")
    current_hour=\$(date +"%H")
    current_minute=\$(date +"%M")
    # tail_day=\$(date -d "\$(date +'%Y-%m-01 next month') -1 day" +%d)

    for interface in "\${interfaces[@]}"; do
        interface_nodot=\${interface//./_}
        echo "NO.\$nline --------------------------------------rp--- interface: \$interface"

        all_rx_bytes=\$ov_current_rx_bytes
        all_rx_bytes=\$((all_rx_bytes + INTERFACE_RT_RX_B[\$interface_nodot]))
        all_rx_ratio=\$(awk -v used="\$all_rx_bytes" -v total="\$THRESHOLD_BYTES_MAX" 'BEGIN { printf "%.3f", ( used / total ) * 100 }')

        ratioandprogress "0" "0" "\$all_rx_ratio"
        all_rx_progress=\$progress
        all_rx_ratio=\$ratio

        all_rx=\$(Bytes_B_TGMK "\$all_rx_bytes")
        all_rx=\$(Remove_B "\$all_rx")

        all_tx_bytes=\$ov_current_tx_bytes
        all_tx_bytes=\$((all_tx_bytes + INTERFACE_RT_TX_B[\$interface_nodot]))
        all_tx_ratio=\$(awk -v used="\$all_tx_bytes" -v total="\$THRESHOLD_BYTES_MAX" 'BEGIN { printf "%.3f", ( used / total ) * 100 }')

        ratioandprogress "0" "0" "\$all_tx_ratio"
        all_tx_progress=\$progress
        all_tx_ratio=\$ratio

        all_tx=\$(Bytes_B_TGMK "\$all_tx_bytes")
        all_tx=\$(Remove_B "\$all_tx")

        # 日报告 #################################################################################################################
        if [ "\$current_hour" == "00" ] && [ "\$current_minute" == "00" ]; then
            diff_day_rx_bytes=\$(( current_rx_bytes[\$interface_nodot] - prev_day_rx_bytes[\$interface_nodot] ))
            diff_day_tx_bytes=\$(( current_tx_bytes[\$interface_nodot] - prev_day_tx_bytes[\$interface_nodot] ))
            diff_rx_day=\$(Bytes_B_TGMK "\$diff_day_rx_bytes")
            diff_tx_day=\$(Bytes_B_TGMK "\$diff_day_tx_bytes")

            if [ "\$StatisticsMode_RP" == "OV" ]; then
                ov_diff_day_rx_bytes=\$(( ov_current_rx_bytes - ov_prev_day_rx_bytes ))
                ov_diff_day_tx_bytes=\$(( ov_current_tx_bytes - ov_prev_day_tx_bytes ))
                ov_diff_rx_day=\$(Bytes_B_TGMK "\$ov_diff_day_rx_bytes")
                ov_diff_tx_day=\$(Bytes_B_TGMK "\$ov_diff_day_tx_bytes")
            fi
            # 月报告
            if [ "\$current_day" == "01" ]; then
                diff_month_rx_bytes=\$(( current_rx_bytes[\$interface_nodot] - prev_month_rx_bytes[\$interface_nodot] ))
                diff_month_tx_bytes=\$(( current_tx_bytes[\$interface_nodot] - prev_month_tx_bytes[\$interface_nodot] ))
                diff_rx_month=\$(Bytes_B_TGMK "\$diff_month_rx_bytes")
                diff_tx_month=\$(Bytes_B_TGMK "\$diff_month_tx_bytes")

                if [ "\$StatisticsMode_RP" == "OV" ]; then
                    ov_diff_month_rx_bytes=\$(( ov_current_rx_bytes - ov_prev_month_rx_bytes ))
                    ov_diff_month_tx_bytes=\$(( ov_current_tx_bytes - ov_prev_month_tx_bytes ))
                    ov_diff_rx_month=\$(Bytes_B_TGMK "\$ov_diff_month_rx_bytes")
                    ov_diff_tx_month=\$(Bytes_B_TGMK "\$ov_diff_month_tx_bytes")
                fi
                # 年报告
                if [ "\$current_month" == "01" ] && [ "\$current_day" == "01" ]; then
                    diff_year_rx_bytes=\$(( current_rx_bytes[\$interface_nodot] - prev_year_rx_bytes[\$interface_nodot] ))
                    diff_year_tx_bytes=\$(( current_tx_bytes[\$interface_nodot] - prev_year_tx_bytes[\$interface_nodot] ))
                    diff_rx_year=\$(Bytes_B_TGMK "\$diff_year_rx_bytes")
                    diff_tx_year=\$(Bytes_B_TGMK "\$diff_year_tx_bytes")

                    if [ "\$StatisticsMode_RP" == "OV" ]; then
                        ov_diff_year_rx_bytes=\$(( ov_current_rx_bytes - ov_prev_year_rx_bytes ))
                        ov_diff_year_tx_bytes=\$(( ov_current_tx_bytes - ov_prev_year_tx_bytes ))
                        ov_diff_rx_year=\$(Bytes_B_TGMK "\$ov_diff_year_rx_bytes")
                        ov_diff_tx_year=\$(Bytes_B_TGMK "\$ov_diff_year_tx_bytes")
                    fi
                    year_rp=true
                fi
                month_rp=true
            fi
            day_rp=true
        fi

        # SE发送报告
        if [ "\$StatisticsMode_RP" == "SE" ]; then
            if [ "\$current_hour" == "$hour_rp" ] && [ "\$current_minute" == "$minute_rp" ]; then

                current_date_send=\$(date +"%Y.%m.%d %T")

                # 获取uptime输出
                if \$SendUptime; then
                    # read uptime idle_time < /proc/uptime
                    # uptime=\${uptime%.*}
                    # days=\$((uptime/86400))
                    # hours=\$(( (uptime%86400)/3600 ))
                    # minutes=\$(( (uptime%3600)/60 ))
                    # seconds=\$((uptime%60))
                    read uptime idle_time < /proc/uptime
                    uptime=\${uptime%.*}
                    days=\$(awk -v up="\$uptime" 'BEGIN{print int(up/86400)}')
                    hours=\$(awk -v up="\$uptime" 'BEGIN{print int((up%86400)/3600)}')
                    minutes=\$(awk -v up="\$uptime" 'BEGIN{print int((up%3600)/60)}')
                    seconds=\$(awk -v up="\$uptime" 'BEGIN{print int(up%60)}')
                    uptimeshow="系统已运行: \$days 日 \$hours 时 \$minutes 分 \$seconds 秒"
                else
                    uptimeshow=""
                fi
                echo "uptimeshow: \$uptimeshow"
                # 获取IP输出
                if \$SendIP; then
                    # lanIP=\$(ip a | grep -E "inet.*brd" | awk '{print \$2}' | awk -F '/' '{print \$1}' | tr '\n' ' ')
                    wanIP=\$(curl -s -"\$GetIP46" "\$GetIPURL")
                    wanIPshow="网络IP地址: \$wanIP"
                else
                    wanIPshow=""
                fi

                if \$day_rp; then

                    # if cat /proc/version 2>/dev/null | grep -q -E -i "openwrt"; then
                        current_timestamp=\$(date +%s)
                        one_day_seconds=\$((24 * 60 * 60))
                        yesterday_timestamp=\$((current_timestamp - one_day_seconds))
                        yesterday_date=\$(date -d "@\$yesterday_timestamp" +'%m月%d日')
                        yesterday="\$yesterday_date"

                        # current_month=\$(date +'%m')
                        # current_day=\$(date +'%d')
                        # yesterday_day=\$((current_day - 1))
                        # yesterday_month=\$current_month
                        # if [ \$yesterday_day -eq 0 ]; then
                        #     yesterday_month=\$((current_month - 1))
                        #     if [ \$yesterday_month -eq 0 ]; then
                        #         yesterday_month=12
                        #     fi
                        #     yesterday_day=\$(date -d "1-\${yesterday_month}-01 -1 day" +'%d')
                        # fi
                        # yesterday="\${yesterday_month}-\${yesterday_day}"

                    # else
                    #     yesterday=\$(date -d "1 day ago" +%m月%d日)
                    # fi

                    diff_rx_day=\$(Remove_B "\$diff_rx_day")
                    diff_tx_day=\$(Remove_B "\$diff_tx_day")

                    message="\${yesterday}🌞流量报告 📈"$'\n'
                    message+="主机名: \$hostname_show 接口: \$interface"$'\n'
                    message+="🌞接收: \${diff_rx_day}  🌞发送: \${diff_tx_day}"$'\n'
                    message+="───────────────"$'\n'
                    message+="总接收: \${all_rx}  总发送: \${all_tx}"$'\n'
                    message+="设置流量上限: \${FlowThresholdMAX_U}🔒"$'\n'
                    message+="使用⬇️: \$all_rx_progress \$all_rx_ratio"$'\n'
                    message+="使用⬆️: \$all_tx_progress \$all_tx_ratio"$'\n'
                    if [[ -n "\$uptimeshow" ]]; then
                        message+="\$uptimeshow"$'\n'
                    fi
                    if [[ -n "\$wanIPshow" ]]; then
                        message+="\$wanIPshow"$'\n'
                    fi
                    message+="服务器时间: \$current_date_send"

                    \$FolderPath/send_tg.sh "\$TelgramBotToken" "\$ChatID_1" "\$message"
                    echo "报告信息已发出..."
                    echo "时间: \$current_date, 活动接口: \$interface, 日接收: \$diff_rx_day, 日发送: \$diff_tx_day"
                    echo "----------------------------------------------------------------"
                    day_rp=false
                    day_sendtag=true
                fi

                if \$month_rp; then

                    sleep 15 # 当有多台VPS时,避免与日报告同时发送造成信息混乱

                    # if cat /proc/version 2>/dev/null | grep -q -E -i "openwrt"; then
                        current_year=\$(date +'%Y')
                        current_month=\$(date +'%m')
                        previous_month=\$((current_month - 1))
                        if [ "\$previous_month" -eq 0 ]; then
                            previous_month=12
                            current_year=\$((current_year - 1))
                        fi
                        last_month="\${current_year}年\${previous_month}月份"
                    # else
                    #     last_month=\$(date -d "1 month ago" +%Y年%m月份)
                    # fi

                    diff_rx_month=\$(Remove_B "\$diff_rx_month")
                    diff_tx_month=\$(Remove_B "\$diff_tx_month")

                    message="\${last_month}🌙总流量报告 📈"$'\n'
                    message+="主机名: \$hostname_show 接口: \$interface"$'\n'
                    message+="🌙接收: \${diff_rx_month}  🌙发送: \${diff_tx_month}"$'\n'
                    message+="───────────────"$'\n'
                    message+="总接收: \${all_rx}  总发送: \${all_tx}"$'\n'
                    message+="设置流量上限: \${FlowThresholdMAX_U}🔒"$'\n'
                    message+="使用⬇️: \$all_rx_progress \$all_rx_ratio"$'\n'
                    message+="使用⬆️: \$all_tx_progress \$all_tx_ratio"$'\n'
                    if [[ -n "\$uptimeshow" ]]; then
                        message+="\$uptimeshow"$'\n'
                    fi
                    if [[ -n "\$wanIPshow" ]]; then
                        message+="\$wanIPshow"$'\n'
                    fi
                    message+="服务器时间: \$current_date_send"

                    \$FolderPath/send_tg.sh "\$TelgramBotToken" "\$ChatID_1" "\$message"
                    echo "报告信息已发出..."
                    echo "时间: \$current_date, 活动接口: \$interface, 月接收: \$diff_rx_day, 月发送: \$diff_tx_day"
                    echo "----------------------------------------------------------------"
                    month_rp=false
                    month_sendtag=true
                fi

                if \$year_rp; then

                    sleep 15

                    # if cat /proc/version 2>/dev/null | grep -q -E -i "openwrt"; then
                        current_year=\$(date +'%Y')
                        previous_year=\$((current_year - 1))
                        last_year="\$previous_year"
                    # else
                    #     last_year=\$(date -d "1 year ago" +%Y)
                    # fi

                    diff_rx_year=\$(Remove_B "\$diff_rx_year")
                    diff_tx_year=\$(Remove_B "\$diff_tx_year")

                    message="\${last_year}年🧧总流量报告 📈"$'\n'
                    message+="主机名: \$hostname_show 接口: \$interface"$'\n'
                    message+="🧧接收: \${diff_rx_year}  🧧发送: \${diff_tx_year}"$'\n'
                    message+="───────────────"$'\n'
                    message+="总接收: \${all_rx}  总发送: \${all_tx}"$'\n'
                    message+="设置流量上限: \${FlowThresholdMAX_U}🔒"$'\n'
                    message+="使用⬇️: \$all_rx_progress \$all_rx_ratio"$'\n'
                    message+="使用⬆️: \$all_tx_progress \$all_tx_ratio"$'\n'
                    if [[ -n "\$uptimeshow" ]]; then
                        message+="\$uptimeshow"$'\n'
                    fi
                    if [[ -n "\$wanIPshow" ]]; then
                        message+="\$wanIPshow"$'\n'
                    fi
                    message+="服务器时间: \$current_date_send"

                    \$FolderPath/send_tg.sh "\$TelgramBotToken" "\$ChatID_1" "\$message"
                    echo "报告信息已发出..."
                    echo "年报告信息:"
                    echo "时间: \$current_date, 活动接口: \$interface, 年接收: \$diff_rx_year, 年发送: \$diff_tx_year"
                    echo "----------------------------------------------------------------"
                    year_rp=false
                    year_sendtag=true
                fi
            fi
        fi
    nline=\$((nline + 1))
    done

    # OV发送报告
    if [ "\$StatisticsMode_RP" == "OV" ]; then
        if [ "\$current_hour" == "$hour_rp" ] && [ "\$current_minute" == "$minute_rp" ]; then

            current_date_send=\$(date +"%Y.%m.%d %T")

            # 获取uptime输出
            if \$SendUptime; then
                # read uptime idle_time < /proc/uptime
                # uptime=\${uptime%.*}
                # days=\$((uptime/86400))
                # hours=\$(( (uptime%86400)/3600 ))
                # minutes=\$(( (uptime%3600)/60 ))
                # seconds=\$((uptime%60))
                read uptime idle_time < /proc/uptime
                uptime=\${uptime%.*}
                days=\$(awk -v up="\$uptime" 'BEGIN{print int(up/86400)}')
                hours=\$(awk -v up="\$uptime" 'BEGIN{print int((up%86400)/3600)}')
                minutes=\$(awk -v up="\$uptime" 'BEGIN{print int((up%3600)/60)}')
                seconds=\$(awk -v up="\$uptime" 'BEGIN{print int(up%60)}')
                uptimeshow="系统已运行: \$days 日 \$hours 时 \$minutes 分 \$seconds 秒"
            else
                uptimeshow=""
            fi
            echo "uptimeshow: \$uptimeshow"
            # 获取IP输出
            if \$SendIP; then
                # lanIP=\$(ip a | grep -E "inet.*brd" | awk '{print \$2}' | awk -F '/' '{print \$1}' | tr '\n' ' ')
                wanIP=\$(curl -s -"\$GetIP46" "\$GetIPURL")
                wanIPshow="网络IP地址: \$wanIP"
            else
                wanIPshow=""
            fi

            if \$day_rp; then

                # if cat /proc/version 2>/dev/null | grep -q -E -i "openwrt"; then
                    current_timestamp=\$(date +%s)
                    one_day_seconds=\$((24 * 60 * 60))
                    yesterday_timestamp=\$((current_timestamp - one_day_seconds))
                    yesterday_date=\$(date -d "@\$yesterday_timestamp" +'%m月%d日')
                    yesterday="\$yesterday_date"

                    # current_month=\$(date +'%m')
                    # current_day=\$(date +'%d')
                    # yesterday_day=\$((current_day - 1))
                    # yesterday_month=\$current_month
                    # if [ \$yesterday_day -eq 0 ]; then
                    #     yesterday_month=\$((current_month - 1))
                    #     if [ \$yesterday_month -eq 0 ]; then
                    #         yesterday_month=12
                    #     fi
                    #     yesterday_day=\$(date -d "1-\${yesterday_month}-01 -1 day" +'%d')
                    # fi
                    # yesterday="\${yesterday_month}-\${yesterday_day}"

                # else
                #     yesterday=\$(date -d "1 day ago" +%m月%d日)
                # fi

                ov_diff_rx_day=\$(Remove_B "\$ov_diff_rx_day")
                ov_diff_tx_day=\$(Remove_B "\$ov_diff_tx_day")

                message="\${yesterday}🌞流量报告 📈"$'\n'
                message+="主机名: \$hostname_show 接口: \$show_interfaces"$'\n'
                message+="🌞接收: \${ov_diff_rx_day}  🌞发送: \${ov_diff_tx_day}"$'\n'
                message+="───────────────"$'\n'
                message+="总接收: \${all_rx}  总发送: \${all_tx}"$'\n'
                message+="设置流量上限: \${FlowThresholdMAX_U}🔒"$'\n'
                message+="使用⬇️: \$all_rx_progress \$all_rx_ratio"$'\n'
                message+="使用⬆️: \$all_tx_progress \$all_tx_ratio"$'\n'
                if [[ -n "\$uptimeshow" ]]; then
                    message+="\$uptimeshow"$'\n'
                fi
                if [[ -n "\$wanIPshow" ]]; then
                    message+="\$wanIPshow"$'\n'
                fi
                message+="服务器时间: \$current_date_send"

                \$FolderPath/send_tg.sh "\$TelgramBotToken" "\$ChatID_1" "\$message"
                echo "报告信息已发出..."
                echo "时间: \$current_date, 活动接口: \$interface, 日接收: \$diff_rx_day, 日发送: \$diff_tx_day"
                echo "----------------------------------------------------------------"
                day_rp=false
                day_sendtag=true
            fi

            if \$month_rp; then

                sleep 15

                # if cat /proc/version 2>/dev/null | grep -q -E -i "openwrt"; then
                    current_year=\$(date +'%Y')
                    current_month=\$(date +'%m')
                    previous_month=\$((current_month - 1))
                    if [ "\$previous_month" -eq 0 ]; then
                        previous_month=12
                        current_year=\$((current_year - 1))
                    fi
                    last_month="\${current_year}年\${previous_month}月份"
                # else
                #     last_month=\$(date -d "1 month ago" +%Y年%m月份)
                # fi

                ov_diff_rx_month=\$(Remove_B "\$ov_diff_rx_month")
                ov_diff_tx_month=\$(Remove_B "\$ov_diff_tx_month")

                message="\${last_month}🌙总流量报告 📈"$'\n'
                message+="主机名: \$hostname_show 接口: \$show_interfaces"$'\n'
                message+="🌙接收: \${ov_diff_rx_month}  🌙发送: \${ov_diff_tx_month}"$'\n'
                message+="───────────────"$'\n'
                message+="总接收: \${all_rx}  总发送: \${all_tx}"$'\n'
                message+="设置流量上限: \${FlowThresholdMAX_U}🔒"$'\n'
                message+="使用⬇️: \$all_rx_progress \$all_rx_ratio"$'\n'
                message+="使用⬆️: \$all_tx_progress \$all_tx_ratio"$'\n'
                if [[ -n "\$uptimeshow" ]]; then
                    message+="\$uptimeshow"$'\n'
                fi
                if [[ -n "\$wanIPshow" ]]; then
                    message+="\$wanIPshow"$'\n'
                fi
                message+="服务器时间: \$current_date_send"

                \$FolderPath/send_tg.sh "\$TelgramBotToken" "\$ChatID_1" "\$message"
                echo "报告信息已发出..."
                echo "时间: \$current_date, 活动接口: \$interface, 月接收: \$diff_rx_day, 月发送: \$diff_tx_day"
                echo "----------------------------------------------------------------"
                month_rp=false
                month_sendtag=true
            fi

            if \$year_rp; then

                sleep 15

                # if cat /proc/version 2>/dev/null | grep -q -E -i "openwrt"; then
                    current_year=\$(date +'%Y')
                    previous_year=\$((current_year - 1))
                    last_year="\$previous_year"
                # else
                #     last_year=\$(date -d "1 year ago" +%Y)
                # fi

                ov_diff_rx_year=\$(Remove_B "\$ov_diff_rx_year")
                ov_diff_tx_year=\$(Remove_B "\$ov_diff_tx_year")

                message="\${last_year}年🧧总流量报告 📈"$'\n'
                message+="主机名: \$hostname_show 接口: \$show_interfaces"$'\n'
                message+="🧧接收: \${ov_diff_rx_year}  🧧发送: \${ov_diff_tx_year}"$'\n'
                message+="───────────────"$'\n'
                message+="总接收: \${all_rx}  总发送: \${all_tx}"$'\n'
                message+="设置流量上限: \${FlowThresholdMAX_U}🔒"$'\n'
                message+="使用⬇️: \$all_rx_progress \$all_rx_ratio"$'\n'
                message+="使用⬆️: \$all_tx_progress \$all_tx_ratio"$'\n'
                if [[ -n "\$uptimeshow" ]]; then
                    message+="\$uptimeshow"$'\n'
                fi
                if [[ -n "\$wanIPshow" ]]; then
                    message+="\$wanIPshow"$'\n'
                fi
                message+="服务器时间: \$current_date_send"

                \$FolderPath/send_tg.sh "\$TelgramBotToken" "\$ChatID_1" "\$message"
                echo "报告信息已发出..."
                echo "年报告信息:"
                echo "时间: \$current_date, 活动接口: \$interface, 年接收: \$diff_rx_year, 年发送: \$diff_tx_year"
                echo "----------------------------------------------------------------"
                year_rp=false
                year_sendtag=true
            fi
        fi
    fi
    for interface in "\${interfaces[@]}"; do
        interface_nodot=\${interface//./_}
        echo "prev_day_rx_bytes[\$interface_nodot]: \${prev_day_rx_bytes[\$interface_nodot]}"
        echo "prev_day_tx_bytes[\$interface_nodot]: \${prev_day_tx_bytes[\$interface_nodot]}"
    done
    echo "活动接口: \$show_interfaces  接收总流量: \$all_rx_mb 发送总流量: \$all_tx_mb"
    echo "活动接口: \$show_interfaces  接收日流量: \$diff_rx_day  发送日流量: \$diff_tx_day 报告时间: $hour_rp 时 $minute_rp 分"
    echo "活动接口: \$show_interfaces  接收月流量: \$diff_rx_month  发送月流量: \$diff_tx_month 报告时间: $hour_rp 时 $minute_rp 分"
    echo "活动接口: \$show_interfaces  接收年流量: \$diff_rx_year  发送年流量: \$diff_tx_year 报告时间: $hour_rp 时 $minute_rp 分"
    echo "报告模式: \$StatisticsMode_RP"
    echo "当前时间: \$(date)"
    echo "------------------------------------------------------"
done
EOF
    chmod +x $FolderPath/tg_flrp.sh
    killpid "tg_flrp.sh"
    nohup $FolderPath/tg_flrp.sh > $FolderPath/tg_flrp.log 2>&1 &
    delcrontab "$FolderPath/tg_flrp.sh"
    addcrontab "@reboot nohup $FolderPath/tg_flrp.sh > $FolderPath/tg_flrp.log 2>&1 &"
    if [ "$mute" == "false" ]; then
        send_time=$(echo $(date +%s%N) | cut -c 16-)
        message="流量定时报告设置成功 ⚙️"$'\n'"主机名: $hostname_show"$'\n'"报告接口: $show_interfaces_RP"$'\n'"报告模式: $StatisticsMode_RP"$'\n'"报告时间: 每天 $hour_rp 时 $minute_rp 分📈"
        $FolderPath/send_tg.sh "$TelgramBotToken" "$ChatID_1" "$message" "flrp" "$send_time" &
        (sleep 15 && $FolderPath/del_lm_tg.sh "$TelgramBotToken" "$ChatID_1" "flrp" "$send_time") &
        sleep 1
        # getpid "send_tg.sh"
        # flrp_pid="$tg_pid"
        flrp_pid=$(getpid "send_tg.sh")
    fi
    tips="$Tip 流量定时报告设置成功, 报告时间: 每天 $hour_rp 时 $minute_rp 分 ($input_time)"
}
