#!/bin/bash

# ====================================
# Zoom机器人部署修复脚本
# ====================================

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

print_status() { echo -e "${GREEN}[INFO]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

PROJECT_DIR="/opt/zoom-bot"

# 检查是否在正确的目录
if [ ! -d "$PROJECT_DIR" ]; then
    print_error "项目目录不存在: $PROJECT_DIR"
    exit 1
fi

cd "$PROJECT_DIR"
print_status "进入项目目录: $PROJECT_DIR"

# 检查当前状态
print_status "检查当前目录内容:"
ls -la

# 如果package.json不存在，从GitHub克隆
if [ ! -f "package.json" ]; then
    print_warning "package.json不存在，尝试修复..."
    
    # 备份.env文件（如果存在）
    if [ -f ".env" ]; then
        cp .env .env.backup
        print_status "备份.env文件"
    fi
    
    # 清空目录（保留.git和.env.backup）
    find . -maxdepth 1 -not -name '.' -not -name '..' -not -name '.git' -not -name '.env.backup' -exec rm -rf {} +
    
    # 从GitHub克隆项目文件
    print_status "从GitHub获取项目文件..."
    if git clone https://github.com/hanzch/zoom-bot.git temp_clone; then
        # 移动文件到当前目录
        mv temp_clone/* .
        mv temp_clone/.* . 2>/dev/null || true
        rm -rf temp_clone
        print_status "项目文件获取成功"
        
        # 恢复.env文件
        if [ -f ".env.backup" ]; then
            mv .env.backup .env
            print_status "恢复.env文件"
        fi
    else
        print_error "从GitHub获取文件失败"
        exit 1
    fi
fi

# 验证文件
if [ -f "package.json" ]; then
    print_status "✓ package.json 存在"
else
    print_error "✗ package.json 仍然不存在"
    exit 1
fi

if [ -f "server.js" ]; then
    print_status "✓ server.js 存在"
else
    print_error "✗ server.js 不存在"
    exit 1
fi

# 安装依赖
print_status "安装npm依赖..."
npm install

# 创建.env文件（如果不存在）
if [ ! -f ".env" ]; then
    if [ -f ".env.example" ]; then
        cp .env.example .env
        print_warning "已创建.env文件，请编辑配置Zoom凭证"
    else
        print_warning ".env.example文件不存在，请手动创建.env文件"
    fi
fi

# 创建日志目录
mkdir -p logs

print_status "修复完成！"
print_status "下一步："
print_status "1. 编辑 .env 文件配置Zoom应用凭证"
print_status "2. 运行 npm start 或 pm2 start server.js 启动服务"