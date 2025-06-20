# VPSKeeper 完整功能文档

## 📋 项目概述

VPSKeeper 是一个功能强大的 Linux VPS 服务器监控和管理工具，提供全面的系统监控、Telegram 通知、AI 助手等功能。

### 🎯 主要特性

- **🔔 多种通知方式**: 开机、关机、登录、系统监控通知
- **📊 系统监控**: CPU、内存、磁盘、网络流量监控
- **🤖 AI 助手**: 集成 Google Gemini AI，提供智能问答和系统管理
- **🌐 Webhook 支持**: 支持 Telegram Webhook 和轮询模式
- **🔧 自动化管理**: 一键设置、自动更新、定时任务管理
- **🛡️ 系统兼容**: 支持多种 Linux 发行版和系统环境

---

## 🏗️ 系统架构

### 目录结构
```
VPSKeeper/
├── vpskeeper.sh              # 管理工具入口
├── README.md                 # 项目说明
├── lib/                      # 核心库
│   ├── core.sh              # 核心函数库
│   ├── colors.sh            # 颜色定义
│   ├── utils.sh             # 工具函数库
│   ├── loader.sh            # 智能加载器
│   └── menu.sh              # 主菜单程序
├── modules/                  # 功能模块
│   ├── monitoring/          # 监控模块
│   ├── notifications/       # 通知模块
│   └── system/              # 系统模块
└── runtime/                 # 运行时文件
```

### 核心组件

#### 1. **核心库 (lib/)**
- **core.sh**: 系统检查、配置管理、基础功能
- **utils.sh**: 工具函数、进程管理、数据处理
- **loader.sh**: 智能模块加载器
- **menu.sh**: 主菜单界面

#### 2. **监控模块 (modules/monitoring/)**
- **statusCheck.sh**: 系统状态检查
- **setupCPUTg.sh**: CPU 监控设置
- **setupMEMTg.sh**: 内存监控设置
- **setupDISKTg.sh**: 磁盘监控设置
- **setupFlowTg.sh**: 网络流量监控
- **setupFlowReportTg.sh**: 流量报告

#### 3. **通知模块 (modules/notifications/)**
- **setupBootTg.sh**: 开机通知设置
- **setupLoginTg.sh**: 登录通知设置
- **setupShutdownTg.sh**: 关机通知设置
- **setupDockerTg.sh**: Docker 监控通知
- **setupDDNSTg.sh**: DDNS 更新通知
- **testTg.sh**: 通知测试
- **unSetupTg.sh**: 通知取消设置

#### 4. **系统模块 (modules/system/)**
- **setupIniFile.sh**: 配置文件管理
- **setAutoUpdate.sh**: 自动更新设置
- **oneKeyDefault.sh**: 一键默认配置
- **update.sh**: 系统更新
- **hiddenADD.sh**: 隐藏功能
- **tgHandlerAi.sh**: AI 助手和 Webhook 处理

---

## 🚀 安装和使用

### 系统要求

- **操作系统**: Linux (Ubuntu, Debian, CentOS, Alpine 等)
- **依赖软件**: bash, curl, crontab
- **可选依赖**: systemd, nginx (用于 Webhook)
- **Python**: Python 3.6+ (用于 AI 功能)

### 快速安装

1. **下载项目**
   ```bash
   git clone https://github.com/redstarxxx/vpskeeper.git
   cd vpskeeper
   ```

2. **运行管理工具**
   ```bash
   bash vpskeeper.sh
   ```

3. **选择安装选项**
   - 选择 `1` 进行安装
   - 系统会自动检测本地文件或在线下载

4. **完成安装**
   - 安装完成后可使用 `vpskeeper` 命令启动

### 基本配置

1. **设置 Telegram Bot**
   - 在主菜单选择 `0` 进入参数设置
   - 输入 Bot Token 和 Chat ID
   - 可通过 @BotFather 创建 Bot
   - 通过 @userinfobot 获取 Chat ID

2. **测试通知**
   - 在主菜单选择相应的通知选项
   - 首次设置会自动发送测试消息

---

## 📱 功能详解

### 主菜单功能

```
================================
    VPSKeeper 主菜单
================================

1. 开机通知 | 已设置
2. 登录通知 | 未设置
3. 关机通知 | 已设置
4. CPU 监控 | 未设置
5. 内存监控 | 未设置
6. 磁盘监控 | 未设置
7. 流量监控 | 未设置
8. 流量报告 | 未设置
9. Docker 监控 | 未设置

t. 测试通知
h. 隐藏功能
o. 一键默认设置
c. 配置文件管理
f. 流量统计查看
u. 更新 VPSKeeper
v. 查看版本信息
x. 退出程序

0. 参数设置
```

### 通知功能

#### 1. **开机通知**
- 系统启动时自动发送通知
- 包含系统信息和启动时间
- 支持 systemd 和 init.d

#### 2. **登录通知**
- SSH 登录时发送通知
- 显示登录用户、IP 地址、时间
- 支持多用户环境

