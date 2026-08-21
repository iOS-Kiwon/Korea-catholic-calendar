import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liturgical_calendar/liturgical_calendar.dart';

import '../../../events/application/event_providers.dart';
import '../../../events/model/calendar_event.dart';
import '../../../events/presentation/event_display.dart';

const _weekdayFull = ['일', '월', '화', '수', '목', '금', '토'];
const _maxMemorialRows = 3;
const _footerBodyLineHeight = 24.0;
const _footerSmallLineHeight = 20.0;

TextStyle _fixedLineHeight(TextStyle? style, double lineHeight) {
  final base = style ?? const TextStyle(fontSize: 16);
  final fontSize = base.fontSize ?? 16;
  return base.copyWith(height: lineHeight / fontSize);
}

/// 달력 하단 정보 카드: 날짜(+상세 이동 셰브런) · 기념/전례명 · 그날의 내 일정 요약,
/// 그리고 (해당하는 날) 나눔 배너. 카드 영역을 누르면 상세 화면으로 이동한다.
class DayInfoBar extends ConsumerWidget {
  const DayInfoBar({
    super.key,
    required this.day,
    required this.onTapDetail,
    this.onSupportTap,
  });

  final LiturgicalDay day;
  final VoidCallback onTapDetail; // 카드 상단(날짜/기념/일정) 탭 → 상세
  final VoidCallback? onSupportTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final d = day.date;
    final weekday = _weekdayFull[d.weekday % 7];
    final titleStyle = _fixedLineHeight(
      theme.textTheme.titleMedium,
      _footerBodyLineHeight,
    ).copyWith(color: const Color(0xFF121212), fontWeight: FontWeight.w700);
    final bodyStyle = _fixedLineHeight(
      theme.textTheme.bodyLarge,
      _footerBodyLineHeight,
    );
    final events = ref.watch(eventsForDateProvider(d));
    final showSupportInvite =
        onSupportTap != null &&
        (day.celebration.rank == Rank.solemnity ||
            day.celebration.rank == Rank.feastOfTheLord);
    final memorials = [
      _MemorialLine(title: day.title, color: day.color),
      for (final m in day.optionalMemorials)
        _MemorialLine(title: m.name, color: m.color),
    ].take(_maxMemorialRows).toList();

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 날짜 + 기념/전례명 + 일정 요약 (탭하면 상세)
            InkWell(
              onTap: onTapDetail,
              borderRadius: BorderRadius.circular(12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${d.month}월 ${d.day}일 $weekday요일',
                          style: titleStyle,
                        ),
                      ),
                      Icon(
                        Icons.chevron_right,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  for (final line in memorials)
                    _MemorialRow(line: line, style: bodyStyle),
                  if (events.isNotEmpty)
                    _EventSummary(events: events, style: bodyStyle),
                ],
              ),
            ),
            if (showSupportInvite) ...[
              const SizedBox(height: 14),
              _SupportBanner(onTap: onSupportTap!),
            ],
          ],
        ),
      ),
    );
  }
}

/// The day's personal events, summarized under the liturgical names.
/// Shows the first event as time/category/memo in one line, then a count when
/// there are more.
class _EventSummary extends StatelessWidget {
  const _EventSummary({required this.events, required this.style});

  final List<CalendarEvent> events;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final first = events.first;
    final extra = events.length - 1;
    final memo = first.memo?.trim();
    final feastSummary = first.isSaintFeast
        ? [
            first.saintName?.trim().isNotEmpty == true
                ? first.saintName!.trim()
                : first.title,
            if (memo != null && memo.isNotEmpty) memo,
          ].join(' ')
        : null;

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              if (first.isSaintFeast) ...[
                EventLabelHighlight(
                  label: kSaintFeastPrefix,
                  color: const Color(kSaintFeastEventColor),
                  style: style,
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: first.isSaintFeast
                    ? Text(
                        feastSummary!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: style,
                      )
                    : RegularEventDisplayLine(
                        event: first,
                        style: style,
                        showAllDayLabel: false,
                      ),
              ),
            ],
          ),
          if (extra > 0)
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 18),
              child: Text(
                '외 $extra개 일정이 있어요.',
                style: _fixedLineHeight(
                  theme.textTheme.bodySmall,
                  _footerSmallLineHeight,
                ).copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
        ],
      ),
    );
  }
}

/// 나눔(응원) 배너. 연한 녹색 배경 + 하트 + 셰브런.
class _SupportBanner extends StatelessWidget {
  const _SupportBanner({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    return Material(
      color: accent.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Icon(Icons.favorite, color: accent, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '오늘의 기쁨을 나눠요',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _fixedLineHeight(
                    theme.textTheme.titleSmall,
                    _footerSmallLineHeight,
                  ).copyWith(color: accent, fontWeight: FontWeight.w700),
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

class _MemorialLine {
  const _MemorialLine({required this.title, required this.color});

  final String title;
  final LiturgicalColor color;
}

/// 기념/전례 한 줄: 전례색 배지 + 이름.
///
/// 배지는 종류(`축일`/`전례`)가 아니라 **전례색**을 보여준다. 색은 그 자체로
/// 정보이기 때문이다 - 홍색은 순교자·사도, 백색은 그 외 성인이며, 선택 기념일은
/// 기념하기로 하면 제의색이 그날 기본색과 달라진다(예: 연중 수요일 녹색 +
/// 성 요한 외드 사제 백색). 종류를 글자로 쓰고 색을 배경 틴트로만 깔던 이전
/// 방식은 백색(`#F8F9FA`)을 24% 알파로 흰 카드에 얹어 배경이 보이지 않았고,
/// 인접한 두 행이 같은 개념을 다르게 인코딩했다.
class _MemorialRow extends StatelessWidget {
  const _MemorialRow({required this.line, required this.style});

  final _MemorialLine line;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          LiturgicalColorLabel(color: line.color, style: style),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              line.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: style,
            ),
          ),
        ],
      ),
    );
  }
}
