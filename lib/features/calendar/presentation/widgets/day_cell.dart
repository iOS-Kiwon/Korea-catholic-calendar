import 'package:flutter/material.dart';
import 'package:liturgical_calendar/liturgical_calendar.dart';

import '../../../../app/theme/liturgical_colors.dart';
import '../calendar_label_metrics.dart';
import '../season_style.dart';

const _todayFill = Color(0xFF121212); // 오늘: 검정 원
const _selectedFill = Color(0xFFD6D6D6); // 선택: 회색 원

/// 와이드 셀(아이패드·맥·웹)에서 선택한 날의 셀 배경.
///
/// 큰 화면에서는 셀이 넓어 날짜 숫자 뒤의 회색 원만으로는 선택한 날이 눈에 들어오지
/// 않는다. 그래서 셀 전체를 페이지 배경보다 한 톤 어둡게 칠한다. 폰 셀은 셀이 작아
/// 원만으로 충분하므로 이 값을 쓰지 않는다.
Color _selectedCellFill(ThemeData theme) =>
    Color.lerp(theme.scaffoldBackgroundColor, Colors.black, 0.10)!;

Color _numberColor(
  BuildContext c,
  DateTime d,
  bool inMonth,
  bool isKoreanHoliday,
  LiturgicalColor liturgicalColor,
) {
  final theme = Theme.of(c);
  if (!inMonth) return theme.disabledColor;
  if (isKoreanHoliday) return const Color(0xFFC62828);
  if (d.weekday == DateTime.sunday) return const Color(0xFFC62828);
  if (d.weekday == DateTime.saturday) return const Color(0xFF1565C0);
  if (liturgicalColor == LiturgicalColor.white) {
    // 백색 전례일은 순검정보다 그리드 배경을 조금 섞어 차콜 톤으로 낮춘다.
    return Color.lerp(
      theme.colorScheme.onSurface,
      theme.scaffoldBackgroundColor,
      0.16,
    )!;
  }
  return theme.colorScheme.onSurface;
}

/// 날짜 숫자. 오늘/선택일 때만 원형 배경을 채운다.
class DayNumber extends StatelessWidget {
  const DayNumber({
    super.key,
    required this.date,
    required this.inCurrentMonth,
    required this.isToday,
    required this.isSelected,
    required this.liturgicalColor,
    this.isKoreanHoliday = false,
    this.isKoreanHolidayTitle = false,
    this.size = 34,
  });

  final DateTime date;
  final bool inCurrentMonth;
  final bool isToday;
  final bool isSelected;
  final LiturgicalColor liturgicalColor;
  final bool isKoreanHoliday;
  final bool isKoreanHolidayTitle;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseStyle = theme.textTheme.bodyLarge;
    final bg = isToday
        ? _todayFill
        : (isSelected ? _selectedFill : Colors.transparent);
    final fg = isToday
        ? Colors.white
        : _numberColor(
            context,
            date,
            inCurrentMonth,
            isKoreanHoliday,
            liturgicalColor,
          );
    final circleSize = isToday || isSelected ? size - 4 : size;
    return SizedBox(
      width: size,
      height: size,
      child: Center(
        child: Container(
          width: circleSize,
          height: circleSize,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
          child: Text(
            '${date.day}',
            style: baseStyle?.copyWith(
              color: fg,
              // Keep the date cell footprint unchanged while making the
              // highlighted circle easier to separate from the title below.
              fontSize: (baseStyle.fontSize ?? 16) + 2,
              fontWeight: isToday ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

/// 셀의 전례명 라벨. 남은 높이를 실제로 재서 들어가는 줄 수만 쓴다.
///
/// 이 위젯이 필요한 이유: 라벨은 `Expanded` 안에 있어 `Text`가 tight 높이를 받는데,
/// `TextOverflow.ellipsis`는 `maxLines` 초과에만 `…`를 넣고 **박스 높이 초과는
/// 예외도 경고도 없이 그냥 잘라낸다**(rendering/paragraph.dart:949, :964).
/// 그래서 OS 글꼴을 키우면 3번째 줄이 반쯤 잘려 보였다.
/// `maxLines`를 측정된 박스 높이에서 역산하면 3줄 → 2줄 → 1줄로 강등되며 `…`로
/// 깔끔히 끝난다.
class _CellTitle extends StatelessWidget {
  const _CellTitle({
    required this.title,
    required this.style,
    required this.fontSize,
    required this.heightFactor,
    required this.maxLines,
    this.textAlign,
  });

  final String title;
  final TextStyle style;

  /// 스케일 **전** 폰트 크기. [style]에 지정된 값과 같아야 한다.
  final double fontSize;

  /// [style]의 `height`와 같아야 한다.
  final double heightFactor;

  /// 상위가 정한 줄 수 상한. 실제 줄 수는 이 값 이하로만 결정된다.
  final int maxLines;

  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    // scope가 LayoutBuilder보다 위에 있어야 아래 계산이 clamp된 스케일러를 읽고,
    // 계산과 렌더링이 같은 값을 쓰게 된다.
    return GridLabelTextScope(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final lineHeight = gridLabelLineHeight(
            context,
            fontSize: fontSize,
            heightFactor: heightFactor,
          );
          final lines = gridLabelFittingLines(
            available: constraints.maxHeight,
            lineHeight: lineHeight,
            maxLines: maxLines,
          );
          // 반 줄을 보여주는 대신 감춘다. 날짜 숫자는 그대로 남는다.
          if (lines == 0) return const SizedBox.shrink();
          return Text(
            title,
            maxLines: lines,
            overflow: TextOverflow.ellipsis,
            textAlign: textAlign,
            strutStyle: gridLabelStrut(
              fontSize: fontSize,
              heightFactor: heightFactor,
            ),
            style: style,
          );
        },
      ),
    );
  }
}

/// A small marker shown on days that have a personal event, distinct from the
/// liturgical color dots (app-primary, at the number's top-right corner).
class EventDot extends StatelessWidget {
  const EventDot({super.key, this.size = 7});

  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: theme.colorScheme.primary,
        border: Border.all(color: theme.scaffoldBackgroundColor, width: 1),
      ),
    );
  }
}

