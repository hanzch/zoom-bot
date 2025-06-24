const express = require('express');
const bodyParser = require('body-parser');
const axios = require('axios');
const fs = require('fs');
const path = require('path');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 3001;

// 创建日志目录
const logsDir = path.join(__dirname, 'logs');
if (!fs.existsSync(logsDir)) {
    fs.mkdirSync(logsDir, { recursive: true });
}

app.use(bodyParser.json());
app.use(bodyParser.urlencoded({ extended: true }));

// 全局变量存储访问令牌和机器人信息
let accessToken = null;
let tokenExpiryTime = null;
let botAccountId = null;
let botRobotJid = null;

// 增强的日志函数
const log = (message, level = 'INFO') => {
    const timestamp = new Date().toISOString();
    const logMessage = `[${timestamp}] [${level}] ${message}`;
    
    // 输出到控制台
    console.log(logMessage);
    
    // 写入日志文件
    try {
        const logFile = path.join(logsDir, 'run.log');
        fs.appendFileSync(logFile, logMessage + '\n');
    } catch (error) {
        console.error('Failed to write log:', error.message);
    }
};

// 进程启动日志
log('='.repeat(50));
log('Zoom Chat Bot Starting...');
log(`Node.js version: ${process.version}`);
log(`Environment: ${process.env.NODE_ENV || 'development'}`);
log(`Port: ${PORT}`);

// 获取访问令牌
async function getAccessToken() {
    // 检查令牌是否仍然有效
    if (accessToken && tokenExpiryTime && Date.now() < tokenExpiryTime) {
        return accessToken;
    }

    // 检查必要的环境变量
    if (!process.env.ZOOM_CLIENT_ID || !process.env.ZOOM_CLIENT_SECRET) {
        const error = new Error('Missing required Zoom credentials (ZOOM_CLIENT_ID or ZOOM_CLIENT_SECRET)');
        log(error.message, 'ERROR');
        throw error;
    }

    try {
        const authString = Buffer.from(`${process.env.ZOOM_CLIENT_ID}:${process.env.ZOOM_CLIENT_SECRET}`).toString('base64');
        
        const requestData = {
            grant_type: 'client_credentials'
        };
        
        // 如果有Account ID，使用Server-to-Server OAuth
        if (process.env.ZOOM_ACCOUNT_ID) {
            requestData.account_id = process.env.ZOOM_ACCOUNT_ID;
        }

        log('Requesting access token...');
        const response = await axios.post('https://zoom.us/oauth/token', null, {
            params: requestData,
            headers: {
                'Authorization': `Basic ${authString}`,
                'Content-Type': 'application/x-www-form-urlencoded'
            }
        });

        if (!response.data.access_token) {
            throw new Error('No access token in response');
        }

        accessToken = response.data.access_token;
        // 设置过期时间为获取时间 + 有效期（减去5分钟缓冲）
        tokenExpiryTime = Date.now() + (response.data.expires_in - 300) * 1000;
        
        log('Access token obtained successfully');
        return accessToken;
    } catch (error) {
        const errorMsg = error.response ? 
            `API Error: ${error.response.status} - ${JSON.stringify(error.response.data)}` : 
            `Network Error: ${error.message}`;
        log(`Failed to get access token: ${errorMsg}`, 'ERROR');
        throw error;
    }
}

// 检查是否为测试JID
function isTestJid(jid) {
    const testJids = [
        'test@xmpp.zoom.us',
        'bot@xmpp.zoom.us',
        'user@xmpp.zoom.us'
    ];
    return testJids.includes(jid);
}

