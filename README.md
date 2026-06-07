# WeChat 自动化项目

基于 FastAPI + SwiftUI 的微信消息管理系统。

## 项目结构

```
.
├── wechat-server/          # FastAPI 后端
│   ├── main.py            # 主服务入口
│   ├── requirements.txt   # Python 依赖
│   └── run.sh             # 启动脚本
├── MyWeChat/              # iOS SwiftUI 客户端
│   └── MyWeChat/
│       ├── MyWeChatApp.swift
│       ├── Models.swift
│       ├── Views.swift
│       └── WebSocketManager.swift
└── .github/workflows/     # GitHub Actions 自动构建
    └── build-ios.yml
```

## 后端部署

### 1. 安装依赖

```bash
cd wechat-server
pip install -r requirements.txt
```

### 2. 启动服务

```bash
bash run.sh
```

或手动启动：

```bash
uvicorn main:app --host 0.0.0.0 --port 8000
```

### 3. API 文档

启动后访问：
- Swagger UI: http://localhost:8000/docs
- ReDoc: http://localhost:8000/redoc

## iOS 客户端

### 功能

- 消息会话列表
- 实时聊天（WebSocket）
- 服务器配置
- 自动重连

### 构建

GitHub Actions 会自动构建无签名 IPA 文件。

### 手动构建

1. 打开 `MyWeChat.xcodeproj`
2. 选择目标设备
3. 点击 Build

## 配置

在 iOS 客户端的"设置"页面中配置服务器 WebSocket 地址，例如：

```
ws://your-server-ip:8000/ws
```

## 技术栈

- **后端**: FastAPI, WebSocket, SQLite
- **iOS**: SwiftUI, URLSessionWebSocketTask
- **构建**: GitHub Actions, Xcode
