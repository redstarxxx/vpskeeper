#!/usr/bin/env bash


# 卸载
UN_SetupBoot_TG() {
    # if [ "$boot_menu_tag" == "$SETTAG" ]; then
        # 停止和禁用 systemd 服务（忽略错误）
        systemctl stop tg_boot.service > /dev/null 2>&1 || true
        systemctl disable tg_boot.service > /dev/null 2>&1 || true
        sleep 1
        rm -f /etc/systemd/system/tg_boot.service

        # 处理 OpenWRT init.d 脚本
        if [ -f /etc/init.d/tg_boot.sh ]; then
            /etc/init.d/tg_boot.sh disable > /dev/null 2>&1 || true
            rm -f /etc/init.d/tg_boot.sh
        fi

        # 删除开机通知脚本文件
        rm -f "$FolderPath/tg_boot.sh"

        tips="$Tip 开机通知 已经取消 / 删除."
    # fi
}
UN_SetupLogin_TG() {
    # if [ "$login_menu_tag" == "$SETTAG" ]; then
        if [ -f /etc/bash.bashrc ]; then
            # 删除所有可能的登录通知配置（处理路径变化）
            sed -i '/tg_login.sh/d' /etc/bash.bashrc
        fi
        if [ -f /etc/profile ]; then
            # 删除所有可能的登录通知配置（处理路径变化）
            sed -i '/tg_login.sh/d' /etc/profile
        fi
        # 删除登录通知脚本文件
        rm -f "$FolderPath/tg_login.sh"
        tips="$Tip 登陆通知 已经取消 / 删除."
    # fi
}
UN_SetupShutdown_TG() {
    # if [ "$shutdown_menu_tag" == "$SETTAG" ]; then
        # 停止和禁用 systemd 服务（忽略错误）
        systemctl stop tg_shutdown.service > /dev/null 2>&1 || true
        systemctl disable tg_shutdown.service > /dev/null 2>&1 || true
        sleep 1
        rm -f /etc/systemd/system/tg_shutdown.service

        # 处理 OpenWRT init.d 脚本
        if [ -f /etc/init.d/tg_shutdown.sh ]; then
            /etc/init.d/tg_shutdown.sh disable > /dev/null 2>&1 || true
            rm -f /etc/init.d/tg_shutdown.sh
        fi

        # 删除关机通知脚本文件
        rm -f "$FolderPath/tg_shutdown.sh"

        tips="$Tip 关机通知 已经取消 / 删除."
    # fi
}
UN_SetupCPU_TG() {
    # if [ "$cpu_menu_tag" == "$SETTAG" ]; then
        killpid "tg_cpu.sh"
        # pkill tg_cpu.sh > /dev/null 2>&1 &
        # pkill tg_cpu.sh > /dev/null 2>&1 &
        # kill $(ps | grep '[t]g_cpu.sh' | awk '{print $1}')
        crontab -l | grep -v "$FolderPath/tg_cpu.sh" | crontab -
        tips="$Tip CPU报警 已经取消 / 删除."
    # fi
}
UN_SetupMEM_TG() {
    # if [ "$mem_menu_tag" == "$SETTAG" ]; then
        killpid "tg_mem.sh"
        crontab -l | grep -v "$FolderPath/tg_mem.sh" | crontab -
        tips="$Tip 内存报警 已经取消 / 删除."
    # fi
}
UN_SetupDISK_TG() {
    # if [ "$disk_menu_tag" == "$SETTAG" ]; then
        killpid "tg_disk.sh"
        crontab -l | grep -v "$FolderPath/tg_disk.sh" | crontab -
        tips="$Tip 磁盘报警 已经取消 / 删除."
    # fi
}
UN_SetupFlow_TG() {
    # if [ "$flow_menu_tag" == "$SETTAG" ]; then
        killpid "tg_flow.sh"
        crontab -l | grep -v "$FolderPath/tg_flow.sh" | crontab -
        tips="$Tip 流量报警 已经取消 / 删除."
    # fi
}
UN_SetFlowReport_TG() {
    # if [ "$flrp_menu_tag" == "$SETTAG" ]; then
        killpid "tg_flrp.sh"
        crontab -l | grep -v "$FolderPath/tg_flrp.sh" | crontab -
        tips="$Tip 流量定时报告 已经取消 / 删除."
    # fi

}
UN_SetupDocker_TG() {
    # if [ "$docker_menu_tag" == "$SETTAG" ]; then
        killpid "tg_docker.sh"
        crontab -l | grep -v "$FolderPath/tg_docker.sh" | crontab -
        tips="$Tip Docker变更通知 已经取消 / 删除."
    # fi
}
UN_SetupDDNS_TG() {
    # if [ "$ddns_menu_tag" == "$SETTAG" ]; then
        killpid "tg_ddns.sh"
        crontab -l | grep -v "$FolderPath/tg_ddns.sh" | crontab -
        crontab -l | grep -v "$FolderPath/tg_ddnskp.sh" | crontab -
        systemctl stop tg_ddnskp.service > /dev/null 2>&1
        systemctl disable tg_ddnskp.service > /dev/null 2>&1
        systemctl stop tg_ddtimer.timer > /dev/null 2>&1
        systemctl disable tg_ddtimer.timer > /dev/null 2>&1
        sleep 1.5
        rm -f /etc/systemd/system/tg_ddnskp.service
        rm -f /etc/systemd/system/tg_ddtimer.timer
        rm -f /etc/systemd/system/tg_ddrun.service
        killpid "tg_ddkpnh.sh"
        tips="$Tip CF-DDNS IP 变更通知 已经取消 / 删除."
    # fi
}
UN_SetAutoUpdate() {
    # if [ "$autoud_menu_tag" == "$SETTAG" ]; then
        killpid "tg_autoud.sh"
        crontab -l | grep -v "$FolderPath/tg_autoud.sh" | crontab -
        crontab -l | grep -v "$FolderPath/vpskeeper.sh" | crontab -
        tips="$Tip 自动更新已经取消."
    # fi
}

