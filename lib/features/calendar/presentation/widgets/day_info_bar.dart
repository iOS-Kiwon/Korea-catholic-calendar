import 'package:flutter/material.dart';
import 'package:liturgical_calendar/liturgical_calendar.dart';

import '../../../../app/theme/liturgical_colors.dart';

const _weekdayFull = ['일', '월', '화', '수', '목', '금', '토'];
const _maxMemorialRows = 3;

/// 달력 하단 고정 정보영역: 얇은 구분선 + 날짜 + 최대 3개의 기념/전례명.
class DayInfoBar extends StatelessWidget {
  const DayInfoBar({super.key, required this.day, required this.onTapDetail});

  final LiturgicalDay day;
  final VoidCallback onTapDetail; // 축일 영역 탭 → 상세

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final d = day.date;
    final weekday = _weekdayFull[d.weekday % 7];
    final memorials = [
      _MemorialLine(title: day.title, color: day.color),
      for (final m in day.optionalMemorials)
        _MemorialLine(title: m.name, color: m.color),
    ].take(_maxMemorialRows).toList();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Divider(
          height: 1,
          thickness: 1,
          color: theme.dividerColor.withValues(alpha: 0.4),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${d.month}월 ${d.day}일 $weekday요일',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: const Color(0xFF121212),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: onTapDetail,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var i = 0; i < _maxMemorialRows; i++)
                        _MemorialRow(
                          line: i < memorials.length ? memorials[i] : null,
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MemorialLine {
  const _MemorialLine({required this.title, required this.color});

  final String title;
  final LiturgicalColor color;
}

class _MemorialRow extends StatelessWidget {
  const _MemorialRow({required this.line});

  final _MemorialLine? line;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      height: 26,
      child: line == null
          ? const SizedBox.shrink()
          : Row(
              children: [
                Container(
                  width: 11,
                  height: 11,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: context.liturgical.of(line!.color),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    line!.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyLarge,
                  ),
                ),
              ],
            ),
    );
  }
}
