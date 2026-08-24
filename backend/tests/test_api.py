import importlib
import sys
from pathlib import Path
from unittest.mock import AsyncMock

import pytest
from fastapi.testclient import TestClient

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))


def make_client(tmp_path, monkeypatch):
    monkeypatch.setenv("SHUNSHI_ENV", "test")
    monkeypatch.setenv("SHUNSHI_DATABASE_PATH", str(tmp_path / "test.db"))
    monkeypatch.setenv("SHUNSHI_JWT_SECRET", "test-secret-that-is-longer-than-32-characters")
    import app.main
    api = importlib.reload(app.main)
    api.init_db()
    return TestClient(api.app)


def test_guest_auth_and_protected_flows(tmp_path, monkeypatch):
    client = make_client(tmp_path, monkeypatch)
    login = client.post("/api/v1/auth/guest-login")
    assert login.status_code == 200
    headers = {"Authorization": f"Bearer {login.json()['access_token']}"}
    assert client.get("/healthz").json()["status"] == "ok"
    chat = client.post("/api/v1/chat/send", headers=headers, json={"message": "我昨晚没睡好"})
    assert chat.status_code == 200 and chat.json()["content"]
    assert chat.json()["ai_metadata"]["provider"] == "development_fallback"
    assert client.get("/api/v1/conversations", headers=headers).json()["items"]
    assert client.post("/api/v1/reflections", headers=headers, json={"content": "今天散步二十分钟"}).status_code == 200


def test_sms_code_is_one_time(tmp_path, monkeypatch):
    client = make_client(tmp_path, monkeypatch)
    sent = client.post("/api/v1/auth/sms/send", json={"phone": "13800138000"}).json()
    body = {"phone": "13800138000", "code": sent["test_code"]}
    assert client.post("/api/v1/auth/sms/verify", json=body).status_code == 200
    assert client.post("/api/v1/auth/sms/verify", json=body).status_code == 400


def test_protected_endpoint_rejects_anonymous(tmp_path, monkeypatch):
    client = make_client(tmp_path, monkeypatch)
    assert client.get("/api/v1/conversations").status_code == 401


def test_openrouter_health_data_requires_explicit_cross_border_authorization(tmp_path, monkeypatch):
    monkeypatch.setenv("SHUNSHI_ENV", "production")
    monkeypatch.setenv("SHUNSHI_DATABASE_PATH", str(tmp_path / "production.db"))
    monkeypatch.setenv("SHUNSHI_JWT_SECRET", "test-secret-that-is-longer-than-32-characters")
    monkeypatch.setenv("SHUNSHI_CORS_ORIGINS", "https://shunshi.test")
    monkeypatch.setenv("OPENROUTER_API_KEY", "test-key")
    monkeypatch.setenv("SHUNSHI_LLM_ALLOW_CROSS_BORDER", "false")
    import app.main
    api = importlib.reload(app.main)
    api.init_db()
    client = TestClient(api.app)
    login = client.post("/api/v1/auth/guest-login")
    headers = {"Authorization": f"Bearer {login.json()['access_token']}"}
    response = client.post("/api/v1/chat/send", headers=headers, json={"message": "我最近失眠"})
    assert response.status_code == 503
    assert "跨境模型" in response.json()["detail"]


@pytest.mark.asyncio
async def test_openrouter_circuit_stops_requests_after_threshold(tmp_path, monkeypatch):
    monkeypatch.setenv("SHUNSHI_ENV", "test")
    monkeypatch.setenv("SHUNSHI_DATABASE_PATH", str(tmp_path / "test.db"))
    monkeypatch.setenv("SHUNSHI_JWT_SECRET", "test-secret-that-is-longer-than-32-characters")
    monkeypatch.setenv("OPENROUTER_API_KEY", "test-key")
    monkeypatch.setenv("SHUNSHI_LLM_ALLOW_CROSS_BORDER", "true")
    monkeypatch.setenv("OPENROUTER_CIRCUIT_FAILURES", "2")
    import app.main
    api = importlib.reload(app.main)

    post = AsyncMock(side_effect=RuntimeError("provider unavailable"))
    class FakeClient:
        def __init__(self, **_kwargs): pass
        async def __aenter__(self): return self
        async def __aexit__(self, *_args): return None
        async def post(self, *args, **kwargs): return await post(*args, **kwargs)
    monkeypatch.setattr(api.httpx, "AsyncClient", FakeClient)

    with pytest.raises(RuntimeError, match="provider unavailable"):
        await api.llm_answer("问题1")
    with pytest.raises(RuntimeError, match="provider unavailable"):
        await api.llm_answer("问题2")
    with pytest.raises(api.HTTPException, match="熔断"):
        await api.llm_answer("问题3")
    assert post.await_count == 2


def test_daily_ai_quota_is_enforced(tmp_path, monkeypatch):
    monkeypatch.setenv("SHUNSHI_AI_DAILY_LIMIT_FREE", "1")
    client = make_client(tmp_path, monkeypatch)
    login = client.post("/api/v1/auth/guest-login")
    headers = {"Authorization": f"Bearer {login.json()['access_token']}"}
    assert client.post("/api/v1/chat/send", headers=headers, json={"message": "第一次"}).status_code == 200
    response = client.post("/api/v1/chat/send", headers=headers, json={"message": "第二次"})
    assert response.status_code == 429
    assert "额度已用完" in response.json()["detail"]
    usage = client.get("/api/v1/ai/usage", headers=headers).json()
    assert usage["used"] == 1 and usage["remaining"] == 0
    assert usage["warning_level"] == "blocked"


def test_iap_receipt_must_be_server_verified_before_entitlement(tmp_path, monkeypatch):
    monkeypatch.setenv("SHUNSHI_IAP_VERIFY_URL", "https://verify.example/iap")
    monkeypatch.setenv("SHUNSHI_IAP_VERIFY_TOKEN", "verify-token")
    client = make_client(tmp_path, monkeypatch)
    import app.main as api

    class VerifiedResponse:
        def raise_for_status(self): return None
        def json(self):
            return {"valid": True, "product_id": "shunshi_yangxin_monthly", "expires_at": int(api.time.time()) + 86400, "original_transaction_id": "transaction-123"}
    class FakeClient:
        def __init__(self, **_kwargs): pass
        async def __aenter__(self): return self
        async def __aexit__(self, *_args): return None
        async def post(self, *_args, **_kwargs): return VerifiedResponse()
    monkeypatch.setattr(api.httpx, "AsyncClient", FakeClient)
    login = client.post("/api/v1/auth/guest-login")
    headers = {"Authorization": f"Bearer {login.json()['access_token']}"}
    response = client.post("/api/v1/billing/iap/verify", headers=headers, json={
        "product_id": "shunshi_yangxin_monthly", "receipt": "receipt-data-long-enough", "store": "app_store",
    })
    assert response.status_code == 200
    assert response.json()["active"] is True
