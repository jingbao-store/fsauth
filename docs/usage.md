# fsauth 使用指南

## 概述

fsauth 是一个飞书免登授权中间层服务，解决本地开发环境（如 openclaw）无法通过 HTTPS 完成飞书 OAuth 授权的问题。

## 工作原理

```
本地 openclaw → fsauth Web 应用 → 飞书 OAuth → 获取 token → 返回给 openclaw
```

## 前置准备

### 1. 配置飞书应用

1. 访问 [飞书开放平台](https://open.feishu.cn/)
2. 创建企业自建应用或获取现有应用的凭证
3. 获取以下信息：
   - **App ID**（应用凭证 - 应用 ID）
   - **App Secret**（应用凭证 - 应用密钥）

4. 配置重定向 URL：
   - 进入应用管理 → 安全设置 → 重定向 URL
   - 添加：`https://your-fsauth-domain.com/auth/feishu/callback`
   - 替换 `your-fsauth-domain.com` 为你的 fsauth 部署域名

### 2. 配置 fsauth

编辑 `config/application.yml`：

```yaml
# 飞书应用凭证
FEISHU_APP_ID: 'cli_xxxxxxxxxxxxxxxx'
FEISHU_APP_SECRET: 'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx'

# OAuth 回调地址（生产环境会自动替换为实际域名）
FEISHU_OAUTH_REDIRECT_URI: '<%= ENV.fetch("PUBLIC_HOST", "http://localhost:3000") %>/auth/feishu/callback'
```

### 3. 启动 fsauth 服务

```bash
# 开发环境
bin/dev

# 生产环境（需要先配置好数据库）
RAILS_ENV=production bundle exec rails db:create db:migrate
RAILS_ENV=production bundle exec rails server
```

## 使用流程

### 方式一：通过 API 集成（推荐）

适合在 openclaw 等本地应用中集成使用。

#### 步骤 1: 创建授权请求

```bash
curl -X POST https://your-fsauth-domain.com/api/v1/auth/request \
  -H "Content-Type: application/json" \
  -d '{
    "app_id": "your-application-uuid"
  }'
```

**响应示例：**
```json
{
  "request_id": "550e8400-e29b-41d4-a716-446655440000",
  "auth_url": "https://your-fsauth-domain.com/auth/start?request_id=550e8400-e29b-41d4-a716-446655440000",
  "expires_at": "2024-01-01T12:10:00Z"
}
```

#### 步骤 2: 引导用户授权

在 openclaw 中打开浏览器访问返回的 `auth_url`：

```python
# Python 示例
import webbrowser
webbrowser.open(auth_url)
```

用户会看到授权确认页面，点击"授权"按钮后跳转到飞书登录。

#### 步骤 3: 轮询获取 Token

授权完成后，openclaw 需要轮询查询 token：

```bash
curl "https://your-fsauth-domain.com/api/v1/auth/token?request_id=550e8400-e29b-41d4-a716-446655440000"
```

**响应示例（授权完成）：**
```json
{
  "status": "completed",
  "token": "u-7xxxxxxxxxxxxxxxxxxxxxxxxxxx",
  "user_info": {
    "open_id": "ou_xxxxxxxxxxxxxxxxxxxxxxxx",
    "name": "张三"
  }
}
```

**响应示例（等待授权）：**
```json
{
  "status": "pending",
  "message": "Authorization in progress"
}
```

**响应示例（已过期）：**
```json
{
  "status": "expired",
  "message": "Authorization request expired"
}
```

#### 步骤 4: 使用 Token 调用飞书 API

```bash
# 示例：获取用户信息
curl -X GET https://open.feishu.cn/open-apis/authen/v1/user_info \
  -H "Authorization: Bearer u-7xxxxxxxxxxxxxxxxxxxxxxxxxxx"
```

#### 步骤 5: Token 刷新（可选）

`user_access_token` 有过期时间（通常 7200 秒 / 2 小时），过期后可以使用 `refresh_token` 获取新的 token，无需用户重新授权。

```bash
curl -X POST https://your-fsauth-domain.com/api/v1/auth/refresh \
  -H "Content-Type: application/json" \
  -d '{
    "app_id": "your-application-uuid",
    "request_id": "550e8400-e29b-41d4-a716-446655440000"
  }'
```

**响应示例：**
```json
{
  "user_access_token": "u-8yyyyyyyyyyyyyyyyyyyyyyyyyy",
  "expires_in": 7200,
  "refresh_token_expires_in": 604800,
  "message": "Token refreshed successfully"
}
```

**注意事项：**
- `refresh_token` 有效期通常为 365 天
- 每次刷新会返回新的 `user_access_token` 和 `refresh_token`
- 旧的 token 在刷新后立即失效（有 1 分钟宽限期）
- 如果 `refresh_token` 过期，需要重新发起授权流程

### 方式二：手动测试

适合开发调试或单次授权场景。

1. 直接在浏览器访问：`https://your-fsauth-domain.com`
2. 由于没有 API 创建的 request_id，需要先通过 API 创建请求
3. 使用返回的 `auth_url` 进行授权
4. 完成后通过 API 获取 token

## OpenClaw 集成示例

### Python 实现

```python
import requests
import time
import webbrowser

class FsauthClient:
    def __init__(self, fsauth_url, app_id):
        self.fsauth_url = fsauth_url.rstrip('/')
        self.app_id = app_id
        self.request_id = None
    
    def authorize(self, timeout=300, poll_interval=2):
        """
        发起授权流程并等待用户完成授权
        
        Args:
            timeout: 超时时间（秒），默认 5 分钟
            poll_interval: 轮询间隔（秒），默认 2 秒
            
        Returns:
            dict: 包含 token 和用户信息的字典
        """
        # 1. 创建授权请求
        response = requests.post(
            f"{self.fsauth_url}/api/v1/auth/request",
            json={"app_id": self.app_id}
        )
        response.raise_for_status()
        data = response.json()
        
        self.request_id = data['request_id']
        auth_url = data['auth_url']
        
        print(f"请在浏览器中完成授权: {auth_url}")
        
        # 2. 打开浏览器
        webbrowser.open(auth_url)
        
        # 3. 轮询获取 token
        start_time = time.time()
        while time.time() - start_time < timeout:
            response = requests.get(
                f"{self.fsauth_url}/api/v1/auth/token",
                params={"request_id": self.request_id}
            )
            response.raise_for_status()
            result = response.json()
            
            if result['status'] == 'completed':
                print("授权成功！")
                return {
                    'access_token': result['token'],
                    'user_info': result.get('user_info', {})
                }
            elif result['status'] == 'expired':
                raise Exception("授权请求已过期")
            elif result['status'] == 'failed':
                raise Exception("授权失败")
            
            # 等待后继续轮询
            time.sleep(poll_interval)
        
        raise TimeoutError("授权超时")
    
    def refresh_token(self):
        """
        刷新 user_access_token
        
        Returns:
            dict: 包含新的 access_token 的字典
        """
        if not self.request_id:
            raise Exception("没有可用的 request_id，请先完成授权")
        
        response = requests.post(
            f"{self.fsauth_url}/api/v1/auth/refresh",
            json={
                "app_id": self.app_id,
                "request_id": self.request_id
            }
        )
        response.raise_for_status()
        data = response.json()
        
        return {
            'access_token': data['user_access_token'],
            'expires_in': data.get('expires_in'),
            'refresh_token_expires_in': data.get('refresh_token_expires_in')
        }

# 使用示例
if __name__ == "__main__":
    client = FsauthClient("https://your-fsauth-domain.com", "your-application-uuid")
    
    try:
        # 首次授权
        result = client.authorize()
        print(f"Access Token: {result['access_token']}")
        print(f"User Info: {result['user_info']}")
        
        # 使用 token 调用飞书 API
        # ...
        
        # Token 过期后刷新
        # refreshed = client.refresh_token()
        # print(f"New Access Token: {refreshed['access_token']}")
        
    except Exception as e:
        print(f"授权失败: {e}")
```

### Node.js 实现

```javascript
const axios = require('axios');
const open = require('open');

class FsauthClient {
  constructor(fsauthUrl, appId) {
    this.fsauthUrl = fsauthUrl.replace(/\/$/, '');
    this.appId = appId;
    this.requestId = null;
  }
  
  async authorize(timeout = 300000, pollInterval = 2000) {
    // 1. 创建授权请求
    const { data } = await axios.post(`${this.fsauthUrl}/api/v1/auth/request`, {
      app_id: this.appId
    });
    
    this.requestId = data.request_id;
    const { auth_url } = data;
    console.log(`请在浏览器中完成授权: ${auth_url}`);
    
    // 2. 打开浏览器
    await open(auth_url);
    
    // 3. 轮询获取 token
    const startTime = Date.now();
    while (Date.now() - startTime < timeout) {
      const response = await axios.get(`${this.fsauthUrl}/api/v1/auth/token`, {
        params: { request_id: this.requestId }
      });
      
      const result = response.data;
      
      if (result.status === 'completed') {
        console.log('授权成功！');
        return {
          access_token: result.token,
          user_info: result.user_info || {}
        };
      } else if (result.status === 'expired') {
        throw new Error('授权请求已过期');
      } else if (result.status === 'failed') {
        throw new Error('授权失败');
      }
      
      // 等待后继续轮询
      await new Promise(resolve => setTimeout(resolve, pollInterval));
    }
    
    throw new Error('授权超时');
  }
  
  async refreshToken() {
    if (!this.requestId) {
      throw new Error('没有可用的 request_id，请先完成授权');
    }
    
    const { data } = await axios.post(`${this.fsauthUrl}/api/v1/auth/refresh`, {
      app_id: this.appId,
      request_id: this.requestId
    });
    
    return {
      access_token: data.user_access_token,
      expires_in: data.expires_in,
      refresh_token_expires_in: data.refresh_token_expires_in
    };
  }
}

// 使用示例
(async () => {
  const client = new FsauthClient('https://your-fsauth-domain.com', 'your-application-uuid');
  
  try {
    // 首次授权
    const result = await client.authorize();
    console.log('Access Token:', result.access_token);
    console.log('User Info:', result.user_info);
    
    // 使用 token 调用飞书 API
    // ...
    
    // Token 过期后刷新
    // const refreshed = await client.refreshToken();
    // console.log('New Access Token:', refreshed.access_token);
    
  } catch (error) {
    console.error('授权失败:', error.message);
  }
})();
```

## API 参考

### POST /api/v1/auth/request

创建授权请求。

**请求体：**
```json
{
  "app_id": "your-application-uuid"  // 必需，应用 ID
}
```

**响应：**
```json
{
  "request_id": "uuid",
  "auth_url": "https://fsauth.example.com/auth/start?request_id=uuid",
  "expires_at": "2024-01-01T12:10:00Z"
}
```

### GET /api/v1/auth/token

获取授权 token。

**参数：**
- `request_id` (必需): 授权请求 ID

**响应：**
```json
{
  "status": "completed|pending|expired|failed",
  "token": "user_access_token",  // status=completed 时返回
  "user_info": {                 // status=completed 时返回
    "open_id": "ou_xxx",
    "name": "用户名"
  }
}
```

### GET /api/v1/auth/status

查询授权状态（与 /auth/token 类似，但不返回 token）。

**参数：**
- `request_id` (必需): 授权请求 ID

**响应：**
```json
{
  "status": "completed|pending|expired|failed",
  "message": "状态描述"
}
```

### POST /api/v1/auth/refresh

刷新 user_access_token。

**请求体：**
```json
{
  "app_id": "your-application-uuid",  // 必需，应用 ID
  "request_id": "uuid"                 // 必需，授权请求 ID
}
```

**响应：**
```json
{
  "user_access_token": "u-8yyyyyyyyyyyyyyyyyyyyyyyyyy",
  "expires_in": 7200,
  "refresh_token_expires_in": 604800,
  "message": "Token refreshed successfully"
}
```

**错误响应：**
```json
{
  "error": "Refresh token expired or unavailable",
  "message": "Please re-authorize via /api/v1/auth/request"
}
```

## 安全建议

1. **HTTPS 必须**: 生产环境必须使用 HTTPS，飞书 OAuth 强制要求
2. **Token 有效期**: Token 默认 10 分钟有效期，过期后需重新授权
3. **不存储 Token**: fsauth 不会永久存储 token，仅在内存中短暂保留供轮询获取
4. **速率限制**: 建议对 API 添加速率限制防止滥用

## 故障排除

### 问题 1: 授权后 token 一直显示 pending

**原因：** 可能是飞书回调失败或配置错误

**解决：**
1. 检查 `config/application.yml` 中的 `FEISHU_OAUTH_REDIRECT_URI` 是否正确
2. 确认飞书开放平台配置的重定向 URL 与实际一致
3. 查看 Rails 日志 `log/development.log` 或 `log/production.log`

### 问题 2: 授权请求过期

**原因：** 授权请求有 10 分钟有效期

**解决：**
- 重新发起授权流程
- 如需更长有效期，修改 `app/controllers/api/v1/auth_apis_controller.rb` 中的 `expires_at`

### 问题 3: CORS 错误

**原因：** 浏览器跨域限制

**解决：**
- fsauth 采用轮询方式，不需要跨域请求
- 确保 openclaw 使用服务端发起 API 请求，而非浏览器端

### 问题 4: 无法打开授权页面

**原因：** fsauth 服务未启动或网络不可达

**解决：**
1. 确认 fsauth 服务正常运行：`curl https://your-fsauth-domain.com`
2. 检查防火墙和网络配置
3. 确认域名 DNS 解析正确

## 生产环境部署

### 数据库配置

编辑 `config/database.yml` 生产环境配置：

```yaml
production:
  adapter: postgresql
  encoding: unicode
  pool: <%= ENV.fetch("RAILS_MAX_THREADS") { 5 } %>
  database: fsauth_production
  username: fsauth
  password: <%= ENV['DATABASE_PASSWORD'] %>
  host: <%= ENV['DATABASE_HOST'] %>
```

### 环境变量

```bash
export RAILS_ENV=production
export SECRET_KEY_BASE=$(rails secret)
export DATABASE_HOST=your-db-host
export DATABASE_PASSWORD=your-db-password
export PUBLIC_HOST=https://your-fsauth-domain.com
export FEISHU_APP_ID=cli_xxxxxxxxxxxxxxxx
export FEISHU_APP_SECRET=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

### 启动服务

```bash
# 安装依赖
bundle install --without development test

# 编译资源
npm install
npm run build:css
bundle exec rails assets:precompile

# 初始化数据库
bundle exec rails db:create db:migrate

# 启动服务（使用 systemd、supervisord 或 Docker）
bundle exec puma -C config/puma.rb
```

## 监控与日志

- **应用日志**: `log/production.log`
- **访问日志**: Web 服务器（Nginx/Apache）日志
- **数据库监控**: 监控 `auth_requests` 表大小和查询性能

## 相关链接

- [飞书开放平台文档](https://open.feishu.cn/document/home/introduction-to-custom-app-development)
- [飞书用户身份与授权概述](https://open.feishu.cn/document/common-capabilities/sso/api/get-user-info)
- [fsauth GitHub 仓库](#)（如有）

## 常见问题（FAQ）

**Q: token 会被存储吗？**  
A: 不会。fsauth 仅在内存中短暂保留 token（用于轮询获取），不会持久化到数据库。

**Q: 支持多个应用同时使用吗？**  
A: 支持。每个授权请求都有独立的 request_id，互不干扰。

**Q: 轮询频率建议？**  
A: 建议 2-3 秒轮询一次，避免过于频繁造成服务器压力。

**Q: 授权失败如何处理？**  
A: 检查日志获取详细错误信息，常见原因包括飞书应用配置错误、网络问题、用户拒绝授权等。

**Q: 可以获取哪些用户信息？**  
A: 取决于飞书应用的权限配置，通常包括 open_id、用户名、头像等基本信息。
