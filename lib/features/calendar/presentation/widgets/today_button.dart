import 'package:flutter/material.dart';

/// `< 오늘` 투명 배경 캡슐 버튼. 누르면 오늘로 이동.
/// `<`는 "오늘"보다 한 포인트 작고 연한 회색(장식), "오늘"은 #121212.
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
          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '<',
                style: TextStyle(color: Color(0xFFB0B0B0), fontSize: 14),
              ),
              SizedBox(width: 5),
              Text(
                '오늘',
                style: TextStyle(
                  color: Color(0xFF121212),
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
