"""
FastAPI 后端主入口
模块化路由架构，与 SwiftUI 前端完全对应
"""
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from contextlib import asynccontextmanager
import uvicorn

# 导入配置
from core.config import UPLOAD_DIR, DB_PATH, CORS_ORIGINS

# 导入路由模块
from routers import chat, account, upload, tasks

# 导入调度服务
from services.scheduler import scheduler, restore_scheduled_tasks


# ============ 数据库初始化 ============
def init_db():
    import sqlite3
    conn = sqlite3.connect(DB_PATH)
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

    c.execute('''CREATE TABLE IF NOT EXISTS scheduled_tasks (
        id TEXT PRIMARY KEY,
        name TEXT DEFAULT '',
        message_content TEXT NOT NULL,
        msg_type TEXT DEFAULT 'text',
        media_url TEXT,
        target_accounts TEXT NOT NULL,
        targets TEXT NOT NULL,
        send_time TEXT NOT NULL,
        repeat_interval INTEGER DEFAULT 0,
        repeat_count INTEGER DEFAULT 1,
        sent_count INTEGER DEFAULT 0,
        status TEXT DEFAULT 'pending',
        created_at TEXT NOT NULL,
        next_run TEXT
    )''')

    conn.commit()
    conn.close()


# ============ 应用生命周期 ============
@asynccontextmanager
async def lifespan(app: FastAPI):
    # 启动时
    init_db()
    restore_scheduled_tasks()
    scheduler.start()
    print("🚀 服务启动完成（含定时任务调度器）")
    yield
    # 关闭时
    scheduler.shutdown()
    print("👋 服务关闭")


# ============ 创建应用 ============
app = FastAPI(title="App Backend API", version="2.0.0", lifespan=lifespan)

# CORS 跨域
app.add_middleware(
    CORSMiddleware,
    allow_origins=CORS_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# 静态文件服务（上传的文件可通过此路径访问）
app.mount("/uploads", StaticFiles(directory=UPLOAD_DIR), name="uploads")

# ============ 注册路由 ============
# 账号与设置
app.include_router(account.router, prefix="/api/account", tags=["Account & Settings"])

# 文件上传（前端调用 POST /api/upload/file）
app.include_router(upload.router, prefix="/api/upload", tags=["File Uploads"])

# 定时任务（前端调用 /api/scheduled_tasks/*）
app.include_router(tasks.router, prefix="/api/scheduled_tasks", tags=["Scheduled Tasks"])

# WebSocket 聊天（前端连接 wss://host/ws/chat/{client_id}）
app.include_router(chat.router, prefix="/ws", tags=["WebSocket Chat"])

# 会话 REST 接口（前端调用 /api/conversations/*, /api/send, /api/messages/*）
# chat router 中的 REST 接口需要挂载到 /api 前缀
app.include_router(chat.router, prefix="/api", tags=["Chat REST"])


@app.get("/")
async def root():
    return {"message": "FastAPI Server is running. Ready for SwiftUI client.", "version": "2.0.0"}


if __name__ == "__main__":
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)