// 发送消息到Zoom
async function sendMessage(toJid, message, robotJid) {
    log(`Attempting to send message - toJid: ${toJid}, robotJid: ${robotJid}`, 'INFO');
    
    // 检查是否为测试模式
    if (isTestJid(toJid) || isTestJid(robotJid)) {
        log(`Test mode detected: Would send message to ${toJid}: ${message}`);
        return {
            success: true,
            message: 'Test message sent successfully',
            to_jid: toJid,
            robot_jid: robotJid,
            test_mode: true
        };
    }

    try {
        const token = await getAccessToken();
        log(`Access token obtained, preparing API request`, 'INFO');
        
        // 使用保存的机器人信息（如果可用）
        const finalAccountId = botAccountId || process.env.ZOOM_ACCOUNT_ID;
        const finalRobotJid = botRobotJid || robotJid;
        
        // 记录完整的请求数据 - 使用正确的API格式
        const requestData = {
            robot_jid: finalRobotJid,
            to_jid: toJid,
            account_id: finalAccountId,
            content: {
                head: {
                    text: "Zoom Bot"
                },
                body: [
                    {
                        type: "message",
                        text: message
                    }
                ]
            }
        };
        log(`API Request Data: ${JSON.stringify(requestData)}`, 'INFO');
        
        const response = await axios.post('https://api.zoom.us/v2/im/chat/messages', requestData, {
            headers: {
                'Authorization': `Bearer ${token}`,
                'Content-Type': 'application/json'
            }
        });

        log(`Message sent successfully to ${toJid}: ${message}`);
        return response.data;
    } catch (error) {
        log(`Failed to send message: ${error.message}`, 'ERROR');
        log(`Error code: ${error.code}`, 'ERROR');
        log(`Request URL: https://api.zoom.us/v2/im/chat/messages`, 'ERROR');
        
        if (error.response) {
            log(`HTTP Status: ${error.response.status}`, 'ERROR');
            log(`Response Headers: ${JSON.stringify(error.response.headers)}`, 'ERROR');
            log(`Response Data: ${JSON.stringify(error.response.data)}`, 'ERROR');
        }
        
        if (error.config) {
            log(`Request Headers: ${JSON.stringify(error.config.headers)}`, 'ERROR');
            log(`Request Data: ${JSON.stringify(error.config.data)}`, 'ERROR');
        }
        
        throw error;
    }
}

// 处理机器人命令
function processCommand(cmd, userName) {
    const command = cmd.toLowerCase().trim();
    
    switch (command) {
        case 'hello':
        case 'hi':
        case '你好':
            return `你好 ${userName}！我是Zoom聊天机器人 🤖\n\n试试发送以下命令：\n• help - 查看帮助\n• time - 查看时间\n• ping - 测试连接\n• info - 查看机器人信息`;
            
        case 'help':
        case '帮助':
            return `🤖 **Zoom聊天机器人帮助**\n\n**可用命令：**\n• hello/hi/你好 - 问候机器人\n• help/帮助 - 显示此帮助信息\n• time/时间 - 查看当前时间\n• ping - 测试机器人连接状态\n• info/信息 - 查看机器人版本信息\n\n**使用说明：**\n直接发送命令即可，机器人会自动回复！`;
            
        case 'time':
        case '时间':
            const now = new Date();
            return `🕐 **当前时间**\n${now.toLocaleString('zh-CN', { timeZone: 'Asia/Shanghai' })}`;
            
        case 'ping':
            return `🏓 **Pong!**\n\n系统状态：✅ 运行正常\n响应时间：< 100ms\n服务器时间：${new Date().toISOString()}`;
            
        case 'info':
        case '信息':
            return `🤖 **机器人信息**\n\n**版本：** 1.0.0\n**状态：** 🟢 在线\n**功能：** 智能聊天、命令处理\n**支持：** 中文/英文\n**运行时间：** ${Math.floor(process.uptime())} 秒`;
            
        default:
            return `我收到了你的消息："${cmd}"\n\n🤖 我是智能聊天机器人，试试发送：\n• help - 查看帮助\n• time - 查看时间\n• ping - 测试连接`;
    }
}

// Webhook验证端点 - 处理Zoom的GET验证请求
app.get('/webhook', (req, res) => {
    const { challenge } = req.query;
    log(`Webhook verification request - challenge: ${challenge}`, 'INFO');
    
    if (challenge) {
        // 返回challenge以验证webhook
        res.json({ challenge });
    } else {
        res.status(400).json({ error: 'Missing challenge parameter' });
    }
});

