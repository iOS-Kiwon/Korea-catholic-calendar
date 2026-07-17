import 'dart:async';
import 'dart:io';

import 'package:in_app_purchase/in_app_purchase.dart';

import 'support_models.dart';

class SupportPurchaseStore {
  SupportPurchaseStore._();

  static final instance = SupportPurchaseStore._();

  final InAppPurchase _iap = InAppPurchase.instance;
  final _events = StreamController<SupportPurchaseEvent>.broadcast();
  final Map<String, ProductDetails> _products = {};
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  Stream<SupportPurchaseEvent> get events => _events.stream;

  Future<List<SupportPurchaseOption>> loadProducts() async {
    if (!_isSupportedPlatform) {
      return _disabledOptions('iOS 또는 Android 앱에서 이용할 수 있습니다.');
    }

    _ensureListening();
    final available = await _iap.isAvailable();
    if (!available) {
      return _disabledOptions('스토어 결제를 사용할 수 없습니다.');
    }

    final ids = supportCatalogItems.map((item) => item.id).toSet();
    final response = await _iap.queryProductDetails(ids);
    _products
      ..clear()
      ..addEntries(response.productDetails.map((p) => MapEntry(p.id, p)));

    final queryError = response.error?.message;
    return [
      for (final item in supportCatalogItems)
        if (_products[item.id] case final product?)
          SupportPurchaseOption(item: item, price: product.price, enabled: true)
        else
          SupportPurchaseOption(
            item: item,
            price: '상품 준비 중',
            enabled: false,
            disabledReason: queryError ?? '스토어에 상품이 아직 등록되지 않았습니다.',
          ),
    ];
  }

  Future<void> buy(String productId) async {
    if (!_isSupportedPlatform) {
      throw UnsupportedError(
        'Support purchases are only available on iOS and Android.',
      );
    }

    _ensureListening();
    var product = _products[productId];
    if (product == null) {
      final response = await _iap.queryProductDetails({productId});
      if (response.productDetails.isNotEmpty) {
        product = response.productDetails.first;
        _products[product.id] = product;
      }
    }
    if (product == null) {
      throw StateError('상품 정보를 불러오지 못했습니다.');
    }

    final started = await _iap.buyConsumable(
      purchaseParam: PurchaseParam(productDetails: product),
      autoConsume: true,
    );
    if (!started) {
      _events.add(
        const SupportPurchaseEvent(
          SupportPurchaseEventType.failed,
          '결제를 시작하지 못했습니다.',
        ),
      );
    }
  }

  bool get _isSupportedPlatform => Platform.isIOS || Platform.isAndroid;

  void _ensureListening() {
    _subscription ??= _iap.purchaseStream.listen(
      _onPurchases,
      onError: (_) => _events.add(
        const SupportPurchaseEvent(
          SupportPurchaseEventType.failed,
          '결제 상태를 확인하지 못했습니다.',
        ),
      ),
    );
  }

  Future<void> _onPurchases(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      switch (purchase.status) {
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          if (purchase.pendingCompletePurchase) {
            await _iap.completePurchase(purchase);
          }
          _events.add(
            const SupportPurchaseEvent(
              SupportPurchaseEventType.completed,
              supportThanksMessage,
            ),
          );
        case PurchaseStatus.error:
          _events.add(
            SupportPurchaseEvent(
              SupportPurchaseEventType.failed,
              purchase.error?.message ?? '결제가 완료되지 않았습니다.',
            ),
          );
        case PurchaseStatus.canceled:
          _events.add(
            const SupportPurchaseEvent(
              SupportPurchaseEventType.canceled,
              '결제가 취소되었습니다.',
            ),
          );
        case PurchaseStatus.pending:
          break;
      }
    }
  }

  List<SupportPurchaseOption> _disabledOptions(String reason) {
    return [
      for (final item in supportCatalogItems)
        SupportPurchaseOption(
          item: item,
          price: '이용 불가',
          enabled: false,
          disabledReason: reason,
        ),
    ];
  }
}
