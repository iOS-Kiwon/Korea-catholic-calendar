import 'package:flutter/material.dart';

/// `오늘` 투명 배경 캡슐 버튼. 누르면 오늘로 이동.
class TodayButton extends StatelessWidget {
  const TodayButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: StadiumBorder(
        side: BorderSide(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
        ),
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onPressed,
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 7),
          child: Text(
            '오늘',
            style: TextStyle(
              color: Color(0xFF121212),
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
