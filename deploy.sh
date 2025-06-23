#!/bin/bash

# ====================================
# Zoom聊天机器人一键部署脚本
# ====================================

set -e

# 颜色定义
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

print_status() { echo -e "${GREEN}[INFO]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }
print_header() { echo -e "${BLUE}=== $1 ===${NC}"; }

# 全局变量
DOMAIN_NAME=""
PROJECT_DIR=""
INSTALL_CADDY=false
INSTALL_PM2=false
SETUP_FIREWALL=false

# 检查系统要求
check_system() {
    print_header "检查系统环境"
    
    # 检查操作系统
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        print_status "操作系统: Linux"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        print_status "操作系统: macOS"
    else
        print_error "不支持的操作系统: $OSTYPE"
        exit 1
    fi
    
    # 检查权限
    if [ "$EUID" -eq 0 ]; then
        print_warning "检测到root权限，建议使用普通用户运行"
    fi
    
    # 检查网络连接
    if ! ping -c 1 google.com &> /dev/null; then
        print_warning "网络连接检查失败，请确保网络正常"
    fi
    
    print_status "系统环境检查完成"
}

# 安装Node.js
install_nodejs() {
    print_header "安装Node.js"
    
    if command -v node &> /dev/null; then
        NODE_VERSION=$(node --version)
        print_status "Node.js已安装: $NODE_VERSION"
        
        # 检查版本是否符合要求
        NODE_MAJOR=$(echo $NODE_VERSION | cut -d'.' -f1 | cut -d'v' -f2)
        if [ "$NODE_MAJOR" -lt 16 ]; then
            print_warning "Node.js版本过低，建议升级到16+版本"
        fi
        return
    fi
    
    print_status "安装Node.js 18.x..."
    
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        # Ubuntu/Debian
        if command -v apt-get &> /dev/null; then
            curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
            sudo apt-get install -y nodejs
        # CentOS/RHEL
        elif command -v yum &> /dev/null; then
            curl -fsSL https://rpm.nodesource.com/setup_18.x | sudo bash -
            sudo yum install -y nodejs
        else
            print_error "不支持的Linux发行版"
            exit 1
        fi
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        if command -v brew &> /dev/null; then
            brew install node
        else
            print_error "请先安装Homebrew"
            exit 1
        fi
    fi
    
    print_status "Node.js安装完成: $(node --version)"
}

# 安装PM2
install_pm2() {
    print_header "安装PM2"
    
    if command -v pm2 &> /dev/null; then
        print_status "PM2已安装: $(pm2 --version)"
        return
    fi
    
    print_status "安装PM2..."
    sudo npm install -g pm2
    
    print_status "PM2安装完成"
}

# 安装Caddy
install_caddy() {
    print_header "安装Caddy"
    
    if command -v caddy &> /dev/null; then
        print_status "Caddy已安装: $(caddy version)"
        return
    fi
    
    print_status "安装Caddy..."
    
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        # Ubuntu/Debian
        if command -v apt-get &> /dev/null; then
            sudo apt install -y debian-keyring debian-archive-keyring apt-transport-https
            curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
            curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/caddy-stable.list
            sudo apt update
            sudo apt install caddy
        # CentOS/RHEL
        elif command -v yum &> /dev/null; then
            yum install yum-plugin-copr
            yum copr enable @caddy/caddy
            yum install caddy
        fi
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        if command -v brew &> /dev/null; then
            brew install caddy
        fi
    fi
    
    print_status "Caddy安装完成"
}

# 配置防火墙
setup_firewall() {
    print_header "配置防火墙"
    
    if command -v ufw &> /dev/null; then
        print_status "配置UFW防火墙..."
        sudo ufw allow 22/tcp
        sudo ufw allow 80/tcp
        sudo ufw allow 443/tcp
        sudo ufw allow 3001/tcp
        sudo ufw --force enable
        print_status "UFW防火墙配置完成"
    elif command -v firewall-cmd &> /dev/null; then
        print_status "配置firewalld..."
        sudo firewall-cmd --permanent --add-service=ssh
        sudo firewall-cmd --permanent --add-service=http
        sudo firewall-cmd --permanent --add-service=https
        sudo firewall-cmd --permanent --add-port=3001/tcp
        sudo firewall-cmd --reload
        print_status "firewalld配置完成"
    else
        print_warning "未检测到防火墙工具，请手动配置防火墙"
    fi
}

# 获取用户输入
get_user_input() {
    print_header "配置部署参数"
    
    # 获取域名
    read -p "请输入域名 (例: bot.example.com): " DOMAIN_NAME
    if [ -z "$DOMAIN_NAME" ]; then
        print_error "域名不能为空"
        exit 1
    fi
    
    # 获取项目目录
    read -p "请输入项目目录 (默认: /opt/zoom-bot): " PROJECT_DIR
    if [ -z "$PROJECT_DIR" ]; then
        PROJECT_DIR="/opt/zoom-bot"
    fi
    
    # 询问是否安装Caddy
    read -p "是否安装Caddy作为反向代理? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        INSTALL_CADDY=true
    fi
    
    # 询问是否安装PM2
    read -p "是否安装PM2进程管理器? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        INSTALL_PM2=true
    fi
    
    # 询问是否配置防火墙
    read -p "是否配置防火墙? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        SETUP_FIREWALL=true
    fi
    
    print_status "配置参数确认:"
    echo "  域名: $DOMAIN_NAME"
    echo "  项目目录: $PROJECT_DIR"
    echo "  安装Caddy: $INSTALL_CADDY"
    echo "  安装PM2: $INSTALL_PM2"
    echo "  配置防火墙: $SETUP_FIREWALL"
    
    read -p "确认继续部署? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_status "部署取消"
        exit 0
    fi
}

# 下载和部署项目
deploy_project() {
    print_header "部署项目"
    
    # 创建项目目录
    print_status "创建项目目录: $PROJECT_DIR"
    sudo mkdir -p "$PROJECT_DIR"
    sudo chown $USER:$USER "$PROJECT_DIR"
    
    # 进入项目目录
    cd "$PROJECT_DIR"
    
    # 如果存在git仓库，从远程拉取
    if [ -d ".git" ]; then
        print_status "更新现有项目..."
        git pull
    else
        # 这里假设项目在某个git仓库中
        print_status "初始化项目..."
        
        # 如果有远程仓库，克隆项目
        # git clone https://github.com/hanzch/zoom_boot.git .
        
        # 如果没有远程仓库，使用本地模板
        print_status "使用本地模板创建项目..."
        
        # 获取脚本所在目录
        SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
        
        # 复制模板文件
        if [ -d "$SCRIPT_DIR/templates" ]; then
            cp -r "$SCRIPT_DIR/templates"/* .
        else
            print_error "模板目录不存在: $SCRIPT_DIR/templates"
            exit 1
        fi
        
        # 复制脚本文件
        if [ -d "$SCRIPT_DIR/scripts" ]; then
            cp -r "$SCRIPT_DIR/scripts" .
        fi
        
        # 复制setup脚本
        if [ -f "$SCRIPT_DIR/setup_project.sh" ]; then
            cp "$SCRIPT_DIR/setup_project.sh" .
        fi
        
        # 创建.gitignore
        cat > .gitignore << EOF
node_modules/
.env
logs/
*.log
.DS_Store
*.pid
EOF
    fi
    
    # 安装依赖
    print_status "安装项目依赖..."
    npm install
    
    # 配置环境变量
    if [ ! -f ".env" ]; then
        print_status "创建环境变量文件..."
        cp .env.example .env
        
        # 自动配置域名
        sed -i "s/your-domain.com/$DOMAIN_NAME/g" .env
        
        print_warning "请编辑 .env 文件配置Zoom应用凭证:"
        print_warning "  - ZOOM_CLIENT_ID"
        print_warning "  - ZOOM_CLIENT_SECRET"
        print_warning "  - ZOOM_VERIFICATION_TOKEN"
    fi
    
    print_status "项目部署完成"
}

# 配置Caddy
configure_caddy() {
    if [ "$INSTALL_CADDY" = false ]; then
        return
    fi
    
    print_header "配置Caddy"
    
    # 创建Caddy配置文件
    sudo tee /etc/caddy/Caddyfile > /dev/null <<EOF
$DOMAIN_NAME {
    # Webhook端点
    handle /webhook* {
        reverse_proxy localhost:3001
    }
    
    # OAuth回调
    handle /oauth* {
        reverse_proxy localhost:3001
    }
    
    # API和测试端点
    handle /test* /health* /api* {
        reverse_proxy localhost:3001
    }
    
    # 静态文件和其他请求
    handle {
        reverse_proxy localhost:3001
    }
    
    # 访问日志
    log {
        output file /var/log/caddy/access.log
        format json
    }
    
    # 错误日志
    log {
        output file /var/log/caddy/error.log
        level ERROR
    }
}
EOF
    
    # 创建日志目录
    sudo mkdir -p /var/log/caddy
    sudo chown caddy:caddy /var/log/caddy
    
    # 重启Caddy
    sudo systemctl restart caddy
    sudo systemctl enable caddy
    
    print_status "Caddy配置完成"
}

# 配置PM2
configure_pm2() {
    if [ "$INSTALL_PM2" = false ]; then
        return
    fi
    
    print_header "配置PM2"
    
    cd "$PROJECT_DIR"
    
    # 创建PM2配置文件
    cat > ecosystem.config.js << EOF
module.exports = {
    apps: [{
        name: 'zoom-bot',
        script: 'server.js',
        instances: 1,
        autorestart: true,
        watch: false,
        max_memory_restart: '512M',
        env: {
            NODE_ENV: 'production',
            PORT: 3001
        },
        log_file: 'logs/combined.log',
        out_file: 'logs/out.log',
        error_file: 'logs/error.log',
        log_date_format: 'YYYY-MM-DD HH:mm Z'
    }]
};
EOF
    
    # 创建日志目录
    mkdir -p logs
    
    # 启动PM2
    pm2 start ecosystem.config.js
    pm2 save
    pm2 startup
    
    print_status "PM2配置完成"
}

# 创建系统服务（如果不使用PM2）
create_systemd_service() {
    if [ "$INSTALL_PM2" = true ]; then
        return
    fi
    
    print_header "创建系统服务"
    
    # 创建systemd服务文件
    sudo tee /etc/systemd/system/zoom-bot.service > /dev/null <<EOF
[Unit]
Description=Zoom Chat Bot
After=network.target

[Service]
Type=simple
User=$USER
WorkingDirectory=$PROJECT_DIR
ExecStart=$(which node) server.js
Restart=always
RestartSec=10
Environment=NODE_ENV=production
Environment=PORT=3001

# 日志
StandardOutput=journal
StandardError=journal
SyslogIdentifier=zoom-bot

[Install]
WantedBy=multi-user.target
EOF
    
    # 重载systemd并启动服务
    sudo systemctl daemon-reload
    sudo systemctl enable zoom-bot
    sudo systemctl start zoom-bot
    
    print_status "系统服务创建完成"
}

# 显示部署结果
show_deployment_result() {
    print_header "部署完成"
    
    echo "🎉 Zoom聊天机器人部署成功！"
    echo ""
    echo "📋 部署信息："
    echo "  - 项目目录: $PROJECT_DIR"
    echo "  - 域名: $DOMAIN_NAME"
    echo "  - 本地端口: 3001"
    echo ""
    echo "🌐 访问地址："
    echo "  - 主页: https://$DOMAIN_NAME"
    echo "  - 健康检查: https://$DOMAIN_NAME/health"
    echo "  - 测试控制台: https://$DOMAIN_NAME/test"
    echo "  - Webhook: https://$DOMAIN_NAME/webhook"
    echo ""
    echo "⚙️  配置Zoom应用："
    echo "  1. 访问 https://marketplace.zoom.us/develop/create"
    echo "  2. 创建General App"
    echo "  3. 配置Webhook URL: https://$DOMAIN_NAME/webhook"
    echo "  4. 配置OAuth回调: https://$DOMAIN_NAME/oauth/callback"
    echo "  5. 编辑 $PROJECT_DIR/.env 文件填入应用凭证"
    echo ""
    echo "🔧 管理命令："
    
    if [ "$INSTALL_PM2" = true ]; then
        echo "  - 查看状态: pm2 status"
        echo "  - 查看日志: pm2 logs zoom-bot"
        echo "  - 重启服务: pm2 restart zoom-bot"
        echo "  - 停止服务: pm2 stop zoom-bot"
    else
        echo "  - 查看状态: sudo systemctl status zoom-bot"
        echo "  - 查看日志: sudo journalctl -u zoom-bot -f"
        echo "  - 重启服务: sudo systemctl restart zoom-bot"
        echo "  - 停止服务: sudo systemctl stop zoom-bot"
    fi
    
    if [ "$INSTALL_CADDY" = true ]; then
        echo "  - Caddy状态: sudo systemctl status caddy"
        echo "  - Caddy日志: sudo journalctl -u caddy -f"
        echo "  - 重载配置: sudo systemctl reload caddy"
    fi
    
    echo ""
    echo "📝 下一步："
    echo "  1. 编辑 $PROJECT_DIR/.env 配置Zoom凭证"
    echo "  2. 重启服务使配置生效"
    echo "  3. 测试机器人功能"
    echo ""
    echo "🔗 有用链接："
    echo "  - Zoom开发者文档: https://marketplace.zoom.us/docs"
    echo "  - 项目文档: https://$DOMAIN_NAME"
}

# 主函数
main() {
    print_header "Zoom聊天机器人一键部署"
    
    check_system
    get_user_input
    
    install_nodejs
    
    if [ "$INSTALL_PM2" = true ]; then
        install_pm2
    fi
    
    if [ "$INSTALL_CADDY" = true ]; then
        install_caddy
    fi
    
    if [ "$SETUP_FIREWALL" = true ]; then
        setup_firewall
    fi
    
    deploy_project
    configure_caddy
    configure_pm2
    create_systemd_service
    
    show_deployment_result
}

# 显示帮助
show_help() {
    echo "用法: $0 [选项]"
    echo ""
    echo "一键部署Zoom聊天机器人到服务器"
    echo ""
    echo "选项:"
    echo "  -h, --help     显示帮助信息"
    echo "  -q, --quiet    静默模式"
    echo ""
    echo "示例:"
    echo "  $0             # 交互式部署"
    echo "  curl -sSL https://raw.githubusercontent.com/hanzch/zoom_boot/main/deploy.sh | bash"
}

# 处理参数
case "$1" in
    -h|--help)
        show_help
        exit 0
        ;;
    -q|--quiet)
        # 静默模式，使用默认值
        DOMAIN_NAME="localhost"
        PROJECT_DIR="/opt/zoom-bot"
        INSTALL_CADDY=false
        INSTALL_PM2=true
        SETUP_FIREWALL=false
        ;;
    *)
        # 交互式模式
        ;;
esac

# 运行主函数
main "$@"