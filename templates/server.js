const express = require('express');
const bodyParser = require('body-parser');
const axios = require('axios');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 3001;

app.use(bodyParser.json());
app.use(bodyParser.urlencoded({ extended: true }));

// 全局变量存储访问令牌
let accessToken = null;
let tokenExpiryTime = null;

// 日志函数
const log = (message, level = 'INFO') => {
    const timestamp = new Date().toISOString();
    console.log(`[${timestamp}] [${level}] ${message}`);
};

// 获取访问令牌
async function getAccessToken() {
    // 检查令牌是否仍然有效
    if (accessToken && tokenExpiryTime && Date.now() < tokenExpiryTime) {
        return accessToken;
    }

    try {
        const response = await axios.post('https://zoom.us/oauth/token', null, {
            params: {
                grant_type: 'client_credentials',
                account_id: process.env.ZOOM_ACCOUNT_ID
            },
            headers: {
                'Authorization': `Basic ${Buffer.from(`${process.env.ZOOM_CLIENT_ID}:${process.env.ZOOM_CLIENT_SECRET}`).toString('base64')}`
            }
        });

        accessToken = response.data.access_token;
        // 设置过期时间为获取时间 + 有效期（减去5分钟缓冲）
        tokenExpiryTime = Date.now() + (response.data.expires_in - 300) * 1000;
        
        log('访问令牌获取成功');
        return accessToken;
    } catch (error) {
        log(`获取访问令牌失败: ${error.message}`, 'ERROR');
        throw error;
    }
}

// 发送消息到Zoom
async function sendMessage(toJid, message, robotJid) {
    try {
        const token = await getAccessToken();
        
        const response = await axios.post('https://api.zoom.us/v2/im/chat/messages', {
            to_jid: toJid,
            message: message,
            robot_jid: robotJid
        }, {
            headers: {
                'Authorization': `Bearer ${token}`,
                'Content-Type': 'application/json'
            }
        });

        log(`消息发送成功到 ${toJid}: ${message}`);
        return response.data;
    } catch (error) {
        log(`发送消息失败: ${error.message}`, 'ERROR');
        if (error.response) {
            log(`错误详情: ${JSON.stringify(error.response.data)}`, 'ERROR');
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

// Webhook端点 - 接收Zoom消息
app.post('/webhook', async (req, res) => {
    try {
        log(`收到Webhook请求: ${JSON.stringify(req.body)}`);
        
        // 验证请求
        const verificationToken = req.headers['authorization'];
        if (verificationToken !== process.env.ZOOM_VERIFICATION_TOKEN) {
            log('验证令牌不匹配', 'WARNING');
            return res.status(401).json({ error: '未授权访问' });
        }

        const { event, payload } = req.body;
        
        if (event === 'bot_notification' && payload) {
            const { cmd, userName, userJid, robotJid } = payload;
            
            if (cmd && userJid && robotJid) {
                // 处理命令并生成回复
                const replyMessage = processCommand(cmd, userName || '用户');
                
                // 发送回复消息
                await sendMessage(userJid, replyMessage, robotJid);
                
                // 返回响应给Zoom（兼容格式）
                const response = {
                    to_jid: userJid,
                    message: replyMessage,
                    robot_jid: robotJid
                };
                
                log(`处理命令成功: ${cmd} -> ${userName}`);
                return res.json(response);
            }
        }
        
        // 其他事件类型的处理
        log('收到非机器人通知事件或格式不正确');
        res.json({ status: 'ok', message: '事件已接收' });
        
    } catch (error) {
        log(`Webhook处理错误: ${error.message}`, 'ERROR');
        res.status(500).json({ 
            error: '服务器内部错误',
            message: error.message 
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

// 启动服务器
app.listen(PORT, () => {
    log(`🚀 Zoom聊天机器人启动成功！`);
    log(`📡 服务器运行在端口: ${PORT}`);
    log(`🌐 Webhook地址: http://localhost:${PORT}/webhook`);
    log(`🔧 测试控制台: http://localhost:${PORT}/test`);
    log(`💚 健康检查: http://localhost:${PORT}/health`);
});

// 优雅关闭
process.on('SIGTERM', () => {
    log('收到SIGTERM信号，正在关闭服务器...');
    process.exit(0);
});

process.on('SIGINT', () => {
    log('收到SIGINT信号，正在关闭服务器...');
    process.exit(0);
});