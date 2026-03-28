# ShunShi App - Codemagic 构建指南

## 📱 项目信息
- **GitHub 仓库**: https://github.com/feifeizhao25-ship-it/shunshi-app
- **Flutter SDK**: 3.24.0
- **Bundle ID (iOS)**: com.shunshi.app
- **Application ID (Android)**: com.shunshi.app

---

## 🚀 第一步：在 Codemagic 创建应用

1. 访问 https://codemagic.io/register 注册账号（用 GitHub 登录最快）
2. 点击 **Add Application**
3. 选择 **shunshi-app** 仓库
4. 选择 **Flutter** 项目类型
5. 点击 **Finish**

---

## 🤖 第二步：配置 Android 构建（必须先做）

Android 构建需要上传签名密钥。在 Codemagic 进入 App Settings：

### 2.1 上传签名密钥
1. 进入 **Android Code Signing**
2. 上传文件：`/opt/shunshi/keystore/shunshi-release.jks`
3. 填入信息：
   - **Keystore password**: `shunshi2024`
   - **Key alias**: `shunshi`
   - **Key password**: `shunshi2024`

### 2.2 触发 Android 构建
1. 点击 **Start new build**
2. 选择 **android-workflow**
3. 等待构建完成
4. 下载 APK: `build/app/outputs/flutter-apk/app-release.apk`

---

## 🍎 第三步：配置 iOS 构建

### 3.1 需要的材料
- Apple 开发者账号（$99/年）
- Mac 电脑（用于创建证书）或通过 Codemagic 自动签名

### 3.2 自动签名（推荐）
1. 在 App Store Connect 创建 App ID: `com.shunshi.app`
2. 在 Codemagic → **iOS Code Signing**
3. 选择 **App Store Connect API Key**
4. 关联你的 App Store Connect 账号

### 3.3 触发 iOS 构建
1. 点击 **Start new build**
2. 选择 **ios-workflow**
3. 选择 Mac Mini (arm64) 构建机器
4. 等待约 15-20 分钟
5. 下载 IPA: `build/ios/ipa/*.ipa`

---

## ⚙️ 第四步：发布 App

### Android - Google Play
1. 创建 Google Play 开发者账号
2. 上传签名后的 APK/AAB
3. 填写应用信息并提交审核

### iOS - App Store
1. 创建 App Store Connect 应用
2. 在 Codemagic 构建完成后自动上传
3. 或手动通过 Transporter 上传 IPA
4. 填写应用信息并提交审核

---

## 📋 构建产物位置

- **Android APK**: `build/app/outputs/flutter-apk/app-release.apk`
- **Android AAB**: `build/app/outputs/flutter-apk/app-release.aab`
- **iOS IPA**: `build/ios/ipa/*.ipa`

---

## ❓ 常见问题

**Q: Android keystore 找不到或密码不对？**
A: Keystore 位置：`/opt/shunshi/keystore/shunshi-release.jks`
   密码：shunshi2024

**Q: iOS 构建失败 "No profiles found"?**
A: 需要在 Apple Developer Portal 创建 App ID 和 Provisioning Profile，然后在 Codemagic 配置签名

**Q: 如何测试分发？**
A: Android 可以直接安装 APK；iOS 需要 Ad Hoc 或 TestFlight

---

## 📁 仓库文件结构

```
shunshi-app/
├── ios/              # iOS 项目
├── android/         # Android 项目
├── lib/              # Flutter Dart 代码
├── web/              # Web 版本
├── pubspec.yaml      # Flutter 依赖
├── codemagic.yaml    # CI/CD 配置
└── CODEMAGIC_GUIDE.md
```
