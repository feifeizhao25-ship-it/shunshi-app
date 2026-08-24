// lib/presentation/pages/login/login_page.dart
//
// 顺时登录页 — 手机号验证码 / 密码 / 微信 / 游客
// 设计风格: ShunshiColors (鼠尾草绿, 米白), 大留白, 柔和输入框

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/shunshi_colors.dart';
import '../../../core/theme/shunshi_spacing.dart';
import '../../../core/theme/shunshi_text_styles.dart';
import '../../../data/network/api_client.dart';
import '../../../data/storage/storage_manager.dart';
import '../../widgets/responsive_content.dart';

/// 登录方式
enum _LoginMode { sms, password }

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  _LoginMode _mode = _LoginMode.sms;
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _codeController = TextEditingController();

  bool _isLoading = false;
  bool _acceptedLegal = false;
  bool _codeSent = false;
  int _countdown = 0;
  String? _errorMessage;

  bool _ensureLegalConsent() {
    if (_acceptedLegal) return true;
    setState(() => _errorMessage = '请先阅读并同意用户协议和隐私政策');
    return false;
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  /// 发送验证码
  Future<void> _sendCode() async {
    if (!_ensureLegalConsent()) return;
    final phone = _phoneController.text.trim();
    if (phone.length < 11) {
      setState(() => _errorMessage = '请输入正确的手机号');
      return;
    }

    setState(() => _isLoading = true);
    _errorMessage = null;

    try {
      final client = ApiClient();
      await client.post('/api/v1/auth/sms/send', data: {'phone': phone});
      setState(() {
        _codeSent = true;
        _isLoading = false;
        _countdown = 60;
      });
      _startCountdown();
    } catch (_) {
      setState(() {
        _errorMessage = '发送失败，请稍后重试';
        _isLoading = false;
      });
    }
  }

  void _startCountdown() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      setState(() => _countdown--);
      return _countdown > 0;
    });
  }

  /// 短信验证码登录
  Future<void> _smsLogin() async {
    if (!_ensureLegalConsent()) return;
    final phone = _phoneController.text.trim();
    final code = _codeController.text.trim();
    if (phone.length < 11 || code.isEmpty) {
      setState(() => _errorMessage = '请填写手机号和验证码');
      return;
    }

    setState(() => _isLoading = true);
    _errorMessage = null;

    try {
      final client = ApiClient();
      final response = await client.post(
        '/api/v1/auth/sms/verify',
        data: {'phone': phone, 'code': code},
      );
      final data = response.data as Map<String, dynamic>;
      _handleLoginSuccess(data);
    } catch (_) {
      setState(() {
        _errorMessage = '登录失败，请检查验证码';
        _isLoading = false;
      });
    }
  }

  /// 密码登录
  Future<void> _passwordLogin() async {
    if (!_ensureLegalConsent()) return;
    final phone = _phoneController.text.trim();
    final password = _passwordController.text.trim();
    if (phone.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = '请填写手机号和密码');
      return;
    }

    setState(() => _isLoading = true);
    _errorMessage = null;

    try {
      final client = ApiClient();
      final response = await client.post(
        '/api/v1/auth/login',
        data: {'phone': phone, 'password': password},
      );
      final data = response.data as Map<String, dynamic>;
      _handleLoginSuccess(data);
    } catch (_) {
      setState(() {
        _errorMessage = '登录失败，请检查手机号和密码';
        _isLoading = false;
      });
    }
  }

  /// 游客登录
  Future<void> _guestLogin() async {
    if (!_ensureLegalConsent()) return;
    setState(() => _isLoading = true);
    try {
      final client = ApiClient();
      final response = await client.post('/api/v1/auth/guest-login');
      final data = response.data as Map<String, dynamic>;
      _handleLoginSuccess(data);
    } catch (_) {
      setState(() {
        _errorMessage = '游客登录失败，请稍后重试';
        _isLoading = false;
      });
    }
  }

  /// 微信登录（预留）
  Future<void> _wechatLogin() async {
    if (!_ensureLegalConsent()) return;
    setState(() => _isLoading = true);
    // TODO: 接入微信SDK
    setState(() => _isLoading = false);
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('微信登录即将开放')));
    }
  }

  Future<void> _handleLoginSuccess(Map<String, dynamic> data) async {
    final token = (data['access_token'] ?? data['token']) as String?;
    final refreshToken = data['refresh_token'] as String? ?? '';
    if (token != null) {
      await StorageManager.user.saveToken(token, refreshToken: refreshToken);
    }
    if (!mounted) return;
    context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ShunshiColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: ShunshiSpacing.pagePadding,
          ),
          // 桌面宽屏下限宽居中，避免移动布局拉满全宽
          child: MaxWidthContent(
            maxWidth: kFormContentMaxWidth,
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 60),

              // Logo / 品牌
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: ShunshiColors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Center(
                        child: Text('🌿', style: const TextStyle(fontSize: 36)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text('顺时', style: ShunshiTextStyles.greeting),
                    const SizedBox(height: 4),
                    Text('顺应时节，养生有道', style: ShunshiTextStyles.bodySecondary),
                  ],
                ),
              ),

              const SizedBox(height: 48),

              // 错误提示
              if (_errorMessage != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: ShunshiColors.error.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(
                      ShunshiSpacing.radiusMedium,
                    ),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: ShunshiTextStyles.caption.copyWith(
                      color: ShunshiColors.error,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // 手机号输入框
              _buildInputField(
                controller: _phoneController,
                hint: '手机号',
                prefix: Icons.phone_android_outlined,
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),

              // 验证码 or 密码
              if (_mode == _LoginMode.sms) ...[
                Row(
                  children: [
                    Expanded(
                      child: _buildInputField(
                        controller: _codeController,
                        hint: '验证码',
                        prefix: Icons.shield_outlined,
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      height: 52,
                      child: TextButton(
                        onPressed: _codeSent && _countdown > 0
                            ? null
                            : _sendCode,
                        child: Text(
                          _codeSent && _countdown > 0
                              ? '${_countdown}s'
                              : '获取验证码',
                          style: ShunshiTextStyles.buttonSmall.copyWith(
                            color: _codeSent && _countdown > 0
                                ? ShunshiColors.textHint
                                : ShunshiColors.primary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                _buildInputField(
                  controller: _passwordController,
                  hint: '密码',
                  prefix: Icons.lock_outline,
                  obscureText: true,
                ),
              ],

              const SizedBox(height: 8),

              // 切换登录方式
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    setState(() {
                      _mode = _mode == _LoginMode.sms
                          ? _LoginMode.password
                          : _LoginMode.sms;
                      _errorMessage = null;
                    });
                  },
                  child: Text(
                    _mode == _LoginMode.sms ? '密码登录' : '验证码登录',
                    style: ShunshiTextStyles.caption.copyWith(
                      color: ShunshiColors.primary,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: Checkbox(
                      value: _acceptedLegal,
                      activeColor: ShunshiColors.primary,
                      onChanged: _isLoading
                          ? null
                          : (value) => setState(() {
                              _acceptedLegal = value ?? false;
                              if (_acceptedLegal) _errorMessage = null;
                            }),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text('我已阅读并同意', style: ShunshiTextStyles.caption),
                        TextButton(
                          onPressed: () => context.push('/terms'),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            minimumSize: const Size(0, 32),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text('《用户协议》'),
                        ),
                        Text('和', style: ShunshiTextStyles.caption),
                        TextButton(
                          onPressed: () => context.push('/privacy'),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            minimumSize: const Size(0, 32),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text('《隐私政策》'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // 登录按钮
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading
                      ? null
                      : (_mode == _LoginMode.sms ? _smsLogin : _passwordLogin),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ShunshiColors.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: ShunshiColors.primary.withValues(
                      alpha: 0.5,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        ShunshiSpacing.radiusMedium,
                      ),
                    ),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text('登录', style: ShunshiTextStyles.button),
                ),
              ),

              const SizedBox(height: 12),

              // 注册入口
              Center(
                child: TextButton(
                  onPressed: () {
                    // 跳转注册（暂复用登录页）
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(const SnackBar(content: Text('注册页面即将开放')));
                  },
                  child: Text(
                    '还没有账号？立即注册',
                    style: ShunshiTextStyles.caption.copyWith(
                      color: ShunshiColors.primary,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 40),

              // 分割线
              Row(
                children: [
                  const Expanded(child: Divider(color: ShunshiColors.divider)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      '其他登录方式',
                      style: ShunshiTextStyles.caption.copyWith(
                        color: ShunshiColors.textHint,
                      ),
                    ),
                  ),
                  const Expanded(child: Divider(color: ShunshiColors.divider)),
                ],
              ),

              const SizedBox(height: 28),

              // 第三方登录: 微信
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildSocialButton(
                    icon: Icons.chat_bubble,
                    label: '微信',
                    color: const Color(0xFF07C160),
                    onTap: _wechatLogin,
                  ),
                  const SizedBox(width: 32),
                  _buildSocialButton(
                    icon: Icons.person_outline,
                    label: '游客登录',
                    color: ShunshiColors.textSecondary,
                    onTap: _guestLogin,
                  ),
                ],
              ),

              const SizedBox(height: 40),

              // 跳过
              Center(
                child: TextButton(
                  onPressed: () => context.go('/home'),
                  child: Text(
                    '跳过',
                    style: ShunshiTextStyles.caption.copyWith(
                      color: ShunshiColors.textHint,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),
            ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String hint,
    required IconData prefix,
    TextInputType? keyboardType,
    bool obscureText = false,
  }) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: ShunshiColors.surfaceDim,
        borderRadius: BorderRadius.circular(ShunshiSpacing.radiusMedium),
        border: Border.all(color: ShunshiColors.border),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        style: ShunshiTextStyles.body.copyWith(fontSize: 15),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: ShunshiTextStyles.caption.copyWith(
            color: ShunshiColors.textHint,
          ),
          prefixIcon: Icon(prefix, color: ShunshiColors.textHint, size: 20),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        ),
      ),
    );
  }

  Widget _buildSocialButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(label, style: ShunshiTextStyles.caption),
        ],
      ),
    );
  }
}