// 调试端点 - 记录所有到达webhook的请求
app.all('/webhook-debug', (req, res) => {
    log(`DEBUG - Method: ${req.method}, Headers: ${JSON.stringify(req.headers)}`, 'INFO');
    log(`DEBUG - Query: ${JSON.stringify(req.query)}`, 'INFO');
    log(`DEBUG - Body: ${JSON.stringify(req.body)}`, 'INFO');
    res.json({ status: 'debug', method: req.method, received: true });
});

// Webhook端点 - 接收Zoom消息
app.post('/webhook', async (req, res) => {
    try {
        log(`Received webhook request from ${req.ip}`);
        
        // 更灵活的验证逻辑
        const verificationToken = req.headers['authorization'] || req.headers['Authorization'];
        const expectedToken = process.env.ZOOM_VERIFICATION_TOKEN;
        
        if (expectedToken && verificationToken !== expectedToken) {
            log(`Verification token mismatch. Expected: ${expectedToken ? '[SET]' : '[NOT SET]'}, Received: ${verificationToken ? '[PROVIDED]' : '[NOT PROVIDED]'}`, 'WARNING');
            return res.status(401).json({ error: 'Unauthorized access' });
        }

        if (!req.body || typeof req.body !== 'object') {
            log('Invalid request body', 'WARNING');
            return res.status(400).json({ error: 'Invalid request body' });
        }

        const { event, payload } = req.body;
        log(`Event type: ${event}, Payload: ${JSON.stringify(payload)}`);
        
        // 处理机器人安装事件
        if (event === 'bot_installed' && payload) {
            const { accountId, robotJid, userId, userJid, userName } = payload;
            log(`Bot installed - accountId: ${accountId}, robotJid: ${robotJid}`, 'INFO');
            
            // 保存机器人信息
            botAccountId = accountId;
            botRobotJid = robotJid;
            
            log(`Bot installation completed successfully`, 'INFO');
            return res.json({ status: 'ok', message: 'Bot installed successfully' });
        }
        
        if (event === 'bot_notification' && payload) {
            const { cmd, userName, userJid, robotJid, accountId } = payload;
            
            // 如果payload中包含accountId，更新保存的信息
            if (accountId && !botAccountId) {
                botAccountId = accountId;
                log(`Updated botAccountId from payload: ${accountId}`, 'INFO');
            }
            if (robotJid && !botRobotJid) {
                botRobotJid = robotJid;
                log(`Updated botRobotJid from payload: ${robotJid}`, 'INFO');
            }
            
            // 详细记录接收到的JID信息
            log(`Received JIDs - userJid: ${userJid}, robotJid: ${robotJid}, accountId: ${accountId}`, 'INFO');
            log(`Test JID check - userJid is test: ${isTestJid(userJid)}, robotJid is test: ${isTestJid(robotJid)}`, 'INFO');
            
            if (!cmd || !userJid || !robotJid) {
                log(`Missing required fields - cmd: ${cmd}, userJid: ${userJid}, robotJid: ${robotJid}`, 'WARNING');
                return res.status(400).json({ error: 'Missing required fields' });
            }
            
            try {
                // 处理命令并生成回复
                const replyMessage = processCommand(cmd, userName || 'User');
                log(`Generated reply message: ${replyMessage}`, 'INFO');
                
                // 发送回复消息
                const sendResult = await sendMessage(userJid, replyMessage, robotJid);
                log(`Send message result: ${JSON.stringify(sendResult)}`, 'INFO');
                
                // 返回响应给Zoom（兼容格式）
                const response = {
                    to_jid: userJid,
                    message: replyMessage,
                    robot_jid: robotJid
                };
                
                log(`Command processed successfully: ${cmd} -> ${userName || 'User'}`);
                return res.json(response);
            } catch (sendError) {
                log(`Error sending message: ${sendError.message}`, 'ERROR');
                if (sendError.response) {
                    log(`API Error Response: ${JSON.stringify(sendError.response.data)}`, 'ERROR');
                    log(`API Error Status: ${sendError.response.status}`, 'ERROR');
                    log(`API Error Headers: ${JSON.stringify(sendError.response.headers)}`, 'ERROR');
                }
                // 仍然返回成功状态给Zoom，避免重试
                return res.json({ status: 'received', error: 'Failed to send reply' });
            }
        }
        
        // 处理其他事件类型
        log(`Received event: ${event}`);
        res.json({ status: 'ok', message: 'Event received' });
        
    } catch (error) {
        log(`Webhook processing error: ${error.message}`, 'ERROR');
        log(`Stack trace: ${error.stack}`, 'ERROR');
        res.status(500).json({ 
            error: 'Internal server error',
            message: process.env.NODE_ENV === 'development' ? error.message : 'Processing failed'
        });
    }
});

