#!/bin/bash
# ---------------------------------------------------------
# 修复 Windows Git Bash 下路径自动转换导致的问题
export MSYS_NO_PATHCONV=1
# ---------------------------------------------------------

# QzoneWall-Go Docker 部署脚本
# 用于快速部署 qzonewall-go

set -e

echo "🚀 开始部署 QzoneWall-Go..."

# 1. 检查 Docker 是否安装
if ! command -v docker &> /dev/null; then
    echo "❌ Docker 未安装，请先安装 Docker"
    exit 1
fi

# 2. 创建并进入工作目录 (改为简短的 'wall')
WORK_DIR="wall"
if [ -d "$WORK_DIR" ]; then
    echo "📂 目录 $WORK_DIR 已存在，进入该目录"
else
    mkdir -p "$WORK_DIR"
    echo "📁 创建工作目录: $WORK_DIR"
fi

cd "$WORK_DIR"

# 3. 拉取最新镜像
echo "📦 拉取 Docker 镜像..."
docker pull guohuiyuan/qzonewall-go:latest

# 4. 创建配置文件 (使用 example_config.yaml 的内容)
if [ ! -f "config.yaml" ]; then
    echo "📝 检测到无配置文件，正在根据模板创建 config.yaml..."
    cat > config.yaml << 'EOF'
# QzoneWall-Go 配置文件

# QQ空间配置
qzone:
  # Cookie 有效性轮询间隔
  keep_alive: 10s
  # 接口最大重试次数
  max_retry: 2
  # HTTP 超时
  timeout: 30s

# QQ 机器人配置 (NapCat + ZeroBot)
bot:
  zero:
    nickname:
      - "表白墙"
      - "墙墙"
    command_prefix: "/"
    super_users:
      - 123456789 # ⚠️ 请替换为你的管理员 QQ 号
    ring_len: 4096
    latency: 1000000
    max_process_time: 240000000000
  ws:
    - url: "ws://localhost:3001" # ⚠️ 请替换为 NapCat 地址 (如果是 Docker 互联请用容器IP或host.docker.internal)
      access_token: "your_token"   # ⚠️ 请替换为你的 token
  # 管理群号（用于通知）
  manage_group: 0

# 表白墙配置
wall:
  show_author: false   # 发布到空间时，非匿名稿件是否追加"来自xxx的投稿"署名
  anon_default: false # 投稿页默认是否勾选"匿名投稿"
  max_images: 9
  max_text_len: 2000
  publish_delay: 0s

# 数据库
database:
  path: "data.db"

# Web 管理后台
web:
  enable: true
  addr: ":8081"
  admin_user: "admin"
  admin_pass: "admin123" # ⚠️ 务必修改默认密码！
  # prefix: "/wall" # 如果你在 Nginx 使用了二级目录反代，请修改这里或者代码里的默认值

# 敏感词
censor:
  enable: true
  words:
    - "广告"
    - "代写"
  words_file: ""

# 任务调度
worker:
  workers: 1
  retry_count: 3
  retry_delay: 5s
  rate_limit: 30s
  poll_interval: 5s

# 日志
log:
  level: "info"
EOF
    echo "✅ 配置文件已创建: $(pwd)/config.yaml"
    echo "⚠️  【重要】请立即编辑 config.yaml 文件，修改 QQ号、Token 和 密码！"
else
    echo "ℹ️  配置文件已存在，跳过创建"
fi

# 5. 停止并移除旧容器
CONTAINER_NAME="qzonewall"
if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    echo "🛑 发现旧容器，正在停止并移除..."
    docker stop "$CONTAINER_NAME" >/dev/null 2>&1 || true
    docker rm "$CONTAINER_NAME" >/dev/null 2>&1 || true
fi

# 6. 运行新容器
echo "🏃 启动新容器..."

# 如果不提前 touch 一个文件，Docker 会把挂载点 data.db 自动创建成一个文件夹，导致报错
if [ ! -f "data.db" ]; then
    echo "📄 未检测到数据库文件，正在创建空 data.db 防止 Docker 误判..."
    touch data.db
else
    echo "✅ 检测到现有数据库文件，准备挂载..."
fi

# 注意：使用了双斜杠 // 来兼容部分 Git Bash 环境，配合 MSYS_NO_PATHCONV 更稳妥
docker run -d \
  --name "$CONTAINER_NAME" \
  --restart unless-stopped \
  -p 8081:8081 \
  -v "$(pwd)/config.yaml://home/appuser/config.yaml" \
  -v "$(pwd)/data.db://home/appuser/data.db" \
  guohuiyuan/qzonewall-go:latest

# 7. 检查启动状态
echo "⏳ 等待服务初始化 (3秒)..."
sleep 3

if docker ps | grep -q "$CONTAINER_NAME"; then
    echo ""
    echo "✅ 部署成功！"
    echo "------------------------------------------------"
    echo "📂 工作目录: $(pwd)"
    echo "🌐 管理后台: http://localhost:8081"
    echo "👤 默认账号: admin / admin123 (请在配置中修改)"
    echo "------------------------------------------------"
    echo "📊 查看日志: docker logs -f $CONTAINER_NAME"
    echo "🛑 停止服务: docker stop $CONTAINER_NAME"
    echo "🔄 重启服务: docker restart $CONTAINER_NAME"
else
    echo ""
    echo "❌ 容器启动失败！"
    echo "请运行以下命令查看错误日志："
    echo "docker logs $CONTAINER_NAME"
    exit 1
fi