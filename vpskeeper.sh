#!/usr/bin/env bash

#=======================================================
# VPSKeeper 管理脚本
# 功能: 安装/卸载/更新 VPSKeeper
# 作者: tse
# 仓库: https://github.com/redstarxxx/vpskeeper
#=======================================================

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# 版本和路径配置
CURRENT_VERSION="1.2500616.1"
GITHUB_REPO="https://github.com/redstarxxx/vpskeeper"
GITHUB_RAW="https://raw.githubusercontent.com/redstarxxx/vpskeeper/main"
INSTALL_DIR="/opt/vpskeeper"
CONFIG_DIR="/opt/vpskeeper/runtime"

# 检查是否为 root 用户
check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo -e "${RED}错误: 请使用 root 权限运行此脚本${NC}"
        exit 1
    fi
}

# 检查系统类型
check_system() {
    if [ -f /etc/redhat-release ]; then
        release="centos"
    elif cat /etc/issue | grep -Eqi "debian"; then
        release="debian"
    elif cat /etc/issue | grep -Eqi "ubuntu"; then
        release="ubuntu"
    elif cat /etc/issue | grep -Eqi "centos|red hat|redhat"; then
        release="centos"
    elif cat /proc/version | grep -Eqi "debian"; then
        release="debian"
    elif cat /proc/version | grep -Eqi "ubuntu"; then
        release="ubuntu"
    elif cat /proc/version | grep -Eqi "centos|red hat|redhat"; then
        release="centos"
    else
        release="unknown"
    fi
}