UN_ALL() {
    if [ "$autorun" == "false" ]; then
        if [ ! -z "${delall_pid:-}" ] && universal_process_exists "$delall_pid"; then
            tips="$Err PID(${GR}$delall_pid${NC}) 正在发送中,请稍后..."
            return 1
        fi
        writeini "SHUTDOWN_RT" "false"
        writeini "ProxyURL" ""
        writeini "SendUptime" "false"
        writeini "SendIP" "false"
        writeini "SendPrice" "false"
    fi
    UN_SetupBoot_TG
    UN_SetupLogin_TG
    UN_SetupShutdown_TG
    UN_SetupCPU_TG
    UN_SetupMEM_TG
    UN_SetupDISK_TG
    UN_SetupFlow_TG
    UN_SetFlowReport_TG
    UN_SetupDocker_TG
    UN_SetAutoUpdate

    # pkill -f 'tg_.+.sh' > /dev/null 2>&1 &
    # # ps | grep '[t]g_' | awk '{print $1}' | xargs kill
    # kill $(ps | grep '[t]g_' | awk '{print $1}')
    # sleep 1
    # if pgrep -f 'tg_.+.sh' > /dev/null; then
    #     pkill -9 -f 'tg_.+.sh' > /dev/null 2>&1 &
    #     # ps | grep '[t]g_' | awk '{print $1}' | xargs kill -9
    #     kill -9 $(ps | grep '[t]g_' | awk '{print $1}')
    # fi

    # if [ "$autorun" == "false" ]; then
    if [ "$un_tag" == "true" ]; then
        killpid "tg_"
        crontab -l | grep -v "$FolderPath/tg_" | crontab -
        rm -f /etc/systemd/system/tg_*
        send_time=$(echo $(date +%s%N) | cut -c 16-)
        current_date_send=$(date +"%Y.%m.%d %T")
        message="已执行一键删除所有通知 ☎️"$'\n'
        message+="主机名: $hostname_show"$'\n'
        message+="服务器时间: $current_date_send"
        $FolderPath/send_tg.sh "$TelgramBotToken" "$ChatID_1" "$message" "delall" "$send_time" &
        (sleep 15 && $FolderPath/del_lm_tg.sh "$TelgramBotToken" "$ChatID_1" "delall" "$send_time") &
        sleep 1
        # getpid "send_tg.sh"
        # delall_pid="$tg_pid"
        delall_pid=$(getpid "send_tg.sh")
        tips="$Tip 已取消 / 删除所有通知."
    fi
}

DELFOLDER() {
    if [ "$boot_menu_tag" == "$UNSETTAG" ] && [ "$login_menu_tag" == "$UNSETTAG" ] && [ "$shutdown_menu_tag" == "$UNSETTAG" ] && [ "$cpu_menu_tag" == "$UNSETTAG" ] && [ "$mem_menu_tag" == "$UNSETTAG" ] && [ "$disk_menu_tag" == "$UNSETTAG" ] && [ "$flow_menu_tag" == "$UNSETTAG" ] && [ "$docker_menu_tag" == "$UNSETTAG" ]; then
        if [ -d "$FolderPath" ]; then
            read -e -p "是否要删除 $FolderPath 文件夹? (建议保留) Y/其它 : " yorn
            if [ "$yorn" == "Y" ] || [ "$yorn" == "y" ]; then
                rm -rf $FolderPath
                folder_menu_tag=""
                tips="$Tip $FolderPath 文件夹已经${RE}删除${NC}."
                exit 0
            else
                tips="$Tip $FolderPath 文件夹已经${GR}保留${NC}."
            fi
        fi
    else
        tips="$Err 请先取消所有通知后再删除文件夹."
    fi
}
