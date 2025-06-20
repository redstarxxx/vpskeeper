#!/usr/bin/env bash

#=======================================================
# VPSKeeper 核心函数库
# 功能: 基础函数 + 配置管理 + 系统检查 + 进程管理
# 整合自: base.sh + config.sh + 部分 dataTools.sh + 部分 tools.sh
#=======================================================

# 启用严格模式（部分，不包括 -e 以避免非关键命令失败导致脚本退出）
set -uo pipefail
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

# 脚本版本号
sh_ver="1.2500616.1"

# 基本参数配置
SHURL="https://raw.githubusercontent.com/redstarxxx/shell/2025"
SHURL_PROXY="https://xx80.eu.org/p/$SHURL"
FolderPath="/opt/vpskeeper/runtime"
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

# Webhook 配置
WebhookPort="5000"
WebhookPath="/webhook"
WebhookURL=""
TGWhConf="/etc/nginx/conf.d/tgwh.conf"
WebhookSecret=""
WebhookEnabled="false"
VenvPath="$FolderPath/.webhook"

# 系统信息
release=""
systemPackage=""
systempwd=""

# 检查系统类型
check_sys() {
    if [ -f /etc/redhat-release ]; then
        release="centos"
        systemPackage="yum"
        systempwd="/usr/lib/systemd/system/"
    elif cat /etc/issue | grep -Eqi "debian"; then
        release="debian"
        systemPackage="apt"
        systempwd="/lib/systemd/system/"
    elif cat /etc/issue | grep -Eqi "ubuntu"; then
        release="ubuntu"
        systemPackage="apt"
        systempwd="/lib/systemd/system/"
    elif cat /etc/issue | grep -Eqi "centos|red hat|redhat"; then
        release="centos"
        systemPackage="yum"
        systempwd="/usr/lib/systemd/system/"
    elif cat /proc/version | grep -Eqi "debian"; then
        release="debian"
        systemPackage="apt"
        systempwd="/lib/systemd/system/"
    elif cat /proc/version | grep -Eqi "ubuntu"; then
        release="ubuntu"
        systemPackage="apt"
        systempwd="/lib/systemd/system/"
    elif cat /proc/version | grep -Eqi "centos|red hat|redhat"; then
        release="centos"
        systemPackage="yum"
        systempwd="/usr/lib/systemd/system/"
    else
        release="unknown"
        systemPackage="unknown"
        systempwd="/lib/systemd/system/"
    fi
}

# 检测系统 (别名，保持向后兼容)
CheckSys() {
    if [[ -f /etc/redhat-release ]]; then
        release="centos"
    elif cat /etc/issue 2>/dev/null | grep -q -E -i "debian"; then
        release="debian"
    elif cat /etc/issue 2>/dev/null | grep -q -E -i "ubuntu"; then
        release="ubuntu"
    elif cat /etc/issue 2>/dev/null | grep -q -E -i "centos|red hat|redhat"; then
        release="centos"
    elif cat /etc/issue 2>/dev/null | grep -q -E -i "Armbian"; then
        release="Armbian"
    elif cat /proc/version 2>/dev/null | grep -q -E -i "debian"; then
        release="debian"
    elif cat /proc/version 2>/dev/null | grep -q -E -i "ubuntu"; then
        release="ubuntu"
    elif cat /proc/version 2>/dev/null | grep -q -E -i "centos|red hat|redhat"; then
        release="centos"
    elif cat /proc/version 2>/dev/null | grep -q -E -i "openwrt"; then
        release="openwrt"
    else
        release="unknown"
    fi
}

# 清屏函数
CLS() {
    clear
}

# 暂停函数
Pause() {
    # echo ""
    echo -e "${YELLOW}按任意键继续...${NC}"
    # read -n 1 -r
    read -n 1 -s -r -p ""
}

# 添加 crontab 任务
addcrontab() {
    local cron_job="$1"
    if [ -z "$cron_job" ]; then
        echo -e "${RED}错误: crontab 任务不能为空${NC}"
        return 1
    fi

    # 检查任务是否已存在
    if crontab -l 2>/dev/null | grep -Fq "$cron_job"; then
        echo -e "${YELLOW}crontab 任务已存在${NC}"
        return 0
    fi

    # 添加任务
    (crontab -l 2>/dev/null; echo "$cron_job") | crontab -
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}crontab 任务添加成功${NC}"
    else
        echo -e "${RED}crontab 任务添加失败${NC}"
        return 1
    fi
}

