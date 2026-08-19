import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'data/storage/storage_manager.dart';
import 'data/services/notification_service.dart';
import 'design_system/theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 并行初始化，不阻塞启动 — 避免主线程等待导致 iOS 系统 watchdog kill
  unawaited(
    Future.wait<void>([
      StorageManager.init(),
      NotificationService().init(),
    ]).catchError((Object e) {
      debugPrint('Init error: $e');
      return <void>[];
    }),
  );

  // 注意：offlineSyncService.startAutoSync() 已移至 HomePage.initState 中延迟启动
  // 网络服务单例在首次引用时自动初始化，无需在 main 中主动触发

  runApp(const ProviderScope(child: ShunshiApp()));
}

class ShunshiApp extends StatelessWidget {
  const ShunshiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      routerConfig: AppRouter.router,
      title: '顺时 ShunShi',
      debugShowCheckedModeBanner: false,
      theme: ShunShiTheme.lightTheme,
      // ShunShiTheme 目前只有浅色主题。此前把 darkTheme 也指向 lightTheme
      // 并设 themeMode: system —— 效果是系统开启深色模式时仍显示浅色，
      // 但 Flutter 会认为 App 支持深色，导致状态栏/系统控件按深色渲染，
      // 与页面浅色背景冲突。
      // 在补齐真正的深色主题之前，明确声明本 App 仅支持浅色。
      themeMode: ThemeMode.light,
    );
  }
}
