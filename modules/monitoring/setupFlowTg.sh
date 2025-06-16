#!/usr/bin/env bash


# 设置流量报警
SetupFlow_TG() {
    if [ ! -z "${flow_pid:-}" ] && pgrep -a '' | grep -Eq "^\s*$flow_pid\s" > /dev/null; then
        tips="$Err PID(${GR}$flow_pid${NC}) 正在发送中,请稍后..."
        return 1
    fi
    if [[ -z "${TelgramBotToken}" || -z "${ChatID_1}" ]]; then
        tips="$Err 参数丢失, 请设置后再执行 (先执行 ${GR}0${NC} 选项)."
        return 1
    fi
    if [ "$autorun" == "false" ]; then
        echo -en "请输入 流量报警阈值 ${GR}数字 + MB/GB/TB${NC} (回车跳过修改): "
        read -er threshold
    else
        if [ ! -z "$FlowThreshold" ]; then
            threshold=$FlowThreshold
        else
            threshold=$FlowThreshold_de
        fi
    fi
    if [ -z "$threshold" ]; then
        echo
        tips="$Tip 输入为空, 跳过操作."
        return 1
    fi
    if [[ $threshold =~ ^[0-9]+(\.[0-9])?$ ]] || [[ $threshold =~ ^[0-9]+(\.[0-9]+)?(M)$ ]] || [[ $threshold =~ ^[0-9]+(\.[0-9]+)?(MB)$ ]] || [[ $threshold =~ ^[0-9]+(\.[0-9]+)?(m)$ ]] || [[ $threshold =~ ^[0-9]+(\.[0-9]+)?(mb)$ ]]; then
        threshold=${threshold%M}
        threshold=${threshold%MB}
        threshold=${threshold%m}
        threshold=${threshold%mb}
        if awk -v value="$threshold" 'BEGIN { exit !(value >= 1024 * 1024) }'; then
            threshold=$(awk -v value="$threshold" 'BEGIN { printf "%.1f", value / (1024 * 1024) }')
            threshold="${threshold}TB"
        elif awk -v value="$threshold" 'BEGIN { exit !(value >= 1024) }'; then
            threshold=$(awk -v value="$threshold" 'BEGIN { printf "%.1f", value / 1024 }')
            threshold="${threshold}GB"
        else
            threshold="${threshold}MB"
        fi
        writeini "FlowThreshold" "$threshold"
    elif [[ $threshold =~ ^[0-9]+(\.[0-9]+)?(G)$ ]] || [[ $threshold =~ ^[0-9]+(\.[0-9]+)?(GB)$ ]] || [[ $threshold =~ ^[0-9]+(\.[0-9]+)?(g)$ ]] || [[ $threshold =~ ^[0-9]+(\.[0-9]+)?(gb)$ ]]; then
        threshold=${threshold%G}
        threshold=${threshold%GB}
        threshold=${threshold%g}
        threshold=${threshold%gb}
        if awk -v value="$threshold" 'BEGIN { exit !(value >= 1024) }'; then
            threshold=$(awk -v value="$threshold" 'BEGIN { printf "%.1f", value / 1024 }')
            threshold="${threshold}TB"
        else
            threshold="${threshold}GB"
        fi
        writeini "FlowThreshold" "$threshold"
    elif [[ $threshold =~ ^[0-9]+(\.[0-9]+)?(T)$ ]] || [[ $threshold =~ ^[0-9]+(\.[0-9]+)?(TB)$ ]] || [[ $threshold =~ ^[0-9]+(\.[0-9]+)?(t)$ ]] || [[ $threshold =~ ^[0-9]+(\.[0-9]+)?(tb)$ ]]; then
        threshold=${threshold%T}
        threshold=${threshold%TB}
        threshold=${threshold%t}
        threshold=${threshold%tb}
        threshold="${threshold}TB"
        writeini "FlowThreshold" "$threshold"
    else
        echo -e "$Err ${REB}输入无效${NC}, 报警阈值 必须是: 数字|数字MB/数字GB (%.1f) 的格式."
        tips="$Err ${REB}输入无效${NC}, 报警阈值 必须是: 数字|数字MB/数字GB (%.1f) 的格式."
        return 1
    fi
    if [ "$autorun" == "false" ]; then
        echo -en "请设置 流量上限 ${GR}数字 + MB/GB/TB${NC} (回车默认: $FlowThresholdMAX_de): "
        read -er threshold_max
    else
        if [ ! -z "$FlowThresholdMAX" ]; then
            threshold_max=$FlowThresholdMAX
        else
            threshold_max=$FlowThresholdMAX_de
        fi
    fi
    if [ ! -z "$threshold_max" ]; then
        if [[ $threshold_max =~ ^[0-9]+(\.[0-9])?$ ]] || [[ $threshold_max =~ ^[0-9]+(\.[0-9]+)?(M)$ ]] || [[ $threshold_max =~ ^[0-9]+(\.[0-9]+)?(MB)$ ]] || [[ $threshold_max =~ ^[0-9]+(\.[0-9]+)?(m)$ ]] || [[ $threshold_max =~ ^[0-9]+(\.[0-9]+)?(mb)$ ]]; then
            threshold_max=${threshold_max%M}
            threshold_max=${threshold_max%MB}
            threshold_max=${threshold_max%m}
            threshold_max=${threshold_max%mb}
            if awk -v value="$threshold_max" 'BEGIN { exit !(value >= 1024 * 1024) }'; then
                threshold_max=$(awk -v value="$threshold_max" 'BEGIN { printf "%.1f", value / (1024 * 1024) }')
                threshold_max="${threshold_max}TB"
            elif awk -v value="$threshold_max" 'BEGIN { exit !(value >= 1024) }'; then
                threshold_max=$(awk -v value="$threshold_max"_max 'BEGIN { printf "%.1f", value / 1024 }')
                threshold_max="${threshold_max}GB"
            else
                threshold_max="${threshold_max}MB"
            fi
            writeini "FlowThresholdMAX" "$threshold_max"
        elif [[ $threshold_max =~ ^[0-9]+(\.[0-9]+)?(G)$ ]] || [[ $threshold_max =~ ^[0-9]+(\.[0-9]+)?(GB)$ ]] || [[ $threshold_max =~ ^[0-9]+(\.[0-9]+)?(g)$ ]] || [[ $threshold_max =~ ^[0-9]+(\.[0-9]+)?(gb)$ ]]; then
            threshold_max=${threshold_max%G}
            threshold_max=${threshold_max%GB}
            threshold_max=${threshold_max%g}
            threshold_max=${threshold_max%gb}
            if awk -v value="$threshold_max" 'BEGIN { exit !(value >= 1024) }'; then
                threshold_max=$(awk -v value="$threshold_max"_max 'BEGIN { printf "%.1f", value / 1024 }')
                threshold_max="${threshold_max}TB"
            else
                threshold_max="${threshold_max}GB"
            fi
            writeini "FlowThresholdMAX" "$threshold_max"
        elif [[ $threshold_max =~ ^[0-9]+(\.[0-9]+)?(T)$ ]] || [[ $threshold_max =~ ^[0-9]+(\.[0-9]+)?(TB)$ ]] || [[ $threshold_max =~ ^[0-9]+(\.[0-9]+)?(t)$ ]] || [[ $threshold_max =~ ^[0-9]+(\.[0-9]+)?(tb)$ ]]; then
            threshold_max=${threshold_max%T}
            threshold_max=${threshold_max%TB}
            threshold_max=${threshold_max%t}
            threshold_max=${threshold_max%tb}
            threshold_max="${threshold_max}TB"
            writeini "FlowThresholdMAX" "$threshold_max"
        else
            echo -e "$Err ${REB}输入无效${NC}, 报警阈值 必须是: 数字|数字MB/数字GB (%.1f) 的格式."
            tips="$Err ${REB}输入无效${NC}, 报警阈值 必须是: 数字|数字MB/数字GB (%.1f) 的格式."
            return 1
        fi
    else
        echo
        writeini "FlowThresholdMAX" "$FlowThresholdMAX_de"
        echo -e "$Tip 输入为空, 默认最大流量上限为: $FlowThresholdMAX_de"
    fi
    if [ "$autorun" == "false" ]; then
        # interfaces_ST_0=$(ip -br link | awk '$2 == "UP" {print $1}' | grep -v "lo")
        # output=$(ip -br link)
        IFS=$'\n'
        count=1
        choice_array=()
        interfaces_ST=()
        w_interfaces_ST=()
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
            # if [[ $interfaces_ST_0 =~ $columns_1 ]]; then
            if [[ $interfaces_up =~ $columns_1 ]]; then
                printf "${GR}%d. %s${NC}\n" "$count" "$columns_2"
            else
                printf "${GR}%d. ${NC}%s\n" "$count" "$columns_1"
            fi
            ((count++))
        done
        echo -e "请选择编号进行统计, 例如统计1项和2项可输入: ${GR}1,2${NC} 或 ${GR}回车自动检测${NC}活跃接口:"
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
            #         interfaces_ST+=("${columns_1_array[index]}")
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
                interfaces_ST+=("${columns_1_array[index]}")
            done

            # for ((i = 0; i < ${#interfaces_ST[@]}; i++)); do
            #     w_interfaces_ST+="${interfaces_ST[$i]}"
            #     if ((i < ${#interfaces_ST[@]} - 1)); then
            #         w_interfaces_ST+=","
            #     fi
            # done
            w_interfaces_ST=$(sep_array interfaces_ST ",")
            # echo "确认选择接口: $w_interfaces_ST"
            writeini "interfaces_ST" "$w_interfaces_ST"
        else
            # IFS=',' read -ra interfaces_ST_de <<< "$interfaces_ST_de"
            # IFS=',' read -ra interfaces <<< "$(echo "$interfaces_ST_de" | tr ',' '\n' | sort -u | tr '\n' ',')"
            # IFS=',' read -ra interfaces <<< "$(echo "$interfaces_ST_de" | awk -v RS=, '!a[$1]++ {if (NR>1) printf ",%s", $0; else printf "%s", $0}')"
            # interfaces_ST=("${interfaces_ST_de[@]}")
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
            interfaces_ST=("${active_interfaces[@]}")
            # for ((i = 0; i < ${#interfaces_ST[@]}; i++)); do
            #     w_interfaces_ST+="${interfaces_ST[$i]}"
            #     if ((i < ${#interfaces_ST[@]} - 1)); then
            #         w_interfaces_ST+=","
            #     fi
            # done
            w_interfaces_ST=$(sep_array interfaces_ST ",")
            echo -e "$Tip 检测到活动的接口: $w_interfaces_ST"
            # echo "确认选择接口: $w_interfaces_ST"
            writeini "interfaces_ST" "$w_interfaces_ST"
        fi
    else
        if [ ! -z "${interfaces_ST+x}" ]; then
            interfaces_ST=("${interfaces_ST[@]}")
        else
            interfaces_ST=("${interfaces_ST_de[@]}")
        fi
        echo "interfaces_ST: $interfaces_ST"
    fi
    interfaces_ST=($(unique_array "${interfaces_ST[@]}")) # 去重处理
    show_interfaces_ST=$(sep_array interfaces_ST ",") # 加入分隔符
    # for ((i = 0; i < ${#interfaces_ST[@]}; i++)); do
    #     show_interfaces_ST+="${interfaces_ST[$i]}"
    #     if ((i < ${#interfaces_ST[@]} - 1)); then
    #         show_interfaces_ST+=","
    #     fi
    # done
    if [ "$autorun" == "false" ]; then
        read -e -p "请选择统计模式: 1.接口合计发送  2.接口单独发送 (回车默认为单独发送): " mode
        if [ "$mode" == "1" ]; then
            StatisticsMode_ST="OV"
        elif [ "$mode" == "2" ]; then
            StatisticsMode_ST="SE"
        else
            StatisticsMode_ST=$StatisticsMode_ST_de
        fi
        writeini "StatisticsMode_ST" "$StatisticsMode_ST"
    else
        if [ ! -z "$StatisticsMode_ST" ]; then
            StatisticsMode_ST=$StatisticsMode_ST
        else
            StatisticsMode_ST=$StatisticsMode_ST_de
        fi
    fi
    echo "统计模式为: $StatisticsMode_ST"

    source $ConfigFile
    FlowThreshold_UB=$FlowThreshold
    FlowThreshold_U=$(Remove_B "$FlowThreshold")
    if [[ $FlowThreshold == *MB ]]; then
        FlowThreshold=${FlowThreshold%MB}
        FlowThreshold=$(awk -v value=$FlowThreshold 'BEGIN { printf "%.1f", value }')
    elif [[ $FlowThreshold == *GB ]]; then
        FlowThreshold=${FlowThreshold%GB}
        FlowThreshold=$(awk -v value=$FlowThreshold 'BEGIN { printf "%.1f", value * 1024 }')
    elif [[ $FlowThreshold == *TB ]]; then
        FlowThreshold=${FlowThreshold%TB}
        FlowThreshold=$(awk -v value=$FlowThreshold 'BEGIN { printf "%.1f", value * 1024 * 1024 }')
    fi
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
    cat <<EOF > $FolderPath/tg_flow.sh
#!/bin/bash

$(declare -f create_progress_bar)
$(declare -f ratioandprogress)
progress=""
ratio=""
$(declare -f Bytes_B_TGMK)
$(declare -f TG_M_removeXB)
$(declare -f Remove_B)
$(declare -f redup_array)
$(declare -f clear_array)
$(declare -f sep_array)
$(declare -f Checkpara)

FolderPath="$FolderPath"
if [ ! -d "\$FolderPath" ]; then
    mkdir -p "\$FolderPath"
fi
ConfigFile="$ConfigFile"
source \$ConfigFile &>/dev/null
Checkpara "hostname_show" "$hostname_show"
Checkpara "ProxyURL" "$ProxyURL"
Checkpara "StatisticsMode_ST" "$StatisticsMode_ST"
Checkpara "SendUptime" "$SendUptime"
Checkpara "SendIP" "$SendIP"
Checkpara "GetIP46" "$GetIP46"
Checkpara "GetIPURL" "$GetIPURL"
Checkpara "SendPrice" "$SendPrice"
Checkpara "GetPriceType" "$GetPriceType"
Checkpara "FlowThreshold" "$FlowThreshold"
Checkpara "FlowThresholdMAX" "$FlowThresholdMAX"
Checkpara "interfaces_ST" "$interfaces_ST"

FlowThreshold_U=\$(Remove_B "\$FlowThreshold")
FlowThreshold=\$(TG_M_removeXB "\$FlowThreshold")
FlowThresholdMAX_U=\$(Remove_B "\$FlowThresholdMAX")
FlowThresholdMAX=\$(TG_M_removeXB "\$FlowThresholdMAX")

get_price() {
    local url="\${ProxyURL}https://api.coingecko.com/api/v3/simple/price?ids=\${1}&vs_currencies=usd"
    local price=\$(curl -s "\$url" | sed 's/[^0-9.]*//g')
    echo "\$price"
}

tt=10
duration=0
StatisticsMode_ST="\$StatisticsMode_ST"

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
if [ "\$SendPrice" == "true" ]; then
    SendPrice="true"
else
    SendPrice="false"
fi

echo "FlowThreshold: \$FlowThreshold  FlowThresholdMAX: \$FlowThresholdMAX"
THRESHOLD_BYTES=\$(awk "BEGIN {print \$FlowThreshold * 1024 * 1024}")
THRESHOLD_BYTES_MAX=\$(awk "BEGIN {print \$FlowThresholdMAX * 1024 * 1024}")

# sci_notation_regex='^[0-9]+(\.[0-9]+)?[eE][+-]?[0-9]+$'
# if [[ \$THRESHOLD_BYTES =~ \$sci_notation_regex ]]; then
#     THRESHOLD_BYTES=\$(printf "%.0f" \$THRESHOLD_BYTES)
# fi
# if [[ \$THRESHOLD_BYTES_MAX =~ \$sci_notation_regex ]]; then
#     THRESHOLD_BYTES_MAX=\$(printf "%.0f" \$THRESHOLD_BYTES_MAX)
# fi

THRESHOLD_BYTES=\$(printf "%.0f" \$THRESHOLD_BYTES)
THRESHOLD_BYTES_MAX=\$(printf "%.0f" \$THRESHOLD_BYTES_MAX)
echo "==================================================================="
echo "THRESHOLD_BYTES: \$THRESHOLD_BYTES  THRESHOLD_BYTES_MAX: \$THRESHOLD_BYTES_MAX"

# interfaces_up=\$(ip -br link | awk '\$2 == "UP" {print \$1}' | grep -v "lo")
# interfaces_all=\$(ip -br link | awk '{print \$1}' | tr '\n' ' ')
# declare -a interfaces=(\$interfaces_get)
# IFS=',' read -ra interfaces <<< "\$interfaces_ST"
# 去重并且分割字符串为数组
# IFS=',' read -ra interfaces <<< "\$(echo "\$interfaces_ST" | tr ',' '\n' | sort -u | tr '\n' ',')"
# 去重并且保持原有顺序，分割字符串为数组
# IFS=',' read -ra interfaces <<< "$(echo "$interfaces_ST" | awk -v RS=, '!a[$1]++ {if (NR>1) printf ",%s", $0; else printf "%s", $0}')"
IFS=',' read -ra interfaces <<< "\$(echo "\$interfaces_ST" | awk -v RS=, '!a[\$1]++ {if (NR>1) printf ",%s", \$0; else printf "%s", \$0}')"


echo "统计接口: \${interfaces[@]}"
for ((i = 0; i < \${#interfaces[@]}; i++)); do
    echo "\$((i+1)): \${interfaces[i]}"
done
# for ((i = 0; i < \${#interfaces[@]}; i++)); do
#     show_interfaces+="\${interfaces[\$i]}"
#     if ((i < \${#interfaces[@]} - 1)); then
#         show_interfaces+=","
#     fi
# done
show_interfaces=\$(sep_array interfaces ",")
# 如果接口名称中包含 '@' 或 ':'，则仅保留 '@' 或 ':' 之前的部分
# for ((i=0; i<\${#interfaces[@]}; i++)); do
#     interface=\${interfaces[\$i]%@*}
#     interface=\${interface%:*}
#     interfaces[\$i]=\$interface
# done
interfaces=(\$(clear_array "\${interfaces[@]}"))
echo "纺计接口(处理后): \${interfaces[@]}"

# 之前使用的是下面代码，统计网速时采用UP标记的接口，由于有些特殊名称的接口容易导致统计网速时出错，后改为与检测流量的接口相同.
interfaces_up=(\${interfaces[@]})

# interfaces_up=\$(ip -br link | awk '\$2 == "UP" {print \$1}' | grep -v "lo")
# 如果接口名称中包含 '@' 或 ':'，则仅保留 '@' 或 ':' 之前的部分
# for ((i=0; i<\${#interfaces_up[@]}; i++)); do
#     interface=\${interfaces_up[\$i]%@*}
#     interface=\${interface%:*}
#     interfaces_up[\$i]=\$interface
# done
# interfaces_up=(\$(redup_array "\${interfaces_up[@]}"))
# interfaces_up=(\$(clear_array "\${interfaces_up[@]}"))
echo "纺计网速接口(处理后): \${interfaces_up[@]}"

# 定义数组
declare -A prev_rx_bytes
declare -A prev_tx_bytes
declare -A prev_rx_bytes_T
declare -A prev_tx_bytes_T
declare -A tt_prev_rx_bytes_T
declare -A tt_prev_tx_bytes_T
declare -A current_rx_bytes
declare -A current_tx_bytes
declare -A INTERFACE_RT_RX_B
declare -A INTERFACE_RT_TX_B

# 初始化接口流量数据
source \$ConfigFile &>/dev/null
for interface in "\${interfaces[@]}"; do
    interface_nodot=\${interface//./_}
    INTERFACE_RT_RX_B[\$interface_nodot]=\${INTERFACE_RT_RX_B[\$interface_nodot]}
    echo "读取: INTERFACE_RT_RX_B[\$interface_nodot]: \${INTERFACE_RT_RX_B[\$interface_nodot]}"
    INTERFACE_RT_TX_B[\$interface_nodot]=\${INTERFACE_RT_TX_B[\$interface_nodot]}
    echo "读取: INTERFACE_RT_TX_B[\$interface_nodot]: \${INTERFACE_RT_TX_B[\$interface_nodot]}"
done

# 循环检查
sendtag=true
tt_prev=false
while true; do

    source \$ConfigFile &>/dev/null
    Checkpara "hostname_show" "$hostname_show"
    Checkpara "ProxyURL" "$ProxyURL"
    Checkpara "StatisticsMode_ST" "$StatisticsMode_ST"
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
    if \$sendtag; then
        echo "发送 \$interface 前只执行一次."

        if ! \$tt_prev; then
            for interface in "\${interfaces[@]}"; do
                interface_nodot=\${interface//./_}
                prev_rx_bytes_T[\$interface_nodot]=\${prev_rx_bytes[\$interface_nodot]}
                prev_tx_bytes_T[\$interface_nodot]=\${prev_tx_bytes[\$interface_nodot]}
            done
            ov_prev_rx_bytes_T=\$ov_prev_rx_bytes
            ov_prev_tx_bytes_T=\$ov_prev_tx_bytes
        else
            for interface in "\${interfaces[@]}"; do
                interface_nodot=\${interface//./_}
                prev_rx_bytes_T[\$interface_nodot]=\${tt_prev_rx_bytes_T[\$interface_nodot]}
                prev_tx_bytes_T[\$interface_nodot]=\${tt_prev_tx_bytes_T[\$interface_nodot]}
            done
            ov_prev_rx_bytes_T=\$tt_ov_prev_rx_bytes_T
            ov_prev_tx_bytes_T=\$tt_ov_prev_tx_bytes_T
        fi

    fi
    sendtag=false
    echo "上一次发送前记录 (为了避免在发送过程中未统计到而造成数据遗漏):"
    echo "SE模式: rx_bytes[\$interface_nodot]: \${prev_rx_bytes_T[\$interface_nodot]} tx_bytes[\$interface_nodot]: \${prev_tx_bytes_T[\$interface_nodot]}"
    echo "OV模式: ov_rx_bytes: \$ov_prev_rx_bytes_T ov_tx_bytes: \$ov_prev_tx_bytes_T"

    sp_ov_prev_rx_bytes=0
    sp_ov_prev_tx_bytes=0
    for interface in "\${interfaces_up[@]}"; do
        interface_nodot=\${interface//./_}
        prev_rx_bytes[\$interface_nodot]=\$(ip -s link show \$interface | awk '/RX:/ { getline; print \$1 }')
        prev_tx_bytes[\$interface_nodot]=\$(ip -s link show \$interface | awk '/TX:/ { getline; print \$1 }')
        sp_ov_prev_rx_bytes=\$((sp_ov_prev_rx_bytes + prev_rx_bytes[\$interface_nodot]))
        sp_ov_prev_tx_bytes=\$((sp_ov_prev_tx_bytes + prev_tx_bytes[\$interface_nodot]))
    done

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
    sp_ov_current_rx_bytes=0
    sp_ov_current_tx_bytes=0
    for interface in "\${interfaces_up[@]}"; do
        interface_nodot=\${interface//./_}
        sp_current_rx_bytes[\$interface_nodot]=\$(ip -s link show \$interface | awk '/RX:/ { getline; print \$1 }')
        sp_current_tx_bytes[\$interface_nodot]=\$(ip -s link show \$interface | awk '/TX:/ { getline; print \$1 }')
        sp_ov_current_rx_bytes=\$((sp_ov_current_rx_bytes + sp_current_rx_bytes[\$interface_nodot]))
        sp_ov_current_tx_bytes=\$((sp_ov_current_tx_bytes + sp_current_tx_bytes[\$interface_nodot]))
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
    for interface in "\${interfaces[@]}"; do
        interface_nodot=\${interface//./_}
        echo "NO.\$nline ----------------------------------------- interface: \$interface"

        # 计算差值
        rx_diff_bytes=\$((current_rx_bytes[\$interface_nodot] - prev_rx_bytes_T[\$interface_nodot]))
        tx_diff_bytes=\$((current_tx_bytes[\$interface_nodot] - prev_tx_bytes_T[\$interface_nodot]))
        ov_rx_diff_bytes=\$((ov_current_rx_bytes - ov_prev_rx_bytes_T))
        ov_tx_diff_bytes=\$((ov_current_tx_bytes - ov_prev_tx_bytes_T))

        # 计算网速
        ov_rx_diff_speed=\$((sp_ov_current_rx_bytes - sp_ov_prev_rx_bytes))
        ov_tx_diff_speed=\$((sp_ov_current_tx_bytes - sp_ov_prev_tx_bytes))
        # rx_speed=\$(awk "BEGIN { speed = \$ov_rx_diff_speed / (\$tt * 1024); if (speed >= 1024) { printf \"%.1fMB\", speed/1024 } else { printf \"%.1fKB\", speed } }")
        # tx_speed=\$(awk "BEGIN { speed = \$ov_tx_diff_speed / (\$tt * 1024); if (speed >= 1024) { printf \"%.1fMB\", speed/1024 } else { printf \"%.1fKB\", speed } }")
        rx_speed=\$(awk -v v1="\$ov_rx_diff_speed" -v t1="\$tt" \
            'BEGIN {
                speed = v1 / (t1 * 1024)
                if (speed >= (1024 * 1024)) {
                    printf "%.1fGB", speed/(1024 * 1024)
                } else if (speed >= 1024) {
                    printf "%.1fMB", speed/1024
                } else {
                    printf "%.1fKB", speed
                }
            }')
        tx_speed=\$(awk -v v1="\$ov_tx_diff_speed" -v t1="\$tt" \
            'BEGIN {
                speed = v1 / (t1 * 1024)
                if (speed >= (1024 * 1024)) {
                    printf "%.1fGB", speed/(1024 * 1024)
                } else if (speed >= 1024) {
                    printf "%.1fMB", speed/1024
                } else {
                    printf "%.1fKB", speed
                }
            }')
        rx_speed=\$(Remove_B "\$rx_speed")
        tx_speed=\$(Remove_B "\$tx_speed")

        # 总流量百分比计算
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

        # 调试使用(tt秒的流量增量)
        echo "RX_diff(BYTES): \$rx_diff_bytes TX_diff(BYTES): \$tx_diff_bytes   SE模式下达到 \$THRESHOLD_BYTES 时报警"
        # 调试使用(叠加流量增量)
        echo "OV_RX_diff(BYTES): \$ov_rx_diff_bytes OV_TX_diff(BYTES): \$ov_tx_diff_bytes   OV模式下达到 \$THRESHOLD_BYTES 时报警"
        # 调试使用(TT前记录的流量)
        echo "Prev_rx_bytes_T(BYTES): \${prev_rx_bytes_T[\$interface_nodot]} Prev_tx_bytes_T(BYTES): \${prev_tx_bytes_T[\$interface_nodot]}"
        # # 调试使用(持续的流量增加)
        # echo "Current_RX(BYTES): \${current_rx_bytes[\$interface_nodot]} Current_TX(BYTES): \${current_tx_bytes[\$interface_nodot]}"
        # 调试使用(叠加持续的流量增加)
        echo "OV_Current_RX(BYTES): \$ov_current_rx_bytes OV_Current_TX(BYTES): \$ov_current_tx_bytes"
        # 调试使用(网速)
        echo "rx_speed: \$rx_speed  tx_speed: \$tx_speed"
        # 状态
        echo "统计模式: \$StatisticsMode_ST   发送在线时长: \$SendUptime   发送IP: \$SendIP   发送货币报价: \$SendPrice"

        # 检查是否超过阈值
        if [ "\$StatisticsMode_ST" == "SE" ]; then

            rx_diff_bytes=\$(printf "%.0f" \$rx_diff_bytes)
            tx_diff_bytes=\$(printf "%.0f" \$tx_diff_bytes)

            # threshold_reached=\$(awk -v rx_diff="\$rx_diff" -v tx_diff="\$tx_diff" -v threshold="\$THRESHOLD_BYTES" 'BEGIN {print (rx_diff >= threshold) || (tx_diff >= threshold) ? 1 : 0}')
            # if [ "\$threshold_reached" -eq 1 ]; then

            if [ \$rx_diff_bytes -ge \$THRESHOLD_BYTES ] || [ \$tx_diff_bytes -ge \$THRESHOLD_BYTES ]; then

                rx_diff=\$(Bytes_B_TGMK "\$rx_diff_bytes")
                tx_diff=\$(Bytes_B_TGMK "\$tx_diff_bytes")
                rx_diff=\$(Remove_B "\$rx_diff")
                tx_diff=\$(Remove_B "\$tx_diff")

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
                echo "wanIPshow: \$wanIPshow"
                # 获取货币报价
                if \$SendPrice; then
                    priceshow=\$(get_price "\$GetPriceType")
                    if [[ -z \$priceshow || \$priceshow == *"429"* ]]; then
                        # 如果priceshow为空或包含"429"，则表示获取失败
                        priceshow=""
                    fi
                else
                    priceshow=""
                fi
                echo "priceshow: \$priceshow"

                message="流量到达阈值🧭 > \${FlowThreshold_U}❗️  \$priceshow"$'\n'
                message+="主机名: \$hostname_show 接口: \$interface"$'\n'
                message+="已接收: \${rx_diff}  已发送: \${tx_diff}"$'\n'
                message+="───────────────"$'\n'
                message+="总接收: \${all_rx}  总发送: \${all_tx}"$'\n'
                message+="设置流量上限: \${FlowThresholdMAX_U}🔒"$'\n'
                message+="使用⬇️: \$all_rx_progress \$all_rx_ratio"$'\n'
                message+="使用⬆️: \$all_tx_progress \$all_tx_ratio"$'\n'
                message+="网络⬇️: \${rx_speed}/s  网络⬆️: \${tx_speed}/s"$'\n'
                if [[ -n "\$uptimeshow" ]]; then
                    message+="\$uptimeshow"$'\n'
                fi
                if [[ -n "\$wanIPshow" ]]; then
                    message+="\$wanIPshow"$'\n'
                fi
                message+="服务器时间: \$current_date_send"

                \$FolderPath/send_tg.sh "\$TelgramBotToken" "\$ChatID_1" "\$message"
                echo "报警信息已发出..."

                # 更新前一个状态的流量数据
                sendtag=true
            fi
        fi
        nline=\$((nline + 1))
    done
    if [ "\$StatisticsMode_ST" == "OV" ]; then

        ov_rx_diff_bytes=\$(printf "%.0f" \$ov_rx_diff_bytes)
        ov_tx_diff_bytes=\$(printf "%.0f" \$ov_tx_diff_bytes)

        if [ \$ov_rx_diff_bytes -ge \$THRESHOLD_BYTES ] || [ \$ov_tx_diff_bytes -ge \$THRESHOLD_BYTES ]; then

            ov_rx_diff=\$(Bytes_B_TGMK "\$ov_rx_diff_bytes")
            ov_tx_diff=\$(Bytes_B_TGMK "\$ov_tx_diff_bytes")
            ov_rx_diff=\$(Remove_B "\$ov_rx_diff")
            ov_tx_diff=\$(Remove_B "\$ov_tx_diff")

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
            echo "wanIPshow: \$wanIPshow"
            # 获取货币报价
            if \$SendPrice; then
                priceshow=\$(get_price "\$GetPriceType")
                if [[ -z \$priceshow || \$priceshow == *"429"* ]]; then
                    # 如果priceshow为空或包含"429"，则表示获取失败
                    priceshow=""
                fi
            else
                priceshow=""
            fi
            echo "priceshow: \$priceshow"

            message="流量到达阈值🧭 > \${FlowThreshold_U}❗️  \$priceshow"$'\n'
            message+="主机名: \$hostname_show 接口: \$show_interfaces"$'\n'
            message+="已接收: \${ov_rx_diff}  已发送: \${ov_tx_diff}"$'\n'
            message+="───────────────"$'\n'
            message+="总接收: \${all_rx}  总发送: \${all_tx}"$'\n'
            message+="设置流量上限: \${FlowThresholdMAX_U}🔒"$'\n'
            message+="使用⬇️: \$all_rx_progress \$all_rx_ratio"$'\n'
            message+="使用⬆️: \$all_tx_progress \$all_tx_ratio"$'\n'
            message+="网络⬇️: \${rx_speed}/s  网络⬆️: \${tx_speed}/s"$'\n'
            if [[ -n "\$uptimeshow" ]]; then
                message+="\$uptimeshow"$'\n'
            fi
            if [[ -n "\$wanIPshow" ]]; then
                message+="\$wanIPshow"$'\n'
            fi
            message+="服务器时间: \$current_date_send"

            \$FolderPath/send_tg.sh "\$TelgramBotToken" "\$ChatID_1" "\$message"
            echo "报警信息已发出..."

            # 更新前一个状态的流量数据
            sendtag=true
        fi
    fi
    if [ "\$StatisticsMode_ST" != "SE" ] && [ "\$StatisticsMode_ST" != "OV" ]; then
        echo "StatisticsMode_ST Err!!! \$StatisticsMode_ST"
    fi
done
EOF
    chmod +x $FolderPath/tg_flow.sh
    # pkill tg_flow.sh > /dev/null 2>&1 &
    # pkill tg_flow.sh > /dev/null 2>&1 &
    # kill $(ps | grep '[t]g_flow.sh' | awk '{print $1}')
    killpid "tg_flow.sh"
    nohup $FolderPath/tg_flow.sh > $FolderPath/tg_flow.log 2>&1 &
    delcrontab "$FolderPath/tg_flow.sh"
    addcrontab "@reboot nohup $FolderPath/tg_flow.sh > $FolderPath/tg_flow.log 2>&1 &"
#     cat <<EOF > $FolderPath/tg_interface_re.sh
#     # 内容已经移位.
# EOF
    # # 此为单独计算网速的子脚本（暂未启用）
    # chmod +x $FolderPath/tg_interface_re.sh
    # pkill -f tg_interface_re.sh > /dev/null 2>&1 &
    # pkill -f tg_interface_re.sh > /dev/null 2>&1 &
    # kill $(ps | grep '[t]g_interface_re.sh' | awk '{print $1}')
    # nohup $FolderPath/tg_interface_re.sh > $FolderPath/tg_interface_re.log 2>&1 &
    ##############################################################################
#     cat <<EOF > /etc/systemd/system/tg_interface_re.service
# [Unit]
# Description=tg_interface_re
# DefaultDependencies=no
# Before=shutdown.target

# [Service]
# Type=oneshot
# ExecStart=$FolderPath/tg_interface_re.sh
# TimeoutStartSec=0

# [Install]
# WantedBy=shutdown.target
# EOF
#     systemctl enable tg_interface_re.service > /dev/null
    if [ "$mute" == "false" ]; then
        send_time=$(echo $(date +%s%N) | cut -c 16-)
        message="流量报警设置成功 ⚙️"$'\n'"主机名: $hostname_show"$'\n'"检测接口: $show_interfaces_ST"$'\n'"检测模式: $StatisticsMode_ST"$'\n'"当流量达阈值 $FlowThreshold_UB 时将收到通知💡"
        $FolderPath/send_tg.sh "$TelgramBotToken" "$ChatID_1" "$message" "flow" "$send_time" &
        (sleep 15 && $FolderPath/del_lm_tg.sh "$TelgramBotToken" "$ChatID_1" "flow" "$send_time") &
        sleep 1
        # getpid "send_tg.sh"
        # flow_pid="$tg_pid"
        flow_pid=$(getpid "send_tg.sh")
    fi
    tips="$Tip 流量 通知已经设置成功, 当流量使用达 ${GR}$FlowThreshold_UB${NC} 时发出通知."
}
