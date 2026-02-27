const axios = require('axios');
const open = require('open');

/**
 * fsauth 客户端类
 */
class FsauthClient {
  /**
   * 初始化客户端
   * @param {string} fsauthUrl - fsauth 服务地址
   * @param {string} appId - 应用 ID
   */
  constructor(fsauthUrl, appId) {
    this.fsauthUrl = fsauthUrl.replace(/\/$/, '');
    this.appId = appId;
  }
  
  /**
   * 发起授权流程并等待用户完成授权
   * @param {number} timeout - 超时时间（毫秒），默认 5 分钟
   * @param {number} pollInterval - 轮询间隔（毫秒），默认 2 秒
   * @returns {Promise<Object>} 包含 access_token 和 user_info 的对象
   */
  async authorize(timeout = 300000, pollInterval = 2000) {
    console.log('📝 正在创建授权请求...');
    
    // 步骤 1: 创建授权请求
    const { data } = await axios.post(`${this.fsauthUrl}/api/v1/auth/request`, {
      app_id: this.appId
    });
    
    const { request_id, auth_url, expires_at } = data;
    
    console.log('✅ 授权请求已创建');
    console.log(`   Request ID: ${request_id}`);
    console.log(`   过期时间: ${expires_at}`);
    console.log('\n🌐 即将在浏览器中打开授权页面...');
    console.log(`   URL: ${auth_url}\n`);
    
    // 步骤 2: 打开浏览器
    await new Promise(resolve => setTimeout(resolve, 1000));
    await open(auth_url);
    
    console.log('⏳ 等待用户完成授权...');
    console.log('   提示：请在浏览器中完成飞书登录和授权\n');
    
    // 步骤 3: 轮询获取 token
    const startTime = Date.now();
    let pollCount = 0;
    
    while (Date.now() - startTime < timeout) {
      pollCount++;
      
      try {
        const response = await axios.get(`${this.fsauthUrl}/api/v1/auth/token`, {
          params: { request_id }
        });
        
        const result = response.data;
        const { status } = result;
        
        if (status === 'completed') {
          console.log(`✅ 授权成功！（轮询 ${pollCount} 次）\n`);
          return {
            access_token: result.token,
            user_info: result.user_info || {},
            request_id
          };
        } else if (status === 'expired') {
          throw new Error('❌ 授权请求已过期，请重新发起授权');
        } else if (status === 'failed') {
          throw new Error('❌ 授权失败，请重试');
        } else {
          // status === 'pending'
          console.log(`   轮询 ${pollCount} - 状态: ${status}（等待中...）`);
        }
      } catch (error) {
        if (error.response) {
          console.log(`   ⚠️  请求失败: ${error.message}`);
        } else {
          throw error;
        }
      }
      
      // 等待后继续轮询
      await new Promise(resolve => setTimeout(resolve, pollInterval));
    }
    
    throw new Error(`❌ 授权超时（${timeout / 1000} 秒内未完成）`);
  }
  
  /**
   * 查询授权状态（不返回 token）
   * @param {string} requestId - 授权请求 ID
   * @returns {Promise<Object>} 包含 status 和 message 的对象
   */
  async getStatus(requestId) {
    const response = await axios.get(`${this.fsauthUrl}/api/v1/auth/status`, {
      params: { request_id: requestId }
    });
    return response.data;
  }
}

/**
 * 基础使用示例
 */
