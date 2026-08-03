import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../events/model/calendar_event.dart';
import 'event_sharer.dart';
import 'share_link.dart';

/// 개인 일정 공유 아이콘 버튼. 탭하면 OS 공유 시트를 연다.
class EventShareButton extends ConsumerWidget {
  const EventShareButton({super.key, required this.event});
  final CalendarEvent event;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      icon: const Icon(Icons.ios_share, size: 20),
      tooltip: '공유',
      visualDensity: VisualDensity.compact,
      onPressed: () => ref.read(eventSharerProvider).share(buildShareText(event)),
    );
  }
}
