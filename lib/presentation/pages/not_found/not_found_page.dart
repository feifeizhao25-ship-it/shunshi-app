// 404 页 — 路由未匹配时的兜底页
//
// GoRouter 默认错误页为英文且会把 `GoException: no routes for location: ...`
// 框架异常文本直接暴露给用户；这里换成中文友好提示，不展示任何异常细节。

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/shunshi_colors.dart';
import '../../../core/theme/shunshi_text_styles.dart';

class NotFoundPage extends StatelessWidget {
  const NotFoundPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ShunshiColors.background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('🌿', style: TextStyle(fontSize: 48)),
                const SizedBox(height: 20),
                Text(
                  '页面不存在',
                  style: ShunshiTextStyles.heading.copyWith(
                    color: ShunshiColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '你要找的页面走丢了，回首页看看吧',
                  textAlign: TextAlign.center,
                  style: ShunshiTextStyles.bodySecondary.copyWith(height: 1.6),
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: () => context.go('/home'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ShunshiColors.primaryDark,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text('返回首页', style: ShunshiTextStyles.buttonSmall),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
