import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liturgical_calendar/liturgical_calendar.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/theme/liturgical_colors.dart';
import '../../../events/application/event_providers.dart';
import '../../../events/model/calendar_event.dart';
import '../../../events/presentation/event_editor_sheet.dart';
import 'liturgical_color_badge.dart';
import 'month_header.dart' show weekdayLabels;

String _seasonLabel(Season s) {
  switch (s) {
    case Season.advent:
      return '대림 시기';
    case Season.christmas:
      return '성탄 시기';
    case Season.ordinaryTime:
      return '연중 시기';
    case Season.lent:
      return '사순 시기';
    case Season.paschalTriduum:
      return '파스카 성삼일';
    case Season.easter:
      return '부활 시기';
  }
}

String _rankLabel(Rank r) {
  switch (r) {
    case Rank.solemnity:
      return '대축일';
    case Rank.feastOfTheLord:
      return '주님의 축일';
    case Rank.feast:
      return '축일';
    case Rank.sunday:
      return '주일';
    case Rank.obligatoryMemorial:
      return '의무 기념일';
    case Rank.optionalMemorial:
      return '선택 기념일';
    case Rank.privilegedFeria:
      return '특전 평일';
    case Rank.feria:
      return '평일';
  }
}

String _sundayCycleLabel(SundayCycle c) => switch (c) {
  SundayCycle.a => '가해',
  SundayCycle.b => '나해',
  SundayCycle.c => '다해',
};

String _weekdayCycleLabel(WeekdayCycle c) =>
    c == WeekdayCycle.i ? '제1주기(홀수해)' : '제2주기(짝수해)';

/// Reusable content body for a single day's liturgical detail. Presentation-
/// agnostic: used in a side pane, a full-screen route and a bottom sheet.
class DayDetailView extends ConsumerWidget {
  const DayDetailView({super.key, required this.day, this.scrollController});

  final LiturgicalDay day;
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final d = day.date;
    final events = ref.watch(eventsForDateProvider(d));
    final weekday = weekdayLabels[d.weekday % 7];
    final seasonText = day.seasonWeek != null
        ? '${_seasonLabel(day.season)} 제${day.seasonWeek}주간'
        : _seasonLabel(day.season);

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          '${d.year}년 ${d.month}월 ${d.day}일 ($weekday)',
          style: theme.textTheme.titleMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        Text(day.title, style: theme.textTheme.headlineSmall),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _Chip(label: seasonText),
            _Chip(
              label: LiturgicalColors.label(day.color),
              leading: LiturgicalColorBadge(day.color),
            ),
            for (final alt in day.alternativeColors)
              _Chip(
                label: '${LiturgicalColors.label(alt)}(선택)',
                leading: LiturgicalColorBadge(alt),
              ),
            _Chip(label: _rankLabel(day.celebration.rank)),
            if (day.isHolyDayOfObligation) const _Chip(label: '의무 축일'),
            if (day.specialDay != null && day.specialDay!.isNotEmpty)
              _Chip(label: day.specialDay!),
          ],
        ),
        const Divider(height: 32),
        _MyEventsSection(date: d, events: events),
        const Divider(height: 32),
        _InfoRow(label: '주일 독서', value: _sundayCycleLabel(day.sundayCycle)),
        _InfoRow(label: '평일 독서', value: _weekdayCycleLabel(day.weekdayCycle)),
        if (day.celebration.isProperToKorea)
          const _InfoRow(label: '전례력', value: '한국 고유 전례력'),
        if (day.scriptureReadings.isNotEmpty) ...[
          const Divider(height: 32),
          Text('말씀 (구절)', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          for (final r in day.scriptureReadings)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(r, style: theme.textTheme.bodyMedium),
            ),
          if (day.sourceUrl != null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => _openSourceUrl(day.sourceUrl!),
                icon: const Icon(Icons.open_in_new, size: 18),
                label: const Text('매일미사에서 전문 보기'),
              ),
            ),
          ],
        ],
        if (day.optionalMemorials.isNotEmpty) ...[
          const Divider(height: 32),
          Text('이 날의 다른 기념', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          for (final m in day.optionalMemorials)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 5, right: 8),
                    child: LiturgicalColorBadge(m.color, size: 10),
                  ),
                  Expanded(child: Text(m.name)),
                ],
              ),
            ),
        ],
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

/// "내 일정" section inside the day detail: list + add/edit/delete.
class _MyEventsSection extends ConsumerWidget {
  const _MyEventsSection({required this.date, required this.events});

  final DateTime date;
  final List<CalendarEvent> events;

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    CalendarEvent event,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('일정 삭제'),
        content: Text("'${event.title}' 일정을 삭제할까요?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(eventStoreProvider.notifier).delete(event);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('내 일정', style: theme.textTheme.titleSmall),
            const Spacer(),
            TextButton.icon(
              onPressed: () => showEventEditor(context, date: date),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('추가'),
            ),
          ],
        ),
        if (events.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              '등록된 일정이 없습니다.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          )
        else
          for (final e in events)
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: Icon(
                e.notify
                    ? Icons.notifications_active_outlined
                    : Icons.event_note_outlined,
                color: Color(e.categoryColor),
              ),
              title: Text(e.title),
              subtitle: Text(
                [
                  e.isAllDay ? '종일' : e.time!,
                  if (e.memo != null && e.memo!.isNotEmpty) e.memo!,
                ].join(' · '),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: '삭제',
                onPressed: () => _confirmDelete(context, ref, e),
              ),
              onTap: () =>
                  showEventEditor(context, date: date, existing: e),
            ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, this.leading});
  final String label;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: leading,
      label: Text(label),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(child: Text(value, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}
