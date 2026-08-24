// 桌面宽屏内容限宽 — 移动布局页面在桌面视口下不再拉满全宽
//
// 与 onboarding 落地页的桌面布局思路一致（Center + ConstrainedBox）：
// 窄屏（手机）下约束不生效，宽屏下内容居中并限制最大宽度。

import 'package:flutter/material.dart';

/// 表单类页面（登录/订阅）桌面限宽
const double kFormContentMaxWidth = 520;

/// 信息流类页面（首页四层结构）桌面限宽
const double kFeedContentMaxWidth = 720;

/// 内容限宽居中容器
class MaxWidthContent extends StatelessWidget {
  final double maxWidth;
  final Widget child;

  const MaxWidthContent({
    super.key,
    required this.maxWidth,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: SizedBox(width: double.infinity, child: child),
      ),
    );
  }
}
