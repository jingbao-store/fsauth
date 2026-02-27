# fsauth 文档中心

欢迎使用 fsauth 文档！这里包含了所有你需要的信息。

## 📚 文档导航

### 🚀 快速开始
- [**快速开始指南**](../QUICKSTART.md) - 30 秒快速体验 fsauth
- [**README**](../README.md) - 项目概览和特性介绍

### 📖 详细文档
- [**使用指南**](usage.md) - 完整的使用文档，包含 API 参考和集成示例
- [**架构文档**](architecture.md) - 技术架构和设计原理

### 💻 示例代码
- [**Python 客户端**](../examples/python_client.py) - Python 集成示例
- [**Node.js 客户端**](../examples/nodejs_client.js) - Node.js 集成示例
- [**示例说明**](../examples/README.md) - 示例代码使用指南

### 🛠️ 配置与部署
- [**配置示例**](../config/application.yml.example) - 飞书应用配置模板
- [**环境变量**](../.env.example) - 生产环境配置示例
- [**Docker 部署**](../docker-compose.yml) - Docker Compose 配置
- [**部署脚本**](../bin/deploy.sh) - 一键部署脚本

### 🧪 测试与调试
- [**API 测试脚本**](../bin/test_api.sh) - 快速测试 API 端点

## 📝 常用场景

### 我是新用户，想快速体验
👉 开始阅读：[快速开始指南](../QUICKSTART.md)

### 我想集成到我的应用中
👉 开始阅读：[使用指南 - API 使用示例](usage.md#方式一通过-api-集成推荐)

### 我想了解技术细节
👉 开始阅读：[架构文档](architecture.md)

### 我想部署到生产环境
👉 开始阅读：[使用指南 - 生产环境部署](usage.md#生产环境部署)

### 我遇到了问题
👉 开始阅读：[使用指南 - 故障排除](usage.md#故障排除)

## 🔍 快速查找

### API 端点

| 端点 | 方法 | 说明 | 文档 |
|------|------|------|------|
| `/api/v1/auth/request` | POST | 创建授权请求 | [详情](usage.md#post-apiv1authrequest) |
| `/api/v1/auth/token` | GET | 获取授权 token | [详情](usage.md#get-apiv1authtoken) |
| `/api/v1/auth/status` | GET | 查询授权状态 | [详情](usage.md#get-apiv1authstatus) |

### 配置项

| 配置项 | 必需 | 说明 | 文档 |
|--------|------|------|------|
| `FEISHU_APP_ID` | ✅ | 飞书应用 ID | [配置示例](../config/application.yml.example) |
| `FEISHU_APP_SECRET` | ✅ | 飞书应用密钥 | [配置示例](../config/application.yml.example) |
| `PUBLIC_HOST` | 生产 | 公网访问地址 | [环境变量](../.env.example) |
| `SECRET_KEY_BASE` | 生产 | Rails 密钥 | [环境变量](../.env.example) |

### 核心概念

| 概念 | 说明 | 文档 |
|------|------|------|
| **request_id** | 唯一标识每个授权请求的 UUID | [架构文档](architecture.md#authrequest) |
| **auth_url** | 用户完成授权的页面地址 | [使用指南](usage.md#步骤-1-创建授权请求) |
| **user_access_token** | 飞书返回的用户访问令牌 | [使用指南](usage.md#步骤-4-使用-token-调用飞书-api) |
| **轮询** | openclaw 定期查询授权状态的方式 | [使用指南](usage.md#步骤-3-轮询获取-token) |

## 🔗 外部链接

- [飞书开放平台](https://open.feishu.cn/)
- [飞书 OAuth 文档](https://open.feishu.cn/document/common-capabilities/sso/api/get-user-info)
- [Rails 官方文档](https://guides.rubyonrails.org/)

## 💡 贡献文档

发现文档错误或有改进建议？

1. Fork 本项目
2. 编辑 Markdown 文件
3. 提交 Pull Request

感谢你的贡献！

## 📧 获取帮助

- 📝 提交 Issue：[GitHub Issues](#)
- 💬 社区讨论：[Discussions](#)
- 📧 邮件联系：your-email@example.com

---

最后更新：2024-01-01
