#!/usr/bin/env bash

#=======================================================
#	System Required: CentOS/Debian/Ubuntu/OpenWRT/Alpine/RHEL
#	Description: VPS keeper for telgram
#	Version: $sh_ver
#	Author: tse
#	Blog: https://vtse.eu.org
#=======================================================

# for file in "$FolderPath"/sub/*.sh; do
#     [ -f "$file" ] && source "$file"
# done

# 载入子脚本
# SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# SCRIPT_DIR="$(cd "$(dirname -- "$0")" && pwd)"
SCRIPT_DIR="$(cd "$(dirname -- "$0")/.." && pwd)"
# 如果SCRIPT_DIR为/usr/local则改为/opt/vpskeeper
if [ "$SCRIPT_DIR" == "/usr/local" ]; then
    SCRIPT_DIR="/opt/vpskeeper"
fi
echo "当前目录: $SCRIPT_DIR"

if [ -f "$SCRIPT_DIR/lib/loader.sh" ]; then
    source "$SCRIPT_DIR/lib/loader.sh"
    load_vpskeeper
else
    echo "错误: 无法找到脚本加载器"
    echo "请确保脚本已正确安装或在正确的目录中运行"
    echo "预期路径: $SCRIPT_DIR/lib/loader.sh"
    exit 1
fi


# CheckSetup函数已移动到 sub/statusCheck.sh



un_tag=false

# 输出版本号
# echo "脚本版本号: $sh_ver"

declare -a interfaces_all=() # 声明数组
declare -a interfaces_up=()
# interfaces_all=$(ip -br link | awk '{print $1}')
interfaces_all=$(ip -br link | awk '{print $1}' | tr '\n' ' ')
# readarray -t interfaces_all < <(ip -br link | awk '{print $1}')
interfaces_all=($(redup_array "${interfaces_all[@]}"))
interfaces_all=($(clear_array "${interfaces_all[@]}"))
# interfaces_all=($(dtu_array "${interfaces_all[@]}"))
interfaces_up=$(ip -br link | awk '$2 == "UP" {print $1}' | grep -v "lo" | tr '\n' ' ')
interfaces_up=($(redup_array "${interfaces_up[@]}"))
interfaces_up=($(clear_array "${interfaces_up[@]}"))
# interfaces_up=($(dtu_array "${interfaces_up[@]}"))
# 以下两种复制方法:
# interfaces=(${interfaces_all[@]}) # 复制数组(interfaces_all必须已经声明)
# declare -a interfaces=($interfaces_all) # 声明+复制数组

# echo "interfaces_all: ${interfaces_all[@]}" # 调试
# echo "interfaces_up: ${interfaces_up[@]}" # 调试
# Pause # 调试

interfaces_RP_0=("${interfaces_up[@]}")
interfaces_RP_de=("${interfaces_RP_0[@]}")
StatisticsMode_RP_de="SE"
interfaces_ST_0=("${interfaces_up[@]}")
interfaces_ST_de=("${interfaces_ST_0[@]}")
StatisticsMode_ST_de="SE"
# StatisticsMode_ST_de="OV" # 整体统计
# StatisticsMode_ST_de="SE" # 单独统计

# 主程序
init_config

rm -f "$FolderPath"/send_tg*.log > /dev/null 2>&1
if [ ! -f "$FolderPath/tg_flrp.sh" ] && [ -f "$FolderPath/tg_flowrp.sh" ]; then
    mv "$FolderPath/tg_flowrp.sh" "$FolderPath/tg_flrp.sh" > /dev/null 2>&1
else
    rm -f "$FolderPath/tg_flowrp.sh" > /dev/null 2>&1
fi
rm -f "$FolderPath/tg_flowrp.log" > /dev/null 2>&1

CheckSys
if [[ "${1:-}" =~ ^[0-9]{5,}$ ]]; then
    ChatID_1="$1"
    writeini "ChatID_1" "$1"
elif [[ "${2:-}" =~ ^[0-9]{5,}$ ]]; then
    ChatID_1="$2"
    writeini "ChatID_1" "$2"
