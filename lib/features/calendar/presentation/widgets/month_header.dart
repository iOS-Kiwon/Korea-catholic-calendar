import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/date/year_month.dart';

const weekdayLabels = ['주일', '월', '화', '수', '목', '금', '토'];

/// 전례색 헤더: 좌측 이전 달(‹), 중앙 월 제목(항상 화면 정중앙), 우측 [오늘 · 다음 달(›)].
/// [showToday]가 참일 때만 `오늘` 버튼을 노출한다(오늘이 아닌 날을 보고 있을 때).
/// [compact](폰)일 때는 초록 배경이 상태바 영역까지 채워지고 상태바 아이콘을
/// 배경 밝기에 맞춰 흰색/검정으로 맞춘다. 월 제목을 누르면 [onTapTitle]이 호출된다.
class MonthHeader extends StatelessWidget {
  const MonthHeader({
    super.key,
    required this.month,
    required this.color,
    required this.compact,
    required this.onPrevMonth,
    required this.onNextMonth,
    required this.onTapTitle,
    required this.onToday,
    required this.showToday,
  });

  final YearMonth month;
  final Color color;
  final bool compact;
  final VoidCallback onPrevMonth;
  final VoidCallback onNextMonth;
  final VoidCallback onTapTitle;
  final VoidCallback onToday;
  final bool showToday;

  @override
  Widget build(BuildContext context) {
    final onColor = _readableOn(color);
    final t = Theme.of(context).textTheme;
    final titleStyle = compact ? t.titleLarge : t.headlineSmall;

    final header = Container(
      color: color,
      // compact(폰): 초록이 상태바 뒤까지 깔리도록 top 인셋을 헤더 안에서 처리.
      child: SafeArea(
        top: compact,
        bottom: false,
        child: Padding(
          padding: compact
              ? const EdgeInsets.fromLTRB(8, 8, 8, 10)
              : const EdgeInsets.fromLTRB(16, 12, 16, 12),
          // 타이틀은 화면 정중앙에 고정. 좌측 이전 버튼, 우측 [오늘 · 다음]
          // 버튼이 있어도 밀리지 않도록 Stack으로 배치한다.
          child: SizedBox(
            height: 44,
            child: Stack(
              children: [
                Align(
                  alignment: Alignment.center,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: onTapTitle,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
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
                Align(
                  alignment: Alignment.centerLeft,
                  child: _chevron('‹', onColor, onPrevMonth, '이전 달'),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (showToday) ...[
                        _todayPill(onColor, onToday),
                        const SizedBox(width: 6),
                      ],
                      _chevron('›', onColor, onNextMonth, '다음 달'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (!compact) return header;
    // 초록(어두운) 배경이면 상태바 아이콘을 밝게, 밝은 배경이면 어둡게.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: onColor == Colors.white
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
      child: header,
    );
  }

  /// `오늘` 캡슐 버튼(헤더 전례색 배경 위). 누르면 오늘로 이동.
  Widget _todayPill(Color onColor, VoidCallback onTap) {
    return Tooltip(
      message: '오늘',
      child: Material(
        color: onColor.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 40),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            alignment: Alignment.center,
            child: Text(
              '오늘',
              style: TextStyle(
                color: onColor,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _chevron(String label, Color onColor, VoidCallback onTap, String tip) {
    return Tooltip(
      message: tip,
      child: Material(
        color: onColor.withValues(alpha: 0.18),
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
