import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/date/year_month.dart';
import '../../application/calendar_providers.dart';
import '../widgets/day_detail_view.dart';
import 'calendar_page.dart';

/// Full-screen day detail (used on compact/phone layouts).
class DayDetailPage extends ConsumerWidget {
  const DayDetailPage({super.key, required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final calendarAsync = ref.watch(liturgicalCalendarProvider);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(monthPath(YearMonth.of(date))),
        ),
        title: Text('${date.month}월 ${date.day}일'),
      ),
      body: calendarAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('전례력을 불러오지 못했습니다.\n$e')),
        data: (calendar) => DayDetailView(day: calendar.day(date)),
      ),
    );
  }
}
