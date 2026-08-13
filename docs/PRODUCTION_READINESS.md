# 顺时国内版生产就绪说明

## 自动门禁

提交和合并请求会验证以下内容：

- Flutter 静态分析无错误；
- 完整单元、组件与应用流程测试通过；
- Web Release 构建通过；
- Android Release 冒烟构建通过；
- 生产 API 地址在 Release 模式下必须显式配置；
- 移动端不保存或发送大模型供应商密钥；
- Android/iOS 所需权限说明齐全；
- 正式 Android 包不存在静默使用调试签名的路径。

本地运行生产门禁：

```bash
python3 scripts/verify_production_release.py
flutter analyze --no-fatal-infos --no-fatal-warnings
flutter test
flutter build web --release \
  --dart-define=SHUNSHI_API_BASE_URL="https://<your-production-api-host>"
```

## 生产配置契约

- `SHUNSHI_API_BASE_URL`：必须是已启用 HTTPS 的国内生产 API 根地址。
- Android 本地签名：复制 `android/key.properties.example`，真实签名文件保存在仓库外。
- Codemagic Android 签名标识：`shunshi_release`。
- Codemagic 环境变量组：`shunshi_production`。
- iOS Bundle ID：`com.shunshi.app`。

上述名称只描述配置契约，不包含任何密码、密钥或证书内容。

## 上线前人工动作

以下动作涉及主体身份、法律责任或生产密钥，必须由账号所有者完成：

1. 确认国内隐私政策、用户协议、算法与生成式 AI 合规材料及备案状态；
2. 在生产环境配置 HTTPS API 地址和服务端密钥主备，完成回滚演练；
3. 向 Codemagic 上传 Android 签名和 Apple 发布证书/描述文件；
4. 在应用市场后台完成实名、支付、内容分级与最终发布确认；
5. 对真实生产 API 完成登录、订阅、退款、AI 安全提示和数据删除验收。

只有取得商店构建 ID、审核状态和生产探针结果，才能记录为“已正式上线”。
