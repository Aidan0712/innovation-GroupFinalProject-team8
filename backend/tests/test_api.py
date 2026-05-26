"""
API 接口测试
使用 httpx 进行 HTTP 接口测试
"""

import pytest
from httpx import ASGITransport, AsyncClient

from app.main import app


@pytest.fixture
async def client():
    """创建异步测试客户端"""
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        yield ac


@pytest.mark.asyncio
async def test_health_check(client: AsyncClient):
    """测试健康检查端点"""
    response = await client.get("/health")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "ok"
    assert "version" in data


@pytest.mark.asyncio
async def test_register_user(client: AsyncClient):
    """测试用户注册"""
    payload = {
        "username": "testuser123",
        "password": "testpass123",
        "email": "test@example.com",
    }
    response = await client.post("/api/auth/register", json=payload)
    assert response.status_code == 200
    data = response.json()
    assert data["code"] == 200
    assert data["data"]["username"] == "testuser123"


@pytest.mark.asyncio
async def test_login(client: AsyncClient):
    """测试用户登录"""
    # 先注册
    await client.post("/api/auth/register", json={
        "username": "logintest",
        "password": "testpass123",
    })

    # 登录
    response = await client.post("/api/auth/login", json={
        "username": "logintest",
        "password": "testpass123",
    })
    assert response.status_code == 200
    data = response.json()
    assert "access_token" in data["data"]
    assert "refresh_token" in data["data"]


@pytest.mark.asyncio
async def test_login_wrong_password(client: AsyncClient):
    """测试错误密码登录"""
    response = await client.post("/api/auth/login", json={
        "username": "nonexistent",
        "password": "wrong",
    })
    assert response.status_code == 401
