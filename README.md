# 🤖 Zoom聊天机器人

功能强大、易于部署的Zoom Team Chat智能机器人，支持自动回复、命令处理和实时消息响应。

## 🚀 快速开始

### 一键部署
```bash
# 下载并运行初始化脚本
curl -sSL https://raw.githubusercontent.com/hanzch/zoom_boot/main/setup_project.sh | bash

# 或本地初始化
./setup_project.sh ./my-zoom-bot --start
```

### 手动安装
```bash
# 1. 创建项目
git clone https://github.com/hanzch/zoom_boot.git
cd zoom_boot

# 2. 初始化项目
./setup_project.sh ./zoom-chatbot

# 3. 配置环境变量
cd zoom-chatbot
nano .env  # 填入Zoom应用凭证

# 4. 启动服务
npm run pm2:start
```

## ⚙️ 配置说明

### 必需配置
```env
ZOOM_CLIENT_ID=your_client_id_here
ZOOM_CLIENT_SECRET=your_client_secret_here  
ZOOM_VERIFICATION_TOKEN=your_verification_token_here
DOMAIN_NAME=your-domain.com
```

### Zoom应用设置
1. 访问 [Zoom Marketplace](https://marketplace.zoom.us/develop/create)
2. 创建 **General App**，启用 **Team Chat Subscription**
3. 添加权限：`imchat:bot`, `imchat:write`, `imchat:read`
4. 配置URL：
   - **Webhook**: `https://your-domain.com/webhook`
   - **OAuth回调**: `https://your-domain.com/oauth/callback`

## 🤖 机器人功能

### 支持的命令
- `hello/hi/你好` - 问候机器人
- `help/帮助` - 显示帮助信息
- `time/时间` - 查看当前时间
- `ping` - 测试连接状态
- `info/信息` - 查看机器人信息

### 智能回复
机器人会对所有消息进行智能回复，提供友好的用户交互体验。

## 🔧 管理命令

### 服务管理
```bash
# PM2管理
npm run pm2:start    # 启动服务
npm run pm2:status   # 查看状态
npm run pm2:logs     # 查看日志
npm run pm2:restart  # 重启服务
npm run pm2:stop     # 停止服务

# 开发模式
npm start            # 直接启动
npm run dev          # 开发模式（自动重启）
```

### 脚本工具
```bash
# 使用启动脚本（推荐）
bash scripts/start_services.sh pm2     # PM2启动
bash scripts/start_services.sh dev     # 开发模式
bash scripts/start_services.sh         # 交互式选择

# 重新安装依赖
bash scripts/install_deps.sh --force   # 强制重装
bash scripts/install_deps.sh --global  # 安装全局工具
```

## 🧪 测试和调试

### 测试接口
- 健康检查: `http://localhost:3001/health`
- 测试控制台: `http://localhost:3001/test`
- API测试: `POST /test-send-message`

### 调试方法
```bash
# 查看详细日志
export ENABLE_DETAILED_LOGS=true
npm start

# 实时日志监控
pm2 logs zoom-bot --lines 100

# 测试Webhook
curl -X POST http://localhost:3001/webhook \
  -H "Content-Type: application/json" \
  -H "Authorization: your_verification_token" \
  -d '{"event": "bot_notification", "payload": {"cmd": "hello", "userName": "测试"}}'
```

## 🌐 生产部署

### 使用一键部署脚本
```bash
# 下载部署脚本
curl -sSL https://raw.githubusercontent.com/hanzch/zoom_boot/main/deploy.sh -o deploy.sh
chmod +x deploy.sh

# 运行部署（自动安装Node.js、PM2、Caddy等）
sudo ./deploy.sh
```

### 手动部署
```bash
# 1. 安装环境
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get install -y nodejs caddy
npm install -g pm2

# 2. 配置反向代理（Caddy）
sudo nano /etc/caddy/Caddyfile
# 添加配置后重启：sudo systemctl reload caddy

# 3. 启动服务
pm2 start server.js --name zoom-bot
pm2 startup && pm2 save
```

## 🛡️ 安全特性

- **环境变量保护** - 敏感信息隔离存储
- **Webhook验证** - 请求来源合法性检查  
- **错误处理** - 完善的异常捕获机制
- **访问日志** - 详细的请求响应记录

## 📊 项目结构

```
zoom-chatbot/
├── server.js           # 主服务器文件
├── package.json        # 项目配置
├── .env               # 环境变量（自动生成）
├── scripts/           # 管理脚本
│   ├── start_services.sh   # 启动服务脚本
│   └── install_deps.sh     # 依赖安装脚本
├── logs/              # 日志目录
└── README.md          # 项目文档
```

## 🚨 故障排除

### 常见问题
1. **机器人无响应** - 检查Zoom权限配置和Webhook URL
2. **端口冲突** - 修改.env中的PORT配置
3. **依赖安装失败** - 使用 `scripts/install_deps.sh --force`

### 诊断命令
```bash
# 系统状态检查
curl http://localhost:3001/health
pm2 status

# 网络连接测试  
ping your-domain.com
curl -I https://your-domain.com

# 日志分析
pm2 logs zoom-bot --lines 50
tail -f logs/service.log
```

## 📝 开发说明

### 本地开发
```bash
# 安装依赖并启动开发模式
npm install
npm run dev
```

### API接口
- `POST /webhook` - 接收Zoom消息
- `GET /health` - 健康检查
- `GET /test` - 测试控制台
- `POST /test-send-message` - 消息发送测试

## 🤝 贡献

欢迎提交Issue和Pull Request！

### 提交规范
- `feat:` 新功能
- `fix:` Bug修复  
- `docs:` 文档更新
- `chore:` 维护性更改

---

## 📞 支持

- **问题反馈**: [GitHub Issues](https://github.com/hanzch/zoom_boot/issues)
- **文档**: [项目Wiki](https://github.com/hanzch/zoom_boot/wiki)
- **相关链接**: [Zoom API文档](https://marketplace.zoom.us/docs/api-reference/zoom-api)

<div align="center">

**⭐ 如果这个项目对你有帮助，请给我们一个Star！**

</div>