elif [[ "${3:-}" =~ ^[0-9]{5,}$ ]]; then
    ChatID_1="$3"
    writeini "ChatID_1" "$3"
fi
# declare -f send_telegram_message | sed -n '/^{/,/^}/p' | sed '1d;$d' | sed 's/$1/$3/g; s/$TelgramBotToken/$1/g; s/$ChatID_1/$2/g' > $FolderPath/send_tg.sh
cat <<EOF > $FolderPath/send_tg.sh
#!/bin/bash

$(declare -f Checkpara)

FolderPath="$FolderPath"
if [ ! -d "\$FolderPath" ]; then
    mkdir -p "\$FolderPath"
fi
ConfigFile="$ConfigFile"
source \$ConfigFile &>/dev/null
Checkpara "ProxyURL" "$ProxyURL"

declare -A send_tg=()
declare -A message_id=()

if [ ! -z "\${6}" ] && [ ! -z "\${7}" ]; then
    curl -s -X POST "\${ProxyURL}https://api.telegram.org/bot\${1}/sendMessage" \
        -d chat_id="\${2}" -d text="\${3}" -d parse_mode="\${6}" -d entities="\${7}" > \$FolderPath/send_tg[\${4}\${5}].log 2>&1 &
else
    curl -s -X POST "\${ProxyURL}https://api.telegram.org/bot\${1}/sendMessage" \
        -d chat_id="\${2}" -d text="\${3}" > \$FolderPath/send_tg[\${4}\${5}].log 2>&1 &
fi

send_status=${?}

if [ ! -z "\${4}" ] && [ \$send_status -eq 0 ]; then
    sleep 6
    touch \$FolderPath/send_tg[\${4}\${5}].log
    message_id[\${4}\${5}]=\$(grep -o '"message_id":[0-9]*' \$FolderPath/send_tg[\${4}\${5}].log | grep -o '[0-9]*')
    rm -f "\$FolderPath/send_tg[].log"
    rm -f "\$FolderPath/send_tg[\${5}].log"
    rm -f "\$FolderPath/send_tg[\${4}\${5}].log"
    if [ ! -z "\${message_id[\${4}\${5}]}" ]; then
        echo "message_id[\${4}\${5}]=\${message_id[\${4}\${5}]}" > "\$FolderPath/message_id[\${4}\${5}].txt"
    fi
fi
EOF
chmod +x $FolderPath/send_tg.sh
cat <<EOF > $FolderPath/del_lm_tg.sh
#!/bin/bash

$(declare -f Checkpara)

FolderPath="$FolderPath"
if [ ! -d "\$FolderPath" ]; then
    mkdir -p "\$FolderPath"
fi
ConfigFile="$ConfigFile"
source \$ConfigFile &>/dev/null
Checkpara "ProxyURL" "$ProxyURL"

declare -A message_id=()

if [ -f \$FolderPath/message_id[\${3}\${4}].txt ]; then
    source "\$FolderPath/message_id[\${3}\${4}].txt"
    rm -f "\$FolderPath/message_id[\${3}\${4}].txt"
fi

curl -s -X POST "\${ProxyURL}https://api.telegram.org/bot\${1}/deleteMessage" \
    -d chat_id="\${2}" -d message_id="\${message_id[\${3}\${4}]}" > /dev/null 2>&1 &
EOF
chmod +x $FolderPath/del_lm_tg.sh
if [ -z "${ChatID_1:-}" ]; then
    CLS
    echo -e "$Tip 在使用前请先设置 [${GR}CHAT ID${NC}] 用以接收通知信息."
    echo -e "$Tip [${REB}CHAT ID${NC}] 获取方法: 在 Telgram 中添加机器人 @userinfobot, 点击或输入: /start"
    echo -e "$Tip 您可以现在输入 CHAT ID，或者稍后通过选项 ${GR}0${NC} 进行设置"
    read -e -p "请输入你的 [CHAT ID] (回车跳过): " cahtid
    if [ ! -z "$cahtid" ]; then
        if [[ $cahtid =~ ^[0-9]+$ ]]; then
            writeini "ChatID_1" "$cahtid"
            ChatID_1=$cahtid
            echo -e "$Tip CHAT ID 设置成功!"
            # source $ConfigFile
        else
            echo -e "$Err ${REB}输入无效${NC}, Chat ID 必须是数字, 将跳过设置."
            echo -e "$Tip 您可以稍后通过选项 ${GR}0${NC} 重新设置."
            sleep 2
        fi
    else
        echo -e "$Tip 输入为空, 已跳过设置."
        echo -e "$Tip 您可以稍后通过选项 ${GR}0${NC} 进行设置."
        sleep 2
    fi
