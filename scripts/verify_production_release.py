#!/usr/bin/env python3
from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read(relative: str) -> str:
    return (ROOT / relative).read_text(encoding="utf-8")


errors: list[str] = []
app_config = read("lib/core/config/app_config.dart")
android = read("android/app/build.gradle.kts")
manifest = read("android/app/src/main/AndroidManifest.xml")
info = read("ios/Runner/Info.plist")
router_files = "\n".join(
    [
        read("lib/core/ai_router/ai_router.dart"),
        read("lib/core/ai_router/shunshi_router.dart"),
        read("lib/core/config/models.dart"),
    ]
)

if "SHUNSHI_API_BASE_URL" not in app_config or "kReleaseMode" not in app_config:
    errors.append("release API URL is not fail-closed")
if 'signingConfigs.getByName("debug")' in android and "ALLOW_DEBUG_RELEASE_SIGNING" not in android:
    errors.append("Android release silently uses the debug signer")
if "key.properties" not in android:
    errors.append("Android release keystore contract is missing")
for variable in (
    "CM_KEYSTORE_PATH",
    "CM_KEYSTORE_PASSWORD",
    "CM_KEY_ALIAS",
    "CM_KEY_PASSWORD",
):
    if variable not in android:
        errors.append(f"Codemagic Android signing contract missing: {variable}")
for permission in ("INTERNET", "RECORD_AUDIO", "CAMERA"):
    if permission not in manifest:
        errors.append(f"Android permission missing: {permission}")
for usage in ("NSMicrophoneUsageDescription", "NSSpeechRecognitionUsageDescription"):
    if usage not in info:
        errors.append(f"iOS usage description missing: {usage}")
if re.search(r"Authorization['\"]?\s*:\s*['\"]Bearer\s*\$\{[^}]*apiKey", router_files):
    errors.append("provider API key is sent from the mobile client")
if "final String apiKey" in router_files:
    errors.append("provider API key remains in a mobile client config model")

if errors:
    print("ShunShi production release gate: FAIL")
    for error in errors:
        print(f"- {error}")
    sys.exit(1)

print("ShunShi production release gate: PASS")
