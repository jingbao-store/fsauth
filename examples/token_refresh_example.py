#!/usr/bin/env python3
"""
fsauth Token Refresh Example

This example demonstrates how to:
1. Authorize and get initial access_token
2. Use the access_token to call Feishu API
3. Refresh the access_token when it expires
"""

import requests
import time
import webbrowser
from datetime import datetime, timedelta


class FsauthClient:
    def __init__(self, fsauth_url, app_id):
        self.fsauth_url = fsauth_url.rstrip('/')
        self.app_id = app_id
        self.request_id = None
        self.access_token = None
        self.token_expires_at = None

    def authorize(self, timeout=300, poll_interval=2):
        """
        发起授权流程并等待用户完成授权

        Args:
            timeout: 超时时间（秒），默认 5 分钟
            poll_interval: 轮询间隔（秒），默认 2 秒

        Returns:
            dict: 包含 token 和用户信息的字典
        """
        print("\n=== Step 1: Creating authorization request ===")
        # 1. 创建授权请求
        response = requests.post(
            f"{self.fsauth_url}/api/v1/auth/request",
            json={"app_id": self.app_id}
        )
        response.raise_for_status()
        data = response.json()

        self.request_id = data['request_id']
        auth_url = data['auth_url']

        print(f"Request ID: {self.request_id}")
        print(f"Authorization URL: {auth_url}")
        print("\n=== Step 2: Opening browser for user authorization ===")

        # 2. 打开浏览器
        webbrowser.open(auth_url)

        # 3. 轮询获取 token
        print("\n=== Step 3: Polling for authorization completion ===")
        start_time = time.time()
        while time.time() - start_time < timeout:
            response = requests.get(
                f"{self.fsauth_url}/api/v1/auth/token",
                params={"request_id": self.request_id}
            )
            response.raise_for_status()
            result = response.json()

            if result['state'] == 'authorized':
                print("✓ Authorization successful!")
                self.access_token = result['user_access_token']
                # Assume token expires in 2 hours (7200 seconds)
                self.token_expires_at = datetime.now() + timedelta(hours=2)
                return {
                    'access_token': self.access_token,
                    'auth_data': result.get('auth_data', {})
                }
            elif result['state'] == 'expired':
                raise Exception("授权请求已过期")
            elif result['state'] == 'failed':
                raise Exception("授权失败")

            print(f"  Waiting for authorization... ({int(time.time() - start_time)}s)")
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

        print("\n=== Refreshing access token ===")
        response = requests.post(
            f"{self.fsauth_url}/api/v1/auth/refresh",
            json={
                "app_id": self.app_id,
                "request_id": self.request_id
            }
        )
        response.raise_for_status()
        data = response.json()

        self.access_token = data['user_access_token']
        expires_in = data.get('expires_in', 7200)
        self.token_expires_at = datetime.now() + timedelta(seconds=expires_in)

        print(f"✓ Token refreshed successfully")
        print(f"  New access_token: {self.access_token[:20]}...")
        print(f"  Expires at: {self.token_expires_at}")

        return {
            'access_token': self.access_token,
            'expires_in': expires_in,
            'refresh_token_expires_in': data.get('refresh_token_expires_in')
        }

    def is_token_expired(self):
        """Check if current token is expired"""
        if not self.token_expires_at:
            return True
        # Refresh 5 minutes before actual expiration
        return datetime.now() >= (self.token_expires_at - timedelta(minutes=5))

    def get_user_info(self):
        """
        Get user info from Feishu API

        Returns:
            dict: User information
        """
        if self.is_token_expired():
            print("Token expired, refreshing...")
            self.refresh_token()

        response = requests.get(
            "https://open.feishu.cn/open-apis/authen/v1/user_info",
            headers={"Authorization": f"Bearer {self.access_token}"}
        )
        response.raise_for_status()
        data = response.json()

        if data.get('code') == 0:
            return data.get('data')
        else:
            raise Exception(f"Feishu API error: {data.get('msg')}")


def main():
    """
    Main example demonstrating token refresh workflow
    """
    # Configuration
    FSAUTH_URL = "http://localhost:3000"  # Replace with your fsauth URL
    APP_ID = "your-application-uuid"       # Replace with your application ID

    print("=" * 60)
    print("fsauth Token Refresh Example")
    print("=" * 60)

    client = FsauthClient(FSAUTH_URL, APP_ID)

    try:
        # === Initial Authorization ===
        result = client.authorize()
        print(f"\n✓ Initial access token: {client.access_token[:20]}...")
        print(f"✓ Token expires at: {client.token_expires_at}")

        # === Use Token to Call Feishu API ===
        print("\n=== Step 4: Using token to call Feishu API ===")
        user_info = client.get_user_info()
        print(f"✓ User info retrieved:")
        print(f"  Name: {user_info.get('name')}")
        print(f"  Open ID: {user_info.get('open_id')}")

        # === Simulate Token Expiration ===
        print("\n=== Simulating token expiration ===")
        client.token_expires_at = datetime.now() - timedelta(minutes=1)
        print("Token marked as expired")

        # === Auto-Refresh When Calling API ===
        print("\n=== Step 5: Auto-refreshing token when calling API ===")
        user_info = client.get_user_info()
        print(f"✓ User info retrieved with refreshed token")

        # === Manual Token Refresh ===
        print("\n=== Step 6: Manual token refresh ===")
        refreshed = client.refresh_token()
        print(f"✓ New token expires in: {refreshed['expires_in']} seconds")
        print(f"✓ Refresh token expires in: {refreshed['refresh_token_expires_in']} seconds")

        print("\n" + "=" * 60)
        print("Example completed successfully!")
        print("=" * 60)

    except Exception as e:
        print(f"\n✗ Error: {e}")
        import traceback
        traceback.print_exc()


if __name__ == "__main__":
    main()
