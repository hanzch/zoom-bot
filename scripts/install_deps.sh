#!/bin/bash

# ====================================
# Zoom聊天机器人依赖安装脚本
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
INSTALL_GLOBAL_TOOLS=false
SKIP_PACKAGE_INSTALL=false
FORCE_REINSTALL=false

# 显示帮助信息
show_help() {
    echo "用法: $0 [选项]"
    echo ""
    echo "安装Zoom聊天机器人项目依赖"
    echo ""
    echo "选项:"
    echo "  -g, --global        安装全局开发工具 (nodemon, pm2)"
    echo "  -s, --skip-packages 跳过npm包安装"
    echo "  -f, --force         强制重新安装所有依赖"
    echo "  -h, --help          显示帮助信息"
    echo ""
    echo "示例:"
    echo "  $0                  # 标准安装"
    echo "  $0 --global         # 安装包含全局工具"
    echo "  $0 --force          # 强制重新安装"
    echo "  $0 -g -f            # 全局工具 + 强制重装"
}

# 处理命令行参数
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -g|--global)
                INSTALL_GLOBAL_TOOLS=true
                shift
                ;;
            -s|--skip-packages)
                SKIP_PACKAGE_INSTALL=true
                shift
                ;;
            -f|--force)
                FORCE_REINSTALL=true
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                print_error "未知参数: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

# 检查系统环境
check_system() {
    print_header "检查系统环境"
    
    # 检查操作系统
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        print_status "操作系统: Linux"
        OS_TYPE="linux"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        print_status "操作系统: macOS"
        OS_TYPE="macos"
    elif [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]]; then
        print_status "操作系统: Windows"
        OS_TYPE="windows"
    else
        print_warning "未知操作系统: $OSTYPE"
        OS_TYPE="unknown"
    fi
    
    # 检查可用内存
    if command -v free &> /dev/null; then
        MEMORY_MB=$(free -m | awk 'NR==2{printf "%.0f", $7}')
        if [ "$MEMORY_MB" -lt 512 ]; then
            print_warning "可用内存较低 (${MEMORY_MB}MB)，安装可能较慢"
        else
            print_status "可用内存: ${MEMORY_MB}MB"
        fi
    fi
    
    # 检查磁盘空间
    DISK_SPACE=$(df . | tail -1 | awk '{print $4}')
    if [ "$DISK_SPACE" -lt 1000000 ]; then
        print_warning "磁盘空间较低，请确保有足够空间安装依赖"
    fi
}

# 检查Node.js
check_nodejs() {
    print_header "检查Node.js环境"
    
    if ! command -v node &> /dev/null; then
        print_error "Node.js未安装，请先安装Node.js 16+"
        echo ""
        echo "🔧 安装方法："
        echo ""
        echo "📦 Ubuntu/Debian:"
        echo "  curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -"
        echo "  sudo apt-get install -y nodejs"
        echo ""
        echo "📦 CentOS/RHEL:"
        echo "  curl -fsSL https://rpm.nodesource.com/setup_18.x | sudo bash -"
        echo "  sudo yum install -y nodejs"
        echo ""
        echo "📦 macOS:"
        echo "  brew install node"
        echo ""
        echo "📦 Windows:"
        echo "  下载并安装: https://nodejs.org/en/download/"
        echo ""
        exit 1
    fi
    
    NODE_VERSION=$(node --version)
    NODE_MAJOR=$(echo $NODE_VERSION | cut -d'.' -f1 | cut -d'v' -f2)
    
    if [ "$NODE_MAJOR" -lt 16 ]; then
        print_error "Node.js版本过低 ($NODE_VERSION)，需要16+版本"
        exit 1
    fi
    
    print_status "Node.js版本: $NODE_VERSION ✓"
    
    # 检查npm
    if ! command -v npm &> /dev/null; then
        print_error "npm未安装"
        exit 1
    fi
    
    NPM_VERSION=$(npm --version)
    print_status "npm版本: $NPM_VERSION ✓"
    
    # 检查yarn（可选）
    if command -v yarn &> /dev/null; then
        YARN_VERSION=$(yarn --version)
        print_status "Yarn版本: $YARN_VERSION ✓"
    fi
}

