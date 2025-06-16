#!/usr/bin/env bash


# 设置ini参数文件
SetupIniFile() {
    # 设置电报机器人参数
    autochoice=5
    divline
    echo -e "$Tip 默认机器人: ${GR}@vpskeeperbot${NC} 使用前必须添加并点击 ${GR}/start${NC}"
    while true; do
        source $ConfigFile
        if [ "$autorun" == "true" ]; then
            if [ "$autochoice" = "10" ]; then
                choice="*"
            else
                choice="$autochoice"
                ((autochoice++))
            fi
        else
            divline
            echo -e "${GR}1${NC}. BOT Token\t\t${GR}$TelgramBotToken${NC}"
            echo -e "${GR}2${NC}. CHAT ID\t\t${GR}$ChatID_1${NC}"
            echo -e "${GR}3${NC}. CPU检测工具\t\t${GR}$CPUTools${NC}"
            echo -e "${GR}4${NC}. 设置流量上限\t\t${GR}$FlowThresholdMAX${NC}"
            if [ "$SHUTDOWN_RT" == "true" ]; then
                settag="${GR}已启动${NC}"
            else
                settag=""
            fi
            echo -e "${GR}5${NC}. 设置关机记录流量\t$settag"
            if [ ! -z "$ProxyURL" ]; then
                settag="${GR}已启动${NC} | ${GR}$ProxyURL${NC}"
            else
                settag=""
            fi
            echo -e "${GR}6${NC}. 设置TG代理 (${RE}国内${NC})\t$settag"
            if [ "$SendUptime" == "true" ]; then
                # read uptime idle_time < /proc/uptime
                # uptime=${uptime%.*}
                # days=$((uptime/86400))
                # hours=$(( (uptime%86400)/3600 ))
                # minutes=$(( (uptime%3600)/60 ))
                # seconds=$((uptime%60))
                read uptime idle_time < /proc/uptime
                uptime=${uptime%.*}
                days=$(awk -v up="$uptime" 'BEGIN{print int(up/86400)}')
                hours=$(awk -v up="$uptime" 'BEGIN{print int((up%86400)/3600)}')
                minutes=$(awk -v up="$uptime" 'BEGIN{print int((up%3600)/60)}')
                seconds=$(awk -v up="$uptime" 'BEGIN{print int(up%60)}')
                uptimeshow="系统已运行: $days 日 $hours 时 $minutes 分 $seconds 秒"
                settag="${GR}已启动${NC} | ${GR}$uptimeshow${NC}"
            else
                settag=""
            fi
            echo -e "${GR}7${NC}. 设置发送在线时长\t$settag"
            if [ "$SendIP" == "true" ] && [ ! -z "$GetIPAddress" ]; then
                settag="${GR}已启动${NC} | ${GR}$GetIPAddress${NC}"
            else
                settag=""
            fi
            echo -e "${GR}8${NC}. 设置发送IP地址\t$settag"
            if [ "$SendPrice" == "true" ]; then
                settag="${GR}已启动${NC} | ${GR}$GetPriceType${NC}"
            else
                settag=""
            fi
            echo -e "${GR}9${NC}. 设置发送货币报价\t$settag"
            echo -e "${GR}回车${NC}. 退出设置"
            divline
            read -e -p "请输入对应的序号: " choice
        fi
        case $choice in
            1)
                # 设置BOT Token
                echo -e "$Tip ${REB}BOT Token${NC} 获取方法: 在 Telgram 中添加机器人 @BotFather, 输入: /newbot"
                divline
                if [ "$TelgramBotToken" != "" ]; then
                    echo -e "当前${GR}[BOT Token]${NC}: $TelgramBotToken"
                else
                    echo -e "当前${GR}[BOT Token]${NC}: 空"
                fi
                divline
                read -e -p "请输入 BOT Token (回车跳过修改 / 输入 R 使用默认机器人): " bottoken
                if [ "$bottoken" == "r" ] || [ "$bottoken" == "R" ]; then
                    writeini "TelgramBotToken" "6718888288:AAG5aVWV4FCmS0ItoPy1-3KkhdNg8eym5AM"
                    UN_ALL
                    tips="$Tip 接收信息已经改动, 请重新设置所有通知."
                    break
                fi
                if [ ! -z "$bottoken" ]; then
                    writeini "TelgramBotToken" "$bottoken"
                    UN_ALL
                    tips="$Tip 接收信息已经改动, 请重新设置所有通知."
                    break
                else
                    echo -e "$Tip 输入为空, 跳过操作."
                    tips=""
                fi
                ;;
            2)
                # 设置Chat ID
                echo -e "$Tip ${REB}Chat ID${NC} 获取方法: 在 Telgram 中添加机器人 @userinfobot, 点击或输入: /start"
                divline
                if [ "$ChatID_1" != "" ]; then
                    echo -e "当前${GR}[CHAT ID]${NC}: $ChatID_1"
                else
                    echo -e "当前${GR}[CHAT ID]${NC}: 空"
                fi
                divline
                read -e -p "请输入 Chat ID (回车跳过修改): " cahtid
                if [ ! -z "$cahtid" ]; then
                    if [[ $cahtid =~ ^[0-9]+$ ]]; then
                        writeini "ChatID_1" "$cahtid"
                        UN_ALL
                        tips="$Tip 接收信息已经改动, 请重新设置所有通知."
                        break
                    else
                        echo -e "$Err ${REB}输入无效${NC}, Chat ID 必须是数字, 跳过操作."
                    fi
                else
                    echo -e "$Tip 输入为空, 跳过操作."
                    tips=""
                fi
                ;;
            3)
                # 设置CPU检测工具
                if cat /proc/version 2>/dev/null | grep -q -E -i "openwrt"; then
                    tips="$Tip OpenWRT 系统只能使用默认的 top 工具."
                    break
                else
                    echo -e "$Tip 请选择 ${REB}CPU 检测工具${NC}: 1.top(系统自带) 2.sar(更专业) 3.top+sar"
                    divline
                    if [ "$CPUTools" != "" ]; then
                        echo -e "当前${GR}[CPU 检测工具]${NC}: $CPUTools"
                    else
                        echo -e "当前${GR}[CPU 检测工具]${NC}: 空"
                    fi
                    divline
                    read -e -p "请输入序号 (默认采用 1.top / 回车跳过修改): " choice
                    if [ ! -z "$choice" ]; then
                        if [ "$choice" == "1" ]; then
                            CPUTools="top"
                            writeini "CPUTools" "$CPUTools"
                        elif [ "$choice" == "2" ]; then
                            CPUTools="sar"
                            writeini "CPUTools" "$CPUTools"
                        elif [ "$choice" == "3" ]; then
                            CPUTools="top_sar"
                            writeini "CPUTools" "$CPUTools"
                        fi
                    else
                        echo -e "$Tip 输入为空, 跳过操作."
                        tips=""
                    fi
                fi
                ;;
            4)
                # 设置流量上限（仅参考）
                echo -en "请设置 流量上限 ${GR}数字 + MB/GB/TB${NC} (回车默认: $FlowThresholdMAX_de): "
                read -er threshold_max
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
                        echo -e "$Err ${REB}输入无效${NC}, 报警阈值 必须是: 数字|数字MB/数字GB (%.1f) 的格式(支持1位小数), 跳过操作."
                        return 1
                    fi
                else
                    echo
                    writeini "FlowThresholdMAX" "$FlowThresholdMAX_de"
                    echo -e "$Tip 输入为空, 默认最大流量上限为: $FlowThresholdMAX_de"
                fi
                ;;
            5)
                # 设置关机记录流量
                if [ "$autorun" == "true" ]; then
                    choice=""
                else
                    if cat /proc/version 2>/dev/null | grep -q -E -i "openwrt"; then
                        tips="$Err OpenWRT 系统暂不支持."
                        break
                    fi
                    if ! command -v systemd &>/dev/null; then
                        tips="$Err 系统未检测到 \"systemd\" 程序, 无法设置关机通知."
                        break
                    fi
                    if [[ -z "${TelgramBotToken}" || -z "${ChatID_1}" ]]; then
                        tips="$Err 参数丢失, 请设置后再执行 (先执行 ${GR}0${NC} 选项)."
                        break
                    fi
                    read -e -p "请选择是否开启 设置关机记录流量  Y.开启  回车.关闭(删除记录): " choice
                fi
                if [ "$choice" == "y" ] || [ "$choice" == "Y" ]; then
                    cat <<EOF > $FolderPath/tg_shutdown_rt.sh
