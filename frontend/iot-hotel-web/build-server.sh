#!/bin/bash
# 服务器端低内存构建脚本 - 适用于1.5GB可用内存环境
# 用法: bash build-server.sh

set -e

echo "=========================================="
echo "🚀 低内存服务器构建模式"
echo "=========================================="
echo ""

# 检查系统内存
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
  TOTAL_MEM=$(free -m | awk '/^Mem:/{print $2}')
  AVAILABLE_MEM=$(free -m | awk '/^Mem:/{print $7}')
  echo "💾 系统内存信息:"
  echo "   总内存: ${TOTAL_MEM}MB"
  echo "   可用内存: ${AVAILABLE_MEM}MB"
  echo ""

  if [ "$AVAILABLE_MEM" -lt 1500 ]; then
    echo "⚠️  可用内存不足1.5GB，建议关闭其他进程后重试"
    echo ""
  fi
fi

# 设置Node.js内存限制为1024MB (留出约500MB给系统)
export NODE_OPTIONS="--max-old-space-size=1024 --max-old-space-size=1024"
export LOW_MEMORY=true

echo "⚙️  构建配置:"
echo "   Node.js 堆内存上限: 1024MB"
echo "   低内存模式: 开启"
echo "   代码压缩: 关闭"
echo "   Source Map: 关闭"
echo "   CSS分割: 关闭"
echo ""
echo "🔨 开始构建..."
echo "------------------------------------------"

# 清理旧的构建产物
rm -rf dist node_modules/.vite

# 执行构建
node --max-old-space-size=1024 ./node_modules/vite/bin/vite.js build

BUILD_EXIT_CODE=$?

echo "------------------------------------------"
if [ $BUILD_EXIT_CODE -eq 0 ]; then
  echo "✅ 构建成功!"

  # 显示构建产物大小
  if command -v du &> /dev/null; then
    echo ""
    echo "📦 构建产物大小:"
    du -sh dist/*
    TOTAL_SIZE=$(du -sh dist | awk '{print $1}')
    echo "   总计: $TOTAL_SIZE"
  fi

  # 显示dist目录内容
  echo ""
  echo "📁 构建产物列表:"
  ls -lh dist/ | head -20
else
  echo "❌ 构建失败! 错误码: $BUILD_EXIT_CODE"
  exit $BUILD_EXIT_CODE
fi

echo ""
echo "=========================================="
echo "💡 提示:"
echo "   - 生产环境建议使用 nginx + gzip/brotli 压缩"
echo "   - 可使用 'npm run build' 进行完整压缩构建（需更多内存）"
echo "=========================================="
