import 'package:flutter/material.dart';

import '../../../../core/date/year_month.dart';

/// 연/월 선택 팝업. 선택하면 [YearMonth]를 반환, 취소하면 null.
Future<YearMonth?> showMonthYearPicker(
  BuildContext context,
  YearMonth initial,
) {
  return showDialog<YearMonth>(
    context: context,
    builder: (_) => _MonthYearPicker(initial: initial),
  );
}

class _MonthYearPicker extends StatefulWidget {
  const _MonthYearPicker({required this.initial});
  final YearMonth initial;

  @override
  State<_MonthYearPicker> createState() => _MonthYearPickerState();
}

class _MonthYearPickerState extends State<_MonthYearPicker> {
  late int _year = widget.initial.year;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      title: const Text('연/월 선택'),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 연도 스테퍼: ‹ 2026 ›
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: () => setState(() => _year--),
                  icon: const Icon(Icons.chevron_left),
                  tooltip: '이전 해',
                ),
                SizedBox(
                  width: 96,
                  child: Text(
                    '$_year년',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  onPressed: () => setState(() => _year++),
                  icon: const Icon(Icons.chevron_right),
                  tooltip: '다음 해',
                ),
              ],
            ),
            const SizedBox(height: 8),
            // 월 그리드 (3 x 4)
            GridView.count(
              crossAxisCount: 4,
              shrinkWrap: true,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1.6,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                for (var m = 1; m <= 12; m++)
                  _MonthChip(
                    month: m,
                    selected:
                        _year == widget.initial.year &&
                        m == widget.initial.month,
                    onTap: () => Navigator.of(context).pop(YearMonth(_year, m)),
                  ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
      ],
    );
  }
}

class _MonthChip extends StatelessWidget {
  const _MonthChip({
    required this.month,
    required this.selected,
    required this.onTap,
  });
  final int month;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: selected
          ? theme.colorScheme.primaryContainer
          : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Center(
          child: Text(
            '$month월',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: selected ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
