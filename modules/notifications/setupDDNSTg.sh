#!/usr/bin/env bash


SetupDDNS_TG() {
    if [ ! -z "${ddns_pid:-}" ] && pgrep -a '' | grep -Eq "^\s*$ddns_pid\s" > /dev/null; then
        tips="$Err PID(${GR}$ddns_pid${NC}) 正在发送中,请稍后..."
        return 1
    fi
    if [[ -z "${TelgramBotToken}" || -z "${ChatID_1}" ]]; then
        tips="$Err 参数丢失, 请设置后再执行 (先执行 ${GR}0${NC} 选项)."
        return 1
    fi
    # if [ "$autorun" == "false" ]; then
    echo -en "请输入 DDNS 的 IP 格式: ${GR}4.${NC}IPv4 ${GR}6.${NC}IPv6 : "
    read -er input_iptype
    if [ "$input_iptype" == "4" ]; then
        CFDDNS_IP_TYPE="A"
    elif [ "$input_iptype" == "6" ]; then
        CFDDNS_IP_TYPE="AAAA"
    else
        echo
        tips="$Err 输入有误, 取消操作."
        return 1
    fi
    echo -en "请输入 CF 帐号名 (邮箱) : "
    read -er input_email
    email_regex="^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$"
    if [ -z "$input_email" ] || [[ ! $input_email =~ $email_regex ]]; then
        echo
        tips="$Err 输入有误, 取消操作."
        return 1
    else
        CFDDNS_EMAIL=$input_email
    fi
    echo -en "请输入 CF Global API Key : "
    read -er input_apikey
    if [ -z "$input_apikey" ]; then
        echo
        tips="$Err 输入有误, 取消操作."
        return 1
    else
        CFDDNS_APIKEY=$input_apikey
    fi
    echo -en "请输入 CF Zone ID : "
    read -er input_zoneid
    if [ -z "$input_zoneid" ]; then
        echo
        tips="$Err 输入有误, 取消操作."
        return 1
    else
        CFDDNS_ZID=$input_zoneid
    fi
    echo -e "请输入 DDNS 完整域名 (含前缀)"
    echo -en "( 如: abc.xxx.eu.org ) : "
    read -er input_domain
    if [ -z "$input_domain" ]; then
        echo
        tips="$Err 输入有误, 取消操作."
        return 1
    else
        CFDDNS_DOMAIN_P="${input_domain%%.*}"
        CFDDNS_DOMAIN_S="${input_domain#*.}"
    fi
    echo -e "模式: ${GR}1.${NC}当自身IP发生变化时 ${GR}2.${NC}当与域名IP对比不匹配时"
    echo -en "请选择 DDNS 模式 ( 回车默认 1 ) : "
    read -er input_choice
    if [ "$input_choice" == "1" ] || [ -z "$input_choice" ]; then
        CFDDNS_MODE="1"
    elif [ "$input_choice" == "2" ]; then
        CFDDNS_MODE="2"
    else
        echo
        tips="$Err 输入有误, 取消操作."
        return 1
    fi

    echo -e "当 DDNS 进程无故被中止时, DDNS 守护将会为你打开进程, 以确保 DDNS 持续运行."
    echo -e "是否开启 DDNS 守护? ${GR}Y.${NC}开启 ${GR}N.${NC}不开启"
    echo -en "请选择 DDNS 模式 ( 回车默认 ${GR}开启${NC} ) : "
    read -er keeper_choice
    if [ "$keeper_choice" == "y" ] || [ "$keeper_choice" == "Y" ] || [ -z "$keeper_choice" ]; then
        CFDDNS_KEEPER="true"
    elif [ "$keeper_choice" == "n" ] || [ "$keeper_choice" == "N" ]; then
        CFDDNS_KEEPER="false"
    else
        echo
        tips="$Err 输入有误, 取消操作."
        return 1
    fi


    cat <<EOF > "$FolderPath/tg_ddns.sh"
#!/bin/bash

#################################################################### Cloudflare账户信息
email="$CFDDNS_EMAIL" # 帐号邮箱
api_key="$CFDDNS_APIKEY" # 主页获取
zone_id="$CFDDNS_ZID" # 主页获取
domain="$CFDDNS_DOMAIN_S" # 域名
record_name="$CFDDNS_DOMAIN_P" # 自定义前缀
iptype="$CFDDNS_IP_TYPE" # 动态解析IP类型: A为IPV4, AAAA为IPV6
ddns_mode="$CFDDNS_MODE"
ttls="1" # TTL: 1为自动, 60为1分钟, 120为2分钟
proxysw="false" # 是否开启小云朵(CF代理)( true 或 false )
####################################################################

$(declare -f Checkpara)

FolderPath="$FolderPath"
if [ ! -d "\$FolderPath" ]; then
    mkdir -p "\$FolderPath"
fi
ConfigFile="$ConfigFile"
source \$ConfigFile &>/dev/null
Checkpara "hostname_show" "$hostname_show"

action() {
    local iptype_lo="\${1}"
    local ipaddress="\${2}"

    attempts=1 # 尝试次数标记
    max_attempts=5 # 最多获取次数(可自定义)
    record_id="" # 无需更改

    while [ \$attempts -le \$max_attempts ]; do
        response=\$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/\${zone_id}/dns_records?type=\${iptype}&name=\${record_name}.\${domain}" \
            -H "X-Auth-Email: \${email}" \
            -H "X-Auth-Key: \${api_key}" \
            -H "Content-Type: application/json")
        echo "获取DNS记录API响应: \$response"

        record_id=\$(echo "\$response" | awk -F'"' '/id/{print \$6; exit}')

        if [ -z "\$record_id" ]; then
            echo "第 \$attempts 次获取DNS记录ID失败。"
            if [ \$attempts -eq \$max_attempts ]; then
                echo "获取DNS记录ID失败，请检查输入的信息是否正确。"
                get_record_id="获取DNS记录ID失败!"
                # get_record_id_tag="geterr"
                return 1
            else
                attempts=\$((attempts+1))
            fi
            sleep 1
        else
            echo "成功获取DNS记录ID: \$record_id"
            get_record_id=""
            break
        fi
    done
    update_response=\$(curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/\${zone_id}/dns_records/\${record_id}" \
        -H "X-Auth-Email: \${email}" \
        -H "X-Auth-Key: \${api_key}" \
        -H "Content-Type: application/json" \
        --data '{"type":"'\${iptype_lo}'","name":"'\${record_name}'","content":"'\${ipaddress}'","ttl":'\${ttls}',"proxied":'\${proxysw}'}')

    echo "更新DNS记录API响应: \$update_response"
    if [[ "\$update_response" == *"success\":true"* ]]; then
        echo "DNS记录更新成功。"
        date
    else
        echo "DNS记录更新失败，请检查输入的信息是否正确。"
        date
    fi
}
if [ "\${1}" == "re" ]; then
    revive="true"
else
    revive="false"
    URL_regex="^(http|https)://[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}(/*)?$"
    if [[ "\${1}" =~ "\$URL_regex" ]]; then
        customizeURL="\${1}"
        echo "自定URL\${1}: \$customizeURL"
    fi
fi
getipurl4=('ip.sb' 'ip.gs' 'ifconfig.io' 'ipinfo.io/ip' 'ifconfig.me' 'icanhazip.com' 'ipecho.net/plain')
getipurl42=('ip.sb' 'ip.gs' 'ifconfig.io' 'ipinfo.io/ip' 'ifconfig.me' 'icanhazip.com' 'ipecho.net/plain')
getipurl6=('ip.sb' 'ip.gs' 'ifconfig.io' 'ifconfig.me' 'ipecho.net/plain' 'ipv6.icanhazip.com')
echo "获取 IPv4 URL: \${getipurl4[@]} \${getipurl42[@]}"
echo "获取 IPv6 URL: \${getipurl6[@]}"
ipv4_regex="^([0-9]{1,3}\.){3}[0-9]{1,3}$"
ipv6_regex="^(
    ([0-9a-fA-F]{1,4}:){7,7}[0-9a-fA-F]{1,4}|
    ([0-9a-fA-F]{1,4}:){1,7}:|
    ([0-9a-fA-F]{1,4}:){1,6}:[0-9a-fA-F]{1,4}|
    ([0-9a-fA-F]{1,4}:){1,5}(:[0-9a-fA-F]{1,4}){1,2}|
    ([0-9a-fA-F]{1,4}:){1,4}(:[0-9a-fA-F]{1,4}){1,3}|
    ([0-9a-fA-F]{1,4}:){1,3}(:[0-9a-fA-F]{1,4}){1,4}|
    ([0-9a-fA-F]{1,4}:){1,2}(:[0-9a-fA-F]{1,4}){1,5}|
    [0-9a-fA-F]{1,4}:((:[0-9a-fA-F]{1,4}){1,6})|
    :((:[0-9a-fA-F]{1,4}){1,7}|:)|fe80:(:[0-9a-fA-F]{0,4}){0,4}%[0-9a-zA-Z]{1,}|
    ::(ffff(:0{1,4}){0,1}:){0,1}((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])|
    ([0-9a-fA-F]{1,4}:){1,4}:((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])
)$"
echo "----------------------------------------------------------"

get_ipvx() {
    local urls=("\${!1}")  # 使用间接引用获取 URL 数组
    local ip_regex="\$3"   # 获取 IP 地址的正则表达式
    local option="\$2"     # 获取 curl 参数
    for url in "\${urls[@]}"; do
        echo "CURL: \$url ..."
        ip_result=\$(curl \$option "\$url")
        if [[ \$ip_result =~ \$ip_regex ]]; then
            echo "IP: \$ip_result   GET: \$url"
            export GETURL="\$url"
            export ip_result="\$ip_result"  # 将 ip_result 导出为全局变量
            return 0  # 返回成功
        else
            echo "IP: 获取失败!   GET: \$url"
            ip_result="获取失败! ✖️"
        fi
    done
    get_tag="geterr"
    return 1  # 返回失败
}

url_get_ipv4() {
    local show_URL_IPV4="\${1}"
    local URL_IPV4=""
    # URL_IPV4=\$(ping -c 1 \${record_name}.\${domain} | awk '/^PING/{print \$3}' | awk -F'[()]' '{print \$2}')
    URL_IPV4=\$(curl -s https://dns.google/resolve?name=\${record_name}.\${domain} | grep -oE "\\b([0-9]{1,3}\\.){3}[0-9]{1,3}\\b" | head -n 1)
    if [ -z "\$URL_IPV4" ] || [[ ! \$URL_IPV4 =~ \$ipv4_regex ]]; then
        # URL_IPV4=\$(curl -s "https://api.ipify.org?format=json&hostname=\${record_name}.\${domain}" | awk -F'"' '/ip/{print \$4}')
        URL_IPV4=\$(ping -c 1 \${record_name}.\${domain} | awk '/^PING/{print \$3}' | awk -F'[()]' '{print \$2}')
        if [ -z "\$URL_IPV4" ] || [[ ! \$URL_IPV4 =~ \$ipv4_regex ]]; then
            # echo "show_URL_IPV4获取失败!  |  URL_IPV4: URL_IPV4"
            echo "IPV4获取失败!"
            return 1
        fi
    fi
    echo "\$URL_IPV4"
}

url_get_ipv6() {
    local show_URL_IPV6="\${1}"
    local URL_IPV6=""
    # URL_IPV6=\$(dig +short AAAA \${record_name}.\${domain})
    URL_IPV6=\$(curl -s "https://ipv6-test.com/api/myip.php?host=\${record_name}.\${domain}")
    if [ -z "\$URL_IPV6" ] || [[ ! \$URL_IPV6 =~ \$ipv6_regex ]]; then
        URL_IPV6=\$(curl -s "https://api6.ipify.org?format=json&hostname=\${record_name}.\${domain}" | awk -F'"' '/ip/{print \$4}')
        if [ -z "\$URL_IPV6" ] || [[ ! \$URL_IPV6 =~ \$ipv6_regex ]]; then
            # echo "show_URL_IPV6获取失败!  |  URL_IPV6: URL_IPV6"
            echo "IPV6获取失败!"
            return 1
        fi
    fi
    echo "\$URL_IPV4"
}

if [ "\$ddns_mode" == "1" ]; then
    show_ddns_mode="↪️"
    if [ "\$iptype" == "A" ]; then
        get_ipvx "getipurl4[@]" "-4" "\$ipv4_regex"
        O_IPV4="\$ip_result"
        O_IPV4_tag="\$get_tag"
        if [ "\$O_IPV4_tag" == "geterr" ]; then
            get_ipvx "getipurl42[@]" "" "\$ipv4_regex"
            O_IPV4="\$ip_result"
        fi
    elif [ "\$iptype" == "AAAA" ]; then
        get_ipvx "getipurl6[@]" "" "\$ipv6_regex"
        O_IPV6="\$ip_result"
    else
        echo "IP type 有误."
    fi
elif [ "\$ddns_mode" == "2" ]; then
    show_ddns_mode="↩️"
    if [ "\$iptype" == "A" ]; then
        O_URL_IPV4=\$(url_get_ipv4 "O_URL_IPV4")
    elif [ "\$iptype" == "AAAA" ]; then
        O_URL_IPV6=\$(url_get_ipv6 "O_URL_IPV6")
    else
        echo "IP type 有误."
    fi
else
    echo "DDNS mode 有误."
fi

dellog_tag=1
dellog_max=25
only_onece="true"
sleep_send="false"
while true; do

    N_IPV4=""
    N_IPV6=""

    if [ ! -z "\$customizeURL" ]; then
        N_IPV4=\$(curl -4 "\$customizeURL")
        if [ -z "\$N_IPV4" ]; then
            echo "从 \$customizeURL 获取IP失败!"
        else
            echo "IPv4: \$N_IPV4   GET: \$customizeURL"
        fi
    fi
    if [ "\$iptype" == "A" ]; then
        get_ipvx "getipurl4[@]" "-4" "\$ipv4_regex"
        N_IPV4="\$ip_result"
        N_IPV4_tag="\$get_tag"
        if [ "\$N_IPV4_tag" == "geterr" ]; then
            get_ipvx "getipurl42[@]" "" "\$ipv4_regex"
            N_IPV4="\$ip_result"
        fi
    elif [ "\$iptype" == "AAAA" ]; then
        get_ipvx "getipurl6[@]" "" "\$ipv6_regex"
        N_IPV6="\$ip_result"
    else
        echo "IP type 有误."
    fi

    if [ "\$iptype" == "A" ] && [ ! -z "\$N_IPV4" ]; then

        COM_N_IPV4=\$(echo "\$N_IPV4" | tr -d '.')
        echo "COM_N_IPV4: \$COM_N_IPV4"
        if [ "\$ddns_mode" == "1" ]; then
            COM_O_IPV4=\$(echo "\$O_IPV4" | tr -d '.')
            echo "COM_O_IPV4: \$COM_O_IPV4  |  DDNS_MODE: \$ddns_mode"
        elif [ "\$ddns_mode" == "2" ]; then
            COM_O_IPV4=\$(echo "\$O_URL_IPV4" | tr -d '.')
            echo "COM_O_IPV4: \$COM_O_IPV4  |  DDNS_MODE: \$ddns_mode"
        else
            echo "DDNS mode 有误."
        fi

        if [ "\$only_onece" == "true" ]; then
            action "\$iptype" "\$N_IPV4"
            return_code=\$?
            if [ "\$return_code" -eq 1 ]; then
                echo "首次执行 DDNS 失败!"
            else
                current_date_send=\$(date +"%Y.%m.%d %T")
                if [ "\$revive" == "true" ]; then
                    message="复活执行 DDNS \$show_ddns_mode"$'\n'
                else
                    message="首次执行 DDNS \$show_ddns_mode"$'\n'
                fi
                message+="主机名: \$hostname_show"$'\n'
                message+="URL: \$record_name.\$domain"$'\n'
                # if [ "\$ddns_mode" == "1" ]; then
                #     message+="更新前IP地址: \$O_IPV4"$'\n'
                # elif [ "\$ddns_mode" == "2" ]; then
                #     message+="更新前IP地址: \$O_URL_IPV4"$'\n'
                # fi
                # message+="更新后IP地址: \$N_IPV4"$'\n'
                message+="当前IP地址: \$N_IPV4"$'\n'
                message+="───────────────"$'\n'
                message+="GETIP 地址: \$GETURL"$'\n'
                message+="服务器时间: \$current_date_send"
                \$FolderPath/send_tg.sh "\$TelgramBotToken" "\$ChatID_1" "\$message"
                echo \$N_IPV4 >> \$FolderPath/IP4_history.txt
            fi
            only_onece="false"
        fi

        if [[ "\$COM_N_IPV4" != "\$COM_O_IPV4" ]]; then
            echo -e "更新后: \$N_IPV4   GET: \$GETURL     更新前: \$O_IPV4"
            if [ -z "\$COM_O_IPV4" ]; then
                echo "首次执行 DDNS 更新IP中..." # 调试
            else
                echo "IP已改变! 正在执行 DDNS 更新IP中..." # 调试
            fi
            action "\$iptype" "\$N_IPV4"
            return_code=\$?
            for ((i=1; i<=6; i++)); do
                N_URL_IPV4=\$(url_get_ipv4 "N_URL_IPV4")
                COM_N_IPV4=\$(echo "\$N_URL_IPV4" | tr -d '.')
                if [[ "\$COM_N_IPV4" != "\$COM_O_IPV4" ]]; then
                    break
                fi
                sleep 10
            done
            echo "\${record_name}.\${domain} - \$N_URL_IPV4"
            current_date_send=\$(date +"%Y.%m.%d %T")
            message="IP 已变更! \$show_ddns_mode"$'\n'
            message+="主机名: \$hostname_show"$'\n'
            message+="URL: \$record_name.\$domain"$'\n'
            if [ "\$ddns_mode" == "1" ]; then
                message+="更新前IP地址: \$O_IPV4"$'\n'
            elif [ "\$ddns_mode" == "2" ]; then
                message+="更新前IP地址: \$O_URL_IPV4"$'\n'
            fi
            # if [ "\$return_code" -eq 1 ]; then
            #     message+="\$record_name.\$domain 更新失败! ✖️"$'\n'
            # else
            #     # if [ ! -z "\$O_URL_IPV4" ]; then
            #         message+="\$record_name.\$domain \$O_URL_IPV4"$'\n'
            #     # fi
            # fi
            message+="更新后IP地址: \$N_IPV4"$'\n'
            # if [ "\$return_code" -eq 1 ]; then
            #     message+="\$record_name.\$domain 更新失败! ✖️"$'\n'
            # else
            #     # if [ ! -z "\$N_URL_IPV4" ]; then
            #         message+="\$record_name.\$domain \$N_URL_IPV4"$'\n'
            #     # fi
            # fi
            message+="───────────────"$'\n'
            if [[ \$N_IPV4 =~ \$ipv4_regex ]]; then
                message+="GETIP 地址: \$GETURL"$'\n'
            fi
            message+="服务器时间: \$current_date_send"
            \$FolderPath/send_tg.sh "\$TelgramBotToken" "\$ChatID_1" "\$message"
            O_IPV4=\$N_IPV4
            O_URL_IPV4=\$N_URL_IPV4
            echo \$N_IPV4 >> \$FolderPath/IP4_history.txt
            sleep_send="true"
        else
            echo -e "更新后: \$N_IPV4   GET: \$GETURL     更新前: \$O_IPV4"
            echo "IP未改变." # 调试
        fi
    elif [ "\$iptype" == "AAAA" ] && [ ! -z "\$N_IPV6" ]; then

        COM_N_IPV6=\$(echo "\$N_IPV6" | tr -d ':')
        echo "COM_N_IPV6: \$COM_N_IPV6"
        if [ "\$ddns_mode" == "1" ]; then
            COM_O_IPV6=\$(echo "\$O_IPV6" | tr -d ':')
            echo "COM_O_IPV6: \$COM_O_IPV6  |  DDNS_MODE: \$ddns_mode"
        elif [ "\$ddns_mode" == "2" ]; then
            COM_O_IPV6=\$(echo "\$O_URL_IPV6" | tr -d ':')
            echo "COM_O_IPV6: \$COM_O_IPV6  |  DDNS_MODE: \$ddns_mode"
        else
            echo "DDNS mode 有误."
        fi

        if [ "\$only_onece" == "true" ]; then
            action "\$iptype" "\$N_IPV6"
            return_code=\$?
            if [ "\$return_code" -eq 1 ]; then
                echo "首次执行 DDNS 失败!"
            else
                current_date_send=\$(date +"%Y.%m.%d %T")
                if [ "\$revive" == "true" ]; then
                    message="复活执行 DDNS \$show_ddns_mode"$'\n'
                else
                    message="首次执行 DDNS \$show_ddns_mode"$'\n'
                fi
                message+="主机名: \$hostname_show"$'\n'
                message+="URL: \$record_name.\$domain"$'\n'
                # if [ "\$ddns_mode" == "1" ]; then
                #     message+="更新前IP地址: \$O_IPV6"$'\n'
                # elif [ "\$ddns_mode" == "2" ]; then
                #     message+="更新前IP地址: \$O_URL_IPV6"$'\n'
                # fi
                # message+="更新后IP地址: \$N_IPV6"$'\n'
                message+="当前IP地址: \$N_IPV6"$'\n'
                message+="───────────────"$'\n'
                message+="GETIP 地址: \$GETURL"$'\n'
                message+="服务器时间: \$current_date_send"
                \$FolderPath/send_tg.sh "\$TelgramBotToken" "\$ChatID_1" "\$message"
                echo \$N_IPV6 >> \$FolderPath/IP6_history.txt
            fi
            only_onece="false"
        fi

        if [[ "\$COM_N_IPV6" != "\$COM_O_IPV6" ]]; then
            echo -e "更新后: \$N_IPV6   GET: \$GETURL     更新前: \$O_IPV6"
            if [ -z "\$COM_O_IPV6" ]; then
                echo "首次执行 DDNS 更新IP中..." # 调试
            else
                echo "IP已改变! 正在执行 DDNS 更新IP中..." # 调试
            fi
            action "\$iptype" "\$N_IPV6"
            return_code=\$?
            for ((i=1; i<=6; i++)); do
                N_URL_IPV6=\$(url_get_ipv6 "N_URL_IPV6")
                COM_N_IPV6=\$(echo "\$N_URL_IPV6" | tr -d ':')
                if [[ "\$COM_N_IPV6" != "\$COM_O_IPV6" ]]; then
                    break
                fi
                sleep 10
            done
            echo "\${record_name}.\${domain} - \$N_URL_IPV6"
            current_date_send=\$(date +"%Y.%m.%d %T")
            message="IP 已变更! \$show_ddns_mode"$'\n'
            message+="主机名: \$hostname_show"$'\n'
            message+="URL: \$record_name.\$domain"$'\n'
            if [ "\$ddns_mode" == "1" ]; then
                message+="更新前IP地址: \$O_IPV6"$'\n'
            elif [ "\$ddns_mode" == "2" ]; then
                message+="更新前IP地址: \$O_URL_IPV6"$'\n'
            fi
            # if [ "\$return_code" -eq 1 ]; then
            #     message+="\$record_name.\$domain 更新失败! ✖️"$'\n'
            # else
            #     # if [ ! -z "\$O_URL_IPV6" ]; then
            #         message+="\$record_name.\$domain \$O_URL_IPV6"$'\n'
            #     # fi
            # fi
            message+="更新后IP地址: \$N_IPV6"$'\n'
            # if [ "\$return_code" -eq 1 ]; then
            #     message+="\$record_name.\$domain 更新失败! ✖️"$'\n'
            # else
            #     # if [ ! -z "\$N_URL_IPV6" ]; then
            #         message+="\$record_name.\$domain \$N_URL_IPV6"$'\n'
            #     # fi
            # fi
            message+="───────────────"$'\n'
            if [[ \$N_IPV6 =~ \$ipv6_regex ]]; then
                message+="GETIP 地址: \$GETURL"$'\n'
            fi
            message+="服务器时间: \$current_date_send"
            \$FolderPath/send_tg.sh "\$TelgramBotToken" "\$ChatID_1" "\$message"
            O_IPV6=\$N_IPV6
            O_URL_IPV6=\$N_URL_IPV6
            echo \$N_IPV6 >> \$FolderPath/IP6_history.txt
            sleep_send="true"
        else
            echo -e "更新后: \$N_IPV6   GET: \$GETURL     更新前: \$O_IPV6"
            echo "IP未改变." # 调试
        fi
    else
        echo "N_IPV4/6 获取失败 或 IP type 有误."
        # exit 1
    fi
    current_date_send=\$(date +"%Y.%m.%d %T")
    echo "\$current_date_send     LOG: \$dellog_tag / \$dellog_max"
    if [ "\$dellog_tag" -ge "\$dellog_max" ]; then
        > \$FolderPath/tg_ddns.log
        dellog_tag=0
    fi
    ((dellog_tag++))
    echo "----------------------------------------------------------"
    if [ "\$sleep_send" == "true" ]; then
        sleep 120
        sleep_send="false"
    else
        sleep 30
    fi
done
# END
EOF
    chmod +x $FolderPath/tg_ddns.sh
    killpid "tg_ddns.sh"
    nohup $FolderPath/tg_ddns.sh > $FolderPath/tg_ddns.log 2>&1 &
    delcrontab "$FolderPath/tg_ddns.sh"
    addcrontab "@reboot nohup $FolderPath/tg_ddns.sh > $FolderPath/tg_ddns.log 2>&1 &"

    if [ "$CFDDNS_KEEPER" == "true"  ]; then
        cat > "$FolderPath/tg_ddnskp.sh" << EOF
#!/bin/bash

####################################################################
# DDNS 守护脚本

$(declare -f getpid)
$(declare -f addcrontab)

FolderPath="$FolderPath"
if [ ! -d "\$FolderPath" ]; then
    mkdir -p "\$FolderPath"
fi

for ((i=0; i<3; i++)); do

    ddnskp_pid=\$(getpid "tg_ddns.sh")

    if [ -z "\$ddnskp_pid" ]; then
        current_date=\$(date +"%Y.%m.%d %T")
        echo "\$current_date : 后台未检查到 tg_ddns.sh 进程, 正在启动中..."
        nohup \$FolderPath/tg_ddns.sh "re" > \$FolderPath/tg_ddns.log 2>&1 &
    fi

    if ! crontab -l | grep -q "\$FolderPath/tg_ddnskp.sh"; then
        addcrontab "*/5 * * * * bash \$FolderPath/tg_ddnskp.sh >> \$FolderPath/tg_ddnskp.log 2>&1 &"
        /etc/init.d/cron restart > /dev/null 2>&1
    fi

sleep 3
done
EOF
        chmod +x $FolderPath/tg_ddnskp.sh
        delcrontab "$FolderPath/tg_ddnskp.sh"
        addcrontab "*/3 * * * * bash $FolderPath/tg_ddnskp.sh >> $FolderPath/tg_ddnskp.log 2>&1 &"
        cat > "$FolderPath/tg_ddkpnh.sh" << EOF
#!/bin/bash

$(declare -f addcrontab)

FolderPath="$FolderPath"
if [ ! -d "\$FolderPath" ]; then
    mkdir -p "\$FolderPath"
fi

while true; do
    if ! crontab -l | grep -q "\$FolderPath/tg_ddnskp.sh"; then
        addcrontab "*/5 * * * * bash \$FolderPath/tg_ddnskp.sh >> \$FolderPath/tg_ddnskp.log 2>&1 &"
        /etc/init.d/cron restart > /dev/null 2>&1
    fi
    current_date=\$(date +"%Y.%m.%d %T")
    echo "\$current_date : 已执行 DDNS 复活."
    sleep 60
done
EOF
        chmod +x $FolderPath/tg_ddkpnh.sh
        killpid "tg_ddkpnh.sh"
        nohup $FolderPath/tg_ddkpnh.sh > $FolderPath/tg_ddkpnh.log 2>&1 &
#         cat > /etc/systemd/system/tg_ddnskp.service << EOF
# [Unit]
# Description=CheckAndStartService
# After=network.target

# [Service]
# Type=oneshot
# ExecStart=/bin/bash -c '/usr/bin/env bash <<SCRIPT
# while true; do
#     if ! pgrep -x "tg_ddkpnh.sh" >/dev/null; then
#         nohup $FolderPath/tg_ddkpnh.sh &
#     fi
#     sleep 60
# done
# SCRIPT'

# [Install]
# WantedBy=multi-user.target
# EOF
#         systemctl daemon-reload
#         systemctl enable tg_ddnskp.service > /dev/null
        cat > /etc/systemd/system/tg_ddrun.service << EOF
[Unit]
Description=Your Script Description

[Service]
Type=oneshot
ExecStart=/bin/bash $FolderPath/tg_ddnskp.sh >> $FolderPath/tg_ddnskp.log 2>&1

[Install]
WantedBy=multi-user.target
EOF

        cat > /etc/systemd/system/tg_ddtimer.timer << EOF
[Unit]
Description=Your Timer Description

[Timer]
OnUnitActiveSec=10min
Unit=tg_ddrun.service

[Install]
WantedBy=timers.target
EOF
        systemctl daemon-reload
        systemctl start tg_ddtimer.timer
        systemctl enable tg_ddtimer.timer
    fi

    if [ "$mute" == "false" ]; then
        send_time=$(echo $(date +%s%N) | cut -c 16-)
        # N_URL_IPV4=$(curl -s https://dns.google/resolve?name=$CFDDNS_DOMAIN_P.$CFDDNS_DOMAIN_S | grep -oE "\\b([0-9]{1,3}\\.){3}[0-9]{1,3}\\b" | head -n 1)
        message="DDNS 报告设置成功 ⚙️"$'\n'"主机名: $hostname_show"$'\n'"当主机 IP 变更时将收到通知."
        $FolderPath/send_tg.sh "$TelgramBotToken" "$ChatID_1" "$message" "ddns" "$send_time" &
        (sleep 15 && $FolderPath/del_lm_tg.sh "$TelgramBotToken" "$ChatID_1" "ddns" "$send_time") &
        sleep 1
        # getpid "send_tg.sh"
        # ddns_pid="$tg_pid"
        ddns_pid=$(getpid "send_tg.sh")
    fi
    tips="$Tip DDNS 报告设置成功, 当主机 IP 变更时发出通知."
}