fi

if [ "${1:-}" == "mute" ] || [ "${2:-}" == "mute" ] || [ "${3:-}" == "mute" ]; then
    mute=true
else
    mute=false
fi

if [ "${1:-}" == "ok" ] || [ "${2:-}" == "ok" ] || [ "${3:-}" == "ok" ]; then
    OneKeydefault
    exit 0
fi

if [ "${1:-}" == "auto" ] || [ "${2:-}" == "auto" ] || [ "${3:-}" == "auto" ]; then
    autorun=true
    echo "自动模式..."
    init_config
    CheckSetup
    GetVPSInfo
    UN_ALL
    sleep 1

    mute=true
    Setuped=false
    if [ "$boot_menu_tag" == "$SETTAG" ] || [ "$login_menu_tag" == "$SETTAG" ] || [ "$shutdown_menu_tag" == "$SETTAG" ] || [ "$cpu_menu_tag" == "$SETTAG" ] || [ "$mem_menu_tag" == "$SETTAG" ] || [ "$disk_menu_tag" == "$SETTAG" ] || [ "$flow_menu_tag" == "$SETTAG" ] || [ "$flrp_menu_tag" == "$SETTAG" ] || [ "$docker_menu_tag" == "$SETTAG" ] || [ "$autoud_menu_tag" == "$SETTAG" ]; then
        Setuped=true
    fi
    if [ "$boot_menu_tag" == "$SETTAG" ]; then
        SetupBoot_TG
    fi
    if [ "$login_menu_tag" == "$SETTAG" ]; then
        SetupLogin_TG
    fi
    if [ "$shutdown_menu_tag" == "$SETTAG" ]; then
        SetupShutdown_TG
    fi
    if [ "$cpu_menu_tag" == "$SETTAG" ]; then
        SetupCPU_TG
    fi
    if [ "$mem_menu_tag" == "$SETTAG" ]; then
        SetupMEM_TG
    fi
    if [ "$disk_menu_tag" == "$SETTAG" ]; then
        SetupDISK_TG
    fi
    if [ "$flow_menu_tag" == "$SETTAG" ]; then
        SetupFlow_TG
    fi
    if [ "$flrp_menu_tag" == "$SETTAG" ]; then
        SetFlowReport_TG
    fi
    if [ "$docker_menu_tag" == "$SETTAG" ]; then
        SetupDocker_TG
    fi
    if [ "$autoud_menu_tag" == "$SETTAG" ]; then
        SetAutoUpdate
    fi
    # mute=false

    if [ "${1:-}" != "mute" ] && [ "${2:-}" != "mute" ] && [ "${3:-}" != "mute" ]; then
        if [[ "$boot_menu_tag" == "$SETTAG" || "$login_menu_tag" == "$SETTAG" || "$shutdown_menu_tag" == "$SETTAG" || "$cpu_menu_tag" == "$SETTAG" || "$mem_menu_tag" == "$SETTAG" || "$disk_menu_tag" == "$SETTAG" || "$flow_menu_tag" == "$SETTAG" || "$flrp_menu_tag" == "$SETTAG" || "$docker_menu_tag" == "$SETTAG" || "$autoud_menu_tag" == "$SETTAG" ]] && [[ "$Setuped" ]]; then
            current_date_send=$(date +"%Y.%m.%d %T")
            message="vpskeeper 脚本已更新 ♻️"$'\n'
            message+="主机名: $hostname_show"$'\n'
            message+="服务器时间: $current_date_send"
            $FolderPath/send_tg.sh "$TelgramBotToken" "$ChatID_1" "$message" &
        fi
    fi

    echo "自动模式执行完成."
    exit 0
