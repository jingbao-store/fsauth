# fsauth 快速开始指南

## 30 秒快速体验

### 1. 配置飞书应用

复制配置模板并填入你的飞书应用凭证：

```bash
cp config/application.yml.example config/application.yml
```

编辑 `config/application.yml`，填入：
- `FEISHU_APP_ID`: 你的飞书应用 ID
- `FEISHU_APP_SECRET`: 你的飞书应用密钥

> 💡 还没有飞书应用？访问 [飞书开放平台](https://open.feishu.cn/) 创建一个

### 2. 启动服务

```bash
# 安装依赖
bundle install
npm install

# 初始化数据库
rails db:create db:migrate db:seed

# 启动开发服务器
bin/dev
```

服务将运行在 `http://localhost:3000`

### 3. 测试授权流程

**方式 A：通过 API（推荐）**

```bash
# 1. 创建授权请求
curl -X POST http://localhost:3000/api/v1/auth/request \
  -H "Content-Type: application/json" \
  -d '{"app_id": "your-application-uuid"}'

# 返回示例：
# {
#   "request_id": "550e8400-e29b-41d4-a716-446655440000",
#   "auth_url": "http://localhost:3000/auth/start?request_id=...",
#   "expires_at": "2024-01-01T12:10:00Z"
# }

# 2. 在浏览器中打开返回的 auth_url

# 3. 完成授权后，轮询获取 token
curl "http://localhost:3000/api/v1/auth/token?request_id=550e8400-e29b-41d4-a716-446655440000"

# 授权完成后返回：
# {
#   "status": "completed",
#   "token": "u-7xxxxxxxxxxxxxxxxxxxxxxxxxxx",
#   "user_info": {"open_id": "ou_xxx", "name": "张三"}
# }
```

**方式 B：使用示例客户端**

Python:
```bash
pip install requests
python examples/python_client.py
```

Node.js:
```bash
npm install axios open
node examples/nodejs_client.js
```

## 常见问题

### Q: 如何获取飞书应用凭证？

1. 访问 [飞书开放平台](https://open.feishu.cn/)
2. 创建企业自建应用
3. 在"凭证与基础信息"页面找到 App ID 和 App Secret
4. 在"安全设置"中配置重定向 URL：`http://localhost:3000/auth/feishu/callback`（开发环境）

### Q: 授权请求一直显示 pending？

可能原因：
1. 飞书应用配置不正确（检查 App ID/Secret）
2. 重定向 URL 配置错误
3. 用户还未在浏览器中完成授权

查看日志：
```bash
tail -f log/development.log
```

### Q: 如何部署到生产环境？

参考完整文档：
- [部署指南](docs/usage.md#生产环境部署)
- [环境变量配置](config/application.yml.example)

### Q: 支持哪些飞书 API？

获取的 `user_access_token` 可以调用所有飞书用户身份相关的 API，取决于你的飞书应用权限配置。

常用 API：
- 获取用户信息：`/open-apis/authen/v1/user_info`
- 访问文档：`/open-apis/drive/v1/files/*`
- 发送消息：`/open-apis/im/v1/messages`

完整 API 文档：https://open.feishu.cn/document/

## 下一步

- 📖 阅读 [完整使用文档](docs/usage.md)
- 🔌 查看 [API 参考](docs/usage.md#api-参考)
- 💻 运行 [示例代码](examples/)
- 🚀 了解 [生产部署](docs/usage.md#生产环境部署)

## 帮助与支持

- 📝 提交 Issue：[GitHub Issues](#)
- 📧 邮件联系：your-email@example.com
- 📚 飞书开放平台文档：https://open.feishu.cn/document/

---

**祝你使用愉快！** 🎉
