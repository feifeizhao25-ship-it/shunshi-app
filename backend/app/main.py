from __future__ import annotations

import base64
import hashlib
import hmac
import json
import os
import secrets
import sqlite3
import time
import uuid
from contextlib import contextmanager
from pathlib import Path
from typing import Any, Optional

import httpx
from fastapi import Depends, FastAPI, Header, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field


ENV = os.getenv("SHUNSHI_ENV", "development")
DB_PATH = Path(os.getenv("SHUNSHI_DATABASE_PATH", "/data/shunshi.db" if ENV == "production" else "./shunshi.db"))
JWT_SECRET = os.getenv("SHUNSHI_JWT_SECRET", "")
CORS = [item.strip() for item in os.getenv("SHUNSHI_CORS_ORIGINS", "").split(",") if item.strip()]
LLM_BASE = os.getenv("SHUNSHI_OPENAI_BASE_URL", "").rstrip("/")
LLM_KEY = os.getenv("SHUNSHI_OPENAI_API_KEY", "")
LLM_MODEL = os.getenv("SHUNSHI_OPENAI_MODEL", "qwen-plus")
SMS_URL = os.getenv("SHUNSHI_SMS_PROVIDER_URL", "")
SMS_TOKEN = os.getenv("SHUNSHI_SMS_PROVIDER_TOKEN", "")

if ENV == "production" and (len(JWT_SECRET) < 32 or not CORS):
    raise RuntimeError("生产环境必须配置至少 32 位 JWT 密钥和明确的 CORS 来源")
if not JWT_SECRET:
    JWT_SECRET = secrets.token_urlsafe(32)

app = FastAPI(title="顺时 API", version="1.0.0", docs_url=None if ENV == "production" else "/docs")
app.add_middleware(CORSMiddleware, allow_origins=CORS or ["http://localhost:3000"], allow_methods=["GET", "POST", "PUT", "PATCH", "DELETE"], allow_headers=["Authorization", "Content-Type", "X-Request-ID"])


@contextmanager
def db():
    DB_PATH.parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    try:
        yield conn
        conn.commit()
    finally:
        conn.close()


def init_db() -> None:
    with db() as conn:
        conn.executescript("""
        CREATE TABLE IF NOT EXISTS users(id TEXT PRIMARY KEY, phone TEXT UNIQUE, password_hash TEXT, nickname TEXT NOT NULL, is_guest INTEGER NOT NULL DEFAULT 0, created_at INTEGER NOT NULL);
        CREATE TABLE IF NOT EXISTS sms_codes(phone TEXT PRIMARY KEY, code_hash TEXT NOT NULL, expires_at INTEGER NOT NULL, attempts INTEGER NOT NULL DEFAULT 0);
        CREATE TABLE IF NOT EXISTS messages(id TEXT PRIMARY KEY, user_id TEXT NOT NULL, role TEXT NOT NULL, content TEXT NOT NULL, created_at INTEGER NOT NULL);
        CREATE TABLE IF NOT EXISTS settings(user_id TEXT NOT NULL, kind TEXT NOT NULL, value TEXT NOT NULL, PRIMARY KEY(user_id, kind));
        CREATE TABLE IF NOT EXISTS reflections(id TEXT PRIMARY KEY, user_id TEXT NOT NULL, content TEXT NOT NULL, created_at INTEGER NOT NULL);
        CREATE TABLE IF NOT EXISTS feedback(id TEXT PRIMARY KEY, user_id TEXT NOT NULL, payload TEXT NOT NULL, created_at INTEGER NOT NULL);
        CREATE TABLE IF NOT EXISTS entitlements(user_id TEXT PRIMARY KEY, product_id TEXT NOT NULL, store TEXT NOT NULL, expires_at INTEGER NOT NULL, original_transaction_id TEXT UNIQUE NOT NULL, updated_at INTEGER NOT NULL);
        """)


@app.on_event("startup")
def startup() -> None:
    init_db()