# 配置npm设置
configure_npm() {
    print_header "配置npm设置"
    
    # 设置npm镜像（中国用户）
    read -p "是否使用淘宝npm镜像？(推荐中国用户使用) (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        npm config set registry https://registry.npmmirror.com
        print_status "已设置淘宝镜像"
    fi
    
    # 设置npm缓存目录
    if [ "$OS_TYPE" = "windows" ]; then
        CACHE_DIR="$HOME/AppData/Roaming/npm-cache"
    else
        CACHE_DIR="$HOME/.npm"
    fi
    
    if [ ! -d "$CACHE_DIR" ]; then
        mkdir -p "$CACHE_DIR"
        npm config set cache "$CACHE_DIR"
        print_status "创建npm缓存目录: $CACHE_DIR"
    fi
    
    # 显示当前配置
    print_status "当前npm配置:"
    echo "  - 镜像源: $(npm config get registry)"
    echo "  - 缓存目录: $(npm config get cache)"
}

# 清理环境（如果需要）
cleanup_environment() {
    if [ "$FORCE_REINSTALL" = true ]; then
        print_header "清理现有环境"
        
        if [ -d "node_modules" ]; then
            print_status "删除 node_modules 目录..."
            rm -rf node_modules
        fi
        
        if [ -f "package-lock.json" ]; then
            print_status "删除 package-lock.json..."
            rm -f package-lock.json
        fi
        
        if [ -f "yarn.lock" ]; then
            print_status "删除 yarn.lock..."
            rm -f yarn.lock
        fi
        
        # 清理npm缓存
        npm cache clean --force
        print_status "npm缓存已清理"
    fi
}

# 验证package.json
validate_package_json() {
    if [ ! -f "package.json" ]; then
        print_error "package.json文件不存在"
        print_error "请确保在正确的项目目录中运行此脚本"
        exit 1
    fi
    
    # 验证package.json格式
    if ! node -e "JSON.parse(require('fs').readFileSync('package.json', 'utf8'))" 2>/dev/null; then
        print_error "package.json格式错误"
        exit 1
    fi
    
    print_status "package.json验证通过"
    
    # 显示项目信息
    PROJECT_NAME=$(node -e "console.log(JSON.parse(require('fs').readFileSync('package.json', 'utf8')).name)" 2>/dev/null || echo "未知")
    PROJECT_VERSION=$(node -e "console.log(JSON.parse(require('fs').readFileSync('package.json', 'utf8')).version)" 2>/dev/null || echo "未知")
    
    print_status "项目名称: $PROJECT_NAME"
    print_status "项目版本: $PROJECT_VERSION"
}

# 安装项目依赖
install_packages() {
    if [ "$SKIP_PACKAGE_INSTALL" = true ]; then
        print_warning "跳过npm包安装"
        return
    fi
    
    print_header "安装项目依赖"
    
    # 检查是否已安装
    if [ -d "node_modules" ] && [ "$FORCE_REINSTALL" = false ]; then
        print_warning "node_modules已存在"
        read -p "是否重新安装依赖？(y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_status "跳过依赖安装"
            return
        fi
    fi
    
    # 选择包管理器
    PACKAGE_MANAGER="npm"
    if command -v yarn &> /dev/null; then
        read -p "检测到Yarn，是否使用Yarn安装？(y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            PACKAGE_MANAGER="yarn"
        fi
    fi
    
    print_status "使用 $PACKAGE_MANAGER 安装依赖..."
    
    # 显示安装进度
    if [ "$PACKAGE_MANAGER" = "yarn" ]; then
        yarn install
    else
        npm install
    fi
    
    print_status "项目依赖安装完成"
    
    # 验证关键依赖
    print_status "验证关键依赖..."
    REQUIRED_DEPS=("express" "axios" "dotenv" "body-parser")
    
    for dep in "${REQUIRED_DEPS[@]}"; do
        if [ -d "node_modules/$dep" ]; then
            print_status "✓ $dep"
        else
            print_warning "✗ $dep (可能影响功能)"
        fi
    done
}

# 安装全局工具
install_global_tools() {
    if [ "$INSTALL_GLOBAL_TOOLS" = false ]; then
        # 询问是否安装
        read -p "是否安装全局开发工具？(nodemon, pm2) (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            return
        fi
    fi
    
    print_header "安装全局开发工具"
    
    # 检查权限
    if ! npm list -g --depth=0 &>/dev/null; then
        print_warning "可能需要管理员权限安装全局包"
        if [[ "$OSTYPE" != "msys" ]] && [[ "$OSTYPE" != "cygwin" ]]; then
            print_warning "如果安装失败，请使用: sudo npm install -g [包名]"
        fi
    fi
    
    # 安装nodemon
    if ! command -v nodemon &> /dev/null; then
        print_status "安装 nodemon..."
        if npm install -g nodemon; then
            print_status "✓ nodemon安装完成"
        else
            print_warning "✗ nodemon安装失败"
        fi
    else
        NODEMON_VERSION=$(nodemon --version)
        print_status "✓ nodemon已安装: $NODEMON_VERSION"
    fi
    
    # 安装PM2
    if ! command -v pm2 &> /dev/null; then
        print_status "安装 PM2..."
        if npm install -g pm2; then
            print_status "✓ PM2安装完成"
        else
            print_warning "✗ PM2安装失败"
        fi
    else
        PM2_VERSION=$(pm2 --version)
        print_status "✓ PM2已安装: $PM2_VERSION"
    fi
    
    # 安装其他有用工具（可选）
    read -p "是否安装其他有用工具？(http-server, npx) (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        if ! command -v http-server &> /dev/null; then
            npm install -g http-server && print_status "✓ http-server安装完成"
        fi
    fi
}

