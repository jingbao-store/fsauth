# SKILL.md 更新说明

## 更新日期
2026-03-01

## 更新内容

在 `app/views/applications/skill.md.erb` 中新增了完整的 **Token 刷新机制** 文档。

### 新增章节

#### 1. Token 刷新机制概述
- 解释为什么需要刷新 Token
- 说明 Token 的生命周期：
  - `access_token`: 2 小时有效期
  - `refresh_token`: 30 天有效期
  - `offline_access` 权限必需

#### 2. 刷新 API 使用方法

**端点**: `POST /api/v1/auth/refresh`

**请求参数**:
```json
{
  "app_id": "application-uuid",
  "request_id": "req_xxx"
}
```

**成功响应**:
```json
{
  "user_access_token": "u-NEW_TOKEN_HERE",
  "expires_in": 7200,
  "refresh_token_expires_in": 2592000,
  "message": "Token refreshed successfully"
}
```

**错误响应**:
- `401 Unauthorized`: refresh_token 已过期，需要重新授权
- `422 Unprocessable Entity`: 飞书 API 调用失败

#### 3. 最佳实践

**方案 1: 主动刷新（推荐）**
- 提供了完整的 Bash 脚本示例
- 每隔 1.5 小时自动刷新一次
- 避免 token 过期导致的 API 调用失败

**方案 2: 错误重试**
- 提供了完整的 Python 客户端实现
- 自动检测 token 是否即将过期
- 当 API 调用返回 401 时自动刷新并重试

#### 4. Token 生命周期管理流程图

使用 Mermaid 图表展示完整的 Token 刷新流程：
- 初次授权 → 获取 access_token + refresh_token
- 使用 token 调用 API
- Token 即将过期 → 调用刷新接口
- 如果 refresh_token 有效 → 获取新 token
- 如果 refresh_token 过期 → 重新授权

#### 5. 错误码对照表

| 状态码 | 错误 | 说明 | 解决方案 |
|--------|------|------|----------|
| 400 | app_id and request_id are required | 缺少必需参数 | 检查请求参数 |
| 401 | Refresh token expired or unavailable | refresh_token 已过期 | 重新发起授权 |
| 404 | Token not found for this request | 找不到 token 记录 | 检查 request_id |
| 422 | Token refresh failed | 飞书 API 失败 | 查看详细错误 |

#### 6. 注意事项

1. **保存 request_id**: 初次授权返回的 request_id 必须保存
2. **refresh_token 只能用一次**: 每次刷新后会获得新的 refresh_token
3. **并发刷新**: 避免多进程同时刷新同一个 token
4. **提前刷新**: 建议在 token 过期前 5-10 分钟刷新
5. **错误重试**: 如果返回 401，说明 refresh_token 已过期

### API 端点列表更新

在 "API 端点" 章节新增：
```
- **刷新 Token**: `POST /api/v1/auth/refresh` (需要 app_id 和 request_id)
```

### 代码示例

#### Bash 主动刷新脚本
提供了完整的自动化刷新脚本，每 1.5 小时自动刷新一次 token。

#### Python 客户端类
提供了完整的 `FeishuClient` 类实现：
- `refresh_token()`: 刷新 access_token
- `is_token_expired()`: 检查 token 是否即将过期
- `call_feishu_api()`: 自动处理 token 刷新的 API 调用方法

## 相关实现

### 后端实现
- `app/controllers/api/v1/auth_apis_controller.rb#refresh_token`: 刷新 token 的控制器方法
- `app/services/feishu_auth_service.rb#refresh_user_access_token`: 调用飞书 API 刷新 token
- `app/models/auth_token.rb#can_refresh?`: 检查 token 是否可以刷新

### 测试覆盖
- `spec/requests/auth_token_refresh_spec.rb`: 完整的刷新功能测试
- `spec/services/feishu_auth_service_spec.rb`: 包含 scope 参数测试

### 示例代码
- `examples/token_refresh_example.py`: Python 客户端完整示例

## 验证方式

访问任意应用的 SKILL.md 页面：
```
http://localhost:3000/applications/{application_id}/SKILL.md
```

或使用 curl：
```bash
curl http://localhost:3000/applications/{application_id}/SKILL.md
```

## 文档结构

更新后的 SKILL.md 包含以下主要章节：
1. 获取飞书用户 Access Token（步骤 1-3）
2. 应用信息
3. API 端点（新增刷新端点）
4. 故障排除
5. 使用 Token 调用飞书 API
6. **Token 刷新机制**（新增）
   - 为什么需要刷新
   - Token 生命周期
   - 刷新 API 使用
   - 最佳实践（Bash + Python）
   - 生命周期管理流程图
   - 错误码对照表
   - 注意事项

## 影响范围

- ✅ 所有使用 fsauth 的客户端都可以通过 SKILL.md 了解如何使用刷新功能
- ✅ OpenClaw AI 可以自动学习并使用 token 刷新机制
- ✅ 提供了完整的代码示例，方便快速集成
- ✅ 详细的错误码说明，便于排查问题

## 测试结果

- ✅ 所有测试通过（66 examples, 0 failures）
- ✅ SKILL.md 正确渲染
- ✅ 包含所有新增内容
