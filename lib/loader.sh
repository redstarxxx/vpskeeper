#!/usr/bin/env bash

#=======================================================
# VPSKeeper 脚本加载器
# 功能: 加载所有必要的脚本和模块
# 基于: loadList.sh
#=======================================================

# 获取脚本目录
get_script_dir() {
    local script_path="$0"

    if [ -L "$script_path" ]; then
        script_path=$(readlink -f "$script_path")
    fi

    local script_dir=$(dirname "$script_path")

    script_dir=$(cd "$script_dir" && pwd)

    if [ -f "$script_dir/lib/core.sh" ]; then
        SCRIPT_DIR="$script_dir"
    elif [ -f "$script_dir/core.sh" ]; then
        SCRIPT_DIR="$(dirname "$script_dir")"
    else
        SCRIPT_DIR="$script_dir"
    fi

    echo "$SCRIPT_DIR"
}

# 加载核心库
load_core_libs() {
    local script_dir="$1"

    if [ -f "$script_dir/lib/colors.sh" ]; then
        source "$script_dir/lib/colors.sh"
    elif [ -f "$script_dir/sub/color.sh" ]; then
        source "$script_dir/sub/color.sh"
    else
        echo "警告: 无法找到颜色定义文件"
        echo "当前目录: $SCRIPT_DIR"
    fi

    if [ -f "$script_dir/lib/core.sh" ]; then
        source "$script_dir/lib/core.sh"
    elif [ -f "$script_dir/sub/base.sh" ] && [ -f "$script_dir/sub/config.sh" ]; then
        source "$script_dir/sub/base.sh"
        source "$script_dir/sub/config.sh"
    else
        echo "错误: 无法找到核心函数文件"
        echo "当前目录: $SCRIPT_DIR"
        exit 1
    fi

    if [ -f "$script_dir/lib/utils.sh" ]; then
        source "$script_dir/lib/utils.sh"
    elif [ -f "$script_dir/sub/tools.sh" ] && [ -f "$script_dir/sub/dataTools.sh" ]; then
        source "$script_dir/sub/tools.sh"
        source "$script_dir/sub/dataTools.sh"
    else
        echo "警告: 无法找到工具函数文件"
        echo "当前目录: $SCRIPT_DIR"
    fi
}

# 加载监控模块
load_monitoring_modules() {
    local script_dir="$1"

    local monitoring_modules=(
        "statusCheck.sh"
        "setupCPUTg.sh"
        "setupMEMTg.sh"
        "setupDISKTg.sh"
        "setupFlowTg.sh"
        "setupFlowReportTg.sh"
    )

    for module in "${monitoring_modules[@]}"; do
        if [ -f "$script_dir/modules/monitoring/$module" ]; then
            source "$script_dir/modules/monitoring/$module"
        elif [ -f "$script_dir/sub/$module" ]; then
            source "$script_dir/sub/$module"
        fi
    done
}

# 加载通知模块
load_notification_modules() {
    local script_dir="$1"

    local notification_modules=(
        "setupBootTg.sh"
        "setupLoginTg.sh"
        "setupShutdownTg.sh"
        "setupDockerTg.sh"
        "setupDDNSTg.sh"
        "testTg.sh"
        "unSetupTg.sh"
    )

    for module in "${notification_modules[@]}"; do
        if [ -f "$script_dir/modules/notifications/$module" ]; then
            source "$script_dir/modules/notifications/$module"
        elif [ -f "$script_dir/sub/$module" ]; then
            source "$script_dir/sub/$module"
        fi
    done
}

# 加载系统模块
load_system_modules() {
    local script_dir="$1"

    local system_modules=(
        "setupIniFile.sh"
        "setAutoUpdate.sh"
        "oneKeyDefault.sh"
        "update.sh"
        "hiddenADD.sh"
        "tgHandlerAi.sh"
    )

    for module in "${system_modules[@]}"; do
        if [ -f "$script_dir/modules/system/$module" ]; then
            source "$script_dir/modules/system/$module"
        elif [ -f "$script_dir/sub/$module" ]; then
            source "$script_dir/sub/$module"
        fi
    done
}

# 加载所有模块
load_all_modules() {
    local script_dir="$1"

    load_core_libs "$script_dir"

    init_system

    load_monitoring_modules "$script_dir"
    load_notification_modules "$script_dir"
    load_system_modules "$script_dir"
}

# 主加载函数
load_vpskeeper() {
    SCRIPT_DIR=$(get_script_dir)

    export SCRIPT_DIR
    export FolderPath="/opt/vpskeeper/runtime"
    export ConfigFile="$FolderPath/TelgramBot.ini"

    load_all_modules "$SCRIPT_DIR"

    # 设置错误处理（仅对关键错误）
    # 注意：不使用 set -e，因为某些操作（如 systemctl stop 不存在的服务）
    # 可能会返回非零退出码，但这是正常的
    # set -e
    # trap 'error_exit "脚本执行出错，行号: $LINENO"' ERR
}

# 检查依赖
check_loader_dependencies() {
    local missing_deps=()

    local required_commands=("awk" "sed" "grep" "curl" "wget")
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing_deps+=("$cmd")
        fi
    done

    if [ ${#missing_deps[@]} -gt 0 ]; then
        echo "错误: 缺少必要依赖: ${missing_deps[*]}"
        echo "请安装缺少的依赖后重试"
        exit 1
    fi
}

# 显示加载信息
show_loader_info() {
    if [ "${VPSKEEPER_DEBUG:-}" = "true" ]; then
        echo "VPSKeeper 加载器信息:"
        echo "  脚本目录: $SCRIPT_DIR"
        echo "  配置目录: $FolderPath"
        echo "  配置文件: $ConfigFile"
        echo "  版本: $sh_ver"
        echo ""
    fi
}

# 如果直接运行此脚本
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    echo "VPSKeeper 脚本加载器"
    echo "此脚本应该被其他脚本引用，不应直接运行"
    exit 1
fi
