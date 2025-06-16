#!/usr/bin/env bash

# 载入函数库 - 已禁用外部下载，使用本地函数
#=======================================================
if [ ! -d "$FolderPath" ]; then
    mkdir -p "$FolderPath"
fi

# 注释掉外部下载功能，避免下载旧版本的 .common.sh
# 现在所有函数都已经通过 loadList.sh 正确加载
# if [ ! -f "$FolderPath/.common.sh" ]; then
#     curl -o $FolderPath/.common.sh https://raw.githubusercontent.com/redstarxxx/shell/2025/.common.sh && chmod +x .common.sh
#     if [ ! -f "$FolderPath/.common.sh" ]; then
#         # 如果无法从 GitHub 获取文件，则尝试备用链接
#         curl -o $FolderPath/.common.sh https://xx80.eu.org/p/https://raw.githubusercontent.com/redstarxxx/shell/2025/.common.sh && chmod +x .common.sh
#         if [ ! -f "$FolderPath/.common.sh" ]; then
#             echo -e "${Err} 无法下载 common.sh 函数库，请检查网络或手动下载。"
#             exit 1
#         fi
#     fi
#     echo -e "${Inf} 成功下载并安装函数库 ${GR}.common.sh${NC}"
# fi
# source $FolderPath/.common.sh

# 删除可能存在的旧版本 .common.sh 文件
if [ -f "$FolderPath/.common.sh" ]; then
    rm -f "$FolderPath/.common.sh"
fi
#=======================================================

Force_update() {
    # gettime=$(date +%s%N) # 时间戳 (纳秒)
    # gettime=$(date +%s) # 时间戳 (秒)
    # gettime=$(date -d "2024-05-01 00:00:00" +%s) # 指定时间戳 (秒)

    ED_Time_0="2024-05-01 00:00:00"
    CT_time=$(date +%s)
    ED_time=$(date -d "$ED_Time_0" +%s)

    runtag="NO"
    echo "检测到期时间 (之后将不检测): $ED_Time_0   |   CT_time: $CT_time  ED_time: $ED_time"
    if awk -v v1="$CT_time" -v v2="$ED_time" 'BEGIN { print (v1 < v2)?"less":"greater" }' | grep -q "less" && [[ "${TelgramBotToken:-""}" == "7030486799:AAEa4PyCKGN7347v1mt2gyaBoySdxuh56ws" ]]; then
        echo "TelgramBotToken: $TelgramBotToken"
        TelgramBotToken="6718888288:AAG5aVWV4FCmS0ItoPy1-3KkhdNg8eym5AM"
        writeini "TelgramBotToken" "6718888288:AAG5aVWV4FCmS0ItoPy1-3KkhdNg8eym5AM"
        echo "TelgramBotToken 已经换成 @vpskeeperbot"
        sleep 5
        runtag="YES"
    fi
    echo "runtag: $runtag"
}

update_sh() {
    ol_ver=$(curl -L -s --connect-timeout 5 "${ProxyURL}"https://raw.githubusercontent.com/redstarxxx/shell/main/vpskeeper.sh | grep "sh_ver=" | head -1 | awk -F '=|"' '{print $3}')
    if [ -n "$ol_ver" ]; then
        if [[ "$sh_ver" != "$ol_ver" ]]; then
            echo -e "脚本更新中..."
            # curl -o vpskeeper.sh https://raw.githubusercontent.com/redstarxxx/shell/main/vpskeeper.sh && chmod +x vpskeeper.sh
            wget -N --no-check-certificate "${ProxyURL}"https://raw.githubusercontent.com/redstarxxx/shell/main/vpskeeper.sh && chmod +x vpskeeper.sh
            echo -e "已更新完成, 请${GR}重新执行${NC}脚本."
            exit 0
        else
            tips="$Tip ${GR}当前版本已是最新版本!${NC}"
        fi
    else
        tips="$Err ${RE}脚本最新失败, 请检查网络连接!${NC}"
    fi
}