/// Wide (desktop/web) day cell: colored top bar + date circle + celebration name.
class DayCell extends StatelessWidget {
  const DayCell({
    super.key,
    required this.day,
    required this.inCurrentMonth,
    required this.isToday,
    required this.isSelected,
    this.isKoreanHoliday = false,
    this.isKoreanHolidayTitle = false,
    required this.onTap,
    this.hasEvent = false,
    this.shortTitle,
  });

  final LiturgicalDay day;
  final bool inCurrentMonth;
  final bool isToday;
  final bool isSelected;
  final bool isKoreanHoliday;
  final bool isKoreanHolidayTitle;
  final VoidCallback onTap;
  final bool hasEvent;
  final String? shortTitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final titleStyle = theme.textTheme.labelMedium ?? const TextStyle();
    final notable = inCurrentMonth && isNotableDay(day);
    final accent = context.liturgical.of(day.color);
    final hasTitle = shortTitle?.trim().isNotEmpty == true;
    final isWhiteTitle =
        day.color == LiturgicalColor.white && !isKoreanHolidayTitle;

    return InkWell(
      onTap: onTap,
      splashFactory: NoSplash.splashFactory,
      overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      child: Container(
        decoration: BoxDecoration(
          // Keep the grid visually continuous with the phone layout. The
          // footer/card surface is intentionally a different, softer white.
          color: isSelected
              ? _selectedCellFill(theme)
              : theme.scaffoldBackgroundColor,
          border: Border.all(
            color: theme.dividerColor.withValues(alpha: 0.2),
            width: 0.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 띠는 **전례색만** 나타낸다(범례와 1:1). 공휴일 이름이 셀 라벨로
            // 들어오는 날(추석 등)에도 전례색을 유지해야 한다. 공휴일 빨강
            // `#C62828`은 전례색 홍색과 값이 같아, 띠에 쓰면 그날이 사도·순교일로
            // 읽힌다(예: 한가위는 백색인데 빨간 띠). 공휴일 강조는 글자색이 맡는다.
            Container(
              height: 3,
              color: notable || hasTitle ? accent : Colors.transparent,
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(6, 4, 6, 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        DayNumber(
                          date: day.date,
                          inCurrentMonth: inCurrentMonth,
                          isToday: isToday,
                          isSelected: isSelected,
                          liturgicalColor: day.color,
                          isKoreanHoliday: isKoreanHoliday,
                          size: 28,
                        ),
                        if (hasEvent)
                          const Positioned(right: 0, top: 0, child: EventDot()),
                      ],
                    ),
                    if (shortTitle case final title?) ...[
                      const SizedBox(height: 1),
                      Expanded(
                        child: _CellTitle(
                          title: title,
                          fontSize: (titleStyle.fontSize ?? 12) + 2,
                          heightFactor: 1.2,
                          maxLines: 3,
                          style: titleStyle.copyWith(
                            color: isKoreanHolidayTitle
                                ? const Color(0xFFC62828)
                                : isWhiteTitle
                                ? Colors.black
                                : theme.colorScheme.onSurfaceVariant,
                            fontSize: (titleStyle.fontSize ?? 12) + 2,
                            height: 1.2,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact (phone) day cell: date circle + optional personal-event marker.
class CompactDayCell extends StatelessWidget {
  const CompactDayCell({
    super.key,
    required this.day,
    required this.inCurrentMonth,
    required this.isToday,
    required this.isSelected,
    this.isKoreanHoliday = false,
    this.isKoreanHolidayTitle = false,
    this.onTap,
    this.hasEvent = false,
    this.shortTitle,
    this.titleMaxLines = 3,
  });

  final LiturgicalDay day;
  final bool inCurrentMonth;
  final bool isToday;
  final bool isSelected;
  final bool isKoreanHoliday;
  final bool isKoreanHolidayTitle;
  final VoidCallback? onTap;
  final bool hasEvent;
  final String? shortTitle;
  final int titleMaxLines;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isWhiteTitle =
        day.color == LiturgicalColor.white && !isKoreanHolidayTitle;

    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      splashFactory: NoSplash.splashFactory,
      overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          const SizedBox(height: 3),
          Stack(
            clipBehavior: Clip.none,
            children: [
              DayNumber(
                date: day.date,
                inCurrentMonth: inCurrentMonth,
                isToday: isToday,
                isSelected: isSelected,
                liturgicalColor: day.color,
                isKoreanHoliday: isKoreanHoliday,
              ),
              if (hasEvent)
                const Positioned(right: 0, top: 0, child: EventDot()),
            ],
          ),
          if (shortTitle case final title?) ...[
            const SizedBox(height: 1),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1),
                child: _CellTitle(
                  title: title,
                  fontSize: 10,
                  heightFactor: 1.0,
                  maxLines: titleMaxLines,
                  textAlign: TextAlign.center,
                  style: (theme.textTheme.labelSmall ?? const TextStyle())
                      .copyWith(
                        color: isKoreanHolidayTitle
                            ? const Color(0xFFC62828)
                            : isWhiteTitle
                            ? Colors.black
                            : context.liturgical.of(day.color),
                        fontSize: 10,
                        height: 1.0,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