# 删除 crontab 任务
delcrontab() {
    local pattern="$1"
    if [ -z "$pattern" ]; then
        echo -e "${RED}错误: 删除模式不能为空${NC}"
        return 1
    fi

    crontab -l 2>/dev/null | grep -v "$pattern" | crontab -
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}crontab 任务删除成功${NC}"
    else
        echo -e "${RED}crontab 任务删除失败${NC}"
        return 1
    fi
}

# 写入配置文件
writeini() {
    local key="$1"
    local value="$2"
    local file="${3:-$ConfigFile}"

    if [ -z "$key" ]; then
        echo -e "${RED}错误: 配置键不能为空${NC}"
        return 1
    fi

    # 确保配置文件存在
    if [ ! -f "$file" ]; then
        touch "$file"
    fi

    # 删除已存在的键
    sed -i "/^$key=/d" "$file"

    # 添加新的键值对
    echo "$key=\"$value\"" >> "$file"
}

# 读取配置文件
readini() {
    if [ -f "$ConfigFile" ]; then
        source "$ConfigFile"
    fi
}

# 删除ini文件指定行
delini() {
    sed -i "/^$1=/d" $ConfigFile
}

# 创建配置目录
init_config() {
    if [ ! -d "$FolderPath" ]; then
        mkdir -p "$FolderPath" || {
            echo -e "$Err 无法创建配置目录: $FolderPath"
            exit 1
        }
    fi
    if [ -f $ConfigFile ]; then
        source $ConfigFile
    else
        # 创建默认配置
        TelgramBotToken_de=""
        CPUTools_de="top"
        FlowThresholdMAX_de="500GB"

        writeini "TelgramBotToken" "$BOTToken_de"
        writeini "CPUTools" "$CPUTools_de"
        writeini "FlowThresholdMAX" "$FlowThresholdMAX_de"
        writeini "SHUTDOWN_RT" "false"
        hostname_show=$(hostname)
        writeini "hostname_show" "$hostname_show"
        writeini "ProxyURL" ""
        writeini "SendUptime" "false"
        writeini "SendIP" "false"
        writeini "GetIPURL" "ip.sb"
        writeini "GetIP46" "4"
        writeini "SendPrice" "false"
        writeini "GetPriceType" "bitcoin"
        writeini "WebhookEnabled" "false"
        writeini "WebhookURL" ""
        writeini "SSLCertPath" ""
        writeini "SSLKeyPath" ""
        writeini "GeminiAPIKey" ""

        source $ConfigFile
    fi
}

# 检查命令是否存在
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# 安装包
install_package() {
    local package="$1"
    if [ -z "$package" ]; then
        echo -e "${RED}错误: 包名不能为空${NC}"
        return 1
    fi

    case $systemPackage in
        "yum")
            yum install -y "$package"
            ;;
        "apt")
            apt-get update && apt-get install -y "$package"
            ;;
        *)
            echo -e "${RED}不支持的包管理器: $systemPackage${NC}"
            return 1
            ;;
    esac
}