# 设置开发环境
setup_development_environment() {
    print_header "设置开发环境"
    
    # 创建必要目录
    mkdir -p logs
    print_status "创建 logs 目录"
    
    # 设置环境变量文件
    if [ ! -f ".env" ] && [ -f ".env.example" ]; then
        cp .env.example .env
        print_status "创建 .env 文件"
        print_warning "请编辑 .env 文件配置Zoom应用凭证"
    fi
    
    # 设置Git hooks（如果存在Git仓库）
    if [ -d ".git" ]; then
        print_status "检测到Git仓库"
        
        # 创建pre-commit hook
        if [ ! -f ".git/hooks/pre-commit" ]; then
            cat > .git/hooks/pre-commit << 'EOF'
#!/bin/bash
# 运行基本检查
if [ -f "package.json" ]; then
    echo "运行npm test..."
    npm test
fi
EOF
            chmod +x .git/hooks/pre-commit
            print_status "创建Git pre-commit hook"
        fi
    fi
}

# 运行后安装脚本
run_postinstall() {
    print_header "运行后安装脚本"
    
    # 检查是否有postinstall脚本
    if [ -f "package.json" ]; then
        POSTINSTALL_SCRIPT=$(node -e "console.log(JSON.parse(require('fs').readFileSync('package.json', 'utf8')).scripts?.postinstall || '')" 2>/dev/null)
        if [ -n "$POSTINSTALL_SCRIPT" ]; then
            print_status "运行postinstall脚本..."
            npm run postinstall
        fi
    fi
    
    # 运行测试确保安装正确
    if npm run test &>/dev/null; then
        print_status "✓ 基本测试通过"
    else
        print_warning "测试未通过，但这可能是正常的"
    fi
}

# 显示安装结果
show_installation_result() {
    print_header "安装完成"
    
    echo "🎉 依赖安装完成！"
    echo ""
    echo "📊 安装统计:"
    
    if [ -f "package.json" ]; then
        DEPS_COUNT=$(node -e "console.log(Object.keys(JSON.parse(require('fs').readFileSync('package.json', 'utf8')).dependencies || {}).length)" 2>/dev/null || echo "0")
        DEVDEPS_COUNT=$(node -e "console.log(Object.keys(JSON.parse(require('fs').readFileSync('package.json', 'utf8')).devDependencies || {}).length)" 2>/dev/null || echo "0")
        echo "  - 生产依赖: $DEPS_COUNT 个"
        echo "  - 开发依赖: $DEVDEPS_COUNT 个"
    fi
    
    if [ -d "node_modules" ]; then
        MODULES_SIZE=$(du -sh node_modules 2>/dev/null | cut -f1 || echo "未知")
        echo "  - node_modules大小: $MODULES_SIZE"
    fi
    
    echo ""
    echo "🔧 已安装的全局工具:"
    command -v nodemon &>/dev/null && echo "  ✓ nodemon: $(nodemon --version)"
    command -v pm2 &>/dev/null && echo "  ✓ PM2: $(pm2 --version)"
    
    echo ""
    echo "🚀 下一步操作:"
    echo "  1. 编辑 .env 文件配置环境变量"
    echo "  2. 运行 npm start 启动项目"
    echo "  3. 或运行 npm run dev 进入开发模式"
    echo ""
    echo "💡 有用命令:"
    echo "  npm run dev        # 开发模式"
    echo "  npm run pm2:start  # PM2启动"
    echo "  npm run pm2:logs   # 查看日志"
    echo "  npm test           # 运行测试"
}

# 主函数
main() {
    print_header "Zoom聊天机器人依赖安装"
    
    parse_args "$@"
    check_system
    check_nodejs
    configure_npm
    cleanup_environment
    validate_package_json
    install_packages
    install_global_tools
    setup_development_environment
    run_postinstall
    show_installation_result
    
    print_status "安装脚本执行完成！"
}

# 运行主函数
main "$@"