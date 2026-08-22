import importlib
import sys
from pathlib import Path

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
