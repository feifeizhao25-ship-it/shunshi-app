import 'package:in_app_purchase/in_app_purchase.dart';

class StoreService {
  StoreService._();

  static final StoreService _instance = StoreService._();
  factory StoreService() => _instance;

  final InAppPurchase _purchase = InAppPurchase.instance;
  bool _available = false;
  Future<bool>? _initializing;

  static const Set<String> productIds = {
    'shunshi_yangxin_monthly',
    'shunshi_healing_monthly',
    'shunshi_family_monthly',
  };

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

  Future<void> purchaseSubscription(String productId) async {
    if (!productIds.contains(productId)) {
      throw ArgumentError.value(productId, 'productId', '未知订阅商品');
    }
    if (!await initialize()) {
      throw StateError('当前设备不支持应用内购');
    }
    final response = await _purchase.queryProductDetails({productId});
    if (response.error != null) {
      throw StateError(response.error!.message);
    }
    if (response.productDetails.isEmpty) {
      throw StateError('订阅商品尚未在应用商店配置，请稍后再试');
    }
    final parameter = PurchaseParam(productDetails: response.productDetails.single);
    final started = await _purchase.buyNonConsumable(purchaseParam: parameter);
    if (!started) {
      throw StateError('未能启动支付，请稍后再试');
    }
  }
}
