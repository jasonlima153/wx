from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager
import json
import asyncio
from datetime import datetime
from typing import Dict, List, Optional
import sqlite3
import os

DB_PATH = os.path.join(os.path.dirname(__file__), "database.db")


def init_db():
    conn = sqlite3.connect(DB_PATH)
    c = conn.cursor()
    c.execute('''CREATE TABLE IF NOT EXISTS messages (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sender TEXT,
        receiver TEXT,
        content TEXT,
        timestamp TEXT,
        msg_type TEXT DEFAULT 'text'
    )''')
    c.execute('''CREATE TABLE IF NOT EXISTS conversations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT,
        avatar TEXT,
        last_message TEXT,
        last_time TEXT,
        unread_count INTEGER DEFAULT 0
    )''')
    conn.commit()
    conn.close()


class ConnectionManager:
    def __init__(self):
        self.active_connections: Dict[str, WebSocket] = {}

    async def connect(self, websocket: WebSocket, client_id: str):
        await websocket.accept()
        self.active_connections[client_id] = websocket
        print(f"✅ 客户端 {client_id} 已连接")

    def disconnect(self, client_id: str):
        if client_id in self.active_connections:
            del self.active_connections[client_id]
            print(f"❌ 客户端 {client_id} 已断开")

    async def send_personal_message(self, message: dict, client_id: str):
        if client_id in self.active_connections:
            await self.active_connections[client_id].send_json(message)

    async def broadcast(self, message: dict):
        for connection in self.active_connections.values():
            await connection.send_json(message)


manager = ConnectionManager()


@asynccontextmanager
async def lifespan(app: FastAPI):
    init_db()
    print("🚀 数据库初始化完成")
    yield
    print("👋 服务关闭")


app = FastAPI(title="WeChat Server", lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/")
async def root():
    return {"status": "ok", "message": "WeChat Server is running"}


@app.get("/api/conversations")
async def get_conversations():
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    c = conn.cursor()
    c.execute("SELECT * FROM conversations ORDER BY last_time DESC")
    rows = c.fetchall()
    conn.close()
    return [dict(row) for row in rows]


@app.get("/api/messages/{conversation_id}")
async def get_messages(conversation_id: str):
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    c = conn.cursor()
    c.execute("SELECT * FROM messages WHERE sender=? OR receiver=? ORDER BY timestamp",
              (conversation_id, conversation_id))
    rows = c.fetchall()
    conn.close()
    return [dict(row) for row in rows]


@app.post("/api/send")
async def send_message(request: dict):
    sender = request.get("sender", "user")
    receiver = request.get("receiver", "")
    content = request.get("content", "")
    msg_type = request.get("msg_type", "text")
    timestamp = datetime.now().isoformat()

    conn = sqlite3.connect(DB_PATH)
    c = conn.cursor()
    c.execute("INSERT INTO messages (sender, receiver, content, timestamp, msg_type) VALUES (?, ?, ?, ?, ?)",
              (sender, receiver, content, timestamp, msg_type))

    # 更新会话
    c.execute("SELECT id FROM conversations WHERE name=?", (receiver,))
    row = c.fetchone()
    if row:
        c.execute("UPDATE conversations SET last_message=?, last_time=?, unread_count=unread_count+1 WHERE name=?",
                  (content, timestamp, receiver))
    else:
        c.execute("INSERT INTO conversations (name, avatar, last_message, last_time, unread_count) VALUES (?, ?, ?, ?, ?)",
                  (receiver, "person.circle.fill", content, timestamp, 1))
    conn.commit()
    conn.close()

    # 广播消息给所有客户端
    await manager.broadcast({
        "type": "new_message",
        "sender": sender,
        "receiver": receiver,
        "content": content,
        "timestamp": timestamp,
        "msg_type": msg_type
    })

    return {"status": "ok"}


@app.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    client_id = f"client_{id(websocket)}"
    await manager.connect(websocket, client_id)
    try:
        while True:
            data = await websocket.receive_text()
            try:
                msg = json.loads(data)
                msg_type = msg.get("type", "message")

                if msg_type == "message":
                    # 保存消息
                    sender = msg.get("sender", "user")
                    receiver = msg.get("receiver", "")
                    content = msg.get("content", "")
                    timestamp = datetime.now().isoformat()

                    conn = sqlite3.connect(DB_PATH)
                    c = conn.cursor()
                    c.execute("INSERT INTO messages (sender, receiver, content, timestamp) VALUES (?, ?, ?, ?)",
                              (sender, receiver, content, timestamp))

                    c.execute("SELECT id FROM conversations WHERE name=?", (receiver,))
                    row = c.fetchone()
                    if row:
                        c.execute("UPDATE conversations SET last_message=?, last_time=?, unread_count=unread_count+1 WHERE name=?",
                                  (content, timestamp, receiver))
                    else:
                        c.execute("INSERT INTO conversations (name, avatar, last_message, last_time, unread_count) VALUES (?, ?, ?, ?, ?)",
                                  (receiver, "person.circle.fill", content, timestamp, 1))
                    conn.commit()
                    conn.close()

                    # 广播
                    await manager.broadcast({
                        "type": "new_message",
                        "sender": sender,
                        "receiver": receiver,
                        "content": content,
                        "timestamp": timestamp
                    })

                elif msg_type == "ping":
                    await websocket.send_json({"type": "pong"})

            except json.JSONDecodeError:
                await websocket.send_json({"type": "error", "message": "Invalid JSON"})

    except WebSocketDisconnect:
        manager.disconnect(client_id)
    except Exception as e:
        print(f"WebSocket error: {e}")
        manager.disconnect(client_id)
