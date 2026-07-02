import 'package:flutter/material.dart';

import '../../../../core/date/year_month.dart';

const weekdayLabels = ['주일', '월', '화', '수', '목', '금', '토'];

/// Liturgical-color month header: season/color label + big month title + nav.
/// Adapts between a wide (title left, nav right) and compact (centered) layout.
class MonthHeader extends StatelessWidget {
  const MonthHeader({
    super.key,
    required this.month,
    required this.seasonText,
    required this.color,
    required this.compact,
    required this.onPrevMonth,
    required this.onNextMonth,
    required this.onPrevYear,
    required this.onNextYear,
    required this.onToday,
  });

  final YearMonth month;
  final String seasonText;
  final Color color;
  final bool compact;
  final VoidCallback onPrevMonth;
  final VoidCallback onNextMonth;
  final VoidCallback onPrevYear;
  final VoidCallback onNextYear;
  final VoidCallback onToday;

  @override
  Widget build(BuildContext context) {
    final onColor = _readableOn(color);
    return Container(
      color: color,
      padding: EdgeInsets.fromLTRB(
        compact ? 12 : 28,
        compact ? 12 : 24,
        compact ? 12 : 28,
        compact ? 14 : 24,
      ),
      child: compact ? _compact(context, onColor) : _wide(context, onColor),
    );
  }

  Widget _wide(BuildContext context, Color onColor) {
    final t = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                seasonText,
                style: t.titleSmall?.copyWith(
                  color: onColor.withValues(alpha: 0.85),
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${month.year}년 ${month.month}월',
                style: t.headlineMedium?.copyWith(
                  color: onColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        _navButton('«', onColor, onPrevYear, '이전 해'),
        _navButton('‹', onColor, onPrevMonth, '이전 달'),
        _navButton('오늘', onColor, onToday, '오늘', wide: true),
        _navButton('›', onColor, onNextMonth, '다음 달'),
        _navButton('»', onColor, onNextYear, '다음 해'),
      ],
    );
  }

  Widget _compact(BuildContext context, Color onColor) {
    final t = Theme.of(context).textTheme;
    return Row(
      children: [
        _navButton('«', onColor, onPrevYear, '이전 해'),
        _navButton('‹', onColor, onPrevMonth, '이전 달'),
        Expanded(
          child: Column(
            children: [
              Text(
                '${month.year}년 ${month.month}월',
                style: t.titleLarge?.copyWith(
                  color: onColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                seasonText,
                style: t.labelMedium?.copyWith(
                  color: onColor.withValues(alpha: 0.85),
                ),
              ),
            ],
          ),
        ),
        _navButton('›', onColor, onNextMonth, '다음 달'),
        _navButton('»', onColor, onNextYear, '다음 해'),
      ],
    );
  }

  Widget _navButton(
    String label,
    Color onColor,
    VoidCallback onTap,
    String tip, {
    bool wide = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Tooltip(
        message: tip,
        child: Material(
          color: onColor.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: onTap,
            child: Container(
              constraints: BoxConstraints(
                minWidth: wide ? 52 : 38,
                minHeight: 38,
              ),
              alignment: Alignment.center,
              padding: EdgeInsets.symmetric(horizontal: wide ? 12 : 0),
              child: Text(
                label,
                style: TextStyle(
                  color: onColor,
                  fontWeight: FontWeight.w600,
                  fontSize: wide ? 14 : 18,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The weekday header row (주일 … 토), Sunday red and Saturday blue.
class WeekdayRow extends StatelessWidget {
  const WeekdayRow({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          for (var i = 0; i < 7; i++)
            Expanded(
              child: Text(
                weekdayLabels[i],
                textAlign: TextAlign.center,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: i == 0
                      ? const Color(0xFFC62828)
                      : i == 6
                      ? const Color(0xFF1565C0)
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Chooses black/white text for legibility on [background].
Color _readableOn(Color background) =>
    background.computeLuminance() > 0.55 ? Colors.black87 : Colors.white;
