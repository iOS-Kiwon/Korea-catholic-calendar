import 'package:flutter/material.dart';
import 'package:liturgical_calendar/liturgical_calendar.dart';

import '../../../app/theme/liturgical_colors.dart';
import '../model/calendar_event.dart';
import '../model/event_category.dart';

String regularEventDisplayText(CalendarEvent event) {
  final memo = event.memo?.trim();
  final time = event.isAllDay ? '종일' : event.time!;
  final suffix = memo == null || memo.isEmpty ? '' : ' $memo';
  return '${event.categoryName} $time$suffix';
}

class EventLabelHighlight extends StatelessWidget {
  const EventLabelHighlight({
    super.key,
    required this.label,
    required this.color,
    this.style,
    this.backgroundColor,
    this.backgroundOpacity = 0.24,
    this.maxLines = 1,
    this.overflow = TextOverflow.ellipsis,
  });

  EventLabelHighlight.fromCategory(
    EventCategory category, {
    super.key,
    this.style,
  }) : label = category.name,
       color = Color(category.color),
       backgroundColor = null,
       backgroundOpacity = 0.24,
       maxLines = 1,
       overflow = TextOverflow.ellipsis;

  final String label;
  final Color color;
  final TextStyle? style;
  final Color? backgroundColor;
  final double backgroundOpacity;
  final int maxLines;
  final TextOverflow overflow;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveStyle = style ?? theme.textTheme.bodyLarge;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: (backgroundColor ?? color).withValues(alpha: backgroundOpacity),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
        child: Text(
          label,
          maxLines: maxLines,
          overflow: overflow,
          style: effectiveStyle,
        ),
      ),
    );
  }
}

/// A liturgical-color label used consistently in the calendar footer and the
/// day detail screen.
class LiturgicalColorLabel extends StatelessWidget {
  const LiturgicalColorLabel({super.key, required this.color, this.style});

  final LiturgicalColor color;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final liturgicalColor = context.liturgical.of(color);
    final isWhite = color == LiturgicalColor.white;
    return EventLabelHighlight(
      label: liturgicalColorShortLabel(color),
      color: liturgicalColor,
      backgroundColor: isWhite ? const Color(0xFF666666) : null,
      backgroundOpacity: isWhite ? 0.92 : 0.24,
      style: (style ?? theme.textTheme.bodyLarge)?.copyWith(
        color: isWhite ? Colors.white : liturgicalColor,
      ),
    );
  }
}

String liturgicalColorShortLabel(LiturgicalColor color) {
  switch (color) {
    case LiturgicalColor.green:
      return '[녹]';
    case LiturgicalColor.red:
      return '[홍]';
    case LiturgicalColor.white:
      return '[백]';
    case LiturgicalColor.violet:
      return '[자]';
    case LiturgicalColor.rose:
      return '[장]';
    case LiturgicalColor.black:
      return '[흑]';
  }
}

class RegularEventDisplayLine extends StatelessWidget {
  const RegularEventDisplayLine({
    super.key,
    required this.event,
    this.style,
    this.maxLines = 1,
    this.showAllDayLabel = true,
  });

  final CalendarEvent event;
  final TextStyle? style;
  final int maxLines;
  final bool showAllDayLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveStyle = style ?? theme.textTheme.bodyLarge;
    final memo = event.memo?.trim();
    final time = event.isAllDay ? (showAllDayLabel ? '종일' : null) : event.time!;
    final detailText = [
      ?time,
      if (memo != null && memo.isNotEmpty) memo,
    ].join(' ');
    final hasDetail = detailText.isNotEmpty;

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxLabelWidth = constraints.hasBoundedWidth
            ? constraints.maxWidth * 0.45
            : double.infinity;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxLabelWidth),
              child: EventLabelHighlight(
                label: event.categoryName,
                color: Color(event.categoryColor),
                style: effectiveStyle,
                maxLines: maxLines,
              ),
            ),
            if (hasDetail) ...[
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  detailText,
                  maxLines: maxLines,
                  overflow: TextOverflow.ellipsis,
                  style: effectiveStyle,
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
