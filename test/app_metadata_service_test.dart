import 'package:catholic_calendar/features/app_metadata/app_metadata_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses feast gift shop URL from metadata', () {
    final metadata = AppMetadata.fromJson({
      'giftShop': {'url': 'https://example.com/gifts'},
    });

    expect(metadata.feastGiftShopUrl, 'https://example.com/gifts');
  });

  test('falls back when gift shop URL is invalid', () {
    final metadata = AppMetadata.fromJson({
      'giftShop': {'url': 'javascript:alert(1)'},
    });

    expect(metadata.feastGiftShopUrl, kDefaultFeastGiftShopUrl);
  });
}