// OAuth回调端点
app.get('/oauth/callback', (req, res) => {
    const { code, state } = req.query;
    
    log(`OAuth回调接收: code=${code ? '已提供' : '未提供'}, state=${state}`);
    
    if (code) {
        res.send(`
            <h2>🎉 Zoom机器人授权成功！</h2>
            <p>您已成功授权Zoom聊天机器人。</p>
            <p>现在可以在Zoom Team Chat中与机器人对话了！</p>
            <p><strong>试试发送：</strong> hello 或 help</p>
            <br>
            <p><em>您可以关闭此页面。</em></p>
        `);
    } else {
        res.status(400).send(`
            <h2>❌ 授权失败</h2>
            <p>授权过程中出现错误，请重试。</p>
            <p><a href="javascript:history.back()">返回重试</a></p>
        `);
    }
});

// 健康检查端点
app.get('/health', (req, res) => {
    const config = {
        port: PORT,
        clientId: process.env.ZOOM_CLIENT_ID ? '已配置' : '未配置',
        clientSecret: process.env.ZOOM_CLIENT_SECRET ? '已配置' : '未配置',
        verificationToken: process.env.ZOOM_VERIFICATION_TOKEN ? '已配置' : '未配置',
        accountId: process.env.ZOOM_ACCOUNT_ID ? '已配置' : '未配置'
    };
    
    res.json({
        status: 'running',
        timestamp: new Date().toISOString(),
        uptime: process.uptime(),
        config: config,
        message: '🤖 Zoom聊天机器人运行正常'
    });
});

// 测试发送消息端点
app.post('/test-send-message', async (req, res) => {
    try {
        const { to_jid, message } = req.body;
        
        if (!to_jid || !message) {
            return res.status(400).json({ 
                error: '缺少必要参数',
                required: ['to_jid', 'message']
            });
        }
        
        // 使用默认机器人JID（如果没有提供）
        const robotJid = req.body.robot_jid || process.env.ZOOM_BOT_JID || 'default_robot_jid';
        
        const result = await sendMessage(to_jid, message, robotJid);
        
        res.json({
            status: 'success',
            message: '消息发送成功',
            data: result
        });
        
    } catch (error) {
        res.status(500).json({
            status: 'error',
            message: '消息发送失败',
            error: error.message
        });
    }
});

