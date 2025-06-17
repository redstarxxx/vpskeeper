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
    # 首先尝试从 GitHub Releases API 获取最新版本标签
    ol_ver=$(curl -L -s --connect-timeout 5 "${ProxyURL}"https://api.github.com/repos/redstarxxx/vpskeeper/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/' 2>/dev/null)

    # 移除版本号前缀 'v' (如果存在)
    ol_ver=$(echo "$ol_ver" | sed 's/^v//')

    # 如果 GitHub API 失败，回退到从源码文件获取版本
    if [ -z "$ol_ver" ]; then
        ol_ver=$(curl -L -s --connect-timeout 5 "${ProxyURL}"https://raw.githubusercontent.com/redstarxxx/vpskeeper/main/lib/core.sh | grep "sh_ver=" | head -1 | awk -F '=|"' '{print $3}')
    fi

    if [ -n "$ol_ver" ]; then
        if [[ "$sh_ver" != "$ol_ver" ]]; then
            echo -e "检测到新版本，开始更新..."
            echo -e "当前版本: ${GR}$sh_ver${NC}"
            echo -e "最新版本: ${GR}$ol_ver${NC}"
            echo ""

            # 创建临时目录
            TEMP_DIR="/tmp/vpskeeper_update_$(date +%Y%m%d_%H%M%S)"
            mkdir -p "$TEMP_DIR"

            echo -e "${YELLOW}正在下载最新版本的所有文件...${NC}"

            # 下载主安装脚本
            echo "下载主安装脚本..."
            if ! wget -O "$TEMP_DIR/vpskeeper.sh" "${ProxyURL}https://raw.githubusercontent.com/redstarxxx/vpskeeper/main/vpskeeper.sh" 2>/dev/null; then
                echo -e "${RED}下载主安装脚本失败${NC}"
                rm -rf "$TEMP_DIR"
                tips="$Err ${RE}更新失败, 请检查网络连接!${NC}"
                return 1
            fi

            chmod +x "$TEMP_DIR/vpskeeper.sh"

            echo -e "${GREEN}下载完成！${NC}"
            echo ""
            echo -e "${YELLOW}重要提示：${NC}"
            echo -e "1. 已下载最新的安装脚本到: ${GR}$TEMP_DIR/vpskeeper.sh${NC}"
            echo -e "2. 请运行以下命令完成完整更新："
            echo -e "   ${GR}bash $TEMP_DIR/vpskeeper.sh${NC}"
            echo -e "3. 在新安装脚本中选择 ${GR}2. 更新 VPSKeeper${NC} 来更新所有文件"
            echo ""
            echo -e "${RED}注意：这将更新所有项目文件（lib、modules等），并保留您的配置${NC}"
            echo ""

            # 询问是否立即执行完整更新
            read -e -p "是否现在立即执行完整更新? (y/N): " choice
            if [[ $choice =~ ^[Yy]$ ]]; then
                echo -e "${YELLOW}正在执行完整更新...${NC}"
                exec bash "$TEMP_DIR/vpskeeper.sh"
            else
                echo -e "${YELLOW}请稍后手动执行完整更新${NC}"
                tips="$Tip 更新脚本已准备就绪，请运行: ${GR}bash $TEMP_DIR/vpskeeper.sh${NC}"
            fi
        else
            tips="$Tip ${GR}当前版本已是最新版本!${NC}"
        fi
    else
        tips="$Err ${RE}获取最新版本失败, 请检查网络连接!${NC}"
    fi
}
