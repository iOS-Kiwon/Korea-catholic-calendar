import 'package:flutter/material.dart';

/// `오늘` 투명 배경 캡슐 버튼. 누르면 오늘로 이동.
class TodayButton extends StatelessWidget {
  const TodayButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      shape: StadiumBorder(
        side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.5)),
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
          child: Text(
            '오늘',
            style: TextStyle(
              color: theme.colorScheme.onSurface,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
