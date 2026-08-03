import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

/// 공유 시트 호출 seam(테스트에서 교체 가능).
abstract class EventSharer {
  Future<void> share(String text);
}

class DefaultEventSharer implements EventSharer {
  const DefaultEventSharer();
  @override
  Future<void> share(String text) => SharePlus.instance.share(ShareParams(text: text));
}

final eventSharerProvider = Provider<EventSharer>((ref) => const DefaultEventSharer());