# 获取远程版本（只在脚本启动时执行一次）
get_remote_version() {
    local remote_version=""

    # 尝试从 GitHub Releases API 获取最新版本标签
    if command -v curl >/dev/null 2>&1; then
        remote_version=$(timeout 5 curl -s https://api.github.com/repos/redstarxxx/vpskeeper/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/' 2>/dev/null)
    fi

    # 如果 curl 失败，尝试 wget
    if [ -z "$remote_version" ] && command -v wget >/dev/null 2>&1; then
        remote_version=$(timeout 5 wget -qO- https://api.github.com/repos/redstarxxx/vpskeeper/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/' 2>/dev/null)
    fi

    # 如果 GitHub API 失败，回退到从源码文件获取版本
    if [ -z "$remote_version" ]; then
        if command -v curl >/dev/null 2>&1; then
            remote_version=$(timeout 5 curl -s "$GITHUB_RAW/lib/core.sh" | grep 'sh_ver=' | head -1 | cut -d'"' -f2 2>/dev/null)
        elif command -v wget >/dev/null 2>&1; then
            remote_version=$(timeout 5 wget -qO- "$GITHUB_RAW/lib/core.sh" | grep 'sh_ver=' | head -1 | cut -d'"' -f2 2>/dev/null)
        fi
    fi

    # 移除版本号前缀 'v' (如果存在)
    remote_version=$(echo "$remote_version" | sed 's/^v//')

    echo "$remote_version"
}

# 检查系统状态
check_system_status() {
    local status_info=""

    # 检查安装状态
    if [ -d "$INSTALL_DIR" ] && [ -f "$INSTALL_DIR/lib/menu.sh" ]; then
        status_info="${GREEN}✓ 已安装${NC}"
    else
        status_info="${RED}✗ 未安装${NC}"
    fi

    # 检查配置目录
    if [ -d "$CONFIG_DIR" ]; then
        status_info="$status_info | ${GREEN}✓ 配置存在${NC}"
    else
        status_info="$status_info | ${RED}✗ 配置缺失${NC}"
    fi

    # 检查系统命令
    if [ -L /usr/local/bin/vpskeeper ]; then
        status_info="$status_info | ${GREEN}✓ 命令可用${NC}"
    else
        status_info="$status_info | ${RED}✗ 命令不可用${NC}"
    fi

    # 检查运行进程
    local running_processes=0
    if command -v pgrep >/dev/null 2>&1; then
        running_processes=$(pgrep -af 'tg_' | grep -v grep | wc -l)
    else
        # 回退到 ps + grep 方案
        if ps x >/dev/null 2>&1; then
            running_processes=$(ps x | grep 'tg_' | grep -v grep | wc -l)
        else
            running_processes=$(ps | grep 'tg_' | grep -v grep | wc -l)
        fi
    fi

    if [ "$running_processes" -gt 0 ]; then
        status_info="$status_info | ${GREEN}✓ $running_processes 个进程运行中${NC}"
    else
        status_info="$status_info | ${YELLOW}⚠ 无监控进程${NC}"
    fi

    echo "$status_info"
}

# 显示欢迎信息和状态
show_welcome() {
    clear
    echo -e "${CYAN}================================${NC}"
    echo -e "${CYAN}    VPSKeeper 管理工具${NC}"
    echo -e "${CYAN}================================${NC}"
    echo ""

    # 版本信息
    echo -e "${WHITE}当前版本: ${GREEN}$CURRENT_VERSION${NC}"
    if [ -n "$REMOTE_VERSION" ]; then
        echo -e "${WHITE}远程版本: ${GREEN}$REMOTE_VERSION${NC}"

        # 版本比较
        if [ "$CURRENT_VERSION" != "$REMOTE_VERSION" ]; then
            echo -e "${YELLOW}⚠️  发现新版本可用！${NC}"
        else
            echo -e "${GREEN}✓ 当前版本是最新的${NC}"
        fi
    else
        echo -e "${RED}✗ 无法获取远程版本信息${NC}"
    fi

    echo ""
    echo -e "${WHITE}仓库地址: ${BLUE}$GITHUB_REPO${NC}"
    echo ""

    # 系统状态
    echo -e "${CYAN}系统状态:${NC}"
    echo -e "$(check_system_status)"
    echo ""
}

# 显示主菜单
show_menu() {
    echo -e "${CYAN}请选择操作:${NC}"
    echo ""
    echo -e "${WHITE}1.${NC} ${GREEN}安装 VPSKeeper${NC}"
    echo -e "${WHITE}2.${NC} ${YELLOW}更新 VPSKeeper${NC}"
    echo -e "${WHITE}3.${NC} ${RED}卸载 VPSKeeper${NC}"
    echo -e "${WHITE}4.${NC} ${PURPLE}启动 VPSKeeper${NC} | 可直接执行: vpskeeper"
    echo -e "${WHITE}0.${NC} ${WHITE}退出${NC}"
    echo ""
    echo -ne "${CYAN}请输入选项 [0-4]: ${NC}"
}

# 创建目录
create_directories() {
    echo -e "${YELLOW}创建必要目录...${NC}"

    # 创建安装目录
    if [ ! -d "$INSTALL_DIR" ]; then
        mkdir -p "$INSTALL_DIR"
        echo -e "${GREEN}创建安装目录: $INSTALL_DIR${NC}"
    fi

    # 创建核心库目录
    if [ ! -d "$INSTALL_DIR/lib" ]; then
        mkdir -p "$INSTALL_DIR/lib"
        echo -e "${GREEN}创建核心库目录: $INSTALL_DIR/lib${NC}"
    fi

    # 创建功能模块目录
    if [ ! -d "$INSTALL_DIR/modules" ]; then
        mkdir -p "$INSTALL_DIR/modules"
        echo -e "${GREEN}创建功能模块目录: $INSTALL_DIR/modules${NC}"
    fi

    # 创建子脚本目录
    if [ ! -d "$INSTALL_DIR/runtime" ]; then
        mkdir -p "$INSTALL_DIR/runtime"
        echo -e "${GREEN}创建子脚本目录: $INSTALL_DIR/runtime${NC}"
    fi

    # 创建配置目录
    if [ ! -d "$CONFIG_DIR" ]; then
        mkdir -p "$CONFIG_DIR"
        echo -e "${GREEN}创建配置目录: $CONFIG_DIR${NC}"
    fi

}

# 下载文件
download_files() {
    echo -e "${YELLOW}下载文件...${NC}"

    # 核心库文件列表
    local lib_files=(
        "core.sh" "colors.sh" "utils.sh" "loader.sh" "menu.sh"
    )

    # 监控模块文件列表
    local monitoring_files=(
        "statusCheck.sh" "setupCPUTg.sh" "setupMEMTg.sh"
        "setupDISKTg.sh" "setupFlowTg.sh" "setupFlowReportTg.sh"
    )

    # 通知模块文件列表
    local notification_files=(
        "setupBootTg.sh" "setupLoginTg.sh" "setupShutdownTg.sh"
        "setupDockerTg.sh" "setupDDNSTg.sh" "testTg.sh" "unSetupTg.sh"
    )

    # 系统模块文件列表
    local system_files=(
        "setupIniFile.sh" "setAutoUpdate.sh" "oneKeyDefault.sh"
        "update.sh" "hiddenADD.sh" "tgHandlerAi.sh"
    )

    # 下载核心库文件
    echo "下载核心库文件..."
    for file in "${lib_files[@]}"; do
        echo "  下载 lib/$file..."
        if ! wget -O "$INSTALL_DIR/lib/$file" "$GITHUB_RAW/lib/$file" 2>/dev/null; then
            echo -e "${RED}下载 lib/$file 失败${NC}"
            return 1
        fi
    done

    # 创建模块子目录
    mkdir -p "$INSTALL_DIR/modules/monitoring"
    mkdir -p "$INSTALL_DIR/modules/notifications"
    mkdir -p "$INSTALL_DIR/modules/system"

    # 下载监控模块
    echo "下载监控模块..."
    for file in "${monitoring_files[@]}"; do
        echo "  下载 modules/monitoring/$file..."
        if ! wget -O "$INSTALL_DIR/modules/monitoring/$file" "$GITHUB_RAW/modules/monitoring/$file" 2>/dev/null; then
            echo -e "${RED}下载 modules/monitoring/$file 失败${NC}"
            return 1
        fi
    done

    # 下载通知模块
    echo "下载通知模块..."
    for file in "${notification_files[@]}"; do
        echo "  下载 modules/notifications/$file..."
        if ! wget -O "$INSTALL_DIR/modules/notifications/$file" "$GITHUB_RAW/modules/notifications/$file" 2>/dev/null; then
            echo -e "${RED}下载 modules/notifications/$file 失败${NC}"
            return 1
        fi
    done

    # 下载系统模块
    echo "下载系统模块..."
    for file in "${system_files[@]}"; do
        echo "  下载 modules/system/$file..."
        if ! wget -O "$INSTALL_DIR/modules/system/$file" "$GITHUB_RAW/modules/system/$file" 2>/dev/null; then
            echo -e "${RED}下载 modules/system/$file 失败${NC}"
            return 1
        fi
    done

    echo -e "${GREEN}文件下载完成${NC}"
    return 0
}

# 复制本地文件
copy_local_files() {
    echo -e "${YELLOW}复制本地文件...${NC}"

    # 复制核心库文件
    if [ -d "./lib" ]; then
        cp -r ./lib/* "$INSTALL_DIR/lib/"
        echo -e "${GREEN}复制核心库完成${NC}"
    else
        echo -e "${RED}本地核心库目录不存在${NC}"
        return 1
    fi

    # 复制功能模块
    if [ -d "./modules" ]; then
        cp -r ./modules/* "$INSTALL_DIR/modules/"
        echo -e "${GREEN}复制功能模块完成${NC}"
    else
        echo -e "${RED}本地功能模块目录不存在${NC}"
        return 1
    fi

    # 复制文档（如果存在）
    if [ -d "./docs" ]; then
        cp -r "./docs" "$INSTALL_DIR/"
        echo -e "${GREEN}复制文档完成${NC}"
    fi

    # 复制子脚本（如果存在）
    if [ -d "./sub" ] && [ "$(ls -A ./sub 2>/dev/null)" ]; then
        cp -r ./sub/* "$INSTALL_DIR/runtime/"
        echo -e "${GREEN}复制子脚本完成${NC}"
    else
        echo -e "${YELLOW}本地子脚本目录为空或不存在，跳过${NC}"
    fi

    return 0
}

# 设置权限
set_permissions() {
    echo -e "${YELLOW}设置文件权限...${NC}"

    # 设置主脚本权限
    chmod +x "$INSTALL_DIR/lib/menu.sh"

    # 设置库文件权限
    if [ -d "$INSTALL_DIR/lib" ]; then
        chmod +x "$INSTALL_DIR/lib"/*.sh 2>/dev/null || true
    fi

    # 设置模块文件权限
    if [ -d "$INSTALL_DIR/modules" ]; then
        find "$INSTALL_DIR/modules" -name "*.sh" -exec chmod +x {} \; 2>/dev/null || true
    fi

    # 设置子脚本权限（如果存在）
    if [ -d "$INSTALL_DIR/runtime" ] && [ "$(ls -A "$INSTALL_DIR/runtime"/*.sh 2>/dev/null)" ]; then
        chmod +x "$INSTALL_DIR/runtime"/*.sh 2>/dev/null || true
    fi

    echo -e "${GREEN}权限设置完成${NC}"
}

# 创建系统命令链接
create_symlink() {
    echo -e "${YELLOW}创建系统命令链接...${NC}"

    # 删除旧链接
    if [ -L /usr/local/bin/vpskeeper ]; then
        rm -f /usr/local/bin/vpskeeper
    fi

    # 创建新链接
    ln -sf "$INSTALL_DIR/lib/menu.sh" /usr/local/bin/vpskeeper

    if [ -L /usr/local/bin/vpskeeper ]; then
        echo -e "${GREEN}创建系统命令成功: vpskeeper${NC}"
    else
        echo -e "${YELLOW}警告: 无法创建系统命令链接${NC}"
    fi
}

# 安装 VPSKeeper
install_vpskeeper() {
    echo -e "${GREEN}================================${NC}"
    echo -e "${GREEN}    开始安装 VPSKeeper${NC}"
    echo -e "${GREEN}================================${NC}"
    echo ""

    create_directories

    # 获取脚本所在目录
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

    # 检查是否为本地安装
    if [ -d "$script_dir/lib" ] && [ -d "$script_dir/modules" ]; then
        echo -e "${YELLOW}检测到本地文件，进行本地安装...${NC}"
        echo -e "${BLUE}脚本目录: $script_dir${NC}"

        # 临时切换到脚本目录
        local original_dir="$(pwd)"
        cd "$script_dir"

        if copy_local_files; then
            set_permissions
            create_symlink
            echo -e "${GREEN}本地安装完成！${NC}"
        else
            echo -e "${RED}本地安装失败！${NC}"
            cd "$original_dir"
            return 1
        fi

        # 恢复原目录
        cd "$original_dir"
    else
        # 在线安装
        echo -e "${YELLOW}进行在线安装...${NC}"
        if download_files; then
            set_permissions
            create_symlink
            echo -e "${GREEN}在线安装完成！${NC}"
        else
            echo -e "${RED}在线安装失败！请检查网络连接${NC}"
            return 1
        fi
    fi

    echo ""
    echo -e "${GREEN}安装成功！${NC}"
    echo -e "${YELLOW}使用方法:${NC}"
    echo "1. 运行: vpskeeper"
    echo "2. 或者: bash $INSTALL_DIR/lib/menu.sh"
    echo ""
}

# 更新 VPSKeeper
update_vpskeeper() {
    echo -e "${GREEN}================================${NC}"
    echo -e "${GREEN}    开始更新 VPSKeeper${NC}"
    echo -e "${GREEN}================================${NC}"
    echo ""

    # 检查当前安装
    if [ ! -d "$INSTALL_DIR" ]; then
        echo -e "${RED}错误: VPSKeeper 未安装${NC}"
        echo -e "${YELLOW}请先运行安装选项${NC}"
        return 1
    fi

    # 获取远程版本
    echo -e "${YELLOW}检查远程版本...${NC}"
    local remote_version=$(get_remote_version)

    if [ -z "$remote_version" ]; then
        echo -e "${RED}无法获取远程版本信息${NC}"
        echo -e "${YELLOW}是否强制更新? (y/N): ${NC}"
        read -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            return 1
        fi
    else
        echo -e "${WHITE}当前版本: ${GREEN}$CURRENT_VERSION${NC}"
        echo -e "${WHITE}远程版本: ${GREEN}$remote_version${NC}"

        if [ "$CURRENT_VERSION" == "$remote_version" ]; then
            echo -e "${GREEN}当前版本已是最新，无需更新${NC}"
            return 0
        fi
    fi

    # 备份配置
    echo -e "${YELLOW}备份配置文件...${NC}"
    BACKUP_DIR="/tmp/vpskeeper_backup_$(date +%Y%m%d_%H%M%S)"
    if [ -d "$CONFIG_DIR" ]; then
        cp -r "$CONFIG_DIR" "$BACKUP_DIR"
        echo -e "${GREEN}配置已备份到: $BACKUP_DIR${NC}"
    fi

    # 下载更新
    echo -e "${YELLOW}下载更新文件...${NC}"
    if download_files; then
        set_permissions
        echo -e "${GREEN}更新完成！${NC}"

        # 恢复配置
        if [ -d "$BACKUP_DIR" ]; then
            echo -e "${YELLOW}恢复配置文件...${NC}"
            cp -r "$BACKUP_DIR"/* "$CONFIG_DIR/"
            echo -e "${GREEN}配置文件已恢复${NC}"
        fi
    else
        echo -e "${RED}更新失败！${NC}"
        return 1
    fi
}

# 卸载 VPSKeeper
uninstall_vpskeeper() {
    echo -e "${RED}================================${NC}"
    echo -e "${RED}    卸载 VPSKeeper${NC}"
    echo -e "${RED}================================${NC}"
    echo ""

    echo -e "${YELLOW}警告: 此操作将完全删除 VPSKeeper 及其所有文件${NC}"
    echo -e "${YELLOW}是否确认卸载? (y/N): ${NC}"
    read -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${GREEN}取消卸载${NC}"
        return 0
    fi

    # 停止所有相关进程（排除当前脚本）
    echo -e "${YELLOW}停止相关进程...${NC}"
    local current_pid=$$

    # 停止 tg_ 开头的监控进程
    if command -v pkill >/dev/null 2>&1; then
        pkill -f "tg_" 2>/dev/null
    else
        # 回退到 kill + ps 方案
        if ps x >/dev/null 2>&1; then
            ps x | grep 'tg_' | grep -v grep | awk '{print $1}' | xargs kill 2>/dev/null
        else
            ps | grep 'tg_' | grep -v grep | awk '{print $1}' | xargs kill 2>/dev/null
        fi
    fi

    # 停止其他 vpskeeper 相关进程（排除当前进程）
    if command -v pgrep >/dev/null 2>&1; then
        local vps_pids=$(pgrep -f "vpskeeper" | grep -v "^$current_pid$")
        if [ -n "$vps_pids" ]; then
            echo "$vps_pids" | xargs kill 2>/dev/null
        fi
    else
        # 回退方案：手动过滤当前进程
        if ps x >/dev/null 2>&1; then
            ps x | grep 'vpskeeper' | grep -v grep | grep -v "^[[:space:]]*$current_pid[[:space:]]" | awk '{print $1}' | xargs kill 2>/dev/null
        else
            ps | grep 'vpskeeper' | grep -v grep | grep -v "^[[:space:]]*$current_pid[[:space:]]" | awk '{print $1}' | xargs kill 2>/dev/null
        fi
    fi

    # 等待进程完全停止
    sleep 2

    # 删除 crontab 任务
    echo -e "${YELLOW}清理 crontab 任务...${NC}"
    if crontab -l 2>/dev/null | grep -q "vpskeeper\|tg_"; then
        crontab -l 2>/dev/null | grep -v "vpskeeper\|tg_" | crontab - 2>/dev/null
        echo -e "${GREEN}  ✓ crontab 任务已清理${NC}"
    else
        echo -e "${BLUE}  ✓ 无需清理 crontab 任务${NC}"
    fi

    # 删除系统命令链接
    echo -e "${YELLOW}删除系统命令链接...${NC}"
    if [ -L /usr/local/bin/vpskeeper ] || [ -f /usr/local/bin/vpskeeper ]; then
        rm -f /usr/local/bin/vpskeeper
        echo -e "${GREEN}  ✓ 系统命令链接已删除${NC}"
    else
        echo -e "${BLUE}  ✓ 无需删除系统命令链接${NC}"
    fi

    # 删除 systemd 服务文件
    echo -e "${YELLOW}清理 systemd 服务...${NC}"
    local systemd_files_found=false
    for service_file in /etc/systemd/system/tg_*.service /etc/systemd/system/tg_*.timer; do
        if [ -f "$service_file" ]; then
            systemd_files_found=true
            systemctl stop "$(basename "$service_file")" 2>/dev/null
            systemctl disable "$(basename "$service_file")" 2>/dev/null
            rm -f "$service_file"
        fi
    done
    if [ "$systemd_files_found" = true ]; then
        systemctl daemon-reload 2>/dev/null
        echo -e "${GREEN}  ✓ systemd 服务已清理${NC}"
    else
        echo -e "${BLUE}  ✓ 无需清理 systemd 服务${NC}"
    fi

    # 删除安装目录
    echo -e "${YELLOW}删除安装文件...${NC}"
    local dirs_removed=0
    for install_dir in "/opt/vpskeeper" "/opt/VPSKeeper" "/opt/vpskeeper2025"; do
        if [ -d "$install_dir" ]; then
            rm -rf "$install_dir"
            dirs_removed=$((dirs_removed + 1))
        fi
    done
    if [ $dirs_removed -gt 0 ]; then
        echo -e "${GREEN}  ✓ 安装目录已删除 ($dirs_removed 个)${NC}"
    else
        echo -e "${BLUE}  ✓ 无需删除安装目录${NC}"
    fi

    # 删除配置目录
    echo -e "${YELLOW}删除配置文件...${NC}"
    local config_dirs_removed=0
    for config_dir in "/opt/vpskeeper/runtime" "/opt/VPSKeeper/runtime" "$HOME/.shfile"; do
        if [ -d "$config_dir" ]; then
            rm -rf "$config_dir"
            config_dirs_removed=$((config_dirs_removed + 1))
        fi
    done
    if [ $config_dirs_removed -gt 0 ]; then
        echo -e "${GREEN}  ✓ 配置目录已删除 ($config_dirs_removed 个)${NC}"
    else
        echo -e "${BLUE}  ✓ 无需删除配置目录${NC}"
    fi

    # 删除登录通知配置
    echo -e "${YELLOW}清理登录通知配置...${NC}"
    local login_configs_cleaned=0
    for config_file in "/etc/bash.bashrc" "/etc/profile" "$HOME/.bashrc" "$HOME/.profile"; do
        if [ -f "$config_file" ] && grep -q "tg_login.sh" "$config_file"; then
            sed -i '/tg_login.sh/d' "$config_file"
            login_configs_cleaned=$((login_configs_cleaned + 1))
        fi
    done
    if [ $login_configs_cleaned -gt 0 ]; then
        echo -e "${GREEN}  ✓ 登录通知配置已清理 ($login_configs_cleaned 个文件)${NC}"
    else
        echo -e "${BLUE}  ✓ 无需清理登录通知配置${NC}"
    fi

    echo ""
    echo -e "${GREEN}================================${NC}"
    echo -e "${GREEN}  VPSKeeper 已完全卸载！${NC}"
    echo -e "${GREEN}================================${NC}"
    echo ""
    echo -e "${YELLOW}感谢您使用 VPSKeeper！${NC}"
}



# 启动 VPSKeeper
start_vpskeeper() {
    echo -e "${PURPLE}================================${NC}"
    echo -e "${PURPLE}    启动 VPSKeeper${NC}"
    echo -e "${PURPLE}================================${NC}"
    echo ""

    if [ ! -f "$INSTALL_DIR/lib/menu.sh" ]; then
        echo -e "${RED}错误: VPSKeeper 未安装${NC}"
        return 1
    fi

    echo -e "${GREEN}启动 VPSKeeper...${NC}"
    bash "$INSTALL_DIR/lib/menu.sh"
}

# 主函数
main() {
    check_root
    check_system

    # 只在脚本启动时获取一次远程版本
    echo -e "${YELLOW}正在检查远程版本...${NC}"
    REMOTE_VERSION=$(get_remote_version)

    while true; do
        show_welcome
        show_menu

        read -n 1 -r choice
        echo
        echo

        case $choice in
            1)
                install_vpskeeper
                ;;
            2)
                update_vpskeeper
                ;;
            3)
                uninstall_vpskeeper
                ;;
            4)
                start_vpskeeper
                ;;
            0)
                echo -e "${GREEN}退出管理工具${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}无效选项，请重新选择${NC}"
                ;;
        esac

        echo ""
        echo -e "${CYAN}按任意键继续...${NC}"
        read -n 1 -r
    done
}

# 运行主函数
main "$@"
