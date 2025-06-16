#!/usr/bin/env bash


# 一键默认设置
OneKeydefault() {
    mutebakup=$mute
    autorun=true
    mute=true
    SetupIniFile
    SetupBoot_TG
    SetupLogin_TG
    SetupShutdown_TG
    writeini "CPUThreshold" "$CPUThreshold_de"
    writeini "MEMThreshold" "$MEMThreshold_de"
    writeini "DISKThreshold" "$DISKThreshold_de"
    writeini "FlowThreshold" "$FlowThreshold_de"
    writeini "FlowThresholdMAX" "$FlowThresholdMAX_de"
    writeini "ReportTime" "$ReportTime_de"
    writeini "AutoUpdateTime" "$AutoUpdateTime_de"
    source $ConfigFile
    SetupCPU_TG
    SetupMEM_TG
    SetupDISK_TG
    SetupFlow_TG
    SetFlowReport_TG
    SetAutoUpdate
    if [ "$mutebakup" == "false" ]; then
        current_date_send=$(date +"%Y.%m.%d %T")
        message="已成功启动以下通知 ☎️"$'\n'
        message+="主机名: $hostname_show"$'\n'
        message+="───────────────"$'\n'
        message+="开机通知"$'\n'
        message+="登陆通知"$'\n'
        message+="关机通知"$'\n'
        message+="CPU使用率超 ${CPUThreshold}% 报警"$'\n'
        message+="内存使用率超 ${MEMThreshold}% 报警"$'\n'
        message+="磁盘使用率超 ${DISKThreshold}% 报警"$'\n'
        message+="流量使用率超 ${FlowThreshold_UB} 报警"$'\n'
        message+="流量报告时间 ${ReportTime}"$'\n'
        message+="自动更新时间 ${AutoUpdateTime}"$'\n'
        message+="开启重启时记录流量"$'\n'
        message+="开启TG代理"$'\n'
        message+="开启发送在线时长"$'\n'
        message+="开启发送IP地址"$'\n'
        message+="开启发送货币报价"$'\n'
        message+="───────────────"$'\n'
        message+="服务器时间: $current_date_send"
        $FolderPath/send_tg.sh "$TelgramBotToken" "$ChatID_1" "$message" &
    fi
    tips="$Tip 已经启动所有通知 (除了Docker 变更通知)."
    autorun=false
    mute=false
    mute=$mutebakup
}
