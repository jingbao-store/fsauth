# fsauth 示例代码

本目录包含使用 fsauth 的示例客户端代码。

## 可用示例

### 1. Python 客户端 (`python_client.py`)

完整的 Python 集成示例，包含：
- FsauthClient 类封装
- 授权流程演示
- 飞书 API 调用示例
- 状态查询示例

**依赖安装：**
```bash
pip install requests
```

**运行：**
```bash
python examples/python_client.py
```

### 2. Node.js 客户端 (`nodejs_client.js`)

完整的 Node.js 集成示例，包含：
- FsauthClient 类封装
- 授权流程演示
- 飞书 API 调用示例
- 状态查询示例

**依赖安装：**
```bash
npm install axios open
```

**运行：**
```bash
node examples/nodejs_client.js
```

## 快速开始

### Python 示例

```python
from fsauth_client import FsauthClient

# 初始化客户端
client = FsauthClient("http://localhost:3000")

# 发起授权（会自动打开浏览器）
result = client.authorize()

# 获取 token
print(f"Access Token: {result['access_token']}")
print(f"User Info: {result['user_info']}")
```

### Node.js 示例

```javascript
const { FsauthClient } = require('./nodejs_client');

// 初始化客户端
const client = new FsauthClient('http://localhost:3000');

// 发起授权（会自动打开浏览器）
const result = await client.authorize();

// 获取 token
console.log('Access Token:', result.access_token);
console.log('User Info:', result.user_info);
```

## 自定义集成

如果你想自己实现客户端，核心流程如下：

```bash
# 1. 创建授权请求
curl -X POST http://localhost:3000/api/v1/auth/request \
  -H "Content-Type: application/json" \
  -d '{"app_id": "your-application-uuid"}'

# 返回: {"request_id": "xxx", "auth_url": "http://..."}

# 2. 打开浏览器访问 auth_url，用户完成授权

# 3. 轮询获取 token（每 2 秒一次）
curl "http://localhost:3000/api/v1/auth/token?request_id=xxx"

# 返回: {"status": "completed", "token": "u-xxx", "user_info": {...}}
```

## 注意事项

1. **fsauth 服务必须运行** - 确保 fsauth 服务在 `http://localhost:3000` 运行
2. **飞书应用配置** - 需要在 `config/application.yml` 配置飞书应用凭证
3. **浏览器授权** - 授权需要在浏览器中完成飞书登录
4. **轮询间隔** - 建议 2-3 秒轮询一次，避免频繁请求
5. **超时处理** - 授权请求默认 10 分钟有效期

## 更多信息

- 完整 API 文档：[../docs/usage.md](../docs/usage.md)
- 项目主页：[../README.md](../README.md)
