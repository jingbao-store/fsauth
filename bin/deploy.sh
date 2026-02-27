#!/bin/bash
set -e

echo "🚀 fsauth 部署脚本"
echo "=================="
echo ""

# 检查必需的环境变量
if [ -z "$FEISHU_APP_ID" ] || [ -z "$FEISHU_APP_SECRET" ] || [ -z "$SECRET_KEY_BASE" ]; then
  echo "❌ 错误：缺少必需的环境变量"
  echo ""
  echo "请设置以下环境变量："
  echo "  - FEISHU_APP_ID"
  echo "  - FEISHU_APP_SECRET"
  echo "  - SECRET_KEY_BASE (使用 'rails secret' 生成)"
  echo ""
  echo "或者复制 .env.example 为 .env 并填入配置："
  echo "  cp .env.example .env"
  exit 1
fi

echo "✅ 环境变量检查通过"
echo ""

# 1. 安装依赖
echo "📦 安装依赖..."
bundle install --without development test
npm install
echo "✅ 依赖安装完成"
echo ""

# 2. 编译资源
echo "🎨 编译前端资源..."
npm run build:css
bundle exec rails assets:precompile RAILS_ENV=production
echo "✅ 资源编译完成"
echo ""

# 3. 初始化数据库
echo "🗄️  初始化数据库..."
bundle exec rails db:create RAILS_ENV=production || true
bundle exec rails db:migrate RAILS_ENV=production
echo "✅ 数据库初始化完成"
echo ""

# 4. 启动服务
echo "🚀 启动 fsauth 服务..."
echo ""
echo "访问地址：${PUBLIC_HOST:-http://localhost:3000}"
echo ""

bundle exec puma -C config/puma.rb
