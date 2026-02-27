#!/usr/bin/env python3
"""
fsauth 客户端示例

演示如何在 Python 应用中集成 fsauth 进行飞书授权。
"""

import requests
import time
import webbrowser
from typing import Dict, Optional


class FsauthClient:
    def __init__(self, fsauth_url: str, app_id: str):
        """
        初始化客户端
        
        Args:
            fsauth_url: fsauth 服务地址（例如：https://fsauth.example.com）
            app_id: 应用 ID
        """
        self.fsauth_url = fsauth_url.rstrip('/')
        self.app_id = app_id
    
    def authorize(self, timeout: int = 300, poll_interval: int = 2) -> Dict:
        """
        发起授权流程并等待用户完成授权
        
        Args:
            timeout: 超时时间（秒），默认 5 分钟
            poll_interval: 轮询间隔（秒），默认 2 秒
            
        Returns:
            包含 access_token 和 user_info 的字典
            
        Raises:
            TimeoutError: 授权超时
            Exception: 授权失败或过期
        """
        # 步骤 1: 创建授权请求
        print("📝 正在创建授权请求...")
        response = requests.post(
            f"{self.fsauth_url}/api/v1/auth/request",
            json={"app_id": self.app_id},
            timeout=10
        )
        response.raise_for_status()
        data = response.json()
        
        request_id = data['request_id']
        auth_url = data['auth_url']
        expires_at = data['expires_at']
        
        print(f"✅ 授权请求已创建")
        print(f"   Request ID: {request_id}")
        print(f"   过期时间: {expires_at}")
        print(f"\n🌐 即将在浏览器中打开授权页面...")
        print(f"   URL: {auth_url}\n")
        
        # 步骤 2: 打开浏览器
        time.sleep(1)  # 给用户一点时间看消息
        webbrowser.open(auth_url)
        
        print("⏳ 等待用户完成授权...")
        print("   提示：请在浏览器中完成飞书登录和授权\n")
        
        # 步骤 3: 轮询获取 token
        start_time = time.time()
        poll_count = 0
        
        while time.time() - start_time < timeout:
            poll_count += 1
            
            try:
                response = requests.get(
                    f"{self.fsauth_url}/api/v1/auth/token",
                    params={"request_id": request_id},
                    timeout=10
                )
                response.raise_for_status()
                result = response.json()
                
                status = result['status']
                
                if status == 'completed':
                    print(f"✅ 授权成功！（轮询 {poll_count} 次）\n")
                    return {
                        'access_token': result['token'],
                        'user_info': result.get('user_info', {}),
                        'request_id': request_id
                    }
                elif status == 'expired':
                    raise Exception("❌ 授权请求已过期，请重新发起授权")
                elif status == 'failed':
                    raise Exception("❌ 授权失败，请重试")
                else:
                    # status == 'pending'
                    print(f"   轮询 {poll_count} - 状态: {status}（等待中...）")
                
            except requests.RequestException as e:
                print(f"   ⚠️  网络请求失败: {e}")
            
            # 等待后继续轮询
            time.sleep(poll_interval)
        
        raise TimeoutError(f"❌ 授权超时（{timeout} 秒内未完成）")
    
    def get_status(self, request_id: str) -> Dict:
        """
        查询授权状态（不返回 token）
        
        Args:
            request_id: 授权请求 ID
            
        Returns:
            包含 status 和 message 的字典
        """
        response = requests.get(
            f"{self.fsauth_url}/api/v1/auth/status",
            params={"request_id": request_id},
            timeout=10
        )
        response.raise_for_status()
        return response.json()


def demo_basic_usage():
    """基础使用示例"""
    print("=" * 60)
    print("fsauth 客户端示例 - 基础用法")
    print("=" * 60 + "\n")
    
    # 1. 初始化客户端
    # 注意：请替换为你的 fsauth 服务地址和应用 ID
    client = FsauthClient("http://localhost:3000", "your-application-uuid")
    
    try:
        # 2. 发起授权
        result = client.authorize(timeout=300, poll_interval=2)
        
        # 3. 打印结果
        print("📄 授权信息:")
        print(f"   Access Token: {result['access_token'][:20]}...")
        print(f"   Request ID: {result['request_id']}")
        
        if result.get('user_info'):
            print(f"\n👤 用户信息:")
            for key, value in result['user_info'].items():
                print(f"   {key}: {value}")
        
        # 4. 使用 token 调用飞书 API
        print(f"\n🔧 现在可以使用 access_token 调用飞书 API 了！")
        print(f"   示例：")
        print(f"   curl -H 'Authorization: Bearer {result['access_token']}' \\")
        print(f"        https://open.feishu.cn/open-apis/authen/v1/user_info")
        
        return result
        
    except TimeoutError as e:
        print(f"\n{e}")
        print("💡 提示：授权请求可能已过期，请重新运行程序")
        return None
    
    except Exception as e:
        print(f"\n❌ 授权失败: {e}")
        return None


def demo_with_feishu_api(access_token: str):
    """使用获取的 token 调用飞书 API 示例"""
    print("\n" + "=" * 60)
    print("调用飞书 API 示例")
    print("=" * 60 + "\n")
    
    try:
        # 调用飞书用户信息接口
        print("📡 正在调用飞书 API 获取用户信息...")
        response = requests.get(
            "https://open.feishu.cn/open-apis/authen/v1/user_info",
            headers={"Authorization": f"Bearer {access_token}"},
            timeout=10
        )
        response.raise_for_status()
        user_data = response.json()
        
        print("✅ API 调用成功！\n")
        print("📄 用户详细信息:")
        
        if user_data.get('data'):
            for key, value in user_data['data'].items():
                print(f"   {key}: {value}")
        else:
            print(f"   {user_data}")
        
    except requests.RequestException as e:
        print(f"❌ API 调用失败: {e}")


def demo_status_check():
    """状态查询示例"""
    print("\n" + "=" * 60)
    print("授权状态查询示例")
    print("=" * 60 + "\n")
    
    client = FsauthClient("http://localhost:3000")
    
    # 假设你已经有一个 request_id
    request_id = input("请输入 request_id（按 Enter 跳过）: ").strip()
    
    if not request_id:
        print("⏭️  跳过状态查询")
        return
    
    try:
        status_result = client.get_status(request_id)
        print(f"\n📊 授权状态: {status_result['status']}")
        print(f"   消息: {status_result.get('message', 'N/A')}")
    except Exception as e:
        print(f"❌ 查询失败: {e}")


if __name__ == "__main__":
    # 运行基础示例
    result = demo_basic_usage()
    
    # 如果授权成功，演示调用飞书 API
    if result and result.get('access_token'):
        use_api = input("\n是否演示调用飞书 API？(y/n): ").strip().lower()
        if use_api == 'y':
            demo_with_feishu_api(result['access_token'])
    
    # 状态查询示例
    check_status = input("\n是否演示状态查询？(y/n): ").strip().lower()
    if check_status == 'y':
        demo_status_check()
    
    print("\n" + "=" * 60)
    print("示例结束，感谢使用 fsauth！")
    print("=" * 60)
