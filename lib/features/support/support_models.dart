const supportDisclosure =
    '이 결제는 앱을 응원하는 선택적 1회성 결제이며, 결제 후 앱 기능, 콘텐츠, 보상은 제공되지 않습니다. '
    '운영자는 운영비를 제외한 수익금 전부를 올마이키즈에 전달할 예정입니다.';

const supportThanksMessage = '따뜻한 마음에 감사합니다. 아이들의 내일을 위해 소중히 전달하겠습니다.';

const supportCatalogItems = [
  SupportCatalogItem(
    id: 'kcc.support.small_kindness',
    title: '작은 나눔 한 잔',
    description: '앱을 응원하는 1회성 감사 결제입니다.',
  ),
  SupportCatalogItem(
    id: 'kcc.support.learning',
    title: '아이들의 배움 응원',
    description: '운영과 나눔 활동을 함께 응원합니다.',
  ),
  SupportCatalogItem(
    id: 'kcc.support.tomorrow',
    title: '내일을 밝히는 마음',
    description: '더 큰 마음으로 아이들의 내일을 응원합니다.',
  ),
];

class SupportCatalogItem {
  const SupportCatalogItem({
    required this.id,
    required this.title,
    required this.description,
  });

  final String id;
  final String title;
  final String description;
}

class SupportPurchaseOption {
  const SupportPurchaseOption({
    required this.item,
    required this.price,
    required this.enabled,
    this.disabledReason,
  });

  final SupportCatalogItem item;
  final String price;
  final bool enabled;
  final String? disabledReason;
}

enum SupportPurchaseEventType { completed, canceled, failed }

class SupportPurchaseEvent {
  const SupportPurchaseEvent(this.type, this.message);

  final SupportPurchaseEventType type;
  final String message;
}
