from fastapi import FastAPI, WebSocket, WebSocketDisconnect, UploadFile, File, Form, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.responses import FileResponse
from contextlib import asynccontextmanager
import json
import os
import uuid
import shutil
from datetime import datetime
from typing import Dict, List, Optional
import sqlite3

# ============ 配置 ============
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
UPLOAD_DIR = os.path.join(BASE_DIR, "uploads")
DB_PATH = os.path.join(BASE_DIR, "database.db")

os.makedirs(UPLOAD_DIR, exist_ok=True)
os.makedirs(os.path.join(UPLOAD_DIR, "images"), exist_ok=True)
os.makedirs(os.path.join(UPLOAD_DIR, "voices"), exist_ok=True)
os.makedirs(os.path.join(UPLOAD_DIR, "files"), exist_ok=True)


# ============ 数据库 ============
def get_db():
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn


def init_db():
    conn = get_db()
    c = conn.cursor()

    c.execute('''CREATE TABLE IF NOT EXISTS accounts (
        id TEXT PRIMARY KEY,
        nickname TEXT NOT NULL,
        wx_id TEXT UNIQUE NOT NULL,
        phone TEXT,
        avatar TEXT,
        is_active INTEGER DEFAULT 0,
        last_login TEXT,
        server_url TEXT
    )''')

    c.execute('''CREATE TABLE IF NOT EXISTS messages (
        id TEXT PRIMARY KEY,
        sender TEXT NOT NULL,
        receiver TEXT NOT NULL,
        content TEXT DEFAULT '',
        msg_type TEXT DEFAULT 'text',
        media_url TEXT,
        file_name TEXT,
        file_size INTEGER,
        voice_duration REAL,
        timestamp TEXT NOT NULL,
        account_id TEXT DEFAULT '',
        is_read INTEGER DEFAULT 1
    )''')

    c.execute('''CREATE TABLE IF NOT EXISTS conversations (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        avatar TEXT,
        last_message TEXT,
        last_time TEXT,
        unread_count INTEGER DEFAULT 0,
        account_id TEXT DEFAULT '',
        is_group INTEGER DEFAULT 0,
        is_pinned INTEGER DEFAULT 0
    )''')

    conn.commit()
    conn.close()


# ============ WebSocket 连接管理 ============
class ConnectionManager:
    def __init__(self):
        self.active_connections: Dict[str, WebSocket] = {}

    async def connect(self, websocket: WebSocket, client_id: str):
        await websocket.accept()
        self.active_connections[client_id] = websocket
        print(f"✅ 客户端 {client_id} 已连接 (在线: {len(self.active_connections)})")

    def disconnect(self, client_id: str):
        if client_id in self.active_connections:
            del self.active_connections[client_id]
            print(f"❌ 客户端 {client_id} 已断开 (在线: {len(self.active_connections)})")

    async def send_to(self, message: dict, client_id: str):
        if client_id in self.active_connections:
            try:
                await self.active_connections[client_id].send_json(message)
            except Exception as e:
                print(f"发送失败 {client_id}: {e}")
                self.disconnect(client_id)

    async def broadcast(self, message: dict, exclude: str = ""):
        for cid, conn in list(self.active_connections.items()):
            if cid != exclude:
                try:
                    await conn.send_json(message)
                except Exception:
                    self.disconnect(cid)


manager = ConnectionManager()


# ============ 应用生命周期 ============
@asynccontextmanager
async def lifespan(app: FastAPI):
    init_db()
    print("🚀 数据库初始化完成")
    yield
    print("👋 服务关闭")


