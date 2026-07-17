import 'dart:async';

import 'support_models.dart';

class SupportPurchaseStore {
  SupportPurchaseStore._();

  static final instance = SupportPurchaseStore._();

  Stream<SupportPurchaseEvent> get events => const Stream.empty();

  Future<List<SupportPurchaseOption>> loadProducts() async {
    return [
      for (final item in supportCatalogItems)
        SupportPurchaseOption(
          item: item,
          price: '모바일 앱 전용',
          enabled: false,
          disabledReason: 'iOS 또는 Android 앱에서 이용할 수 있습니다.',
        ),
    ];
  }

  Future<void> buy(String productId) async {
    throw UnsupportedError(
      'Support purchases are only available on iOS and Android.',
    );
  }
}
