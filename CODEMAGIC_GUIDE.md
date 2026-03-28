# ShunShi App - Codemagic 构建指南

## 📱 项目信息
- **GitHub 仓库**: https://github.com/feifeizhao25-ship-it/shunshi-app
- **Flutter SDK**: 3.24.0
- **Bundle ID (iOS)**: com.shunshi.app
- **Application ID (Android)**: com.shunshi.app

---

## 🚀 第一步：在 Codemagic 创建应用

1. 访问 https://codemagic.io/register 注册账号
2. 使用 GitHub 登录（推荐）
3. 点击 **Add Application**
4. 选择 **shunshi-app** 仓库
5. 选择 **Flutter** 项目类型
6. 点击 **Finish**

---

## 📋 第二步：配置 iOS 构建（需要 Apple 开发者账号）

### 2.1 在 Apple Developer Portal 创建 App
1. 访问 https://developer.apple.com
2. 进入 Certificates, Identifiers & Profiles
3. 点击 + 创建新的 **App ID**（com.shunshi.app）
4. 创建 **Provisioning Profile**（App Store 类型）

### 2.2 在 Codemagic 配置签名
1. 进入 App Settings → **iOS Code Signing**
2. 上传你的 **Distribution Certificate** (.cer)
3. 上传 **Provisioning Profile** (.mobileprovision)
4. 或者关联 **App Store Connect API Key**（推荐）

### 2.3 配置 App Store Connect API Key（推荐）
1. 在 App Store Connect 创建 API Key（用户访问 → 密钥）
2. 在 Codemagic → **Team Integrations** → 添加 App Store Connect
3. 授权后自动获取签名文件

---

## 🤖 第三步：配置 Android 构建

### 3.1 在 Codemagic 上传签名密钥
1. 进入 App Settings → **Android Code Signing**
2. 上传 `shunshi-release.jks` 文件
3. 填入以下信息：
   - **Keystore password**: （需要查 Android build.gradle.kts 或 key.properties）
   - **Key alias**: `shunshi`
   - **Key password**: （同 keystore password）

### 3.2 查找 Android 签名信息
在你的 Mac 上查找 `android/key.properties` 或 `android/app/build.gradle.kts`

---

## ⚙️ 第四步：配置环境变量（如需要）

在 Codemagic → App Settings → **Environment Variables** 添加：

```bash
# iOS
APPLE_ID=your-apple-id@email.com
APP_SPECIFIC_PASSWORD=your-app-specific-password

# Android（如果需要）
ANDROID_SDK_ROOT=/Users/builder/Android/SDK
```

---

## ▶️ 第五步：触发构建

### iOS 构建
1. 在 Codemagic 点击 **Start new build**
2. 选择 **ios-workflow**
3. 选择构建机器（Mac Mini 或 Mac Pro）
4. 点击 **Start build**

### Android 构建
1. 选择 **android-workflow**
2. 点击 **Start build**

---

## 📦 构建产物

- **iOS**: `build/ios/ipa/*.ipa`（可在 TestFlight / App Store 发布）
- **Android**: `build/app/outputs/flutter-apk/*.apk`（可在 Google Play 发布）

---

## 🔧 工作流配置

`codemagic.yaml` 已在仓库中，包含：
- `ios-workflow`: iOS App Store 构建
- `android-workflow`: Android release 构建

如需调整，在 GitHub 修改 `codemagic.yaml` 后重新构建即可。

---

## ❓ 常见问题

**Q: iOS 构建失败提示"no pods installed"**
A: 在 Codemagic 的 iOS workflow 中添加：
```yaml
- name: Install CocoaPods
  script: |
    cd ios && pod install
```

**Q: Android 构建失败**
A: 检查签名密钥信息是否正确

**Q: 如何构建 Ad Hoc 测试版？**
A: 修改 `codemagic.yaml` 中 iOS workflow 的 `--type` 为 `ad-hoc`

---

需要帮助可以截图发给我！
