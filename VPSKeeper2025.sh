#!/usr/bin/env bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

#=======================================================
#	System Required: CentOS/Debian/Ubuntu/OpenWRT/Alpine/RHEL
#	Description: VPS keeper for telgram
#	Version: $sh_ver
#	Author: tse
#	Blog: https://vtse.eu.org
#=======================================================

# 检查基本命令是否存在
for cmd in basename awk sed grep cut tr; do
    if ! command -v $cmd >/dev/null 2>&1; then
        echo "Error: $cmd is not installed"
        exit 1
    fi
done

# 颜色代码 (增加对tput的支持)
if command -v tput >/dev/null 2>&1; then
    GR="$(tput setaf 2)"
    RE="$(tput setaf 1)"
    GRB="$(tput setab 2)$(tput setaf 7)"
    REB="$(tput setab 1)$(tput setaf 7)"
    NC="$(tput sgr0)"
else
    GR="\033[32m"
    RE="\033[31m"
    GRB="\033[42;37m"
    REB="\033[41;37m"
    NC="\033[0m"
fi

Inf="${GR}[信息]${NC}:"
Err="${RE}[错误]${NC}:"
Tip="${GR}[提示]${NC}:"
SETTAG="${GR}-> 已设置${NC}"
UNSETTAG="${RE}-> 未设置${NC}"

# 脚本版本号
sh_ver="1.250331.1"

# 基本参数
SHURL="https://raw.githubusercontent.com/redstarxxx/shell/2025"
SHURL_PROXY="https://xx80.eu.org/p/$SHURL"
FolderPath="/$HOME/.shfile"
ConfigFile="$FolderPath/TelgramBot.ini"
BOTToken_de="6718888288:AAG5aVWV4FCmS0ItoPy1-3KkhdNg8eym5AM"
CPUTools_de="top"
CPUThreshold_de="80"
MEMThreshold_de="80"
DISKThreshold_de="80"
FlowThreshold_de="3GB"
FlowThresholdMAX_de="500GB"
ReportTime_de="00:00"
AutoUpdateTime_de="01:01"

WebhookPort="5000"
WebhookPath="/webhook"
WebhookURL=""
TGWhConf="/etc/nginx/conf.d/tgwh.conf"
WebhookSecret=""
WebhookEnabled="false"
VenvPath="$FolderPath/.webhook"

# 载入函数库
#=======================================================
if [ ! -d "$FolderPath" ]; then
    mkdir -p "$FolderPath"
fi
if [ ! -f "$FolderPath/.common.sh" ]; then
    curl -o $FolderPath/.common.sh https://raw.githubusercontent.com/redstarxxx/shell/2025/.common.sh && chmod +x .common.sh
    if [ ! -f "$FolderPath/.common.sh" ]; then
        # 如果无法从 GitHub 获取文件，则尝试备用链接
        curl -o $FolderPath/.common.sh https://xx80.eu.org/p/https://raw.githubusercontent.com/redstarxxx/shell/2025/.common.sh && chmod +x .common.sh
        if [ ! -f "$FolderPath/.common.sh" ]; then
            echo -e "${Err} 无法下载 common.sh 函数库，请检查网络或手动下载。"
            exit 1
        fi
    fi
    echo -e "${Inf} 成功下载并安装函数库 ${GR}.common.sh${NC}"
fi
source $FolderPath/.common.sh
#=======================================================

if ! check_root; then
    exit 1
fi

# 检查系统必需命令
required_commands=(curl wget ip sed awk grep)
missing_commands=()

for cmd in "${required_commands[@]}"; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        missing_commands+=("$cmd")
    fi
done

