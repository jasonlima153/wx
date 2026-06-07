"""
定时任务调度服务
使用 APScheduler 管理定时群发任务的执行、恢复和状态更新
"""
import sqlite3
import uuid
import json
from datetime import datetime, timedelta
from typing import Dict

from apscheduler.schedulers.asyncio import AsyncIOScheduler
from apscheduler.triggers.date import DateTrigger

from core.config import DB_PATH


# ============ 调度器实例 ============
scheduler = AsyncIOScheduler()


def get_db():
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn


async def execute_scheduled_task(task_id: str):
    """
    执行定时群发任务的核心逻辑
    - 从数据库读取任务配置
    - 对每个账号的每个目标发送消息
    - 更新任务执行计数和状态
    - 如果有下一次循环，调度下一次执行
    """
    conn = get_db()
    c = conn.cursor()
    c.execute("SELECT * FROM scheduled_tasks WHERE id=?", (task_id,))
    row = c.fetchone()
    if not row:
        conn.close()
        return

    task = dict(row)
    target_accounts = json.loads(task['target_accounts'])
    targets = json.loads(task['targets'])

    # 对每个账号的每个目标发送消息
    for account_id in target_accounts:
        for target in targets:
            msg_id = str(uuid.uuid4())
            timestamp = datetime.now().isoformat()
            content = task['message_content']
            msg_type = task['msg_type']
            media_url = task['media_url'] or ''

            c.execute(
                """INSERT INTO messages
                (id, sender, receiver, content, msg_type, media_url, timestamp, account_id)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?)""",
                (msg_id, account_id, target, content, msg_type, media_url, timestamp, account_id))

            # 更新会话
            display_msg = content if msg_type == "text" else f"[{msg_type}]"
            c.execute("SELECT id FROM conversations WHERE name=? AND account_id=?", (target, account_id))
            conv = c.fetchone()
            if conv:
                c.execute(
                    "UPDATE conversations SET last_message=?, last_time=?, unread_count=unread_count+1 WHERE id=?",
                    (display_msg, timestamp, conv['id']))
            else:
                conv_id = str(uuid.uuid4())
                c.execute(
                    "INSERT INTO conversations (id, name, last_message, last_time, unread_count, account_id) VALUES (?, ?, ?, ?, ?, ?)",
                    (conv_id, target, display_msg, timestamp, 1, account_id))

    # 更新任务状态
    new_sent = task['sent_count'] + 1
    new_status = 'completed' if new_sent >= task['repeat_count'] else 'running'

    if new_status == 'running' and task['repeat_interval'] > 0:
        next_run = datetime.now() + timedelta(seconds=task['repeat_interval'])
        c.execute("UPDATE scheduled_tasks SET sent_count=?, status=?, next_run=? WHERE id=?",
                  (new_sent, new_status, next_run.isoformat(), task_id))
        # 调度下一次执行
        scheduler.add_job(
            execute_scheduled_task,
            trigger=DateTrigger(run_date=next_run),
            args=[task_id],
            id=f"task_{task_id}_{new_sent}"
        )
    else:
        c.execute("UPDATE scheduled_tasks SET sent_count=?, status=?, next_run=NULL WHERE id=?",
                  (new_sent, new_status, task_id))

    conn.commit()
    conn.close()
    print(f"📨 定时任务 {task_id} 执行完成 (第 {new_sent}/{task['repeat_count']} 次)")


def restore_scheduled_tasks():
    """
    服务启动时恢复数据库中未完成的定时任务
    在 main.py 的 lifespan 中调用
    """
    conn = get_db()
    c = conn.cursor()
    c.execute("SELECT * FROM scheduled_tasks WHERE status IN ('pending', 'running') AND next_run IS NOT NULL")
    rows = c.fetchall()
    for row in rows:
        task = dict(row)
        try:
            next_run = datetime.fromisoformat(task['next_run'])
            if next_run > datetime.now():
                scheduler.add_job(
                    execute_scheduled_task,
                    trigger=DateTrigger(run_date=next_run),
                    args=[task['id']],
                    id=f"task_{task['id']}_{task['sent_count']}",
                    replace_existing=True
                )
                print(f"🔄 恢复定时任务: {task['id']} -> {next_run}")
        except Exception as e:
            print(f"❌ 恢复任务失败 {task['id']}: {e}")
    conn.close()
