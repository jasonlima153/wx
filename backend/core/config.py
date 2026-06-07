import os

# ============ 基础路径 ============
BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
UPLOAD_DIR = os.path.join(BASE_DIR, "uploads")
DB_PATH = os.path.join(BASE_DIR, "database.db")

# 上传子目录
UPLOAD_IMAGES_DIR = os.path.join(UPLOAD_DIR, "images")
UPLOAD_VOICES_DIR = os.path.join(UPLOAD_DIR, "voices")
UPLOAD_FILES_DIR = os.path.join(UPLOAD_DIR, "files")

# 确保目录存在
for d in [UPLOAD_DIR, UPLOAD_IMAGES_DIR, UPLOAD_VOICES_DIR, UPLOAD_FILES_DIR]:
    os.makedirs(d, exist_ok=True)

# ============ CORS ============
CORS_ORIGINS = ["*"]  # 生产环境替换为真实域名

# ============ JWT（占位） ============
JWT_SECRET = "your-secret-key-change-in-production"
JWT_ALGORITHM = "HS256"
JWT_EXPIRE_HOURS = 72
