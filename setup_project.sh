#!/bin/bash

# ====================================
# Zoom Chat Bot Project Setup Script
# ====================================

set -e

# Color definitions
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

print_status() { echo -e "${GREEN}[INFO]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }
print_header() { echo -e "${BLUE}=== $1 ===${NC}"; }

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATES_DIR="$SCRIPT_DIR/templates"
SCRIPTS_DIR="$SCRIPT_DIR/scripts"

# Global variables
PROJECT_DIR=""
PROJECT_NAME=""
AUTO_START=false

# Show help information
show_help() {
    echo "Usage: $0 [project_directory] [options]"
    echo ""
    echo "Initialize Zoom Chat Bot project"
    echo ""
    echo "Arguments:"
    echo "  project_directory   Target project directory (default: ./zoom-chatbot)"
    echo ""
    echo "Options:"
    echo "  -n, --name          Project name"
    echo "  -s, --start         Auto start after initialization"
    echo "  -h, --help          Show help information"
    echo ""
    echo "Examples:"
    echo "  $0                              # Initialize in default directory"
    echo "  $0 ./my-bot                     # Initialize in specified directory"
    echo "  $0 ./my-bot --name \"My Bot\"     # Specify project name"
    echo "  $0 ./my-bot --start             # Auto start after initialization"
}

# Parse command line arguments
parse_args() {
    PROJECT_DIR="${1:-./zoom-chatbot}"
    shift || true
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -n|--name)
                PROJECT_NAME="$2"
                shift 2
                ;;
            -s|--start)
                AUTO_START=true
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                print_error "Unknown parameter: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

# Check system environment
check_environment() {
    print_header "Checking System Environment"
    
    # Check Node.js
    if ! command -v node &> /dev/null; then
        print_error "Node.js not installed, please install Node.js 16+"
        echo "Installation methods:"
        echo "  Ubuntu/Debian: curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash - && sudo apt-get install -y nodejs"
        echo "  CentOS/RHEL: curl -fsSL https://rpm.nodesource.com/setup_18.x | sudo bash - && sudo yum install -y nodejs"
        echo "  macOS: brew install node"
        exit 1
    fi
    
    NODE_VERSION=$(node --version)
    NODE_MAJOR=$(echo $NODE_VERSION | cut -d'.' -f1 | cut -d'v' -f2)
    
    if [ "$NODE_MAJOR" -lt 16 ]; then
        print_error "Node.js version too low ($NODE_VERSION), requires 16+"
        exit 1
    fi
    
    print_status "Node.js version: $NODE_VERSION ✓"
    
    # Check npm
    if ! command -v npm &> /dev/null; then
        print_error "npm not installed"
        exit 1
    fi
    
    print_status "npm version: $(npm --version) ✓"
    
    # Check templates directory
    if [ ! -d "$TEMPLATES_DIR" ]; then
        print_error "Templates directory not found: $TEMPLATES_DIR"
        exit 1
    fi
    
    print_status "Environment check completed"
}

# Setup project directory
setup_project_directory() {
    print_header "Setting Up Project Directory"
    
    PROJECT_DIR=$(realpath "$PROJECT_DIR")
    
    if [ -d "$PROJECT_DIR" ]; then
        if [ "$(ls -A "$PROJECT_DIR" 2>/dev/null)" ]; then
            print_warning "Project directory $PROJECT_DIR is not empty"
            echo "Existing files:"
            ls -la "$PROJECT_DIR" | head -10
            
            read -p "Backup existing files and continue? (y/N): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                BACKUP_DIR="${PROJECT_DIR}.backup.$(date +%Y%m%d_%H%M%S)"
                print_status "Backing up to: $BACKUP_DIR"
                mv "$PROJECT_DIR" "$BACKUP_DIR"
            else
                print_status "Initialization cancelled"
                exit 0
            fi
        fi
    fi
    
    mkdir -p "$PROJECT_DIR"
    cd "$PROJECT_DIR"
    
    print_status "Project directory: $PROJECT_DIR"
}