async function demoBasicUsage() {
  console.log('='.repeat(60));
  console.log('fsauth 客户端示例 - 基础用法');
  console.log('='.repeat(60) + '\n');
  
  // 1. 初始化客户端
  // 注意：请替换为你的 fsauth 服务地址和应用 ID
  const client = new FsauthClient('http://localhost:3000', 'your-application-uuid');
  
  try {
    // 2. 发起授权
    const result = await client.authorize(300000, 2000);
    
    // 3. 打印结果
    console.log('📄 授权信息:');
    console.log(`   Access Token: ${result.access_token.substring(0, 20)}...`);
    console.log(`   Request ID: ${result.request_id}`);
    
    if (result.user_info && Object.keys(result.user_info).length > 0) {
      console.log('\n👤 用户信息:');
      for (const [key, value] of Object.entries(result.user_info)) {
        console.log(`   ${key}: ${value}`);
      }
    }
    
    // 4. 使用 token 调用飞书 API
    console.log('\n🔧 现在可以使用 access_token 调用飞书 API 了！');
    console.log('   示例：');
    console.log(`   curl -H 'Authorization: Bearer ${result.access_token}' \\`);
    console.log('        https://open.feishu.cn/open-apis/authen/v1/user_info');
    
    return result;
    
  } catch (error) {
    console.log(`\n${error.message}`);
    if (error.message.includes('超时')) {
      console.log('💡 提示：授权请求可能已过期，请重新运行程序');
    }
    return null;
  }
}

/**
 * 使用获取的 token 调用飞书 API 示例
 */
async function demoWithFeishuApi(accessToken) {
  console.log('\n' + '='.repeat(60));
  console.log('调用飞书 API 示例');
  console.log('='.repeat(60) + '\n');
  
  try {
    // 调用飞书用户信息接口
    console.log('📡 正在调用飞书 API 获取用户信息...');
    const response = await axios.get(
      'https://open.feishu.cn/open-apis/authen/v1/user_info',
      {
        headers: { Authorization: `Bearer ${accessToken}` }
      }
    );
    
    const userData = response.data;
    
    console.log('✅ API 调用成功！\n');
    console.log('📄 用户详细信息:');
    
    if (userData.data) {
      for (const [key, value] of Object.entries(userData.data)) {
        console.log(`   ${key}: ${value}`);
      }
    } else {
      console.log(`   ${JSON.stringify(userData, null, 2)}`);
    }
    
  } catch (error) {
    console.log(`❌ API 调用失败: ${error.message}`);
  }
}

/**
 * 状态查询示例
 */
async function demoStatusCheck() {
  console.log('\n' + '='.repeat(60));
  console.log('授权状态查询示例');
  console.log('='.repeat(60) + '\n');
  
  const readline = require('readline');
  const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout
  });
  
  return new Promise((resolve) => {
    rl.question('请输入 request_id（按 Enter 跳过）: ', async (requestId) => {
      rl.close();
      
      if (!requestId.trim()) {
        console.log('⏭️  跳过状态查询');
        resolve();
        return;
      }
      
      const client = new FsauthClient('http://localhost:3000');
      
      try {
        const statusResult = await client.getStatus(requestId.trim());
        console.log(`\n📊 授权状态: ${statusResult.status}`);
        console.log(`   消息: ${statusResult.message || 'N/A'}`);
      } catch (error) {
        console.log(`❌ 查询失败: ${error.message}`);
      }
      
      resolve();
    });
  });
}

/**
 * 主函数
 */
async function main() {
  // 运行基础示例
  const result = await demoBasicUsage();
  
  // 如果授权成功，可以演示调用飞书 API
  if (result && result.access_token) {
    const readline = require('readline');
    const rl = readline.createInterface({
      input: process.stdin,
      output: process.stdout
    });
    
    await new Promise((resolve) => {
      rl.question('\n是否演示调用飞书 API？(y/n): ', async (answer) => {
        if (answer.trim().toLowerCase() === 'y') {
          await demoWithFeishuApi(result.access_token);
        }
        resolve();
      });
    });
    
    await new Promise((resolve) => {
      rl.question('\n是否演示状态查询？(y/n): ', async (answer) => {
        rl.close();
        if (answer.trim().toLowerCase() === 'y') {
          await demoStatusCheck();
        }
        resolve();
      });
    });
  }
  
  console.log('\n' + '='.repeat(60));
  console.log('示例结束，感谢使用 fsauth！');
  console.log('='.repeat(60));
}

// 导出类和函数
module.exports = {
  FsauthClient,
  demoBasicUsage,
  demoWithFeishuApi,
  demoStatusCheck
};

// 如果直接运行此文件
if (require.main === module) {
  main().catch(error => {
    console.error('程序执行出错:', error);
    process.exit(1);
  });
}
