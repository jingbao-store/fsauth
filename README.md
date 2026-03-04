# fsauth

飞书 OAuth 授权平台 — 多租户 SaaS，支持多用户、多应用管理

## ✨ 特性

- 🚀 **多租户架构** - 用户注册登录，创建多个应用配置
- 🔒 **独立应用凭证** - 每个应用拥有独立的飞书 App ID 和 Secret
- 🛡️ **HTTPS 加密** - 全程 HTTPS 通信，满足飞书安全要求
- ⏱️ **请求有效期** - 授权请求 10 分钟自动过期
- 📊 **状态追踪** - 实时追踪授权状态，清晰的流程反馈
- 💻 **开发者友好** - 简洁的 API 接口，完善的错误处理
- 🎨 **现代化 UI** - Tailwind CSS 设计，响应式布局

## 🎯 使用场景

fsauth 专为解决以下痛点而设计：

```
❌ 问题：本地应用无法通过 HTTPS 完成飞书 OAuth
          （飞书强制要求 OAuth 回调必须是 HTTPS）

✅ 解决：本地应用 → fsauth（HTTPS）→ 飞书 OAuth → 返回 token
```

## 🚀 快速开始

### 1. 用户注册和登录

访问 fsauth 平台首页，注册账号并登录。

### 2. 创建应用

1. 登录后进入"应用管理"页面
2. 点击"创建新应用"
3. 填写应用名称
4. 保存后获得应用的唯一 ID（UUID）

### 3. 配置飞书应用

