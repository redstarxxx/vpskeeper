#!/usr/bin/env bash

# 状态检查相关函数

# 检测设置标记
CheckSetup() {
    echo "检测中..."
    # 检查登录通知状态
    login_menu_tag="$UNSETTAG"
    # 检查脚本文件是否存在以及配置文件中是否有相关配置
    if [ -f "$FolderPath/tg_login.sh" ]; then
        # 检查 bash.bashrc 中是否有登录通知配置
        if [ -f /etc/bash.bashrc ] && [ "$release" != "openwrt" ]; then
            if grep -q "tg_login.sh" /etc/bash.bashrc; then
                login_menu_tag="$SETTAG"
            fi
        # 检查 profile 中是否有登录通知配置
        elif [ -f /etc/profile ]; then
            if grep -q "tg_login.sh" /etc/profile; then
                login_menu_tag="$SETTAG"
            fi
        fi
    fi
    if [ -f $FolderPath/tg_boot.sh ]; then
        if [ -f /etc/systemd/system/tg_boot.service ]; then
            boot_menu_tag="$SETTAG"
        elif [ -f /etc/init.d/tg_boot.sh ]; then
            boot_menu_tag="$SETTAG"
        else
            boot_menu_tag="$UNSETTAG"
        fi
    else
        boot_menu_tag="$UNSETTAG"
    fi
    if [ -f $FolderPath/tg_shutdown.sh ]; then
        if [ -f /etc/systemd/system/tg_shutdown.service ]; then
            shutdown_menu_tag="$SETTAG"
        elif [ -f /etc/init.d/tg_shutdown.sh ]; then
            shutdown_menu_tag="$SETTAG"
        else
            shutdown_menu_tag="$UNSETTAG"
        fi
    else
        shutdown_menu_tag="$UNSETTAG"
    fi

    docker_menu_tag=$(Checkprocess "tg_docker.sh")
    cpu_menu_tag=$(Checkprocess "tg_cpu.sh")
    mem_menu_tag=$(Checkprocess "tg_mem.sh")
    disk_menu_tag=$(Checkprocess "tg_disk.sh")
    flow_menu_tag=$(Checkprocess "tg_flow.sh")
    flrp_menu_tag=$(Checkprocess "tg_flrp.sh")

    if [ -f $FolderPath/tg_ddns.sh ]; then
        if pgrep -af "$FolderPath/tg_ddns.sh" | grep -v grep > /dev/null 2>&1; then
            ddns_menu_tag="$SETTAG"
        else
            ddns_menu_tag="$UNSETTAG"
        fi
    else
        ddns_menu_tag="$UNSETTAG"
    fi
    if [ -f $FolderPath/tg_autoud.sh ]; then
        if crontab -l | grep -q "$FolderPath/tg_autoud.sh"; then
            autoud_menu_tag="$SETTAG"
        else
            autoud_menu_tag="$UNSETTAG"
        fi
    else
        autoud_menu_tag="$UNSETTAG"
    fi
    if [ -d "$FolderPath" ]; then
        folder_menu_tag="${GR}-> 文件夹存在${NC}"
    else
        folder_menu_tag="${RE}-> 文件夹不存在${NC}"
    fi
}
