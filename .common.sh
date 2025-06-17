#!/usr/bin/env bash

# 改进的root权限检测方式
check_root() {
    local user_id
    if command -v id >/dev/null 2>&1; then
        user_id="$(id -u)"
    else
        user_id="$(whoami)"
    fi

    if [ "$user_id" != "0" ]; then
        echo "非 \"root权限\" 用户, 请使用 \"root\" 用户或 \"sudo\" 指令执行."
        usreid="${REB}非ROOT权限${NC}"
        return 1
    fi
    usreid="${GRB}ROOT权限${NC}"
    return 0
}

# 写入ini文件
# writeini() {
#     init_config  # 确保配置目录和文件存在
#     if grep -q "^$1=" "$ConfigFile" 2>/dev/null; then
#         sed -i "/^$1=/d" "$ConfigFile"
#     fi
#     # echo "$1=$2" >> $ConfigFile
#     echo "$1=\"$2\"" >> "$ConfigFile"
# }

writeini() {
    local key="$1"
    local value="$2"
    local file="$ConfigFile"

    # 删除旧值
    sed -i "\|^$key=|d" "$file"

    # 确保文件末尾有换行符
    sed -i -e '$a\' "$file"

    # 追加新值
    echo "$key=\"$value\"" >> "$file"
}


# 读取配置文件
readini() {
    if [ -f "$ConfigFile" ]; then
        source "$ConfigFile"
    fi
}

# 创建.shfile目录
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
        touch "$ConfigFile" || {
            echo -e "$Err 无法创建配置文件: $ConfigFile"
            exit 1
        }
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
    fi
}

# 生成随机验证码
generate_secret() {
    local length=${1:-8} # 默认长度8
    local chars="0123456789"
    local secret=""
    for ((i=0; i<length; i++)); do
        secret+=${chars:$((RANDOM%${#chars})):1}
    done
    echo "$secret"
}

# 通用包检查函数
check_python_packages() {
    local packages=("$@")
    local missing_packages=()

    for package in "${packages[@]}"; do
        if ! python3 -c "import $package" 2>/dev/null; then
            missing_packages+=("$package")
        fi
    done

    if [ ${#missing_packages[@]} -ne 0 ]; then
        echo -e "$Tip 以下Python包未安装："
        printf '%s\n' "${missing_packages[@]}"
        read -p "是否安装这些包？(y/n): " choice
        if [[ $choice == "y" ]]; then
            for package in "${missing_packages[@]}"; do
                echo -e "$Tip 正在安装 $package..."
                pip install "$package" || {
                    echo -e "$Err 安装 $package 失败"
                    return 1
                }
            done
            echo -e "$OK 所有包安装完成"
        else
            echo -e "$Err 请手动安装所需的包后再运行"
            echo "pip install ${missing_packages[*]}"
            return 1
        fi
    fi
    return 0
}

# 创建角色描述文件
create_character_desc() {
    local base_desc="收到此信息后回复:服务器: $hostname\\n连接成功！欢迎使用VPSKeeper助手!;\
        以下内容不要在你的回复中提及;\
        默认简洁回复,每次回复控制在100字以内;\
        当看到详细说/详细告诉我/细说/说多点/详细回答等类似关键词时不作限制,尽可能详细回复,但是只针对包含此类关键词的信息,其它信息一律按上述100字以内的限制;\
        你是一个Linux操作系统专家,你也是一个VPS Keeper助手,帮助用户维护当前所在的VPS系统;\
        你非常熟悉Linux下的系统操作指令/Bash脚本和Python编程;"
    # local base_desc_add1="当用户询问系统操作时只回复指令(不作多余回复)."

    # 收集系统信息
    local os_info=$(cat /etc/os-release 2>/dev/null | grep "PRETTY_NAME" | cut -d'"' -f2)
    local kernel_ver=$(uname -r)
    local cpu_info=$(grep "model name" /proc/cpuinfo | head -n1 | cut -d':' -f2 | xargs)
    local cpu_cores=$(grep -c "processor" /proc/cpuinfo)
    local mem_total=$(free -h | grep "Mem:" | awk '{print $2}')
    local disk_info=$(df -h / | tail -n1 | awk '{print $2 " 总空间, " $4 " 可用"}')
    local uptime_info=$(uptime -p)
    local ip_info=$(curl -s ifconfig.me 2>/dev/null || echo "无法获取")
    local installed_packages=$(dpkg -l 2>/dev/null | grep "^ii" | wc -l || rpm -qa | wc -l)
    local running_services=$(systemctl list-units --type=service --state=running | grep ".service" | wc -l)
    local network_interfaces=$(ip -o link show | awk -F': ' '{print $2}' | tr '\n' ', ')
    local file_tree=$(tree -L 3 -d / 2>/dev/null || find / -maxdepth 3 -type d 2>/dev/null)
    local docker_info=$(docker info 2>/dev/null || echo "Docker未安装")
    local log_size=$(du -sh /var/log 2>/dev/null | cut -f1)

    # 创建描述文件
    cat > "$FolderPath/CharacterDesc.txt" << EOF
$base_desc
$base_desc_add1

当前VPS系统信息：
- 操作系统：$os_info
- 内核版本：$kernel_ver
- CPU型号：$cpu_info
- CPU核心数：$cpu_cores
- 内存大小：$mem_total
- 磁盘空间：$disk_info
- 运行时间大于：$uptime_info
- 公网IP：$ip_info
- 已安装软件包数量：$installed_packages
- 运行中的服务数量：$running_services
- 网络接口：$network_interfaces
- 系统日志大小：$log_size

Docker信息：
$docker_info

目录结构：
$file_tree
EOF

    # 检查文件是否创建成功
    if [ -f "$FolderPath/CharacterDesc.txt" ]; then
        echo -e "$OK 角色描述文件已更新"
        return 0
    else
        echo -e "$Err 角色描述文件创建失败"
        return 1
    fi
}

# 创建Gemini处理脚本
create_gemini_handler() {
    # 检查必要的包
    check_python_packages "requests" || return 1

    # 检查GeminiAPIKey是否为空
    if [ -z "$GeminiAPIKey" ]; then
        echo -e "$Tip 未检测到GeminiAPIKey"
        read -p "请输入你的 Google API Key: " GeminiAPIKey
        writeini "GeminiAPIKey" "$GeminiAPIKey"
    fi

    # 创建/更新角色描述文件
    create_character_desc || {
        echo -e "$Err 无法创建角色描述文件"
        return 1
    }

    cat > "$FolderPath/gemini_handler.py" <<EOF
import os
import requests
import json
from datetime import datetime

# 计数器文件路径
COUNTER_FILE = os.path.join('$FolderPath', 'gemini_counter.json')
DAILY_LIMIT = 80

def load_counter():
    try:
        if os.path.exists(COUNTER_FILE):
            with open(COUNTER_FILE, 'r') as f:
                data = json.load(f)
                # 检查是否是新的一天
                last_date = datetime.strptime(data['date'], '%Y-%m-%d').date()
                today = datetime.now().date()
                if last_date != today:
                    # 新的一天，重置计数器
                    return save_counter(0)
                return data['count']
        return 0
    except Exception:
        return 0

def save_counter(count):
    try:
        with open(COUNTER_FILE, 'w') as f:
            json.dump({
                'count': count,
                'date': datetime.now().strftime('%Y-%m-%d')
            }, f)
        return count
    except Exception:
        return 0

def process_response(response):
    # 获取当前计数
    count = load_counter()

    # 检查是否超过每日限额
    if count >= DAILY_LIMIT:
        return f"抱歉，今日AI回复次数已达上限（{DAILY_LIMIT}次/天）。请明天再试。"

    # 增加计数
    count += 1
    save_counter(count)

    # 去除所有*符号
    response = response.replace('*', '')

    # 添加头部信息
    header = f"主机名: {os.uname().nodename}   回复次数: {count}/{DAILY_LIMIT}\\n"
    return header + response

def make_gemini_request(text):
    # 首先检查计数器
    count = load_counter()
    if count >= DAILY_LIMIT:
        return f"抱歉，今日AI回复次数已达上限（{DAILY_LIMIT}次/天）。请明天再试。"

    api_key = '$GeminiAPIKey'
    if not api_key:
        return None

    url = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent"

    headers = {
        "Content-Type": "application/json"
    }

    # 从文件读取角色描述
    try:
        with open('$FolderPath/CharacterDesc.txt', 'r') as f:
            character_desc = f.read().strip()
    except Exception:
        character_desc = "你是VPSKeeper助手, 未找到角色描述文件, 也无法获取系统基本信息。"

    data = {
        "contents": [{
            "parts":[{"text": f"{character_desc}\\n\\n{text}"}]
        }]
    }

    try:
        response = requests.post(
            f"{url}?key={api_key}",
            headers=headers,
            json=data
        )

        if response.status_code == 200:
            raw_response = response.json()["candidates"][0]["content"]["parts"][0]["text"]
            return process_response(raw_response)
        else:
            return None
    except Exception:
        return None
EOF
}

create_message_processor() {
    # 检查必要的包
    check_python_packages "subprocess" || return 1

    cat > "$FolderPath/message_processor.py" <<EOF
import subprocess
import os
import re
from gemini_handler import make_gemini_request

# 消息长度限制配置
MAX_LINES = ${MaxLines:-10}  # 默认10行
MAX_CHARS = ${MaxChars:-800}  # 默认800字符

# 命令白名单和黑名单
WHITELIST_COMMANDS = {
    'ls': '列出目录内容',
    'netstat': '显示网络状态',
    'ss': '显示网络socket状态',
    'cat': '查看文件内容',
    'echo': '显示文本',
    'reboot': '重启系统',
    'uptime': '系统运行时间',
    'free': '内存使用情况',
    'df': '磁盘使用情况',
    'du': '目录空间使用情况',
    'ps': '进程状态',
    # 'top': '系统状态',
    # 'htop': '系统状态监控',
    'ifconfig': '网络接口配置',
    'ip': '网络配置',
    'ping': '连通性测试(使用-c3参数)',
    'date': '显示系统时间',
    'who': '当前登录用户',
    'w': '当前登录用户和负载',
    'uname': '系统信息',
    'pwd': '当前目录',
    'nginx': 'NGINX相关操作',
    'history': '命令历史'
}

BLACKLIST_COMMANDS = {
    'nano': '文本编辑器',
    'vim': '文本编辑器',
    'rm': '删除文件/目录',
    'mv': '移动/重命名文件',
    'cp': '复制文件',
    'chmod': '修改权限',
    'chown': '修改所有者',
    'dd': '数据复制/转换',
    'mkfs': '创建文件系统',
    'fdisk': '分区管理',
    'mount': '挂载文件系统',
    'umount': '卸载文件系统',
    'passwd': '修改密码',
    'useradd': '添加用户',
    'userdel': '删除用户',
    'groupadd': '添加用户组',
    'groupdel': '删除用户组',
    'shutdown': '关机',
    'init': '改变系统运行级别',
    'systemctl': '系统服务管理',
    'service': '服务管理',
    'iptables': '防火墙规则',
    'ufw': '防火墙管理',
    'apt': '包管理',
    'apt-get': '包管理',
    'yum': '包管理',
    'dnf': '包管理',
    'pacman': '包管理',
    'docker': 'Docker管理',
    'wget': '下载文件',
    'curl': '传输数据'
}

def is_command_allowed(command):
    """检查命令是否允许执行"""
    # 提取主命令（第一个单词）
    main_command = command.split()[0]

    # 检查是否在黑名单中
    if main_command in BLACKLIST_COMMANDS:
        return False, f"为了系统安全，命令 '{main_command}' 已被禁用。\\n原因：{BLACKLIST_COMMANDS[main_command]}"

    # 检查是否在白名单中
    if main_command in WHITELIST_COMMANDS:
        return True, None

    # 不在白名单中的命令也禁用
    return False, f"命令 '{main_command}' 不在允许列表中。\\n请使用以下允许的命令：\\n" + "\\n".join([f"- {cmd}: {desc}" for cmd, desc in WHITELIST_COMMANDS.items()])

def truncate_message(message, max_lines=MAX_LINES, max_chars=MAX_CHARS):
    """处理过长的消息"""
    if len(message) <= max_chars:
        return message

    # 保留第一行和最后N行
    lines = message.splitlines()
    if len(lines) > max_lines + 1:  # +1 是因为要显示第一行
        first_line = lines[0]
        last_lines = lines[-max_lines:]
        truncated_msg = f"{first_line}\n\n...(内容过长，仅显示最后{max_lines}行)...\n\n" + "\n".join(last_lines)
    else:
        # 如果行数不足但字符数过多，保留最后N个字符
        truncated_msg = f"...(内容过长，仅显示最后{max_chars}个字符)...\n\n" + message[-max_chars:]

    return truncated_msg

def execute_command(command):
    """执行系统命令并返回结果"""
    # 首先检查命令是否允许
    allowed, message = is_command_allowed(command)
    if not allowed:
        return message

    try:
        # 使用timeout限制命令执行时间，防止长时间运行
        result = subprocess.run(command, shell=True, capture_output=True, text=True, timeout=30)
        output = result.stdout or result.stderr
        # 处理输出长度
        return truncate_message(output.strip() if output else "命令执行完成，但没有输出")
    except subprocess.TimeoutExpired:
        return "命令执行超时（30秒）"
    except Exception as e:
        return f"命令执行错误: {str(e)}"

def get_help_message():
    """返回帮助信息"""
    help_text = f"""VPSKeeper 使用指南：

1. 系统命令
   /com <命令> - 执行系统命令
   例如：/com ls /root
   注意：
   - 输出内容过长时将只显示第一行和最后{MAX_LINES}行
   - 如果内容少于{MAX_LINES}行但超过{MAX_CHARS}字符，则只显示最后{MAX_CHARS}字符

2. 预设命令
   在WHsub.txt中定义的子函数触发器

3. 预设回复
   在WHreply.txt中定义的触发词

4. AI助手
   直接输入问题即可获得AI回复
   每天限额20次

5. 帮助信息
   /help - 显示此帮助信息

允许的命令列表：
"""
    return help_text + "\n".join([f"- {cmd}: {desc}" for cmd, desc in WHITELIST_COMMANDS.items()])

def process_message(text):
    # 处理帮助命令
    if text.strip() == "/help":
        help_message = get_help_message()
        subprocess.Popen(['bash', '$FolderPath/send_tg.sh',
            '$TelgramBotToken', '$ChatID_1', help_message])
        return True

    # 处理系统命令
    if text.startswith("/com "):
        command = text[5:].strip()  # 提取命令内容
        if command:
            result = execute_command(command)
            subprocess.Popen(['bash', '$FolderPath/send_tg.sh',
                '$TelgramBotToken', '$ChatID_1', result])
            return True
        else:
            subprocess.Popen(['bash', '$FolderPath/send_tg.sh',
                '$TelgramBotToken', '$ChatID_1', "请在/com后输入要执行的命令"])
            return True

    # 检查WHsub.txt中的命令
    try:
        with open('$FolderPath/WHsub.txt', 'r') as f:
            for line in f:
                command, function = line.strip().split()
                if text == command:
                    subprocess.Popen(['bash', '$FolderPath/VPSKeeper2025.sh', function.rstrip('()')])
                    return True
    except Exception:
        pass

    # 检查WHreply.txt中的回复
    try:
        with open('$FolderPath/WHreply.txt', 'r') as f:
            for line in f:
                trigger, response = line.strip().split(' ', 1)
                if text == trigger:
                    subprocess.Popen(['bash', '$FolderPath/send_tg.sh',
                        '$TelgramBotToken', '$ChatID_1', response])
                    return True
    except Exception:
        pass

    # 如果没有匹配的命令和回复，使用Gemini生成回复
    response = make_gemini_request(text)
    if response:
        subprocess.Popen(['bash', '$FolderPath/send_tg.sh',
            '$TelgramBotToken', '$ChatID_1', response])
        return True

    return False
EOF
}

# 创建WebHook处理脚本
create_webhook_handler() {
    # 检查必要的包
    check_python_packages "flask" "logging" || return 1

    # 确保日志目录存在
    echo -e "$Tip 正在初始化日志文件..."
    touch "$FolderPath/webhook.log" || {
        echo -e "$Err 无法创建日志文件"
        return 1
    }

    cat > "$FolderPath/webhook_handler.py" <<EOF
from flask import Flask, request, jsonify, render_template_string
import subprocess
import os
import json
import logging
from datetime import datetime
from message_processor import process_message

# 设置日志
logging.basicConfig(
    filename='$FolderPath/webhook.log',
    level=logging.DEBUG,
    format='%(asctime)s - %(levelname)s - %(message)s'
)

app = Flask(__name__)

HTML_TEMPLATE = '''
<!DOCTYPE html>
<html>
<head>
    <title>Webhook Status</title>
    <style>
        body { font-family: Arial, sans-serif; padding: 20px; }
        .status { background-color: #e8f5e9; padding: 20px; border-radius: 8px; }
        h1 { color: #2e7d32; }
    </style>
</head>
<body>
    <div class="status">
        <h1>Webhook Status: Active</h1>
        <p>Server Time: {{ current_time }}</p>
        <p>Status: Running</p>
        <p>Endpoint: {{ endpoint }}</p>
    </div>
</body>
</html>
'''

def save_unauthorized_message(message_data):
    """保存未授权消息到专门的JSON文件"""
    try:
        unauthorized_file = os.path.join('$FolderPath', 'unauthorized_messages.json')
        current_time = datetime.now().strftime('%Y-%m-%d %H:%M:%S')

        # 提取重要信息
        chat_id = message_data.get('chat', {}).get('id', 'unknown')
        username = message_data.get('from', {}).get('username', 'unknown')
        first_name = message_data.get('from', {}).get('first_name', 'unknown')
        text_content = message_data.get('text', '')
        message_id = message_data.get('message_id', 'unknown')

        new_entry = {
            "timestamp": current_time,
            "chat_id": chat_id,
            "username": username,
            "first_name": first_name,
            "message_id": message_id,
            "content": text_content,
            "raw_data": message_data
        }

        try:
            with open(unauthorized_file, 'r', encoding='utf-8') as f:
                messages = json.load(f)
        except (FileNotFoundError, json.JSONDecodeError):
            messages = []

        messages.append(new_entry)

        with open(unauthorized_file, 'w', encoding='utf-8') as f:
            json.dump(messages, f, ensure_ascii=False, indent=2)

        logging.info(f"收到来自chat_id: {chat_id}的消息")

    except Exception:
        pass  # 静默处理保存错误

# 根路径处理
@app.route('/', methods=['GET'])
def root():
    return jsonify({'status': 'ok', 'message': 'Server is running'})

# Webhook 路径处理
@app.route('$WebhookPath', methods=['GET', 'POST'])
def webhook():
    if request.method == 'GET':
        current_time = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
        return render_template_string(HTML_TEMPLATE,
            current_time=current_time,
            endpoint=request.host_url.rstrip('/') + '$WebhookPath')

    try:
        data = request.get_json()
        if not data or 'message' not in data:
            return jsonify({'status': 'ok'}), 200

        message = data['message']
        chat_id = str(message.get('chat', {}).get('id', ''))

        # 保存所有消息到通用日志
        with open('$FolderPath/message.json', 'a', encoding='utf-8') as f:
            timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
            f.write(f"[{timestamp}] {json.dumps(message, ensure_ascii=False)}\n")

        # 检查是否为授权用户
        if chat_id != '$ChatID_1':
            save_unauthorized_message(message)
            logging.info(f"收到非本机用户消息 (ChatID: {chat_id})")
            return jsonify({'status': 'ok'}), 200

        # 处理授权用户的消息
        if 'text' in message:
            text = message['text']  # 修复：正确获取text内容
            logging.debug(f"处理授权用户消息: {text}")
            process_message(text)

        return jsonify({'status': 'ok'}), 200

    except Exception as e:
        logging.error(f"系统错误: {str(e)}")  # 只记录系统级错误
        return jsonify({'status': 'ok'}), 200  # 对外仍返回成功

if __name__ == '__main__':
    # send_startup_message()
    app.run(host='0.0.0.0', port=$WebhookPort)
EOF
    chmod +x "$FolderPath/webhook_handler.py"
}

# 创建轮询处理脚本
create_polling_handler() {
    # 检查必要的包
    check_python_packages "requests" || return 1

    cat > "$FolderPath/polling_handler.py" <<EOF
import requests
import json
import time
import subprocess
import os
from datetime import datetime
from message_processor import process_message

def save_unauthorized_message(message_data):
    """保存未授权消息到专门的JSON文件"""
    try:
        unauthorized_file = os.path.join('$FolderPath', 'unauthorized_messages.json')
        current_time = datetime.now().strftime('%Y-%m-%d %H:%M:%S')

        # 提取重要信息
        chat_id = message_data.get('chat', {}).get('id', 'unknown')
        username = message_data.get('from', {}).get('username', 'unknown')
        first_name = message_data.get('from', {}).get('first_name', 'unknown')
        text_content = message_data.get('text', '')
        message_id = message_data.get('message_id', 'unknown')

        new_entry = {
            "timestamp": current_time,
            "chat_id": chat_id,
            "username": username,
            "first_name": first_name,
            "message_id": message_id,
            "content": text_content,
            "raw_data": message_data
        }

        try:
            with open(unauthorized_file, 'r', encoding='utf-8') as f:
                messages = json.load(f)
        except (FileNotFoundError, json.JSONDecodeError):
            messages = []

        messages.append(new_entry)

        with open(unauthorized_file, 'w', encoding='utf-8') as f:
            json.dump(messages, f, ensure_ascii=False, indent=2)

    except Exception:
        pass  # 静默处理保存错误

def save_message(message):
    """保存所有消息到通用日志"""
    try:
        with open('$FolderPath/message.json', 'a', encoding='utf-8') as f:
            timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
            f.write(f"[{timestamp}] {json.dumps(message, ensure_ascii=False)}\n")
    except Exception as e:
        print(f"Error saving message: {str(e)}")

def main():
    token = "$TelgramBotToken"
    offset = 0

    while True:
        try:
            response = requests.get(
                f"https://api.telegram.org/bot{token}/getUpdates",
                params={"offset": offset, "timeout": 30}
            ).json()

            if response.get("ok") and response.get("result"):
                for update in response["result"]:
                    offset = update["update_id"] + 1

                    if "message" in update:
                        message = update["message"]
                        chat_id = str(message.get('chat', {}).get('id', ''))

                        # 保存所有消息到通用日志
                        save_message(message)

                        # 检查是否为授权用户
                        if chat_id != '$ChatID_1':
                            # 记录非本机用户消息
                            print(f"收到非本机用户消息 (ChatID: {chat_id})")
                            save_unauthorized_message(message)
                            continue

                        # 处理授权用户的消息
                        if "text" in message:
                            process_message(message["text"])

        except requests.RequestException as e:
            print(f"Network error: {str(e)}")
            time.sleep(5)  # 网络错误时等待更长时间
        except Exception as e:
            print(f"Error: {str(e)}")

        time.sleep(1)

if __name__ == "__main__":
    main()
EOF
    chmod +x "$FolderPath/polling_handler.py"
}

# 启动webhook服务器
start_webhook_server() {
    # 检查是否已经运行
    if pgrep -f "webhook_handler.py" >/dev/null; then
        echo -e "$Err Webhook服务器已在运行!"
        return 1
    fi

    # 检查当前是否在虚拟环境中
    if [ ! -z "$VIRTUAL_ENV" ]; then
        echo -e "$Tip 检测到当前处于虚拟环境中: ${VIRTUAL_ENV}"
        read -p "是否继续使用当前虚拟环境? [Y/n] " use_current_venv
        if [[ $use_current_venv =~ ^[Nn]$ ]]; then
            deactivate 2>/dev/null
        else
            PYTHON="python3"
            return_val=0
        fi
    fi

    if [ -z "$return_val" ]; then
        # 询问环境选择
        divline
        echo "请选择Python环境："
        echo "1. 使用独立虚拟环境（推荐）"
        echo "2. 使用系统环境（不推荐）"
        divline
        read -p "请选择 [1-2]: " env_choice

        case $env_choice in
            2)
                echo -e "$Tip 警告：使用系统环境可能会影响其他Python应用"
                read -p "确定要继续吗? [y/N] " confirm
                if [[ ! $confirm =~ ^[Yy]$ ]]; then
                    return 1
                fi
                unset VIRTUAL_ENV
                PYTHON="python3"
                ;;
            *)
                # 默认使用虚拟环境
                if ! setup_venv; then
                    echo -e "$Err 虚拟环境设置失败!"
                    return 1
                fi
                PYTHON="$VenvPath/bin/python3"
                ;;
        esac
    fi

    # 创建并启动webhook handler
    create_webhook_handler
    nohup $PYTHON "$FolderPath/webhook_handler.py" >/dev/null 2>&1 &
    server_pid=$!

    # 等待服务器启动
    echo -e "$Tip 等待服务器启动..."
    for i in {1..10}; do
        if curl -s "http://127.0.0.1:$WebhookPort/" | grep -q '"status":"ok"'; then
            echo -e "$Tip Webhook服务器启动成功!"
            return 0
        fi
        sleep 1
    done

    # 如果启动失败，清理进程
    kill $server_pid 2>/dev/null
    echo -e "$Err Webhook服务器启动失败!"
    return 1
}

# 停止webhook服务器
stop_webhook_server() {
    # 停止 webhook 服务器
    pkill -f "webhook_handler.py"

    # 停止轮询服务
    if [ -f "$FolderPath/polling.pid" ]; then
        pid=$(cat "$FolderPath/polling.pid")
        kill $pid 2>/dev/null
        rm -f "$FolderPath/polling.pid"
    fi

    # 删除webhook设置
    curl -s -X POST "https://api.telegram.org/bot$TelgramBotToken/deleteWebhook"

    # 更新配置
    WebhookEnabled="false"
    WebhookURL=""
    writeini "WebhookEnabled" "false"
    writeini "WebhookURL" ""

    echo -e "$Tip Webhook服务器已停止!"
}

# 监控消息文件
monitor_messages() {
    echo -e "$Tip 开始监控消息..."
    echo -e "$Tip 按 Ctrl+C 退出监控"

    # 如果文件不存在则创建
    touch $FolderPath/message.json

    # 使用tail -f监控文件变化
    tail -f $FolderPath/message.json
}

# 设置虚拟环境
setup_venv() {
    if [ ! -d "$VenvPath" ]; then
        echo -e "$Tip 创建Python虚拟环境..."
        python3 -m venv "$VenvPath" || {
            echo -e "$Err 创建虚拟环境失败!"
            return 1
        }
    fi

    # 激活虚拟环境并安装依赖
    source "$VenvPath/bin/activate"
    pip install flask requests || {
        echo -e "$Err 安装依赖失败!"
        return 1
    }
}

# 删除虚拟环境
remove_venv() {
    if [ -d "$VenvPath" ]; then
        read -p "确定要删除虚拟环境吗? [y/N] " confirm
        if [[ $confirm =~ ^[Yy]$ ]]; then
            rm -rf "$VenvPath"
            echo -e "$Tip 虚拟环境已删除!"
        fi
    else
        echo -e "$Tip 虚拟环境不存在!"
    fi
}

# 主菜单
main_menu() {
    while true; do
        clear
        divline
        echo "  Telegram Bot Webhook 设置"
        divline
        echo "  1. 启用 Webhook"
        echo "  2. 禁用 Webhook"
        echo "  3. 查看 Webhook 状态"
        echo "  4. 重启 Webhook 服务器"
        echo "  5. 监控消息"
        echo "  6. 删除虚拟环境"
        echo "  x. 退出"
        divline
        echo "  当前状态: ${WebhookEnabled}"
        echo "  虚拟环境: $([ -d "$VenvPath" ] && echo "已安装" || echo "未安装")"
        divline

        read -p "请选择: " choice
        case $choice in
            1)
                check_python_packages
                create_message_processor
                create_gemini_handler
                setup_webhook
                ;;
            2)
                stop_webhook_server
                ;;
            3)
                show_status
                ;;
            4)
                restart_webhook
                ;;
            5)
                monitor_messages
                ;;
            6)
                remove_venv
                ;;
            x|X)
                # exit 0
                break
                ;;
            *)
                echo -e "$Err 无效的选择!"
                ;;
        esac

        read -p "按回车键继续..."
    done
}

# 设置webhook
setup_webhook() {
    # 检查必要参数
    readini
    if [[ -z "$TelgramBotToken" ]]; then
        echo -e "$Err 请先设置Telegram Bot Token!"
        return 1
    fi

    # 清除之前的updates（静默执行）
    curl -s -X POST "https://api.telegram.org/bot$TelgramBotToken/deleteWebhook" > /dev/null
    curl -s -X POST "https://api.telegram.org/bot$TelgramBotToken/getUpdates" -d "offset=-1" > /dev/null

    # 生成验证码
    WebhookSecret=$(generate_secret)
    echo -e "$Tip 生成的验证码: ${GRB}${WebhookSecret}${NC}"
    echo -e "$Tip 请在1分钟内通过Telegram Bot发送该验证码."

    # 等待验证
    local start_time=$(date +%s)
    local verified=false
    local last_update_id=0
    local remaining_time=60
    local retry_count=0
    local max_retries=3
    local last_error=""

    while [ $(($(date +%s) - start_time)) -lt 60 ]; do
        remaining_time=$((60 - ($(date +%s) - start_time)))
        echo -ne "\r$Tip 等待验证中... ${remaining_time}秒"

        # 使用超时参数进行curl请求
        local response=$(curl -s -m 5 "https://api.telegram.org/bot$TelgramBotToken/getUpdates?offset=$last_update_id")

        # 检查curl是否成功
        if [ $? -ne 0 ]; then
            retry_count=$((retry_count + 1))
            if [ $retry_count -le $max_retries ]; then
                echo -ne "\r$Tip 网络请求失败，正在重试 ($retry_count/$max_retries)..."
                sleep 1
                continue
            else
                echo -e "\n$Err 网络连接不稳定，但验证继续进行中..."
                retry_count=0
                sleep 2
                continue
            fi
        fi

        # 检查响应格式
        if ! echo "$response" | grep -q '"ok":\|"ok":'; then
            last_error="响应格式错误"
            retry_count=$((retry_count + 1))
            if [ $retry_count -le $max_retries ]; then
                sleep 1
                continue
            fi
        elif ! echo "$response" | grep -q '"ok":true'; then
            last_error="Bot API 错误"
            retry_count=$((retry_count + 1))
            if [ $retry_count -le $max_retries ]; then
                sleep 1
                continue
            else
                echo -e "\n$Err Bot连接失败，请检查网络或Token是否正确"
                echo -e "$Tip 错误信息: $response"
                if [ ! -z "$last_error" ]; then
                    echo -e "$Tip 上次错误: $last_error"
                fi
                return 1
            fi
        else
            retry_count=0
        fi

        # 验证码检查
        if echo "$response" | grep -q "$WebhookSecret"; then
            verified=true
            echo -e "\n$Tip Bot连接成功！"
            break
        fi

        # 更新last_update_id（增加错误处理）
        local new_update_id
        new_update_id=$(echo "$response" | grep -o '"update_id":[0-9]*' | grep -o '[0-9]*' | tail -n1)
        if [ ! -z "$new_update_id" ] && [ "$new_update_id" -gt "$last_update_id" ]; then
            last_update_id=$((new_update_id + 1))
        fi

        # 控制循环频率
        sleep 0.5
    done

    if [ "$verified" = false ]; then
        echo -e "\n$Err 验证超时，请重试!"
        if [ ! -z "$last_error" ]; then
            echo -e "$Tip 最后一次错误: $last_error"
        fi
        echo -e "$Tip 请确保:"
        echo -e "1. Bot Token是否正确"
        echo -e "2. 是否已经与Bot开始对话(/start)"
        echo -e "3. 验证码是否完全正确（包括大小写）"
        echo -e "4. 网络连接是否稳定"
        return 1
    fi

    # 继续执行后续设置过程
    echo -e "$Tip 验证成功, 开始配置Webhook..."

    # SSL证书配置选项
    divline
    echo "请选择SSL证书配置方式："
    echo "1. 配置域名/SSL证书"
    echo "2. 跳过SSL证书 (HTTP 不推荐)"
    echo "3. 跳过SSL证书设置 (不作处理)"
    divline
    read -p "请选择 [1-3]: " ssl_choice

    if [ -z "$ssl_choice" ]; then
        ssl_choice=1 # 默认选择配置SSL证书
    fi
    case $ssl_choice in
        1)
            # 设置域名
            read -p "请输入您的域名 (例如: abc.com): " domain
            if [ -z "$domain" ]; then
                echo -e "$Err 域名不能为空!"
                return 1
            fi

            # 检查域名解析
            if ! host "$domain" >/dev/null 2>&1; then
                echo -e "$Err 域名解析失败，请确保域名正确并已解析!"
                return 1
            fi

            # 检查现有配置
            source $ConfigFile
            local ssl_cert="$SSLCertPath"
            local ssl_key="$SSLKeyPath"
            if [ -f "$TGWhConf" ]; then
                current_cert=$(grep "ssl_certificate" "$TGWhConf" | awk '{print $2}' | sed 's/;$//')
                current_key=$(grep "ssl_certificate_key" "$TGWhConf" | awk '{print $2}' | sed 's/;$//')

                # 如果配置文件中没有值，但Nginx配置中有，则更新配置文件
                if [ -z "$ssl_cert" ] && [ ! -z "$current_cert" ]; then
                    writeini "SSLCertPath" "$current_cert"
                    ssl_cert=$current_cert
                fi
                if [ -z "$ssl_key" ] && [ ! -z "$current_key" ]; then
                    writeini "SSLKeyPath" "$current_key"
                    ssl_key=$current_key
                fi
            fi

            if [ ! -z "$ssl_cert" ] && [ ! -z "$ssl_key" ]; then
                echo -e "$Tip 检测到已配置的证书:"
                echo "证书路径: $ssl_cert"
                echo "密钥路径: $ssl_key"
                divline
                echo "1. 保留现有设置"
                echo "2. 更新证书设置"
                read -p "请选择 [1-2]: " cert_choice

                case $cert_choice in
                    1)
                        echo -e "$Tip 保留现有证书设置"
                        ;;
                    2)
                        echo -e "$Tip 请输入新的证书路径"
                        read -p "请输入SSL证书路径 (fullchain.pem): " new_cert
                        read -p "请输入SSL密钥路径 (privkey.pem): " new_key

                        if [ ! -f "$new_cert" ] || [ ! -f "$new_key" ]; then
                            echo -e "$Err 证书文件不存在!"
                            return 1
                        fi
                        ssl_cert=$new_cert
                        ssl_key=$new_key
                        writeini "SSLCertPath" "$ssl_cert"
                        writeini "SSLKeyPath" "$ssl_key"
                        ;;
                    *)
                        echo -e "$Err 无效的选择!"
                        return 1
                        ;;
                esac
            else
                read -p "请输入SSL证书路径 (fullchain.pem): " ssl_cert
                read -p "请输入SSL密钥路径 (privkey.pem): " ssl_key

                if [ ! -f "$ssl_cert" ] || [ ! -f "$ssl_key" ]; then
                    echo -e "$Err 证书文件不存在!"
                    return 1
                fi
                writeini "SSLCertPath" "$ssl_cert"
                writeini "SSLKeyPath" "$ssl_key"
            fi

            # 设置Nginx配置
            cat > "$TGWhConf" <<EOF
server {
    listen 443 ssl http2;
    server_name $domain;

    ssl_certificate $ssl_cert;
    ssl_certificate_key $ssl_key;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;

    # 允许大文件上传
    client_max_body_size 50M;

    # 增加超时时间
    proxy_connect_timeout 60s;
    proxy_send_timeout 60s;
    proxy_read_timeout 60s;

    location $WebhookPath {
        # 明确允许 GET 和 POST 方法
        if (\$request_method !~ ^(GET|POST)$) {
            return 405;
        }

        proxy_pass http://127.0.0.1:$WebhookPort;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;

        # 确保正确处理内容类型
        proxy_set_header Content-Type \$http_content_type;
        proxy_buffering off;

        # 错误处理
        proxy_intercept_errors off;
    }
}