// 测试页面
app.get('/test', (req, res) => {
    res.send(`
        <!DOCTYPE html>
        <html lang="zh-CN">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>Zoom机器人测试控制台</title>
            <style>
                body { 
                    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Arial, sans-serif;
                    max-width: 800px; 
                    margin: 40px auto; 
                    padding: 20px;
                    background: #f5f5f5;
                }
                .container {
                    background: white;
                    padding: 30px;
                    border-radius: 8px;
                    box-shadow: 0 2px 10px rgba(0,0,0,0.1);
                }
                h1 { color: #2d8cff; border-bottom: 2px solid #2d8cff; padding-bottom: 10px; }
                .section { margin: 20px 0; padding: 15px; background: #f8f9fa; border-radius: 5px; }
                .button { 
                    background: #2d8cff; 
                    color: white; 
                    border: none; 
                    padding: 8px 16px; 
                    border-radius: 4px; 
                    cursor: pointer;
                    margin: 5px;
                }
                .button:hover { background: #1e7ce8; }
                input, textarea { 
                    width: 100%; 
                    padding: 8px; 
                    margin: 5px 0; 
                    border: 1px solid #ddd; 
                    border-radius: 4px;
                    box-sizing: border-box;
                }
                .result { 
                    margin-top: 15px; 
                    padding: 10px; 
                    background: #e8f5e8; 
                    border-radius: 4px;
                    border-left: 4px solid #28a745;
                }
                .error { 
                    background: #f8e8e8; 
                    border-left-color: #dc3545; 
                }
            </style>
        </head>
        <body>
            <div class="container">
                <h1>🤖 Zoom机器人测试控制台</h1>
                
                <div class="section">
                    <h3>📊 系统状态</h3>
                    <button class="button" onclick="checkHealth()">检查健康状态</button>
                    <div id="healthResult"></div>
                </div>
                
                <div class="section">
                    <h3>📝 测试Webhook</h3>
                    <p>模拟Zoom发送消息到机器人：</p>
                    <input type="text" id="testCommand" placeholder="输入命令，如: hello" value="hello">
                    <input type="text" id="testUser" placeholder="用户名" value="测试用户">
                    <button class="button" onclick="testWebhook()">测试Webhook</button>
                    <div id="webhookResult"></div>
                </div>
                
                <div class="section">
                    <h3>💬 测试发送消息</h3>
                    <p>直接发送消息到指定用户：</p>
                    <input type="text" id="toJid" placeholder="目标用户JID，如: user@xmpp.zoom.us">
                    <textarea id="message" rows="3" placeholder="输入要发送的消息"></textarea>
                    <button class="button" onclick="testSendMessage()">发送消息</button>
                    <div id="sendResult"></div>
                </div>
                
                <div class="section">
                    <h3>🔧 快速命令测试</h3>
                    <button class="button" onclick="quickTest('hello')">测试 hello</button>
                    <button class="button" onclick="quickTest('help')">测试 help</button>
                    <button class="button" onclick="quickTest('time')">测试 time</button>
                    <button class="button" onclick="quickTest('ping')">测试 ping</button>
                    <button class="button" onclick="quickTest('info')">测试 info</button>
                </div>
            </div>
            
            <script>
                async function checkHealth() {
                    try {
                        const response = await fetch('/health');
                        const data = await response.json();
                        document.getElementById('healthResult').innerHTML = 
                            '<div class="result"><strong>✅ 系统状态：</strong><pre>' + 
                            JSON.stringify(data, null, 2) + '</pre></div>';
                    } catch (error) {
                        document.getElementById('healthResult').innerHTML = 
                            '<div class="result error"><strong>❌ 错误：</strong>' + error.message + '</div>';
                    }
                }
                
                async function testWebhook() {
                    const cmd = document.getElementById('testCommand').value;
                    const userName = document.getElementById('testUser').value;
                    
                    try {
                        const response = await fetch('/webhook', {
                            method: 'POST',
                            headers: {
                                'Content-Type': 'application/json',
                                'Authorization': '${process.env.ZOOM_VERIFICATION_TOKEN || 'test-token'}'
                            },
                            body: JSON.stringify({
                                event: 'bot_notification',
                                payload: {
                                    cmd: cmd,
                                    userName: userName,
                                    userJid: 'test@xmpp.zoom.us',
                                    robotJid: 'bot@xmpp.zoom.us'
                                }
                            })
                        });
                        
                        const data = await response.json();
                        document.getElementById('webhookResult').innerHTML = 
                            '<div class="result"><strong>✅ Webhook响应：</strong><pre>' + 
                            JSON.stringify(data, null, 2) + '</pre></div>';
                    } catch (error) {
                        document.getElementById('webhookResult').innerHTML = 
                            '<div class="result error"><strong>❌ 错误：</strong>' + error.message + '</div>';
                    }
                }
                
                async function testSendMessage() {
                    const toJid = document.getElementById('toJid').value;
                    const message = document.getElementById('message').value;
                    
                    if (!toJid || !message) {
                        alert('请填写目标JID和消息内容');
                        return;
                    }
                    
                    try {
                        const response = await fetch('/test-send-message', {
                            method: 'POST',
                            headers: { 'Content-Type': 'application/json' },
                            body: JSON.stringify({ to_jid: toJid, message: message })
                        });
                        
                        const data = await response.json();
                        document.getElementById('sendResult').innerHTML = 
                            '<div class="result"><strong>✅ 发送结果：</strong><pre>' + 
                            JSON.stringify(data, null, 2) + '</pre></div>';
                    } catch (error) {
                        document.getElementById('sendResult').innerHTML = 
                            '<div class="result error"><strong>❌ 错误：</strong>' + error.message + '</div>';
                    }
                }
                
                function quickTest(command) {
                    document.getElementById('testCommand').value = command;
                    testWebhook();
                }
                
                // 页面加载时自动检查健康状态
                window.onload = function() {
                    checkHealth();
                };
            </script>
        </body>
        </html>
    `);
});

