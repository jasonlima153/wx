"""
文件上传接口（图片、语音、文件）
对应前端: APIClient.upload() -> POST /api/upload
路径前缀: /api/upload
"""
from fastapi import APIRouter, UploadFile, File, Form, HTTPException
import os
import uuid
from core.config import UPLOAD_DIR, UPLOAD_IMAGES_DIR, UPLOAD_VOICES_DIR, UPLOAD_FILES_DIR

router = APIRouter()


@router.post("/upload")
async def upload_file(
    file: UploadFile = File(...),
    account_id: str = Form(""),
    msg_type: str = Form("file")
):
    """
    通用文件上传
    对应前端: api.upload(data:filename:mimeType:) -> POST /api/upload

    前端 APIClient 会以 multipart/form-data 发送:
      - file: 二进制文件
      - account_id: 当前账号 ID
      - msg_type: "image" / "voice" / "file"
    """
    if not file or not file.filename:
        raise HTTPException(status_code=400, detail="No file sent")

    # 根据 msg_type 选择存储目录和扩展名
    if msg_type == "image":
        save_dir = UPLOAD_IMAGES_DIR
        ext = os.path.splitext(file.filename)[1] or ".jpg"
    elif msg_type == "voice":
        save_dir = UPLOAD_VOICES_DIR
        ext = os.path.splitext(file.filename)[1] or ".aac"
    else:
        save_dir = UPLOAD_FILES_DIR
        ext = os.path.splitext(file.filename)[1] or ".dat"

    # 生成唯一文件名
    file_id = uuid.uuid4().hex
    filename = f"{file_id}{ext}"
    filepath = os.path.join(save_dir, filename)

    # 保存文件
    file_size = 0
    with open(filepath, "wb") as f:
        while chunk := await file.read(8192):
            f.write(chunk)
            file_size += len(chunk)

    # 返回访问路径（与前端 APIClient.upload 的 UploadResponse.url 对应）
    media_url = f"/uploads/{msg_type}s/{filename}"

    return {
        "status": "ok",
        "media_url": media_url,
        "file_name": file.filename,
        "file_size": file_size,
        "file_id": file_id
    }


@router.post("/upload/audio")
async def upload_audio(voice: UploadFile = File(...)):
    """语音专用上传入口（内部转发到通用上传）"""
    return await upload_file(file=voice, msg_type="voice")
