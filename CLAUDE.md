# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Language Preference

**IMPORTANT: Always communicate in Chinese (中文) when working with this repository.** This project is primarily designed for Chinese users, and all responses should be in Chinese to maintain consistency with the project's documentation and target audience.

## Project Overview

This is a Zoom Team Chat bot project template generator. The repository contains setup scripts and templates for creating a fully functional Zoom chatbot with webhook integration, OAuth authentication, and automated deployment capabilities.

## Architecture

### Structure
- `setup_project.sh` - Main project initialization script that orchestrates the setup process
- `templates/` - Contains template files for the generated project:
  - `package.json` - Node.js project configuration with Zoom bot dependencies
  - `README.md` - Comprehensive documentation template in Chinese
  - `.env.example` - Environment variables template with Zoom API credentials
- `scripts/` - Setup automation scripts:
  - `install_deps.sh` - Dependency installation and environment verification
  - `start_services.sh` - Service startup script (currently empty)

### Generated Project Components
The setup script creates a Zoom bot project with:
- Express.js server for webhook handling
- Zoom API integration with OAuth authentication
- PM2 process management support
- Caddy reverse proxy configuration
- Comprehensive error handling and logging

## Development Commands

### Project Setup
```bash
# Initialize new bot project
./setup_project.sh [project_directory]

# Install dependencies manually
bash scripts/install_deps.sh
```

### Generated Project Commands
Once a project is created using the templates, these commands are available:

```bash
# Development
npm start          # Start the bot server
npm run dev        # Development mode with nodemon
npm test           # Run tests

# PM2 Process Management
npm run pm2:start    # Start with PM2
npm run pm2:stop     # Stop PM2 process
npm run pm2:restart  # Restart PM2 process
npm run pm2:logs     # View PM2 logs
npm run pm2:status   # Check PM2 status
npm run pm2:delete   # Delete PM2 process
```

## Configuration

### Environment Variables
The generated project requires these Zoom API credentials in `.env`:
- `ZOOM_CLIENT_ID` - Zoom app client ID
- `ZOOM_CLIENT_SECRET` - Zoom app client secret
- `ZOOM_VERIFICATION_TOKEN` - Webhook verification token
- `PORT` - Server port (default: 3001)
- `DOMAIN_NAME` - Domain for webhook URLs

### Zoom App Setup
Generated projects require a Zoom General App with:
- Team Chat Subscription enabled
- OAuth permissions: `imchat:bot`, `imchat:write`, `imchat:read`
- Webhook endpoint configured to `https://domain.com/webhook`
- OAuth redirect URL set to `https://domain.com/oauth/callback`

## Key Features

### Bot Capabilities
- Intelligent message processing and auto-reply
- Command system (hello, help, time, ping, info)
- Multi-language support (Chinese/English)
- Real-time webhook message handling

### Infrastructure
- PM2 process management with auto-restart
- Caddy reverse proxy with automatic HTTPS
- Health monitoring endpoints
- Comprehensive logging and error handling
- OAuth authentication flow

## Testing

Generated projects include test endpoints:
- `GET /health` - Health check and configuration status
- `POST /test-send-message` - Message sending test
- `GET /test` - Web-based testing console