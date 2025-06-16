#!/usr/bin/env bash




# 发送测试
test1() {
    if [ ! -z "${test1_pid:-}" ] && pgrep -a '' | grep -Eq "^\s*$test1_pid\s" > /dev/null; then
        tips="$Err PID(${GR}$test1_pid${NC}) 正在发送中,请稍后..."
        return 1
    fi
    if [[ -z "${TelgramBotToken}" || -z "${ChatID_1}" ]]; then
        tips="$Err 参数丢失, 请设置后再执行 (先执行 ${GR}0${NC} 选项)."
        return 1
    fi

    message="来自 $hostname_show 的测试信息."
    # 使用 for 循环将消息分成多个实体
    for ((i=0; i<${#message}; i++)); do
        start=$i
        length=$(( ${#message} - $i ))
        entity="{\"type\":\"text_fragment\",\"offset\":$start,\"length\":$length}"
        entities+="{"
        if [[ $i -eq 0 ]]; then
            entities+="\"entities\":[ $entity ]"
        else
            entities+=", $entity"
        fi
    done
    # curl -s -X POST "https://api.telegram.org/bot$TelgramBotToken/sendMessage" \
    #     -d chat_id="$ChatID_1" -d text="来自 $hostname_show 的测试信息" > /dev/null
    send_time=$(echo $(date +%s%N) | cut -c 16-)
    $FolderPath/send_tg.sh "$TelgramBotToken" "$ChatID_1" "$message" "test1" "$send_time" "MarkdownV2" "$(echo $entities)"&
    (sleep 15 && $FolderPath/del_lm_tg.sh "$TelgramBotToken" "$ChatID_1" "test1" "$send_time") &
    sleep 1
    # getpid "send_tg.sh"
    # test1_pid="$tg_pid"
    test1_pid=$(getpid "send_tg.sh")
    tips="$Inf 测试信息已发出, 电报将收到一条\"来自 $hostname_show 的测试信息\"的信息.111"
}

# 发送测试
test() {
    if [ ! -z "${test_pid:-}" ] && pgrep -a '' | grep -Eq "^\s*$test_pid\s" > /dev/null; then
        tips="$Err PID(${GR}$test_pid${NC}) 正在发送中,请稍后..."
        return 1
    fi
    if [[ -z "${TelgramBotToken}" || -z "${ChatID_1}" ]]; then
        tips="$Err 参数丢失, 请设置后再执行 (先执行 ${GR}0${NC} 选项)."
        return 1
    fi
    # curl -s -X POST "https://api.telegram.org/bot$TelgramBotToken/sendMessage" \
    #     -d chat_id="$ChatID_1" -d text="来自 $hostname_show 的测试信息" > /dev/null
    send_time=$(echo $(date +%s%N) | cut -c 16-)
    $FolderPath/send_tg.sh "$TelgramBotToken" "$ChatID_1" "来自 $hostname_show 的测试信息." "test" "$send_time" &
    (sleep 15 && $FolderPath/del_lm_tg.sh "$TelgramBotToken" "$ChatID_1" "test" "$send_time") &
    sleep 1
    # if [ "$release" == "openwrt" ]; then
    #     test_pid=$(ps | grep '[s]end_tg' | tail -n 1 | awk '{print $1}')
    # else
    #     test_pid=$(ps aux | grep '[s]end_tg' | tail -n 1 | awk '{print $2}')
    # fi
    # getpid "send_tg.sh"
    # test_pid="$tg_pid"
    test_pid=$(getpid "send_tg.sh")
    tips="$Inf 测试信息已发出, 电报将收到一条\"来自 $hostname_show 的测试信息\"的信息."
}
