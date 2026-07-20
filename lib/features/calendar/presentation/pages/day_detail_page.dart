import 'package:flutter/material.dart';
import 'package:liturgical_calendar/liturgical_calendar.dart';

import '../widgets/day_detail_view.dart';
import '../widgets/month_header.dart' show weekdayLabels;

/// A full-screen day detail, pushed onto the navigation stack (replacing the
/// old bottom sheet / dialog). The date sits in the app bar; the body reuses the
/// existing [DayDetailView] content.
class DayDetailPage extends StatelessWidget {
  const DayDetailPage({super.key, required this.day});

  final LiturgicalDay day;

  @override
  Widget build(BuildContext context) {
    final d = day.date;
    final weekday = weekdayLabels[d.weekday % 7];
    return Scaffold(
      appBar: AppBar(title: Text('${d.month}월 ${d.day}일 $weekday요일')),
      body: SafeArea(child: DayDetailView(day: day, embedded: true)),
    );
  }
}
