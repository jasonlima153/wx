const WebSocket = require('ws');
const schedule = require('node-schedule');

const wss = new WebSocket.Server({ port: 8080 });
let clients = new Set();
let tasks = [];
let jobs = new Map();

wss.on('connection', ws => {
    console.log('✅ 客户端已连接');
    clients.add(ws);

    ws.send(JSON.stringify({
        type: 'task_list',
        tasks: tasks.map(t => ({ id: t.id, name: t.name, targetId: t.targetId, message: t.message, cron: t.cron }))
    }));

    ws.on('message', data => {
        let msg = JSON.parse(data);
        console.log(`📩 收到命令类型: ${msg.type}`);

        if (msg.type === 'message') {
            setTimeout(() => {
                const reply = {
                    type: 'new_message',
                    message: {
                        id: Date.now().toString(),
                        text: `[自动回复] 已收到: ${msg.text}`,
                        targetId: msg.targetId
                    }
                };
                ws.send(JSON.stringify(reply));
            }, 500);

        } else if (msg.type === 'add_task') {
            const task = msg.task;
            const job = schedule.scheduleJob(task.cron, () => {
                const taskMsg = JSON.stringify({
                    type: 'new_message',
                    message: {
                        id: Date.now().toString(),
                        text: `[定时发送] ${task.message}`,
                        targetId: task.targetId
                    }
                });
                clients.forEach(c => {
                    if (c.readyState === WebSocket.OPEN) c.send(taskMsg);
                });
            });
            jobs.set(task.id, job);
            tasks.push(task);
            broadcastTaskList();

        } else if (msg.type === 'delete_task') {
            const job = jobs.get(msg.taskId);
            if (job) job.cancel();
            jobs.delete(msg.taskId);
            tasks = tasks.filter(t => t.id !== msg.taskId);
            broadcastTaskList();

        } else if (msg.type === 'get_tasks') {
            ws.send(JSON.stringify({
                type: 'task_list',
                tasks: tasks.map(t => ({ id: t.id, name: t.name, targetId: t.targetId, message: t.message, cron: t.cron }))
            }));
        }
    });

    ws.on('close', () => {
        console.log('❌ 客户端断开');
        clients.delete(ws);
    });
});

function broadcastTaskList() {
    const listMsg = JSON.stringify({
        type: 'task_list',
        tasks: tasks.map(t => ({ id: t.id, name: t.name, targetId: t.targetId, message: t.message, cron: t.cron }))
    });
    clients.forEach(c => {
        if (c.readyState === WebSocket.OPEN) c.send(listMsg);
    });
}

console.log('🚀 WebSocket 服务器已启动，监听端口: 8080');
