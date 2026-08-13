import 'package:in_app_purchase/in_app_purchase.dart';

class StoreService {
  StoreService._();

  static final StoreService _instance = StoreService._();
  factory StoreService() => _instance;

  final InAppPurchase _purchase = InAppPurchase.instance;
  bool _available = false;
  Future<bool>? _initializing;

  bool get isAvailable => _available;

  Future<bool> initialize() {
    return _initializing ??= _purchase.isAvailable().then((available) {
      _available = available;
      return available;
    });
  }

  Future<void> restorePurchases() async {
    if (!await initialize()) {
      throw StateError('当前设备不支持应用内购');
    }
    await _purchase.restorePurchases();
  }
}
