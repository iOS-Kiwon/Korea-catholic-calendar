import 'package:flutter/material.dart';

/// 메인 캘린더의 추가 버튼. 탭하면 스크림이 덮이고 위로 미니 버튼 3개
/// (일정 추가/축일 추가/설정)가 라벨과 함께 순차로 펼쳐진다. 메인 버튼의
/// `+`는 45° 회전해 닫기(X)가 된다. 스크림/재탭/항목 선택 시 닫힌다.
class SpeedDialFab extends StatefulWidget {
  const SpeedDialFab({
    super.key,
    required this.color,
    required this.onAddEvent,
    required this.onAddFeast,
    required this.onOpenSettings,
  });

  final Color color;
  final VoidCallback onAddEvent;
  final VoidCallback onAddFeast;
  final VoidCallback onOpenSettings;

  @override
  State<SpeedDialFab> createState() => _SpeedDialFabState();
}

class _SpeedDialFabState extends State<SpeedDialFab>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 240),
  );

  bool get _open => _controller.value > 0 || _controller.isAnimating;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    if (_controller.isCompleted || _controller.velocity > 0) {
      _controller.reverse();
    } else {
      _controller.forward();
    }
    setState(() {});
  }

  void _close() {
    _controller.reverse();
    setState(() {});
  }

  void _select(VoidCallback action) {
    _close();
    action();
  }

  @override
  Widget build(BuildContext context) {
    // 스크림은 화면 전체를 덮어야 하므로 FAB 위치를 벗어나 Stack 최상위로 올린다.
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.bottomRight,
      children: [
        // 스크림(열렸을 때만 터치 흡수).
        if (_open)
          Positioned.fill(
            child: IgnorePointer(
              ignoring: false,
              child: FadeTransition(
                opacity: _controller,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _close,
                  child: Container(color: Colors.black.withValues(alpha: 0.35)),
                ),
              ),
            ),
          ),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _miniItem(
              index: 2,
              label: '설정',
              icon: Icons.settings,
              onTap: () => _select(widget.onOpenSettings),
            ),
            _miniItem(
              index: 1,
              label: '축일 추가',
              icon: Icons.star_border,
              onTap: () => _select(widget.onAddFeast),
            ),
            _miniItem(
              index: 0,
              label: '일정 추가',
              icon: Icons.event,
              onTap: () => _select(widget.onAddEvent),
            ),
            const SizedBox(height: 12),
            _mainButton(),
          ],
        ),
      ],
    );
  }

  Widget _mainButton() {
    return FloatingActionButton(
      key: const ValueKey('speed_dial_main'),
      heroTag: null,
      backgroundColor: widget.color,
      foregroundColor: Colors.white,
      onPressed: _toggle,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => Transform.rotate(
          angle: _controller.value * 0.785398, // 45°(π/4)
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  Widget _miniItem({
    required int index,
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    // 아래(0)부터 위(2)로 순차 등장.
    final start = 0.1 * index;
    final animation = CurvedAnimation(
      parent: _controller,
      curve: Interval(start, (start + 0.6).clamp(0.0, 1.0), curve: Curves.easeOut),
    );

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        if (animation.value == 0) return const SizedBox.shrink();
        return Opacity(
          opacity: animation.value,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: child,
          ),
        );
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 라벨도 버튼과 동일한 동작을 하도록 자체적으로 탭 가능하게 만든다.
          GestureDetector(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                label,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(width: 12),
          FloatingActionButton(
            heroTag: null,
            mini: true,
            backgroundColor: Colors.white,
            foregroundColor: widget.color,
            onPressed: onTap,
            child: Icon(icon),
          ),
        ],
      ),
    );
  }
}
