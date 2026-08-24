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
LLM_BASE = os.getenv("SHUNSHI_OPENAI_BASE_URL", os.getenv("OPENROUTER_BASE_URL", "https://openrouter.ai/api/v1" if os.getenv("OPENROUTER_API_KEY") else "")).rstrip("/")
LLM_KEY = os.getenv("SHUNSHI_OPENAI_API_KEY", os.getenv("OPENROUTER_API_KEY", ""))
LLM_MODEL = os.getenv("SHUNSHI_OPENAI_MODEL", os.getenv("OPENROUTER_MODEL_FAST", "qwen/qwen3-30b-a3b-instruct-2507"))
LLM_FALLBACK_MODELS = [item.strip() for item in os.getenv("OPENROUTER_FALLBACK_MODELS", "deepseek/deepseek-v3.2,google/gemini-2.5-flash-lite").split(",") if item.strip()]
LLM_IS_OPENROUTER = "openrouter.ai" in LLM_BASE
LLM_ALLOW_CROSS_BORDER = os.getenv("SHUNSHI_LLM_ALLOW_CROSS_BORDER", "false").lower() == "true"
LLM_CIRCUIT_FAILURES = max(1, int(os.getenv("OPENROUTER_CIRCUIT_FAILURES", "3")))
LLM_CIRCUIT_COOLDOWN_SECONDS = max(1, int(os.getenv("OPENROUTER_CIRCUIT_COOLDOWN_SECONDS", "60")))
AI_DAILY_LIMIT_FREE = max(1, int(os.getenv("SHUNSHI_AI_DAILY_LIMIT_FREE", "20")))
AI_DAILY_LIMIT_MEMBER = max(AI_DAILY_LIMIT_FREE, int(os.getenv("SHUNSHI_AI_DAILY_LIMIT_MEMBER", "200")))
llm_failures = 0
llm_open_until = 0.0
SMS_URL = os.getenv("SHUNSHI_SMS_PROVIDER_URL", "")
SMS_TOKEN = os.getenv("SHUNSHI_SMS_PROVIDER_TOKEN", "")
IAP_VERIFY_URL = os.getenv("SHUNSHI_IAP_VERIFY_URL", "")
IAP_VERIFY_TOKEN = os.getenv("SHUNSHI_IAP_VERIFY_TOKEN", "")
IAP_PRODUCTS = {"shunshi_yangxin_monthly", "shunshi_healing_monthly", "shunshi_family_monthly"}

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
        CREATE TABLE IF NOT EXISTS ai_usage(id TEXT PRIMARY KEY, user_id TEXT NOT NULL, day_key INTEGER NOT NULL, tokens INTEGER NOT NULL DEFAULT 0, cost_usd REAL NOT NULL DEFAULT 0, created_at INTEGER NOT NULL);
        CREATE INDEX IF NOT EXISTS idx_ai_usage_user_day ON ai_usage(user_id, day_key);
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


class IAPReceipt(BaseModel):
    product_id: str
    receipt: str = Field(min_length=16, max_length=200000)
    store: str = Field(pattern=r"^(app_store|google_play)$")


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


async def llm_answer(message: str) -> tuple[str, dict[str, Any]]:
    global llm_failures, llm_open_until
    if not LLM_BASE or not LLM_KEY:
        if ENV == "production":
            raise HTTPException(503, "智能服务暂不可用")
        return "我已收到你的记录。你可以先从一件今天能完成的小事开始；如有持续不适，请及时咨询专业医生。", {"provider": "development_fallback", "model": None, "tokens": 0, "cost_usd": 0, "latency_ms": 0}
    if LLM_IS_OPENROUTER and not LLM_ALLOW_CROSS_BORDER:
        raise HTTPException(503, "跨境模型未获得明确授权，智能服务已拒绝发送健康数据")
    if LLM_IS_OPENROUTER and time.monotonic() < llm_open_until:
        raise HTTPException(503, "智能服务暂时熔断，请稍后重试")
    prompt = "你是顺时健康陪伴助手。只用简明中文，不诊断、不替代医生；涉及危险症状应建议立即就医。回答要可执行、易懂。"
    payload: dict[str, Any] = {"model": LLM_MODEL, "messages": [{"role": "system", "content": prompt}, {"role": "user", "content": message}], "temperature": 0.3, "max_tokens": 800}
    if LLM_IS_OPENROUTER:
        payload.update({"models": [LLM_MODEL, *LLM_FALLBACK_MODELS], "provider": {"data_collection": "deny", "zdr": True, "require_parameters": True}})
    started_at = time.monotonic()
    try:
        async with httpx.AsyncClient(timeout=60) as client:
            response = await client.post(f"{LLM_BASE}/chat/completions", headers={"Authorization": f"Bearer {LLM_KEY}", "HTTP-Referer": os.getenv("OPENROUTER_SITE_URL", "https://shunshi.cn"), "X-Title": "顺时"}, json=payload)
            response.raise_for_status()
            data = response.json()
            content = str(data.get("choices", [{}])[0].get("message", {}).get("content", "")).strip()
            if not content:
                raise HTTPException(502, "智能服务未返回有效内容")
    except Exception:
        if LLM_IS_OPENROUTER:
            llm_failures += 1
            if llm_failures >= LLM_CIRCUIT_FAILURES:
                llm_open_until = time.monotonic() + LLM_CIRCUIT_COOLDOWN_SECONDS
        raise
    if LLM_IS_OPENROUTER:
        llm_failures = 0
        llm_open_until = 0.0
    usage = data.get("usage", {})
    return content, {"provider": "openrouter" if LLM_IS_OPENROUTER else "openai_compatible", "model": data.get("model", LLM_MODEL), "tokens": int(usage.get("total_tokens", 0) or 0), "cost_usd": float(usage["cost"]) if usage.get("cost") is not None else None, "latency_ms": int((time.monotonic() - started_at) * 1000)}


