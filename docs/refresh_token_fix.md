# Refresh Token 修复说明

## 问题描述

之前的实现中，`refresh_token_expires_in` 字段返回 `null`，导致无法刷新访问令牌。根本原因是：

**飞书 OAuth 要求在授权 URL 的 `scope` 参数中必须包含 `offline_access`，才能获取 `refresh_token`**。

### 问题根源

根据飞书文档：
> 在开通 offline_access 权限后，如需获取 refresh_token，具体的请求参数设置如下：
> 首先在发起授权时，授权链接的 scope 参数中必须拼接 offline_access

之前的代码在生成授权 URL 时没有包含 `scope` 参数，导致：
- ❌ 飞书 OAuth 不返回 `refresh_token`
- ❌ `refresh_token_expires_in` 为 `null`
- ❌ 无法使用刷新令牌功能

## 解决方案

### 1. 修改 FeishuAuthService

在 `authorization_url` 方法中添加 `scope` 参数支持：

```ruby
def authorization_url(state:, scope: 'offline_access')
  base_url = 'https://accounts.feishu.cn/open-apis/authen/v1/authorize'
  
  # Convert scope to space-separated string if it's an array
  scope_string = scope.is_a?(Array) ? scope.join(' ') : scope.to_s
  
  # Ensure offline_access is always included for refresh_token support
  unless scope_string.include?('offline_access')
    scope_string = "#{scope_string} offline_access".strip
  end
  
  params = {
    client_id: @app_id,
    response_type: 'code',
    redirect_uri: @redirect_uri,
    state: state,
    scope: scope_string  # ✅ 添加 scope 参数
  }
  "#{base_url}?#{URI.encode_www_form(params)}"
end
```

**功能特性：**
- ✅ 默认包含 `offline_access` scope
- ✅ 支持自定义 scope（字符串或数组）
- ✅ 自动确保 `offline_access` 始终被包含
- ✅ 防止重复添加 `offline_access`

### 2. 更新 AuthsController

在调用 `authorization_url` 时显式传递 scope：

```ruby
# IMPORTANT: Must include 'offline_access' scope to receive refresh_token
# See: https://open.feishu.cn/document/authentication-management
redirect_to service.authorization_url(state: state, scope: 'offline_access'), allow_other_host: true
```

## 效果对比

### 修复前的授权 URL
```
https://accounts.feishu.cn/open-apis/authen/v1/authorize?
  client_id=cli_xxx&
  response_type=code&
  redirect_uri=https%3A%2F%2Fexample.com%2Fcallback&
  state=xxx
```

❌ 缺少 `scope` 参数

### 修复后的授权 URL
```
https://accounts.feishu.cn/open-apis/authen/v1/authorize?
  client_id=cli_xxx&
  response_type=code&
  redirect_uri=https%3A%2F%2Fexample.com%2Fcallback&
  state=xxx&
  scope=offline_access
```

✅ 包含 `scope=offline_access` 参数

## API 响应变化

### 修复前（问题版本）
```json
{
  "state": "authorized",
  "user_access_token": "u-7tmwG4coh8...",
  "refresh_token": null,
  "expires_in": 6900,
  "refresh_token_expires_in": null,
  "user_info": { ... }
}
```

❌ `refresh_token` 和 `refresh_token_expires_in` 为 `null`

### 修复后（正常版本）
```json
{
  "state": "authorized",
  "user_access_token": "u-7tmwG4coh8YbhMJMgLVBfJk0nPOk0hWjU22y2Aw0067x",
  "refresh_token": "r-AfswUBdVtzEcfDshRf9cOdaGmIj0zfLwJGHjUbZyI0kux",
  "expires_in": 6900,
  "refresh_token_expires_in": 604800,
  "user_info": {
    "open_id": "ou_5c45e3505566e8c0af46fdfebe60e01b",
    "union_id": "on_c88028e0f85084891f5c5adfab8ba110",
    "user_id": "4da7b53c",
    "name": "张润胜",
    ...
  }
}
```

✅ `refresh_token` 和 `refresh_token_expires_in` 正常返回

## 高级用法

### 请求多个权限 scope

如果应用需要额外的权限，可以传递多个 scope：

**字符串形式：**
```ruby
service.authorization_url(
  state: state,
  scope: 'bitable:app:readonly contact:contact.base:readonly offline_access'
)
```

**数组形式：**
```ruby
service.authorization_url(
  state: state,
  scope: ['bitable:app:readonly', 'contact:contact.base:readonly']
)
# offline_access 会自动添加
```

### 实际授权 URL 示例

```
https://accounts.feishu.cn/open-apis/authen/v1/authorize?
  client_id=cli_a5d611352af9d00b&
  redirect_uri=https%3A%2F%2Fexample.com%2Fapi%2Foauth%2Fcallback&
  scope=bitable%3Aapp%3Areadonly+offline_access&
  state=xxx
```

## 测试覆盖

新增测试用例验证 scope 功能：

1. ✅ 默认包含 `offline_access`
2. ✅ 支持自定义 scope 并自动添加 `offline_access`
3. ✅ 支持数组形式的 scope
4. ✅ 防止重复添加 `offline_access`

测试文件：`spec/services/feishu_auth_service_spec.rb`

```ruby
it 'generates OAuth authorization URL with offline_access scope' do
  url = service.authorization_url(state: 'test_state')
  expect(url).to include('scope=offline_access')
end

it 'supports custom scopes while ensuring offline_access is included' do
  url = service.authorization_url(state: 'test_state', scope: 'bitable:app:readonly')
  expect(url).to include('scope=bitable%3Aapp%3Areadonly+offline_access')
end
```

## 刷新令牌使用

修复后，客户端可以正常使用刷新令牌功能：

### 1. 获取初始令牌
```bash
GET /api/v1/auth/token?request_id=xxx

Response:
{
  "user_access_token": "u-xxx",
  "refresh_token": "r-yyy",
  "expires_in": 7200,
  "refresh_token_expires_in": 604800
}
```

### 2. 刷新访问令牌
```bash
POST /api/v1/auth/refresh
{
  "app_id": "your-app-id",
  "request_id": "original-request-id"
}

Response:
{
  "user_access_token": "u-new-token",
  "expires_in": 7200,
  "refresh_token_expires_in": 604800,
  "message": "Token refreshed successfully"
}
```

## 重要提示

⚠️ **应用配置要求**

在飞书开放平台后台，确保应用已开通以下权限：
- ✅ **offline_access** 权限（用于获取 refresh_token）
- ✅ 其他业务所需的权限（如 `bitable:app:readonly`、`contact:contact.base:readonly` 等）

如果未开通 `offline_access` 权限，即使在授权 URL 中包含该 scope，飞书也不会返回 refresh_token。

## 参考文档

- [飞书 OAuth 2.0 授权](https://open.feishu.cn/document/authentication-management)
- [获取授权码](https://open.feishu.cn/document/authentication-management/get-authorization-code)
- [获取 user_access_token](https://open.feishu.cn/document/authentication-management/get-user-access-token)
- [刷新 user_access_token](https://open.feishu.cn/document/authentication-management/refresh-user-access-token)
