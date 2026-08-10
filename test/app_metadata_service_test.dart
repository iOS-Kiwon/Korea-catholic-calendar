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

  test('review.enabled가 false면 리뷰 요청을 끈다', () {
    final metadata = AppMetadata.fromJson({
      'review': {'enabled': false},
    });

    expect(metadata.reviewPromptEnabled, isFalse);
  });

  test('review 필드가 없으면 리뷰 요청은 켜짐', () {
    final metadata = AppMetadata.fromJson({
      'giftShop': {'url': 'https://example.com/gifts'},
    });

    expect(metadata.reviewPromptEnabled, isTrue);
  });

  test('review.enabled 타입이 잘못되면 켜짐으로 본다', () {
    final metadata = AppMetadata.fromJson({
      'review': {'enabled': 'nope'},
    });

    expect(metadata.reviewPromptEnabled, isTrue);
  });

  test('fallback은 리뷰 요청이 켜져 있다', () {
    expect(AppMetadata.fallback.reviewPromptEnabled, isTrue);
  });
}
