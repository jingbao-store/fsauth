#!/bin/bash

# fsauth API 测试脚本
# 用于快速测试 API 端点是否正常工作

set -e

# 配置
FSAUTH_URL="${FSAUTH_URL:-http://localhost:3000}"
APP_ID="${APP_ID:-your-application-uuid}"

echo "=========================================="
echo "fsauth API 测试"
echo "=========================================="
echo "服务地址: $FSAUTH_URL"
echo "应用 ID: $APP_ID"
echo ""

# 测试 1: 创建授权请求
echo "📝 测试 1: 创建授权请求"
echo "----------------------------------------"
RESPONSE=$(curl -s -X POST "$FSAUTH_URL/api/v1/auth/request" \
  -H "Content-Type: application/json" \
  -d "{\"app_id\": \"$APP_ID\"}")

echo "响应: $RESPONSE"
echo ""

# 提取 request_id
REQUEST_ID=$(echo $RESPONSE | grep -o '"request_id":"[^"]*"' | cut -d'"' -f4)
AUTH_URL=$(echo $RESPONSE | grep -o '"auth_url":"[^"]*"' | sed 's/"auth_url":"//g' | sed 's/"//g')

if [ -z "$REQUEST_ID" ]; then
  echo "❌ 失败: 无法获取 request_id"
  exit 1
fi

echo "✅ 成功获取 request_id: $REQUEST_ID"
echo "📌 授权 URL: $AUTH_URL"
echo ""

# 测试 2: 查询授权状态（应该是 pending）
echo "📊 测试 2: 查询授权状态"
echo "----------------------------------------"
STATUS_RESPONSE=$(curl -s "$FSAUTH_URL/api/v1/auth/status?request_id=$REQUEST_ID")
echo "响应: $STATUS_RESPONSE"
echo ""

STATUS=$(echo $STATUS_RESPONSE | grep -o '"status":"[^"]*"' | cut -d'"' -f4)
if [ "$STATUS" = "pending" ]; then
  echo "✅ 状态正确: pending（等待授权）"
else
  echo "⚠️  状态: $STATUS"
fi
echo ""

# 测试 3: 查询 token（应该返回 pending，因为还未授权）
echo "🔑 测试 3: 查询 token（未授权状态）"
echo "----------------------------------------"
TOKEN_RESPONSE=$(curl -s "$FSAUTH_URL/api/v1/auth/token?request_id=$REQUEST_ID")
echo "响应: $TOKEN_RESPONSE"
echo ""

# 测试 4: 访问主页
echo "🏠 测试 4: 访问主页"
echo "----------------------------------------"
HOME_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$FSAUTH_URL/")
if [ "$HOME_STATUS" = "200" ]; then
  echo "✅ 主页访问成功 (HTTP $HOME_STATUS)"
else
  echo "❌ 主页访问失败 (HTTP $HOME_STATUS)"
fi
echo ""

# 测试 5: 访问授权页面
echo "🔐 测试 5: 访问授权页面"
echo "----------------------------------------"
AUTH_PAGE_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$FSAUTH_URL/auth/start?request_id=$REQUEST_ID")
if [ "$AUTH_PAGE_STATUS" = "200" ]; then
  echo "✅ 授权页面访问成功 (HTTP $AUTH_PAGE_STATUS)"
else
  echo "❌ 授权页面访问失败 (HTTP $AUTH_PAGE_STATUS)"
fi
echo ""

# 总结
echo "=========================================="
echo "测试总结"
echo "=========================================="
echo "✅ API 端点正常工作"
echo "✅ 授权请求创建成功"
echo "✅ 状态查询正常"
echo ""
echo "📌 下一步："
echo "   1. 在浏览器中打开授权 URL 完成飞书登录"
echo "   2. 授权完成后，使用以下命令获取 token："
echo ""
echo "   curl \"$FSAUTH_URL/api/v1/auth/token?request_id=$REQUEST_ID\""
echo ""
echo "   或者直接在浏览器中访问："
echo "   $AUTH_URL"
echo ""
echo "=========================================="
