import 'package:flutter/material.dart';

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
    this.maxLines = 1,
    this.overflow = TextOverflow.ellipsis,
  });

  EventLabelHighlight.fromCategory(
    EventCategory category, {
    super.key,
    this.style,
  }) : label = category.name,
       color = Color(category.color),
       maxLines = 1,
       overflow = TextOverflow.ellipsis;

  final String label;
  final Color color;
  final TextStyle? style;
  final int maxLines;
  final TextOverflow overflow;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveStyle = style ?? theme.textTheme.bodyLarge;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.24),
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

class RegularEventDisplayLine extends StatelessWidget {
  const RegularEventDisplayLine({
    super.key,
    required this.event,
    this.style,
    this.maxLines = 1,
  });

  final CalendarEvent event;
  final TextStyle? style;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveStyle = style ?? theme.textTheme.bodyLarge;
    final memo = event.memo?.trim();
    final time = event.isAllDay ? '종일' : event.time!;
    return Text.rich(
      TextSpan(
        style: effectiveStyle,
        children: [
          TextSpan(
            text: event.categoryName,
            style: effectiveStyle?.copyWith(
              backgroundColor: Color(
                event.categoryColor,
              ).withValues(alpha: 0.24),
            ),
          ),
          TextSpan(text: ' $time'),
          if (memo != null && memo.isNotEmpty) TextSpan(text: ' $memo'),
        ],
      ),
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
    );
  }
}