def b64(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode()


def token_for(user_id: str) -> str:
    payload = b64(json.dumps({"sub": user_id, "exp": int(time.time()) + 604800}, separators=(",", ":")).encode())
    signature = b64(hmac.new(JWT_SECRET.encode(), payload.encode(), hashlib.sha256).digest())
    return f"{payload}.{signature}"


def current_user(authorization: Optional[str] = Header(default=None)) -> str:
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(401, "请先登录")
    try:
        payload, signature = authorization[7:].split(".", 1)
        expected = b64(hmac.new(JWT_SECRET.encode(), payload.encode(), hashlib.sha256).digest())
        if not hmac.compare_digest(signature, expected):
            raise ValueError
        data = json.loads(base64.urlsafe_b64decode(payload + "=" * (-len(payload) % 4)))
        if int(data["exp"]) < time.time():
            raise ValueError
        return str(data["sub"])
    except (ValueError, KeyError, json.JSONDecodeError):
        raise HTTPException(401, "登录状态已失效") from None


class Phone(BaseModel):
    phone: str = Field(pattern=r"^1\d{10}$")


class SmsVerify(Phone):
    code: str = Field(min_length=4, max_length=8)


class Login(Phone):
    password: str = Field(min_length=8, max_length=128)


class Chat(BaseModel):
    message: Optional[str] = Field(default=None, min_length=1, max_length=4000)
    user_input: Optional[str] = Field(default=None, min_length=1, max_length=4000)
    user_id: Optional[str] = None

    def text(self) -> str:
        value = self.message or self.user_input
        if not value:
            raise HTTPException(422, "消息内容不能为空")
        return value


def auth_response(user_id: str) -> dict[str, Any]:
    return {"access_token": token_for(user_id), "token_type": "bearer", "expires_in": 604800}


@app.get("/healthz")
def healthz():
    with db() as conn:
        conn.execute("SELECT 1")
    return {"status": "ok", "service": "shunshi-api"}


@app.post("/api/v1/auth/guest-login")
def guest_login():
    user_id = str(uuid.uuid4())
    with db() as conn:
        conn.execute("INSERT INTO users VALUES(?,?,?,?,?,?)", (user_id, None, None, "顺时用户", 1, int(time.time())))
    return auth_response(user_id)


@app.post("/api/v1/auth/sms/send")
async def sms_send(body: Phone):
    code = f"{secrets.randbelow(1000000):06d}"
    if not SMS_URL or not SMS_TOKEN:
        if ENV == "production":
            raise HTTPException(503, "短信服务尚未配置")
    else:
        async with httpx.AsyncClient(timeout=10) as client:
            response = await client.post(SMS_URL, json={"phone": body.phone, "code": code}, headers={"Authorization": f"Bearer {SMS_TOKEN}"})
            response.raise_for_status()
    digest = hmac.new(JWT_SECRET.encode(), f"{body.phone}:{code}".encode(), hashlib.sha256).hexdigest()
    with db() as conn:
        conn.execute("INSERT OR REPLACE INTO sms_codes VALUES(?,?,?,0)", (body.phone, digest, int(time.time()) + 300))
    result: dict[str, Any] = {"sent": True, "expires_in": 300}
    if ENV == "test":
        result["test_code"] = code
    return result


@app.post("/api/v1/auth/sms/verify")
def sms_verify(body: SmsVerify):
    digest = hmac.new(JWT_SECRET.encode(), f"{body.phone}:{body.code}".encode(), hashlib.sha256).hexdigest()
    with db() as conn:
        row = conn.execute("SELECT * FROM sms_codes WHERE phone=?", (body.phone,)).fetchone()
        if not row or row["expires_at"] < time.time() or row["attempts"] >= 5 or not hmac.compare_digest(row["code_hash"], digest):
            if row:
                conn.execute("UPDATE sms_codes SET attempts=attempts+1 WHERE phone=?", (body.phone,))
            raise HTTPException(400, "验证码错误或已过期")
        user = conn.execute("SELECT id FROM users WHERE phone=?", (body.phone,)).fetchone()
        user_id = user["id"] if user else str(uuid.uuid4())
        if not user:
            conn.execute("INSERT INTO users VALUES(?,?,?,?,?,?)", (user_id, body.phone, None, "顺时用户", 0, int(time.time())))
        conn.execute("DELETE FROM sms_codes WHERE phone=?", (body.phone,))
    return auth_response(user_id)


@app.post("/api/v1/auth/login")
def password_login(body: Login):
    with db() as conn:
        row = conn.execute("SELECT id,password_hash FROM users WHERE phone=?", (body.phone,)).fetchone()
    if not row or not row["password_hash"]:
        raise HTTPException(401, "手机号或密码错误")
    supplied = hashlib.scrypt(body.password.encode(), salt=body.phone.encode(), n=16384, r=8, p=1).hex()
    if not hmac.compare_digest(row["password_hash"], supplied):
        raise HTTPException(401, "手机号或密码错误")
    return auth_response(row["id"])


async def llm_answer(message: str) -> str:
    if not LLM_BASE or not LLM_KEY:
        if ENV == "production":
            raise HTTPException(503, "智能服务暂不可用")
        return "我已收到你的记录。你可以先从一件今天能完成的小事开始；如有持续不适，请及时咨询专业医生。"
    prompt = "你是顺时健康陪伴助手。只用简明中文，不诊断、不替代医生；涉及危险症状应建议立即就医。回答要可执行、易懂。"
    async with httpx.AsyncClient(timeout=60) as client:
        response = await client.post(f"{LLM_BASE}/chat/completions", headers={"Authorization": f"Bearer {LLM_KEY}"}, json={"model": LLM_MODEL, "messages": [{"role": "system", "content": prompt}, {"role": "user", "content": message}], "temperature": 0.3})
        response.raise_for_status()
        return response.json()["choices"][0]["message"]["content"]


@app.post("/api/v1/chat/send")
@app.post("/api/v1/ai/chat")
async def chat(body: Chat, user_id: str = Depends(current_user)):
    message = body.text()
    answer = await llm_answer(message)
    now = int(time.time())
    with db() as conn:
        conn.execute("INSERT INTO messages VALUES(?,?,?,?,?)", (str(uuid.uuid4()), user_id, "user", message, now))
        conn.execute("INSERT INTO messages VALUES(?,?,?,?,?)", (str(uuid.uuid4()), user_id, "assistant", answer, now))
    return {"content": answer, "message": answer, "text": answer, "tone": "gentle", "care_status": "stable", "safety_flag": "none"}


@app.get("/api/v1/seasons/home/dashboard")
def dashboard(user_id: str = Depends(current_user)):
    return {"greeting": "今天也照顾好自己", "daily_recommendation": "规律作息，适度活动，感到不适及时就医", "personalization": {"user_id": user_id, "source": "profile_and_recent_activity"}, "updated_at": int(time.time())}


@app.get("/api/v1/conversations")
def conversations(user_id: str = Depends(current_user)):
    with db() as conn:
        rows = conn.execute("SELECT role,content,created_at FROM messages WHERE user_id=? ORDER BY created_at DESC LIMIT 100", (user_id,)).fetchall()
    return {"items": [dict(row) for row in rows]}


@app.api_route("/api/v1/settings/{kind}", methods=["GET", "PUT"])
@app.api_route("/api/v1/notifications/{kind}", methods=["GET", "PUT"])
async def settings(kind: str, request: Request, user_id: str = Depends(current_user)):
    key = f"{request.url.path.split('/')[3]}:{kind}"
    with db() as conn:
        if request.method == "PUT":
            value = await request.json()
            conn.execute("INSERT OR REPLACE INTO settings VALUES(?,?,?)", (user_id, key, json.dumps(value, ensure_ascii=False)))
            return value
        row = conn.execute("SELECT value FROM settings WHERE user_id=? AND kind=?", (user_id, key)).fetchone()
    return json.loads(row["value"]) if row else {}


@app.post("/api/v1/reflections")
async def reflection(request: Request, user_id: str = Depends(current_user)):
    payload = await request.json()
    content = str(payload.get("content") or payload.get("text") or "").strip()
    if not content:
        raise HTTPException(422, "记录内容不能为空")
    item_id = str(uuid.uuid4())
    with db() as conn:
        conn.execute("INSERT INTO reflections VALUES(?,?,?,?)", (item_id, user_id, content[:10000], int(time.time())))
    return {"id": item_id, "saved": True}


@app.post("/api/v1/feedback")
@app.post("/api/v1/feedback/rating")
async def feedback(request: Request, user_id: str = Depends(current_user)):
    payload = await request.json()
    with db() as conn:
        conn.execute("INSERT INTO feedback VALUES(?,?,?,?)", (str(uuid.uuid4()), user_id, json.dumps(payload, ensure_ascii=False), int(time.time())))
    return {"saved": True}


@app.delete("/api/v1/conversations")
def delete_conversations(user_id: str = Depends(current_user)):
    with db() as conn:
        conn.execute("DELETE FROM messages WHERE user_id=?", (user_id,))
    return {"deleted": True}


@app.delete("/api/v1/memory/all")
def delete_memory(user_id: str = Depends(current_user)):
    with db() as conn:
        conn.execute("DELETE FROM settings WHERE user_id=?", (user_id,))
    return {"deleted": True}


@app.post("/api/v1/auth/data/export")
def export_data(user_id: str = Depends(current_user)):
    return {"status": "queued", "request_id": str(uuid.uuid4()), "user_id": user_id}


@app.delete("/api/v1/auth/account")
def delete_account(user_id: str = Depends(current_user)):
    with db() as conn:
        for table in ("messages", "settings", "reflections", "feedback", "entitlements"):
            conn.execute(f"DELETE FROM {table} WHERE user_id=?", (user_id,))
        conn.execute("DELETE FROM users WHERE id=?", (user_id,))
    return {"deleted": True}
