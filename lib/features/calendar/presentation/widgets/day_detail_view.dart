import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liturgical_calendar/liturgical_calendar.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/theme/liturgical_colors.dart';
import '../../../app_metadata/app_metadata_service.dart';
import '../../../events/application/event_providers.dart';
import '../../../events/model/calendar_event.dart';
import '../../../events/presentation/event_editor_sheet.dart';
import '../../../saints/presentation/saint_feast_editor_page.dart';
import '../../../support/presentation/support_sheet.dart';

/// 독서 마커(①/②/㉥ …) → 사람이 읽는 라벨.
const _readingLabels = {
  '①': '제1독서',
  '②': '제2독서',
  '③': '제3독서',
  '④': '제4독서',
  '⑤': '제5독서',
  '⑥': '제6독서',
  '⑦': '제7독서',
  '⑧': '제8독서',
  '㉥': '복음',
};

/// 원문 독서 문자열을 (라벨, 구절)로 분리. 라벨 마커가 없으면 라벨은 빈 문자열.
({String label, String reference}) _parseReading(String raw) {
  final space = raw.indexOf(' ');
  if (space > 0) {
    final marker = raw.substring(0, space);
    final label = _readingLabels[marker];
    if (label != null) {
      return (label: label, reference: raw.substring(space + 1).trim());
    }
  }
  return (label: '', reference: raw);
}

/// 하루의 전례 정보 상세: 전례력 · 내 일정 · 말씀을 한 장의 카드에 담고,
/// 그 아래 나눔 배너를 둔다. (날짜/시기는 상위 [DayDetailPage]의 앱바에 표시)
class DayDetailView extends ConsumerWidget {
  const DayDetailView({super.key, required this.day});

  final LiturgicalDay day;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final events = ref.watch(eventsForDateProvider(day.date));
    final metadata =
        ref.watch(appMetadataProvider).value ?? AppMetadata.fallback;
    final hasSaintFeast = events.any((event) => event.isSaintFeast);
    final readings = day.scriptureReadings;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      children: [
        Card(
          elevation: 0.5,
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          color: theme.colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // 전례력
                _SectionHeader('전례력'),
                const SizedBox(height: 12),
                _DotLine(
                  color: context.liturgical.of(day.color),
                  text: day.title,
                ),
                for (final m in day.optionalMemorials) ...[
                  const SizedBox(height: 10),
                  _DotLine(color: context.liturgical.of(m.color), text: m.name),
                ],

                // 일정 (추가는 유지 - 기존 기능)
                const _SectionDivider(),
                Row(
                  children: [
                    Expanded(child: _SectionHeader('일정')),
                    TextButton.icon(
                      onPressed: () => showEventEditor(context, date: day.date),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('추가'),
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                if (events.isEmpty)
                  Text(
                    '등록된 일정이 없습니다.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  )
                else
                  for (var i = 0; i < events.length; i++) ...[
                    if (i > 0) const SizedBox(height: 10),
                    _EventLine(event: events[i]),
                  ],

                // 말씀
                if (readings.isNotEmpty) ...[
                  const _SectionDivider(),
                  _SectionHeader('말씀'),
                  const SizedBox(height: 12),
                  for (final r in readings) ...[
                    _ReadingLine(raw: r),
                    const SizedBox(height: 6),
                  ],
                  if (day.sourceUrl != null)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => _openSourceUrl(day.sourceUrl!),
                        icon: const Icon(Icons.open_in_new, size: 16),
                        label: const Text('매일미사에서 전문 보기'),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (hasSaintFeast)
          _SupportBanner(
            icon: const Text('🎁', style: TextStyle(fontSize: 22)),
            title: '오늘은 특별한 축일이에요',
            subtitle: '축하 메시지와 작은 선물로 마음을 전해보세요',
            onTap: () => _openExternalUrl(metadata.feastGiftShopUrl),
          )
        else
          _SupportBanner(
            icon: Icon(
              Icons.favorite,
              color: theme.colorScheme.primary,
              size: 22,
            ),
            title: '오늘의 기쁨을 나눠요',
            subtitle: '하느님의 말씀을 전하는 데 함께해주세요',
            onTap: () => showSupportSheet(context),
          ),
      ],
    );
  }
}

Future<void> _openSourceUrl(String url) async {
  final uri = Uri.parse(url);
  final openedInApp = await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
  if (!openedInApp) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

Future<void> _openExternalUrl(String url) async {
  final uri = Uri.parse(url);
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      title,
      style: theme.textTheme.titleSmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _SectionDivider extends StatelessWidget {
  const _SectionDivider();

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 32,
      color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
    );
  }
}

/// 색점 + 이름 (전례력 행).
class _DotLine extends StatelessWidget {
  const _DotLine({required this.color, required this.text});
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Container(
            width: 11,
            height: 11,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(text, style: theme.textTheme.bodyLarge)),
      ],
    );
  }
}

/// 일정 한 줄(색점 + 시간 + 제목). 누르면 편집 화면으로 이동.
class _EventLine extends StatelessWidget {
  const _EventLine({required this.event});
  final CalendarEvent event;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final timeLabel = event.isAllDay ? '종일' : event.time!;
    final isSaintFeast = event.isSaintFeast;
    final memo = event.memo?.trim();
    final title = isSaintFeast
        ? [
            event.saintName?.trim().isNotEmpty == true
                ? event.saintName!.trim()
                : event.title,
            if (memo != null && memo.isNotEmpty) memo,
          ].join(' ')
        : event.title;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () {
        final date = parseEventDate(event.date);
        if (event.isSaintFeast) {
          showSaintFeastEditor(context, date: date, existing: event);
        } else {
          showEventEditor(context, date: date, existing: event);
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.only(top: isSaintFeast ? 1 : 5),
              child: isSaintFeast
                  ? const Text(
                      kSaintFeastPrefix,
                      style: TextStyle(fontSize: 14),
                    )
                  : Container(
                      width: 11,
                      height: 11,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(event.categoryColor),
                      ),
                    ),
            ),
            const SizedBox(width: 12),
            if (!isSaintFeast) ...[
              Text(
                timeLabel,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyLarge,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 말씀 한 줄(라벨 | 구절).
class _ReadingLine extends StatelessWidget {
  const _ReadingLine({required this.raw});
  final String raw;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final parsed = _parseReading(raw);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 60,
            child: Text(
              parsed.label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Container(
            width: 1,
            height: 16,
            color: theme.dividerColor.withValues(alpha: 0.6),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(parsed.reference, style: theme.textTheme.bodyLarge),
          ),
        ],
      ),
    );
  }
}

/// 나눔(응원) 배너 - 카드 아래에 연한 녹색으로 표시.
class _SupportBanner extends StatelessWidget {
  const _SupportBanner({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final Widget icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    return Material(
      color: accent.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              icon,
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: accent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: accent.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: accent),
            ],
          ),
        ),
      ),
    );
  }
}