#!/bin/bash

ConfigFile=$ConfigFile

$(declare -f writeini)
$(declare -f redup_array)
$(declare -f clear_array)
$(declare -f caav)

declare -A INTERFACE_RT_RX_B
declare -A INTERFACE_RT_TX_B
declare -A INTERFACE_RT_RX_PB
declare -A INTERFACE_RT_TX_PB
declare -a interfaces_all=()

interfaces_all=\$(ip -br link | awk '{print \$1}' | tr '\n' ' ')
interfaces_all=(\$(redup_array "\${interfaces_all[@]}"))
interfaces_all=(\$(clear_array "\${interfaces_all[@]}"))
# declare -a interfaces=(\$interfaces_all)
interfaces=(\${interfaces_all[@]})
# echo "统计接口: \${interfaces[@]}"
# for ((i = 0; i < \${#interfaces[@]}; i++)); do
#     echo "\$((i+1)): \${interfaces[i]}"
# done

source \$ConfigFile

for interface in "\${interfaces[@]}"; do
    interface_nodot=\${interface//./_}
    INTERFACE_RT_RX_PB[\$interface_nodot]=\${INTERFACE_RT_RX_B[\$interface_nodot]}
    # echo "读取: INTERFACE_RT_RX_PB[\$interface_nodot]: \${INTERFACE_RT_RX_PB[\$interface_nodot]}"
    INTERFACE_RT_TX_PB[\$interface_nodot]=\${INTERFACE_RT_TX_B[\$interface_nodot]}
    # echo "读取: INTERFACE_RT_TX_PB[\$interface_nodot]: \${INTERFACE_RT_TX_PB[\$interface_nodot]}"
done

for interface in "\${interfaces[@]}"; do
    interface_nodot=\${interface//./_}
    echo "----------------------------------- FOR: \$interface"
    rx_bytes=\$(ip -s link show \$interface | awk '/RX:/ { getline; print \$1 }')
    echo "rx_bytes: \$rx_bytes"
    if [ ! -z "\$rx_bytes" ] && [[ \$rx_bytes =~ ^[0-9]+(\.[0-9]+)?$ ]]; then

        INTERFACE_RT_RX_B[\$interface_nodot]=\$rx_bytes
        if [ ! -z "\${INTERFACE_RT_RX_PB[\$interface_nodot]}" ] && [[ \${INTERFACE_RT_RX_PB[\$interface_nodot]} =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
            INTERFACE_RT_RX_B[\$interface_nodot]=\$(awk -v v1="\${INTERFACE_RT_RX_B[\$interface_nodot]}" -v v2="\${INTERFACE_RT_RX_PB[\$interface_nodot]}" 'BEGIN { printf "%.0f", v1 + v2 }')
        fi

        sed -i "/^INTERFACE_RT_RX_B\[\$interface_nodot\]=/d" \$ConfigFile
        writeini "INTERFACE_RT_RX_B[\$interface_nodot]" "\${INTERFACE_RT_RX_B[\$interface_nodot]}"
        echo "INTERFACE_RT_RX_B[\$interface_nodot]: \${INTERFACE_RT_RX_B[\$interface_nodot]}"
    fi

    tx_bytes=\$(ip -s link show \$interface | awk '/TX:/ { getline; print \$1 }')
    echo "tx_bytes: \$tx_bytes"
    if [ ! -z "\$tx_bytes" ] && [[ \$tx_bytes =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
        INTERFACE_RT_TX_B[\$interface_nodot]=\$tx_bytes

        if [ ! -z "\${INTERFACE_RT_TX_PB[\$interface_nodot]}" ] && [[ \${INTERFACE_RT_TX_PB[\$interface_nodot]} =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
            INTERFACE_RT_TX_B[\$interface_nodot]=\$(awk -v v1="\${INTERFACE_RT_TX_B[\$interface_nodot]}" -v v2="\${INTERFACE_RT_TX_PB[\$interface_nodot]}" 'BEGIN { printf "%.0f", v1 + v2 }')
        fi

        sed -i "/^INTERFACE_RT_TX_B\[\$interface_nodot\]=/d" \$ConfigFile
        writeini "INTERFACE_RT_TX_B[\$interface_nodot]" "\${INTERFACE_RT_TX_B[\$interface_nodot]}"
        echo "INTERFACE_RT_TX_B[\$interface_nodot]: \${INTERFACE_RT_TX_B[\$interface_nodot]}"
    fi

done
echo "====================================== 检正部分"
echo "文件内容:"
cat \$ConfigFile | grep '^INTERFACE_RT'
echo "======================================"
echo "读取测试:"
source \$ConfigFile
for interface in "\${interfaces[@]}"; do
    interface_nodot=\${interface//./_}
    echo "interface: \$interface"
    echo "interface_nodot: \$interface_nodot"
    echo "写入变量名称: INTERFACE_RT_RX_B[\$interface_nodot]"
    INTERFACE_RT_RX_B[\$interface_nodot]=\${INTERFACE_RT_RX_B[\$interface_nodot]}
    echo "读取: INTERFACE_RT_RX_B[\$interface_nodot]: \${INTERFACE_RT_RX_B[\$interface_nodot]}"
    echo "写入变量名称: INTERFACE_RT_TX_B[\$interface_nodot]"
    INTERFACE_RT_TX_B[\$interface_nodot]=\${INTERFACE_RT_TX_B[\$interface_nodot]}
    echo "读取: INTERFACE_RT_TX_B[\$interface_nodot]: \${INTERFACE_RT_TX_B[\$interface_nodot]}"
done
echo "=============================================="
echo
EOF
                    chmod +x $FolderPath/tg_shutdown_rt.sh
                    cat <<EOF > /etc/systemd/system/tg_shutdown_rt.service
[Unit]
Description=tg_shutdown
DefaultDependencies=no
Before=shutdown.target

[Service]
Type=oneshot
ExecStart=/bin/bash -c 'exec $FolderPath/tg_shutdown_rt.sh >> $FolderPath/tg_shutdown_rt.log 2>&1'
TimeoutStartSec=0

[Install]
WantedBy=shutdown.target
EOF
                    systemctl enable tg_shutdown_rt.service > /dev/null
                    writeini "SHUTDOWN_RT" "true"
                    echo -e "$Tip 关机记录流量 已经成功设置."
                else
                    systemctl stop tg_shutdown_rt.service > /dev/null 2>&1
                    systemctl disable tg_shutdown_rt.service > /dev/null 2>&1
                    sleep 1
                    rm -f /etc/systemd/system/tg_shutdown_rt.service
                    rm -f $FolderPath/tg_shutdown_rt.log
                    sed -i "/^INTERFACE_RT_RX_B/d" $ConfigFile
                    sed -i "/^INTERFACE_RT_TX_B/d" $ConfigFile
                    writeini "SHUTDOWN_RT" "false"
                    echo -e "$Tip 关机记录流量 (已删除记录) 已经取消 / 删除."
                fi
                ;;
            6)
                # 设置Telegram代理(国内使用)
                prev_ProxyURL=$ProxyURL
                if [ "$autorun" == "true" ]; then
                    inputurl="1"
                else
                    # if [ -z "$ProxyURL" ]; then
                    #     echo -e "$Inf 目前代理: ${GRB}无${NC}"
                    # else
                    #     echo -e "$Inf 目前代理: ${GRB}$ProxyURL${NC}"
                    # fi
                    divline
                    echo "以下代理可用:"
                    echo -e "${GR}1${NC}. https://xx80.eu.org/p/"
                    echo -e "${GR}2${NC}. https://cp.iexx.eu.org/proxy/"
                    echo -e "${GR}3${NC}. https://mirror.ghproxy.com/"
                    echo -e "${GR}4${NC}. https://endpoint.fastgit.org/"
                    read -e -p "请输入以上序号或代理地址 (回车取消代理): " inputurl
                fi
                if [ -z "$inputurl" ]; then
                    inputurl=""
                    writeini "ProxyURL" "$inputurl"
                elif [ "$inputurl" == "1" ]; then
                    inputurl="https://cp.255.cloudns.biz/proxy/"
                    writeini "ProxyURL" "$inputurl"
                elif [ "$inputurl" == "2" ]; then
                    inputurl="https://cp.iexx.eu.org/proxy/"
                    writeini "ProxyURL" "$inputurl"
                elif [ "$inputurl" == "3" ]; then
                    inputurl="https://mirror.ghproxy.com/"
                    writeini "ProxyURL" "$inputurl"
                elif [ "$inputurl" == "4" ]; then
                    inputurl="https://endpoint.fastgit.org/"
                    writeini "ProxyURL" "$inputurl"
                elif [[ $inputurl =~ ^https?:// ]]; then
                    # 如果网址后面没有"/"则在网址后面加上"/"
                    if [ "${inputurl: -1}" != "/" ]; then
                        inputurl="${inputurl}/"
                    fi
                    writeini "ProxyURL" "$inputurl"
                    echo -e "$Tip 代理地址: ${GRB}$inputurl${NC}"
                else
                    echo -e "$Err ${REB}输入无效${NC}, 代理地址 必须是以上序号或以 http(s):// 开头的网址."
                    inputurl=$prev_ProxyURL
                fi
                if [ -z $inputurl ]; then
                    inputurl_show="无"
                else
                    inputurl_show=$inputurl
                fi
                if [ "$prev_ProxyURL" != "$inputurl" ]; then
                    cat <<EOF > $FolderPath/send_tg.sh
#!/bin/bash
curl -s -X POST "${inputurl}https://api.telegram.org/bot\${1}/sendMessage" \
    -d chat_id="\${2}" -d text="\${3}" > /dev/null 2>&1 &
EOF
                    echo -e "$Tip 代理地址: ${GRB}$inputurl_show${NC}"
                else
                    echo -e "$Tip 代理地址: ${GRB}$inputurl_show${NC} ${GR}未变更${NC}."
                fi
                ;;
            7)
                # 设置是否发送机器在线时长
                if [ "$autorun" == "true" ]; then
                    choice="Y"
                else
                    # if [ -z $SendUptime ] || [ "$SendUptime" == "false" ]; then
                    #     echo -e "$Inf 目前是否发送机器在线时长: ${GRB}否${NC}"
                    # else
                    #     echo -e "$Inf 目前是否发送机器在线时长: ${GRB}是${NC}"
                    # fi
                    divline
                    read -e -p "请选择是否发送机器在线时长  Y.是  其它/回车.否: " choice
                fi
                if [ "$choice" == "y" ] || [ "$choice" == "Y" ]; then
                    writeini "SendUptime" "true"
                    echo -e "$Tip 已开启发送机器在线时长."
                else
                    writeini "SendUptime" "false"
                    echo -e "$Tip 已关闭发送机器在线时长."
                fi
                ;;
            8)
                # 设置是否发送IP地址
                if [ "$autorun" == "true" ]; then
                    choice="Y"
                    inputurl="1"
                    input46="4"
                else
                    # if [ -z $SendIP ] || [ "$SendIP" == "false" ]; then
                    #     echo -e "$Inf 目前是否发送IP地址: ${GRB}否${NC}"
                    # else
                    #     echo -e "$Inf 目前是否发送IP地址: ${GRB}是${NC}"
                    # fi
                    divline
                    read -e -p "请选择是否发送IP地址  Y.是  其它/回车.否: " choice
                fi
                if [ "$choice" == "y" ] || [ "$choice" == "Y" ]; then
                    if [ "$autorun" == "false" ]; then
                        echo "采用以下地址获取IP:"
                        echo -e "${GR}1${NC}. ip.sb"
                        echo -e "${GR}2${NC}. ip.gs"
                        echo -e "${GR}3${NC}. ifconfig.me"
                        echo -e "${GR}4${NC}. ipinfo.io/ip"
                        read -e -p "请输入以上序号或网址 (回车默认: ip.sb ): " inputurl
                    fi
                    if [ -z "$inputurl" ]; then
                        GetIPURL="ip.sb"
                    elif [ "$inputurl" == "1" ]; then
                        GetIPURL="ip.sb"
                    elif [ "$inputurl" == "2" ]; then
                        GetIPURL="ip.gs"
                    elif [ "$inputurl" == "3" ]; then
                        GetIPURL="ifconfig.me"
                    elif [ "$inputurl" == "4" ]; then
                        GetIPURL="ipinfo.io/ip"
                    else
                        GetIPURL=$inputurl
                    fi
                    if [ "$autorun" == "false" ]; then
                        read -e -p "请选择 IP 类型:  4: IPv4  6: IPv6 (回车默认: IPv4 ): " input46
                    fi
                    if [ -z "$input46" ]; then
                        GetIP46="4"
                    elif [ "$input46" == "4" ]; then
                        GetIP46="4"
                    elif [ "$input46" == "6" ]; then
                        GetIP46="6"
                    fi
                    writeini "SendIP" "true"
                    writeini "GetIPURL" "$GetIPURL"
                    writeini "GetIP46" "$GetIP46"
                    echo -e "$Tip 已开启发送IP地址, 从 ${GRB}$GetIPURL (IPv$GetIP46)${NC} 处获取."
                    TestIP=$(curl -s -"$GetIP46" "$GetIPURL")
                    if [ ! -z "$TestIP" ]; then
                        writeini "GetIPAddress" "$TestIP"
                    fi
                    echo -e "测试结果: ${GR}$TestIP${NC}"

                else
                    writeini "SendIP" "false"
                    writeini "GetIPAddress" ""
                    echo -e "$Tip 已关闭发送IP地址."
                fi
                ;;
            9)
                # 设置是否发送加密货币报价
                if [ "$autorun" == "true" ]; then
                    choice="Y"
                    inputb="3"
                else
                    # if [ -z $SendPrice ] || [ "$SendPrice" == "false" ]; then
                    #     echo -e "$Inf 目前是否发送加密货币报价: ${GRB}否${NC}"
                    # else
                    #     echo -e "$Inf 目前是否发送加密货币报价: ${GRB}是${NC} - ${GR}$GetPriceType${NC} "
                    # fi
                    divline
                    read -e -p "请选择是否发送加密货币报价  Y.是  其它/回车.否: " choice
                fi
                if [ "$choice" == "y" ] || [ "$choice" == "Y" ]; then
                    if [ "$autorun" == "false" ]; then
                        echo "获取加密货币类型:"
                        echo -e "${GR}1${NC}. bitcoin"
                        echo -e "${GR}2${NC}. ethereum"
                        echo -e "${GR}3${NC}. chia"
                        echo -e "自定义网址查询: https://api.coingecko.com/api/v3/coins/list"
                        read -e -p "请输入以上序号或自定义 (回车默认: chia ): " inputb
                    fi
                    if [ -z "$inputb" ]; then
                        GetPriceType="chia"
                    elif [ "$inputb" == "1" ]; then
                        GetPriceType="bitcoin"
                    elif [ "$inputb" == "2" ]; then
                        GetPriceType="ethereum"
                    elif [ "$inputb" == "3" ]; then
                        GetPriceType="chia"
                    else
                        GetPriceType=$inputb
                    fi
                    writeini "SendPrice" "true"
                    writeini "GetPriceType" "$GetPriceType"
                    echo -e "$Tip 已开启发送加密货币报价, 获取 ${GRB}$GetPriceType${NC} 报价."
                else
                    writeini "SendPrice" "false"
                    echo -e "$Tip 已关闭发送加密货币报价."
                fi
                ;;
            *)
                echo "退出设置."
                tips=""
                break
            ;;
        esac
    done
}

# 用于显示内容（调试用）
# SourceAndShowINI() {
#     if [ -f $ConfigFile ] && [ -s $ConfigFile ]; then
#         source $ConfigFile
#         divline
#         cat $ConfigFile
#         divline
#         echo -e "$Tip 以上为 TelgramBot.ini 文件内容, 可重新执行 ${GR}0${NC} 修改参数."
#     fi
# }