#### 3. **关机通知**
- 系统关闭前发送通知
- 包含运行时间统计
- 优雅关机处理

### 监控功能

#### 1. **CPU 监控**
- 实时监控 CPU 使用率
- 可设置阈值告警
- 支持多核心监控

#### 2. **内存监控**
- 监控内存使用情况
- 包含 swap 使用监控
- 内存不足时告警

#### 3. **磁盘监控**
- 监控磁盘空间使用
- 支持多分区监控
- 磁盘空间不足告警

#### 4. **流量监控**
- 网络流量实时监控
- 支持多网卡监控
- 流量异常告警

#### 5. **Docker 监控**
- Docker 容器状态监控
- 容器启动/停止通知
- 资源使用监控

### AI 助手功能

#### 1. **智能问答**
- 基于 Google Gemini AI
- 支持系统管理问题
- 每日使用限额控制

#### 2. **命令执行**
- 安全的命令白名单
- 远程系统管理
- 输出长度限制

#### 3. **系统信息**
- 自动收集系统信息
- 智能上下文理解
- 个性化回复

### Webhook 功能

#### 1. **HTTPS Webhook**
- 支持 SSL 证书配置
- Nginx 反向代理
- 高性能消息处理

#### 2. **HTTP 轮询**
- 无需 SSL 证书
- 适合测试环境
- 自动消息拉取

---

## ⚙️ 配置参数

### 基本配置

| 参数名 | 说明 | 示例值 |
|--------|------|--------|
| TelgramBotToken | Telegram Bot Token | 123456:ABC-DEF... |
| ChatID_1 | 主要接收者 Chat ID | 123456789 |
| hostname | 主机名 | MyServer |
| FolderPath | 配置文件路径 | /opt/vpskeeper/runtime |

### 监控配置

| 参数名 | 说明 | 默认值 |
|--------|------|--------|
| cpu_threshold | CPU 告警阈值 | 80% |
| mem_threshold | 内存告警阈值 | 80% |
| disk_threshold | 磁盘告警阈值 | 85% |
| flow_threshold | 流量告警阈值 | 1GB |

### AI 配置

| 参数名 | 说明 | 默认值 |
|--------|------|--------|
| GeminiAPIKey | Google AI API Key | - |
| MaxLines | 输出最大行数 | 10 |
| MaxChars | 输出最大字符数 | 800 |
| DAILY_LIMIT | 每日回复限额 | 80 |

### Webhook 配置

| 参数名 | 说明 | 默认值 |
|--------|------|--------|
| WebhookEnabled | Webhook 启用状态 | false |
| WebhookURL | Webhook URL | - |
| WebhookPort | Webhook 端口 | 8443 |
| WebhookPath | Webhook 路径 | /webhook |

---

## 🔧 高级功能

### 1. **一键默认设置**
- 快速配置常用监控
- 自动设置合理阈值
- 批量启用通知功能

### 2. **自动更新**
- 定期检查新版本
- 自动下载和安装
- 配置文件备份

### 3. **流量统计**
- 详细的流量使用报告
- 按时间段统计
- 图表化显示

### 4. **隐藏功能**
- 高级系统管理
- 调试和诊断工具
- 开发者选项

---

## 🛡️ 系统兼容性

### 支持的操作系统

- **Ubuntu**: 16.04+
- **Debian**: 9+
- **CentOS**: 7+
- **RHEL**: 7+
- **Fedora**: 28+
- **Alpine Linux**: 3.8+
- **OpenWRT**: 19.07+

### 兼容性特性

#### 1. **通用进程管理**
- 自动检测 `pgrep`/`pkill` 可用性
- 智能回退到 `ps` + `grep` + `kill`
- 支持不同的 `ps` 命令变体

#### 2. **服务管理兼容**
- 优先使用 systemd
- 自动回退到 init.d
- 支持 OpenWRT 等特殊环境

#### 3. **包管理兼容**
- 自动检测包管理器
- 支持 apt, yum, dnf, apk
- 智能依赖安装

---

## 📞 技术支持

### 常见问题

#### 1. **安装失败**
- 检查网络连接
- 确认系统权限
- 查看错误日志

#### 2. **通知不工作**
- 验证 Bot Token
- 检查 Chat ID
- 测试网络连通性

#### 3. **监控异常**
- 检查 crontab 设置
- 验证脚本权限
- 查看系统日志

### 日志文件

- **主日志**: `/opt/vpskeeper/runtime/vpskeeper.log`
- **Webhook 日志**: `/opt/vpskeeper/runtime/webhook.log`
- **消息日志**: `/opt/vpskeeper/runtime/message.json`

### 联系方式

- **GitHub**: https://github.com/redstarxxx/vpskeeper
- **Issues**: 通过 GitHub Issues 报告问题
- **Wiki**: 查看详细文档和教程

---

## 📄 许可证

本项目采用 MIT 许可证，详见 LICENSE 文件。

---

*最后更新：2024年12月16日*