# 检查并安装依赖
check_dependencies() {
    # 确保颜色变量已定义
    if [ -z "${YELLOW:-}" ]; then
        YELLOW='\033[1;33m'
    fi
    if [ -z "${NC:-}" ]; then
        NC='\033[0m'
    fi

    local deps=("curl" "wget" "crontab")
    local missing_deps=()

    for dep in "${deps[@]}"; do
        if ! command_exists "$dep"; then
            missing_deps+=("$dep")
        fi
    done

    if [ ${#missing_deps[@]} -gt 0 ]; then
        echo -e "${YELLOW}缺少依赖: ${missing_deps[*]}${NC}"
        echo -e "${YELLOW}正在安装...${NC}"

        for dep in "${missing_deps[@]}"; do
            install_package "$dep"
        done
    fi
}

# 获取系统信息
get_system_info() {
    # 获取系统版本
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS_NAME="$NAME"
        OS_VERSION="$VERSION"
    else
        OS_NAME="Unknown"
        OS_VERSION="Unknown"
    fi

    # 获取内核版本
    KERNEL_VERSION=$(uname -r)

    # 获取架构
    ARCH=$(uname -m)

    # 获取运行时间
    UPTIME=$(uptime -p 2>/dev/null || uptime)
}

# 初始化系统
init_system() {
    check_sys
    init_config
    check_dependencies
    get_system_info
}

# 错误处理
error_exit() {
    echo -e "${RED}错误: $1${NC}" >&2
    exit 1
}

# 成功信息
success_msg() {
    echo -e "${GREEN}成功: $1${NC}"
}

# 警告信息
warning_msg() {
    # 确保颜色变量已定义
    if [ -z "${YELLOW:-}" ]; then
        YELLOW='\033[1;33m'
    fi
    if [ -z "${NC:-}" ]; then
        NC='\033[0m'
    fi
    echo -e "${YELLOW}警告: $1${NC}"
}

# 信息输出
info_msg() {
    echo -e "${BLUE}信息: $1${NC}"
}

# 获取VPS信息
GetVPSInfo() {
    cpu_total=""
    cpu_used=""
    if [ -x "$(command -v lscpu)" ]; then
        cpu_total=$(lscpu | grep "^CPU(s):" | awk '{print $2}')
    fi
    cpu_used=$(cat /proc/cpuinfo | grep "^core id" | wc -l)
    if [ "$cpu_total" == "" ]; then
        cpuusedOfcpus=$cpu_used
    elif [ "$cpu_used" == "$cpu_total" ]; then
        cpuusedOfcpus=$cpu_total
    else
        cpuusedOfcpus=$(cat /proc/cpuinfo | grep "^core id" | wc -l)/$(lscpu | grep "^CPU(s):" | awk '{print $2}')
    fi

    mem_total_bytes=$(free | grep 'Mem:' | awk '{print int($2)}')
    mem_total=$((mem_total_bytes / 1024))
    swap_total_bytes=$(free | grep 'Swap:' | awk '{print int($2)}')
    swap_total=$((swap_total_bytes / 1024))
    disk_total=$(df -h / | awk 'NR==2 {print $2}')
    disk_used=$(df -h / | awk 'NR==2 {print $3}')
}

# 检查并安装依赖
CheckRely() {
    echo "检查并安装依赖..."
    if cat /proc/version 2>/dev/null | grep -q -E -i "openwrt"; then
        echo "OpenWRT 系统跳过依赖检测..."
    else
        declare -a dependencies=("sed" "grep" "awk" "hostnamectl" "systemd" "curl")
        missing_dependencies=()
        for dep in "${dependencies[@]}"; do
            if ! command -v "$dep" &>/dev/null; then
                missing_dependencies+=("$dep")
            fi
        done
        if [ ${#missing_dependencies[@]} -gt 0 ]; then
            echo -e "$Tip 以下依赖未安装: ${missing_dependencies[*]}"
            read -e -p "是否要安装依赖 Y/其它 : " yorn
            if [ "$yorn" == "Y" ] || [ "$yorn" == "y" ]; then
                echo "正在安装缺失的依赖..."
                if [ -x "$(command -v apt)" ]; then
                    apt install -y "${missing_dependencies[@]}"
                elif [ -x "$(command -v yum)" ]; then
                    yum install -y "${missing_dependencies[@]}"
                else
                    echo -e "$Err 无法安装依赖, 未知的包管理器或系统版本不支持, 请手动安装所需依赖."
                    exit 1
                fi
            else
                echo -e "$Tip 已跳过安装."
            fi
        else
            echo -e "$Tip 所有依赖已安装."
        fi
    fi
}

# 修改Hostname
ModifyHostname() {
    echo "当前 主机名 : $hostname_show"
    read -e -p "请输入要修改的 主机名 (回车跳过): " name
    if [[ ! -z "${name}" ]]; then
        hostname_show="$name"
        writeini "hostname_show" "$name"
        source $ConfigFile
        if command -v hostnamectl &>/dev/null; then
            read -e -p "是否要将 Hostmane 修改成 $hostname_show  Y/回车跳过 : " yorn
            if [ "$yorn" == "Y" ] || [ "$yorn" == "y" ]; then
                echo "修改 hosts 和 hostname..."
                sed -i "s/$hostname_show/$name/g" /etc/hosts
                echo -e "$name" > /etc/hostname
                hostnamectl set-hostname $name
            fi
            tips="$Tip 修改后 主机名 : $hostname_show  Hostname: $(hostname)"
        else
            tips="$Tip 修改后 主机名: $hostname_show, 但未检测到 hostnamectl, 无法修改 Hostname."
        fi
    else
        tips="$Tip 输入为空, 跳过操作."
    fi
}

# CPU检测函数
CheckCPU_top() {
    echo "正在检测 CPU 使用率..."
    if top -bn 1 | grep '^%Cpu(s)'; then
        cpu_usage_ratio=$(awk '{ gsub(/us,|sy,|ni,|id,|:/, " ", $0); idle+=$5; count++ } END { printf "%.2f", 100 - (idle / count) }' <(grep "Cpu(s)" <(top -bn5 -d 3)))
    fi
    if top -bn 1 | grep -q '^CPU'; then
        cpu_usage_ratio=$(top -bn5 -d 3 | grep '^CPU' | awk '{ idle+=$8; count++ } END { printf "%.2f", 100 - (idle / count) }')
    fi
    echo "top检测结果: $cpu_usage_ratio | 日期: $(date)"
}

CheckCPU_sar() {
    echo "正在检测 CPU 使用率..."
    cpu_usage_ratio=$(sar -u 3 5 | awk '/^Average:/ { printf "%.2f", 100 - $NF }')
    echo "sar检测结果: $cpu_usage_ratio | 日期: $(date)"
}

CheckCPU_top_sar() {
    echo "正在检测 CPU 使用率..."
    cpu_usage_sar=$(sar -u 3 5 | awk '/^Average:/ { printf "%.0f", 100 - $NF }')
    cpu_usage_top=$(awk '{ gsub(/us,|sy,|ni,|id,|:/, " ", $0); idle+=$5; count++ } END { printf "%.0f", 100 - (idle / count) }' <(grep "Cpu(s)" <(top -bn5 -d 3)))
    cpu_usage_ratio=$(awk -v sar="$cpu_usage_sar" -v top="$cpu_usage_top" 'BEGIN { printf "%.2f", (sar + top) / 2 }')
    echo "sar检测结果: $cpu_usage_sar | top检测结果: $cpu_usage_top | 平均值: $cpu_usage_ratio | 日期: $(date)"
}

# 获取系统信息
GetInfo_now() {
    echo "正在获取系统信息..."
    top_output=$(top -bn 1 | head -n 10)
    if echo "$top_output" | grep -q "^%Cpu"; then
        top_output_h=$(echo "$top_output" | awk 'NR > 7')
        cpu_h1=$(echo "$top_output_h" | awk 'NR == 1 || $9 > max { max = $9; process = $NF } END { print process }')
        cpu_h2=$(echo "$top_output_h" | awk 'NR == 2 || $9 > max { max = $9; process = $NF } END { print process }')
    elif echo "$top_output" | grep -q "^CPU"; then
        top_output_h=$(echo "$top_output" | awk 'NR > 4')
        cpu_h1=$(echo "$top_output_h" | awk 'NR == 1 || $7 > max { max = $7; process = $8 } END { print process }' | awk '{print $1}')
        cpu_h2=$(echo "$top_output_h" | awk 'NR == 2 || $7 > max { max = $7; process = $8 } END { print process }' | awk '{print $1}')
    else
        echo "top 指令获取信息失败."
    fi
    mem_total_bytes=$(free | grep 'Mem:' | awk '{print int($2)}')
    mem_used_bytes=$(free | grep 'Mem:' | awk '{print int($3)}')
    mem_use_ratio=$(awk -v used="$mem_used_bytes" -v total="$mem_total_bytes" 'BEGIN { printf "%.2f", ( used / total ) * 100 }')
    swap_total_bytes=$(free | grep 'Swap:' | awk '{print int($2)}')
    swap_used_bytes=$(free | grep 'Swap:' | awk '{print int($3)}')
    if [ $swap_total_bytes -eq 0 ]; then
        swap_use_ratio=0
    else
        swap_use_ratio=$(awk -v used="$swap_used_bytes" -v total="$swap_total_bytes" 'BEGIN { printf "%.2f", ( used / total ) * 100 }')
    fi
    disk_total=$(df -h / | awk 'NR==2 {print $2}')
    disk_used=$(df -h / | awk 'NR==2 {print $3}')
    disk_use_ratio=$(df -h / | awk 'NR==2 {gsub("%", "", $5); print $5}')
    echo "内存使用率: $mem_use_ratio | 交换使用率: $swap_use_ratio | 磁盘使用率: $disk_use_ratio | 日期: $(date)"
}

#=======================================================
# 配置文件操作函数 (来自 config.sh)
#=======================================================

# 读取配置文件中的特定值
readini_value() {
    local key="$1"
    local file="${2:-$ConfigFile}"
    if [ -f "$file" ]; then
        grep "^$key=" "$file" | cut -d'=' -f2- | sed 's/^"//;s/"$//'
    fi
}

# 检查配置文件中是否存在某个键
check_config_key() {
    local key="$1"
    local file="${2:-$ConfigFile}"
    if [ -f "$file" ]; then
        grep -q "^$key=" "$file"
    else
        return 1
    fi
}

# 备份配置文件
backup_config() {
    if [ -f "$ConfigFile" ]; then
        cp "$ConfigFile" "$ConfigFile.backup.$(date +%Y%m%d_%H%M%S)"
        echo -e "${GREEN}配置文件已备份${NC}"
    fi
}

# 恢复配置文件
restore_config() {
    local backup_file="$1"
    if [ -f "$backup_file" ]; then
        cp "$backup_file" "$ConfigFile"
        echo -e "${GREEN}配置文件已恢复${NC}"
    else
        echo -e "${RED}备份文件不存在${NC}"
        return 1
    fi
}
