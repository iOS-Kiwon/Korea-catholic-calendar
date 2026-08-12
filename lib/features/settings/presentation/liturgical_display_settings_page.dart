import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../calendar/application/calendar_providers.dart';
import '../../calendar/application/liturgical_display_filter.dart';
import '../../calendar/data/calendar_service.dart';
import '../../calendar/presentation/widgets/day_cell.dart';

/// 전례일 표시 방식 선택 + 미리보기.
class LiturgicalDisplaySettingsPage extends ConsumerWidget {
  const LiturgicalDisplaySettingsPage({super.key});

  // 미리보기용 대표 날짜(2026): 평범한 주일 / 대축일 / 성인 축일 / 성인 기념일 / 평일.
  static final _sampleDates = <DateTime>[
    DateTime(2026, 7, 26), // 연중 제17주일
    DateTime(2026, 8, 15), // 성모 승천 대축일
    DateTime(2026, 7, 25), // 성 야고보 사도 축일
    DateTime(2026, 7, 31), // 성 이냐시오 데 로욜라 기념일
    DateTime(2026, 7, 28), // 연중 평일
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(liturgicalDisplayFilterProvider);
    final calendar = ref.watch(calendarControllerProvider).value;

    return Scaffold(
      appBar: AppBar(title: const Text('전례일 표시'), centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          const _SectionLabel('미리보기'),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              child: calendar == null
                  ? const SizedBox(
                      height: 64,
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : _PreviewRow(calendar: calendar, filter: selected),
            ),
          ),
          const SizedBox(height: 16),
          const _SectionLabel('표시 방식'),
          Card(
            child: RadioGroup<LiturgicalDisplayFilter>(
              groupValue: selected,
              onChanged: (v) {
                if (v != null) {
                  ref.read(liturgicalDisplayFilterProvider.notifier).set(v);
                }
              },
              child: Column(
                children: [
                  for (final f in LiturgicalDisplayFilter.values)
                    RadioListTile<LiturgicalDisplayFilter>(
                      value: f,
                      title: Text(f.displayName),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewRow extends StatelessWidget {
  const _PreviewRow({required this.calendar, required this.filter});
  final CalendarService calendar;
  final LiturgicalDisplayFilter filter;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final date in LiturgicalDisplaySettingsPage._sampleDates)
          Expanded(
            child: _PreviewCell(calendar: calendar, filter: filter, date: date),
          ),
      ],
    );
  }
}

class _PreviewCell extends StatelessWidget {
  const _PreviewCell({
    required this.calendar,
    required this.filter,
    required this.date,
  });
  final CalendarService calendar;
  final LiturgicalDisplayFilter filter;
  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final day = calendar.day(date);
    final label = gridLiturgicalLabel(filter, calendar.shortTitleFor(day), day);
    return SizedBox(
      height: 72,
      child: CompactDayCell(
        day: day,
        inCurrentMonth: true,
        isToday: false,
        isSelected: false,
        shortTitle: label,
        hasEvent: false,
        titleMaxLines: 3,
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
