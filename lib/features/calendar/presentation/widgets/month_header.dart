import 'package:flutter/material.dart';

import '../../../../core/date/year_month.dart';

const weekdayLabels = ['주일', '월', '화', '수', '목', '금', '토'];

/// 전례색 헤더: `‹ 2026년 7월 ›` (양옆 이전/다음 달) + 시기·색 부제.
/// 월 제목을 누르면 [onTapTitle](연/월 선택 팝업)이 호출된다.
class MonthHeader extends StatelessWidget {
  const MonthHeader({
    super.key,
    required this.month,
    required this.seasonText,
    required this.color,
    required this.compact,
    required this.onPrevMonth,
    required this.onNextMonth,
    required this.onTapTitle,
  });

  final YearMonth month;
  final String seasonText;
  final Color color;
  final bool compact;
  final VoidCallback onPrevMonth;
  final VoidCallback onNextMonth;
  final VoidCallback onTapTitle;

  @override
  Widget build(BuildContext context) {
    final onColor = _readableOn(color);
    final t = Theme.of(context).textTheme;
    final titleStyle = compact ? t.titleLarge : t.headlineSmall;
    return Container(
      color: color,
      padding: compact
          ? const EdgeInsets.fromLTRB(8, 10, 8, 12)
          : const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              _chevron('‹', onColor, onPrevMonth, '이전 달'),
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: onTapTitle,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      '${month.year}년 ${month.month}월',
                      textAlign: TextAlign.center,
                      style: titleStyle?.copyWith(
                        color: onColor,
                        fontSize: (titleStyle.fontSize ?? 24) + 1,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              _chevron('›', onColor, onNextMonth, '다음 달'),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            seasonText,
            style: t.labelMedium?.copyWith(
              color: onColor.withValues(alpha: 0.85),
              fontSize: (t.labelMedium?.fontSize ?? 12) + 2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _chevron(String label, Color onColor, VoidCallback onTap, String tip) {
    return Tooltip(
      message: tip,
      child: Material(
        color: onColor.withValues(alpha: 0.10), // 더 연한 버튼 배경
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            alignment: Alignment.center,
            child: Text(
              label,
              style: TextStyle(
                color: onColor,
                fontWeight: FontWeight.w600,
                fontSize: 20,
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
                style: theme.textTheme.titleSmall?.copyWith(
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
