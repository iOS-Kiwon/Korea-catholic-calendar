import 'package:flutter/material.dart';
import 'package:liturgical_calendar/liturgical_calendar.dart';

import '../widgets/day_detail_view.dart';
import '../widgets/month_header.dart' show weekdayLabels;

/// A full-screen day detail, pushed onto the navigation stack. The date and
/// liturgical title sit in the app bar; the body ([DayDetailView]) shows the
/// 전례력 / 일정 / 말씀 card and the support banner.
class DayDetailPage extends StatelessWidget {
  const DayDetailPage({super.key, required this.day});

  final LiturgicalDay day;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final d = day.date;
    final weekday = weekdayLabels[d.weekday % 7];
    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${d.month}월 ${d.day}일 $weekday요일',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              day.title,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(top: false, child: DayDetailView(day: day)),
    );
  }
}