1. 访问 [飞书开放平台](https://open.feishu.cn/) 创建应用
2. 获取你的飞书 `App ID` 和 `App Secret`
3. 在 fsauth 应用详情页填写飞书凭证
4. 复制应用详情页提供的**重定向 URL**
5. 在飞书应用的 OAuth 设置中添加该重定向 URL

**重要**：每个 fsauth 应用都有独立的重定向 URL，格式为：
```
https://your-fsauth.com/auth/feishu/callback/{app_id}
```

### 4. 集成到你的应用

在你的应用中使用该应用的 `app_id` 调用 API（见下方示例）。

## 📖 API 使用示例

### Python 集成示例

```python
import requests
import webbrowser
import time

# 你的 fsauth 应用 ID（从应用详情页获取）
APP_ID = "your-app-id-uuid"

# 1. 创建授权请求（必须传递 app_id）
response = requests.post('https://your-fsauth.com/api/v1/auth/request', 
    json={
        'app_id': APP_ID  # 必需参数
    })
data = response.json()

# 2. 打开浏览器引导用户授权
webbrowser.open(data['auth_url'])

# 3. 轮询获取 token
while True:
    result = requests.get('https://your-fsauth.com/api/v1/auth/token',
        params={'request_id': data['request_id']}).json()
    
    if result['status'] == 'completed':
        print(f"授权成功！Token: {result['token']}")
        print(f"用户信息: {result['user_info']}")
        break
    
    time.sleep(2)  # 2秒后重试
```

### cURL 示例

```bash
# 1. 创建授权请求（必须包含 app_id）
curl -X POST https://your-fsauth.com/api/v1/auth/request \
  -H "Content-Type: application/json" \
  -d '{
    "app_id": "your-app-id-uuid"
  }'

# 返回: {"request_id": "xxx", "auth_url": "https://..."}

# 2. 在浏览器打开 auth_url 完成授权

# 3. 获取 token
curl "https://your-fsauth.com/api/v1/auth/token?request_id=xxx"

# 返回: {"status": "completed", "token": "u-xxx", "user_info": {...}}
```

## 🔌 API 端点

| 端点 | 方法 | 说明 | 必需参数 |
|------|------|------|---------|
| `/api/v1/auth/request` | POST | 创建授权请求 | `app_id` (可选: `scope` 数组) |
| `/api/v1/auth/token` | GET | 获取授权 token | `request_id` |
| `/api/v1/auth/status` | GET | 查询授权状态 | `request_id` |

完整 API 文档：[docs/usage.md](docs/usage.md)

## 🏗️ 技术栈

- **后端**: Ruby on Rails 7.2
- **数据库**: PostgreSQL（UUID 主键）
- **认证**: Rails Authentication（支持多 OAuth）
- **样式**: Tailwind CSS v3
- **前端**: Stimulus + Turbo
- **HTTP 客户端**: HTTParty

## 📂 项目结构

```
fsauth/
├── app/
│   ├── controllers/
│   │   ├── applications_controller.rb       # 应用管理控制器
│   │   ├── auths_controller.rb              # 授权流程控制器
│   │   └── api/v1/auth_apis_controller.rb   # API 端点
│   ├── models/
│   │   ├── user.rb                          # 用户模型
│   │   ├── application.rb                   # 应用模型（UUID 主键）
│   │   ├── auth_request.rb                  # 授权请求模型
│   │   └── auth_token.rb                    # Token 模型
│   ├── services/
│   │   └── feishu_auth_service.rb           # 飞书 OAuth 服务
│   └── views/
│       ├── home/index.html.erb              # 主页
│       ├── applications/                    # 应用管理视图
│       └── auths/                           # 授权流程视图
├── config/
│   ├── application.yml                      # 环境变量配置
│   └── routes.rb                            # 路由配置
└── docs/
    └── usage.md                             # 详细使用文档
```

## 🔐 安全特性

1. **用户隔离** - 每个用户只能管理自己的应用
2. **应用隔离** - 每个应用有独立的飞书凭证和回调 URL
3. **UUID 标识** - 应用使用 UUID 而非递增 ID，提高安全性
4. **不存储敏感信息** - Token 仅在内存中短暂保留，用于轮询获取
5. **请求过期机制** - 授权请求 10 分钟自动失效
6. **HTTPS 强制** - 生产环境强制使用 HTTPS

## 📝 多租户工作流程

```mermaid
sequenceDiagram
    participant U as 用户
    participant P as fsauth 平台
    participant A as 本地应用
    participant F as 飞书 OAuth

    U->>P: 1. 注册登录
    U->>P: 2. 创建应用，填写飞书凭证
    P-->>U: 3. 返回 app_id 和重定向 URL
    
    U->>F: 4. 在飞书配置重定向 URL
    
    Note over A,F: 本地应用使用 app_id 调用 API
    A->>P: 5. POST /api/v1/auth/request (含 app_id)
    P-->>A: 返回 request_id 和 auth_url
    
    A->>A: 6. 打开浏览器访问 auth_url
    
    Note over P,F: 用户在浏览器中操作
    P->>F: 7. 重定向到飞书登录（使用该应用的凭证）
    F-->>P: 8. 回调并返回 code
    P->>F: 9. 用 code 换取 token（使用该应用的凭证）
    F-->>P: 10. 返回 user_access_token
    
    A->>P: 11. 轮询 GET /api/v1/auth/token
    P-->>A: 12. 返回 token 和用户信息
    
    A->>F: 13. 使用 token 调用飞书 API
```

## 🛠️ 开发指南

### 安装依赖

```bash
# 安装 Ruby 依赖
bundle install

# 安装 Node.js 依赖
npm install
```

### 初始化数据库

```bash
# 创建数据库
rails db:create

# 运行迁移
rails db:migrate

# （可选）加载种子数据
rails db:seed
```

### 启动开发服务器

```bash
# 启动开发服务器（自动编译 CSS 和 JS）
bin/dev
```

访问 `http://localhost:3000` 查看应用。

### 运行测试

```bash
# 运行全部测试
bundle exec rake test

# 运行单个测试文件
bundle exec rspec spec/requests/applications_spec.rb
bundle exec rspec spec/requests/auths_spec.rb
```

### 代码规范

- 遵循 Rails 最佳实践
- 使用 RuboCop 进行代码检查
- Turbo Stream 架构（无 JSON 响应，API 命名空间除外）
- 使用 Stimulus 控制器处理前端交互

### 本地调试

```bash
# 生成测试 token
rails dev:token[test@example.com]

# 查看日志
tail -f log/development.log

# Rails 控制台
rails runner "p User.count"
rails runner "p Application.count"
```

## 🚀 生产部署

### 环境变量

```bash
RAILS_ENV=production
SECRET_KEY_BASE=your-secret-key
DATABASE_URL=postgresql://user:pass@host/db
PUBLIC_HOST=https://your-fsauth-domain.com

# OAuth 配置（可选，使用 Clacky Auth 回退）
GOOGLE_OAUTH_ENABLED=true
GOOGLE_CLIENT_ID=xxx
GOOGLE_CLIENT_SECRET=xxx
```

**重要说明**：
- 不再需要全局的 `FEISHU_APP_ID` 和 `FEISHU_APP_SECRET`
- 每个应用在平台内管理自己的飞书凭证
- `PUBLIC_HOST` 可选，系统会自动使用 `request.base_url` 动态生成正确的 URL

### Docker 部署（推荐）

```dockerfile
# Dockerfile 示例
FROM ruby:3.3-alpine
WORKDIR /app
COPY . .
RUN bundle install --without development test
RUN npm install && npm run build:css
CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]
```

```bash
docker build -t fsauth .
docker run -p 3000:3000 --env-file .env fsauth
```

### Clacky 平台部署

fsauth 在 Clacky 平台上运行时会自动适配：

- 自动检测 Clacky 域名（`CLACKY_PUBLIC_HOST`）
- 支持 Clacky Auth OAuth 回退
- 自动使用 `request.base_url` 生成正确的回调 URL

## 🤝 贡献指南

欢迎提交 Issue 和 Pull Request！

1. Fork 本项目
2. 创建特性分支 (`git checkout -b feature/amazing-feature`)
3. 提交更改 (`git commit -m 'Add amazing feature'`)
4. 推送到分支 (`git push origin feature/amazing-feature`)
5. 开启 Pull Request

## 📄 许可证

MIT License

## 🔗 相关链接

- [飞书开放平台文档](https://open.feishu.cn/document/)
- [详细使用文档](docs/usage.md)
- [Rails 官方文档](https://guides.rubyonrails.org/)

## ❓ 常见问题

**Q: 为什么采用多租户架构？**  
A: 允许多个用户各自管理自己的飞书应用配置，互不干扰，更适合团队和企业使用。

**Q: 每个用户可以创建多少个应用？**  
A: 理论上无限制，每个应用都有独立的飞书凭证和回调 URL。

**Q: 应用 ID 为什么使用 UUID？**  
A: UUID 提供更好的安全性，避免应用 ID 被猜测或枚举攻击。

**Q: token 会被存储吗？**  
A: 不会。fsauth 仅在内存中短暂保留供轮询获取，不持久化到数据库。

**Q: 支持多用户同时授权吗？**  
A: 支持。每个授权请求都有独立的 UUID，跨用户、跨应用互不干扰。

**Q: 轮询频率建议多少？**  
A: 建议 2-3 秒，避免过于频繁。

**Q: 授权请求有效期多久？**  
A: 默认 10 分钟，可在代码中自定义。

**Q: 重定向 URL 显示 localhost 怎么办？**  
A: 系统会自动使用 `request.base_url` 生成正确的 URL。在 Clacky 平台或生产环境访问时，会显示实际域名。如果在本地开发，可以配置 `PUBLIC_HOST` 环境变量。

## 📧 联系方式

- 问题反馈：提交 GitHub Issue
- 邮件：your-email@example.com

---

⭐ 如果这个项目对你有帮助，欢迎 Star！
