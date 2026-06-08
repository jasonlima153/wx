"""
WebSocket 与会话接口
对应前端: WebSocketManager.connect() -> ws://host/ws
路径前缀: /ws（WebSocket）和 /api（会话 REST）
"""
from fastapi import APIRouter, WebSocket, WebSocketDisconnect, HTTPException
from typing import List, Dict
import json
import uuid
import sqlite3
from datetime import datetime

from core.config import DB_PATH

router = APIRouter()


# ============ 数据库工具 ============
def get_db():
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn


# ============ WebSocket 连接管理器 ============
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


# ============ 会话 REST 接口 ============

@router.get("/conversations")
async def get_conversations(account_id: str = ""):
    """
    获取会话列表
    对应前端: api.fetchConversations() -> GET /api/conversations
    注意：前端路径是 /api/conversations，但 chat router 挂载在 /ws 前缀下
    所以需要额外在 main.py 中挂载此路由到 /api
    """
    conn = get_db()
    c = conn.cursor()
    if account_id:
        c.execute("SELECT * FROM conversations WHERE account_id=? ORDER BY is_pinned DESC, last_time DESC",
                  (account_id,))
    else:
        c.execute("SELECT * FROM conversations ORDER BY is_pinned DESC, last_time DESC")
    rows = c.fetchall()
    conn.close()
    return [dict(row) for row in rows]


@router.get("/conversations/{conv_id}/messages")
async def get_conversation_messages(conv_id: str, limit: int = 50, offset: int = 0):
    """
    获取会话消息历史
    对应前端: api.fetchMessages(for:) -> GET /api/conversations/{id}/messages
    """
    conn = get_db()
    c = conn.cursor()
    c.execute(
        "SELECT * FROM messages WHERE sender=? OR receiver=? ORDER BY timestamp DESC LIMIT ? OFFSET ?",
        (conv_id, conv_id, limit, offset))
    rows = c.fetchall()
    conn.close()
    return [dict(row) for row in reversed(list(rows))]


@router.post("/send")
async def send_message(request: dict):
    """
    发送消息（REST 方式）
    对应前端: api.sendMessage() -> POST /api/send
    """
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
    c.execute(
        """INSERT INTO messages
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
        c.execute(
            "INSERT INTO conversations (id, name, last_message, last_time, unread_count, account_id) VALUES (?, ?, ?, ?, ?, ?)",
            (conv_id, receiver, display_msg, timestamp, 1, account_id))

    conn.commit()
    conn.close()

    # 广播给所有 WebSocket 客户端（包括发送者）
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


@router.get("/messages/unread")
async def get_unread_messages(account_id: str = ""):
    """获取未读消息"""
    conn = get_db()
    c = conn.cursor()
    if account_id:
        c.execute("SELECT * FROM messages WHERE is_read=0 AND account_id=? ORDER BY timestamp", (account_id,))
    else:
        c.execute("SELECT * FROM messages WHERE is_read=0 ORDER BY timestamp")
    rows = c.fetchall()
    conn.close()
    return [dict(row) for row in rows]


@router.post("/messages/{msg_id}/read")
async def mark_message_read(msg_id: str):
    """标记消息已读"""
    conn = get_db()
    c = conn.cursor()
    c.execute("UPDATE messages SET is_read=1 WHERE id=?", (msg_id,))
    conn.commit()
    conn.close()
    return {"status": "ok"}


# ============ WebSocket 端点 ============

@router.websocket("/chat/{client_id}")
async def websocket_endpoint(websocket: WebSocket, client_id: str):
    """
    WebSocket 聊天端点
    对应前端: WebSocketManager.connect() -> wss://host/ws/chat/{client_id}
    """
    await manager.connect(websocket, client_id)

    try:
        while True:
            data = await websocket.receive_text()
            try:
                msg = json.loads(data)
                msg_type = msg.get("type", "message")

                if msg_type == "message":
                    # 处理聊天消息
                    sender = msg.get("sender", client_id)
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

                    # 存入数据库
                    conn = get_db()
                    c = conn.cursor()
                    c.execute(
                        """INSERT INTO messages
                        (id, sender, receiver, content, msg_type, media_url, file_name, file_size, voice_duration, timestamp, account_id)
                        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)""",
                        (msg_id, sender, receiver, content, m_type, media_url, file_name, file_size, voice_duration, timestamp, account_id))

                    # 更新会话
                    display_msg = content if m_type == "text" else f"[{m_type}]"
                    c.execute("SELECT id FROM conversations WHERE name=? AND account_id=?", (receiver, account_id))
                    row = c.fetchone()
                    if row:
                        c.execute("UPDATE conversations SET last_message=?, last_time=?, unread_count=unread_count+1 WHERE id=?",
                                  (display_msg, timestamp, row['id']))
                    else:
                        conv_id = str(uuid.uuid4())
                        c.execute(
                            "INSERT INTO conversations (id, name, last_message, last_time, unread_count, account_id) VALUES (?, ?, ?, ?, ?, ?)",
                            (conv_id, receiver, display_msg, timestamp, 1, account_id))
                    conn.commit()
                    conn.close()

                    # 广播给所有客户端（包括发送者，前端通过 isFromMe 判断显示方向）
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
                    })

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
