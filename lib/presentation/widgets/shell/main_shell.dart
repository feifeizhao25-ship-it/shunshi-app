import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../design_system/theme.dart';

/// MainShell — 5 Tab 底部导航容器
///
/// 由 GoRouter ShellRoute 驱动，不再使用 IndexedStack。
/// child 即当前路由对应的页面 Widget。
class MainShell extends StatelessWidget {
  final Widget child;

  const MainShell({super.key, required this.child});

  // ── 5个Tab定义 ──────────────────────────────────────────
  static const _tabs = [
    _TabDef(
      path: '/home',
      icon: Icons.home_outlined,
      activeIcon: Icons.home_rounded,
      label: '首页',
    ),
    _TabDef(
      path: '/companion',
      icon: Icons.chat_bubble_outline,
      activeIcon: Icons.chat_bubble_rounded,
      label: 'AI对话',
    ),
    _TabDef(
      path: '/seasons',
      icon: Icons.eco_outlined,
      activeIcon: Icons.eco,
      label: '节气',
    ),
    _TabDef(
      path: '/library',
      icon: Icons.auto_stories_outlined,
      activeIcon: Icons.auto_stories,
      label: '内容',
    ),
    _TabDef(
      path: '/profile',
      icon: Icons.person_outline,
      activeIcon: Icons.person_rounded,
      label: '我的',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentPath = GoRouterState.of(context).uri.path;

    return Scaffold(
      backgroundColor: isDark ? null : ShunShiColors.background,
      body: child,
      bottomNavigationBar: Container(
        // 背景白色 + 顶部细线（0.5dp，surfaceDim色）
        decoration: BoxDecoration(
          color: isDark ? null : ShunShiColors.surface,
          border: Border(
            top: BorderSide(
              color: ShunShiColors.border,
              width: 0.5,
            ),
          ),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 64,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: _tabs.asMap().entries.map((entry) {
                final index = entry.key;
                final tab = entry.value;
                final isActive = currentPath == tab.path ||
                    (tab.path != '/home' &&
                        currentPath.startsWith(tab.path));
                return _NavTab(
                  icon: tab.icon,
                  activeIcon: tab.activeIcon,
                  label: tab.label,
                  isActive: isActive,
                  activeColor: ShunShiColors.primary,
                  inactiveColor: ShunShiColors.textTertiary,
                  isCenter: index == 1,
                  onTap: () => context.go(tab.path),
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }
}

class _TabDef {
  final String path;
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const _TabDef({
    required this.path,
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}

/// 极简导航 Tab
///
/// - 高度 64dp + SafeArea（由父级 SafeArea 提供）
/// - 图标 24dp，选中 primary 色，未选中 textHint 色
/// - 标签 12sp
/// - 切换动画：颜色渐变 200ms，无缩放无弹跳
/// - 中间 Tab（Companion）轻微放大装饰
class _NavTab extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isActive;
  final Color activeColor;
  final Color inactiveColor;
  final bool isCenter;
  final VoidCallback onTap;

  const _NavTab({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isActive,
    required this.activeColor,
    required this.inactiveColor,
    this.isCenter = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final iconSize = isCenter ? 26.0 : 24.0;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 图标 — AnimatedSwitcher 不合适（只做颜色过渡）
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              child: Icon(
                isActive ? activeIcon : icon,
                color: isActive ? activeColor : inactiveColor,
                size: iconSize,
              ),
            ),
            const SizedBox(height: 4),
            // 标签 — 颜色渐变
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                fontSize: 12,
                fontWeight: isActive ? FontWeight.w500 : FontWeight.w400,
                color: isActive ? activeColor : inactiveColor,
              ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }
}