if [ ${#missing_commands[@]} -ne 0 ]; then
    echo "${Err} 以下必需命令未安装: ${missing_commands[*]}"
    echo "${Tip} 请安装缺失的命令后再运行脚本"
    exit 1
fi

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

rm -f "$FolderPath/send_tg*.log" > /dev/null 2>&1
if [ ! -f "$FolderPath/tg_flrp.sh" ]; then
    mv "$FolderPath/tg_flowrp.sh" "$FolderPath/tg_flrp.sh" > /dev/null 2>&1
else
    rm -f "$FolderPath/tg_flowrp.sh" > /dev/null 2>&1
fi
rm -f "$FolderPath/tg_flowrp.log" > /dev/null 2>&1

CheckSys
if [[ "$1" =~ ^[0-9]{5,}$ ]]; then
    ChatID_1="$1"
    writeini "ChatID_1" "$1"
elif [[ "$2" =~ ^[0-9]{5,}$ ]]; then
    ChatID_1="$2"
    writeini "ChatID_1" "$2"
elif [[ "$3" =~ ^[0-9]{5,}$ ]]; then
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
if [ -z "$ChatID_1" ]; then
    CLS
    echo -e "$Tip 在使用前请先设置 [${GR}CHAT ID${NC}] 用以接收通知信息."
    echo -e "$Tip [${REB}CHAT ID${NC}] 获取方法: 在 Telgram 中添加机器人 @userinfobot, 点击或输入: /start"
    read -e -p "请输入你的 [CHAT ID] : " cahtid
    if [ ! -z "$cahtid" ]; then
        if [[ $cahtid =~ ^[0-9]+$ ]]; then
            writeini "ChatID_1" "$cahtid"
            ChatID_1=$cahtid
            # source $ConfigFile
        else
            echo -e "$Err ${REB}输入无效${NC}, Chat ID 必须是数字, 退出操作."
            exit 1
        fi
    else
        echo -e "$Tip 输入为空, 退出操作."
        exit 1
    fi
fi

if [ "$1" == "mute" ] || [ "$2" == "mute" ] || [ "$3" == "mute" ]; then
    mute=true
else
    mute=false
fi

if [ "$1" == "ok" ] || [ "$2" == "ok" ] || [ "$3" == "ok" ]; then
    OneKeydefault
    exit 0
fi

if [ "$1" == "auto" ] || [ "$2" == "auto" ] || [ "$3" == "auto" ]; then
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

    if [ "$1" != "mute" ] && [ "$2" != "mute" ] && [ "$3" != "mute" ]; then
        if [[ "$boot_menu_tag" == "$SETTAG" || "$login_menu_tag" == "$SETTAG" || "$shutdown_menu_tag" == "$SETTAG" || "$cpu_menu_tag" == "$SETTAG" || "$mem_menu_tag" == "$SETTAG" || "$disk_menu_tag" == "$SETTAG" || "$flow_menu_tag" == "$SETTAG" || "$flrp_menu_tag" == "$SETTAG" || "$docker_menu_tag" == "$SETTAG" || "$autoud_menu_tag" == "$SETTAG" ]] && [[ "$Setuped" ]]; then
            current_date_send=$(date +"%Y.%m.%d %T")
            message="VPSKeeper 脚本已更新 ♻️"$'\n'
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

if [ "$1" == "test" ] || [ "$2" == "test" ] || [ "$3" == "test" ]; then
    init_config
    test
    exit 0
fi

tips=""

while true; do
CheckSetup
GetVPSInfo
readini
if [ -z "$CPUThreshold" ]; then
    CPUThreshold_tag="${RE}未设置${NC}"
else
    CPUThreshold_tag="${GR}$CPUThreshold %${NC}"
fi
if [ -z "$MEMThreshold" ]; then
    MEMThreshold_tag="${RE}未设置${NC}"
else
    MEMThreshold_tag="${GR}$MEMThreshold %${NC}"
fi
if [ -z "$DISKThreshold" ]; then
    DISKThreshold_tag="${RE}未设置${NC}"
else
    DISKThreshold_tag="${GR}$DISKThreshold %${NC}"
fi
if [ -z "$FlowThreshold" ]; then
    FlowThreshold_tag="${RE}未设置${NC}"
else
    FlowThreshold_tag="${GR}$FlowThreshold${NC}"
fi
if [ -z "$FlowThresholdMAX" ]; then
    flowthm_menu_tag=""
else
    flowthm_menu_tag="${GRB}$FlowThresholdMAX${NC}"
fi
if [ -z $SHUTDOWN_RT ] || [ "$SHUTDOWN_RT" == "false" ]; then
    sd_rt_menu_tag=""
else
    sd_rt_menu_tag="${GRB}SR${NC}"
fi
if [ -z "$ProxyURL" ]; then
    proxy_menu_tag=""
else
    proxy_menu_tag="${GRB}Px${NC}"
fi
if [ -z $SendUptime ] || [ "$SendUptime" == "false" ]; then
    senduptime_menu_tag=""
else
    senduptime_menu_tag="${GRB}UT${NC}"
fi
if [ -z $SendIP ] || [ "$SendIP" == "false" ]; then
    sendip_menu_tag=""
else
    sendip_menu_tag="${GRB}IP${NC}"
fi
if [ -z $SendPrice ] || [ "$SendPrice" == "false" ]; then
    sendprice_menu_tag=""
else
    sendprice_menu_tag="${GRB}Pi${NC}"
fi
if crontab -l | grep -q "$FolderPath/tg_ddnskp.sh"; then
    ddnskp_menu_tag="${GRB}K${NC}"
else
    ddnskp_menu_tag=""
fi
if [ -z "$WebhookEnabled" ] || [ "$WebhookEnabled" == "false" ]; then
    webhook_menu_tag=""
else
    webhook_menu_tag="${GRB}Runing...${NC}"
fi

# Force_update

CLS
echo && echo -e "${GR}VPS-TG${NC} 守护一键管理脚本 ${RE}[v${sh_ver}]${NC}
-- tse | vtse.eu.org | $release --
                        ${flowthm_menu_tag}             ${sd_rt_menu_tag} ${proxy_menu_tag} ${senduptime_menu_tag} ${sendip_menu_tag} ${sendprice_menu_tag}
 ${GR}0.${NC} 检查依赖 / 设置参数 \t$reset_menu_tag
————————————————————————
 ${GR}1. ${NC} 设置 ${GR}[开机]${NC} TG 通知 \t\t\t$boot_menu_tag
 ${GR}2. ${NC} 设置 ${GR}[登陆]${NC} TG 通知 \t\t\t$login_menu_tag
 ${GR}3. ${NC} 设置 ${GR}[关机]${NC} TG 通知 \t\t\t$shutdown_menu_tag
 ${GR}4. ${NC} 设置 ${GR}[CPU 报警]${NC} TG 通知 ${REB}阈值${NC} : $CPUThreshold_tag \t$cpu_menu_tag
 ${GR}5. ${NC} 设置 ${GR}[内存报警]${NC} TG 通知 ${REB}阈值${NC} : $MEMThreshold_tag \t$mem_menu_tag
 ${GR}6. ${NC} 设置 ${GR}[磁盘报警]${NC} TG 通知 ${REB}阈值${NC} : $DISKThreshold_tag \t$disk_menu_tag
 ${GR}7. ${NC} 设置 ${GR}[流量报警]${NC} TG 通知 ${REB}阈值${NC} : $FlowThreshold_tag \t$flow_menu_tag
 ${GR}8. ${NC} 设置 ${GR}[流量定时报告]${NC} TG 通知 \t\t$flrp_menu_tag${NC}
 ${GR}9. ${NC} 设置 ${GR}[Docker 变更]${NC} TG 通知 \t\t$docker_menu_tag${NC}
 ${GR}10.${NC} 设置 ${GR}[CF-DDNS IP 变更]${NC} TG 通知 $ddnskp_menu_tag \t\t$ddns_menu_tag
  ————————————————————————————————————————————————————————
 ${GR}w.${NC} WEBHOOK - 配置 Webhook 地址 (Nginx) \t$webhook_menu_tag
 ————————————————————————————————————————————————————————
 ${GR}t.${NC} 测试 - 发送一条信息用以检验参数设置
 ————————————————————————————————————————————————————————
 ${GR}h.${NC} 修改 - 主机名 以此作为主机标记 \t${GR}$hostname_show${NC}
 ————————————————————————————————————————————————————————
 ${GR}o.${NC} ${GRB}一键${NC} ${GR}开启${NC} 所有通知
 ${GR}c.${NC} ${GRB}一键${NC} ${RE}取消 / 删除${NC} 所有通知
 ${GR}f.${NC} ${GRB}一键${NC} ${RE}删除${NC} 所有脚本子文件 \t\t${GR}$folder_menu_tag${NC}
 ————————————————————————————————————————————————————————
 ${GR}u.${NC} 设置自动更新脚本 \t\t\t$autoud_menu_tag
 ————————————————————————————————————————————————————————
 ${GR}v.${NC} 查看配置文件 (及部分隐藏指令)
 ${GR}x.${NC} 退出脚本
————————————"
if [ "$tips" = "" ]; then
    echo -e "$Tip 使用前先执行 0 进入参数设置, 启动后再次选择则为取消." && echo
else
    echo -e "$tips" && echo
fi
echo -en "请输入选项 [${GR}0-9${NC}|${GR}t${NC}|${GR}h${NC}|${GR}o${NC}|${GR}c${NC}|${GR}f${NC}|${GR}u${NC}|${GR}v${NC}|${GR}x${NC}] : "
read -er num
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
        if [ "$boot_menu_tag" == "$SETTAG" ]; then
            UN_SetupBoot_TG
        else
            SetupBoot_TG
        fi
    ;;
    2)
        init_config
        if [ "$login_menu_tag" == "$SETTAG" ]; then
            UN_SetupLogin_TG
        else
            SetupLogin_TG
        fi
    ;;
    3)
        init_config
        if [ "$shutdown_menu_tag" == "$SETTAG" ]; then
            UN_SetupShutdown_TG
        else
            SetupShutdown_TG
        fi
    ;;
    4)
        init_config
        if [ "$cpu_menu_tag" == "$SETTAG" ]; then
            UN_SetupCPU_TG
        else
            SetupCPU_TG
        fi
    ;;
    5)
        init_config
        if [ "$mem_menu_tag" == "$SETTAG" ]; then
            UN_SetupMEM_TG
        else
            SetupMEM_TG
        fi
    ;;
    6)
        init_config
        if [ "$disk_menu_tag" == "$SETTAG" ]; then
            UN_SetupDISK_TG
        else
            SetupDISK_TG
        fi
    ;;
    7)
        init_config
        if [ "$flow_menu_tag" == "$SETTAG" ]; then
            UN_SetupFlow_TG
        else
            SetupFlow_TG
        fi
    ;;
    8)
        init_config
        if [ "$flrp_menu_tag" == "$SETTAG" ]; then
            UN_SetFlowReport_TG
        else
            SetFlowReport_TG
        fi
    ;;
    9)
        init_config
        if [ "$docker_menu_tag" == "$SETTAG" ]; then
            UN_SetupDocker_TG
        else
            SetupDocker_TG
        fi
    ;;
    10)
        init_config
        if [ "$ddns_menu_tag" == "$SETTAG" ]; then
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
        if [ "$autoud_menu_tag" == "$SETTAG" ]; then
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
        echo -e "s     - 实时网速"
        echo -e "ss    - 实时网速(科学统计)"
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
        pgrep -af 'tg_' | grep -v grep
        divline
        Pause
    ;;
    vc)
        # 查看配置文件
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
