#!/usr/bin/env bash


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
    local base_desc="收到此信息后回复:服务器: $hostname\\n连接成功！欢迎使用vpskeeper助手!;\
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
        character_desc = "你是vpskeeper助手, 未找到角色描述文件, 也无法获取系统基本信息。"

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
    help_text = f"""vpskeeper 使用指南：

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
                    subprocess.Popen(['bash', '$FolderPath/vpskeeper.sh', function.rstrip('()')])
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
    universal_pkill "webhook_handler.py"

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
