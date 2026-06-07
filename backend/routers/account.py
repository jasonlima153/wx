"""
账号与设置接口
对应前端: APIClient.fetchAccounts(), SettingsScreen
路径前缀: /api/account
"""
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from typing import Optional
import sqlite3
import uuid
from datetime import datetime

from core.config import DB_PATH

router = APIRouter()


# ============ 数据库工具 ============
def get_db():
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn


# ============ Pydantic 模型 ============
class LoginRequest(BaseModel):
    username: str
    password: str


class AccountCreate(BaseModel):
    nickname: str = ""
    wx_id: str = ""
    phone: str = ""
    avatar: str = ""
    server_url: str = ""


class SettingsUpdate(BaseModel):
    notifications_enabled: Optional[bool] = None
    theme: Optional[str] = None
    server_base_url: Optional[str] = None
    websocket_url: Optional[str] = None
    auth_token: Optional[str] = None


# ============ 接口 ============

@router.post("/login")
async def login(req: LoginRequest):
    """登录占位，返回模拟 token"""
    return {
        "status": "ok",
        "token": "fake-jwt-token-placeholder",
        "user_id": str(uuid.uuid4())
    }


@router.get("/accounts")
async def get_accounts():
    """
    获取所有账号列表
    对应前端: api.fetchAccounts() -> GET /api/accounts
    """
    conn = get_db()
    c = conn.cursor()
    c.execute("SELECT * FROM accounts ORDER BY is_active DESC, last_login DESC")
    rows = c.fetchall()
    conn.close()
    return [dict(row) for row in rows]


@router.post("/accounts")
async def create_account(data: dict):
    """创建新账号"""
    account_id = str(uuid.uuid4())
    conn = get_db()
    c = conn.cursor()
    try:
        c.execute(
            "INSERT INTO accounts (id, nickname, wx_id, phone, avatar, server_url) VALUES (?, ?, ?, ?, ?, ?)",
            (account_id, data.get("nickname", ""), data.get("wx_id", ""),
             data.get("phone", ""), data.get("avatar", ""), data.get("server_url", ""))
        )
        conn.commit()
        conn.close()
        return {"status": "ok", "id": account_id}
    except sqlite3.IntegrityError:
        conn.close()
        raise HTTPException(400, "wx_id 已存在")


@router.put("/accounts/{account_id}/activate")
async def activate_account(account_id: str):
    """激活指定账号"""
    conn = get_db()
    c = conn.cursor()
    c.execute("UPDATE accounts SET is_active=0")
    c.execute("UPDATE accounts SET is_active=1, last_login=? WHERE id=?",
              (datetime.now().isoformat(), account_id))
    conn.commit()
    conn.close()
    return {"status": "ok"}


@router.get("/profile")
async def get_profile():
    """获取当前用户信息占位"""
    return {"username": "Admin", "avatar": "https://example.com/avatar.jpg"}


@router.post("/settings")
async def update_settings(settings: SettingsUpdate):
    """更新用户设置占位"""
    return {"status": "ok", "updated_settings": settings.model_dump(exclude_none=True)}