app = FastAPI(title="WeChat Server", version="2.0", lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# 静态文件服务 - 上传的文件可通过 HTTP 访问
app.mount("/uploads", StaticFiles(directory=UPLOAD_DIR), name="uploads")


# ============ REST API ============

@app.get("/")
async def root():
    return {"status": "ok", "version": "2.0", "message": "WeChat Server is running"}


# --- 账号管理 ---
@app.get("/api/accounts")
async def get_accounts():
    conn = get_db()
    c = conn.cursor()
    c.execute("SELECT * FROM accounts ORDER BY is_active DESC, last_login DESC")
    rows = c.fetchall()
    conn.close()
    return [dict(row) for row in rows]


@app.post("/api/accounts")
async def create_account(data: dict):
    account_id = str(uuid.uuid4())
    conn = get_db()
    c = conn.cursor()
    try:
        c.execute("INSERT INTO accounts (id, nickname, wx_id, phone, avatar, server_url) VALUES (?, ?, ?, ?, ?, ?)",
                  (account_id, data.get("nickname", ""), data.get("wx_id", ""),
                   data.get("phone", ""), data.get("avatar", ""), data.get("server_url", "")))
        conn.commit()
        conn.close()
        return {"status": "ok", "id": account_id}
    except sqlite3.IntegrityError:
        conn.close()
        raise HTTPException(400, "wx_id 已存在")


@app.put("/api/accounts/{account_id}/activate")
async def activate_account(account_id: str):
    conn = get_db()
    c = conn.cursor()
    c.execute("UPDATE accounts SET is_active=0")
    c.execute("UPDATE accounts SET is_active=1, last_login=? WHERE id=?", (datetime.now().isoformat(), account_id))
    conn.commit()
    conn.close()
    return {"status": "ok"}


# --- 会话管理 ---
@app.get("/api/conversations")
async def get_conversations(account_id: str = ""):
    conn = get_db()
    c = conn.cursor()
    if account_id:
        c.execute("SELECT * FROM conversations WHERE account_id=? ORDER BY is_pinned DESC, last_time DESC", (account_id,))
    else:
        c.execute("SELECT * FROM conversations ORDER BY is_pinned DESC, last_time DESC")
    rows = c.fetchall()
    conn.close()
    return [dict(row) for row in rows]


@app.get("/api/conversations/{conv_id}/messages")
async def get_conversation_messages(conv_id: str, limit: int = 50, offset: int = 0):
    conn = get_db()
    conn.row_factory = sqlite3.Row
    c = conn.cursor()
    c.execute("SELECT * FROM messages WHERE sender=? OR receiver=? ORDER BY timestamp DESC LIMIT ? OFFSET ?",
              (conv_id, conv_id, limit, offset))
    rows = c.fetchall()
    conn.close()
    return [dict(row) for row in reversed(list(rows))]


@app.get("/api/messages/unread")
async def get_unread_messages(account_id: str = ""):
    conn = get_db()
    conn.row_factory = sqlite3.Row
    c = conn.cursor()
    if account_id:
        c.execute("SELECT * FROM messages WHERE is_read=0 AND account_id=? ORDER BY timestamp", (account_id,))
    else:
        c.execute("SELECT * FROM messages WHERE is_read=0 ORDER BY timestamp")
    rows = c.fetchall()
    conn.close()
    return [dict(row) for row in rows]


@app.post("/api/messages/{msg_id}/read")
async def mark_message_read(msg_id: str):
    conn = get_db()
    c = conn.cursor()
    c.execute("UPDATE messages SET is_read=1 WHERE id=?", (msg_id,))
    conn.commit()
    conn.close()
    return {"status": "ok"}


# --- 文件上传 ---
@app.post("/api/upload")
async def upload_file(file: UploadFile = File(...), account_id: str = Form(""), msg_type: str = Form("file")):
    # 根据类型选择存储目录
    if msg_type == "image":
        save_dir = os.path.join(UPLOAD_DIR, "images")
        ext = os.path.splitext(file.filename)[1] or ".jpg"
    elif msg_type == "voice":
        save_dir = os.path.join(UPLOAD_DIR, "voices")
        ext = os.path.splitext(file.filename)[1] or ".aac"
    else:
        save_dir = os.path.join(UPLOAD_DIR, "files")
        ext = os.path.splitext(file.filename)[1] or ".dat"

    file_id = str(uuid.uuid4())
    filename = f"{file_id}{ext}"
    filepath = os.path.join(save_dir, filename)

    # 保存文件
    file_size = 0
    with open(filepath, "wb") as f:
        while chunk := await file.read(8192):
            f.write(chunk)
            file_size += len(chunk)

    # 返回可访问的 URL
    media_url = f"/uploads/{msg_type}s/{filename}"

    return {
        "status": "ok",
        "media_url": media_url,
        "file_name": file.filename,
        "file_size": file_size,
        "file_id": file_id
    }


# --- 发送消息 ---
@app.post("/api/send")
async def send_message(request: dict):
    sender = request.get("sender", "user")
    receiver = request.get("receiver", "")
    content = request.get("content", "")
    msg_type = request.get("msg_type", "text")
    media_url = request.get("media_url", "")
    file_name = request.get("file_name", "")
    file_size = request.get("file_size", 0)
    voice_duration = request.get("voice_duration", 0)
    account_id = request.get("account_id", "")
    timestamp = datetime.now().isoformat()
    msg_id = str(uuid.uuid4())

    conn = get_db()
    c = conn.cursor()

    c.execute("""INSERT INTO messages
        (id, sender, receiver, content, msg_type, media_url, file_name, file_size, voice_duration, timestamp, account_id)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)""",
              (msg_id, sender, receiver, content, msg_type, media_url, file_name, file_size, voice_duration, timestamp, account_id))

    # 更新会话
    display_msg = content if msg_type == "text" else f"[{msg_type}]"
    c.execute("SELECT id FROM conversations WHERE name=? AND account_id=?", (receiver, account_id))
    row = c.fetchone()
    if row:
        c.execute("UPDATE conversations SET last_message=?, last_time=?, unread_count=unread_count+1 WHERE id=?",
                  (display_msg, timestamp, row['id']))
    else:
        conv_id = str(uuid.uuid4())
        c.execute("INSERT INTO conversations (id, name, last_message, last_time, unread_count, account_id) VALUES (?, ?, ?, ?, ?, ?)",
                  (conv_id, receiver, display_msg, timestamp, 1, account_id))

    conn.commit()
    conn.close()

    # 广播消息
    await manager.broadcast({
        "type": "new_message",
        "message_id": msg_id,
        "sender": sender,
        "receiver": receiver,
        "content": content,
        "msg_type": msg_type,
        "media_url": media_url,
        "file_name": file_name,
        "file_size": file_size,
        "voice_duration": voice_duration,
        "timestamp": timestamp,
        "account_id": account_id
    })

    return {"status": "ok", "message_id": msg_id}


# ============ WebSocket ============
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
                    sender = msg.get("sender", "user")
                    receiver = msg.get("receiver", "")
                    content = msg.get("content", "")
                    m_type = msg.get("msg_type", "text")
                    media_url = msg.get("media_url", "")
                    file_name = msg.get("file_name", "")
                    file_size = msg.get("file_size", 0)
                    voice_duration = msg.get("voice_duration", 0)
                    account_id = msg.get("account_id", "")
                    timestamp = datetime.now().isoformat()
                    msg_id = str(uuid.uuid4())

                    conn = get_db()
                    c = conn.cursor()
                    c.execute("""INSERT INTO messages
                        (id, sender, receiver, content, msg_type, media_url, file_name, file_size, voice_duration, timestamp, account_id)
                        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)""",
                              (msg_id, sender, receiver, content, m_type, media_url, file_name, file_size, voice_duration, timestamp, account_id))

                    display_msg = content if m_type == "text" else f"[{m_type}]"
                    c.execute("SELECT id FROM conversations WHERE name=? AND account_id=?", (receiver, account_id))
                    row = c.fetchone()
                    if row:
                        c.execute("UPDATE conversations SET last_message=?, last_time=?, unread_count=unread_count+1 WHERE id=?",
                                  (display_msg, timestamp, row['id']))
                    else:
                        conv_id = str(uuid.uuid4())
                        c.execute("INSERT INTO conversations (id, name, last_message, last_time, unread_count, account_id) VALUES (?, ?, ?, ?, ?, ?)",
                                  (conv_id, receiver, display_msg, timestamp, 1, account_id))
                    conn.commit()
                    conn.close()

                    await manager.broadcast({
                        "type": "new_message",
                        "message_id": msg_id,
                        "sender": sender,
                        "receiver": receiver,
                        "content": content,
                        "msg_type": m_type,
                        "media_url": media_url,
                        "file_name": file_name,
                        "file_size": file_size,
                        "voice_duration": voice_duration,
                        "timestamp": timestamp,
                        "account_id": account_id
                    }, exclude=client_id)

                elif msg_type == "ping":
                    await websocket.send_json({"type": "pong"})

                elif msg_type == "read_receipt":
                    msg_id = msg.get("message_id", "")
                    conn = get_db()
                    c = conn.cursor()
                    c.execute("UPDATE messages SET is_read=1 WHERE id=?", (msg_id,))
                    conn.commit()
                    conn.close()

            except json.JSONDecodeError:
                await websocket.send_json({"type": "error", "message": "Invalid JSON"})

    except WebSocketDisconnect:
        manager.disconnect(client_id)
    except Exception as e:
        print(f"WebSocket error: {e}")
        manager.disconnect(client_id)