server {
    listen 80;
    server_name $domain;
    return 301 https://\$server_name\$request_uri;
}
EOF
            WebhookURL="https://$domain$WebhookPath"
            ;;
        2)
            # 使用HTTP配置（轮询模式）
            echo -e "$Tip 您选择了HTTP模式（轮询模式）"
            echo -e "$Tip 警告：此模式会占用更多系统资源，仅建议临时使用"
            echo -e "$Tip 建议尽快配置SSL证书并切换到Webhook模式"
            read -p "按回车键继续..."

            # 创建并启动轮询处理器
            create_polling_handler
            nohup python3 "$FolderPath/polling_handler.py" >/dev/null 2>&1 &
            echo $! > "$FolderPath/polling.pid"

            WebhookURL="http://127.0.0.1:$WebhookPort$WebhookPath"
            WebhookEnabled="true"
            writeini "WebhookEnabled" "$WebhookEnabled"
            writeini "WebhookURL" "$WebhookURL"
            echo -e "$Tip HTTP轮询模式已启动"
            ;;
        3)
            # 跳过SSL证书设置
            echo -e "$Tip 已经跳过SSL证书设置，若手动配置请自行修改Nginx配置文件"
            echo -e "$Tip Nginx配置文件位置: $TGWhConf"
            return 1
            ;;
        *)
            echo -e "$Err 无效的选择!"
            return 1
            ;;
    esac

    # 重启Nginx
    if command -v systemctl >/dev/null 2>&1; then
        systemctl reload nginx
    else
        service nginx reload
    fi
    echo -e "$Tip Nginx配置已设置."

    # 根据模式设置webhook或继续轮询
    if [ "$ssl_choice" = "1" ]; then
        # HTTPS模式，设置webhook
        if start_webhook_server; then
            echo -e "$Tip 正在设置Telegram webhook..."

            # 删除现有webhook
            curl -s -X POST "https://api.telegram.org/bot$TelgramBotToken/deleteWebhook" > /dev/null
            sleep 2

            # 设置新的webhook
            local response=$(curl -s -X POST \
                "https://api.telegram.org/bot$TelgramBotToken/setWebhook" \
                -H "Content-Type: application/json" \
                -d "{\"url\":\"$WebhookURL\"}")

            if echo "$response" | grep -q '"ok":true'; then
                # 验证webhook是否设置成功
                local webhook_info=$(curl -s "https://api.telegram.org/bot$TelgramBotToken/getWebhookInfo")
                if echo "$webhook_info" | grep -q "\"url\":\"$WebhookURL\""; then
                    WebhookEnabled="true"
                    writeini "WebhookEnabled" "true"
                    writeini "WebhookURL" "$WebhookURL"
                    echo -e "$Tip Webhook设置成功!"
                    return 0
                fi
            fi

            echo -e "$Err Webhook设置失败! 响应: $response"
            stop_webhook_server
            return 1
        fi
    elif [ "$ssl_choice" = "2" ]; then
        # HTTP轮询模式不需要设置webhook
        WebhookEnabled="true"
        writeini "WebhookEnabled" "true"
        writeini "WebhookURL" "$WebhookURL"
        echo -e "$Tip HTTP轮询模式已启动"
    else
        # 如果选择了跳过SSL证书设置，直接返回
        WebhookEnabled="true"
        writeini "WebhookEnabled" "true"
        writeini "WebhookURL" "$WebhookURL"
        echo -e "$Tip 已跳过SSL证书设置，当前Webhook URL: $WebhookURL"
        return 0
    fi
}

# 显示状态
show_status() {
    readini
    divline
    echo "Webhook 状态"
    divline
    echo "启用状态: $WebhookEnabled"
    echo "URL: $WebhookURL"
    echo "端口: $WebhookPort"
    echo "路径: $WebhookPath"
    divline
}

# 重启webhook
restart_webhook() {
    if [ "$WebhookEnabled" = "true" ]; then
        stop_webhook_server
        sleep 2
        start_webhook_server
    else
        echo -e "$Err Webhook未启用!"
    fi
}

# 清屏
CLS() {
    if command -v apt &>/dev/null; then
        clear
    elif command -v opkg &>/dev/null; then
        clear
    elif command -v yum &>/dev/null; then
        printf "\033c"
    else
        echo
    fi
}

# 暂停
Pause() {
    echo -e "${Tip} 执行完成, 按 \"任意键\" 继续..."
    read -n 1 -s -r -p ""
}

# 分界线条
divline() {
    echo "—————————————————————————————————————————————————————————"
}

# 检测系统
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
        echo -e "$Err 系统不支持." >&2
        exit 1
    fi
    if [ -z $hostname_show ]; then
        if cat /proc/version 2>/dev/null | grep -q -E -i "openwrt"; then
            current_date=$(date +%m%d)
            hostname_show="openwrt_$current_date"
            writeini "hostname_show" "$hostname_show"
        else
            hostname_show=$(hostname)
            writeini "hostname_show" "$hostname_show"
        fi
    fi
}

