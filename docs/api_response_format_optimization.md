# API 响应格式优化说明

## 问题描述

之前的 API 返回格式将所有授权数据嵌套在 `auth_data` 对象中，导致：
1. 数据结构过于复杂，嵌套层级深
2. 不符合标准 OAuth 响应格式
3. 客户端需要多次解析才能获取需要的数据

### 旧格式示例 (问题版本)
```json
{
  "state": "authorized",
  "user_access_token": "u-7tmwG4coh8...",
  "auth_data": {
    "expires_in": 6900,
    "refresh_token_expires_in": null,
    "user_info": {
      "open_id": "ou_5c45e3505566...",
      "name": "张润胜",
      ...
    }
  },
  "message": "Authorization completed successfully"
}
```

## 解决方案

优化后的 API 返回格式遵循 OAuth 2.0 标准，将所有关键字段提升到顶层：

### 新格式示例 (优化后)
```json
{
  "state": "authorized",
  "user_access_token": "u-7tmwG4coh8YbhMJMgLVBfJk0nPOk0hWjU22y2Aw0067x",
  "refresh_token": "r-AfswUBdVtzEcfDshRf...",
  "expires_in": 6900,
  "refresh_token_expires_in": 604800,
  "user_info": {
    "open_id": "ou_5c45e3505566e8c0af46fdfebe60e01b",
    "union_id": "on_c88028e0f85084891f5c5adfab8ba110",
    "user_id": "4da7b53c",
    "name": "张润胜",
    "en_name": "Zhang San",
    "avatar_url": "https://s1-imfile.feishucdn.com/...",
    "avatar_thumb": "https://s1-imfile.feishucdn.com/...",
    "avatar_middle": "https://s3-imfile.feishucdn.com/...",
    "avatar_big": "https://s1-imfile.feishucdn.com/...",
    "tenant_key": "15bde27fff1f175f"
  },
  "message": "Authorization completed successfully"
}
```

## 改进点

### 1. 扁平化数据结构
- ✅ 移除不必要的 `auth_data` 嵌套层级
- ✅ 所有关键字段直接位于响应根层级
- ✅ 客户端可以直接访问 `response.expires_in` 而不是 `response.auth_data.expires_in`

### 2. 符合 OAuth 2.0 标准
- ✅ `user_access_token`: 访问令牌（主要令牌）
- ✅ `refresh_token`: 刷新令牌（用于续期）
- ✅ `expires_in`: 访问令牌剩余有效时间（秒）
- ✅ `refresh_token_expires_in`: 刷新令牌剩余有效时间（秒）

### 3. 智能时间计算
```ruby
# 返回实际剩余时间，而不是创建时的过期时长
access_expires_in = if auth_token.access_token_expires_at
  [(auth_token.access_token_expires_at - Time.current).to_i, 0].max
else
  auth_token.auth_data['expires_in']
end
```
- ✅ `expires_in` 现在返回**实际剩余时间**（秒）
- ✅ 过期的令牌返回 `0` 而不是负数
- ✅ 客户端可以直接判断令牌是否过期：`if (expires_in <= 0)`

### 4. 清晰的用户信息结构
- ✅ `user_info` 对象包含完整的用户身份信息
- ✅ 支持飞书的多种头像尺寸
- ✅ 包含租户信息（tenant_key）用于多租户场景

## 受影响的 API 端点

### 1. GET /api/v1/auth/token
获取授权令牌的主要端点。

**请求示例：**
```bash
curl -X GET "https://your-domain.com/api/v1/auth/token?request_id=5901d3c7-..."
```

**响应示例：** 见上方"新格式示例"

### 2. GET /api/v1/auth/status
查询授权状态（用于轮询）。

**响应字段：**
```json
{
  "request_id": "5901d3c7-e5de-4d21-b441-37bfba2fa69b",
  "state": "authorized",
  "expired": false,
  "user_access_token": "u-7tmwG4coh8...",
  "refresh_token": "r-AfswUBdVtzEcf...",
  "expires_in": 6850,
  "refresh_token_expires_in": 604750,
  "user_info": { ... }
}
```

## 向后兼容性

⚠️ **破坏性变更：** 此次优化是破坏性更新，旧版客户端需要适配新的响应格式。

### 迁移指南

**旧代码：**
```javascript
// ❌ 旧格式访问方式
const userInfo = response.auth_data.user_info;
const expiresIn = response.auth_data.expires_in;
```

**新代码：**
```javascript
// ✅ 新格式访问方式
const userInfo = response.user_info;
const expiresIn = response.expires_in;
const refreshToken = response.refresh_token;
```

## 测试覆盖

新增测试文件 `spec/requests/api/v1/auth_api_response_format_spec.rb`，覆盖：
- ✅ 标准 OAuth 响应格式验证
- ✅ 不包含旧的 `auth_data` 嵌套
- ✅ 时间计算准确性
- ✅ 边缘情况处理（缺失字段、过期令牌等）
- ✅ 端点间格式一致性

## 参考文档

- [飞书 OAuth 2.0 文档](https://open.feishu.cn/document/authentication-management)
- [OAuth 2.0 RFC 6749](https://datatracker.ietf.org/doc/html/rfc6749)