# Copy template files
copy_templates() {
    print_header "Copying Project Templates"
    
    local files_copied=0
    
    # Copy all template files
    for file in "$TEMPLATES_DIR"/*; do
        if [ -f "$file" ]; then
            filename=$(basename "$file")
            
            if [ -f "$filename" ]; then
                read -p "$filename exists, overwrite? (y/N): " -n 1 -r
                echo
                if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                    print_status "Skipping $filename"
                    continue
                fi
            fi
            
            cp "$file" .
            print_status "Copied $filename"
            ((files_copied++))
        fi
    done
    
    # Copy .env.example to .env
    if [ ! -f ".env" ] && [ -f ".env.example" ]; then
        cp .env.example .env
        print_status "Created .env file"
        ((files_copied++))
    fi
    
    # Copy scripts directory
    if [ -d "$SCRIPTS_DIR" ]; then
        cp -r "$SCRIPTS_DIR" .
        chmod +x scripts/*.sh
        print_status "Copied scripts directory"
        ((files_copied++))
    fi
    
    # Create other necessary directories
    mkdir -p logs
    print_status "Created logs directory"
    
    # Create .gitignore
    if [ ! -f ".gitignore" ]; then
        cat > .gitignore << 'EOF'
# Dependencies
node_modules/
npm-debug.log*
yarn-debug.log*
yarn-error.log*

# Environment variables
.env
.env.local
.env.development.local
.env.test.local
.env.production.local

# Logs
logs/
*.log
*.pid

# Cache
.cache/
.tmp/

# System files
.DS_Store
Thumbs.db

# PM2
.pm2/

# Editors
.vscode/
.idea/
*.swp
*.swo

# Backup files
*.backup.*
EOF
        print_status "Created .gitignore file"
        ((files_copied++))
    fi
    
    print_status "Total copied $files_copied files/directories"
}

# Customize project configuration
customize_project() {
    print_header "Customizing Project Configuration"
    
    # Update project name in package.json
    if [ -n "$PROJECT_NAME" ] && [ -f "package.json" ]; then
        if command -v node &> /dev/null; then
            node -e "
                const fs = require('fs');
                const pkg = JSON.parse(fs.readFileSync('package.json', 'utf8'));
                pkg.name = '$PROJECT_NAME';
                pkg.description = '$PROJECT_NAME - Zoom Chat Bot';
                fs.writeFileSync('package.json', JSON.stringify(pkg, null, 2));
            "
            print_status "Updated project name: $PROJECT_NAME"
        fi
    fi
    
    # Prompt user to configure environment variables
    if [ -f ".env" ]; then
        print_warning "Please edit .env file to configure Zoom app credentials:"
        echo "  - ZOOM_CLIENT_ID"
        echo "  - ZOOM_CLIENT_SECRET" 
        echo "  - ZOOM_VERIFICATION_TOKEN"
        echo "  - DOMAIN_NAME"
        
        read -p "Edit configuration file now? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            # Try different editors
            if command -v code &> /dev/null; then
                code .env
            elif command -v nano &> /dev/null; then
                nano .env
            elif command -v vi &> /dev/null; then
                vi .env
            else
                print_warning "No suitable editor found, please manually edit .env file"
            fi
        fi
    fi
}

# Install dependencies
install_dependencies() {
    print_header "Installing Project Dependencies"
    
    if [ -f "$SCRIPTS_DIR/install_deps.sh" ]; then
        bash "$SCRIPTS_DIR/install_deps.sh"
    else
        print_status "Installing npm dependencies..."
        npm install
        print_status "Dependencies installation completed"
    fi
    
    # Ask whether to install global tools
    read -p "Install global development tools? (nodemon, pm2) (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        if ! command -v nodemon &> /dev/null; then
            print_status "Installing nodemon..."
            npm install -g nodemon
        fi
        
        if ! command -v pm2 &> /dev/null; then
            print_status "Installing PM2..."
            npm install -g pm2
        fi
    fi
}

# Initialize git repository
init_git() {
    print_header "Initializing Git Repository"
    
    if [ -d ".git" ]; then
        print_status "Git repository already exists"
        return
    fi
    
    read -p "Initialize Git repository? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        git init
        git add .
        git commit -m "Initialize Zoom Chat Bot project

🤖 Generated with [Claude Code](https://claude.ai/code)

Co-Authored-By: Claude <noreply@anthropic.com>"
        print_status "Git repository initialization completed"
    fi
}

# Start service
start_service() {
    if [ "$AUTO_START" = false ]; then
        return
    fi
    
    print_header "Starting Service"
    
    if [ -f "scripts/start_services.sh" ]; then
        bash scripts/start_services.sh pm2
    else
        npm start
    fi
}

# Show completion information
show_completion_info() {
    print_header "Project Initialization Completed"
    
    echo "🎉 Zoom Chat Bot project created successfully!"
    echo ""
    echo "📂 Project Information:"
    echo "  - Project directory: $PROJECT_DIR"
    echo "  - Project name: ${PROJECT_NAME:-zoom-chatbot}"
    echo "  - Node.js version: $(node --version)"
    echo ""
    echo "📋 Next Steps:"
    echo "  1. Edit .env file to configure Zoom app credentials"
    echo "  2. Start development server"
    echo ""
    echo "🚀 Start Commands:"
    echo "  npm start              # Direct start"
    echo "  npm run dev            # Development mode"
    echo "  npm run pm2:start      # PM2 management"
    echo "  bash scripts/start_services.sh  # Use startup script"
    echo ""
    echo "🔧 Other Commands:"
    echo "  npm test               # Run tests"
    echo "  npm run pm2:logs       # View logs"
    echo "  npm run pm2:status     # Check status"
    echo ""
    echo "📡 Access URLs (after startup):"
    echo "  - Homepage: http://localhost:3001"
    echo "  - Health check: http://localhost:3001/health"
    echo "  - Test console: http://localhost:3001/test"
    echo ""
    echo "📚 Configure Zoom App:"
    echo "  1. Visit https://marketplace.zoom.us/develop/create"
    echo "  2. Create General App, enable Team Chat Subscription"
    echo "  3. Add permissions: imchat:bot, imchat:write, imchat:read"
    echo "  4. Configure Webhook URL and OAuth callback URL"
    echo "  5. Copy credentials to .env file"
    echo ""
    
    if [ "$AUTO_START" = false ]; then
        echo "💡 Tip: Use --start parameter to auto-start service"
    fi
}

# Main function
main() {
    print_header "Zoom Chat Bot Project Initialization"
    
    parse_args "$@"
    check_environment
    setup_project_directory
    copy_templates
    customize_project
    install_dependencies
    init_git
    start_service
    show_completion_info
    
    print_status "Initialization completed! 🎉"
}

# Run main function
main "$@"