def assert_ai_quota(user_id: str) -> int:
    """按北京时间自然日校验 AI 权益；有效会员使用会员额度。"""
    day_key = (int(time.time()) + 8 * 3600) // 86400
    with db() as conn:
        member = conn.execute(
            "SELECT 1 FROM entitlements WHERE user_id=? AND expires_at>? LIMIT 1",
            (user_id, int(time.time())),
        ).fetchone()
        used = conn.execute(
            "SELECT COUNT(*) AS count FROM ai_usage WHERE user_id=? AND day_key=?",
            (user_id, day_key),
        ).fetchone()["count"]
    limit = AI_DAILY_LIMIT_MEMBER if member else AI_DAILY_LIMIT_FREE
    if used >= limit:
        raise HTTPException(429, f"今日智能对话额度已用完（{used}/{limit}）")
    return day_key


def record_ai_usage(user_id: str, day_key: int, metadata: dict[str, Any]) -> None:
    with db() as conn:
        conn.execute(
            "INSERT INTO ai_usage VALUES(?,?,?,?,?,?)",
            (str(uuid.uuid4()), user_id, day_key, int(metadata.get("tokens", 0) or 0), float(metadata.get("cost_usd", 0) or 0), int(time.time())),
        )


@app.get("/api/v1/ai/usage")
def ai_usage(user_id: str = Depends(current_user)):
    day_key = (int(time.time()) + 8 * 3600) // 86400
    with db() as conn:
        member = conn.execute("SELECT 1 FROM entitlements WHERE user_id=? AND expires_at>? LIMIT 1", (user_id, int(time.time()))).fetchone()
        row = conn.execute(
            "SELECT COUNT(*) AS calls, COALESCE(SUM(tokens),0) AS tokens, COALESCE(SUM(cost_usd),0) AS cost FROM ai_usage WHERE user_id=? AND day_key=?",
            (user_id, day_key),
        ).fetchone()
    limit = AI_DAILY_LIMIT_MEMBER if member else AI_DAILY_LIMIT_FREE
    used = int(row["calls"])
    ratio = used / limit
    warning = "blocked" if ratio >= 1 else "critical" if ratio >= 0.95 else "warning" if ratio >= 0.8 else "normal"
    return {"used": used, "limit": limit, "remaining": max(limit - used, 0), "usage_ratio": round(ratio, 4), "warning_level": warning, "tokens": int(row["tokens"]), "cost_usd": round(float(row["cost"]), 6), "timezone": "Asia/Shanghai"}


@app.post("/api/v1/billing/iap/verify")
async def verify_iap(body: IAPReceipt, user_id: str = Depends(current_user)):
    if body.product_id not in IAP_PRODUCTS:
        raise HTTPException(400, "未知订阅商品")
    if not IAP_VERIFY_URL or not IAP_VERIFY_TOKEN:
        raise HTTPException(503, "应用商店凭证验证服务尚未配置")
    async with httpx.AsyncClient(timeout=30) as client:
        response = await client.post(IAP_VERIFY_URL, json=body.model_dump(), headers={"Authorization": f"Bearer {IAP_VERIFY_TOKEN}"})
        response.raise_for_status()
    verified = response.json()
    if verified.get("valid") is not True or verified.get("product_id") != body.product_id:
        raise HTTPException(400, "购买凭证验证失败")
    expires_at = int(verified.get("expires_at", 0) or 0)
    transaction_id = str(verified.get("original_transaction_id", "")).strip()
    if expires_at <= time.time() or not transaction_id:
        raise HTTPException(400, "购买凭证已过期或不完整")
    with db() as conn:
        owner = conn.execute("SELECT user_id FROM entitlements WHERE original_transaction_id=?", (transaction_id,)).fetchone()
        if owner and owner["user_id"] != user_id:
            raise HTTPException(409, "该购买凭证已绑定其他账号")
        conn.execute(
            "INSERT INTO entitlements VALUES(?,?,?,?,?,?) ON CONFLICT(user_id) DO UPDATE SET product_id=excluded.product_id,store=excluded.store,expires_at=excluded.expires_at,original_transaction_id=excluded.original_transaction_id,updated_at=excluded.updated_at",
            (user_id, body.product_id, body.store, expires_at, transaction_id, int(time.time())),
        )
    return {"active": True, "product_id": body.product_id, "expires_at": expires_at}


@app.post("/api/v1/chat/send")
@app.post("/api/v1/ai/chat")
async def chat(body: Chat, user_id: str = Depends(current_user)):
    message = body.text()
    day_key = assert_ai_quota(user_id)
    answer, ai_metadata = await llm_answer(message)
    record_ai_usage(user_id, day_key, ai_metadata)
    now = int(time.time())
    with db() as conn:
        conn.execute("INSERT INTO messages VALUES(?,?,?,?,?)", (str(uuid.uuid4()), user_id, "user", message, now))
        conn.execute("INSERT INTO messages VALUES(?,?,?,?,?)", (str(uuid.uuid4()), user_id, "assistant", answer, now))
    return {"content": answer, "message": answer, "text": answer, "tone": "gentle", "care_status": "stable", "safety_flag": "none", "ai_metadata": ai_metadata}


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
