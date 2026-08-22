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
android_settings = read("android/settings.gradle.kts")
gradle_wrapper = read("android/gradle/wrapper/gradle-wrapper.properties")
manifest = read("android/app/src/main/AndroidManifest.xml")
info = read("ios/Runner/Info.plist")
router_files = "\n".join(
    [
        read("lib/core/ai_router/ai_router.dart"),
        read("lib/core/ai_router/shunshi_router.dart"),
        read("lib/core/config/models.dart"),
    ]
)
runtime_dart = "\n".join(
    path.read_text(encoding="utf-8")
    for path in (ROOT / "lib").rglob("*.dart")
)
records_page = read("lib/presentation/pages/records/records_page.dart")

if "SHUNSHI_API_BASE_URL" not in app_config or "kReleaseMode" not in app_config:
    errors.append("release API URL is not fail-closed")
if 'signingConfigs.getByName("debug")' in android and "ALLOW_DEBUG_RELEASE_SIGNING" not in android:
    errors.append("Android release silently uses the debug signer")
if "key.properties" not in android:
    errors.append("Android release keystore contract is missing")
if 'com.android.application") version "8.9.2"' not in android_settings:
    errors.append("Android Gradle plugin must support the release AAR metadata")
if "gradle-8.11.1-all.zip" not in gradle_wrapper:
    errors.append("Gradle wrapper is incompatible with the Android Gradle plugin")
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
if "demo_user" in runtime_dart:
    errors.append("production runtime still falls back to a shared demo identity")
for fabricated_marker in ("模拟7天", "工作顺利", "和朋友聚餐", "完成了项目"):
    if fabricated_marker in records_page:
        errors.append(f"health records page contains fabricated user data: {fabricated_marker}")
if "HealthRecordStorage" not in records_page or "SharedPreferences" in records_page:
    errors.append("health journal is not persisted using encrypted local storage")

if errors:
    print("ShunShi production release gate: FAIL")
    for error in errors:
        print(f"- {error}")
    sys.exit(1)

print("ShunShi production release gate: PASS")
