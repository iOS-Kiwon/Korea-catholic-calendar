import 'package:flutter/material.dart';
import 'package:liturgical_calendar/liturgical_calendar.dart';

import '../../../../app/theme/liturgical_colors.dart';

const _weekdayFull = ['일', '월', '화', '수', '목', '금', '토'];

/// Compact liturgical-color summary card shown under the phone calendar.
/// Tapping it opens the full detail (a bottom sheet).
class DaySummaryCard extends StatelessWidget {
  const DaySummaryCard({
    super.key,
    required this.day,
    required this.isToday,
    required this.onTap,
  });

  final LiturgicalDay day;
  final bool isToday;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = context.liturgical.of(day.color);
    final on = bg.computeLuminance() > 0.55 ? Colors.black87 : Colors.white;
    final d = day.date;
    final weekday = _weekdayFull[d.weekday % 7];

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${isToday ? '오늘' : '선택'} · ${LiturgicalColors.label(day.color)}',
                style: TextStyle(
                  color: on.withValues(alpha: 0.85),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${d.year}년 ${d.month}월 ${d.day}일 $weekday요일',
                style: TextStyle(
                  color: on,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                day.title,
                style: TextStyle(
                  color: on.withValues(alpha: 0.9),
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