// 根路径
app.get('/', (req, res) => {
    res.send(`
        <h1>🤖 Zoom聊天机器人</h1>
        <p>机器人正在运行中...</p>
        <ul>
            <li><a href="/health">健康检查</a></li>
            <li><a href="/test">测试控制台</a></li>
        </ul>
    `);
});

// 环境变量检查
function checkEnvironment() {
    const requiredVars = ['ZOOM_CLIENT_ID', 'ZOOM_CLIENT_SECRET', 'ZOOM_VERIFICATION_TOKEN'];
    const missingVars = requiredVars.filter(varName => !process.env[varName]);
    
    if (missingVars.length > 0) {
        log(`Missing required environment variables: ${missingVars.join(', ')}`, 'ERROR');
        log('Please check your .env file configuration', 'ERROR');
        return false;
    }
    
    log('Environment variables check passed');
    return true;
}

// 启动服务器
const server = app.listen(PORT, (error) => {
    if (error) {
        log(`Failed to start server: ${error.message}`, 'ERROR');
        process.exit(1);
    }
    
    log(`🚀 Zoom Chat Bot started successfully!`);
    log(`📡 Server running on port: ${PORT}`);
    log(`🌐 Webhook URL: http://localhost:${PORT}/webhook`);
    log(`🔧 Test Console: http://localhost:${PORT}/test`);
    log(`💚 Health Check: http://localhost:${PORT}/health`);
    
    // 检查环境变量
    if (!checkEnvironment()) {
        log('Server started but configuration is incomplete', 'WARNING');
        log('The bot may not function properly without proper Zoom credentials', 'WARNING');
    }
    
    // 如果配置了域名，显示公网地址
    if (process.env.DOMAIN_NAME && process.env.DOMAIN_NAME !== 'your-domain.com') {
        log(`🌍 Public Webhook URL: https://${process.env.DOMAIN_NAME}/webhook`);
        log(`🌍 Public OAuth Callback: https://${process.env.DOMAIN_NAME}/oauth/callback`);
    }
    
    log('='.repeat(50));
});

// 处理服务器错误
server.on('error', (error) => {
    if (error.code === 'EADDRINUSE') {
        log(`Port ${PORT} is already in use. Please use a different port.`, 'ERROR');
        log(`You can set PORT environment variable: PORT=3002 npm start`, 'ERROR');
    } else {
        log(`Server error: ${error.message}`, 'ERROR');
    }
    process.exit(1);
});

// 未捕获的异常处理
process.on('uncaughtException', (error) => {
    log(`Uncaught Exception: ${error.message}`, 'ERROR');
    log(`Stack: ${error.stack}`, 'ERROR');
    process.exit(1);
});

process.on('unhandledRejection', (reason, promise) => {
    log(`Unhandled Rejection at: ${promise}, reason: ${reason}`, 'ERROR');
    process.exit(1);
});

// 优雅关闭
process.on('SIGTERM', () => {
    log('Received SIGTERM signal, shutting down server...');
    server.close(() => {
        log('Server closed successfully');
        process.exit(0);
    });
});

process.on('SIGINT', () => {
    log('Received SIGINT signal, shutting down server...');
    server.close(() => {
        log('Server closed successfully');
        process.exit(0);
    });
});