getpid() {
    local process_name="$1"
    # local pre_name="${filename%%.*}"
    # local ext_name="${filename##*.}"
    # local enclosed_name='['"${process_name:0:1}"']'"${process_name:1}"
    # echo "process_name: $process_name"
    # echo "enclosed_name: $enclosed_name"
    local tg_pids=()
    local tg_pid=""

    # if ps x > /dev/null 2>&1; then
    #     # tg_pids=($(ps x | grep "$enclosed_name" | awk '{print $1}'))
    #     tg_pids=($(ps x | grep "$process_name" | grep -v grep | awk '{print $1}'))
    # else
    #     # tg_pids=($(ps | grep "$enclosed_name" | awk '{print $1}'))
    #     tg_pids=($(ps | grep "$process_name" | grep -v grep | awk '{print $1}'))
    # fi
    tg_pids=($(pgrep -a "$process_name" | grep -v grep | awk '{print $1}'))
    num_pid=${#tg_pids[@]}

    if [ "$num_pid" -eq 0 ]; then
        tg_pid=""
    else
        tg_pid=${tg_pids[0]}
    fi
    echo "$tg_pid"
}

killpid() {
    local process_name="$1"
    # local enclosed_name='['"${process_name:0:1}"']'"${process_name:1}"
    local tg_pids=()
    local tg_pid=""

    for ((i=1; i<=7; i++)); do
        # if ps x > /dev/null 2>&1; then
        #     if  ! ps x | grep "$process_name" | grep -v grep > /dev/null 2>&1; then
        #         break
        #     fi
        # else
        #     if  ! ps | grep "$process_name" | grep -v grep > /dev/null 2>&1; then
        #         break
        #     fi
        # fi
        if ! pgrep -a "$process_name" | grep -v grep > /dev/null 2>&1; then
            break
        fi

        # if ps x > /dev/null 2>&1; then
        #     tg_pids=($(ps x | grep "$process_name" | grep -v grep | awk '{print $1}'))
        # else
        #     tg_pids=($(ps | grep "$process_name" | grep -v grep | awk '{print $1}'))
        # fi
        tg_pids=($(pgrep -a "$process_name" | grep -v grep | awk '{print $1}'))
        num_pid=${#tg_pids[@]}

        if [ "$num_pid" -eq 0 ]; then
            break
        elif [ "$num_pid" -eq 1 ]; then
            if command -v pkill &>/dev/null; then
                pkill "$process_name" > /dev/null 2>&1 &
                pkill "$process_name" > /dev/null 2>&1 &
            else
                kill "${tg_pids[0]}" > /dev/null 2>&1 &
                kill "${tg_pids[0]}" > /dev/null 2>&1 &
            fi
        else
            if command -v pkill &>/dev/null; then
                # for ((i=0; i<=$num_pid; i++)); do # 在(())里面的变量也可以不需要$
                for ((i=0; i<num_pid; i++)); do
                    pkill "$process_name" > /dev/null 2>&1 &
                    pkill "$process_name" > /dev/null 2>&1 &
                done
            else
                for tg_pid in "${tg_pids[@]}"; do
                    kill "$tg_pid" > /dev/null 2>&1 &
                    kill "$tg_pid" > /dev/null 2>&1 &
                done
            fi
        fi
        sleep 0.5
    done
    # if ps x > /dev/null 2>&1; then
    #     if  ps x | grep "$process_name" | grep -v grep > /dev/null 2>&1; then
    #         tips="$Err 中止失败, 请检查!"
    #     fi
    # else
    #     if  ps | grep "$process_name" | grep -v grep > /dev/null 2>&1; then
    #         tips="$Err 中止失败, 请检查!"
    #     fi
    # fi
    if pgrep -a "$process_name" | grep -v grep > /dev/null 2>&1; then
        tips="$Err 中止失败, 请检查!"
    fi
}

# Crontab 相关操作
delcrontab() {
    local cronKW="$1"
    if crontab -l | grep -q "$cronKW"; then
        crontab -l | grep -v "$cronKW" | crontab -
    fi
}
addcrontab() {
    local cronKW="$1"
    (crontab -l 2>/dev/null; echo "$cronKW") | crontab -
    # if [[ "$cronKW" == *"bash"* ]]; then
    if [[ ! "$cronKW" == *"@reboot"* ]]; then
        /etc/init.d/cron restart > /dev/null 2>&1
    fi
}

# 数组去重处理
# interfaces=($(redup_array "${interfaces[@]}"))
redup_array() {
    local array_in=("$@")
    local array_out=()
    array_out=($(printf "%s\n" "${array_in[@]}" | awk '!a[$0]++'))
    echo "${array_out[@]}"
}

# 去除数组@及其后面
# interfaces_all=($(clear_array "${interfaces_all[@]}"))
clear_array() {
    local array_in=("$@")
    local array_clear=""
    local array_out=()
    for ((i=0; i<${#array_in[@]}; i++)); do
        array_clear=${array_in[$i]%@*}
        array_clear=${array_clear%:*}
        array_out[$i]="$array_clear"
    done
    echo "${array_out[@]}"
}

# 数组加入分隔符
# interfaces=$(sep_array interfaces ",")
sep_array() {
    local -n array_in=$1 # 引用传入的数组名称
    local separator=$2   # 分隔符
    local array_out=""
    for ((i = 0; i < ${#array_in[@]}; i++)); do
        array_out+="${array_in[$i]}"
        if ((i < ${#array_in[@]} - 1)); then
            array_out+="$separator"
        fi
    done
    echo "$array_out"
}

# 将'.'转换成'_' (主要是变量中不允许包含'.' 而很多VLAN设置都包含'.', 比如: eth0.1)
# interfaces=($(dtu_array "${interfaces[@]}"))
# choice="${choice//[, ]/}" # 删除','和'空格'
# choice="${choice//,/_}" # 替换','为'_'
# choice="${choice//[\[\]]/}" # 删除方括号'['和']'
dtu_array() {
    local array_in=("$@")
    local -a array_out=()
    for item in "${array_in[@]}"; do
        local new_item="${item//./_}"
        array_out+=("$new_item")
    done
    echo "${array_out[@]}"
}

# 将字串与变量结合组成新的变量
# INTERFACE_RX=$(caav "INTERFACE_RX" "$interface" "$rx_bytes")
caav() {
    local parameter="$1"
    local string="$2"  # 输入的字符串
    local variable="$3"  # 输入的变量名
    local value="$4"  # 输入的值
    local new_variable="${string}_${variable}"  # 新的变量名
    declare "$new_variable"="$value"  # 声明并赋值
    # 输出
    if [ "$parameter" == "-n" ]; then
        echo "$new_variable"  # 输出新变量的名称
    fi
    if [ "$parameter" == "-v" ]; then
        echo "${!new_variable}"  # 输出新变量的值 (此意思是将new_variable的值作为变量并输出它的值)
    fi
}

Checkprocess() {
    local process_name="$1"
    local prefix_name="${process_name%%.*}"
    local fullname=""$FolderPath"/"$process_name""
    # local enclosed_name='['"${process_name:0:1}"']'"${process_name:1}"
    local menu_tag=""

    if [ -f "$fullname" ] && crontab -l | grep -q "$fullname"; then
        # if ps x > /dev/null 2>&1; then
        #     if  ps x | grep "$fullname" | grep -v grep > /dev/null 2>&1; then
        #         menu_tag="$SETTAG"
        #     else
        #         menu_tag="$UNSETTAG"
        #     fi
        # else
        #     if ps | grep "$fullname" | grep -v grep > /dev/null 2>&1; then
        #         menu_tag="$SETTAG"
        #     else
        #         menu_tag="$UNSETTAG"
        #     fi
        # fi
        if pgrep -af "$fullname" | grep -v grep > /dev/null 2>&1; then
            menu_tag="$SETTAG"
        else
            menu_tag="$UNSETTAG"
        fi
    else
        menu_tag="$UNSETTAG"
    fi
    echo "$menu_tag"
}

Checkpara() {
    local para=$1
    local default_value=$2
    local value
    eval value=\$$para

    if [ -z "$value" ]; then
        eval $para=\"$default_value\"
    fi
}

# 检测设置标记
CheckSetup() {
    echo "检测中..."
    if [ -f $FolderPath/tg_login.sh ]; then
        if [ -f /etc/bash.bashrc ] && [ "$release" != "openwrt" ]; then
            if grep -q "bash $FolderPath/tg_login.sh > /dev/null 2>&1 &" /etc/bash.bashrc; then
                login_menu_tag="$SETTAG"
            else
                login_menu_tag="$UNSETTAG"
            fi
        elif [ -f /etc/profile ]; then
            if grep -q "bash $FolderPath/tg_login.sh > /dev/null 2>&1 &" /etc/profile; then
                login_menu_tag="$SETTAG"
            else
                login_menu_tag="$UNSETTAG"
            fi
        else
            login_menu_tag="$UNSETTAG"
        fi
    else
        login_menu_tag="$UNSETTAG"
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
    # if [ -f $FolderPath/tg_docker.sh ] && ps | grep '[t]g_docker' > /dev/null 2>&1; then
    #     if crontab -l | grep -q "$FolderPath/tg_docker.sh"; then
    #         docker_menu_tag="$SETTAG"
    #     else
    #         docker_menu_tag="$UNSETTAG"
    #     fi
    # else
    #     docker_menu_tag="$UNSETTAG"
    # fi

    # Checkprocess "tg_docker.sh"
    # docker_menu_tag="$menu_tag"
    # Checkprocess "tg_cpu.sh"
    # cpu_menu_tag="$menu_tag"
    # Checkprocess "tg_mem.sh"
    # mem_menu_tag="$menu_tag"
    # Checkprocess "tg_disk.sh"
    # disk_menu_tag="$menu_tag"
    # Checkprocess "tg_flow.sh"
    # flow_menu_tag="$menu_tag"
    # Checkprocess "tg_flrp.sh"
    # flrp_menu_tag="$menu_tag"
    # Checkprocess "tg_ddns.sh"
    # ddns_menu_tag="$menu_tag"

    docker_menu_tag=$(Checkprocess "tg_docker.sh")
    cpu_menu_tag=$(Checkprocess "tg_cpu.sh")
    mem_menu_tag=$(Checkprocess "tg_mem.sh")
    disk_menu_tag=$(Checkprocess "tg_disk.sh")
    flow_menu_tag=$(Checkprocess "tg_flow.sh")
    flrp_menu_tag=$(Checkprocess "tg_flrp.sh")
    # ddns_menu_tag=$(Checkprocess "tg_ddns.sh")

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

# 检查并安装依赖
CheckRely() {
    # 检查并安装依赖
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

# 检查时间格式是否正确
validate_time_format() {
    local time=$1
    local regex='^([01]?[0-9]|2[0-3]):([0-5]?[0-9])$'
    if [[ $time =~ $regex ]]; then
        echo "valid" # 正确返回
    else
        echo "invalid" # 不正确返回
    fi
}

SetAutoUpdate() {
    if [ ! -z "$autoud_pid" ] && pgrep -a '' | grep -Eq "^\s*$autoud_pid\s" > /dev/null; then
        tips="$Err PID(${GR}$autoud_pid${NC}) 正在发送中,请稍后..."
        return 1
    fi
    if [[ -z "${TelgramBotToken}" || -z "${ChatID_1}" ]]; then
        tips="$Err 参数丢失, 请设置后再执行 (先执行 ${GR}0${NC} 选项)."
        return 1
    fi
    if [ "$autorun" == "false" ]; then
        echo -e "输入定时更新时间, 格式如: 23:34 (即每天 ${GR}23${NC} 时 ${GR}34${NC} 分)"
        echo -en "请输入定时模式  (回车默认: ${GR}$AutoUpdateTime_de${NC} ): "
        read -er input_time
    else
        if [ -z "$AutoUpdateTime" ]; then
            input_time=""
        else
            input_time=$AutoUpdateTime
        fi
    fi
    if [ -z "$input_time" ]; then
        echo
        input_time="$AutoUpdateTime_de"
    fi
    if [ $(validate_time_format "$input_time") = "invalid" ]; then
        tips="$Err 输入格式不正确，请确保输入的时间格式为 'HH:MM'"
        return 1
    fi
    writeini "AutoUpdateTime" "$input_time"
    hour_ud=${input_time%%:*}
    minute_ud=${input_time#*:}

    minute_ud_next=$((minute_ud + 1))
    hour_ud_next=$hour_ud

    if [ $minute_ud_next -eq 60 ]; then
        minute_ud_next=0
        hour_ud_next=$((hour + 1))
        if [ $hour_ud_next -eq 24 ]; then
            hour_ud_next=0
        fi
    fi
    if [ ${#hour_ud} -eq 1 ]; then
    hour_ud="0${hour_ud}"
    fi
    if [ ${#minute_ud} -eq 1 ]; then
        minute_ud="0${minute_ud}"
    fi
    if [ ${#hour_ud_next} -eq 1 ]; then
    hour_ud_next="0${hour_ud_next}"
    fi
    if [ ${#minute_ud_next} -eq 1 ]; then
        minute_ud_next="0${minute_ud_next}"
    fi
    cront="$minute_ud $hour_ud * * *"
    cront_next="$minute_ud_next $hour_ud_next * * *"
    echo -e "$Tip 自动更新时间：$hour_ud 时 $minute_ud 分."
    cat <<EOF > "$FolderPath/tg_autoud.sh"
#!/bin/bash

retry=0
max_retries=3
mirror_retries=2

# 下载函数，接受下载链接作为参数
download_file() {
    wget -O "$FolderPath/VPSKeeper.sh" "\$1"
}

# 备份旧文件
if [ -f "$FolderPath/VPSKeeper.sh" ]; then
    mv "$FolderPath/VPSKeeper.sh" "$FolderPath/VPSKeeper_old.sh"
fi

# 尝试从原始地址下载
while [ \$retry -lt \$max_retries ]; do
    download_file "https://raw.githubusercontent.com/redstarxxx/shell/main/VPSKeeper.sh"
    if [ -s "$FolderPath/VPSKeeper.sh" ]; then
        echo "下载成功"
        break
    else
        echo "下载失败，尝试重新下载..."
        ((retry++))
    fi
done

# 如果原始地址下载失败，则尝试从备用镜像地址下载
if [ ! -s "$FolderPath/VPSKeeper.sh" ]; then
    echo "尝试从备用镜像地址下载..."
    retry=0
    while [ \$retry -lt \$mirror_retries ]; do
        download_file "https://mirror.ghproxy.com/https://raw.githubusercontent.com/redstarxxx/shell/main/VPSKeeper.sh"
        if [ -s "$FolderPath/VPSKeeper.sh" ]; then
            echo "备用镜像下载成功"
            break
        else
            echo "备用镜像下载失败，尝试重新下载..."
            ((retry++))
        fi
    done
fi

# 检查是否下载成功
if [ ! -s "$FolderPath/VPSKeeper.sh" ]; then
    echo "下载失败，无法获取 VPSKeeper.sh 文件"
    # 如果下载失败，将旧文件恢复
    if [ -f "$FolderPath/VPSKeeper_old.sh" ]; then
        mv "$FolderPath/VPSKeeper_old.sh" "$FolderPath/VPSKeeper.sh"
    fi
    exit 1
fi

# 比较文件大小
if [ -f "$FolderPath/VPSKeeper_old.sh" ]; then
    old_size=\$(wc -c < "$FolderPath/VPSKeeper_old.sh")
    new_size=\$(wc -c < "$FolderPath/VPSKeeper.sh")
    if [ \$old_size -ne \$new_size ]; then
        echo "更新成功"
    else
        echo "无更新内容"
    fi
fi

# 删除旧文件
if [ -f "$FolderPath/VPSKeeper_old.sh" ]; then
    rm "$FolderPath/VPSKeeper_old.sh"
fi
EOF
    chmod +x $FolderPath/tg_autoud.sh
    delcrontab "$FolderPath/tg_autoud.sh"
    addcrontab "$cront bash $FolderPath/tg_autoud.sh > $FolderPath/tg_autoud.log 2>&1 &"
    if [ "$autorun" == "false" ]; then
        echo -e "如果开启 ${REB}静音模式${NC} 更新时你将不会收到提醒通知, 是否要开启静音模式?"
        read -e -p "请输入你的选择 回车.(默认开启)   N.不开启: " choice
    else
        choice=""
    fi
    if [ "$choice" == "N" ] || [ "$choice" == "n" ]; then
        delcrontab "$FolderPath/VPSKeeper.sh"
        addcrontab "$cront_next bash $FolderPath/VPSKeeper.sh \"auto\" 2>&1 &"
        mute_mode="更新时通知"
    else
        delcrontab "$FolderPath/VPSKeeper.sh"
        addcrontab "$cront_next bash $FolderPath/VPSKeeper.sh \"auto\" \"mute\" 2>&1 &"
        mute_mode="静音模式"
    fi
    if [ "$mute" == "false" ]; then
        send_time=$(echo $(date +%s%N) | cut -c 16-)
        $FolderPath/send_tg.sh "$TelgramBotToken" "$ChatID_1" "自动更新脚本设置成功 ⚙️"$'\n'"主机名: $hostname_show"$'\n'"更新时间: 每天 $hour_ud 时 $minute_ud 分"$'\n'"通知模式: $mute_mode" "autoud" "$send_time" &
        (sleep 15 && $FolderPath/del_lm_tg.sh "$TelgramBotToken" "$ChatID_1" "autoud" "$send_time") &
        sleep 1
        # getpid "send_tg.sh"
        # autoud_pid="$tg_pid"
        autoud_pid=$(getpid "send_tg.sh")
    fi
    tips="$Tip 自动更新设置成功, 更新时间: 每天 $hour_ud 时 $minute_ud 分, 通知模式: ${GR}$mute_mode${NC}"
}

# 发送Telegram消息的函数
send_telegram_message() {
    curl -s -X POST "${ProxyURL}https://api.telegram.org/bot$TelgramBotToken/sendMessage" \
        -d chat_id="$ChatID_1" -d text="$1" > /dev/null
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
    # mem_total=$(top -bn1 | awk '/^MiB Mem/ { gsub(/Mem|total,|free,|used,|buff\/cache|:/, " ", $0); print int($2) }')
    # swap_total=$(top -bn1 | awk '/^MiB Swap/ { gsub(/Swap|total,|free,|used,|buff\/cache|:/, " ", $0); print int($2) }')
    mem_total_bytes=$(free | grep 'Mem:' | awk '{print int($2)}')
    mem_total=$((mem_total_bytes / 1024))
    swap_total_bytes=$(free | grep 'Swap:' | awk '{print int($2)}')
    swap_total=$((swap_total_bytes / 1024))
    disk_total=$(df -h / | awk 'NR==2 {print $2}')
    disk_used=$(df -h / | awk 'NR==2 {print $3}')
    # echo "主机名: $hostname_show"$'\n'"CPUs: $cpuusedOfcpus"$'\n'"内存: $mem_total"\$'\n'"交换: $swap_total"$'\n'"磁盘: $disk_total"
}

# 设置ini参数文件
SetupIniFile() {
    # 设置电报机器人参数
    autochoice=5
    divline
    echo -e "$Tip 默认机器人: ${GR}@vpskeeperbot${NC} 使用前必须添加并点击 ${GR}/start${NC}"
    while true; do
        source $ConfigFile
        if [ "$autorun" == "true" ]; then
            if [ "$autochoice" = "10" ]; then
                choice="*"
            else
                choice="$autochoice"
                ((autochoice++))
            fi
        else
            divline
            echo -e "${GR}1${NC}. BOT Token\t\t${GR}$TelgramBotToken${NC}"
            echo -e "${GR}2${NC}. CHAT ID\t\t${GR}$ChatID_1${NC}"
            echo -e "${GR}3${NC}. CPU检测工具\t\t${GR}$CPUTools${NC}"
            echo -e "${GR}4${NC}. 设置流量上限\t\t${GR}$FlowThresholdMAX${NC}"
            if [ "$SHUTDOWN_RT" == "true" ]; then
                settag="${GR}已启动${NC}"
            else
                settag=""
            fi
            echo -e "${GR}5${NC}. 设置关机记录流量\t$settag"
            if [ ! -z "$ProxyURL" ]; then
                settag="${GR}已启动${NC} | ${GR}$ProxyURL${NC}"
            else
                settag=""
            fi
            echo -e "${GR}6${NC}. 设置TG代理 (${RE}国内${NC})\t$settag"
            if [ "$SendUptime" == "true" ]; then
                # read uptime idle_time < /proc/uptime
                # uptime=${uptime%.*}
                # days=$((uptime/86400))
                # hours=$(( (uptime%86400)/3600 ))
                # minutes=$(( (uptime%3600)/60 ))
                # seconds=$((uptime%60))
                read uptime idle_time < /proc/uptime
                uptime=${uptime%.*}
                days=$(awk -v up="$uptime" 'BEGIN{print int(up/86400)}')
                hours=$(awk -v up="$uptime" 'BEGIN{print int((up%86400)/3600)}')
                minutes=$(awk -v up="$uptime" 'BEGIN{print int((up%3600)/60)}')
                seconds=$(awk -v up="$uptime" 'BEGIN{print int(up%60)}')
                uptimeshow="系统已运行: $days 日 $hours 时 $minutes 分 $seconds 秒"
                settag="${GR}已启动${NC} | ${GR}$uptimeshow${NC}"
            else
                settag=""
            fi
            echo -e "${GR}7${NC}. 设置发送在线时长\t$settag"
            if [ "$SendIP" == "true" ] && [ ! -z "$GetIPAddress" ]; then
                settag="${GR}已启动${NC} | ${GR}$GetIPAddress${NC}"
            else
                settag=""
            fi
            echo -e "${GR}8${NC}. 设置发送IP地址\t$settag"
            if [ "$SendPrice" == "true" ]; then
                settag="${GR}已启动${NC} | ${GR}$GetPriceType${NC}"
            else
                settag=""
            fi
            echo -e "${GR}9${NC}. 设置发送货币报价\t$settag"
            echo -e "${GR}回车${NC}. 退出设置"
            divline
            read -e -p "请输入对应的序号: " choice
        fi
        case $choice in
            1)
                # 设置BOT Token
                echo -e "$Tip ${REB}BOT Token${NC} 获取方法: 在 Telgram 中添加机器人 @BotFather, 输入: /newbot"
                divline
                if [ "$TelgramBotToken" != "" ]; then
                    echo -e "当前${GR}[BOT Token]${NC}: $TelgramBotToken"
                else
                    echo -e "当前${GR}[BOT Token]${NC}: 空"
                fi
                divline
                read -e -p "请输入 BOT Token (回车跳过修改 / 输入 R 使用默认机器人): " bottoken
                if [ "$bottoken" == "r" ] || [ "$bottoken" == "R" ]; then
                    writeini "TelgramBotToken" "6718888288:AAG5aVWV4FCmS0ItoPy1-3KkhdNg8eym5AM"
                    UN_ALL
                    tips="$Tip 接收信息已经改动, 请重新设置所有通知."
                    break
                fi
                if [ ! -z "$bottoken" ]; then
                    writeini "TelgramBotToken" "$bottoken"
                    UN_ALL
                    tips="$Tip 接收信息已经改动, 请重新设置所有通知."
                    break
                else
                    echo -e "$Tip 输入为空, 跳过操作."
                    tips=""
                fi
                ;;
            2)
                # 设置Chat ID
                echo -e "$Tip ${REB}Chat ID${NC} 获取方法: 在 Telgram 中添加机器人 @userinfobot, 点击或输入: /start"
                divline
                if [ "$ChatID_1" != "" ]; then
                    echo -e "当前${GR}[CHAT ID]${NC}: $ChatID_1"
                else
                    echo -e "当前${GR}[CHAT ID]${NC}: 空"
                fi
                divline
                read -e -p "请输入 Chat ID (回车跳过修改): " cahtid
                if [ ! -z "$cahtid" ]; then
                    if [[ $cahtid =~ ^[0-9]+$ ]]; then
                        writeini "ChatID_1" "$cahtid"
                        UN_ALL
                        tips="$Tip 接收信息已经改动, 请重新设置所有通知."
                        break
                    else
                        echo -e "$Err ${REB}输入无效${NC}, Chat ID 必须是数字, 跳过操作."
                    fi
                else
                    echo -e "$Tip 输入为空, 跳过操作."
                    tips=""
                fi
                ;;
            3)
                # 设置CPU检测工具
                if cat /proc/version 2>/dev/null | grep -q -E -i "openwrt"; then
                    tips="$Tip OpenWRT 系统只能使用默认的 top 工具."
                    break
                else
                    echo -e "$Tip 请选择 ${REB}CPU 检测工具${NC}: 1.top(系统自带) 2.sar(更专业) 3.top+sar"
                    divline
                    if [ "$CPUTools" != "" ]; then
                        echo -e "当前${GR}[CPU 检测工具]${NC}: $CPUTools"
                    else
                        echo -e "当前${GR}[CPU 检测工具]${NC}: 空"
                    fi
                    divline
                    read -e -p "请输入序号 (默认采用 1.top / 回车跳过修改): " choice
                    if [ ! -z "$choice" ]; then
                        if [ "$choice" == "1" ]; then
                            CPUTools="top"
                            writeini "CPUTools" "$CPUTools"
                        elif [ "$choice" == "2" ]; then
                            CPUTools="sar"
                            writeini "CPUTools" "$CPUTools"
                        elif [ "$choice" == "3" ]; then
                            CPUTools="top_sar"
                            writeini "CPUTools" "$CPUTools"
                        fi
                    else
                        echo -e "$Tip 输入为空, 跳过操作."
                        tips=""
                    fi
                fi
                ;;
            4)
                # 设置流量上限（仅参考）
                echo -en "请设置 流量上限 ${GR}数字 + MB/GB/TB${NC} (回车默认: $FlowThresholdMAX_de): "
                read -er threshold_max
                if [ ! -z "$threshold_max" ]; then
                    if [[ $threshold_max =~ ^[0-9]+(\.[0-9])?$ ]] || [[ $threshold_max =~ ^[0-9]+(\.[0-9]+)?(M)$ ]] || [[ $threshold_max =~ ^[0-9]+(\.[0-9]+)?(MB)$ ]] || [[ $threshold_max =~ ^[0-9]+(\.[0-9]+)?(m)$ ]] || [[ $threshold_max =~ ^[0-9]+(\.[0-9]+)?(mb)$ ]]; then
                        threshold_max=${threshold_max%M}
                        threshold_max=${threshold_max%MB}
                        threshold_max=${threshold_max%m}
                        threshold_max=${threshold_max%mb}
                        if awk -v value="$threshold_max" 'BEGIN { exit !(value >= 1024 * 1024) }'; then
                            threshold_max=$(awk -v value="$threshold_max" 'BEGIN { printf "%.1f", value / (1024 * 1024) }')
                            threshold_max="${threshold_max}TB"
                        elif awk -v value="$threshold_max" 'BEGIN { exit !(value >= 1024) }'; then
                            threshold_max=$(awk -v value="$threshold_max"_max 'BEGIN { printf "%.1f", value / 1024 }')
                            threshold_max="${threshold_max}GB"
                        else
                            threshold_max="${threshold_max}MB"
                        fi
                        writeini "FlowThresholdMAX" "$threshold_max"
                    elif [[ $threshold_max =~ ^[0-9]+(\.[0-9]+)?(G)$ ]] || [[ $threshold_max =~ ^[0-9]+(\.[0-9]+)?(GB)$ ]] || [[ $threshold_max =~ ^[0-9]+(\.[0-9]+)?(g)$ ]] || [[ $threshold_max =~ ^[0-9]+(\.[0-9]+)?(gb)$ ]]; then
                        threshold_max=${threshold_max%G}
                        threshold_max=${threshold_max%GB}
                        threshold_max=${threshold_max%g}
                        threshold_max=${threshold_max%gb}
                        if awk -v value="$threshold_max" 'BEGIN { exit !(value >= 1024) }'; then
                            threshold_max=$(awk -v value="$threshold_max"_max 'BEGIN { printf "%.1f", value / 1024 }')
                            threshold_max="${threshold_max}TB"
                        else
                            threshold_max="${threshold_max}GB"
                        fi
                        writeini "FlowThresholdMAX" "$threshold_max"
                    elif [[ $threshold_max =~ ^[0-9]+(\.[0-9]+)?(T)$ ]] || [[ $threshold_max =~ ^[0-9]+(\.[0-9]+)?(TB)$ ]] || [[ $threshold_max =~ ^[0-9]+(\.[0-9]+)?(t)$ ]] || [[ $threshold_max =~ ^[0-9]+(\.[0-9]+)?(tb)$ ]]; then
                        threshold_max=${threshold_max%T}
                        threshold_max=${threshold_max%TB}
                        threshold_max=${threshold_max%t}
                        threshold_max=${threshold_max%tb}
                        threshold_max="${threshold_max}TB"
                        writeini "FlowThresholdMAX" "$threshold_max"
                    else
                        echo -e "$Err ${REB}输入无效${NC}, 报警阈值 必须是: 数字|数字MB/数字GB (%.1f) 的格式(支持1位小数), 跳过操作."
                        return 1
                    fi
                else
                    echo
                    writeini "FlowThresholdMAX" "$FlowThresholdMAX_de"
                    echo -e "$Tip 输入为空, 默认最大流量上限为: $FlowThresholdMAX_de"
                fi
                ;;
            5)
                # 设置关机记录流量
                if [ "$autorun" == "true" ]; then
                    choice=""
                else
                    if cat /proc/version 2>/dev/null | grep -q -E -i "openwrt"; then
                        tips="$Err OpenWRT 系统暂不支持."
                        break
                    fi
                    if ! command -v systemd &>/dev/null; then
                        tips="$Err 系统未检测到 \"systemd\" 程序, 无法设置关机通知."
                        break
                    fi
                    if [[ -z "${TelgramBotToken}" || -z "${ChatID_1}" ]]; then
                        tips="$Err 参数丢失, 请设置后再执行 (先执行 ${GR}0${NC} 选项)."
                        break
                    fi
                    read -e -p "请选择是否开启 设置关机记录流量  Y.开启  回车.关闭(删除记录): " choice
                fi
                if [ "$choice" == "y" ] || [ "$choice" == "Y" ]; then
                    cat <<EOF > $FolderPath/tg_shutdown_rt.sh
#!/bin/bash

ConfigFile=$ConfigFile

$(declare -f writeini)
$(declare -f redup_array)
$(declare -f clear_array)
$(declare -f caav)

declare -A INTERFACE_RT_RX_B
declare -A INTERFACE_RT_TX_B
declare -A INTERFACE_RT_RX_PB
declare -A INTERFACE_RT_TX_PB
declare -a interfaces_all=()

interfaces_all=\$(ip -br link | awk '{print \$1}' | tr '\n' ' ')
interfaces_all=(\$(redup_array "\${interfaces_all[@]}"))
interfaces_all=(\$(clear_array "\${interfaces_all[@]}"))
# declare -a interfaces=(\$interfaces_all)
interfaces=(\${interfaces_all[@]})
# echo "统计接口: \${interfaces[@]}"
# for ((i = 0; i < \${#interfaces[@]}; i++)); do
#     echo "\$((i+1)): \${interfaces[i]}"
# done

source \$ConfigFile

for interface in "\${interfaces[@]}"; do
    interface_nodot=\${interface//./_}
    INTERFACE_RT_RX_PB[\$interface_nodot]=\${INTERFACE_RT_RX_B[\$interface_nodot]}
    # echo "读取: INTERFACE_RT_RX_PB[\$interface_nodot]: \${INTERFACE_RT_RX_PB[\$interface_nodot]}"
    INTERFACE_RT_TX_PB[\$interface_nodot]=\${INTERFACE_RT_TX_B[\$interface_nodot]}
    # echo "读取: INTERFACE_RT_TX_PB[\$interface_nodot]: \${INTERFACE_RT_TX_PB[\$interface_nodot]}"
done

for interface in "\${interfaces[@]}"; do
    interface_nodot=\${interface//./_}
    echo "----------------------------------- FOR: \$interface"
    rx_bytes=\$(ip -s link show \$interface | awk '/RX:/ { getline; print \$1 }')
    echo "rx_bytes: \$rx_bytes"
    if [ ! -z "\$rx_bytes" ] && [[ \$rx_bytes =~ ^[0-9]+(\.[0-9]+)?$ ]]; then

        INTERFACE_RT_RX_B[\$interface_nodot]=\$rx_bytes
        if [ ! -z "\${INTERFACE_RT_RX_PB[\$interface_nodot]}" ] && [[ \${INTERFACE_RT_RX_PB[\$interface_nodot]} =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
            INTERFACE_RT_RX_B[\$interface_nodot]=\$(awk -v v1="\${INTERFACE_RT_RX_B[\$interface_nodot]}" -v v2="\${INTERFACE_RT_RX_PB[\$interface_nodot]}" 'BEGIN { printf "%.0f", v1 + v2 }')
        fi

        sed -i "/^INTERFACE_RT_RX_B\[\$interface_nodot\]=/d" \$ConfigFile
        writeini "INTERFACE_RT_RX_B[\$interface_nodot]" "\${INTERFACE_RT_RX_B[\$interface_nodot]}"
        echo "INTERFACE_RT_RX_B[\$interface_nodot]: \${INTERFACE_RT_RX_B[\$interface_nodot]}"
    fi

    tx_bytes=\$(ip -s link show \$interface | awk '/TX:/ { getline; print \$1 }')
    echo "tx_bytes: \$tx_bytes"
    if [ ! -z "\$tx_bytes" ] && [[ \$tx_bytes =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
        INTERFACE_RT_TX_B[\$interface_nodot]=\$tx_bytes

        if [ ! -z "\${INTERFACE_RT_TX_PB[\$interface_nodot]}" ] && [[ \${INTERFACE_RT_TX_PB[\$interface_nodot]} =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
            INTERFACE_RT_TX_B[\$interface_nodot]=\$(awk -v v1="\${INTERFACE_RT_TX_B[\$interface_nodot]}" -v v2="\${INTERFACE_RT_TX_PB[\$interface_nodot]}" 'BEGIN { printf "%.0f", v1 + v2 }')
        fi

        sed -i "/^INTERFACE_RT_TX_B\[\$interface_nodot\]=/d" \$ConfigFile
        writeini "INTERFACE_RT_TX_B[\$interface_nodot]" "\${INTERFACE_RT_TX_B[\$interface_nodot]}"
        echo "INTERFACE_RT_TX_B[\$interface_nodot]: \${INTERFACE_RT_TX_B[\$interface_nodot]}"
    fi

done
echo "====================================== 检正部分"
echo "文件内容:"
cat \$ConfigFile | grep '^INTERFACE_RT'
echo "======================================"
echo "读取测试:"
source \$ConfigFile
for interface in "\${interfaces[@]}"; do
    interface_nodot=\${interface//./_}
    echo "interface: \$interface"
    echo "interface_nodot: \$interface_nodot"
    echo "写入变量名称: INTERFACE_RT_RX_B[\$interface_nodot]"
    INTERFACE_RT_RX_B[\$interface_nodot]=\${INTERFACE_RT_RX_B[\$interface_nodot]}
    echo "读取: INTERFACE_RT_RX_B[\$interface_nodot]: \${INTERFACE_RT_RX_B[\$interface_nodot]}"
    echo "写入变量名称: INTERFACE_RT_TX_B[\$interface_nodot]"
    INTERFACE_RT_TX_B[\$interface_nodot]=\${INTERFACE_RT_TX_B[\$interface_nodot]}
    echo "读取: INTERFACE_RT_TX_B[\$interface_nodot]: \${INTERFACE_RT_TX_B[\$interface_nodot]}"
done
echo "=============================================="
echo
EOF
                    chmod +x $FolderPath/tg_shutdown_rt.sh
                    cat <<EOF > /etc/systemd/system/tg_shutdown_rt.service
[Unit]
Description=tg_shutdown
DefaultDependencies=no
Before=shutdown.target

[Service]
Type=oneshot
ExecStart=/bin/bash -c 'exec $FolderPath/tg_shutdown_rt.sh >> $FolderPath/tg_shutdown_rt.log 2>&1'
TimeoutStartSec=0

[Install]
WantedBy=shutdown.target
EOF
                    systemctl enable tg_shutdown_rt.service > /dev/null
                    writeini "SHUTDOWN_RT" "true"
                    echo -e "$Tip 关机记录流量 已经成功设置."
                else
                    systemctl stop tg_shutdown_rt.service > /dev/null 2>&1
                    systemctl disable tg_shutdown_rt.service > /dev/null 2>&1
                    sleep 1
                    rm -f /etc/systemd/system/tg_shutdown_rt.service
                    rm -f $FolderPath/tg_shutdown_rt.log
                    sed -i "/^INTERFACE_RT_RX_B/d" $ConfigFile
                    sed -i "/^INTERFACE_RT_TX_B/d" $ConfigFile
                    writeini "SHUTDOWN_RT" "false"
                    echo -e "$Tip 关机记录流量 (已删除记录) 已经取消 / 删除."
                fi
                ;;
            6)
                # 设置Telegram代理(国内使用)
                prev_ProxyURL=$ProxyURL
                if [ "$autorun" == "true" ]; then
                    inputurl="1"
                else
                    # if [ -z "$ProxyURL" ]; then
                    #     echo -e "$Inf 目前代理: ${GRB}无${NC}"
                    # else
                    #     echo -e "$Inf 目前代理: ${GRB}$ProxyURL${NC}"
                    # fi
                    divline
                    echo "以下代理可用:"
                    echo -e "${GR}1${NC}. https://xx80.eu.org/p/"
                    echo -e "${GR}2${NC}. https://cp.iexx.eu.org/proxy/"
                    echo -e "${GR}3${NC}. https://mirror.ghproxy.com/"
                    echo -e "${GR}4${NC}. https://endpoint.fastgit.org/"
                    read -e -p "请输入以上序号或代理地址 (回车取消代理): " inputurl
                fi
                if [ -z "$inputurl" ]; then
                    inputurl=""
                    writeini "ProxyURL" "$inputurl"
                elif [ "$inputurl" == "1" ]; then
                    inputurl="https://cp.255.cloudns.biz/proxy/"
                    writeini "ProxyURL" "$inputurl"
                elif [ "$inputurl" == "2" ]; then
                    inputurl="https://cp.iexx.eu.org/proxy/"
                    writeini "ProxyURL" "$inputurl"
                elif [ "$inputurl" == "3" ]; then
                    inputurl="https://mirror.ghproxy.com/"
                    writeini "ProxyURL" "$inputurl"
                elif [ "$inputurl" == "4" ]; then
                    inputurl="https://endpoint.fastgit.org/"
                    writeini "ProxyURL" "$inputurl"
                elif [[ $inputurl =~ ^https?:// ]]; then
                    # 如果网址后面没有"/"则在网址后面加上"/"
                    if [ "${inputurl: -1}" != "/" ]; then
                        inputurl="${inputurl}/"
                    fi
                    writeini "ProxyURL" "$inputurl"
                    echo -e "$Tip 代理地址: ${GRB}$inputurl${NC}"
                else
                    echo -e "$Err ${REB}输入无效${NC}, 代理地址 必须是以上序号或以 http(s):// 开头的网址."
                    inputurl=$prev_ProxyURL
                fi
                if [ -z $inputurl ]; then
                    inputurl_show="无"
                else
                    inputurl_show=$inputurl
                fi
                if [ "$prev_ProxyURL" != "$inputurl" ]; then
                    cat <<EOF > $FolderPath/send_tg.sh
#!/bin/bash
curl -s -X POST "${inputurl}https://api.telegram.org/bot\${1}/sendMessage" \
    -d chat_id="\${2}" -d text="\${3}" > /dev/null 2>&1 &
EOF
                    echo -e "$Tip 代理地址: ${GRB}$inputurl_show${NC}"
                else
                    echo -e "$Tip 代理地址: ${GRB}$inputurl_show${NC} ${GR}未变更${NC}."
                fi
                ;;
            7)
                # 设置是否发送机器在线时长
                if [ "$autorun" == "true" ]; then
                    choice="Y"
                else
                    # if [ -z $SendUptime ] || [ "$SendUptime" == "false" ]; then
                    #     echo -e "$Inf 目前是否发送机器在线时长: ${GRB}否${NC}"
                    # else
                    #     echo -e "$Inf 目前是否发送机器在线时长: ${GRB}是${NC}"
                    # fi
                    divline
                    read -e -p "请选择是否发送机器在线时长  Y.是  其它/回车.否: " choice
                fi
                if [ "$choice" == "y" ] || [ "$choice" == "Y" ]; then
                    writeini "SendUptime" "true"
                    echo -e "$Tip 已开启发送机器在线时长."
                else
                    writeini "SendUptime" "false"
                    echo -e "$Tip 已关闭发送机器在线时长."
                fi
                ;;
            8)
                # 设置是否发送IP地址
                if [ "$autorun" == "true" ]; then
                    choice="Y"
                    inputurl="1"
                    input46="4"
                else
                    # if [ -z $SendIP ] || [ "$SendIP" == "false" ]; then
                    #     echo -e "$Inf 目前是否发送IP地址: ${GRB}否${NC}"
                    # else
                    #     echo -e "$Inf 目前是否发送IP地址: ${GRB}是${NC}"
                    # fi
                    divline
                    read -e -p "请选择是否发送IP地址  Y.是  其它/回车.否: " choice
                fi
                if [ "$choice" == "y" ] || [ "$choice" == "Y" ]; then
                    if [ "$autorun" == "false" ]; then
                        echo "采用以下地址获取IP:"
                        echo -e "${GR}1${NC}. ip.sb"
                        echo -e "${GR}2${NC}. ip.gs"
                        echo -e "${GR}3${NC}. ifconfig.me"
                        echo -e "${GR}4${NC}. ipinfo.io/ip"
                        read -e -p "请输入以上序号或网址 (回车默认: ip.sb ): " inputurl
                    fi
                    if [ -z "$inputurl" ]; then
                        GetIPURL="ip.sb"
                    elif [ "$inputurl" == "1" ]; then
                        GetIPURL="ip.sb"
                    elif [ "$inputurl" == "2" ]; then
                        GetIPURL="ip.gs"
                    elif [ "$inputurl" == "3" ]; then
                        GetIPURL="ifconfig.me"
                    elif [ "$inputurl" == "4" ]; then
                        GetIPURL="ipinfo.io/ip"
                    else
                        GetIPURL=$inputurl
                    fi
                    if [ "$autorun" == "false" ]; then
                        read -e -p "请选择 IP 类型:  4: IPv4  6: IPv6 (回车默认: IPv4 ): " input46
                    fi
                    if [ -z "$input46" ]; then
                        GetIP46="4"
                    elif [ "$input46" == "4" ]; then
                        GetIP46="4"
                    elif [ "$input46" == "6" ]; then
                        GetIP46="6"
                    fi
                    writeini "SendIP" "true"
                    writeini "GetIPURL" "$GetIPURL"
                    writeini "GetIP46" "$GetIP46"
                    echo -e "$Tip 已开启发送IP地址, 从 ${GRB}$GetIPURL (IPv$GetIP46)${NC} 处获取."
                    TestIP=$(curl -s -"$GetIP46" "$GetIPURL")
                    if [ ! -z "$TestIP" ]; then
                        writeini "GetIPAddress" "$TestIP"
                    fi
                    echo -e "测试结果: ${GR}$TestIP${NC}"

                else
                    writeini "SendIP" "false"
                    writeini "GetIPAddress" ""
                    echo -e "$Tip 已关闭发送IP地址."
                fi
                ;;
            9)
                # 设置是否发送加密货币报价
                if [ "$autorun" == "true" ]; then
                    choice="Y"
                    inputb="3"
                else
                    # if [ -z $SendPrice ] || [ "$SendPrice" == "false" ]; then
                    #     echo -e "$Inf 目前是否发送加密货币报价: ${GRB}否${NC}"
                    # else
                    #     echo -e "$Inf 目前是否发送加密货币报价: ${GRB}是${NC} - ${GR}$GetPriceType${NC} "
                    # fi
                    divline
                    read -e -p "请选择是否发送加密货币报价  Y.是  其它/回车.否: " choice
                fi
                if [ "$choice" == "y" ] || [ "$choice" == "Y" ]; then
                    if [ "$autorun" == "false" ]; then
                        echo "获取加密货币类型:"
                        echo -e "${GR}1${NC}. bitcoin"
                        echo -e "${GR}2${NC}. ethereum"
                        echo -e "${GR}3${NC}. chia"
                        echo -e "自定义网址查询: https://api.coingecko.com/api/v3/coins/list"
                        read -e -p "请输入以上序号或自定义 (回车默认: chia ): " inputb
                    fi
                    if [ -z "$inputb" ]; then
                        GetPriceType="chia"
                    elif [ "$inputb" == "1" ]; then
                        GetPriceType="bitcoin"
                    elif [ "$inputb" == "2" ]; then
                        GetPriceType="ethereum"
                    elif [ "$inputb" == "3" ]; then
                        GetPriceType="chia"
                    else
                        GetPriceType=$inputb
                    fi
                    writeini "SendPrice" "true"
                    writeini "GetPriceType" "$GetPriceType"
                    echo -e "$Tip 已开启发送加密货币报价, 获取 ${GRB}$GetPriceType${NC} 报价."
                else
                    writeini "SendPrice" "false"
                    echo -e "$Tip 已关闭发送加密货币报价."
                fi
                ;;
            *)
                echo "退出设置."
                tips=""
                break
            ;;
        esac
    done
}

# 用于显示内容（调试用）
# SourceAndShowINI() {
#     if [ -f $ConfigFile ] && [ -s $ConfigFile ]; then
#         source $ConfigFile
#         divline
#         cat $ConfigFile
#         divline
#         echo -e "$Tip 以上为 TelgramBot.ini 文件内容, 可重新执行 ${GR}0${NC} 修改参数."
#     fi
# }

# 删除ini文件指定行
delini() {
    sed -i "/^$1=/d" $ConfigFile
}

# 检查文件是否存在并显示内容（调试用）
ShowContents() {
    if [ -f "$1" ]; then
        cat "$1"
        echo -e "$Inf 上述内容已经写入: $1"
        echo "-------------------------------------------"
    else
        echo -e "$Err 文件不存在: $1"
    fi
}

# 发送测试
test1() {
    if [ ! -z "$test1_pid" ] && pgrep -a '' | grep -Eq "^\s*$test1_pid\s" > /dev/null; then
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
    if [ ! -z "$test_pid" ] && pgrep -a '' | grep -Eq "^\s*$test_pid\s" > /dev/null; then
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

# 设置开机通知
SetupBoot_TG() {
    if [ ! -z "$boot_pid" ] && pgrep -a '' | grep -Eq "^\s*$boot_pid\s" > /dev/null; then
        tips="$Err PID(${GR}$boot_pid${NC}) 正在发送中,请稍后..."
        return 1
    fi
    if [[ -z "${TelgramBotToken}" || -z "${ChatID_1}" ]]; then
        tips="$Err 参数丢失, 请设置后再执行 (先执行 ${GR}0${NC} 选项)."
        return 1
    fi
    cat <<EOF > $FolderPath/tg_boot.sh
#!/bin/bash

$(declare -f Checkpara)

FolderPath="$FolderPath"
if [ ! -d "\$FolderPath" ]; then
    mkdir -p "\$FolderPath"
fi
ConfigFile="$ConfigFile"
source \$ConfigFile &>/dev/null
# if [ -z \$hostname_show ]; then
#     hostname_show=$hostname_show
# fi
Checkpara "hostname_show" "$hostname_show"

current_date_send=\$(date +"%Y.%m.%d %T")
message="\$hostname_show 已启动❗️"$'\n'
message+="服务器时间: \$current_date_send"

# curl -s -X POST "https://api.telegram.org/bot\$TelgramBotToken/sendMessage" \
#     -d chat_id="\$ChatID_1" -d text="\$message"
\$FolderPath/send_tg.sh "\$TelgramBotToken" "\$ChatID_1" "\$message"
EOF
    chmod +x $FolderPath/tg_boot.sh
    if command -v systemd &>/dev/null; then
        cat <<EOF > /etc/systemd/system/tg_boot.service
[Unit]
Description=Run tg_boot.sh script at boot time
After=network.target

[Service]
Type=oneshot
ExecStart=$FolderPath/tg_boot.sh
RemainAfterExit=true

[Install]
WantedBy=multi-user.target
EOF
        systemctl enable tg_boot.service > /dev/null
    elif cat /proc/version 2>/dev/null | grep -q -E -i "openwrt"; then
        cat <<EOF > /etc/init.d/tg_boot.sh
#!/bin/sh /etc/rc.common

$(declare -f Checkpara)

START=99
STOP=15

FolderPath="$FolderPath"
if [ ! -d "\$FolderPath" ]; then
    mkdir -p "\$FolderPath"
fi
ConfigFile="$ConfigFile"
source \$ConfigFile &>/dev/null
Checkpara "hostname_show" "$hostname_show"

start() {
    current_date_send=\$(date +"%Y.%m.%d %T")
    message="\$hostname_show 已启动❗️"$'\n'
    message+="服务器时间: \$current_date_send"

    # curl -s -X POST "https://api.telegram.org/bot\$TelgramBotToken/sendMessage" \
    #     -d chat_id="\$ChatID_1" -d text="\$message"
    \$FolderPath/send_tg.sh "\$TelgramBotToken" "\$ChatID_1" "\$message"
}
EOF
        chmod +x /etc/init.d/tg_boot.sh
        /etc/init.d/tg_boot.sh enable
    else
        tips="$Err 系统未检测到 \"systemd\" 程序, 无法设置开机通知."
        return 1
    fi
    if [ "$mute" == "false" ]; then
        send_time=$(echo $(date +%s%N) | cut -c 16-)
        $FolderPath/send_tg.sh "$TelgramBotToken" "$ChatID_1" "设置成功: 开机 通知⚙️"$'\n'"主机名: $hostname_show"$'\n'"当 开机 时将收到通知💡" "boot" "$send_time" &
        (sleep 15 && $FolderPath/del_lm_tg.sh "$TelgramBotToken" "$ChatID_1" "boot" "$send_time") &
        sleep 1
        # getpid "send_tg.sh"
        # boot_pid="$tg_pid"
        boot_pid=$(getpid "send_tg.sh")
    fi
    tips="$Tip 开机 通知已经设置成功, 当开机时发出通知."

}

# 设置登陆通知
SetupLogin_TG() {
    if [ ! -z "$login_pid" ] && pgrep -a '' | grep -Eq "^\s*$login_pid\s" > /dev/null; then
        tips="$Err PID(${GR}$login_pid${NC}) 正在发送中,请稍后..."
        return 1
    fi
    if [[ -z "${TelgramBotToken}" || -z "${ChatID_1}" ]]; then
        tips="$Err 参数丢失, 请设置后再执行 (先执行 ${GR}0${NC} 选项)."
        return 1
    fi
    cat <<EOF > $FolderPath/tg_login.sh
#!/bin/bash

$(declare -f Checkpara)

FolderPath="$FolderPath"
if [ ! -d "\$FolderPath" ]; then
    mkdir -p "\$FolderPath"
fi
ConfigFile="$ConfigFile"
source \$ConfigFile &>/dev/null
Checkpara "hostname_show" "$hostname_show"

current_date_send=\$(date +"%Y.%m.%d %T")
message="\$hostname_show \$(id -nu) 用户登陆成功❗️"$'\n'
message+="服务器时间: \$current_date_send"

# curl -s -X POST "https://api.telegram.org/bot\$TelgramBotToken/sendMessage" \
#             -d chat_id="\$ChatID_1" -d text="\$message"
\$FolderPath/send_tg.sh "\$TelgramBotToken" "\$ChatID_1" "\$message"
EOF
    chmod +x $FolderPath/tg_login.sh
    if [ -f /etc/bash.bashrc ] && [ "$release" != "openwrt" ]; then
        if ! grep -q "bash $FolderPath/tg_login.sh > /dev/null 2>&1 &" /etc/bash.bashrc; then
            echo "bash $FolderPath/tg_login.sh > /dev/null 2>&1 &" >> /etc/bash.bashrc
        fi
        if [ "$mute" == "false" ]; then
            send_time=$(echo $(date +%s%N) | cut -c 16-)
            $FolderPath/send_tg.sh "$TelgramBotToken" "$ChatID_1" "设置成功: 登陆 通知⚙️"$'\n'"主机名: $hostname_show"$'\n'"当 登陆 时将收到通知💡" "login" "$send_time" &
            (sleep 15 && $FolderPath/del_lm_tg.sh "$TelgramBotToken" "$ChatID_1" "login" "$send_time") &
            sleep 1
            # getpid "send_tg.sh"
            # login_pid="$tg_pid"
            login_pid=$(getpid "send_tg.sh")
        fi
        tips="$Tip 登陆 通知已经设置成功, 当登陆时发出通知."
    elif [ -f /etc/profile ]; then
        if ! grep -q "bash $FolderPath/tg_login.sh > /dev/null 2>&1 &" /etc/profile; then
            echo "bash $FolderPath/tg_login.sh > /dev/null 2>&1 &" >> /etc/profile
        fi
        if [ "$mute" == "false" ]; then
            send_time=$(echo $(date +%s%N) | cut -c 16-)
            $FolderPath/send_tg.sh "$TelgramBotToken" "$ChatID_1" "设置成功: 登陆 通知⚙️"$'\n'"主机名: $hostname_show"$'\n'"当 登陆 时将收到通知💡 " "login" "$send_time" &
            (sleep 15 && $FolderPath/del_lm_tg.sh "$TelgramBotToken" "$ChatID_1" "login" "$send_time") &
            sleep 1
            # getpid "send_tg.sh"
            # login_pid="$tg_pid"
            login_pid=$(getpid "send_tg.sh")
        fi
        tips="$Tip 登陆 通知已经设置成功, 当登陆时发出通知."
    else
        tips="$Err 未检测到对应文件, 无法设置登陆通知."
    fi
}

# 设置关机通知
SetupShutdown_TG() {
    if [ ! -z "$shutdown_pid" ] && pgrep -a '' | grep -Eq "^\s*$shutdown_pid\s" > /dev/null; then
        tips="$Err PID(${GR}$shutdown_pid${NC}) 正在发送中,请稍后..."
        return 1
    fi
    if [[ -z "${TelgramBotToken}" || -z "${ChatID_1}" ]]; then
        tips="$Err 参数丢失, 请设置后再执行 (先执行 ${GR}0${NC} 选项)."
        return 1
    fi
    cat <<EOF > $FolderPath/tg_shutdown.sh
#!/bin/bash

$(declare -f Checkpara)

FolderPath="$FolderPath"
if [ ! -d "\$FolderPath" ]; then
    mkdir -p "\$FolderPath"
fi
ConfigFile="$ConfigFile"
source \$ConfigFile &>/dev/null
Checkpara "hostname_show" "$hostname_show"

current_date_send=\$(date +"%Y.%m.%d %T")
message="\$hostname_show \$(id -nu) 正在执行关机...❗️"$'\n'
message+="服务器时间: \$current_date_send"

# curl -s -X POST "https://api.telegram.org/bot\$TelgramBotToken/sendMessage" \
#             -d chat_id="\$ChatID_1" -d text="\$message"
\$FolderPath/send_tg.sh "\$TelgramBotToken" "\$ChatID_1" "\$message"
EOF
    chmod +x $FolderPath/tg_shutdown.sh
    if command -v systemd &>/dev/null; then
        cat <<EOF > /etc/systemd/system/tg_shutdown.service
[Unit]
Description=tg_shutdown
DefaultDependencies=no
Before=shutdown.target

[Service]
Type=oneshot
ExecStart=$FolderPath/tg_shutdown.sh
TimeoutStartSec=0

[Install]
WantedBy=shutdown.target
EOF
        systemctl enable tg_shutdown.service > /dev/null
    elif cat /proc/version 2>/dev/null | grep -q -E -i "openwrt"; then
        cat <<EOF > /etc/init.d/tg_shutdown.sh
#!/bin/sh /etc/rc.common

$(declare -f Checkpara)

STOP=15

FolderPath="$FolderPath"
if [ ! -d "\$FolderPath" ]; then
    mkdir -p "\$FolderPath"
fi
ConfigFile="$ConfigFile"
source \$ConfigFile &>/dev/null
Checkpara "hostname_show" "$hostname_show"

stop() {
    current_date_send=\$(date +"%Y.%m.%d %T")
    message="\$hostname_show \$(id -nu) 正在执行关机...❗️"$'\n'
    message+="服务器时间: \$current_date_send"

    # curl -s -X POST "https://api.telegram.org/bot\$TelgramBotToken/sendMessage" \
    #     -d chat_id="\$ChatID_1" -d text="\$message"
    \$FolderPath/send_tg.sh "\$TelgramBotToken" "\$ChatID_1" "\$message"
}
EOF
        chmod +x /etc/init.d/tg_shutdown.sh
        /etc/init.d/tg_shutdown.sh enable
    else
        tips="$Err 系统未检测到 \"systemd\" 程序, 无法设置关机通知."
        return 1
    fi
    if [ "$mute" == "false" ]; then
        send_time=$(echo $(date +%s%N) | cut -c 16-)
        $FolderPath/send_tg.sh "$TelgramBotToken" "$ChatID_1" "设置成功: 关机 通知⚙️"$'\n'"主机名: $hostname_show"$'\n'"当 关机 时将收到通知💡" "shutdown" "$send_time" &
        (sleep 15 && $FolderPath/del_lm_tg.sh "$TelgramBotToken" "$ChatID_1" "shutdown" "$send_time") &
        sleep 1
        # getpid "send_tg.sh"
        # shutdown_pid="$tg_pid"
        shutdown_pid=$(getpid "send_tg.sh")
    fi
    tips="$Tip 关机 通知已经设置成功, 当开机时发出通知."
}

# 设置Dokcer通知
SetupDocker_TG() {
    if [ ! -z "$docker_pid" ] && pgrep -a '' | grep -Eq "^\s*$docker_pid\s" > /dev/null; then
        tips="$Err PID(${GR}$docker_pid${NC}) 正在发送中,请稍后..."
        return 1
    fi
    if ! command -v docker &>/dev/null; then
        tips="$Err 未检测到 \"Docker\" 程序."
        return 1
    fi
    if [[ -z "${TelgramBotToken}" || -z "${ChatID_1}" ]]; then
        tips="$Err 参数丢失, 请设置后再执行 (先执行 ${GR}0${NC} 选项)."
        return 1
    fi
    cat <<EOF > $FolderPath/tg_docker.sh
#!/bin/bash

$(declare -f Checkpara)

FolderPath="$FolderPath"
if [ ! -d "\$FolderPath" ]; then
    mkdir -p "\$FolderPath"
fi
ConfigFile="$ConfigFile"
source \$ConfigFile &>/dev/null
Checkpara "hostname_show" "$hostname_show"

old_message=""
while true; do
    # new_message=\$(docker ps --format '{{.Names}}' | tr '\n' "\n" | sed 's/|$//')
    new_message=\$(docker ps --format '{{.Names}}' | awk '{print NR". " \$0}')
    if [ "\$new_message" != "\$old_message" ]; then
        current_date_send=\$(date +"%Y.%m.%d %T")
        old_message=\$new_message
        message="DOCKER 列表变更❗️"$'\n'
        message+="主机名: \$hostname_show"$'\n'
        message+="───────────────"$'\n'
        message+="\$new_message"$'\n'
        message+="服务器时间: \$current_date_send"
        # curl -s -X POST "https://api.telegram.org/bot\$TelgramBotToken/sendMessage" \
        #     -d chat_id="\$ChatID_1" -d text="\$message"
        \$FolderPath/send_tg.sh "\$TelgramBotToken" "\$ChatID_1" "\$message"
    fi
    sleep 10
done
EOF
    chmod +x $FolderPath/tg_docker.sh
    killpid "tg_docker.sh"
    nohup $FolderPath/tg_docker.sh > $FolderPath/tg_docker.log 2>&1 &
    delcrontab "$FolderPath/tg_docker.sh"
    addcrontab "@reboot nohup $FolderPath/tg_docker.sh > $FolderPath/tg_docker.log 2>&1 &"
    if [ "$mute" == "false" ]; then
        send_time=$(echo $(date +%s%N) | cut -c 16-)
        $FolderPath/send_tg.sh "$TelgramBotToken" "$ChatID_1" "设置成功: Docker 变更通知⚙️"$'\n'"主机名: $hostname_show"$'\n'"当 Docker 列表变更时将收到通知💡" "docker" "$send_time" &
        (sleep 15 && $FolderPath/del_lm_tg.sh "$TelgramBotToken" "$ChatID_1" "docker" "$send_time") &
        sleep 1
        # getpid "send_tg.sh"
        # docker_pid="$tg_pid"
        docker_pid=$(getpid "send_tg.sh")
    fi
    tips="$Tip Docker 通知已经设置成功, 当 Dokcer 挂载发生变化时发出通知."
}

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
    # top_output=$(top -bn1)
    top_output=$(top -bn 1 | head -n 10)
    echo "top: $top_output"
    if echo "$top_output" | grep -q "^%Cpu"; then
        # top -V
        top_output_h=$(echo "$top_output" | awk 'NR > 7')
        cpu_h1=$(echo "$top_output_h" | awk 'NR == 1 || $9 > max { max = $9; process = $NF } END { print process }')
        cpu_h2=$(echo "$top_output_h" | awk 'NR == 2 || $9 > max { max = $9; process = $NF } END { print process }')
        # mem_total=$(echo "$top_output" | awk '/^MiB Mem/ { gsub(/Mem|total,|free,|used,|buff\/cache|:/, " ", $0); print int($2) }')
        # if [ -z "$mem_total" ]; then
        #     mem_total=$(echo "$top_output" | awk '/^KiB Mem/ { gsub(/Mem|total,|free,|used,|buff\/cache|:/, " ", $0); print int($2/1024) }')
        # fi
        # mem_used=$(echo "$top_output" | awk '/^MiB Mem/ { gsub(/Mem|total,|free,|used,|buff\/cache|:/, " ", $0); print int($4) }')
        # if [ -z "$mem_used" ]; then
        #     mem_used=$(echo "$top_output" | awk '/^KiB Mem/ { gsub(/Mem|total,|free,|used,|buff\/cache|:/, " ", $0); print int($4/1024) }')
        # fi
        # mem_use_ratio=$(awk -v used="$mem_used" -v total="$mem_total" 'BEGIN { printf "%.0f", ( used / total ) * 100 }')
        # swap_total=$(echo "$top_output" | awk '/^MiB Swap/ { gsub(/Swap|total,|free,|used,|buff\/cache|:/, " ", $0); print int($2) }')
        # swap_used=$(echo "$top_output" | awk '/^MiB Swap/ { gsub(/Swap|total,|free,|used,|buff\/cache|:/, " ", $0); print int($4) }')
        # swap_use_ratio=$(awk -v used="$swap_used" -v total="$swap_total" 'BEGIN { printf "%.0f", ( used / total ) * 100 }')
    elif echo "$top_output" | grep -q "^CPU"; then
        # top -V
        top_output_h=$(echo "$top_output" | awk 'NR > 4')
        # cpu_h1=$(echo "$top_output_h" | awk 'NR == 1 || $7 > max { max = $7; process = $NF } END { print process }' | awk '{print $1}')
        # cpu_h2=$(echo "$top_output_h" | awk 'NR == 2 || $7 > max { max = $7; process = $NF } END { print process }' | awk '{print $1}')
        cpu_h1=$(echo "$top_output_h" | awk 'NR == 1 || $7 > max { max = $7; process = $8 } END { print process }' | awk '{print $1}')
        cpu_h2=$(echo "$top_output_h" | awk 'NR == 2 || $7 > max { max = $7; process = $8 } END { print process }' | awk '{print $1}')
        # mem_used=$(echo "$top_output" | awk '/^Mem/ { gsub(/K|used,|free,|shrd,|buff,|cached|:/, " ", $0); printf "%.0f", $2 / 1024 }')
        # mem_free=$(echo "$top_output" | awk '/^Mem/ { gsub(/K|used,|free,|shrd,|buff,|cached|:/, " ", $0); printf "%.0f", $3 / 1024 }')
        # # mem_total=$(awk "BEGIN { print $mem_used + $mem_free }") # 支持浮点计算,上面已经采用printf "%.0f"取整,所以使用下行即可
        # mem_total=$((mem_used + mem_free))
        # swap_total=""
        # swap_used=""
        # swap_use_ratio=""
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

# 百分比转换进度条
create_progress_bar() {
    local percentage=$1
    local start_symbol=""
    local used_symbol="▇"
    local free_symbol="▁"
    local progress_bar=""
    local used_count
    local bar_width=10  # 默认进度条宽度为10
    if [[ $percentage -ge 1 && $percentage -le 100 ]]; then
        used_count=$((percentage * bar_width / 100))
        for ((i=0; i<used_count; i++)); do
            progress_bar="${progress_bar}${used_symbol}"
        done
        for ((i=used_count; i<bar_width; i++)); do
            progress_bar="${progress_bar}${free_symbol}"
        done
        echo "${start_symbol}${progress_bar}"
    else
        echo "错误: 参数无效, 必须为 1-100 之间的值."
        return 1
    fi
}

ratioandprogress() {
    # 调用时需要定义全局变量: progress 和 ratio
    lto=false
    gtoh=false
    if [ ! -z "$3" ]; then
        ratio=$3
    elif $(awk -v used="$1" -v total="$2" 'BEGIN { printf "%d", ( used >= 0 && total >= 0 ) }'); then
        ratio=$(awk -v used="$1" -v total="$2" 'BEGIN { printf "%.3f", ( used / total ) * 100 }')
    else
        echo "错误: $1 或 $2 小于 0 ."
        progress="Err 参数有误."
        return 1
    fi
    if $(awk -v v1="$ratio" 'BEGIN { exit !(v1 > 0 && v1 < 1) }'); then
    # if $(awk -v v1="$ratio" 'BEGIN { exit !(v1 < 1) }'); then
        ratio=1
        lto=true
    elif $(awk -v v1="$ratio" 'BEGIN { exit !(v1 > 100) }'); then
        ratio=100
        gtoh=true
    fi
    ratio=$(awk -v v1="$ratio" 'BEGIN { printf "%.0f", v1 }')
    # ratio=$(awk -v v1="$ratio" 'BEGIN { if (v1 > 0 && v1 < 1) { printf "1" } else { printf "%.0f", v1 } }')
    progress=$(create_progress_bar "$ratio")
    return_code=$?
    if [ $return_code -eq 1 ]; then
        progress="🚫"
        ratio=""
    else
        if [ "$lto" == "true" ]; then
            ratio="🔽"
        elif [ "$gtoh" == "true" ]; then
            ratio="🔼"
        else
            ratio="${ratio}%"
        fi
    fi
    # echo "$progress"
    # echo "$ratio"
}

# 设置CPU报警
SetupCPU_TG() {
    if [ ! -z "$cpu_pid" ] && pgrep -a '' | grep -Eq "^\s*$cpu_pid\s" > /dev/null; then
        tips="$Err PID(${GR}$cpu_pid${NC}) 正在发送中,请稍后..."
        return 1
    fi
    if [[ -z "${TelgramBotToken}" || -z "${ChatID_1}" ]]; then
        tips="$Err 参数丢失, 请设置后再执行 (先执行 ${GR}0${NC} 选项)."
        return 1
    fi
    if [ "$autorun" == "false" ]; then
        read -e -p "请输入 CPU 报警阈值 % (回车跳过修改): " threshold
    else
        if [ ! -z "$CPUThreshold" ]; then
            threshold=$CPUThreshold
        else
            threshold=$CPUThreshold_de
        fi
    fi
    if [ -z "$threshold" ]; then
        tips="$Tip 输入为空, 跳过操作."
        return 1
    fi
    threshold="${threshold//%/}"
    if [[ ! $threshold =~ ^([1-9][0-9]?|100)$ ]]; then
        echo -e "$Err ${REB}输入无效${NC}, 报警阈值 必须是数字 (1-100) 的整数, 跳过操作."
        return 1
    fi
    writeini "CPUThreshold" "$threshold"
    CPUThreshold=$threshold
    if [ "$CPUTools" == "sar" ] || [ "$CPUTools" == "top_sar" ]; then
        if ! command -v sar &>/dev/null; then
            echo "正在安装缺失的依赖 sar, 一个检测 CPU 的专业工具."
            if [ -x "$(command -v apt)" ]; then
                apt -y install sysstat
            elif [ -x "$(command -v yum)" ]; then
                yum -y install sysstat
            else
                echo -e "$Err 未知的包管理器, 无法安装依赖. 请手动安装所需依赖后再运行脚本."
            fi
        fi
    fi
    cat <<EOF > "$FolderPath/tg_cpu.sh"
#!/bin/bash

CPUTools="$CPUTools"
CPUThreshold="$CPUThreshold"

export TERM=xterm

$(declare -f CheckCPU_$CPUTools)
$(declare -f GetInfo_now)
$(declare -f create_progress_bar)
$(declare -f ratioandprogress)
$(declare -f Checkpara)

FolderPath="$FolderPath"
if [ ! -d "\$FolderPath" ]; then
    mkdir -p "\$FolderPath"
fi
ConfigFile="$ConfigFile"
source \$ConfigFile &>/dev/null
Checkpara "hostname_show" "$hostname_show"

progress=""
ratio=""
count=0
SleepTime=900
while true; do
    CheckCPU_\$CPUTools

    CPUThreshold_com=\$(awk 'BEGIN {printf "%.0f\n", '\$CPUThreshold' * 100}')
    cpu_usage_ratio_com=\$(awk 'BEGIN {printf "%.0f\n", '\$cpu_usage_ratio' * 100}')
    echo "Threshold: \$CPUThreshold_com   usage: \$cpu_usage_ratio_com  # 这里数值是乘100的结果"
    if (( cpu_usage_ratio_com >= \$CPUThreshold_com )); then
        (( count++ ))
    else
        count=0
    fi
    echo "count: \$count   # 当 count 为 3 时将触发警报."
    if (( count >= 3 )); then

        # 获取并计算其它参数
        GetInfo_now

        # output=\$(ratioandprogress "0" "0" "cpu_usage_ratio")
        # cpu_usage_progress=\$(echo "\$output" | awk 'NR==1 {print \$1}')
        # cpu_usage_ratio=\$(echo "\$output" | awk 'NR==2 {print \$1}')

        ratioandprogress "0" "0" "\$cpu_usage_ratio"
        cpu_usage_progress=\$progress
        cpu_usage_ratio=\$ratio

        ratioandprogress "0" "0" "\$mem_use_ratio"
        mem_use_progress=\$progress
        mem_use_ratio=\$ratio

        ratioandprogress "0" "0" "\$swap_use_ratio"
        swap_use_progress=\$progress
        swap_use_ratio=\$ratio

        ratioandprogress "0" "0" "\$disk_use_ratio"
        disk_use_progress=\$progress
        disk_use_ratio=\$ratio

        current_date_send=\$(date +"%Y.%m.%d %T")
        message="CPU 使用率超过阈值 > \$CPUThreshold%❗️"$'\n'
        message+="主机名: \$hostname_show"$'\n'
        message+="CPU: \$cpu_usage_progress \$cpu_usage_ratio"$'\n'
        message+="内存: \$mem_use_progress \$mem_use_ratio"$'\n'
        message+="交换: \$swap_use_progress \$swap_use_ratio"$'\n'
        message+="磁盘: \$disk_use_progress \$disk_use_ratio"$'\n'
        message+="使用率排行:"$'\n'
        message+="🟠  \$cpu_h1"$'\n'
        message+="🟠  \$cpu_h2"$'\n'
        message+="检测工具: \$CPUTools 休眠: \$((SleepTime / 60))分钟"$'\n'
        message+="服务器时间: \$current_date_send"
        # curl -s -X POST "https://api.telegram.org/bot\$TelgramBotToken/sendMessage" \
        #     -d chat_id="\$ChatID_1" -d text="\$message" > /dev/null
        \$FolderPath/send_tg.sh "\$TelgramBotToken" "\$ChatID_1" "\$message"
        echo "报警信息已发出..."
        count=0  # 发送警告后重置计数器
        sleep \$SleepTime   # 发送后等待SleepTime分钟后再检测
    fi
    sleep 5
done
EOF
    chmod +x $FolderPath/tg_cpu.sh
    killpid "tg_cpu.sh"
    nohup $FolderPath/tg_cpu.sh > $FolderPath/tg_cpu.log 2>&1 &
    delcrontab "$FolderPath/tg_cpu.sh"
    addcrontab "@reboot nohup $FolderPath/tg_cpu.sh > $FolderPath/tg_cpu.log 2>&1 &"
    if [ "$mute" == "false" ]; then
        send_time=$(echo $(date +%s%N) | cut -c 16-)
        $FolderPath/send_tg.sh "$TelgramBotToken" "$ChatID_1" "设置成功: CPU 报警通知⚙️"'
'"主机名: $hostname_show"'
'"CPU: $cpuusedOfcpus"'
'"检测工具: $CPUTools"'
'"当 CPU 使用达 $CPUThreshold % 时将收到通知💡" "cpu" "$send_time" &
#         $FolderPath/send_tg.sh "$TelgramBotToken" "$ChatID_1" "设置成功: CPU 报警通知⚙️"'
# '"主机名: $hostname_show"'
# '"CPU: $cpuusedOfcpus"'
# '"内存: ${mem_total}MB"'
# '"交换: ${swap_total}MB"'
# '"磁盘: ${disk_total}B     已使用: ${disk_used}B"'
# '"检测工具: $CPUTools"'
# '"当 CPU 使用达 $CPUThreshold % 时将收到通知💡" &
        (sleep 15 && $FolderPath/del_lm_tg.sh "$TelgramBotToken" "$ChatID_1" "cpu" "$send_time") &
        sleep 1
        # getpid "send_tg.sh"
        # cpu_pid="$tg_pid"
        cpu_pid=$(getpid "send_tg.sh")
    fi
    tips="$Tip CPU 通知已经设置成功, 当 CPU 使用率达 ${GR}$CPUThreshold${NC} % 时发出通知."
}

# 设置内存报警
SetupMEM_TG() {
    if [ ! -z "$mem_pid" ] && pgrep -a '' | grep -Eq "^\s*$mem_pid\s" > /dev/null; then
        tips="$Err PID(${GR}$mem_pid${NC}) 正在发送中,请稍后..."
        return 1
    fi
    if [[ -z "${TelgramBotToken}" || -z "${ChatID_1}" ]]; then
        tips="$Err 参数丢失, 请设置后再执行 (先执行 ${GR}0${NC} 选项)."
        return 1
    fi
    if [ "$autorun" == "false" ]; then
        read -e -p "请输入 内存阈值 % (回车跳过修改): " threshold
    else
        if [ ! -z "$MEMThreshold" ]; then
            threshold=$MEMThreshold
        else
            threshold=$MEMThreshold_de
        fi
    fi
    if [ -z "$threshold" ]; then
        tips="$Tip 输入为空, 跳过操作."
        return 1
    fi
    threshold="${threshold//%/}"
    if [[ ! $threshold =~ ^([1-9][0-9]?|100)$ ]]; then
        echo -e "$Err ${REB}输入无效${NC}, 报警阈值 必须是数字 (1-100) 的整数, 跳过操作."
        return 1
    fi
    writeini "MEMThreshold" "$threshold"
    MEMThreshold=$threshold
    if [ "$CPUTools" == "sar" ] || [ "$CPUTools" == "top_sar" ]; then
        if ! command -v sar &>/dev/null; then
            echo "正在安装缺失的依赖 sar, 一个检测 CPU 的专业工具."
            if [ -x "$(command -v apt)" ]; then
                apt -y install sysstat
            elif [ -x "$(command -v yum)" ]; then
                yum -y install sysstat
            else
                echo -e "$Err 未知的包管理器, 无法安装依赖. 请手动安装所需依赖后再运行脚本."
            fi
        fi
    fi
    cat <<EOF > "$FolderPath/tg_mem.sh"
#!/bin/bash

CPUTools="$CPUTools"
MEMThreshold="$MEMThreshold"

$(declare -f CheckCPU_$CPUTools)
$(declare -f GetInfo_now)
$(declare -f create_progress_bar)
$(declare -f ratioandprogress)
$(declare -f Checkpara)

FolderPath="$FolderPath"
if [ ! -d "\$FolderPath" ]; then
    mkdir -p "\$FolderPath"
fi
ConfigFile="$ConfigFile"
source \$ConfigFile &>/dev/null
Checkpara "hostname_show" "$hostname_show"

progress=""
ratio=""
count=0
SleepTime=900
while true; do
    GetInfo_now

    MEMThreshold_com=\$(awk 'BEGIN {printf "%.0f\n", '\$MEMThreshold' * 100}')
    mem_use_ratio_com=\$(awk 'BEGIN {printf "%.0f\n", '\$mem_use_ratio' * 100}')
    echo "Threshold: \$MEMThreshold_com   usage: \$mem_use_ratio_com  # 这里数值是乘100的结果"
    if (( mem_use_ratio_com >= \$MEMThreshold_com )); then
        (( count++ ))
    else
        count=0
    fi
    echo "count: \$count   # 当 count 为 3 时将触发警报."
    if (( count >= 3 )); then

        # 获取并计算其它参数
        CheckCPU_\$CPUTools

        ratioandprogress "0" "0" "\$cpu_usage_ratio"
        cpu_usage_progress=\$progress
        cpu_usage_ratio=\$ratio

        ratioandprogress "0" "0" "\$mem_use_ratio"
        mem_use_progress=\$progress
        mem_use_ratio=\$ratio

        ratioandprogress "0" "0" "\$swap_use_ratio"
        swap_use_progress=\$progress
        swap_use_ratio=\$ratio

        ratioandprogress "0" "0" "\$disk_use_ratio"
        disk_use_progress=\$progress
        disk_use_ratio=\$ratio

        current_date_send=\$(date +"%Y.%m.%d %T")
        message="内存 使用率超过阈值 > \$MEMThreshold%❗️"$'\n'
        message+="主机名: \$hostname_show"$'\n'
        message+="CPU: \$cpu_usage_progress \$cpu_usage_ratio"$'\n'
        message+="内存: \$mem_use_progress \$mem_use_ratio"$'\n'
        message+="交换: \$swap_use_progress \$swap_use_ratio"$'\n'
        message+="磁盘: \$disk_use_progress \$disk_use_ratio"$'\n'
        message+="使用率排行:"$'\n'
        message+="🟠  \$cpu_h1"$'\n'
        message+="🟠  \$cpu_h2"$'\n'
        message+="检测工具: \$CPUTools 休眠: \$((SleepTime / 60))分钟"$'\n'
        message+="服务器时间: \$current_date_send"
        # curl -s -X POST "https://api.telegram.org/bot\$TelgramBotToken/sendMessage" \
        #     -d chat_id="\$ChatID_1" -d text="\$message" > /dev/null
        \$FolderPath/send_tg.sh "\$TelgramBotToken" "\$ChatID_1" "\$message"
        echo "报警信息已发出..."
        count=0  # 发送警告后重置计数器
        sleep \$SleepTime   # 发送后等待SleepTime分钟后再检测
    fi
    sleep 5
done
EOF
    chmod +x $FolderPath/tg_mem.sh
    killpid "tg_mem.sh"
    nohup $FolderPath/tg_mem.sh > $FolderPath/tg_mem.log 2>&1 &
    delcrontab "$FolderPath/tg_mem.sh"
    addcrontab "@reboot nohup $FolderPath/tg_mem.sh > $FolderPath/tg_mem.log 2>&1 &"
    if [ "$mute" == "false" ]; then
        send_time=$(echo $(date +%s%N) | cut -c 16-)
        $FolderPath/send_tg.sh "$TelgramBotToken" "$ChatID_1" "设置成功: 内存 报警通知⚙️"'
'"主机名: $hostname_show"'
'"内存: ${mem_total}MB"'
'"交换: ${swap_total}MB"'
'"当内存使用达 $MEMThreshold % 时将收到通知💡" "mem" "$send_time" &
        (sleep 15 && $FolderPath/del_lm_tg.sh "$TelgramBotToken" "$ChatID_1" "mem" "$send_time") &
        sleep 1
        # getpid "send_tg.sh"
        # mem_pid="$tg_pid"
        mem_pid=$(getpid "send_tg.sh")
    fi
    tips="$Tip 内存 通知已经设置成功, 当 内存 使用率达 ${GR}$MEMThreshold${NC} % 时发出通知."

}

# 设置磁盘报警
SetupDISK_TG() {
    if [ ! -z "$disk_pid" ] && pgrep -a '' | grep -Eq "^\s*$disk_pid\s" > /dev/null; then
        tips="$Err PID(${GR}$disk_pid${NC}) 正在发送中,请稍后..."
        return 1
    fi
    if [[ -z "${TelgramBotToken}" || -z "${ChatID_1}" ]]; then
        tips="$Err 参数丢失, 请设置后再执行 (先执行 ${GR}0${NC} 选项)."
        return 1
    fi
    if [ "$autorun" == "false" ]; then
        read -e -p "请输入 磁盘报警阈值 % (回车跳过修改): " threshold
    else
        if [ ! -z "$DISKThreshold" ]; then
            threshold=$DISKThreshold
        else
            threshold=$DISKThreshold_de
        fi
    fi
    if [ -z "$threshold" ]; then
        tips="$Tip 输入为空, 跳过操作."
        return 1
    fi
    threshold="${threshold//%/}"
    if [[ ! $threshold =~ ^([1-9][0-9]?|100)$ ]]; then
        echo -e "$Err ${REB}输入无效${NC}, 报警阈值 必须是数字 (1-100) 的整数, 跳过操作."
        return 1
    fi
    writeini "DISKThreshold" "$threshold"
    DISKThreshold=$threshold
    if [ "$CPUTools" == "sar" ] || [ "$CPUTools" == "top_sar" ]; then
        if ! command -v sar &>/dev/null; then
            echo "正在安装缺失的依赖 sar, 一个检测 CPU 的专业工具."
            if [ -x "$(command -v apt)" ]; then
                apt -y install sysstat
            elif [ -x "$(command -v yum)" ]; then
                yum -y install sysstat
            else
                echo -e "$Err 未知的包管理器, 无法安装依赖. 请手动安装所需依赖后再运行脚本."
            fi
        fi
    fi
    cat <<EOF > "$FolderPath/tg_disk.sh"
#!/bin/bash

CPUTools="$CPUTools"
DISKThreshold="$DISKThreshold"

$(declare -f CheckCPU_$CPUTools)
$(declare -f GetInfo_now)
$(declare -f create_progress_bar)
$(declare -f ratioandprogress)
$(declare -f Checkpara)

FolderPath="$FolderPath"
if [ ! -d "\$FolderPath" ]; then
    mkdir -p "\$FolderPath"
fi
ConfigFile="$ConfigFile"
source \$ConfigFile &>/dev/null
Checkpara "hostname_show" "$hostname_show"

progress=""
ratio=""
count=0
SleepTime=900
while true; do
    GetInfo_now

    DISKThreshold_com=\$(awk 'BEGIN {printf "%.0f\n", '\$DISKThreshold' * 100}')
    disk_use_ratio_com=\$(awk 'BEGIN {printf "%.0f\n", '\$disk_use_ratio' * 100}')
    echo "Threshold: \$DISKThreshold_com   usage: \$disk_use_ratio_com  # 这里数值是乘100的结果"
    if (( disk_use_ratio_com >= \$DISKThreshold_com )); then
        (( count++ ))
    else
        count=0
    fi
    echo "count: \$count   # 当 count 为 3 时将触发警报."
    if (( count >= 3 )); then

        # 获取并计算其它参数
        CheckCPU_\$CPUTools

        echo "前: cpu: \$cpu_usage_ratio mem: \$mem_use_ratio swap: \$swap_use_ratio disk: \$disk_use_ratio"
        ratioandprogress "0" "0" "\$cpu_usage_ratio"
        cpu_usage_progress=\$progress
        cpu_usage_ratio=\$ratio

        ratioandprogress "0" "0" "\$mem_use_ratio"
        mem_use_progress=\$progress
        mem_use_ratio=\$ratio

        ratioandprogress "0" "0" "\$swap_use_ratio"
        swap_use_progress=\$progress
        swap_use_ratio=\$ratio

        ratioandprogress "0" "0" "\$disk_use_ratio"
        disk_use_progress=\$progress
        disk_use_ratio=\$ratio
        echo "后: cpu: \$cpu_usage_ratio mem: \$mem_use_ratio swap: \$swap_use_ratio disk: \$disk_use_ratio"

        current_date_send=\$(date +"%Y.%m.%d %T")
        message="磁盘 使用率超过阈值 > \$DISKThreshold%❗️"$'\n'
        message+="主机名: \$hostname_show"$'\n'
        message+="CPU: \$cpu_usage_progress \$cpu_usage_ratio"$'\n'
        message+="内存: \$mem_use_progress \$mem_use_ratio"$'\n'
        message+="交换: \$swap_use_progress \$swap_use_ratio"$'\n'
        message+="磁盘: \$disk_use_progress \$disk_use_ratio"$'\n'
        message+="使用率排行:"$'\n'
        message+="🟠  \$cpu_h1"$'\n'
        message+="🟠  \$cpu_h2"$'\n'
        message+="检测工具: \$CPUTools 休眠: \$((SleepTime / 60))分钟"$'\n'
        message+="服务器时间: \$current_date_send"
        # curl -s -X POST "https://api.telegram.org/bot\$TelgramBotToken/sendMessage" \
        #     -d chat_id="\$ChatID_1" -d text="\$message" > /dev/null
        \$FolderPath/send_tg.sh "\$TelgramBotToken" "\$ChatID_1" "\$message"
        echo "报警信息已发出..."
        count=0  # 发送警告后重置计数器
        sleep \$SleepTime   # 发送后等待SleepTime分钟后再检测
    fi
    sleep 3
done
EOF
    chmod +x $FolderPath/tg_disk.sh
    killpid "tg_disk.sh"
    nohup $FolderPath/tg_disk.sh > $FolderPath/tg_disk.log 2>&1 &
    delcrontab "$FolderPath/tg_disk.sh"
    addcrontab "@reboot nohup $FolderPath/tg_disk.sh > $FolderPath/tg_disk.log 2>&1 &"
    if [ "$mute" == "false" ]; then
        send_time=$(echo $(date +%s%N) | cut -c 16-)
        $FolderPath/send_tg.sh "$TelgramBotToken" "$ChatID_1" "设置成功: 磁盘 报警通知⚙️"'
'"主机名: $hostname_show"'
'"磁盘: ${disk_total}B     已使用: ${disk_used}B"'
'"当磁盘使用达 $DISKThreshold % 时将收到通知💡" "disk" "$send_time" &
        (sleep 15 && $FolderPath/del_lm_tg.sh "$TelgramBotToken" "$ChatID_1" "disk" "$send_time") &
        sleep 1
        # getpid "send_tg.sh"
        # disk_pid="$tg_pid"
        disk_pid=$(getpid "send_tg.sh")
    fi
    tips="$Tip 磁盘 通知已经设置成功, 当 磁盘 使用率达 ${GR}$DISKThreshold${NC} % 时发出通知."
}

# 删除变量后面的B
Remove_B() {
    local var="$1"
    echo "${var%B}"
}

Bytes_M_TGK() {
    bitvalue="$1"
    if awk -v bitvalue="$bitvalue" 'BEGIN { exit !(bitvalue >= (1024 * 1024)) }'; then
        bitvalue=$(awk -v value="$bitvalue" 'BEGIN { printf "%.1fTB", value / (1024 * 1024) }')
    elif awk -v bitvalue="$bitvalue" 'BEGIN { exit !(bitvalue >= 1024) }'; then
        bitvalue=$(awk -v value="$bitvalue" 'BEGIN { printf "%.1fGB", value / 1024 }')
    elif awk -v bitvalue="$bitvalue" 'BEGIN { exit !(bitvalue < 1) }'; then
        bitvalue=$(awk -v value="$bitvalue" 'BEGIN { printf "%.1fKB", value * 1024 }')
    else
        # bitvalue="${bitvalue}MB"
        bitvalue=$(awk -v value="$bitvalue" 'BEGIN { printf "%.1fMB", value }')
    fi
    echo "$bitvalue"
}

Bytes_K_TGM() {
    bitvalue="$1"
    if awk -v bitvalue="$bitvalue" 'BEGIN { exit !(bitvalue >= (1024 * 1024 * 1024)) }'; then
        bitvalue=$(awk -v value="$bitvalue" 'BEGIN { printf "%.1fTB", value / (1024 * 1024 * 1024) }')
    elif awk -v bitvalue="$bitvalue" 'BEGIN { exit !(bitvalue >= (1024 * 1024)) }'; then
        bitvalue=$(awk -v value="$bitvalue" 'BEGIN { printf "%.1fGB", value / (1024 * 1024) }')
    elif awk -v bitvalue="$bitvalue" 'BEGIN { exit !(bitvalue >= 1024) }'; then
        bitvalue=$(awk -v value="$bitvalue" 'BEGIN { printf "%.1fMB", value / 1024 }')
    else
        # bitvalue="${bitvalue}KB"
        bitvalue=$(awk -v value="$bitvalue" 'BEGIN { printf "%.1fKB", value }')
    fi
    echo "$bitvalue"
}

Bytes_K_TGMi() {
    bitvalue="$1"
    if awk -v bitvalue="$bitvalue" 'BEGIN { exit !(bitvalue >= (1024 * 1024 * 1024)) }'; then
        bitvalue=$(awk -v value="$bitvalue" 'BEGIN { printf "%.1fTiB", value / (1024 * 1024 * 1024) }')
    elif awk -v bitvalue="$bitvalue" 'BEGIN { exit !(bitvalue >= (1024 * 1024)) }'; then
        bitvalue=$(awk -v value="$bitvalue" 'BEGIN { printf "%.1fGiB", value / (1024 * 1024) }')
    elif awk -v bitvalue="$bitvalue" 'BEGIN { exit !(bitvalue >= 1024) }'; then
        bitvalue=$(awk -v value="$bitvalue" 'BEGIN { printf "%.1fMiB", value / 1024 }')
    else
        # bitvalue="${bitvalue}KiB"
        bitvalue=$(awk -v value="$bitvalue" 'BEGIN { printf "%.1fKiB", value }')
    fi
    echo "$bitvalue"
}

Bit_K_TGMi() {
    bitvalue="$1"
    if awk -v bitvalue="$bitvalue" 'BEGIN { exit !(bitvalue >= (1024 * 1024 * 1024)) }'; then
        bitvalue=$(awk -v value="$bitvalue" 'BEGIN { printf "%.1fTibit", value / (1024 * 1024 * 1024) }')
    elif awk -v bitvalue="$bitvalue" 'BEGIN { exit !(bitvalue >= (1024 * 1024)) }'; then
        bitvalue=$(awk -v value="$bitvalue" 'BEGIN { printf "%.1fGibit", value / (1024 * 1024) }')
    elif awk -v bitvalue="$bitvalue" 'BEGIN { exit !(bitvalue >= 1024) }'; then
        bitvalue=$(awk -v value="$bitvalue" 'BEGIN { printf "%.1fMibit", value / 1024 }')
    else
        # bitvalue="${bitvalue}Kibit"
        bitvalue=$(awk -v value="$bitvalue" 'BEGIN { printf "%.1fKibit", value }')
    fi
    echo "$bitvalue"
}

Bytes_B_TGMK() {
    bitvalue="$1"
    if awk -v bitvalue="$bitvalue" 'BEGIN { exit !(bitvalue >= (1024 * 1024 * 1024 * 1024)) }'; then
        bitvalue=$(awk -v value="$bitvalue" 'BEGIN { printf "%.1fTB", value / (1024 * 1024 * 1024 * 1024) }')
    elif awk -v bitvalue="$bitvalue" 'BEGIN { exit !(bitvalue >= (1024 * 1024 * 1024)) }'; then
        bitvalue=$(awk -v value="$bitvalue" 'BEGIN { printf "%.1fGB", value / (1024 * 1024 * 1024) }')
    elif awk -v bitvalue="$bitvalue" 'BEGIN { exit !(bitvalue >= 1024 * 1024) }'; then
        bitvalue=$(awk -v value="$bitvalue" 'BEGIN { printf "%.1fMB", value / (1024 * 1024) }')
    elif awk -v bitvalue="$bitvalue" 'BEGIN { exit !(bitvalue >= 1024) }'; then
        bitvalue=$(awk -v value="$bitvalue" 'BEGIN { printf "%.1fKB", value / 1024 }')
    else
        bitvalue="${bitvalue}bB"
    fi
    echo "$bitvalue"
}

TG_M_removeXB() {
    bitvalue="$1"
    if [[ $bitvalue == *MB ]]; then
        bitvalue=${bitvalue%MB}
        bitvalue=$(awk -v value=$bitvalue 'BEGIN { printf "%.1f", value }')
    elif [[ $bitvalue == *GB ]]; then
        bitvalue=${bitvalue%GB}
        bitvalue=$(awk -v value=$bitvalue 'BEGIN { printf "%.1f", value * 1024 }')
    elif [[ $bitvalue == *TB ]]; then
        bitvalue=${bitvalue%TB}
        bitvalue=$(awk -v value=$bitvalue 'BEGIN { printf "%.1f", value * 1024 * 1024 }')
    fi
    echo "$bitvalue"
}

# 数组去重处理
unique_array() {
    local array_in=("$@")
    local array_out=()
    array_out=($(printf "%s\n" "${array_in[@]}" | awk '!a[$0]++'))
    echo "${array_out[*]}"
}

# 数组加入分隔符
sep_array() {
    local -n array_in=$1 # 引用传入的数组名称
    local separator=$2   # 分隔符
    local array_out=""
    for ((i = 0; i < ${#array_in[@]}; i++)); do
        array_out+="${array_in[$i]}"
        if ((i < ${#array_in[@]} - 1)); then
            array_out+="$separator"
        fi
    done
    echo "$array_out"
}

# 设置流量报警
SetupFlow_TG() {
    if [ ! -z "$flow_pid" ] && pgrep -a '' | grep -Eq "^\s*$flow_pid\s" > /dev/null; then
        tips="$Err PID(${GR}$flow_pid${NC}) 正在发送中,请稍后..."
        return 1
    fi
    if [[ -z "${TelgramBotToken}" || -z "${ChatID_1}" ]]; then
        tips="$Err 参数丢失, 请设置后再执行 (先执行 ${GR}0${NC} 选项)."
        return 1
    fi
    if [ "$autorun" == "false" ]; then
        echo -en "请输入 流量报警阈值 ${GR}数字 + MB/GB/TB${NC} (回车跳过修改): "
        read -er threshold
    else
        if [ ! -z "$FlowThreshold" ]; then
            threshold=$FlowThreshold
        else
            threshold=$FlowThreshold_de
        fi
    fi
    if [ -z "$threshold" ]; then
        echo
        tips="$Tip 输入为空, 跳过操作."
        return 1
    fi
    if [[ $threshold =~ ^[0-9]+(\.[0-9])?$ ]] || [[ $threshold =~ ^[0-9]+(\.[0-9]+)?(M)$ ]] || [[ $threshold =~ ^[0-9]+(\.[0-9]+)?(MB)$ ]] || [[ $threshold =~ ^[0-9]+(\.[0-9]+)?(m)$ ]] || [[ $threshold =~ ^[0-9]+(\.[0-9]+)?(mb)$ ]]; then
        threshold=${threshold%M}
        threshold=${threshold%MB}
        threshold=${threshold%m}
        threshold=${threshold%mb}
        if awk -v value="$threshold" 'BEGIN { exit !(value >= 1024 * 1024) }'; then
            threshold=$(awk -v value="$threshold" 'BEGIN { printf "%.1f", value / (1024 * 1024) }')
            threshold="${threshold}TB"
        elif awk -v value="$threshold" 'BEGIN { exit !(value >= 1024) }'; then
            threshold=$(awk -v value="$threshold" 'BEGIN { printf "%.1f", value / 1024 }')
            threshold="${threshold}GB"
        else
            threshold="${threshold}MB"
        fi
        writeini "FlowThreshold" "$threshold"
    elif [[ $threshold =~ ^[0-9]+(\.[0-9]+)?(G)$ ]] || [[ $threshold =~ ^[0-9]+(\.[0-9]+)?(GB)$ ]] || [[ $threshold =~ ^[0-9]+(\.[0-9]+)?(g)$ ]] || [[ $threshold =~ ^[0-9]+(\.[0-9]+)?(gb)$ ]]; then
        threshold=${threshold%G}
        threshold=${threshold%GB}
        threshold=${threshold%g}
        threshold=${threshold%gb}
        if awk -v value="$threshold" 'BEGIN { exit !(value >= 1024) }'; then
            threshold=$(awk -v value="$threshold" 'BEGIN { printf "%.1f", value / 1024 }')
            threshold="${threshold}TB"
        else
            threshold="${threshold}GB"
        fi
        writeini "FlowThreshold" "$threshold"
    elif [[ $threshold =~ ^[0-9]+(\.[0-9]+)?(T)$ ]] || [[ $threshold =~ ^[0-9]+(\.[0-9]+)?(TB)$ ]] || [[ $threshold =~ ^[0-9]+(\.[0-9]+)?(t)$ ]] || [[ $threshold =~ ^[0-9]+(\.[0-9]+)?(tb)$ ]]; then
        threshold=${threshold%T}
        threshold=${threshold%TB}
        threshold=${threshold%t}
        threshold=${threshold%tb}
        threshold="${threshold}TB"
        writeini "FlowThreshold" "$threshold"
    else
        echo -e "$Err ${REB}输入无效${NC}, 报警阈值 必须是: 数字|数字MB/数字GB (%.1f) 的格式."
        tips="$Err ${REB}输入无效${NC}, 报警阈值 必须是: 数字|数字MB/数字GB (%.1f) 的格式."
        return 1
    fi
    if [ "$autorun" == "false" ]; then
        echo -en "请设置 流量上限 ${GR}数字 + MB/GB/TB${NC} (回车默认: $FlowThresholdMAX_de): "
        read -er threshold_max
    else
        if [ ! -z "$FlowThresholdMAX" ]; then
            threshold_max=$FlowThresholdMAX
        else
            threshold_max=$FlowThresholdMAX_de
        fi
    fi
    if [ ! -z "$threshold_max" ]; then
        if [[ $threshold_max =~ ^[0-9]+(\.[0-9])?$ ]] || [[ $threshold_max =~ ^[0-9]+(\.[0-9]+)?(M)$ ]] || [[ $threshold_max =~ ^[0-9]+(\.[0-9]+)?(MB)$ ]] || [[ $threshold_max =~ ^[0-9]+(\.[0-9]+)?(m)$ ]] || [[ $threshold_max =~ ^[0-9]+(\.[0-9]+)?(mb)$ ]]; then
            threshold_max=${threshold_max%M}
            threshold_max=${threshold_max%MB}
            threshold_max=${threshold_max%m}
            threshold_max=${threshold_max%mb}
            if awk -v value="$threshold_max" 'BEGIN { exit !(value >= 1024 * 1024) }'; then
                threshold_max=$(awk -v value="$threshold_max" 'BEGIN { printf "%.1f", value / (1024 * 1024) }')
                threshold_max="${threshold_max}TB"
            elif awk -v value="$threshold_max" 'BEGIN { exit !(value >= 1024) }'; then
                threshold_max=$(awk -v value="$threshold_max"_max 'BEGIN { printf "%.1f", value / 1024 }')
                threshold_max="${threshold_max}GB"
            else
                threshold_max="${threshold_max}MB"
            fi
            writeini "FlowThresholdMAX" "$threshold_max"
        elif [[ $threshold_max =~ ^[0-9]+(\.[0-9]+)?(G)$ ]] || [[ $threshold_max =~ ^[0-9]+(\.[0-9]+)?(GB)$ ]] || [[ $threshold_max =~ ^[0-9]+(\.[0-9]+)?(g)$ ]] || [[ $threshold_max =~ ^[0-9]+(\.[0-9]+)?(gb)$ ]]; then
            threshold_max=${threshold_max%G}
            threshold_max=${threshold_max%GB}
            threshold_max=${threshold_max%g}
            threshold_max=${threshold_max%gb}
            if awk -v value="$threshold_max" 'BEGIN { exit !(value >= 1024) }'; then
                threshold_max=$(awk -v value="$threshold_max"_max 'BEGIN { printf "%.1f", value / 1024 }')
                threshold_max="${threshold_max}TB"
            else
                threshold_max="${threshold_max}GB"
            fi
            writeini "FlowThresholdMAX" "$threshold_max"
        elif [[ $threshold_max =~ ^[0-9]+(\.[0-9]+)?(T)$ ]] || [[ $threshold_max =~ ^[0-9]+(\.[0-9]+)?(TB)$ ]] || [[ $threshold_max =~ ^[0-9]+(\.[0-9]+)?(t)$ ]] || [[ $threshold_max =~ ^[0-9]+(\.[0-9]+)?(tb)$ ]]; then
            threshold_max=${threshold_max%T}
            threshold_max=${threshold_max%TB}
            threshold_max=${threshold_max%t}
            threshold_max=${threshold_max%tb}
            threshold_max="${threshold_max}TB"
            writeini "FlowThresholdMAX" "$threshold_max"
        else
            echo -e "$Err ${REB}输入无效${NC}, 报警阈值 必须是: 数字|数字MB/数字GB (%.1f) 的格式."
            tips="$Err ${REB}输入无效${NC}, 报警阈值 必须是: 数字|数字MB/数字GB (%.1f) 的格式."
            return 1
        fi
    else
        echo
        writeini "FlowThresholdMAX" "$FlowThresholdMAX_de"
        echo -e "$Tip 输入为空, 默认最大流量上限为: $FlowThresholdMAX_de"
    fi
    if [ "$autorun" == "false" ]; then
        # interfaces_ST_0=$(ip -br link | awk '$2 == "UP" {print $1}' | grep -v "lo")
        # output=$(ip -br link)
        IFS=$'\n'
        count=1
        choice_array=()
        interfaces_ST=()
        w_interfaces_ST=()
        # for line in $output; do
        for line in ${interfaces_all[@]}; do
            columns_1="$line"
            # columns_1=$(echo "$line" | awk '{print $1}')
            # columns_1=${columns_1[$i]%@*}
            # columns_1=${columns_1%:*}
            columns_1_array+=("$columns_1")
            columns_2="$line"
            # columns_2=$(printf "%s\t\tUP" "$line")
            # columns_2=$(echo "$line" | awk '{print $1"\t"UP}')
            # columns_2=${columns_2[$i]%@*}
            # columns_2=${columns_2%:*}
            # if [[ $interfaces_ST_0 =~ $columns_1 ]]; then
            if [[ $interfaces_up =~ $columns_1 ]]; then
                printf "${GR}%d. %s${NC}\n" "$count" "$columns_2"
            else
                printf "${GR}%d. ${NC}%s\n" "$count" "$columns_1"
            fi
            ((count++))
        done
        echo -e "请选择编号进行统计, 例如统计1项和2项可输入: ${GR}1,2${NC} 或 ${GR}回车自动检测${NC}活跃接口:"
        read -e -p "请输入统计接口编号: " choice
        # if [[ $choice == *0* ]]; then
        #     tips="$Err 接口编号中没有 0 选项"
        #     return 1
        # fi
        if [ ! -z "$choice" ]; then
            # choice="${choice//[, ]/}"
            # for (( i=0; i<${#choice}; i++ )); do
            # char="${choice:$i:1}"
            # if [[ "$char" =~ [0-9] ]]; then
            #     choice_array+=("$char")
            # fi
            # done
            # # echo "解析后的接口编号数组: ${choice_array[@]}"
            # for item in "${choice_array[@]}"; do
            #     index=$((item - 1))
            #     if [ -z "${columns_1_array[index]}" ]; then
            #         tips="$Err 错误: 输入的编号 $item 无效或超出范围."
            #         return 1
            #     else
            #         interfaces_ST+=("${columns_1_array[index]}")
            #     fi
            # done

            if [ "$choice" == "0" ]; then
                tips="$Err 输入错误, 没有0选择."
                return 1
            fi

            if ! [[ "$choice" =~ ^[0-9,]+$ ]]; then
                tips="$Err 输入的选项无效, 请输入有效的数字选项或使用逗号分隔多个数字选项."
                return 1
            fi

            choice="${choice//[, ]/,}"  # 将所有逗号后的空格替换成单逗号
            IFS=',' read -ra choice_array <<< "$choice"  # 使用逗号作为分隔符将输入拆分成数组

            for item in "${choice_array[@]}"; do
                if [ "$item" -eq 0 ] || [ "$item" -gt "${#interfaces_all[@]}" ]; then
                    tips="$Err 输入错误, 输入的选项 $item 无效或超出范围。"
                    return 1
                fi
                index=$((item - 1))
                interfaces_ST+=("${columns_1_array[index]}")
            done

            # for ((i = 0; i < ${#interfaces_ST[@]}; i++)); do
            #     w_interfaces_ST+="${interfaces_ST[$i]}"
            #     if ((i < ${#interfaces_ST[@]} - 1)); then
            #         w_interfaces_ST+=","
            #     fi
            # done
            w_interfaces_ST=$(sep_array interfaces_ST ",")
            # echo "确认选择接口: $w_interfaces_ST"
            writeini "interfaces_ST" "$w_interfaces_ST"
        else
            # IFS=',' read -ra interfaces_ST_de <<< "$interfaces_ST_de"
            # IFS=',' read -ra interfaces <<< "$(echo "$interfaces_ST_de" | tr ',' '\n' | sort -u | tr '\n' ',')"
            # IFS=',' read -ra interfaces <<< "$(echo "$interfaces_ST_de" | awk -v RS=, '!a[$1]++ {if (NR>1) printf ",%s", $0; else printf "%s", $0}')"
            # interfaces_ST=("${interfaces_ST_de[@]}")
            # interfaces_all=$(ip -br link | awk '{print $1}' | tr '\n' ' ')
            active_interfaces=()
            echo "检查网络接口流量情况..."
            for interface in ${interfaces_all[@]}
            do
            clean_interface=${interface%%@*}
            stats=$(ip -s link show $clean_interface)
            rx_packets=$(echo "$stats" | awk '/RX:/{getline; print $2}')
            tx_packets=$(echo "$stats" | awk '/TX:/{getline; print $2}')
            if [ "$rx_packets" -gt 0 ] || [ "$tx_packets" -gt 0 ]; then
                echo "接口: $clean_interface 活跃, 接收: $rx_packets 包, 发送: $tx_packets 包."
                active_interfaces+=($clean_interface)
            else
                echo "接口: $clean_interface 不活跃."
            fi
            done
            interfaces_ST=("${active_interfaces[@]}")
            # for ((i = 0; i < ${#interfaces_ST[@]}; i++)); do
            #     w_interfaces_ST+="${interfaces_ST[$i]}"
            #     if ((i < ${#interfaces_ST[@]} - 1)); then
            #         w_interfaces_ST+=","
            #     fi
            # done
            w_interfaces_ST=$(sep_array interfaces_ST ",")
            echo -e "$Tip 检测到活动的接口: $w_interfaces_ST"
            # echo "确认选择接口: $w_interfaces_ST"
            writeini "interfaces_ST" "$w_interfaces_ST"
        fi
    else
        if [ ! -z "${interfaces_ST+x}" ]; then
            interfaces_ST=("${interfaces_ST[@]}")
        else
            interfaces_ST=("${interfaces_ST_de[@]}")
        fi
        echo "interfaces_ST: $interfaces_ST"
    fi
    interfaces_ST=($(unique_array "${interfaces_ST[@]}")) # 去重处理
    show_interfaces_ST=$(sep_array interfaces_ST ",") # 加入分隔符
    # for ((i = 0; i < ${#interfaces_ST[@]}; i++)); do
    #     show_interfaces_ST+="${interfaces_ST[$i]}"
    #     if ((i < ${#interfaces_ST[@]} - 1)); then
    #         show_interfaces_ST+=","
    #     fi
    # done
    if [ "$autorun" == "false" ]; then
        read -e -p "请选择统计模式: 1.接口合计发送  2.接口单独发送 (回车默认为单独发送): " mode
        if [ "$mode" == "1" ]; then
            StatisticsMode_ST="OV"
        elif [ "$mode" == "2" ]; then
            StatisticsMode_ST="SE"
        else
            StatisticsMode_ST=$StatisticsMode_ST_de
        fi
        writeini "StatisticsMode_ST" "$StatisticsMode_ST"
    else
        if [ ! -z "$StatisticsMode_ST" ]; then
            StatisticsMode_ST=$StatisticsMode_ST
        else
            StatisticsMode_ST=$StatisticsMode_ST_de
        fi
    fi
    echo "统计模式为: $StatisticsMode_ST"

    source $ConfigFile
    FlowThreshold_UB=$FlowThreshold
    FlowThreshold_U=$(Remove_B "$FlowThreshold")
    if [[ $FlowThreshold == *MB ]]; then
        FlowThreshold=${FlowThreshold%MB}
        FlowThreshold=$(awk -v value=$FlowThreshold 'BEGIN { printf "%.1f", value }')
    elif [[ $FlowThreshold == *GB ]]; then
        FlowThreshold=${FlowThreshold%GB}
        FlowThreshold=$(awk -v value=$FlowThreshold 'BEGIN { printf "%.1f", value * 1024 }')
    elif [[ $FlowThreshold == *TB ]]; then
        FlowThreshold=${FlowThreshold%TB}
        FlowThreshold=$(awk -v value=$FlowThreshold 'BEGIN { printf "%.1f", value * 1024 * 1024 }')
    fi
    FlowThresholdMAX_UB=$FlowThresholdMAX
    FlowThresholdMAX_U=$(Remove_B "$FlowThresholdMAX_UB")
    if [[ $FlowThresholdMAX == *MB ]]; then
        FlowThresholdMAX=${FlowThresholdMAX%MB}
        FlowThresholdMAX=$(awk -v value=$FlowThresholdMAX 'BEGIN { printf "%.1f", value }')
    elif [[ $FlowThresholdMAX == *GB ]]; then
        FlowThresholdMAX=${FlowThresholdMAX%GB}
        FlowThresholdMAX=$(awk -v value=$FlowThresholdMAX 'BEGIN { printf "%.1f", value * 1024 }')
    elif [[ $FlowThresholdMAX == *TB ]]; then
        FlowThresholdMAX=${FlowThresholdMAX%TB}
        FlowThresholdMAX=$(awk -v value=$FlowThresholdMAX 'BEGIN { printf "%.1f", value * 1024 * 1024 }')
    fi
    cat <<EOF > $FolderPath/tg_flow.sh
#!/bin/bash

$(declare -f create_progress_bar)
$(declare -f ratioandprogress)
progress=""
ratio=""
$(declare -f Bytes_B_TGMK)
$(declare -f TG_M_removeXB)
$(declare -f Remove_B)
$(declare -f redup_array)
$(declare -f clear_array)
$(declare -f sep_array)
$(declare -f Checkpara)

FolderPath="$FolderPath"
if [ ! -d "\$FolderPath" ]; then
    mkdir -p "\$FolderPath"
fi
ConfigFile="$ConfigFile"
source \$ConfigFile &>/dev/null
Checkpara "hostname_show" "$hostname_show"
Checkpara "ProxyURL" "$ProxyURL"
Checkpara "StatisticsMode_ST" "$StatisticsMode_ST"
Checkpara "SendUptime" "$SendUptime"
Checkpara "SendIP" "$SendIP"
Checkpara "GetIP46" "$GetIP46"
Checkpara "GetIPURL" "$GetIPURL"
Checkpara "SendPrice" "$SendPrice"
Checkpara "GetPriceType" "$GetPriceType"
Checkpara "FlowThreshold" "$FlowThreshold"
Checkpara "FlowThresholdMAX" "$FlowThresholdMAX"
Checkpara "interfaces_ST" "$interfaces_ST"

FlowThreshold_U=\$(Remove_B "\$FlowThreshold")
FlowThreshold=\$(TG_M_removeXB "\$FlowThreshold")
FlowThresholdMAX_U=\$(Remove_B "\$FlowThresholdMAX")
FlowThresholdMAX=\$(TG_M_removeXB "\$FlowThresholdMAX")

get_price() {
    local url="\${ProxyURL}https://api.coingecko.com/api/v3/simple/price?ids=\${1}&vs_currencies=usd"
    local price=\$(curl -s "\$url" | sed 's/[^0-9.]*//g')
    echo "\$price"
}

tt=10
duration=0
StatisticsMode_ST="\$StatisticsMode_ST"

if [ "\$SendUptime" == "true" ]; then
    SendUptime="true"
else
    SendUptime="false"
fi
if [ "\$SendIP" == "true" ]; then
    SendIP="true"
else
    SendIP="false"
fi
if [ "\$SendPrice" == "true" ]; then
    SendPrice="true"
else
    SendPrice="false"
fi

echo "FlowThreshold: \$FlowThreshold  FlowThresholdMAX: \$FlowThresholdMAX"
THRESHOLD_BYTES=\$(awk "BEGIN {print \$FlowThreshold * 1024 * 1024}")
THRESHOLD_BYTES_MAX=\$(awk "BEGIN {print \$FlowThresholdMAX * 1024 * 1024}")

# sci_notation_regex='^[0-9]+(\.[0-9]+)?[eE][+-]?[0-9]+$'
# if [[ \$THRESHOLD_BYTES =~ \$sci_notation_regex ]]; then
#     THRESHOLD_BYTES=\$(printf "%.0f" \$THRESHOLD_BYTES)
# fi
# if [[ \$THRESHOLD_BYTES_MAX =~ \$sci_notation_regex ]]; then
#     THRESHOLD_BYTES_MAX=\$(printf "%.0f" \$THRESHOLD_BYTES_MAX)
# fi

THRESHOLD_BYTES=\$(printf "%.0f" \$THRESHOLD_BYTES)
THRESHOLD_BYTES_MAX=\$(printf "%.0f" \$THRESHOLD_BYTES_MAX)
echo "==================================================================="
echo "THRESHOLD_BYTES: \$THRESHOLD_BYTES  THRESHOLD_BYTES_MAX: \$THRESHOLD_BYTES_MAX"

# interfaces_up=\$(ip -br link | awk '\$2 == "UP" {print \$1}' | grep -v "lo")
# interfaces_all=\$(ip -br link | awk '{print \$1}' | tr '\n' ' ')
# declare -a interfaces=(\$interfaces_get)
# IFS=',' read -ra interfaces <<< "\$interfaces_ST"
# 去重并且分割字符串为数组
# IFS=',' read -ra interfaces <<< "\$(echo "\$interfaces_ST" | tr ',' '\n' | sort -u | tr '\n' ',')"
# 去重并且保持原有顺序，分割字符串为数组
# IFS=',' read -ra interfaces <<< "$(echo "$interfaces_ST" | awk -v RS=, '!a[$1]++ {if (NR>1) printf ",%s", $0; else printf "%s", $0}')"
IFS=',' read -ra interfaces <<< "\$(echo "\$interfaces_ST" | awk -v RS=, '!a[\$1]++ {if (NR>1) printf ",%s", \$0; else printf "%s", \$0}')"


echo "统计接口: \${interfaces[@]}"
for ((i = 0; i < \${#interfaces[@]}; i++)); do
    echo "\$((i+1)): \${interfaces[i]}"
done
# for ((i = 0; i < \${#interfaces[@]}; i++)); do
#     show_interfaces+="\${interfaces[\$i]}"
#     if ((i < \${#interfaces[@]} - 1)); then
#         show_interfaces+=","
#     fi
# done
show_interfaces=\$(sep_array interfaces ",")
# 如果接口名称中包含 '@' 或 ':'，则仅保留 '@' 或 ':' 之前的部分
# for ((i=0; i<\${#interfaces[@]}; i++)); do
#     interface=\${interfaces[\$i]%@*}
#     interface=\${interface%:*}
#     interfaces[\$i]=\$interface
# done
interfaces=(\$(clear_array "\${interfaces[@]}"))
echo "纺计接口(处理后): \${interfaces[@]}"

# 之前使用的是下面代码，统计网速时采用UP标记的接口，由于有些特殊名称的接口容易导致统计网速时出错，后改为与检测流量的接口相同.
interfaces_up=(\${interfaces[@]})

# interfaces_up=\$(ip -br link | awk '\$2 == "UP" {print \$1}' | grep -v "lo")
# 如果接口名称中包含 '@' 或 ':'，则仅保留 '@' 或 ':' 之前的部分
# for ((i=0; i<\${#interfaces_up[@]}; i++)); do
#     interface=\${interfaces_up[\$i]%@*}
#     interface=\${interface%:*}
#     interfaces_up[\$i]=\$interface
# done
# interfaces_up=(\$(redup_array "\${interfaces_up[@]}"))
# interfaces_up=(\$(clear_array "\${interfaces_up[@]}"))
echo "纺计网速接口(处理后): \${interfaces_up[@]}"

# 定义数组
declare -A prev_rx_bytes
declare -A prev_tx_bytes
declare -A prev_rx_bytes_T
declare -A prev_tx_bytes_T
declare -A tt_prev_rx_bytes_T
declare -A tt_prev_tx_bytes_T
declare -A current_rx_bytes
declare -A current_tx_bytes
declare -A INTERFACE_RT_RX_B
declare -A INTERFACE_RT_TX_B

# 初始化接口流量数据
source \$ConfigFile &>/dev/null
for interface in "\${interfaces[@]}"; do
    interface_nodot=\${interface//./_}
    INTERFACE_RT_RX_B[\$interface_nodot]=\${INTERFACE_RT_RX_B[\$interface_nodot]}
    echo "读取: INTERFACE_RT_RX_B[\$interface_nodot]: \${INTERFACE_RT_RX_B[\$interface_nodot]}"
    INTERFACE_RT_TX_B[\$interface_nodot]=\${INTERFACE_RT_TX_B[\$interface_nodot]}
    echo "读取: INTERFACE_RT_TX_B[\$interface_nodot]: \${INTERFACE_RT_TX_B[\$interface_nodot]}"
done

# 循环检查
sendtag=true
tt_prev=false
while true; do

    source \$ConfigFile &>/dev/null
    Checkpara "hostname_show" "$hostname_show"
    Checkpara "ProxyURL" "$ProxyURL"
    Checkpara "StatisticsMode_ST" "$StatisticsMode_ST"
    Checkpara "SendUptime" "$SendUptime"
    Checkpara "SendIP" "$SendIP"
    Checkpara "GetIP46" "$GetIP46"
    Checkpara "GetIPURL" "$GetIPURL"
    Checkpara "SendPrice" "$SendPrice"
    Checkpara "GetPriceType" "$GetPriceType"
    Checkpara "FlowThreshold" "$FlowThreshold"
    Checkpara "FlowThresholdMAX" "$FlowThresholdMAX"

    FlowThreshold_U=\$(Remove_B "\$FlowThreshold")
    FlowThreshold=\$(TG_M_removeXB "\$FlowThreshold")
    FlowThresholdMAX_U=\$(Remove_B "\$FlowThresholdMAX")
    FlowThresholdMAX=\$(TG_M_removeXB "\$FlowThresholdMAX")

    # 获取tt秒前数据

    ov_prev_rx_bytes=0
    ov_prev_tx_bytes=0
    for interface in "\${interfaces[@]}"; do
        interface_nodot=\${interface//./_}
        prev_rx_bytes[\$interface_nodot]=\$(ip -s link show \$interface | awk '/RX:/ { getline; print \$1 }')
        prev_tx_bytes[\$interface_nodot]=\$(ip -s link show \$interface | awk '/TX:/ { getline; print \$1 }')
        ov_prev_rx_bytes=\$((ov_prev_rx_bytes + prev_rx_bytes[\$interface_nodot]))
        ov_prev_tx_bytes=\$((ov_prev_tx_bytes + prev_tx_bytes[\$interface_nodot]))
    done
    if \$sendtag; then
        echo "发送 \$interface 前只执行一次."

        if ! \$tt_prev; then
            for interface in "\${interfaces[@]}"; do
                interface_nodot=\${interface//./_}
                prev_rx_bytes_T[\$interface_nodot]=\${prev_rx_bytes[\$interface_nodot]}
                prev_tx_bytes_T[\$interface_nodot]=\${prev_tx_bytes[\$interface_nodot]}
            done
            ov_prev_rx_bytes_T=\$ov_prev_rx_bytes
            ov_prev_tx_bytes_T=\$ov_prev_tx_bytes
        else
            for interface in "\${interfaces[@]}"; do
                interface_nodot=\${interface//./_}
                prev_rx_bytes_T[\$interface_nodot]=\${tt_prev_rx_bytes_T[\$interface_nodot]}
                prev_tx_bytes_T[\$interface_nodot]=\${tt_prev_tx_bytes_T[\$interface_nodot]}
            done
            ov_prev_rx_bytes_T=\$tt_ov_prev_rx_bytes_T
            ov_prev_tx_bytes_T=\$tt_ov_prev_tx_bytes_T
        fi

    fi
    sendtag=false
    echo "上一次发送前记录 (为了避免在发送过程中未统计到而造成数据遗漏):"
    echo "SE模式: rx_bytes[\$interface_nodot]: \${prev_rx_bytes_T[\$interface_nodot]} tx_bytes[\$interface_nodot]: \${prev_tx_bytes_T[\$interface_nodot]}"
    echo "OV模式: ov_rx_bytes: \$ov_prev_rx_bytes_T ov_tx_bytes: \$ov_prev_tx_bytes_T"

    sp_ov_prev_rx_bytes=0
    sp_ov_prev_tx_bytes=0
    for interface in "\${interfaces_up[@]}"; do
        interface_nodot=\${interface//./_}
        prev_rx_bytes[\$interface_nodot]=\$(ip -s link show \$interface | awk '/RX:/ { getline; print \$1 }')
        prev_tx_bytes[\$interface_nodot]=\$(ip -s link show \$interface | awk '/TX:/ { getline; print \$1 }')
        sp_ov_prev_rx_bytes=\$((sp_ov_prev_rx_bytes + prev_rx_bytes[\$interface_nodot]))
        sp_ov_prev_tx_bytes=\$((sp_ov_prev_tx_bytes + prev_tx_bytes[\$interface_nodot]))
    done

    # 等待tt秒
    end_time=\$(date +%s%N)
    if [ ! -z "\$start_time" ]; then
        time_diff=\$((end_time - start_time))
        time_diff_ms=\$((time_diff / 1000000))

        # 输出执行FOR所花费时间
        echo "上一个 FOR循环 所执行时间 \$time_diff_ms 毫秒."

        duration=\$(awk "BEGIN {print \$time_diff_ms/1000}")
        sleep_time=\$(awk -v v1=\$tt -v v2=\$duration 'BEGIN { printf "%.3f", v1 - v2 }')
    else
        sleep_time=\$tt
    fi
    sleep_time=\$(awk "BEGIN {print (\$sleep_time < 0 ? 0 : \$sleep_time)}")
    echo "sleep_time: \$sleep_time   duration: \$duration"
    sleep \$sleep_time
    start_time=\$(date +%s%N)

    # 获取tt秒后数据
    ov_current_rx_bytes=0
    ov_current_tx_bytes=0
    for interface in "\${interfaces[@]}"; do
        interface_nodot=\${interface//./_}
        current_rx_bytes[\$interface_nodot]=\$(ip -s link show \$interface | awk '/RX:/ { getline; print \$1 }')
        current_tx_bytes[\$interface_nodot]=\$(ip -s link show \$interface | awk '/TX:/ { getline; print \$1 }')
        ov_current_rx_bytes=\$((ov_current_rx_bytes + current_rx_bytes[\$interface_nodot]))
        ov_current_tx_bytes=\$((ov_current_tx_bytes + current_tx_bytes[\$interface_nodot]))
    done
    sp_ov_current_rx_bytes=0
    sp_ov_current_tx_bytes=0
    for interface in "\${interfaces_up[@]}"; do
        interface_nodot=\${interface//./_}
        sp_current_rx_bytes[\$interface_nodot]=\$(ip -s link show \$interface | awk '/RX:/ { getline; print \$1 }')
        sp_current_tx_bytes[\$interface_nodot]=\$(ip -s link show \$interface | awk '/TX:/ { getline; print \$1 }')
        sp_ov_current_rx_bytes=\$((sp_ov_current_rx_bytes + sp_current_rx_bytes[\$interface_nodot]))
        sp_ov_current_tx_bytes=\$((sp_ov_current_tx_bytes + sp_current_tx_bytes[\$interface_nodot]))
    done

    for interface in "\${interfaces[@]}"; do
        interface_nodot=\${interface//./_}
        tt_prev_rx_bytes_T[\$interface_nodot]=\${current_rx_bytes[\$interface_nodot]}
        tt_prev_tx_bytes_T[\$interface_nodot]=\${current_tx_bytes[\$interface_nodot]}
    done
    tt_ov_prev_rx_bytes_T=\$ov_current_rx_bytes
    tt_ov_prev_tx_bytes_T=\$ov_current_tx_bytes
    tt_prev=true

    nline=1
    for interface in "\${interfaces[@]}"; do
        interface_nodot=\${interface//./_}
        echo "NO.\$nline ----------------------------------------- interface: \$interface"

        # 计算差值
        rx_diff_bytes=\$((current_rx_bytes[\$interface_nodot] - prev_rx_bytes_T[\$interface_nodot]))
        tx_diff_bytes=\$((current_tx_bytes[\$interface_nodot] - prev_tx_bytes_T[\$interface_nodot]))
        ov_rx_diff_bytes=\$((ov_current_rx_bytes - ov_prev_rx_bytes_T))
        ov_tx_diff_bytes=\$((ov_current_tx_bytes - ov_prev_tx_bytes_T))

        # 计算网速
        ov_rx_diff_speed=\$((sp_ov_current_rx_bytes - sp_ov_prev_rx_bytes))
        ov_tx_diff_speed=\$((sp_ov_current_tx_bytes - sp_ov_prev_tx_bytes))
        # rx_speed=\$(awk "BEGIN { speed = \$ov_rx_diff_speed / (\$tt * 1024); if (speed >= 1024) { printf \"%.1fMB\", speed/1024 } else { printf \"%.1fKB\", speed } }")
        # tx_speed=\$(awk "BEGIN { speed = \$ov_tx_diff_speed / (\$tt * 1024); if (speed >= 1024) { printf \"%.1fMB\", speed/1024 } else { printf \"%.1fKB\", speed } }")
        rx_speed=\$(awk -v v1="\$ov_rx_diff_speed" -v t1="\$tt" \
            'BEGIN {
                speed = v1 / (t1 * 1024)
                if (speed >= (1024 * 1024)) {
                    printf "%.1fGB", speed/(1024 * 1024)
                } else if (speed >= 1024) {
                    printf "%.1fMB", speed/1024
                } else {
                    printf "%.1fKB", speed
                }
            }')
        tx_speed=\$(awk -v v1="\$ov_tx_diff_speed" -v t1="\$tt" \
            'BEGIN {
                speed = v1 / (t1 * 1024)
                if (speed >= (1024 * 1024)) {
                    printf "%.1fGB", speed/(1024 * 1024)
                } else if (speed >= 1024) {
                    printf "%.1fMB", speed/1024
                } else {
                    printf "%.1fKB", speed
                }
            }')
        rx_speed=\$(Remove_B "\$rx_speed")
        tx_speed=\$(Remove_B "\$tx_speed")

        # 总流量百分比计算
        all_rx_bytes=\$ov_current_rx_bytes
        all_rx_bytes=\$((all_rx_bytes + INTERFACE_RT_RX_B[\$interface_nodot]))
        all_rx_ratio=\$(awk -v used="\$all_rx_bytes" -v total="\$THRESHOLD_BYTES_MAX" 'BEGIN { printf "%.3f", ( used / total ) * 100 }')

        ratioandprogress "0" "0" "\$all_rx_ratio"
        all_rx_progress=\$progress
        all_rx_ratio=\$ratio

        all_rx=\$(Bytes_B_TGMK "\$all_rx_bytes")
        all_rx=\$(Remove_B "\$all_rx")

        all_tx_bytes=\$ov_current_tx_bytes
        all_tx_bytes=\$((all_tx_bytes + INTERFACE_RT_TX_B[\$interface_nodot]))
        all_tx_ratio=\$(awk -v used="\$all_tx_bytes" -v total="\$THRESHOLD_BYTES_MAX" 'BEGIN { printf "%.3f", ( used / total ) * 100 }')

        ratioandprogress "0" "0" "\$all_tx_ratio"
        all_tx_progress=\$progress
        all_tx_ratio=\$ratio

        all_tx=\$(Bytes_B_TGMK "\$all_tx_bytes")
        all_tx=\$(Remove_B "\$all_tx")

        # 调试使用(tt秒的流量增量)
        echo "RX_diff(BYTES): \$rx_diff_bytes TX_diff(BYTES): \$tx_diff_bytes   SE模式下达到 \$THRESHOLD_BYTES 时报警"
        # 调试使用(叠加流量增量)
        echo "OV_RX_diff(BYTES): \$ov_rx_diff_bytes OV_TX_diff(BYTES): \$ov_tx_diff_bytes   OV模式下达到 \$THRESHOLD_BYTES 时报警"
        # 调试使用(TT前记录的流量)
        echo "Prev_rx_bytes_T(BYTES): \${prev_rx_bytes_T[\$interface_nodot]} Prev_tx_bytes_T(BYTES): \${prev_tx_bytes_T[\$interface_nodot]}"
        # # 调试使用(持续的流量增加)
        # echo "Current_RX(BYTES): \${current_rx_bytes[\$interface_nodot]} Current_TX(BYTES): \${current_tx_bytes[\$interface_nodot]}"
        # 调试使用(叠加持续的流量增加)
        echo "OV_Current_RX(BYTES): \$ov_current_rx_bytes OV_Current_TX(BYTES): \$ov_current_tx_bytes"
        # 调试使用(网速)
        echo "rx_speed: \$rx_speed  tx_speed: \$tx_speed"
        # 状态
        echo "统计模式: \$StatisticsMode_ST   发送在线时长: \$SendUptime   发送IP: \$SendIP   发送货币报价: \$SendPrice"

        # 检查是否超过阈值
        if [ "\$StatisticsMode_ST" == "SE" ]; then

            rx_diff_bytes=\$(printf "%.0f" \$rx_diff_bytes)
            tx_diff_bytes=\$(printf "%.0f" \$tx_diff_bytes)

            # threshold_reached=\$(awk -v rx_diff="\$rx_diff" -v tx_diff="\$tx_diff" -v threshold="\$THRESHOLD_BYTES" 'BEGIN {print (rx_diff >= threshold) || (tx_diff >= threshold) ? 1 : 0}')
            # if [ "\$threshold_reached" -eq 1 ]; then

            if [ \$rx_diff_bytes -ge \$THRESHOLD_BYTES ] || [ \$tx_diff_bytes -ge \$THRESHOLD_BYTES ]; then

                rx_diff=\$(Bytes_B_TGMK "\$rx_diff_bytes")
                tx_diff=\$(Bytes_B_TGMK "\$tx_diff_bytes")
                rx_diff=\$(Remove_B "\$rx_diff")
                tx_diff=\$(Remove_B "\$tx_diff")

                current_date_send=\$(date +"%Y.%m.%d %T")

                # 获取uptime输出
                if \$SendUptime; then
                    # read uptime idle_time < /proc/uptime
                    # uptime=\${uptime%.*}
                    # days=\$((uptime/86400))
                    # hours=\$(( (uptime%86400)/3600 ))
                    # minutes=\$(( (uptime%3600)/60 ))
                    # seconds=\$((uptime%60))
                    read uptime idle_time < /proc/uptime
                    uptime=\${uptime%.*}
                    days=\$(awk -v up="\$uptime" 'BEGIN{print int(up/86400)}')
                    hours=\$(awk -v up="\$uptime" 'BEGIN{print int((up%86400)/3600)}')
                    minutes=\$(awk -v up="\$uptime" 'BEGIN{print int((up%3600)/60)}')
                    seconds=\$(awk -v up="\$uptime" 'BEGIN{print int(up%60)}')
                    uptimeshow="系统已运行: \$days 日 \$hours 时 \$minutes 分 \$seconds 秒"
                else
                    uptimeshow=""
                fi
                echo "uptimeshow: \$uptimeshow"
                # 获取IP输出
                if \$SendIP; then
                    # lanIP=\$(ip a | grep -E "inet.*brd" | awk '{print \$2}' | awk -F '/' '{print \$1}' | tr '\n' ' ')
                    wanIP=\$(curl -s -"\$GetIP46" "\$GetIPURL")
                    wanIPshow="网络IP地址: \$wanIP"
                else
                    wanIPshow=""
                fi
                echo "wanIPshow: \$wanIPshow"
                # 获取货币报价
                if \$SendPrice; then
                    priceshow=\$(get_price "\$GetPriceType")
                    if [[ -z \$priceshow || \$priceshow == *"429"* ]]; then
                        # 如果priceshow为空或包含"429"，则表示获取失败
                        priceshow=""
                    fi
                else
                    priceshow=""
                fi
                echo "priceshow: \$priceshow"

                message="流量到达阈值🧭 > \${FlowThreshold_U}❗️  \$priceshow"$'\n'
                message+="主机名: \$hostname_show 接口: \$interface"$'\n'
                message+="已接收: \${rx_diff}  已发送: \${tx_diff}"$'\n'
                message+="───────────────"$'\n'
                message+="总接收: \${all_rx}  总发送: \${all_tx}"$'\n'
                message+="设置流量上限: \${FlowThresholdMAX_U}🔒"$'\n'
                message+="使用⬇️: \$all_rx_progress \$all_rx_ratio"$'\n'
                message+="使用⬆️: \$all_tx_progress \$all_tx_ratio"$'\n'
                message+="网络⬇️: \${rx_speed}/s  网络⬆️: \${tx_speed}/s"$'\n'
                if [[ -n "\$uptimeshow" ]]; then
                    message+="\$uptimeshow"$'\n'
                fi
                if [[ -n "\$wanIPshow" ]]; then
                    message+="\$wanIPshow"$'\n'
                fi
                message+="服务器时间: \$current_date_send"

                \$FolderPath/send_tg.sh "\$TelgramBotToken" "\$ChatID_1" "\$message"
                echo "报警信息已发出..."

                # 更新前一个状态的流量数据
                sendtag=true
            fi
        fi
        nline=\$((nline + 1))
    done
    if [ "\$StatisticsMode_ST" == "OV" ]; then

        ov_rx_diff_bytes=\$(printf "%.0f" \$ov_rx_diff_bytes)
        ov_tx_diff_bytes=\$(printf "%.0f" \$ov_tx_diff_bytes)

        if [ \$ov_rx_diff_bytes -ge \$THRESHOLD_BYTES ] || [ \$ov_tx_diff_bytes -ge \$THRESHOLD_BYTES ]; then

            ov_rx_diff=\$(Bytes_B_TGMK "\$ov_rx_diff_bytes")
            ov_tx_diff=\$(Bytes_B_TGMK "\$ov_tx_diff_bytes")
            ov_rx_diff=\$(Remove_B "\$ov_rx_diff")
            ov_tx_diff=\$(Remove_B "\$ov_tx_diff")

            current_date_send=\$(date +"%Y.%m.%d %T")

            # 获取uptime输出
            if \$SendUptime; then
                # read uptime idle_time < /proc/uptime
                # uptime=\${uptime%.*}
                # days=\$((uptime/86400))
                # hours=\$(( (uptime%86400)/3600 ))
                # minutes=\$(( (uptime%3600)/60 ))
                # seconds=\$((uptime%60))
                read uptime idle_time < /proc/uptime
                uptime=\${uptime%.*}
                days=\$(awk -v up="\$uptime" 'BEGIN{print int(up/86400)}')
                hours=\$(awk -v up="\$uptime" 'BEGIN{print int((up%86400)/3600)}')
                minutes=\$(awk -v up="\$uptime" 'BEGIN{print int((up%3600)/60)}')
                seconds=\$(awk -v up="\$uptime" 'BEGIN{print int(up%60)}')
                uptimeshow="系统已运行: \$days 日 \$hours 时 \$minutes 分 \$seconds 秒"
            else
                uptimeshow=""
            fi
            echo "uptimeshow: \$uptimeshow"
            # 获取IP输出
            if \$SendIP; then
                # lanIP=\$(ip a | grep -E "inet.*brd" | awk '{print \$2}' | awk -F '/' '{print \$1}' | tr '\n' ' ')
                wanIP=\$(curl -s -"\$GetIP46" "\$GetIPURL")
                wanIPshow="网络IP地址: \$wanIP"
            else
                wanIPshow=""
            fi
            echo "wanIPshow: \$wanIPshow"
            # 获取货币报价
            if \$SendPrice; then
                priceshow=\$(get_price "\$GetPriceType")
                if [[ -z \$priceshow || \$priceshow == *"429"* ]]; then
                    # 如果priceshow为空或包含"429"，则表示获取失败
                    priceshow=""
                fi
            else
                priceshow=""
            fi
            echo "priceshow: \$priceshow"

            message="流量到达阈值🧭 > \${FlowThreshold_U}❗️  \$priceshow"$'\n'
            message+="主机名: \$hostname_show 接口: \$show_interfaces"$'\n'
            message+="已接收: \${ov_rx_diff}  已发送: \${ov_tx_diff}"$'\n'
            message+="───────────────"$'\n'
            message+="总接收: \${all_rx}  总发送: \${all_tx}"$'\n'
            message+="设置流量上限: \${FlowThresholdMAX_U}🔒"$'\n'
            message+="使用⬇️: \$all_rx_progress \$all_rx_ratio"$'\n'
            message+="使用⬆️: \$all_tx_progress \$all_tx_ratio"$'\n'
            message+="网络⬇️: \${rx_speed}/s  网络⬆️: \${tx_speed}/s"$'\n'
            if [[ -n "\$uptimeshow" ]]; then
                message+="\$uptimeshow"$'\n'
            fi
            if [[ -n "\$wanIPshow" ]]; then
                message+="\$wanIPshow"$'\n'
            fi
            message+="服务器时间: \$current_date_send"

            \$FolderPath/send_tg.sh "\$TelgramBotToken" "\$ChatID_1" "\$message"
            echo "报警信息已发出..."

            # 更新前一个状态的流量数据
            sendtag=true
        fi
    fi
    if [ "\$StatisticsMode_ST" != "SE" ] && [ "\$StatisticsMode_ST" != "OV" ]; then
        echo "StatisticsMode_ST Err!!! \$StatisticsMode_ST"
    fi
done
EOF
    chmod +x $FolderPath/tg_flow.sh
    # pkill tg_flow.sh > /dev/null 2>&1 &
    # pkill tg_flow.sh > /dev/null 2>&1 &
    # kill $(ps | grep '[t]g_flow.sh' | awk '{print $1}')
    killpid "tg_flow.sh"
    nohup $FolderPath/tg_flow.sh > $FolderPath/tg_flow.log 2>&1 &
    delcrontab "$FolderPath/tg_flow.sh"
    addcrontab "@reboot nohup $FolderPath/tg_flow.sh > $FolderPath/tg_flow.log 2>&1 &"
#     cat <<EOF > $FolderPath/tg_interface_re.sh
#     # 内容已经移位.
# EOF
    # # 此为单独计算网速的子脚本（暂未启用）
    # chmod +x $FolderPath/tg_interface_re.sh
    # pkill -f tg_interface_re.sh > /dev/null 2>&1 &
    # pkill -f tg_interface_re.sh > /dev/null 2>&1 &
    # kill $(ps | grep '[t]g_interface_re.sh' | awk '{print $1}')
    # nohup $FolderPath/tg_interface_re.sh > $FolderPath/tg_interface_re.log 2>&1 &
    ##############################################################################
#     cat <<EOF > /etc/systemd/system/tg_interface_re.service
# [Unit]
# Description=tg_interface_re
# DefaultDependencies=no
# Before=shutdown.target

# [Service]
# Type=oneshot
# ExecStart=$FolderPath/tg_interface_re.sh
# TimeoutStartSec=0

# [Install]
# WantedBy=shutdown.target
# EOF
#     systemctl enable tg_interface_re.service > /dev/null
    if [ "$mute" == "false" ]; then
        send_time=$(echo $(date +%s%N) | cut -c 16-)
        message="流量报警设置成功 ⚙️"$'\n'"主机名: $hostname_show"$'\n'"检测接口: $show_interfaces_ST"$'\n'"检测模式: $StatisticsMode_ST"$'\n'"当流量达阈值 $FlowThreshold_UB 时将收到通知💡"
        $FolderPath/send_tg.sh "$TelgramBotToken" "$ChatID_1" "$message" "flow" "$send_time" &
        (sleep 15 && $FolderPath/del_lm_tg.sh "$TelgramBotToken" "$ChatID_1" "flow" "$send_time") &
        sleep 1
        # getpid "send_tg.sh"
        # flow_pid="$tg_pid"
        flow_pid=$(getpid "send_tg.sh")
    fi
    tips="$Tip 流量 通知已经设置成功, 当流量使用达 ${GR}$FlowThreshold_UB${NC} 时发出通知."
}

SetFlowReport_TG() {
    if [ ! -z "$flrp_pid" ] && pgrep -a '' | grep -Eq "^\s*$flrp_pid\s" > /dev/null; then
        tips="$Err PID(${GR}$flrp_pid${NC}) 正在发送中,请稍后..."
        return 1
    fi
    if [[ -z "${TelgramBotToken}" || -z "${ChatID_1}" ]]; then
        tips="$Err 参数丢失, 请设置后再执行 (先执行 ${GR}0${NC} 选项)."
        return 1
    fi
    if [ "$autorun" == "false" ]; then
        echo -e "$Tip 输入流量报告时间, 格式如: 22:34 (即每天 ${GR}22${NC} 时 ${GR}34${NC} 分)"
        read -e -p "请输入定时模式  (回车默认: $ReportTime_de ): " input_time
    else
        if [ -z "$ReportTime" ]; then
            input_time=""
        else
            input_time=$ReportTime
        fi
    fi
    if [ -z "$input_time" ]; then
        input_time="$ReportTime_de"
    fi
    if [ $(validate_time_format "$input_time") = "invalid" ]; then
        tips="$Err 输入格式不正确，请确保输入的时间格式为 'HH:MM'"
        return 1
    fi
    writeini "ReportTime" "$input_time"
    hour_rp=${input_time%%:*}
    minute_rp=${input_time#*:}
    if [ ${#hour_rp} -eq 1 ]; then
    hour_rp="0${hour_rp}"
    fi
    if [ ${#minute_rp} -eq 1 ]; then
        minute_rp="0${minute_rp}"
    fi
    echo -e "$Tip 流量报告时间: $hour_rp 时 $minute_rp 分."
    cronrp="$minute_rp $hour_rp * * *"

    if [ "$autorun" == "false" ]; then
        # interfaces_RP_0=$(ip -br link | awk '$2 == "UP" {print $1}' | grep -v "lo")
        # output=$(ip -br link)
        IFS=$'\n'
        count=1
        choice_array=()
        interfaces_RP=()
        w_interfaces_RP=()
        # for line in $output; do
        for line in ${interfaces_all[@]}; do
            columns_1="$line"
            # columns_1=$(echo "$line" | awk '{print $1}')
            # columns_1=${columns_1[$i]%@*}
            # columns_1=${columns_1%:*}
            columns_1_array+=("$columns_1")
            columns_2="$line"
            # columns_2=$(printf "%s\t\tUP" "$line")
            # columns_2=$(echo "$line" | awk '{print $1"\t"$2}')
            # columns_2=${columns_2[$i]%@*}
            # columns_2=${columns_2%:*}
            # if [[ $interfaces_RP_0 =~ $columns_1 ]]; then
            if [[ $interfaces_up =~ $columns_1 ]]; then
                printf "${GR}%d. %s${NC}\n" "$count" "$columns_2"
            else
                printf "${GR}%d. ${NC}%s\n" "$count" "$columns_1"
            fi
            ((count++))
        done
        echo -e "请选择编号进行报告, 例如报告1项和2项可输入: ${GR}1,2${NC} 或 ${GR}回车自动检测${NC}活跃接口:"
        read -e -p "请输入统计接口编号: " choice
        # if [[ $choice == *0* ]]; then
        #     tips="$Err 接口编号中没有 0 选项"
        #     return 1
        # fi
        if [ ! -z "$choice" ]; then
            # choice="${choice//[, ]/}"
            # for (( i=0; i<${#choice}; i++ )); do
            # char="${choice:$i:1}"
            # if [[ "$char" =~ [0-9] ]]; then
            #     choice_array+=("$char")
            # fi
            # done
            # # echo "解析后的接口编号数组: ${choice_array[@]}"
            # for item in "${choice_array[@]}"; do
            #     index=$((item - 1))
            #     if [ -z "${columns_1_array[index]}" ]; then
            #         tips="$Err 错误: 输入的编号 $item 无效或超出范围."
            #         return 1
            #     else
            #         interfaces_RP+=("${columns_1_array[index]}")
            #     fi
            # done

            if [ "$choice" == "0" ]; then
                tips="$Err 输入错误, 没有0选择."
                return 1
            fi

            if ! [[ "$choice" =~ ^[0-9,]+$ ]]; then
                tips="$Err 输入的选项无效, 请输入有效的数字选项或使用逗号分隔多个数字选项."
                return 1
            fi

            choice="${choice//[, ]/,}"  # 将所有逗号后的空格替换成单逗号
            IFS=',' read -ra choice_array <<< "$choice"  # 使用逗号作为分隔符将输入拆分成数组

            for item in "${choice_array[@]}"; do
                if [ "$item" -eq 0 ] || [ "$item" -gt "${#interfaces_all[@]}" ]; then
                    tips="$Err 输入错误, 输入的选项 $item 无效或超出范围。"
                    return 1
                fi
                index=$((item - 1))
                interfaces_RP+=("${columns_1_array[index]}")
            done

            # for ((i = 0; i < ${#interfaces_RP[@]}; i++)); do
            #     w_interfaces_RP+="${interfaces_RP[$i]}"
            #     if ((i < ${#interfaces_RP[@]} - 1)); then
            #         w_interfaces_RP+=","
            #     fi
            # done
            w_interfaces_RP=$(sep_array interfaces_RP ",")
            # echo "确认选择接口: $w_interfaces_RP"
            writeini "interfaces_RP" "$w_interfaces_RP"
        else
            # IFS=',' read -ra interfaces_RP_de <<< "$interfaces_RP_de"
            # IFS=',' read -ra interfaces <<< "$(echo "$interfaces_RP_de" | tr ',' '\n' | sort -u | tr '\n' ',')"
            # IFS=',' read -ra interfaces <<< "$(echo "$interfaces_RP_de" | awk -v RS=, '!a[$1]++ {if (NR>1) printf ",%s", $0; else printf "%s", $0}')"
            # interfaces_RP=("${interfaces_RP_de[@]}")
            # interfaces_all=$(ip -br link | awk '{print $1}' | tr '\n' ' ')
            active_interfaces=()
            echo "检查网络接口流量情况..."
            for interface in ${interfaces_all[@]}
            do
            clean_interface=${interface%%@*}
            stats=$(ip -s link show $clean_interface)
            rx_packets=$(echo "$stats" | awk '/RX:/{getline; print $2}')
            tx_packets=$(echo "$stats" | awk '/TX:/{getline; print $2}')
            if [ "$rx_packets" -gt 0 ] || [ "$tx_packets" -gt 0 ]; then
                echo "接口: $clean_interface 活跃, 接收: $rx_packets 包, 发送: $tx_packets 包."
                active_interfaces+=($clean_interface)
            else
                echo "接口: $clean_interface 不活跃."
            fi
            done
            interfaces_RP=("${active_interfaces[@]}")
            # for ((i = 0; i < ${#interfaces_RP[@]}; i++)); do
            #     w_interfaces_RP+="${interfaces_RP[$i]}"
            #     if ((i < ${#interfaces_RP[@]} - 1)); then
            #         w_interfaces_RP+=","
            #     fi
            # done
            w_interfaces_RP=$(sep_array interfaces_RP ",")
            echo -e "$Tip 检测到活动的接口: $w_interfaces_RP"
            # echo "确认选择接口: $w_interfaces_RP"
            writeini "interfaces_RP" "$w_interfaces_RP"
        fi
    else
        if [ ! -z "${interfaces_RP+x}" ]; then
            interfaces_RP=("${interfaces_RP[@]}")
        else
            interfaces_RP=("${interfaces_RP_de[@]}")
        fi
        echo "interfaces_RP: $interfaces_RP"
    fi
    interfaces_RP=($(unique_array "${interfaces_RP[@]}")) # 去重处理
    show_interfaces_RP=$(sep_array interfaces_RP ",") # 加入分隔符
    if [ "$autorun" == "false" ]; then
        read -e -p "请选择统计模式: 1.接口合计发送  2.接口单独发送 (回车默认为单独发送): " mode
        if [ "$mode" == "1" ]; then
            StatisticsMode_RP="OV"
        elif [ "$mode" == "2" ]; then
            StatisticsMode_RP="SE"
        else
            StatisticsMode_RP=$StatisticsMode_RP_de
        fi
        writeini "StatisticsMode_RP" "$StatisticsMode_RP"
    else
        if [ ! -z "$StatisticsMode_RP" ]; then
            StatisticsMode_RP=$StatisticsMode_RP
        else
            StatisticsMode_RP=$StatisticsMode_RP_de
        fi
    fi
    echo "统计模式为: $StatisticsMode_RP"

    source $ConfigFile
    FlowThresholdMAX_UB=$FlowThresholdMAX
    FlowThresholdMAX_U=$(Remove_B "$FlowThresholdMAX_UB")
    if [[ $FlowThresholdMAX == *MB ]]; then
        FlowThresholdMAX=${FlowThresholdMAX%MB}
        FlowThresholdMAX=$(awk -v value=$FlowThresholdMAX 'BEGIN { printf "%.1f", value }')
    elif [[ $FlowThresholdMAX == *GB ]]; then
        FlowThresholdMAX=${FlowThresholdMAX%GB}
        FlowThresholdMAX=$(awk -v value=$FlowThresholdMAX 'BEGIN { printf "%.1f", value * 1024 }')
    elif [[ $FlowThresholdMAX == *TB ]]; then
        FlowThresholdMAX=${FlowThresholdMAX%TB}
        FlowThresholdMAX=$(awk -v value=$FlowThresholdMAX 'BEGIN { printf "%.1f", value * 1024 * 1024 }')
    fi
    cat <<EOF > "$FolderPath/tg_flrp.sh"
#!/bin/bash

$(declare -f create_progress_bar)
$(declare -f ratioandprogress)
progress=""
ratio=""
$(declare -f Bytes_B_TGMK)
$(declare -f TG_M_removeXB)
$(declare -f Remove_B)
$(declare -f Checkpara)

FolderPath="$FolderPath"
if [ ! -d "\$FolderPath" ]; then
    mkdir -p "\$FolderPath"
fi
ConfigFile="$ConfigFile"
source \$ConfigFile &>/dev/null
Checkpara "hostname_show" "$hostname_show"
Checkpara "ProxyURL" "$ProxyURL"
Checkpara "StatisticsMode_RP" "$StatisticsMode_RP"
Checkpara "SendUptime" "$SendUptime"
Checkpara "SendIP" "$SendIP"
Checkpara "GetIP46" "$GetIP46"
Checkpara "GetIPURL" "$GetIPURL"
Checkpara "SendPrice" "$SendPrice"
Checkpara "GetPriceType" "$GetPriceType"
Checkpara "FlowThreshold" "$FlowThreshold"
Checkpara "FlowThresholdMAX" "$FlowThresholdMAX"
Checkpara "interfaces_RP" "$interfaces_RP"

FlowThreshold_U=\$(Remove_B "\$FlowThreshold")
FlowThreshold=\$(TG_M_removeXB "\$FlowThreshold")
FlowThresholdMAX_U=\$(Remove_B "\$FlowThresholdMAX")
FlowThresholdMAX=\$(TG_M_removeXB "\$FlowThresholdMAX")

if [ "\$SendUptime" == "true" ]; then
    SendUptime="true"
else
    SendUptime="false"
fi
if [ "\$SendIP" == "true" ]; then
    SendIP="true"
else
    SendIP="false"
fi

THRESHOLD_BYTES_MAX=\$(awk "BEGIN {print \$FlowThresholdMAX * 1024 * 1024}")
THRESHOLD_BYTES_MAX=\$(printf "%.0f" \$THRESHOLD_BYTES_MAX)
echo "==================================================================="
echo "THRESHOLD_BYTES_MAX: \$THRESHOLD_BYTES_MAX"

interfaces=()
# interfaces=\$(ip -br link | awk '\$2 == "UP" {print \$1}' | grep -v "lo")
# interfaces_all=\$(ip -br link | awk '{print \$1}' | tr '\n' ' ')
# IFS=',' read -ra interfaces <<< "\$interfaces_RP"
# 去重并且分割字符串为数组
# IFS=',' read -ra interfaces <<< "\$(echo "\$interfaces_RP" | tr ',' '\n' | sort -u | tr '\n' ',')"
# 去重并且保持原有顺序，分割字符串为数组
# IFS=',' read -ra interfaces <<< "$(echo "$interfaces_RP" | awk -v RS=, '!a[$1]++ {if (NR>1) printf ",%s", $0; else printf "%s", $0}')"
IFS=',' read -ra interfaces <<< "\$(echo "\$interfaces_RP" | awk -v RS=, '!a[\$1]++ {if (NR>1) printf ",%s", \$0; else printf "%s", \$0}')"

echo "统计接口: \${interfaces[@]}"
for ((i = 0; i < \${#interfaces[@]}; i++)); do
    echo "\$((i+1)): \${interfaces[i]}"
done
for ((i = 0; i < \${#interfaces[@]}; i++)); do
    show_interfaces+="\${interfaces[\$i]}"
    if ((i < \${#interfaces[@]} - 1)); then
        show_interfaces+=","
    fi
done

# 如果接口名称中包含 '@' 或 ':'，则仅保留 '@' 或 ':' 之前的部分
for ((i=0; i<\${#interfaces[@]}; i++)); do
    interface=\${interfaces[\$i]%@*}
    interface=\${interface%:*}
    interfaces[\$i]=\$interface
done
echo "纺计接口(处理后): \${interfaces[@]}"

# 定义数组
declare -A prev_rx_bytes
declare -A prev_tx_bytes
declare -A tt_prev_rx_bytes_T
declare -A tt_prev_tx_bytes_T
declare -A prev_day_rx_bytes
declare -A prev_day_tx_bytes
declare -A prev_month_rx_bytes
declare -A prev_month_tx_bytes
declare -A prev_year_rx_bytes
declare -A prev_year_tx_bytes
declare -A current_rx_bytes
declare -A current_tx_bytes
declare -A INTERFACE_RT_RX_B
declare -A INTERFACE_RT_TX_B

source \$ConfigFile &>/dev/null
for interface in "\${interfaces[@]}"; do
    interface_nodot=\${interface//./_}
    INTERFACE_RT_RX_B[\$interface_nodot]=\${INTERFACE_RT_RX_B[\$interface_nodot]}
    echo "读取: INTERFACE_RT_RX_B[\$interface_nodot]: \${INTERFACE_RT_RX_B[\$interface_nodot]}"
    INTERFACE_RT_TX_B[\$interface_nodot]=\${INTERFACE_RT_TX_B[\$interface_nodot]}
    echo "读取: INTERFACE_RT_TX_B[\$interface_nodot]: \${INTERFACE_RT_TX_B[\$interface_nodot]}"
done

# test_hour="01"
# test_minute="47"

tt=60
duration=0
tt_prev=false
year_rp=false
month_rp=false
day_rp=false
day_sendtag=true
month_sendtag=true
year_sendtag=true

echo "runing..."
while true; do

    source \$ConfigFile &>/dev/null
    Checkpara "hostname_show" "$hostname_show"
    Checkpara "ProxyURL" "$ProxyURL"
    Checkpara "StatisticsMode_RP" "$StatisticsMode_RP"
    Checkpara "SendUptime" "$SendUptime"
    Checkpara "SendIP" "$SendIP"
    Checkpara "GetIP46" "$GetIP46"
    Checkpara "GetIPURL" "$GetIPURL"
    Checkpara "SendPrice" "$SendPrice"
    Checkpara "GetPriceType" "$GetPriceType"
    Checkpara "FlowThreshold" "$FlowThreshold"
    Checkpara "FlowThresholdMAX" "$FlowThresholdMAX"

    FlowThreshold_U=\$(Remove_B "\$FlowThreshold")
    FlowThreshold=\$(TG_M_removeXB "\$FlowThreshold")
    FlowThresholdMAX_U=\$(Remove_B "\$FlowThresholdMAX")
    FlowThresholdMAX=\$(TG_M_removeXB "\$FlowThresholdMAX")

    # 获取tt秒前数据
    ov_prev_rx_bytes=0
    ov_prev_tx_bytes=0
    for interface in "\${interfaces[@]}"; do
        interface_nodot=\${interface//./_}
        prev_rx_bytes[\$interface_nodot]=\$(ip -s link show \$interface | awk '/RX:/ { getline; print \$1 }')
        prev_tx_bytes[\$interface_nodot]=\$(ip -s link show \$interface | awk '/TX:/ { getline; print \$1 }')
        ov_prev_rx_bytes=\$((ov_prev_rx_bytes + prev_rx_bytes[\$interface_nodot]))
        ov_prev_tx_bytes=\$((ov_prev_tx_bytes + prev_tx_bytes[\$interface_nodot]))
    done

    if ! \$tt_prev; then
        if \$day_sendtag; then
            for interface in "\${interfaces[@]}"; do
                interface_nodot=\${interface//./_}
                echo "\$interface 发送前只执行一次 tt_prev_day_sendtag."
                prev_day_rx_bytes[\$interface_nodot]=\${prev_rx_bytes[\$interface_nodot]}
                prev_day_tx_bytes[\$interface_nodot]=\${prev_tx_bytes[\$interface_nodot]}
            done
            ov_prev_day_rx_bytes=\$ov_prev_rx_bytes
            ov_prev_day_tx_bytes=\$ov_prev_tx_bytes
        fi
        if \$month_sendtag; then
            for interface in "\${interfaces[@]}"; do
                interface_nodot=\${interface//./_}
                echo "\$interface 发送前只执行一次 tt_prev_month_sendtag."
                prev_month_rx_bytes[\$interface_nodot]=\${prev_rx_bytes[\$interface_nodot]}
                prev_month_tx_bytes[\$interface_nodot]=\${prev_tx_bytes[\$interface_nodot]}
            done
            ov_prev_month_rx_bytes=\$ov_prev_rx_bytes
            ov_prev_month_tx_bytes=\$ov_prev_tx_bytes
        fi
        if \$year_sendtag; then
            for interface in "\${interfaces[@]}"; do
                interface_nodot=\${interface//./_}
                echo "\$interface 发送前只执行一次 tt_prev_year_sendtag."
                prev_year_rx_bytes[\$interface_nodot]=\${prev_rx_bytes[\$interface_nodot]}
                prev_year_tx_bytes[\$interface_nodot]=\${prev_tx_bytes[\$interface_nodot]}
            done
            ov_prev_year_rx_bytes=\$ov_prev_rx_bytes
            ov_prev_year_tx_bytes=\$ov_prev_tx_bytes
        fi
    else
        if \$day_sendtag; then
            for interface in "\${interfaces[@]}"; do
                interface_nodot=\${interface//./_}
                echo "\$interface 发送前只执行一次 day_sendtag."
                prev_day_rx_bytes[\$interface_nodot]=\${tt_prev_rx_bytes_T[\$interface_nodot]}
                prev_day_tx_bytes[\$interface_nodot]=\${tt_prev_tx_bytes_T[\$interface_nodot]}
            done
            ov_prev_day_rx_bytes=\$tt_ov_prev_rx_bytes_T
            ov_prev_day_tx_bytes=\$tt_ov_prev_tx_bytes_T
        fi
        if \$month_sendtag; then
            for interface in "\${interfaces[@]}"; do
                interface_nodot=\${interface//./_}
                echo "\$interface 发送前只执行一次 month_sendtag."
                prev_month_rx_bytes[\$interface_nodot]=\${tt_prev_rx_bytes_T[\$interface_nodot]}
                prev_month_tx_bytes[\$interface_nodot]=\${tt_prev_tx_bytes_T[\$interface_nodot]}
            done
            ov_prev_month_rx_bytes=\$tt_ov_prev_rx_bytes_T
            ov_prev_month_tx_bytes=\$tt_ov_prev_tx_bytes_T
        fi
        if \$year_sendtag; then
            for interface in "\${interfaces[@]}"; do
                interface_nodot=\${interface//./_}
                echo "\$interface 发送前只执行一次 year_sendtag."
                prev_year_rx_bytes[\$interface_nodot]=\${tt_prev_rx_bytes_T[\$interface_nodot]}
                prev_year_tx_bytes[\$interface_nodot]=\${tt_prev_tx_bytes_T[\$interface_nodot]}
            done
            ov_prev_year_rx_bytes=\$tt_ov_prev_rx_bytes_T
            ov_prev_year_tx_bytes=\$tt_ov_prev_tx_bytes_T
        fi
    fi
    day_sendtag=false
    month_sendtag=false
    year_sendtag=false

    # 等待tt秒
    end_time=\$(date +%s%N)
    if [ ! -z "\$start_time" ]; then
        time_diff=\$((end_time - start_time))
        time_diff_ms=\$((time_diff / 1000000))

        # 输出执行FOR所花费时间
        echo "上一个 FOR循环 所执行时间 \$time_diff_ms 毫秒."

        duration=\$(awk "BEGIN {print \$time_diff_ms/1000}")
        sleep_time=\$(awk -v v1=\$tt -v v2=\$duration 'BEGIN { printf "%.3f", v1 - v2 }')
    else
        sleep_time=\$tt
    fi
    sleep_time=\$(awk "BEGIN {print (\$sleep_time < 0 ? 0 : \$sleep_time)}")
    echo "sleep_time: \$sleep_time   duration: \$duration"
    sleep \$sleep_time
    start_time=\$(date +%s%N)

    # 获取tt秒后数据
    ov_current_rx_bytes=0
    ov_current_tx_bytes=0
    for interface in "\${interfaces[@]}"; do
        interface_nodot=\${interface//./_}
        current_rx_bytes[\$interface_nodot]=\$(ip -s link show \$interface | awk '/RX:/ { getline; print \$1 }')
        current_tx_bytes[\$interface_nodot]=\$(ip -s link show \$interface | awk '/TX:/ { getline; print \$1 }')
        ov_current_rx_bytes=\$((ov_current_rx_bytes + current_rx_bytes[\$interface_nodot]))
        ov_current_tx_bytes=\$((ov_current_tx_bytes + current_tx_bytes[\$interface_nodot]))
    done

    for interface in "\${interfaces[@]}"; do
        interface_nodot=\${interface//./_}
        tt_prev_rx_bytes_T[\$interface_nodot]=\${current_rx_bytes[\$interface_nodot]}
        tt_prev_tx_bytes_T[\$interface_nodot]=\${current_tx_bytes[\$interface_nodot]}
    done
    tt_ov_prev_rx_bytes_T=\$ov_current_rx_bytes
    tt_ov_prev_tx_bytes_T=\$ov_current_tx_bytes
    tt_prev=true

    nline=1
    # 获取当前时间的小时和分钟
    current_year=\$(date +"%Y")
    current_month=\$(date +"%m")
    current_day=\$(date +"%d")
    current_hour=\$(date +"%H")
    current_minute=\$(date +"%M")
    # tail_day=\$(date -d "\$(date +'%Y-%m-01 next month') -1 day" +%d)

    for interface in "\${interfaces[@]}"; do
        interface_nodot=\${interface//./_}
        echo "NO.\$nline --------------------------------------rp--- interface: \$interface"

        all_rx_bytes=\$ov_current_rx_bytes
        all_rx_bytes=\$((all_rx_bytes + INTERFACE_RT_RX_B[\$interface_nodot]))
        all_rx_ratio=\$(awk -v used="\$all_rx_bytes" -v total="\$THRESHOLD_BYTES_MAX" 'BEGIN { printf "%.3f", ( used / total ) * 100 }')

        ratioandprogress "0" "0" "\$all_rx_ratio"
        all_rx_progress=\$progress
        all_rx_ratio=\$ratio

        all_rx=\$(Bytes_B_TGMK "\$all_rx_bytes")
        all_rx=\$(Remove_B "\$all_rx")

        all_tx_bytes=\$ov_current_tx_bytes
        all_tx_bytes=\$((all_tx_bytes + INTERFACE_RT_TX_B[\$interface_nodot]))
        all_tx_ratio=\$(awk -v used="\$all_tx_bytes" -v total="\$THRESHOLD_BYTES_MAX" 'BEGIN { printf "%.3f", ( used / total ) * 100 }')

        ratioandprogress "0" "0" "\$all_tx_ratio"
        all_tx_progress=\$progress
        all_tx_ratio=\$ratio

        all_tx=\$(Bytes_B_TGMK "\$all_tx_bytes")
        all_tx=\$(Remove_B "\$all_tx")

        # 日报告 #################################################################################################################
        if [ "\$current_hour" == "00" ] && [ "\$current_minute" == "00" ]; then
            diff_day_rx_bytes=\$(( current_rx_bytes[\$interface_nodot] - prev_day_rx_bytes[\$interface_nodot] ))
            diff_day_tx_bytes=\$(( current_tx_bytes[\$interface_nodot] - prev_day_tx_bytes[\$interface_nodot] ))
            diff_rx_day=\$(Bytes_B_TGMK "\$diff_day_rx_bytes")
            diff_tx_day=\$(Bytes_B_TGMK "\$diff_day_tx_bytes")

            if [ "\$StatisticsMode_RP" == "OV" ]; then
                ov_diff_day_rx_bytes=\$(( ov_current_rx_bytes - ov_prev_day_rx_bytes ))
                ov_diff_day_tx_bytes=\$(( ov_current_tx_bytes - ov_prev_day_tx_bytes ))
                ov_diff_rx_day=\$(Bytes_B_TGMK "\$ov_diff_day_rx_bytes")
                ov_diff_tx_day=\$(Bytes_B_TGMK "\$ov_diff_day_tx_bytes")
            fi
            # 月报告
            if [ "\$current_day" == "01" ]; then
                diff_month_rx_bytes=\$(( current_rx_bytes[\$interface_nodot] - prev_month_rx_bytes[\$interface_nodot] ))
                diff_month_tx_bytes=\$(( current_tx_bytes[\$interface_nodot] - prev_month_tx_bytes[\$interface_nodot] ))
                diff_rx_month=\$(Bytes_B_TGMK "\$diff_month_rx_bytes")
                diff_tx_month=\$(Bytes_B_TGMK "\$diff_month_tx_bytes")

                if [ "\$StatisticsMode_RP" == "OV" ]; then
                    ov_diff_month_rx_bytes=\$(( ov_current_rx_bytes - ov_prev_month_rx_bytes ))
                    ov_diff_month_tx_bytes=\$(( ov_current_tx_bytes - ov_prev_month_tx_bytes ))
                    ov_diff_rx_month=\$(Bytes_B_TGMK "\$ov_diff_month_rx_bytes")
                    ov_diff_tx_month=\$(Bytes_B_TGMK "\$ov_diff_month_tx_bytes")
                fi
                # 年报告
                if [ "\$current_month" == "01" ] && [ "\$current_day" == "01" ]; then
                    diff_year_rx_bytes=\$(( current_rx_bytes[\$interface_nodot] - prev_year_rx_bytes[\$interface_nodot] ))
                    diff_year_tx_bytes=\$(( current_tx_bytes[\$interface_nodot] - prev_year_tx_bytes[\$interface_nodot] ))
                    diff_rx_year=\$(Bytes_B_TGMK "\$diff_year_rx_bytes")
                    diff_tx_year=\$(Bytes_B_TGMK "\$diff_year_tx_bytes")

                    if [ "\$StatisticsMode_RP" == "OV" ]; then
                        ov_diff_year_rx_bytes=\$(( ov_current_rx_bytes - ov_prev_year_rx_bytes ))
                        ov_diff_year_tx_bytes=\$(( ov_current_tx_bytes - ov_prev_year_tx_bytes ))
                        ov_diff_rx_year=\$(Bytes_B_TGMK "\$ov_diff_year_rx_bytes")
                        ov_diff_tx_year=\$(Bytes_B_TGMK "\$ov_diff_year_tx_bytes")
                    fi
                    year_rp=true
                fi
                month_rp=true
            fi
            day_rp=true
        fi

        # SE发送报告
        if [ "\$StatisticsMode_RP" == "SE" ]; then
            if [ "\$current_hour" == "$hour_rp" ] && [ "\$current_minute" == "$minute_rp" ]; then

                current_date_send=\$(date +"%Y.%m.%d %T")

                # 获取uptime输出
                if \$SendUptime; then
                    # read uptime idle_time < /proc/uptime
                    # uptime=\${uptime%.*}
                    # days=\$((uptime/86400))
                    # hours=\$(( (uptime%86400)/3600 ))
                    # minutes=\$(( (uptime%3600)/60 ))
                    # seconds=\$((uptime%60))
                    read uptime idle_time < /proc/uptime
                    uptime=\${uptime%.*}
                    days=\$(awk -v up="\$uptime" 'BEGIN{print int(up/86400)}')
                    hours=\$(awk -v up="\$uptime" 'BEGIN{print int((up%86400)/3600)}')
                    minutes=\$(awk -v up="\$uptime" 'BEGIN{print int((up%3600)/60)}')
                    seconds=\$(awk -v up="\$uptime" 'BEGIN{print int(up%60)}')
                    uptimeshow="系统已运行: \$days 日 \$hours 时 \$minutes 分 \$seconds 秒"
                else
                    uptimeshow=""
                fi
                echo "uptimeshow: \$uptimeshow"
                # 获取IP输出
                if \$SendIP; then
                    # lanIP=\$(ip a | grep -E "inet.*brd" | awk '{print \$2}' | awk -F '/' '{print \$1}' | tr '\n' ' ')
                    wanIP=\$(curl -s -"\$GetIP46" "\$GetIPURL")
                    wanIPshow="网络IP地址: \$wanIP"
                else
                    wanIPshow=""
                fi

                if \$day_rp; then

                    # if cat /proc/version 2>/dev/null | grep -q -E -i "openwrt"; then
                        current_timestamp=\$(date +%s)
                        one_day_seconds=\$((24 * 60 * 60))
                        yesterday_timestamp=\$((current_timestamp - one_day_seconds))
                        yesterday_date=\$(date -d "@\$yesterday_timestamp" +'%m月%d日')
                        yesterday="\$yesterday_date"

                        # current_month=\$(date +'%m')
                        # current_day=\$(date +'%d')
                        # yesterday_day=\$((current_day - 1))
                        # yesterday_month=\$current_month
                        # if [ \$yesterday_day -eq 0 ]; then
                        #     yesterday_month=\$((current_month - 1))
                        #     if [ \$yesterday_month -eq 0 ]; then
                        #         yesterday_month=12
                        #     fi
                        #     yesterday_day=\$(date -d "1-\${yesterday_month}-01 -1 day" +'%d')
                        # fi
                        # yesterday="\${yesterday_month}-\${yesterday_day}"

                    # else
                    #     yesterday=\$(date -d "1 day ago" +%m月%d日)
                    # fi

                    diff_rx_day=\$(Remove_B "\$diff_rx_day")
                    diff_tx_day=\$(Remove_B "\$diff_tx_day")

                    message="\${yesterday}🌞流量报告 📈"$'\n'
                    message+="主机名: \$hostname_show 接口: \$interface"$'\n'
                    message+="🌞接收: \${diff_rx_day}  🌞发送: \${diff_tx_day}"$'\n'
                    message+="───────────────"$'\n'
                    message+="总接收: \${all_rx}  总发送: \${all_tx}"$'\n'
                    message+="设置流量上限: \${FlowThresholdMAX_U}🔒"$'\n'
                    message+="使用⬇️: \$all_rx_progress \$all_rx_ratio"$'\n'
                    message+="使用⬆️: \$all_tx_progress \$all_tx_ratio"$'\n'
                    if [[ -n "\$uptimeshow" ]]; then
                        message+="\$uptimeshow"$'\n'
                    fi
                    if [[ -n "\$wanIPshow" ]]; then
                        message+="\$wanIPshow"$'\n'
                    fi
                    message+="服务器时间: \$current_date_send"

                    \$FolderPath/send_tg.sh "\$TelgramBotToken" "\$ChatID_1" "\$message"
                    echo "报告信息已发出..."
                    echo "时间: \$current_date, 活动接口: \$interface, 日接收: \$diff_rx_day, 日发送: \$diff_tx_day"
                    echo "----------------------------------------------------------------"
                    day_rp=false
                    day_sendtag=true
                fi

                if \$month_rp; then

                    sleep 15 # 当有多台VPS时,避免与日报告同时发送造成信息混乱

                    # if cat /proc/version 2>/dev/null | grep -q -E -i "openwrt"; then
                        current_year=\$(date +'%Y')
                        current_month=\$(date +'%m')
                        previous_month=\$((current_month - 1))
                        if [ "\$previous_month" -eq 0 ]; then
                            previous_month=12
                            current_year=\$((current_year - 1))
                        fi
                        last_month="\${current_year}年\${previous_month}月份"
                    # else
                    #     last_month=\$(date -d "1 month ago" +%Y年%m月份)
                    # fi

                    diff_rx_month=\$(Remove_B "\$diff_rx_month")
                    diff_tx_month=\$(Remove_B "\$diff_tx_month")

                    message="\${last_month}🌙总流量报告 📈"$'\n'
                    message+="主机名: \$hostname_show 接口: \$interface"$'\n'
                    message+="🌙接收: \${diff_rx_month}  🌙发送: \${diff_tx_month}"$'\n'
                    message+="───────────────"$'\n'
                    message+="总接收: \${all_rx}  总发送: \${all_tx}"$'\n'
                    message+="设置流量上限: \${FlowThresholdMAX_U}🔒"$'\n'
                    message+="使用⬇️: \$all_rx_progress \$all_rx_ratio"$'\n'
                    message+="使用⬆️: \$all_tx_progress \$all_tx_ratio"$'\n'
                    if [[ -n "\$uptimeshow" ]]; then
                        message+="\$uptimeshow"$'\n'
                    fi
                    if [[ -n "\$wanIPshow" ]]; then
                        message+="\$wanIPshow"$'\n'
                    fi
                    message+="服务器时间: \$current_date_send"

                    \$FolderPath/send_tg.sh "\$TelgramBotToken" "\$ChatID_1" "\$message"
                    echo "报告信息已发出..."
                    echo "时间: \$current_date, 活动接口: \$interface, 月接收: \$diff_rx_day, 月发送: \$diff_tx_day"
                    echo "----------------------------------------------------------------"
                    month_rp=false
                    month_sendtag=true
                fi

                if \$year_rp; then

                    sleep 15

                    # if cat /proc/version 2>/dev/null | grep -q -E -i "openwrt"; then
                        current_year=\$(date +'%Y')
                        previous_year=\$((current_year - 1))
                        last_year="\$previous_year"
                    # else
                    #     last_year=\$(date -d "1 year ago" +%Y)
                    # fi

                    diff_rx_year=\$(Remove_B "\$diff_rx_year")
                    diff_tx_year=\$(Remove_B "\$diff_tx_year")

                    message="\${last_year}年🧧总流量报告 📈"$'\n'
                    message+="主机名: \$hostname_show 接口: \$interface"$'\n'
                    message+="🧧接收: \${diff_rx_year}  🧧发送: \${diff_tx_year}"$'\n'
                    message+="───────────────"$'\n'
                    message+="总接收: \${all_rx}  总发送: \${all_tx}"$'\n'
                    message+="设置流量上限: \${FlowThresholdMAX_U}🔒"$'\n'
                    message+="使用⬇️: \$all_rx_progress \$all_rx_ratio"$'\n'
                    message+="使用⬆️: \$all_tx_progress \$all_tx_ratio"$'\n'
                    if [[ -n "\$uptimeshow" ]]; then
                        message+="\$uptimeshow"$'\n'
                    fi
                    if [[ -n "\$wanIPshow" ]]; then
                        message+="\$wanIPshow"$'\n'
                    fi
                    message+="服务器时间: \$current_date_send"

                    \$FolderPath/send_tg.sh "\$TelgramBotToken" "\$ChatID_1" "\$message"
                    echo "报告信息已发出..."
                    echo "年报告信息:"
                    echo "时间: \$current_date, 活动接口: \$interface, 年接收: \$diff_rx_year, 年发送: \$diff_tx_year"
                    echo "----------------------------------------------------------------"
                    year_rp=false
                    year_sendtag=true
                fi
            fi
        fi
    nline=\$((nline + 1))
    done

    # OV发送报告
    if [ "\$StatisticsMode_RP" == "OV" ]; then
        if [ "\$current_hour" == "$hour_rp" ] && [ "\$current_minute" == "$minute_rp" ]; then

            current_date_send=\$(date +"%Y.%m.%d %T")

            # 获取uptime输出
            if \$SendUptime; then
                # read uptime idle_time < /proc/uptime
                # uptime=\${uptime%.*}
                # days=\$((uptime/86400))
                # hours=\$(( (uptime%86400)/3600 ))
                # minutes=\$(( (uptime%3600)/60 ))
                # seconds=\$((uptime%60))
                read uptime idle_time < /proc/uptime
                uptime=\${uptime%.*}
                days=\$(awk -v up="\$uptime" 'BEGIN{print int(up/86400)}')
                hours=\$(awk -v up="\$uptime" 'BEGIN{print int((up%86400)/3600)}')
                minutes=\$(awk -v up="\$uptime" 'BEGIN{print int((up%3600)/60)}')
                seconds=\$(awk -v up="\$uptime" 'BEGIN{print int(up%60)}')
                uptimeshow="系统已运行: \$days 日 \$hours 时 \$minutes 分 \$seconds 秒"
            else
                uptimeshow=""
            fi
            echo "uptimeshow: \$uptimeshow"
            # 获取IP输出
            if \$SendIP; then
                # lanIP=\$(ip a | grep -E "inet.*brd" | awk '{print \$2}' | awk -F '/' '{print \$1}' | tr '\n' ' ')
                wanIP=\$(curl -s -"\$GetIP46" "\$GetIPURL")
                wanIPshow="网络IP地址: \$wanIP"
            else
                wanIPshow=""
            fi

            if \$day_rp; then

                # if cat /proc/version 2>/dev/null | grep -q -E -i "openwrt"; then
                    current_timestamp=\$(date +%s)
                    one_day_seconds=\$((24 * 60 * 60))
                    yesterday_timestamp=\$((current_timestamp - one_day_seconds))
                    yesterday_date=\$(date -d "@\$yesterday_timestamp" +'%m月%d日')
                    yesterday="\$yesterday_date"

                    # current_month=\$(date +'%m')
                    # current_day=\$(date +'%d')
                    # yesterday_day=\$((current_day - 1))
                    # yesterday_month=\$current_month
                    # if [ \$yesterday_day -eq 0 ]; then
                    #     yesterday_month=\$((current_month - 1))
                    #     if [ \$yesterday_month -eq 0 ]; then
                    #         yesterday_month=12
                    #     fi
                    #     yesterday_day=\$(date -d "1-\${yesterday_month}-01 -1 day" +'%d')
                    # fi
                    # yesterday="\${yesterday_month}-\${yesterday_day}"

                # else
                #     yesterday=\$(date -d "1 day ago" +%m月%d日)
                # fi

                ov_diff_rx_day=\$(Remove_B "\$ov_diff_rx_day")
                ov_diff_tx_day=\$(Remove_B "\$ov_diff_tx_day")

                message="\${yesterday}🌞流量报告 📈"$'\n'
                message+="主机名: \$hostname_show 接口: \$show_interfaces"$'\n'
                message+="🌞接收: \${ov_diff_rx_day}  🌞发送: \${ov_diff_tx_day}"$'\n'
                message+="───────────────"$'\n'
                message+="总接收: \${all_rx}  总发送: \${all_tx}"$'\n'
                message+="设置流量上限: \${FlowThresholdMAX_U}🔒"$'\n'
                message+="使用⬇️: \$all_rx_progress \$all_rx_ratio"$'\n'
                message+="使用⬆️: \$all_tx_progress \$all_tx_ratio"$'\n'
                if [[ -n "\$uptimeshow" ]]; then
                    message+="\$uptimeshow"$'\n'
                fi
                if [[ -n "\$wanIPshow" ]]; then
                    message+="\$wanIPshow"$'\n'
                fi
                message+="服务器时间: \$current_date_send"

                \$FolderPath/send_tg.sh "\$TelgramBotToken" "\$ChatID_1" "\$message"
                echo "报告信息已发出..."
                echo "时间: \$current_date, 活动接口: \$interface, 日接收: \$diff_rx_day, 日发送: \$diff_tx_day"
                echo "----------------------------------------------------------------"
                day_rp=false
                day_sendtag=true
            fi

            if \$month_rp; then

                sleep 15

                # if cat /proc/version 2>/dev/null | grep -q -E -i "openwrt"; then
                    current_year=\$(date +'%Y')
                    current_month=\$(date +'%m')
                    previous_month=\$((current_month - 1))
                    if [ "\$previous_month" -eq 0 ]; then
                        previous_month=12
                        current_year=\$((current_year - 1))
                    fi
                    last_month="\${current_year}年\${previous_month}月份"
                # else
                #     last_month=\$(date -d "1 month ago" +%Y年%m月份)
                # fi

                ov_diff_rx_month=\$(Remove_B "\$ov_diff_rx_month")
                ov_diff_tx_month=\$(Remove_B "\$ov_diff_tx_month")

                message="\${last_month}🌙总流量报告 📈"$'\n'
                message+="主机名: \$hostname_show 接口: \$show_interfaces"$'\n'
                message+="🌙接收: \${ov_diff_rx_month}  🌙发送: \${ov_diff_tx_month}"$'\n'
                message+="───────────────"$'\n'
                message+="总接收: \${all_rx}  总发送: \${all_tx}"$'\n'
                message+="设置流量上限: \${FlowThresholdMAX_U}🔒"$'\n'
                message+="使用⬇️: \$all_rx_progress \$all_rx_ratio"$'\n'
                message+="使用⬆️: \$all_tx_progress \$all_tx_ratio"$'\n'
                if [[ -n "\$uptimeshow" ]]; then
                    message+="\$uptimeshow"$'\n'
                fi
                if [[ -n "\$wanIPshow" ]]; then
                    message+="\$wanIPshow"$'\n'
                fi
                message+="服务器时间: \$current_date_send"

                \$FolderPath/send_tg.sh "\$TelgramBotToken" "\$ChatID_1" "\$message"
                echo "报告信息已发出..."
                echo "时间: \$current_date, 活动接口: \$interface, 月接收: \$diff_rx_day, 月发送: \$diff_tx_day"
                echo "----------------------------------------------------------------"
                month_rp=false
                month_sendtag=true
            fi

            if \$year_rp; then

                sleep 15

                # if cat /proc/version 2>/dev/null | grep -q -E -i "openwrt"; then
                    current_year=\$(date +'%Y')
                    previous_year=\$((current_year - 1))
                    last_year="\$previous_year"
                # else
                #     last_year=\$(date -d "1 year ago" +%Y)
                # fi

                ov_diff_rx_year=\$(Remove_B "\$ov_diff_rx_year")
                ov_diff_tx_year=\$(Remove_B "\$ov_diff_tx_year")

                message="\${last_year}年🧧总流量报告 📈"$'\n'
                message+="主机名: \$hostname_show 接口: \$show_interfaces"$'\n'
                message+="🧧接收: \${ov_diff_rx_year}  🧧发送: \${ov_diff_tx_year}"$'\n'
                message+="───────────────"$'\n'
                message+="总接收: \${all_rx}  总发送: \${all_tx}"$'\n'
                message+="设置流量上限: \${FlowThresholdMAX_U}🔒"$'\n'
                message+="使用⬇️: \$all_rx_progress \$all_rx_ratio"$'\n'
                message+="使用⬆️: \$all_tx_progress \$all_tx_ratio"$'\n'
                if [[ -n "\$uptimeshow" ]]; then
                    message+="\$uptimeshow"$'\n'
                fi
                if [[ -n "\$wanIPshow" ]]; then
                    message+="\$wanIPshow"$'\n'
                fi
                message+="服务器时间: \$current_date_send"

                \$FolderPath/send_tg.sh "\$TelgramBotToken" "\$ChatID_1" "\$message"
                echo "报告信息已发出..."
                echo "年报告信息:"
                echo "时间: \$current_date, 活动接口: \$interface, 年接收: \$diff_rx_year, 年发送: \$diff_tx_year"
                echo "----------------------------------------------------------------"
                year_rp=false
                year_sendtag=true
            fi
        fi
    fi
    for interface in "\${interfaces[@]}"; do
        interface_nodot=\${interface//./_}
        echo "prev_day_rx_bytes[\$interface_nodot]: \${prev_day_rx_bytes[\$interface_nodot]}"
        echo "prev_day_tx_bytes[\$interface_nodot]: \${prev_day_tx_bytes[\$interface_nodot]}"
    done
    echo "活动接口: \$show_interfaces  接收总流量: \$all_rx_mb 发送总流量: \$all_tx_mb"
    echo "活动接口: \$show_interfaces  接收日流量: \$diff_rx_day  发送日流量: \$diff_tx_day 报告时间: $hour_rp 时 $minute_rp 分"
    echo "活动接口: \$show_interfaces  接收月流量: \$diff_rx_month  发送月流量: \$diff_tx_month 报告时间: $hour_rp 时 $minute_rp 分"
    echo "活动接口: \$show_interfaces  接收年流量: \$diff_rx_year  发送年流量: \$diff_tx_year 报告时间: $hour_rp 时 $minute_rp 分"
    echo "报告模式: \$StatisticsMode_RP"
    echo "当前时间: \$(date)"
    echo "------------------------------------------------------"
done
EOF
    chmod +x $FolderPath/tg_flrp.sh
    killpid "tg_flrp.sh"
    nohup $FolderPath/tg_flrp.sh > $FolderPath/tg_flrp.log 2>&1 &
    delcrontab "$FolderPath/tg_flrp.sh"
    addcrontab "@reboot nohup $FolderPath/tg_flrp.sh > $FolderPath/tg_flrp.log 2>&1 &"
    if [ "$mute" == "false" ]; then
        send_time=$(echo $(date +%s%N) | cut -c 16-)
        message="流量定时报告设置成功 ⚙️"$'\n'"主机名: $hostname_show"$'\n'"报告接口: $show_interfaces_RP"$'\n'"报告模式: $StatisticsMode_RP"$'\n'"报告时间: 每天 $hour_rp 时 $minute_rp 分📈"
        $FolderPath/send_tg.sh "$TelgramBotToken" "$ChatID_1" "$message" "flrp" "$send_time" &
        (sleep 15 && $FolderPath/del_lm_tg.sh "$TelgramBotToken" "$ChatID_1" "flrp" "$send_time") &
        sleep 1
        # getpid "send_tg.sh"
        # flrp_pid="$tg_pid"
        flrp_pid=$(getpid "send_tg.sh")
    fi
    tips="$Tip 流量定时报告设置成功, 报告时间: 每天 $hour_rp 时 $minute_rp 分 ($input_time)"
}

SetupDDNS_TG() {
    if [ ! -z "$ddns_pid" ] && pgrep -a '' | grep -Eq "^\s*$ddns_pid\s" > /dev/null; then
        tips="$Err PID(${GR}$ddns_pid${NC}) 正在发送中,请稍后..."
        return 1
    fi
    if [[ -z "${TelgramBotToken}" || -z "${ChatID_1}" ]]; then
        tips="$Err 参数丢失, 请设置后再执行 (先执行 ${GR}0${NC} 选项)."
        return 1
    fi
    # if [ "$autorun" == "false" ]; then
    echo -en "请输入 DDNS 的 IP 格式: ${GR}4.${NC}IPv4 ${GR}6.${NC}IPv6 : "
    read -er input_iptype
    if [ "$input_iptype" == "4" ]; then
        CFDDNS_IP_TYPE="A"
    elif [ "$input_iptype" == "6" ]; then
        CFDDNS_IP_TYPE="AAAA"
    else
        echo
        tips="$Err 输入有误, 取消操作."
        return 1
    fi
    echo -en "请输入 CF 帐号名 (邮箱) : "
    read -er input_email
    email_regex="^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$"
    if [ -z "$input_email" ] || [[ ! $input_email =~ $email_regex ]]; then
        echo
        tips="$Err 输入有误, 取消操作."
        return 1
    else
        CFDDNS_EMAIL=$input_email
    fi
    echo -en "请输入 CF Global API Key : "
    read -er input_apikey
    if [ -z "$input_apikey" ]; then
        echo
        tips="$Err 输入有误, 取消操作."
        return 1
    else
        CFDDNS_APIKEY=$input_apikey
    fi
    echo -en "请输入 CF Zone ID : "
    read -er input_zoneid
    if [ -z "$input_zoneid" ]; then
        echo
        tips="$Err 输入有误, 取消操作."
        return 1
    else
        CFDDNS_ZID=$input_zoneid
    fi
    echo -e "请输入 DDNS 完整域名 (含前缀)"
    echo -en "( 如: abc.xxx.eu.org ) : "
    read -er input_domain
    if [ -z "$input_domain" ]; then
        echo
        tips="$Err 输入有误, 取消操作."
        return 1
    else
        CFDDNS_DOMAIN_P="${input_domain%%.*}"
        CFDDNS_DOMAIN_S="${input_domain#*.}"
    fi
    echo -e "模式: ${GR}1.${NC}当自身IP发生变化时 ${GR}2.${NC}当与域名IP对比不匹配时"
    echo -en "请选择 DDNS 模式 ( 回车默认 1 ) : "
    read -er input_choice
    if [ "$input_choice" == "1" ] || [ -z "$input_choice" ]; then
        CFDDNS_MODE="1"
    elif [ "$input_choice" == "2" ]; then
        CFDDNS_MODE="2"
    else
        echo
        tips="$Err 输入有误, 取消操作."
        return 1
    fi

    echo -e "当 DDNS 进程无故被中止时, DDNS 守护将会为你打开进程, 以确保 DDNS 持续运行."
    echo -e "是否开启 DDNS 守护? ${GR}Y.${NC}开启 ${GR}N.${NC}不开启"
    echo -en "请选择 DDNS 模式 ( 回车默认 ${GR}开启${NC} ) : "
    read -er keeper_choice
    if [ "$keeper_choice" == "y" ] || [ "$keeper_choice" == "Y" ] || [ -z "$keeper_choice" ]; then
        CFDDNS_KEEPER="true"
    elif [ "$keeper_choice" == "n" ] || [ "$keeper_choice" == "N" ]; then
        CFDDNS_KEEPER="false"
    else
        echo
        tips="$Err 输入有误, 取消操作."
        return 1
    fi


    cat <<EOF > "$FolderPath/tg_ddns.sh"
#!/bin/bash

#################################################################### Cloudflare账户信息
email="$CFDDNS_EMAIL" # 帐号邮箱
api_key="$CFDDNS_APIKEY" # 主页获取
zone_id="$CFDDNS_ZID" # 主页获取
domain="$CFDDNS_DOMAIN_S" # 域名
record_name="$CFDDNS_DOMAIN_P" # 自定义前缀
iptype="$CFDDNS_IP_TYPE" # 动态解析IP类型: A为IPV4, AAAA为IPV6
ddns_mode="$CFDDNS_MODE"
ttls="1" # TTL: 1为自动, 60为1分钟, 120为2分钟
proxysw="false" # 是否开启小云朵(CF代理)( true 或 false )
####################################################################

$(declare -f Checkpara)

FolderPath="$FolderPath"
if [ ! -d "\$FolderPath" ]; then
    mkdir -p "\$FolderPath"
fi
ConfigFile="$ConfigFile"
source \$ConfigFile &>/dev/null
Checkpara "hostname_show" "$hostname_show"

action() {
    local iptype_lo="\${1}"
    local ipaddress="\${2}"

    attempts=1 # 尝试次数标记
    max_attempts=5 # 最多获取次数(可自定义)
    record_id="" # 无需更改

    while [ \$attempts -le \$max_attempts ]; do
        response=\$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/\${zone_id}/dns_records?type=\${iptype}&name=\${record_name}.\${domain}" \
            -H "X-Auth-Email: \${email}" \
            -H "X-Auth-Key: \${api_key}" \
            -H "Content-Type: application/json")
        echo "获取DNS记录API响应: \$response"

        record_id=\$(echo "\$response" | awk -F'"' '/id/{print \$6; exit}')

        if [ -z "\$record_id" ]; then
            echo "第 \$attempts 次获取DNS记录ID失败。"
            if [ \$attempts -eq \$max_attempts ]; then
                echo "获取DNS记录ID失败，请检查输入的信息是否正确。"
                get_record_id="获取DNS记录ID失败!"
                # get_record_id_tag="geterr"
                return 1
            else
                attempts=\$((attempts+1))
            fi
            sleep 1
        else
            echo "成功获取DNS记录ID: \$record_id"
            get_record_id=""
            break
        fi
    done
    update_response=\$(curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/\${zone_id}/dns_records/\${record_id}" \
        -H "X-Auth-Email: \${email}" \
        -H "X-Auth-Key: \${api_key}" \
        -H "Content-Type: application/json" \
        --data '{"type":"'\${iptype_lo}'","name":"'\${record_name}'","content":"'\${ipaddress}'","ttl":'\${ttls}',"proxied":'\${proxysw}'}')

    echo "更新DNS记录API响应: \$update_response"
    if [[ "\$update_response" == *"success\":true"* ]]; then
        echo "DNS记录更新成功。"
        date
    else
        echo "DNS记录更新失败，请检查输入的信息是否正确。"
        date
    fi
}
if [ "\${1}" == "re" ]; then
    revive="true"
else
    revive="false"
    URL_regex="^(http|https)://[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}(/*)?$"
    if [[ "\${1}" =~ "\$URL_regex" ]]; then
        customizeURL="\${1}"
        echo "自定URL\${1}: \$customizeURL"
    fi
fi
getipurl4=('ip.sb' 'ip.gs' 'ifconfig.io' 'ipinfo.io/ip' 'ifconfig.me' 'icanhazip.com' 'ipecho.net/plain')
getipurl42=('ip.sb' 'ip.gs' 'ifconfig.io' 'ipinfo.io/ip' 'ifconfig.me' 'icanhazip.com' 'ipecho.net/plain')
getipurl6=('ip.sb' 'ip.gs' 'ifconfig.io' 'ifconfig.me' 'ipecho.net/plain' 'ipv6.icanhazip.com')
echo "获取 IPv4 URL: \${getipurl4[@]} \${getipurl42[@]}"
echo "获取 IPv6 URL: \${getipurl6[@]}"
ipv4_regex="^([0-9]{1,3}\.){3}[0-9]{1,3}$"
ipv6_regex="^(
    ([0-9a-fA-F]{1,4}:){7,7}[0-9a-fA-F]{1,4}|
    ([0-9a-fA-F]{1,4}:){1,7}:|
    ([0-9a-fA-F]{1,4}:){1,6}:[0-9a-fA-F]{1,4}|
    ([0-9a-fA-F]{1,4}:){1,5}(:[0-9a-fA-F]{1,4}){1,2}|
    ([0-9a-fA-F]{1,4}:){1,4}(:[0-9a-fA-F]{1,4}){1,3}|
    ([0-9a-fA-F]{1,4}:){1,3}(:[0-9a-fA-F]{1,4}){1,4}|
    ([0-9a-fA-F]{1,4}:){1,2}(:[0-9a-fA-F]{1,4}){1,5}|
    [0-9a-fA-F]{1,4}:((:[0-9a-fA-F]{1,4}){1,6})|
    :((:[0-9a-fA-F]{1,4}){1,7}|:)|fe80:(:[0-9a-fA-F]{0,4}){0,4}%[0-9a-zA-Z]{1,}|
    ::(ffff(:0{1,4}){0,1}:){0,1}((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])|
    ([0-9a-fA-F]{1,4}:){1,4}:((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])
)$"
echo "----------------------------------------------------------"

get_ipvx() {
    local urls=("\${!1}")  # 使用间接引用获取 URL 数组
    local ip_regex="\$3"   # 获取 IP 地址的正则表达式
    local option="\$2"     # 获取 curl 参数
    for url in "\${urls[@]}"; do
        echo "CURL: \$url ..."
        ip_result=\$(curl \$option "\$url")
        if [[ \$ip_result =~ \$ip_regex ]]; then
            echo "IP: \$ip_result   GET: \$url"
            export GETURL="\$url"
            export ip_result="\$ip_result"  # 将 ip_result 导出为全局变量
            return 0  # 返回成功
        else
            echo "IP: 获取失败!   GET: \$url"
            ip_result="获取失败! ✖️"
        fi
    done
    get_tag="geterr"
    return 1  # 返回失败
}

url_get_ipv4() {
    local show_URL_IPV4="\${1}"
    local URL_IPV4=""
    # URL_IPV4=\$(ping -c 1 \${record_name}.\${domain} | awk '/^PING/{print \$3}' | awk -F'[()]' '{print \$2}')
    URL_IPV4=\$(curl -s https://dns.google/resolve?name=\${record_name}.\${domain} | grep -oE "\\b([0-9]{1,3}\\.){3}[0-9]{1,3}\\b" | head -n 1)
    if [ -z "\$URL_IPV4" ] || [[ ! \$URL_IPV4 =~ \$ipv4_regex ]]; then
        # URL_IPV4=\$(curl -s "https://api.ipify.org?format=json&hostname=\${record_name}.\${domain}" | awk -F'"' '/ip/{print \$4}')
        URL_IPV4=\$(ping -c 1 \${record_name}.\${domain} | awk '/^PING/{print \$3}' | awk -F'[()]' '{print \$2}')
        if [ -z "\$URL_IPV4" ] || [[ ! \$URL_IPV4 =~ \$ipv4_regex ]]; then
            # echo "show_URL_IPV4获取失败!  |  URL_IPV4: URL_IPV4"
            echo "IPV4获取失败!"
            return 1
        fi
    fi
    echo "\$URL_IPV4"
}

url_get_ipv6() {
    local show_URL_IPV6="\${1}"
    local URL_IPV6=""
    # URL_IPV6=\$(dig +short AAAA \${record_name}.\${domain})
    URL_IPV6=\$(curl -s "https://ipv6-test.com/api/myip.php?host=\${record_name}.\${domain}")
    if [ -z "\$URL_IPV6" ] || [[ ! \$URL_IPV6 =~ \$ipv6_regex ]]; then
        URL_IPV6=\$(curl -s "https://api6.ipify.org?format=json&hostname=\${record_name}.\${domain}" | awk -F'"' '/ip/{print \$4}')
        if [ -z "\$URL_IPV6" ] || [[ ! \$URL_IPV6 =~ \$ipv6_regex ]]; then
            # echo "show_URL_IPV6获取失败!  |  URL_IPV6: URL_IPV6"
            echo "IPV6获取失败!"
            return 1
        fi
    fi
    echo "\$URL_IPV4"
}

if [ "\$ddns_mode" == "1" ]; then
    show_ddns_mode="↪️"
    if [ "\$iptype" == "A" ]; then
        get_ipvx "getipurl4[@]" "-4" "\$ipv4_regex"
        O_IPV4="\$ip_result"
        O_IPV4_tag="\$get_tag"
        if [ "\$O_IPV4_tag" == "geterr" ]; then
            get_ipvx "getipurl42[@]" "" "\$ipv4_regex"
            O_IPV4="\$ip_result"
        fi
    elif [ "\$iptype" == "AAAA" ]; then
        get_ipvx "getipurl6[@]" "" "\$ipv6_regex"
        O_IPV6="\$ip_result"
    else
        echo "IP type 有误."
    fi
elif [ "\$ddns_mode" == "2" ]; then
    show_ddns_mode="↩️"
    if [ "\$iptype" == "A" ]; then
        O_URL_IPV4=\$(url_get_ipv4 "O_URL_IPV4")
    elif [ "\$iptype" == "AAAA" ]; then
        O_URL_IPV6=\$(url_get_ipv6 "O_URL_IPV6")
    else
        echo "IP type 有误."
    fi
else
    echo "DDNS mode 有误."
fi

dellog_tag=1
dellog_max=25
only_onece="true"
sleep_send="false"
while true; do

    N_IPV4=""
    N_IPV6=""

    if [ ! -z "\$customizeURL" ]; then
        N_IPV4=\$(curl -4 "\$customizeURL")
        if [ -z "\$N_IPV4" ]; then
            echo "从 \$customizeURL 获取IP失败!"
        else
            echo "IPv4: \$N_IPV4   GET: \$customizeURL"
        fi
    fi
    if [ "\$iptype" == "A" ]; then
        get_ipvx "getipurl4[@]" "-4" "\$ipv4_regex"
        N_IPV4="\$ip_result"
        N_IPV4_tag="\$get_tag"
        if [ "\$N_IPV4_tag" == "geterr" ]; then
            get_ipvx "getipurl42[@]" "" "\$ipv4_regex"
            N_IPV4="\$ip_result"
        fi
    elif [ "\$iptype" == "AAAA" ]; then
        get_ipvx "getipurl6[@]" "" "\$ipv6_regex"
        N_IPV6="\$ip_result"
    else
        echo "IP type 有误."
    fi

    if [ "\$iptype" == "A" ] && [ ! -z "\$N_IPV4" ]; then

        COM_N_IPV4=\$(echo "\$N_IPV4" | tr -d '.')
        echo "COM_N_IPV4: \$COM_N_IPV4"
        if [ "\$ddns_mode" == "1" ]; then
            COM_O_IPV4=\$(echo "\$O_IPV4" | tr -d '.')
            echo "COM_O_IPV4: \$COM_O_IPV4  |  DDNS_MODE: \$ddns_mode"
        elif [ "\$ddns_mode" == "2" ]; then
            COM_O_IPV4=\$(echo "\$O_URL_IPV4" | tr -d '.')
            echo "COM_O_IPV4: \$COM_O_IPV4  |  DDNS_MODE: \$ddns_mode"
        else
            echo "DDNS mode 有误."
        fi

        if [ "\$only_onece" == "true" ]; then
            action "\$iptype" "\$N_IPV4"
            return_code=\$?
            if [ "\$return_code" -eq 1 ]; then
                echo "首次执行 DDNS 失败!"
            else
                current_date_send=\$(date +"%Y.%m.%d %T")
                if [ "\$revive" == "true" ]; then
                    message="复活执行 DDNS \$show_ddns_mode"$'\n'
                else
                    message="首次执行 DDNS \$show_ddns_mode"$'\n'
                fi
                message+="主机名: \$hostname_show"$'\n'
                message+="URL: \$record_name.\$domain"$'\n'
                # if [ "\$ddns_mode" == "1" ]; then
                #     message+="更新前IP地址: \$O_IPV4"$'\n'
                # elif [ "\$ddns_mode" == "2" ]; then
                #     message+="更新前IP地址: \$O_URL_IPV4"$'\n'
                # fi
                # message+="更新后IP地址: \$N_IPV4"$'\n'
                message+="当前IP地址: \$N_IPV4"$'\n'
                message+="───────────────"$'\n'
                message+="GETIP 地址: \$GETURL"$'\n'
                message+="服务器时间: \$current_date_send"
                \$FolderPath/send_tg.sh "\$TelgramBotToken" "\$ChatID_1" "\$message"
                echo \$N_IPV4 >> \$FolderPath/IP4_history.txt
            fi
            only_onece="false"
        fi

        if [[ "\$COM_N_IPV4" != "\$COM_O_IPV4" ]]; then
            echo -e "更新后: \$N_IPV4   GET: \$GETURL     更新前: \$O_IPV4"
            if [ -z "\$COM_O_IPV4" ]; then
                echo "首次执行 DDNS 更新IP中..." # 调试
            else
                echo "IP已改变! 正在执行 DDNS 更新IP中..." # 调试
            fi
            action "\$iptype" "\$N_IPV4"
            return_code=\$?
            for ((i=1; i<=6; i++)); do
                N_URL_IPV4=\$(url_get_ipv4 "N_URL_IPV4")
                COM_N_IPV4=\$(echo "\$N_URL_IPV4" | tr -d '.')
                if [[ "\$COM_N_IPV4" != "\$COM_O_IPV4" ]]; then
                    break
                fi
                sleep 10
            done
            echo "\${record_name}.\${domain} - \$N_URL_IPV4"
            current_date_send=\$(date +"%Y.%m.%d %T")
            message="IP 已变更! \$show_ddns_mode"$'\n'
            message+="主机名: \$hostname_show"$'\n'
            message+="URL: \$record_name.\$domain"$'\n'
            if [ "\$ddns_mode" == "1" ]; then
                message+="更新前IP地址: \$O_IPV4"$'\n'
            elif [ "\$ddns_mode" == "2" ]; then
                message+="更新前IP地址: \$O_URL_IPV4"$'\n'
            fi
            # if [ "\$return_code" -eq 1 ]; then
            #     message+="\$record_name.\$domain 更新失败! ✖️"$'\n'
            # else
            #     # if [ ! -z "\$O_URL_IPV4" ]; then
            #         message+="\$record_name.\$domain \$O_URL_IPV4"$'\n'
            #     # fi
            # fi
            message+="更新后IP地址: \$N_IPV4"$'\n'
            # if [ "\$return_code" -eq 1 ]; then
            #     message+="\$record_name.\$domain 更新失败! ✖️"$'\n'
            # else
            #     # if [ ! -z "\$N_URL_IPV4" ]; then
            #         message+="\$record_name.\$domain \$N_URL_IPV4"$'\n'
            #     # fi
            # fi
            message+="───────────────"$'\n'
            if [[ \$N_IPV4 =~ \$ipv4_regex ]]; then
                message+="GETIP 地址: \$GETURL"$'\n'
            fi
            message+="服务器时间: \$current_date_send"
            \$FolderPath/send_tg.sh "\$TelgramBotToken" "\$ChatID_1" "\$message"
            O_IPV4=\$N_IPV4
            O_URL_IPV4=\$N_URL_IPV4
            echo \$N_IPV4 >> \$FolderPath/IP4_history.txt
            sleep_send="true"
        else
            echo -e "更新后: \$N_IPV4   GET: \$GETURL     更新前: \$O_IPV4"
            echo "IP未改变." # 调试
        fi
    elif [ "\$iptype" == "AAAA" ] && [ ! -z "\$N_IPV6" ]; then

        COM_N_IPV6=\$(echo "\$N_IPV6" | tr -d ':')
        echo "COM_N_IPV6: \$COM_N_IPV6"
        if [ "\$ddns_mode" == "1" ]; then
            COM_O_IPV6=\$(echo "\$O_IPV6" | tr -d ':')
            echo "COM_O_IPV6: \$COM_O_IPV6  |  DDNS_MODE: \$ddns_mode"
        elif [ "\$ddns_mode" == "2" ]; then
            COM_O_IPV6=\$(echo "\$O_URL_IPV6" | tr -d ':')
            echo "COM_O_IPV6: \$COM_O_IPV6  |  DDNS_MODE: \$ddns_mode"
        else
            echo "DDNS mode 有误."
        fi

        if [ "\$only_onece" == "true" ]; then
            action "\$iptype" "\$N_IPV6"
            return_code=\$?
            if [ "\$return_code" -eq 1 ]; then
                echo "首次执行 DDNS 失败!"
            else
                current_date_send=\$(date +"%Y.%m.%d %T")
                if [ "\$revive" == "true" ]; then
                    message="复活执行 DDNS \$show_ddns_mode"$'\n'
                else
                    message="首次执行 DDNS \$show_ddns_mode"$'\n'
                fi
                message+="主机名: \$hostname_show"$'\n'
                message+="URL: \$record_name.\$domain"$'\n'
                # if [ "\$ddns_mode" == "1" ]; then
                #     message+="更新前IP地址: \$O_IPV6"$'\n'
                # elif [ "\$ddns_mode" == "2" ]; then
                #     message+="更新前IP地址: \$O_URL_IPV6"$'\n'
                # fi
                # message+="更新后IP地址: \$N_IPV6"$'\n'
                message+="当前IP地址: \$N_IPV6"$'\n'
                message+="───────────────"$'\n'
                message+="GETIP 地址: \$GETURL"$'\n'
                message+="服务器时间: \$current_date_send"
                \$FolderPath/send_tg.sh "\$TelgramBotToken" "\$ChatID_1" "\$message"
                echo \$N_IPV6 >> \$FolderPath/IP6_history.txt
            fi
            only_onece="false"
        fi

        if [[ "\$COM_N_IPV6" != "\$COM_O_IPV6" ]]; then
            echo -e "更新后: \$N_IPV6   GET: \$GETURL     更新前: \$O_IPV6"
            if [ -z "\$COM_O_IPV6" ]; then
                echo "首次执行 DDNS 更新IP中..." # 调试
            else
                echo "IP已改变! 正在执行 DDNS 更新IP中..." # 调试
            fi
            action "\$iptype" "\$N_IPV6"
            return_code=\$?
            for ((i=1; i<=6; i++)); do
                N_URL_IPV6=\$(url_get_ipv6 "N_URL_IPV6")
                COM_N_IPV6=\$(echo "\$N_URL_IPV6" | tr -d ':')
                if [[ "\$COM_N_IPV6" != "\$COM_O_IPV6" ]]; then
                    break
                fi
                sleep 10
            done
            echo "\${record_name}.\${domain} - \$N_URL_IPV6"
            current_date_send=\$(date +"%Y.%m.%d %T")
            message="IP 已变更! \$show_ddns_mode"$'\n'
            message+="主机名: \$hostname_show"$'\n'
            message+="URL: \$record_name.\$domain"$'\n'
            if [ "\$ddns_mode" == "1" ]; then
                message+="更新前IP地址: \$O_IPV6"$'\n'
            elif [ "\$ddns_mode" == "2" ]; then
                message+="更新前IP地址: \$O_URL_IPV6"$'\n'
            fi
            # if [ "\$return_code" -eq 1 ]; then
            #     message+="\$record_name.\$domain 更新失败! ✖️"$'\n'
            # else
            #     # if [ ! -z "\$O_URL_IPV6" ]; then
            #         message+="\$record_name.\$domain \$O_URL_IPV6"$'\n'
            #     # fi
            # fi
            message+="更新后IP地址: \$N_IPV6"$'\n'
            # if [ "\$return_code" -eq 1 ]; then
            #     message+="\$record_name.\$domain 更新失败! ✖️"$'\n'
            # else
            #     # if [ ! -z "\$N_URL_IPV6" ]; then
            #         message+="\$record_name.\$domain \$N_URL_IPV6"$'\n'
            #     # fi
            # fi
            message+="───────────────"$'\n'
            if [[ \$N_IPV6 =~ \$ipv6_regex ]]; then
                message+="GETIP 地址: \$GETURL"$'\n'
            fi
            message+="服务器时间: \$current_date_send"
            \$FolderPath/send_tg.sh "\$TelgramBotToken" "\$ChatID_1" "\$message"
            O_IPV6=\$N_IPV6
            O_URL_IPV6=\$N_URL_IPV6
            echo \$N_IPV6 >> \$FolderPath/IP6_history.txt
            sleep_send="true"
        else
            echo -e "更新后: \$N_IPV6   GET: \$GETURL     更新前: \$O_IPV6"
            echo "IP未改变." # 调试
        fi
    else
        echo "N_IPV4/6 获取失败 或 IP type 有误."
        # exit 1
    fi
    current_date_send=\$(date +"%Y.%m.%d %T")
    echo "\$current_date_send     LOG: \$dellog_tag / \$dellog_max"
    if [ "\$dellog_tag" -ge "\$dellog_max" ]; then
        > \$FolderPath/tg_ddns.log
        dellog_tag=0
    fi
    ((dellog_tag++))
    echo "----------------------------------------------------------"
    if [ "\$sleep_send" == "true" ]; then
        sleep 120
        sleep_send="false"
    else
        sleep 30
    fi
done
# END
EOF
    chmod +x $FolderPath/tg_ddns.sh
    killpid "tg_ddns.sh"
    nohup $FolderPath/tg_ddns.sh > $FolderPath/tg_ddns.log 2>&1 &
    delcrontab "$FolderPath/tg_ddns.sh"
    addcrontab "@reboot nohup $FolderPath/tg_ddns.sh > $FolderPath/tg_ddns.log 2>&1 &"

    if [ "$CFDDNS_KEEPER" == "true"  ]; then
        cat > "$FolderPath/tg_ddnskp.sh" << EOF
#!/bin/bash

####################################################################
# DDNS 守护脚本

$(declare -f getpid)
$(declare -f addcrontab)

FolderPath="$FolderPath"
if [ ! -d "\$FolderPath" ]; then
    mkdir -p "\$FolderPath"
fi

for ((i=0; i<3; i++)); do

    ddnskp_pid=\$(getpid "tg_ddns.sh")

    if [ -z "\$ddnskp_pid" ]; then
        current_date=\$(date +"%Y.%m.%d %T")
        echo "\$current_date : 后台未检查到 tg_ddns.sh 进程, 正在启动中..."
        nohup \$FolderPath/tg_ddns.sh "re" > \$FolderPath/tg_ddns.log 2>&1 &
    fi

    if ! crontab -l | grep -q "\$FolderPath/tg_ddnskp.sh"; then
        addcrontab "*/5 * * * * bash \$FolderPath/tg_ddnskp.sh >> \$FolderPath/tg_ddnskp.log 2>&1 &"
        /etc/init.d/cron restart > /dev/null 2>&1
    fi

sleep 3
done
EOF
        chmod +x $FolderPath/tg_ddnskp.sh
        delcrontab "$FolderPath/tg_ddnskp.sh"
        addcrontab "*/3 * * * * bash $FolderPath/tg_ddnskp.sh >> $FolderPath/tg_ddnskp.log 2>&1 &"
        cat > "$FolderPath/tg_ddkpnh.sh" << EOF
#!/bin/bash

$(declare -f addcrontab)

FolderPath="$FolderPath"
if [ ! -d "\$FolderPath" ]; then
    mkdir -p "\$FolderPath"
fi

while true; do
    if ! crontab -l | grep -q "\$FolderPath/tg_ddnskp.sh"; then
        addcrontab "*/5 * * * * bash \$FolderPath/tg_ddnskp.sh >> \$FolderPath/tg_ddnskp.log 2>&1 &"
        /etc/init.d/cron restart > /dev/null 2>&1
    fi
    current_date=\$(date +"%Y.%m.%d %T")
    echo "\$current_date : 已执行 DDNS 复活."
    sleep 60
done
EOF
        chmod +x $FolderPath/tg_ddkpnh.sh
        killpid "tg_ddkpnh.sh"
        nohup $FolderPath/tg_ddkpnh.sh > $FolderPath/tg_ddkpnh.log 2>&1 &
#         cat > /etc/systemd/system/tg_ddnskp.service << EOF
# [Unit]
# Description=CheckAndStartService
# After=network.target

# [Service]
# Type=oneshot
# ExecStart=/bin/bash -c '/usr/bin/env bash <<SCRIPT
# while true; do
#     if ! pgrep -x "tg_ddkpnh.sh" >/dev/null; then
#         nohup $FolderPath/tg_ddkpnh.sh &
#     fi
#     sleep 60
# done
# SCRIPT'

# [Install]
# WantedBy=multi-user.target
# EOF
#         systemctl daemon-reload
#         systemctl enable tg_ddnskp.service > /dev/null
        cat > /etc/systemd/system/tg_ddrun.service << EOF
[Unit]
Description=Your Script Description

[Service]
Type=oneshot
ExecStart=/bin/bash $FolderPath/tg_ddnskp.sh >> $FolderPath/tg_ddnskp.log 2>&1

[Install]
WantedBy=multi-user.target
EOF

        cat > /etc/systemd/system/tg_ddtimer.timer << EOF
[Unit]
Description=Your Timer Description

[Timer]
OnUnitActiveSec=10min
Unit=tg_ddrun.service

[Install]
WantedBy=timers.target
EOF
        systemctl daemon-reload
        systemctl start tg_ddtimer.timer
        systemctl enable tg_ddtimer.timer
    fi

    if [ "$mute" == "false" ]; then
        send_time=$(echo $(date +%s%N) | cut -c 16-)
        # N_URL_IPV4=$(curl -s https://dns.google/resolve?name=$CFDDNS_DOMAIN_P.$CFDDNS_DOMAIN_S | grep -oE "\\b([0-9]{1,3}\\.){3}[0-9]{1,3}\\b" | head -n 1)
        message="DDNS 报告设置成功 ⚙️"$'\n'"主机名: $hostname_show"$'\n'"当主机 IP 变更时将收到通知."
        $FolderPath/send_tg.sh "$TelgramBotToken" "$ChatID_1" "$message" "ddns" "$send_time" &
        (sleep 15 && $FolderPath/del_lm_tg.sh "$TelgramBotToken" "$ChatID_1" "ddns" "$send_time") &
        sleep 1
        # getpid "send_tg.sh"
        # ddns_pid="$tg_pid"
        ddns_pid=$(getpid "send_tg.sh")
    fi
    tips="$Tip DDNS 报告设置成功, 当主机 IP 变更时发出通知."
}

# 卸载
UN_SetupBoot_TG() {
    # if [ "$boot_menu_tag" == "$SETTAG" ]; then
        systemctl stop tg_boot.service > /dev/null 2>&1
        systemctl disable tg_boot.service > /dev/null 2>&1
        sleep 1
        rm -f /etc/systemd/system/tg_boot.service
        if [ -f /etc/init.d/tg_boot.sh ]; then
            /etc/init.d/tg_boot.sh disable
            rm -f /etc/init.d/tg_boot.sh
        fi
        tips="$Tip 机开通知 已经取消 / 删除."
    # fi
}
UN_SetupLogin_TG() {
    # if [ "$login_menu_tag" == "$SETTAG" ]; then
        if [ -f /etc/bash.bashrc ]; then
            sed -i '/bash \/root\/.shfile\/tg_login.sh/d' /etc/bash.bashrc
        fi
        if [ -f /etc/profile ]; then
            sed -i '/bash \/root\/.shfile\/tg_login.sh/d' /etc/profile
        fi
        tips="$Tip 登陆通知 已经取消 / 删除."
    # fi
}
UN_SetupShutdown_TG() {
    # if [ "$shutdown_menu_tag" == "$SETTAG" ]; then
        systemctl stop tg_shutdown.service > /dev/null 2>&1
        systemctl disable tg_shutdown.service > /dev/null 2>&1
        sleep 1
        rm -f /etc/systemd/system/tg_shutdown.service
        if [ -f /etc/init.d/tg_shutdown.sh ]; then
            /etc/init.d/tg_shutdown.sh disable
            rm -f /etc/init.d/tg_shutdown.sh
        fi
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
        crontab -l | grep -v "$FolderPath/VPSKeeper.sh" | crontab -
        tips="$Tip 自动更新已经取消."
    # fi
}

UN_ALL() {
    if [ "$autorun" == "false" ]; then
        if [ ! -z "$delall_pid" ] && pgrep -a '' | grep -Eq "^\s*$delall_pid\s" > /dev/null; then
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

# 清空所有*.log文件
DELLOGFILE() {
    # rm -f ${FolderPath}/*.log
    LogFiles=( $(find ${FolderPath} -name "*.log") )
    # printf '%s\n' "${LogFiles[@]}"
    # rm -f "${LogFiles[@]}"
    logn=1
    divline
    echo -e "${REB}删除记录:${NC}"
    for file in "${LogFiles[@]}"; do
        # echo -e " ${REB}$logn${NC} \t$file"
        if ((logn % 2 == 0)); then
            echo -e " ${REB}$logn \t$file${NC}"
        else
            echo -e " ${RE}$logn \t$file${NC}"
        fi
        ((logn++))
    done
    echo -e " ${REB}A${NC} \t${REB}清空所有 *log 文件!${NC}"
    divline
    read -e -p "请输入要 [清空] 的文件序号 : " lognum
    if [ "$lognum" == "A" ] || [ "$lognum" == "a" ]; then
        for file in "${LogFiles[@]}"; do > "$file"; done
        tips="$Tip 已经清空所有 *log 文件!"
    else
        if [[ -z "${LogFiles[$((lognum-1))]}" ]] || [ -z "$lognum" ]; then
            tips="$Tip 输入有误 或 未找到对应的文件!"
        else
            > "${LogFiles[$((lognum-1))]}"
            tips="$Tip 已经清空文件: ${LogFiles[$((lognum-1))]}"
        fi
    fi
}

# 查看*.log文件
VIEWLOG() {
    LogFiles=( $(find ${FolderPath} -name "*.log") )
    logn=1
    divline
    echo -e "${GRB}查看log:${NC}"
    for file in "${LogFiles[@]}"; do
        # echo -e " ${GR}$logn${NC} \t$file"
        if ((logn % 2 == 0)); then
            echo -e " ${GR}$logn \t$file${NC}"
        else
            echo -e " $logn \t$file"
        fi
        ((logn++))
    done
    divline
    read -e -p "请输入要 [查看] 的文件序号 : " lognum
    if [[ "$lognum" =~ ^[0-9]+$ ]]; then
        if [[ -z "${LogFiles[$((lognum-1))]}" ]] || [ "$lognum" -eq 0 ]; then
            tips="$Tip 输入有误 或 未找到对应的文件!"
        else
            divline
            echo -e "${GR}${LogFiles[$((lognum-1))]} 内容如下:${NC}"
            cat ${LogFiles[$((lognum-1))]}
            divline
            Pause
        fi
    else
        tips="$Tip 必须输入对应的数字序号!"
    fi
}

# 查看*.service文件
VIEWSERVICE() {
    if ! command -v systemd &>/dev/null; then
        tips="$Err 系统未检测到 \"systemd\" 程序, 无法设置关机通知."
        return 1
    fi
    ServiceFiles=( $(find /etc/systemd/system -name "tg_*") )
    servicen=1
    divline
    echo -e "${GRB}查看service:${NC}"
    for file in "${ServiceFiles[@]}"; do
        # echo -e " ${GR}$servicen${NC} \t$file"
        if ((servicen % 2 == 0)); then
            echo -e " ${GR}$servicen \t$file${NC}"
        else
            echo -e " $servicen \t$file"
        fi
        ((servicen++))
    done
    divline
    read -e -p "请输入要 [查看] 的文件序号 : " servicenum
    if [[ "$servicenum" =~ ^[0-9]+$ ]]; then
        if [[ -z "${ServiceFiles[$((servicenum-1))]}" ]] || [ "$servicenum" -eq 0 ]; then
            tips="$Tip 输入有误 或 未找到对应的文件!"
        else
            divline
            echo -e "${GR}${ServiceFiles[$((servicenum-1))]} 内容如下:${NC}"
            cat ${ServiceFiles[$((servicenum-1))]}
            divline
            Pause
        fi
    else
        tips="$Tip 必须输入对应的数字序号!"
    fi
}

# 跟踪查看*.log文件
T_VIEWLOG() {
    LogFiles=( $(find ${FolderPath} -name "*.log") )
    logn=1
    divline
    echo -e "${GRB}跟踪log:${NC}"
    for file in "${LogFiles[@]}"; do
        # echo -e " ${GR}$logn${NC} \t$file"
        if ((logn % 2 == 0)); then
            echo -e " $logn \t$file"
        else
            echo -e " ${GR}$logn \t$file${NC}"
        fi
        ((logn++))
    done
    divline
    echo -e "${RE}注意${NC}:  ${REB}按任意键中止${NC}"
    read -e -p "请输入要 [查看] 的文件序号 : " lognum
    if [[ "$lognum" =~ ^[0-9]+$ ]]; then
        if [[ -z "${LogFiles[$((lognum-1))]}" ]] || [ "$lognum" -eq 0 ]; then
            tips="$Tip 输入有误 或 未找到对应的文件!"
        else
            stty intr ^- # 禁用 CTRL+C
            divline
            echo -e "${GR}${LogFiles[$((lognum-1))]} 内容如下:${NC}"
            tail -f ${LogFiles[$((lognum-1))]} &
            tail_pid=$!
            read -n 1 -s -r -p ""
            stty intr ^C # 恢复 CTRL+C
            # stty sane # 重置终端设置为默认值
            kill -2 $tail_pid 2>/dev/null
            killpid "tail"
            # pkill -f tail
            # kill $(ps | grep '[t]ail' | awk '{print $1}') 2>/dev/null
            # pgrep -f tail | xargs kill -9 2>/dev/null
            if pgrep -x tail > /dev/null; then
                echo -e "中止失败!! 请执行以下指令中止!"
                echo -e "中止指令1: ${REB}pkill -f tail${NC}"
                echo -e "中止指令2: ${REB}kill $(ps | grep '[t]ail' | awk '{print $1}') 2>/dev/null${NC}"
            fi
            divline
            Pause
        fi
    else
        tips="$Tip 必须输入对应的数字序号!"
    fi
}

# 实时网速
T_NETSPEED() {
    # interfaces_re_0=$(ip -br link | awk '$2 == "UP" {print $1}' | grep -v "lo")
    # output=$(ip -br link)
    IFS=$'\n'
    count=1
    choice_array=()
    interfaces_re=()
    show_interfaces_re=()
    # for line in $output; do
    for line in ${interfaces_all[@]}; do
        columns_1="$line"
        # columns_1=$(echo "$line" | awk '{print $1}')
        # columns_1=${columns_1[$i]%@*}
        # columns_1=${columns_1%:*}
        columns_1_array+=("$columns_1")
        columns_2="$line"
        # columns_2=$(printf "%s\t\tUP" "$line")
        # columns_2=$(echo "$line" | awk '{print $1"\t"UP}')
        # columns_2=${columns_2[$i]%@*}
        # columns_2=${columns_2%:*}
        # columns_2=$(echo "$line" | awk '{print $1"\t"$2}')
        # if [[ $interfaces_re_0 =~ $columns_1 ]]; then
        if [[ $interfaces_up =~ $columns_1 ]]; then
            printf "${GR}%d. %s${NC}\n" "$count" "$columns_2"
        else
            printf "${GR}%d. ${NC}%s\n" "$count" "$columns_1"
        fi
        ((count++))
    done
    echo -e "请输入对应的编号进行统计测速"
    echo -en "例如: ${GR}1${NC} 或 ${GR}2${NC} 或 ${GR}1,2 (合计)${NC} 或 ${GR}回车 (自动检测活跃接口) ${NC}: "
    read -er choice
    # if [[ $choice == *0* ]]; then
    #     tips="$Err 接口编号中没有 0 选项"
    #     return 1
    # fi
    if [ ! -z "$choice" ]; then
        # choice="${choice//[, ]/}"
        # for (( i=0; i<${#choice}; i++ )); do
        # char="${choice:$i:1}"
        # if [[ "$char" =~ [0-9] ]]; then
        #     choice_array+=("$char")
        # fi
        # done
        # # echo "解析后的接口编号数组: ${choice_array[@]}"
        # for item in "${choice_array[@]}"; do
        #     index=$((item - 1))
        #     if [ -z "${columns_1_array[index]}" ]; then
        #         tips="$Err 错误: 输入的编号 $item 无效或超出范围."
        #         return 1
        #     else
        #         interfaces_re+=("${columns_1_array[index]}")
        #     fi
        # done

        if [ "$choice" == "0" ]; then
            tips="$Err 输入错误, 没有0选择."
            return 1
        fi

        if ! [[ "$choice" =~ ^[0-9,]+$ ]]; then
            tips="$Err 输入的选项无效, 请输入有效的数字选项或使用逗号分隔多个数字选项."
            return 1
        fi

        choice="${choice//[, ]/,}"  # 将所有逗号后的空格替换成单逗号
        IFS=',' read -ra choice_array <<< "$choice"  # 使用逗号作为分隔符将输入拆分成数组

        for item in "${choice_array[@]}"; do
            if [ "$item" -eq 0 ] || [ "$item" -gt "${#interfaces_all[@]}" ]; then
                tips="$Err 输入错误, 输入的选项 $item 无效或超出范围。"
                return 1
            fi
            index=$((item - 1))
            interfaces_re+=("${columns_1_array[index]}")
        done

        # for ((i = 0; i < ${#interfaces_re[@]}; i++)); do
        #     show_interfaces_re+="${interfaces_re[$i]}"
        #     if ((i < ${#interfaces_re[@]} - 1)); then
        #         show_interfaces_re+=","
        #     fi
        # done
        show_interfaces_re=$(sep_array interfaces_re ",")
        # echo "确认选择接口: interfaces_re: ${interfaces_re[@]}  show_interfaces_re: $show_interfaces_re"
        # Pause
    else
        echo
        # interfaces_all=$(ip -br link | awk '{print $1}' | tr '\n' ' ')
        active_interfaces=()
        echo "检查网络接口流量情况..."
        for interface in ${interfaces_all[@]}
        do
        clean_interface=${interface%%@*}
        stats=$(ip -s link show $clean_interface)
        rx_packets=$(echo "$stats" | awk '/RX:/{getline; print $2}')
        tx_packets=$(echo "$stats" | awk '/TX:/{getline; print $2}')
        if [ "$rx_packets" -gt 0 ] || [ "$tx_packets" -gt 0 ]; then
            echo "接口: $clean_interface 活跃, 接收: $rx_packets 包, 发送: $tx_packets 包."
            active_interfaces+=($clean_interface)
        else
            echo "接口: $clean_interface 不活跃."
        fi
        done
        interfaces_re=("${active_interfaces[@]}")
        # for ((i = 0; i < ${#interfaces_re[@]}; i++)); do
        #     show_interfaces_re+="${interfaces_re[$i]}"
        #     if ((i < ${#interfaces_re[@]} - 1)); then
        #         show_interfaces_re+=","
        #     fi
        # done
        show_interfaces_re=$(sep_array interfaces_re ",")
        # echo "确认选择接口: interfaces_re: $interfaces_re  show_interfaces_re: $show_interfaces_re"
        # Pause
        echo -e "$Tip 检测到活动的接口: $show_interfaces_re"
    fi
    echo -en "请输入统计间隔时间 (回车默认 ${GR}2${NC} 秒) : "
    read -er inputtt
    if [ -z "$inputtt" ]; then
        echo
        nstt=2
    else
        if [[ $inputtt =~ ^[0-9]+(\.[0-9])?$ ]]; then
            nstt=$inputtt
        else
            tips="输入有误."
            return
        fi
    fi
    if [ "$ss_s" == "st" ]; then
        echo -en "显示 TCP/UDP 连接数 (${RE}连接数过多时不建议开启${NC}) (y/${GR}N${NC}) : "
        read -er input_tu
        if [ ! "$input_tu" == "y" ] && [ ! "$input_tu" == "Y" ]; then
            echo
            tu_show="false"
        else
            tu_show="true"
        fi
    fi
    # if [ ! -f $FolderPath/tg_interface_re.sh ]; then
        cat <<EOF > $FolderPath/tg_interface_re.sh
#!/bin/bash

GR="\033[32m" && RE="\033[31m" && GRB="\033[42;37m" && REB="\033[41;37m" && NC="\033[0m"
Inf="\${GR}[信息]\${NC}:"
Err="\${RE}[错误]\${NC}:"
Tip="\${GR}[提示]\${NC}:"

$(declare -f CLS)
$(declare -f Remove_B)
$(declare -f Bytes_K_TGM)

FolderPath="$FolderPath"
if [ ! -d "\$FolderPath" ]; then
    mkdir -p "\$FolderPath"
fi

ss_tag=""
if [ "$ss_s" == "st" ]; then
    ss_tag="st"
    $(declare -f Bytes_K_TGMi)
    $(declare -f Bit_K_TGMi)
fi

# 统计接口网速（只统所有接口）
# interfaces=(\$(ip -br link | awk '{print \$1}' | tr '\n' ' '))

# 统计接口网速（只统计 UP 接口）
# interfaces_up=\$(ip -br link | awk '\$2 == "UP" {print \$1}' | grep -v "lo")
# interfaces=(\$(ip -br link | awk '{print \$1}' | tr '\n' ' '))

# 去重并且保持原有顺序，分割字符串为数组
IFS=',' read -ra interfaces_r <<< "$(echo "$show_interfaces_re" | awk -v RS=, '!a[$1]++ {if (NR>1) printf ",%s", $0; else printf "%s", $0}')"

for ((i=0; i<\${#interfaces_r[@]}; i++)); do
    interface=\${interfaces_r[\$i]%@*}
    interface=\${interface%:*}
    interfaces_r[\$i]=\$interface
done
for ((i = 0; i < \${#interfaces_r[@]}; i++)); do
    show_interfaces+="\${interfaces_r[\$i]}"
    if ((i < \${#interfaces_r[@]} - 1)); then
        show_interfaces+=","
    fi
done

TT=$nstt
tu_show=$tu_show
duration=0
CLEAR_TAG=1
CLEAR_TAG_OLD=\$CLEAR_TAG

avg_count=0
max_rx_speed_kb=0
# min_rx_speed_kb=9999999999999
min_rx_speed_kb=2147483647
total_rx_speed_kb=0
avg_rx_speed_kb=0
max_tx_speed_kb=0
# min_tx_speed_kb=9999999999999
min_tx_speed_kb=2147483647
total_tx_speed_kb=0
avg_tx_speed_kb=0

# 定义数组
declare -A sp_prev_rx_bytes
declare -A sp_prev_tx_bytes
declare -A sp_current_rx_bytes
declare -A sp_current_tx_bytes

CLS
echo " 实时网速计算中..."
echo " =================================================="
while true; do

    # 获取tt秒前数据
    sp_ov_prev_rx_bytes=0
    sp_ov_prev_tx_bytes=0
    for interface in "\${interfaces_r[@]}"; do
        interface_nodot=\${interface//./_}
        sp_prev_rx_bytes[\$interface_nodot]=\$(ip -s link show \$interface | awk '/RX:/ { getline; print \$1 }')
        sp_prev_tx_bytes[\$interface_nodot]=\$(ip -s link show \$interface | awk '/TX:/ { getline; print \$1 }')
        sp_ov_prev_rx_bytes=\$((sp_ov_prev_rx_bytes + sp_prev_rx_bytes[\$interface_nodot]))
        sp_ov_prev_tx_bytes=\$((sp_ov_prev_tx_bytes + sp_prev_tx_bytes[\$interface_nodot]))
    done

    # 等待TT秒
    end_time=\$(date +%s%N)
    if [ ! -z "\$start_time" ]; then
        time_diff=\$((end_time - start_time))
        time_diff_ms=\$((time_diff / 1000000))

        # 输出执行FOR所花费时间
        # echo "上一个 FOR循环 所执行时间 \$time_diff_ms 毫秒."

        # duration=\$(awk "BEGIN {print \$time_diff_ms/1000}")
        duration=\$(awk 'BEGIN { printf "%.3f", '"\$time_diff_ms"' / 1000 }')
        sleep_time=\$(awk -v v1="\$TT" -v v2="\$duration" 'BEGIN { printf "%.3f", v1 - v2 }')
    else
        sleep_time=\$TT
    fi
    sleep_time=\$(awk "BEGIN {print (\$sleep_time < 0 ? 0 : \$sleep_time)}")
    echo " =================================================="
    # se_state=\$(awk 'BEGIN {if ('"\$sleep_time"' <= 0) print "\${REB}不正常\${NC}"; else print "\${GRB}正常\${NC}"}')
    sleep_time_show=\$(awk -v v1="\$sleep_time" 'BEGIN { printf "%.3f", v1 }')
    se_state=\$(awk -v reb="\${REB}" -v grb="\${GRB}" -v nc="\${NC}" 'BEGIN {if ('"\$TT"' < '"\$duration"') print reb "不正常" nc; else print grb "正常" nc}')
    echo -e " 间隔: \$sleep_time_show 秒    时差: \$duration 秒     状态: \$se_state"
    # echo -e "统计接口: \$show_interfaces"
    echo
    date +"%Y.%m.%d %T"
    echo -e "\${RE}按任意键退出\${NC}"
    sleep \$sleep_time
    start_time=\$(date +%s%N)

    # 获取TT秒后数据
    sp_ov_current_rx_bytes=0
    sp_ov_current_tx_bytes=0
    for interface in "\${interfaces_r[@]}"; do
        interface_nodot=\${interface//./_}
        sp_current_rx_bytes[\$interface_nodot]=\$(ip -s link show \$interface | awk '/RX:/ { getline; print \$1 }')
        sp_current_tx_bytes[\$interface_nodot]=\$(ip -s link show \$interface | awk '/TX:/ { getline; print \$1 }')
        sp_ov_current_rx_bytes=\$((sp_ov_current_rx_bytes + sp_current_rx_bytes[\$interface_nodot]))
        sp_ov_current_tx_bytes=\$((sp_ov_current_tx_bytes + sp_current_tx_bytes[\$interface_nodot]))
    done

    # 计算网速
    sp_ov_rx_diff_speed=\$((sp_ov_current_rx_bytes - sp_ov_prev_rx_bytes))
    sp_ov_tx_diff_speed=\$((sp_ov_current_tx_bytes - sp_ov_prev_tx_bytes))
    # rx_speed=\$(awk "BEGIN { speed = \$sp_ov_rx_diff_speed / (\$TT * 1024); if (speed >= 1024) { printf \"%.1fMB\", speed/1024 } else { printf \"%.1fKB\", speed } }")
    # tx_speed=\$(awk "BEGIN { speed = \$sp_ov_tx_diff_speed / (\$TT * 1024); if (speed >= 1024) { printf \"%.1fMB\", speed/1024 } else { printf \"%.1fKB\", speed } }")

    ((avg_count++))

    rx_speed_kb=\$(awk -v v1="\$sp_ov_rx_diff_speed" -v t1="\$TT" 'BEGIN { printf "%.1f", v1 / (t1 * 1024) }')

    if (( \$(awk 'BEGIN {print ('\$rx_speed_kb' > '\$max_rx_speed_kb') ? "1" : "0"}') )); then
        max_rx_speed_kb=\$rx_speed_kb
    fi
    if (( \$(awk 'BEGIN {print ('\$rx_speed_kb' < '\$min_rx_speed_kb') ? "1" : "0"}') )); then
        min_rx_speed_kb=\$rx_speed_kb
    fi

    total_rx_speed_kb=\$(awk 'BEGIN {print "'\$total_rx_speed_kb'" + "'\$rx_speed_kb'"}')
    avg_rx_speed_kb=\$(awk 'BEGIN {printf "%.1f", "'\$total_rx_speed_kb'" / "'\$avg_count'"}')

    rx_speed=\$(Bytes_K_TGM "\$rx_speed_kb")
    max_rx_speed=\$(Bytes_K_TGM "\$max_rx_speed_kb")
    min_rx_speed=\$(Bytes_K_TGM "\$min_rx_speed_kb")
    avg_rx_speed=\$(Bytes_K_TGM "\$avg_rx_speed_kb")

    if [ "\$ss_tag" == "st" ]; then

        rx_speedi=\$(Bytes_K_TGMi "\$rx_speed_kb")
        max_rx_speedi=\$(Bytes_K_TGMi "\$max_rx_speed_kb")
        min_rx_speedi=\$(Bytes_K_TGMi "\$min_rx_speed_kb")
        avg_rx_speedi=\$(Bytes_K_TGMi "\$avg_rx_speed_kb")
        rx_speedb=\$(Bit_K_TGMi "\$(awk 'BEGIN {printf "%.1f", "'\$rx_speed_kb'" * 8}')")
        max_rx_speedb=\$(Bit_K_TGMi "\$(awk 'BEGIN {printf "%.1f", "'\$max_rx_speed_kb'" * 8}')")
        min_rx_speedb=\$(Bit_K_TGMi "\$(awk 'BEGIN {printf "%.1f", "'\$min_rx_speed_kb'" * 8}')")
        avg_rx_speedb=\$(Bit_K_TGMi "\$(awk 'BEGIN {printf "%.1f", "'\$avg_rx_speed_kb'" * 8}')")

    else
        rx_speed=\$(Bytes_K_TGM "\$rx_speed_kb")
        max_rx_speed=\$(Bytes_K_TGM "\$max_rx_speed_kb")
        min_rx_speed=\$(Bytes_K_TGM "\$min_rx_speed_kb")
        avg_rx_speed=\$(Bytes_K_TGM "\$avg_rx_speed_kb")
    fi

    tx_speed_kb=\$(awk -v v1="\$sp_ov_tx_diff_speed" -v t1="\$TT" 'BEGIN { printf "%.1f", v1 / (t1 * 1024) }')

    if (( \$(awk 'BEGIN {print ('\$tx_speed_kb' > '\$max_tx_speed_kb') ? "1" : "0"}') )); then
        max_tx_speed_kb=\$tx_speed_kb
    fi
    if (( \$(awk 'BEGIN {print ('\$tx_speed_kb' < '\$min_tx_speed_kb') ? "1" : "0"}') )); then
        min_tx_speed_kb=\$tx_speed_kb
    fi

    total_tx_speed_kb=\$(awk 'BEGIN {print "'\$total_tx_speed_kb'" + "'\$tx_speed_kb'"}')
    avg_tx_speed_kb=\$(awk 'BEGIN {printf "%.1f", "'\$total_tx_speed_kb'" / "'\$avg_count'"}')

    if [ "\$ss_tag" == "st" ]; then

        tx_speedi=\$(Bytes_K_TGMi "\$tx_speed_kb")
        max_tx_speedi=\$(Bytes_K_TGMi "\$max_tx_speed_kb")
        min_tx_speedi=\$(Bytes_K_TGMi "\$min_tx_speed_kb")
        avg_tx_speedi=\$(Bytes_K_TGMi "\$avg_tx_speed_kb")
        tx_speedb=\$(Bit_K_TGMi "\$(awk 'BEGIN {printf "%.1f", "'\$tx_speed_kb'" * 8}')")
        max_tx_speedb=\$(Bit_K_TGMi "\$(awk 'BEGIN {printf "%.1f", "'\$max_tx_speed_kb'" * 8}')")
        min_tx_speedb=\$(Bit_K_TGMi "\$(awk 'BEGIN {printf "%.1f", "'\$min_tx_speed_kb'" * 8}')")
        avg_tx_speedb=\$(Bit_K_TGMi "\$(awk 'BEGIN {printf "%.1f", "'\$avg_tx_speed_kb'" * 8}')")

        # 实时TCP/UDP连接数
        tut_errtips=""
        tuu_errtips=""
        if [ "\$tu_show" == "true" ]; then
            # 获取tcp开头的行数，并将Foreign Address为本地IP地址和外部地址的连接数进行统计
            if command -v ss &>/dev/null; then
                # tcp_connections=\$(ss -t | tail -n +2)
                # tcp_connections=\$(ss -t | tail -n +2 | sed -e 's/\[\(::ffff:\)\?//g' -e 's/\]//g')
                tcp_connections=\$(ss -at | tail -n +2 | sed -e 's/\[\(::ffff:\)\?//g' -e 's/\]//g' | grep -v 'LISTEN' | grep -v '0.0.0.0:*' | grep -v '\[::\]:*' | grep -v '*:*' | grep -v 'localhost')
                tut_tool="ss"
                tcp_ip_location=5
            elif command -v netstat &>/dev/null; then
                # tcp_connections=\$(netstat -ant | grep '^tcp' | grep -v '0.0.0.0:*' | grep -v '\[::\]:*')
                # tcp_connections=\$(netstat -ant | grep '^tcp' | grep -v 'LISTEN')
                tcp_connections=\$(netstat -ant | grep '^tcp' | grep -v 'LISTEN' | sed -e 's/\(::ffff:\)\?//g' | grep -v '0.0.0.0:*' | grep -v '\[::\]:*' | grep -v ':::*' | grep -v 'localhost')
                tut_tool="netstat"
                tcp_ip_location=5
            else
                tut_errtips="\${RE}TCP 连接数获取失败!\${NC}"
            fi

            if command -v ss &>/dev/null; then
                # udp_connections=\$(ss -u | tail -n +2)
                # udp_connections=\$(ss -u | tail -n +2 | sed -e 's/\[\(::ffff:\)\?//g' -e 's/\]//g') # 注意 udp_ip_location 为4还是5?
                udp_connections=\$(ss -au | tail -n +2 | sed -e 's/\[\(::ffff:\)\?//g' -e 's/\]//g' | grep -v 'LISTEN' | grep -v '0.0.0.0:*' | grep -v '\[::\]:*' | grep -v '*:*' | grep -v 'localhost')
                tuu_tool="ss"
                udp_ip_location=5
            elif command -v netstat &>/dev/null; then
                # udp_connections=\$(netstat -anu | grep '^udp' | grep -v '0.0.0.0:*' | grep -v '\[::\]:*')
                # udp_connections=\$(netstat -anu | grep '^udp' | grep -v 'LISTEN')
                udp_connections=\$(netstat -anu | grep '^udp' | grep -v 'LISTEN' | sed -e 's/\(::ffff:\)\?//g' | grep -v '0.0.0.0:*' | grep -v '\[::\]:*' | grep -v ':::*' | grep -v 'localhost')
                tuu_tool="netstat"
                udp_ip_location=5
            else
                tuu_errtips="\${RE}UDP 连接数获取失败!\${NC}"
            fi

            tcp_local_connections=0
            tcp_external_connections=0
            tcp_external_details=()
            tcp_total=0
            tcp_num_estab_local=0
            tcp_num_estab_external=0

            udp_local_connections=0
            udp_external_connections=0
            udp_external_details=()
            udp_total=0
            # udp_num_estab_local=0
            # udp_num_estab_external=0

            # tcp_num_estab=\$(grep -c -E 'ESTABLISHED|ESTAB' <<< "\$tcp_connections")
            # udp_num_estab=\$(grep -c -E 'ESTABLISHED|ESTAB' <<< "\$udp_connections")

            # 定义本地IP地址范围
            local_ip_ranges=("0.0.0.0" "127.0.0.1" "[::" "fc" "fd" "fe" "localhost" "192.168" "10." "172.16" "172.17" "172.18" "172.19" "172.20" "172.21" "172.22" "172.23" "172.24" "172.25" "172.26" "172.27" "172.28" "172.29" "172.30" "172.31")

            if [[ ! -z "\$tcp_connections" ]]; then
                while IFS= read -r line; do
                    foreign_address=\$(echo \$line | awk -v var=\$tcp_ip_location '{print \$var}')
                    is_local=0
                    for ip_range in "\${local_ip_ranges[@]}"; do
                        if [[ \$foreign_address == \$ip_range* ]]; then
                            is_local=1
                            break
                        fi
                    done
                    if [[ \$is_local -eq 1 ]]; then
                        ((tcp_local_connections++))
                        if [[ \$line =~ ESTABLISHED|ESTAB ]]; then
                            ((tcp_num_estab_local++))
                        fi
                    else
                        ((tcp_external_connections++))
                        if [[ \$line =~ ESTABLISHED|ESTAB ]]; then
                            ((tcp_num_estab_external++))
                        fi
                        tcp_external_details+=("\$line")
                    fi
                    ((tcp_total++))
                done <<< "\$tcp_connections"
            fi
            if [[ ! -z "\$udp_connections" ]]; then
                while IFS= read -r line; do
                    if [[ \$line =~ ESTABLISHED|ESTAB ]]; then
                        ((udp_num_estab++))
                    fi
                    foreign_address=\$(echo \$line | awk -v var=\$udp_ip_location '{print \$var}')
                    is_local=0
                    for ip_range in "\${local_ip_ranges[@]}"; do
                        if [[ \$foreign_address == \$ip_range* ]]; then
                            is_local=1
                            break
                        fi
                    done
                    if [[ \$is_local -eq 1 ]]; then
                        ((udp_local_connections++))
                        # if [[ \$line =~ ESTABLISHED|ESTAB ]]; then
                        #     ((udp_num_estab_local++))
                        # fi
                    else
                        ((udp_external_connections++))
                        # if [[ \$line =~ ESTABLISHED|ESTAB ]]; then
                        #     ((udp_num_estab_external++))
                        # fi
                        udp_external_details+=("\$line")
                    fi
                    ((udp_total++))
                done <<< "\$udp_connections"
            fi
            tcp_num_unusual_local=\$((tcp_local_connections - tcp_num_estab_local))
            tcp_num_unusual_external=\$((tcp_external_connections - tcp_num_estab_external))
            # udp_num_unusual_local=\$((udp_local_connections - udp_num_estab_local))
            # udp_num_unusual_external=\$((udp_external_connections - udp_num_estab_external))
        fi
    else
        tx_speed=\$(Bytes_K_TGM "\$tx_speed_kb")
        max_tx_speed=\$(Bytes_K_TGM "\$max_tx_speed_kb")
        min_tx_speed=\$(Bytes_K_TGM "\$min_tx_speed_kb")
        avg_tx_speed=\$(Bytes_K_TGM "\$avg_tx_speed_kb")
    fi

    # rx_speed=\$(awk -v v1="\$sp_ov_rx_diff_speed" -v t1="\$TT" \
    #     'BEGIN {
    #         speed = v1 / (t1 * 1024)
    #         if (speed >= (1024 * 1024)) {
    #             printf "%.1fGB", speed/(1024 * 1024)
    #         } else if (speed >= 1024) {
    #             printf "%.1fMB", speed/1024
    #         } else {
    #             printf "%.1fKB", speed
    #         }
    #     }')
    # tx_speed=\$(awk -v v1="\$sp_ov_tx_diff_speed" -v t1="\$TT" \
    #     'BEGIN {
    #         speed = v1 / (t1 * 1024)
    #         if (speed >= (1024 * 1024)) {
    #             printf "%.1fGB", speed/(1024 * 1024)
    #         } else if (speed >= 1024) {
    #             printf "%.1fMB", speed/1024
    #         } else {
    #             printf "%.1fKB", speed
    #         }
    #     }')

    if [ \$CLEAR_TAG -eq 1 ]; then
        echo -e "DATE: \$(date +"%Y-%m-%d %H:%M:%S")" > \$FolderPath/interface_re.txt
        CLEAR_TAG=\$((CLEAR_TAG_OLD + 1))
        CLS
        echo -e " \${GRB}实时网速\${NC}                                 (\${TT}s)"
        echo " =================================================="
    else
        echo -e "DATE: \$(date +"%Y-%m-%d %H:%M:%S")" >> \$FolderPath/interface_re.txt
    fi

    if [ "\$ss_tag" == "st" ]; then
        echo -e "   接收: \${GR}\${rx_speedi}\${NC} /s   ( \${GR}\${rx_speedb}\${NC} /s )"
        echo -e "   发送: \${GR}\${tx_speedi}\${NC} /s   ( \${GR}\${tx_speedb}\${NC} /s )"
        echo " =================================================="
        echo -e " 统计接口: \$show_interfaces"
        echo " =================================================="

        echo -e " \${GRB}下\${NC}"
        echo -e "   MAX: \${GR}\$max_rx_speedi\${NC} /s   ( \${GR}\$max_rx_speedb\${NC} /s )"
        echo -e "   MIN: \${GR}\$min_rx_speedi\${NC} /s   ( \${GR}\$min_rx_speedb\${NC} /s )"
        echo -e "   AVG: \${GR}\$avg_rx_speedi\${NC} /s   ( \${GR}\$avg_rx_speedb\${NC} /s )"
        echo " --------------------------------------------------"
        echo -e " \${GRB}上\${NC}"
        echo -e "   MAX: \${GR}\$max_tx_speedi\${NC} /s   ( \${GR}\$max_tx_speedb\${NC} /s )"
        echo -e "   MIN: \${GR}\$min_tx_speedi\${NC} /s   ( \${GR}\$min_tx_speedb\${NC} /s )"
        echo -e "   AVG: \${GR}\$avg_tx_speedi\${NC} /s   ( \${GR}\$avg_tx_speedb\${NC} /s )"

        # 实时TCP/UDP连接数输出结果
        if [ "\$tu_show" == "true" ]; then
            echo " =================================================="
            # echo -e " \${GRB}TCP\${NC} 内网连接(\$tut_tool): \${GR}\$tcp_local_connections\${NC}  / \$tcp_total \$tut_errtips"
            # echo -e " \${GRB}TCP\${NC} 外网连接(\$tut_tool): \${GR}\$tcp_external_connections\${NC}  / \$tcp_total \$tut_errtips"
            echo -e " \${GRB}TCP\${NC} 内网连接(\$tut_tool): \${GR}\$tcp_num_estab_local\${NC}  / \${RE}\$tcp_num_unusual_local\${NC}  / \$tcp_total \$tut_errtips"
            echo -e " \${GRB}TCP\${NC} 外网连接(\$tut_tool): \${GR}\$tcp_num_estab_external\${NC}  / \${RE}\$tcp_num_unusual_external\${NC}  / \$tcp_total \$tut_errtips"
            # if [[ \$tcp_external_connections -gt 0 ]]; then
            #     echo "   TCP外部连接详情:"
            #     for detail in "\${tcp_external_details[@]}"; do
            #         echo "\$detail"
            #     done
            # fi
            echo " --------------------------------------------------"
            # echo -e " \${GRB}UDP\${NC} 内网连接(\$tuu_tool): \${GR}\$udp_local_connections\${NC}  / \$udp_total \$tuu_errtips"
            # echo -e " \${GRB}UDP\${NC} 外网连接(\$tuu_tool): \${GR}\$udp_external_connections\${NC}  / \$udp_total \$tuu_errtips"
            echo -e " \${GRB}UDP\${NC} 内网连接(\$tuu_tool): \${GR}\$udp_local_connections\${NC}  / \$udp_total \$tuu_errtips"
            echo -e " \${GRB}UDP\${NC} 外网连接(\$tuu_tool): \${GR}\$udp_external_connections\${NC}  / \$udp_total \$tuu_errtips"
            # if [[ \$udp_external_connections -gt 0 ]]; then
            #     echo "   UDP外部连接详情:"
            #     for detail in "\${udp_external_details[@]}"; do
            #         echo "\$detail"
            #     done
            # fi
            echo " --------------------------------------------------"
            echo -e " 数值说明: \${GR}正常连接\${NC}  / \${RE}非正常连接(TCP)\${NC}  / 总连接"
        fi
        echo "接收: \$rx_speedi  发送: \$tx_speedi" >> \$FolderPath/interface_re.txt
        echo "==============================================" >> \$FolderPath/interface_re.txt
    else
        rx_speed=\$(Remove_B "\$rx_speed")
        tx_speed=\$(Remove_B "\$tx_speed")
        max_rx_speed=\$(Remove_B "\$max_rx_speed")
        min_rx_speed=\$(Remove_B "\$min_rx_speed")
        avg_rx_speed=\$(Remove_B "\$avg_rx_speed")
        max_tx_speed=\$(Remove_B "\$max_tx_speed")
        min_tx_speed=\$(Remove_B "\$min_tx_speed")
        avg_tx_speed=\$(Remove_B "\$avg_tx_speed")

        echo -e " 接收: \${GR}\${rx_speed}\${NC} /s         发送: \${GR}\${tx_speed}\${NC} /s"
        echo " =================================================="
        echo -e " 统计接口: \$show_interfaces"
        echo " =================================================="

        echo -e " \${GRB}下\${NC} MAX: \${GR}\$max_rx_speed\${NC} /s   MIN: \${GR}\$min_rx_speed\${NC} /s   AVG: \${GR}\$avg_rx_speed\${NC} /s"
        echo " --------------------------------------------------"
        echo -e " \${GRB}上\${NC} MAX: \${GR}\$max_tx_speed\${NC} /s   MIN: \${GR}\$min_tx_speed\${NC} /s   AVG: \${GR}\$avg_tx_speed\${NC} /s"

        echo "接收: \$rx_speed  发送: \$tx_speed" >> \$FolderPath/interface_re.txt
        echo "==============================================" >> \$FolderPath/interface_re.txt
    fi

    CLEAR_TAG=\$((\$CLEAR_TAG - 1))
done
EOF
        chmod +x $FolderPath/tg_interface_re.sh
    # fi
    CLS
    echo -e "${RE}注意${NC}:  ${REB}按任意键中止${NC}"
    stty intr ^- # 禁用 CTRL+C
    divline
    $FolderPath/tg_interface_re.sh &
    tg_interface_re_pid=$!
    read -n 1 -s -r -p ""
    stty intr ^C # 恢复 CTRL+C
    # stty sane # 重置终端设置为默认值
    kill -2 $tg_interface_re_pid 2>/dev/null
    killpid "tg_interface_re"
    # pkill -f tg_interface_re
    # kill $(ps | grep '[t]g_interface_re' | awk '{print $1}') 2>/dev/null
    # pgrep -f tg_interface_re | xargs kill -9 2>/dev/null
    if pgrep -x tg_interface_re > /dev/null; then
        echo -e "中止失败!! 请执行以下指令中止!"
        echo -e "中止指令1: ${REB}pkill -f tg_interface_re${NC}"
        echo -e "中止指令2: ${REB}kill $(ps | grep '[t]g_interface_re' | awk '{print $1}') 2>/dev/null${NC}"
    fi
    divline
}

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
    ol_ver=$(curl -L -s --connect-timeout 5 "${ProxyURL}"https://raw.githubusercontent.com/redstarxxx/shell/main/VPSKeeper.sh | grep "sh_ver=" | head -1 | awk -F '=|"' '{print $3}')
    if [ -n "$ol_ver" ]; then
        if [[ "$sh_ver" != "$ol_ver" ]]; then
            echo -e "脚本更新中..."
            # curl -o VPSKeeper.sh https://raw.githubusercontent.com/redstarxxx/shell/main/VPSKeeper.sh && chmod +x VPSKeeper.sh
            wget -N --no-check-certificate "${ProxyURL}"https://raw.githubusercontent.com/redstarxxx/shell/main/VPSKeeper.sh && chmod +x VPSKeeper.sh
            echo -e "已更新完成, 请${GR}重新执行${NC}脚本."
            exit 0
        else
            tips="$Tip ${GR}当前版本已是最新版本!${NC}"
        fi
    else
        tips="$Err ${RE}脚本最新失败, 请检查网络连接!${NC}"
    fi
}