else
    autorun=false
fi

if [ "${1:-}" == "test" ] || [ "${2:-}" == "test" ] || [ "${3:-}" == "test" ]; then
    init_config
    test
    exit 0
fi

tips=""

# 获取远程版本信息（异步）
get_remote_version_async() {
    local remote_version=""

    if command -v curl >/dev/null 2>&1; then
        remote_version=$(timeout 2 curl -s https://api.github.com/repos/redstarxxx/vpskeeper/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/' 2>/dev/null)
    fi

    if [ -z "$remote_version" ] && command -v wget >/dev/null 2>&1; then
        remote_version=$(timeout 2 wget -qO- https://api.github.com/repos/redstarxxx/vpskeeper/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/' 2>/dev/null)
    fi

    if [ -z "$remote_version" ]; then
        if command -v curl >/dev/null 2>&1; then
            remote_version=$(timeout 2 curl -s "https://raw.githubusercontent.com/redstarxxx/vpskeeper/main/lib/core.sh" | grep 'sh_ver=' | head -1 | cut -d'"' -f2 2>/dev/null)
        elif command -v wget >/dev/null 2>&1; then
            remote_version=$(timeout 2 wget -qO- "https://raw.githubusercontent.com/redstarxxx/vpskeeper/main/lib/core.sh" | grep 'sh_ver=' | head -1 | cut -d'"' -f2 2>/dev/null)
        fi
    fi

    remote_version=$(echo "$remote_version" | sed 's/^v//')

    echo "$remote_version"
}

# 获取远程版本（只在脚本开始时执行一次）
remote_version_info=""
if [ "${autorun:-false}" != "true" ] && [ "${mute:-false}" != "true" ]; then
    echo "正在检查远程版本..." >&2
    remote_version_info=$(get_remote_version_async)
fi

while true; do
CheckSetup
GetVPSInfo
readini
if [ -z "${CPUThreshold:-}" ]; then
    CPUThreshold_tag="${RE}未设置${NC}"
else
    CPUThreshold_tag="${GR}$CPUThreshold %${NC}"
fi
if [ -z "${MEMThreshold:-}" ]; then
    MEMThreshold_tag="${RE}未设置${NC}"
else
    MEMThreshold_tag="${GR}$MEMThreshold %${NC}"
fi
if [ -z "${DISKThreshold:-}" ]; then
    DISKThreshold_tag="${RE}未设置${NC}"
else
    DISKThreshold_tag="${GR}$DISKThreshold %${NC}"
fi
if [ -z "${FlowThreshold:-}" ]; then
    FlowThreshold_tag="${RE}未设置${NC}"
else
    FlowThreshold_tag="${GR}$FlowThreshold${NC}"
fi
if [ -z "${FlowThresholdMAX:-}" ]; then
    flowthm_menu_tag=""
else
    flowthm_menu_tag="${GRB}$FlowThresholdMAX${NC}"
fi
if [ -z "${SHUTDOWN_RT:-}" ] || [ "${SHUTDOWN_RT:-false}" = "false" ]; then
    sd_rt_menu_tag=""
else
    sd_rt_menu_tag="${GRB}SR${NC}"
fi
if [ -z "${ProxyURL:-}" ]; then
    proxy_menu_tag=""
else
    proxy_menu_tag="${GRB}Px${NC}"
fi
if [ -z "${SendUptime:-}" ] || [ "${SendUptime:-false}" = "false" ]; then
    senduptime_menu_tag=""
else
    senduptime_menu_tag="${GRB}UT${NC}"
fi
if [ -z "${SendIP:-}" ] || [ "${SendIP:-false}" = "false" ]; then
    sendip_menu_tag=""
else
    sendip_menu_tag="${GRB}IP${NC}"
fi
if [ -z "${SendPrice:-}" ] || [ "${SendPrice:-false}" = "false" ]; then
    sendprice_menu_tag=""
else
    sendprice_menu_tag="${GRB}Pi${NC}"
fi
if crontab -l | grep -q "$FolderPath/tg_ddnskp.sh"; then
    ddnskp_menu_tag="${GRB}K${NC}"
else
    ddnskp_menu_tag=""
fi
if [ -z "${WebhookEnabled:-}" ] || [ "$WebhookEnabled" == "false" ]; then
    webhook_menu_tag=""
else
    webhook_menu_tag="${GRB}Runing...${NC}"
fi



# Force_update

CLS
# 构建版本显示字符串
if [ -n "$remote_version_info" ]; then
    if [ "$remote_version_info" != "${sh_ver:-unknown}" ]; then
        version_display="${RE}[${sh_ver:-unknown}]${NC} ${YE}→ [${remote_version_info}]${NC}"
    else
        version_display="${GR}[${sh_ver:-unknown}]${NC} ${GR}✓${NC}"
    fi
else
    version_display="${RE}[${sh_ver:-unknown}]${NC} ${RED}?${NC}"
fi

echo && echo -e "${GR}VPS-TG${NC} 守护一键管理脚本 $version_display
-- tse | vtse.eu.org | ${release:-unknown} --
                        ${flowthm_menu_tag}             ${sd_rt_menu_tag} ${proxy_menu_tag} ${senduptime_menu_tag} ${sendip_menu_tag} ${sendprice_menu_tag}
 ${GR}0.${NC} 检查依赖 / 设置参数 \t${reset_menu_tag:-}
————————————————————————
 ${GR}1. ${NC} 设置 ${GR}[开机]${NC} TG 通知 \t\t\t${boot_menu_tag:-}
 ${GR}2. ${NC} 设置 ${GR}[登陆]${NC} TG 通知 \t\t\t${login_menu_tag:-}
 ${GR}3. ${NC} 设置 ${GR}[关机]${NC} TG 通知 \t\t\t${shutdown_menu_tag:-}
 ${GR}4. ${NC} 设置 ${GR}[CPU 报警]${NC} TG 通知 ${REB}阈值${NC} : $CPUThreshold_tag \t${cpu_menu_tag:-}
 ${GR}5. ${NC} 设置 ${GR}[内存报警]${NC} TG 通知 ${REB}阈值${NC} : $MEMThreshold_tag \t${mem_menu_tag:-}
 ${GR}6. ${NC} 设置 ${GR}[磁盘报警]${NC} TG 通知 ${REB}阈值${NC} : $DISKThreshold_tag \t${disk_menu_tag:-}
 ${GR}7. ${NC} 设置 ${GR}[流量报警]${NC} TG 通知 ${REB}阈值${NC} : $FlowThreshold_tag \t${flow_menu_tag:-}
 ${GR}8. ${NC} 设置 ${GR}[流量定时报告]${NC} TG 通知 \t\t${flrp_menu_tag:-}${NC}
 ${GR}9. ${NC} 设置 ${GR}[Docker 变更]${NC} TG 通知 \t\t${docker_menu_tag:-}${NC}
 ${GR}10.${NC} 设置 ${GR}[CF-DDNS IP 变更]${NC} TG 通知 ${ddnskp_menu_tag:-} \t\t${ddns_menu_tag:-}
  ————————————————————————————————————————————————————————
 ${GR}w.${NC} WEBHOOK - 配置 Webhook 地址 (Nginx) \t$webhook_menu_tag
 ————————————————————————————————————————————————————————
 ${GR}t.${NC} 测试 - 发送一条信息用以检验参数设置
 ————————————————————————————————————————————————————————
 ${GR}h.${NC} 修改 - 主机名 以此作为主机标记 \t${GR}${hostname_show:-unknown}${NC}
 ————————————————————————————————————————————————————————
 ${GR}o.${NC} ${GRB}一键${NC} ${GR}开启${NC} 所有通知
 ${GR}c.${NC} ${GRB}一键${NC} ${RE}取消 / 删除${NC} 所有通知
 ${GR}f.${NC} ${GRB}一键${NC} ${RE}删除${NC} 所有脚本子文件 \t\t${GR}${folder_menu_tag:-}${NC}
 ————————————————————————————————————————————————————————
 ${GR}u.${NC} 设置自动更新脚本 \t\t\t${autoud_menu_tag:-}
 ————————————————————————————————————————————————————————
 ${GR}v.${NC} 查看配置文件 (及部分隐藏指令)
 ${GR}x.${NC} 退出脚本
————————————"
if [ "$tips" = "" ]; then
    echo -e "$Tip 使用前先执行 0 进入参数设置, 启动后再次选择则为取消." && echo
else
    echo -e "$tips" && echo
fi
# 保持退格键功能，使用 -p 参数避免提示消失问题
read -e -p "请输入选项 [${GR}0-9${NC}|${GR}t${NC}|${GR}h${NC}|${GR}o${NC}|${GR}c${NC}|${GR}f${NC}|${GR}u${NC}|${GR}v${NC}|${GR}x${NC}] : " num
if [ -z "$num" ]; then echo; fi
case "$num" in
    0)
        init_config
        source $ConfigFile
        CheckRely
        SetupIniFile
        source $ConfigFile
    ;;
    1)
        init_config
        if [ "${boot_menu_tag:-}" == "${SETTAG:-}" ]; then
            UN_SetupBoot_TG
        else
            if SetupBoot_TG; then
                # 设置成功
                :
            else
                # 设置失败，检查是否是参数问题
                if [[ -z "${TelgramBotToken:-}" || -z "${ChatID_1:-}" ]]; then
                    tips="$Err 参数丢失, 请先执行选项 ${GR}0${NC} 设置 Bot Token 和 Chat ID."
                fi
            fi
        fi
    ;;
    2)
        init_config
        if [ "${login_menu_tag:-}" == "${SETTAG:-}" ]; then
            UN_SetupLogin_TG
        else
            if SetupLogin_TG; then
                # 设置成功
                :
            else
                # 设置失败，检查是否是参数问题
                if [[ -z "${TelgramBotToken:-}" || -z "${ChatID_1:-}" ]]; then
                    tips="$Err 参数丢失, 请先执行选项 ${GR}0${NC} 设置 Bot Token 和 Chat ID."
                fi
            fi
        fi
    ;;
    3)
        init_config
        if [ "${shutdown_menu_tag:-}" == "${SETTAG:-}" ]; then
            UN_SetupShutdown_TG
        else
            if SetupShutdown_TG; then
                # 设置成功
                :
            else
                # 设置失败，检查是否是参数问题
                if [[ -z "${TelgramBotToken:-}" || -z "${ChatID_1:-}" ]]; then
                    tips="$Err 参数丢失, 请先执行选项 ${GR}0${NC} 设置 Bot Token 和 Chat ID."
                fi
            fi
        fi
    ;;
    4)
        init_config
        if [ "${cpu_menu_tag:-}" == "${SETTAG:-}" ]; then
            UN_SetupCPU_TG
        else
            SetupCPU_TG
        fi
    ;;
    5)
        init_config
        if [ "${mem_menu_tag:-}" == "${SETTAG:-}" ]; then
            UN_SetupMEM_TG
        else
            SetupMEM_TG
        fi
    ;;
    6)
        init_config
        if [ "${disk_menu_tag:-}" == "${SETTAG:-}" ]; then
            UN_SetupDISK_TG
        else
            SetupDISK_TG
        fi
    ;;
    7)
        init_config
        if [ "${flow_menu_tag:-}" == "${SETTAG:-}" ]; then
            UN_SetupFlow_TG
        else
            SetupFlow_TG
        fi
    ;;
    8)
        init_config
        if [ "${flrp_menu_tag:-}" == "${SETTAG:-}" ]; then
            UN_SetFlowReport_TG
        else
            SetFlowReport_TG
        fi
    ;;
    9)
        init_config
        if [ "${docker_menu_tag:-}" == "${SETTAG:-}" ]; then
            UN_SetupDocker_TG
        else
            SetupDocker_TG
        fi
    ;;
    10)
        init_config
        if [ "${ddns_menu_tag:-}" == "${SETTAG:-}" ]; then
            UN_SetupDDNS_TG
        else
            SetupDDNS_TG
        fi
    ;;
    w|W)
        init_config
        main_menu
        # if [ "$webhook_menu_tag" == "$SETTAG" ]; then
        #     UN_SetupWebhook_TG
        # else
        #     SetupWebhook_TG
        # fi
    ;;
    t|T)
        init_config
        test
    ;;
    t1)
        init_config
        test1
    ;;
    h|H)
        ModifyHostname
    ;;
    o|O)
        OneKeydefault
    ;;
    c|C)
        echo -e "${GRB}卸载前${NC}:"
        # if ps x > /dev/null 2>&1; then
        #     ps x | grep '[t]g_'
        # else
        #     ps | grep '[t]g_'
        # fi
        pgrep -af 'tg_' | grep -v grep
        divline
        un_tag=true
        UN_ALL
        un_tag=false
        echo -e "${GRB}卸载后${NC}:"
        # if ps x > /dev/null 2>&1; then
        #     ps x | grep '[t]g_'
        # else
        #     ps | grep '[t]g_'
        # fi
        pgrep -af 'tg_' | grep -v grep
        divline
        Pause
    ;;
    f|F)
        DELFOLDER
    ;;
    u|U)
        init_config
        if [ "${autoud_menu_tag:-}" == "${SETTAG:-}" ]; then
            UN_SetAutoUpdate
        else
            SetAutoUpdate
        fi
    ;;
    v|V)
        # 查看配置文件
        divline
        echo -e "${GRB}文件参数:${NC}"
        cat $ConfigFile
        divline
        echo -e "${GRB}调试指令:${NC}"
        echo -e "l     - 查看log日志文件"
        echo -e "lt    - 追踪查看log日志文件"
        echo -e "ld    - 删除log日志文件"
        echo -e "vs    - 查看service文件"
        echo -e "s     - 实时网速 (普通模式)"
        echo -e "ss    - 实时网速 (科学统计模式，含TCP/UDP连接数)"
        echo -e "vb    - 查询后台执行中的 tg_"
        echo -e "vc    - 查询 crontab 中的 tg_"
        echo -e "ud    - 手动更新脚本 (国内先设置代理)"
        divline
        Pause
    ;;
    vb)
        # 查看配置文件
        divline
        echo -e "${GRB}后台:${NC}"
        # if ps x > /dev/null 2>&1; then
        #     # ps x | grep '[t]g_'
        #     ps x | grep 'tg_' | grep -v grep
        #     # ps x | grep 'tg_' | grep -v grep | awk '{print $1}'
        #     # ps x | grep 'tg_' | grep -v grep | awk '{print $NF}'
        #     # ps x | awk '/tg_/ && !/awk/ && !/grep/ {print "   " $1 "\t" $NF}'
        #     # pgrep -a 'tg_'
        # else
        #     ps | grep 'tg_' | grep -v grep
        # fi
        # 使用通用进程查找函数
        universal_pgrep 'tg_' true
        divline
        Pause
    ;;
    vc)
        divline
        echo -e "${GRB}Crontab:${NC}"
        # crontab -l | grep '[t]g_'
        crontab -l | grep 'tg_' | grep -v grep
        divline
        Pause
    ;;
    ld)
        DELLOGFILE
    ;;
    l)
        VIEWLOG
    ;;
    lt)
        T_VIEWLOG
    ;;
    vs)
        VIEWSERVICE
    ;;
    s)
        ss_s=""
        T_NETSPEED
    ;;
    ss)
        ss_s="st"
        T_NETSPEED
    ;;
    ud)
        update_sh
    ;;
    x|X)
        exit 0
    ;;
    *)
        tips="$Err 请输入正确数字或字母."
    ;;
esac
done
# END
