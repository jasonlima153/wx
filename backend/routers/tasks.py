"""
定时任务接口
对应前端: APIClient 的 createSchedule / toggleSchedule / deleteSchedule / fetchScheduledTasks
路径前缀: /api/scheduled_tasks（注意：前端调用的是 /api/scheduled_tasks 不是 /api/tasks）
"""
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from typing import Optional, List
import sqlite3
import uuid
import json
from datetime import datetime, timedelta

from core.config import DB_PATH
from services.scheduler import scheduler, execute_scheduled_task

router = APIRouter()


def get_db():
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn


# ============ Pydantic 模型 ============
class TaskCreate(BaseModel):
    name: str = ""
    message_content: str = ""
    msg_type: str = "text"
    media_url: str = ""
    target_accounts: List[str] = []
    targets: List[str] = []
    send_time: str = ""
    repeat_interval: int = 0
    repeat_count: int = 1


# ============ 接口 ============

@router.get("/")
async def list_tasks():
    """
    获取所有定时任务
    对应前端: api.fetchScheduledTasks() -> GET /api/scheduled_tasks
    """
    conn = get_db()
    c = conn.cursor()
    c.execute("SELECT * FROM scheduled_tasks ORDER BY created_at DESC")
    rows = c.fetchall()
    conn.close()
    return [dict(row) for row in rows]


@router.post("/")
async def create_task(task: TaskCreate):
    """
    创建定时任务
    对应前端: api.createSchedule(draft) -> POST /api/scheduled_tasks
    """
    task_id = str(uuid.uuid4())
    send_time = task.send_time or datetime.now().isoformat()

    # 解析发送时间
    try:
        send_dt = datetime.fromisoformat(send_time)
        if send_dt <= datetime.now():
            send_dt = datetime.now() + timedelta(seconds=10)
    except Exception:
        send_dt = datetime.now() + timedelta(seconds=10)

    next_run = send_dt.isoformat()
    created_at = datetime.now().isoformat()

    conn = get_db()
    c = conn.cursor()
    c.execute(
        """INSERT INTO scheduled_tasks
        (id, name, message_content, msg_type, media_url, target_accounts, targets,
         send_time, repeat_interval, repeat_count, sent_count, status, created_at, next_run)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0, 'pending', ?, ?)""",
        (task_id, task.name, task.message_content, task.msg_type, task.media_url,
         json.dumps(task.target_accounts), json.dumps(task.targets),
         send_time, task.repeat_interval, task.repeat_count, created_at, next_run)
    )
    conn.commit()
    conn.close()

    # 调度第一次执行
    from apscheduler.triggers.date import DateTrigger
    scheduler.add_job(
        execute_scheduled_task,
        trigger=DateTrigger(run_date=send_dt),
        args=[task_id],
        id=f"task_{task_id}_0"
    )

    return {"status": "ok", "id": task_id, "next_run": next_run}


@router.delete("/{task_id}")
async def delete_task(task_id: str):
    """
    删除定时任务
    对应前端: api.deleteSchedule(id:) -> DELETE /api/scheduled_tasks/{id}
    """
    # 移除调度器中的所有相关 job
    for job in scheduler.get_jobs():
        if f"task_{task_id}_" in job.id:
            scheduler.remove_job(job.id)

    conn = get_db()
    c = conn.cursor()
    c.execute("DELETE FROM scheduled_tasks WHERE id=?", (task_id,))
    conn.commit()
    conn.close()
    return {"status": "ok"}


@router.put("/{task_id}/pause")
async def pause_task(task_id: str):
    """
    暂停定时任务
    对应前端: api.toggleSchedule(id:, enabled: false) -> PUT /api/scheduled_tasks/{id}/pause
    """
    for job in scheduler.get_jobs():
        if f"task_{task_id}_" in job.id:
            scheduler.pause_job(job.id)

    conn = get_db()
    c = conn.cursor()
    c.execute("UPDATE scheduled_tasks SET status='paused' WHERE id=?", (task_id,))
    conn.commit()
    conn.close()
    return {"status": "ok"}


@router.put("/{task_id}/resume")
async def resume_task(task_id: str):
    """
    恢复定时任务
    对应前端: api.toggleSchedule(id:, enabled: true) -> PUT /api/scheduled_tasks/{id}/resume
    """
    conn = get_db()
    c = conn.cursor()
    c.execute("SELECT * FROM scheduled_tasks WHERE id=?", (task_id,))
    row = c.fetchone()
    if row:
        task = dict(row)
        next_run = datetime.now() + timedelta(seconds=max(task['repeat_interval'], 10))
        c.execute("UPDATE scheduled_tasks SET status='running', next_run=? WHERE id=?",
                  (next_run.isoformat(), task_id))
        conn.commit()

        from apscheduler.triggers.date import DateTrigger
        scheduler.add_job(
            execute_scheduled_task,
            trigger=DateTrigger(run_date=next_run),
            args=[task_id],
            id=f"task_{task_id}_resume",
            replace_existing=True
        )
    conn.close()
    return {"status": "ok"}
