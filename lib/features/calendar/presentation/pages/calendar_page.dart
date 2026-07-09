import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:liturgical_calendar/liturgical_calendar.dart';

import '../../../../app/theme/liturgical_colors.dart';
import '../../../../core/date/year_month.dart';
import '../../application/calendar_providers.dart';
import '../../data/calendar_service.dart';
import '../season_style.dart';
import '../widgets/day_detail_view.dart';
import '../widgets/day_summary_card.dart';
import '../widgets/legend.dart';
import '../widgets/month_grid.dart';
import '../widgets/month_header.dart';

String monthPath(YearMonth ym) =>
    '/${ym.year}/${ym.month.toString().padLeft(2, '0')}';

/// Width at/above which the "wide" (named-cell card) layout is used.
const _wideBreakpoint = 720.0;

class CalendarPage extends ConsumerStatefulWidget {
  const CalendarPage({super.key, required this.month, this.initialSelected});

  final YearMonth month;
  final DateTime? initialSelected;

  @override
  ConsumerState<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends ConsumerState<CalendarPage> {
  DateTime? _selected;

  // Accumulated horizontal drag distance for the swipe gesture.
  double _dragDx = 0;

  // 스와이프로 인정할 최소 이동 거리(px). 미스탭(짧은 튐)은 무시.
  static const _swipeDistance = 72.0;

  // 짧더라도 아주 빠른 플릭은 허용하되, 최소한의 이동은 있어야 함.
  static const _flickVelocity = 700.0;
  static const _flickMinDistance = 28.0;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialSelected;
  }

  @override
  void didUpdateWidget(CalendarPage old) {
    super.didUpdateWidget(old);
    if (old.month != widget.month) _selected = null; // reset on month change
  }

  bool _inMonth(DateTime d) =>
      d.year == widget.month.year && d.month == widget.month.month;

  /// The day whose detail/summary is shown: explicit selection, else today (if
  /// visible), else the first of the month.
  DateTime get _focusDate {
    if (_selected != null) return _selected!;
    final today = DateTime.now();
    return _inMonth(today) ? today : widget.month.firstDay;
  }

  void _goMonth(YearMonth ym) => context.go(monthPath(ym));

  void _goToday() {
    final now = DateTime.now();
    setState(() => _selected = now);
    _goMonth(YearMonth.of(now));
  }

  /// 좌→우 스와이프(오른쪽으로) → 다음 달, 우→좌 스와이프 → 이전 달.
  /// 속도가 아니라 실제 이동 거리를 기준으로 판정해 미스탭을 걸러낸다.
  void _onSwipeEnd(DragEndDetails details) {
    final dx = _dragDx;
    final v = details.primaryVelocity ?? 0;
    final isSwipe =
        dx.abs() >= _swipeDistance ||
        (v.abs() >= _flickVelocity && dx.abs() >= _flickMinDistance);
    if (!isSwipe) return;
    if (dx > 0) {
      _goMonth(widget.month.next); // 좌→우
    } else {
      _goMonth(widget.month.previous); // 우→좌
    }
  }

  @override
  Widget build(BuildContext context) {
    final calendarAsync = ref.watch(liturgicalCalendarProvider);
    return Scaffold(
      body: SafeArea(
        bottom: false, // 하단 인셋은 전역 배너(BottomAdBanner)에서 처리
        child: calendarAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('전례력을 불러오지 못했습니다.\n$e')),
          data: (service) => LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= _wideBreakpoint;
              return GestureDetector(
                behavior: HitTestBehavior.translucent,
                onHorizontalDragStart: (_) => _dragDx = 0,
                onHorizontalDragUpdate: (d) => _dragDx += d.delta.dx,
                onHorizontalDragEnd: _onSwipeEnd,
                child: wide ? _wide(service) : _narrow(service),
              );
            },
          ),
        ),
      ),
    );
  }

  // Header season label/color derived from the middle of the month.
  ({String text, LiturgicalColor color}) _headerStyle(CalendarService s) {
    final mid = s.day(DateTime(widget.month.year, widget.month.month, 15));
    final color = seasonColor(mid.season);
    return (
      text: '${seasonLabel(mid.season)} · ${LiturgicalColors.label(color)}',
      color: color,
    );
  }

  MonthHeader _header(CalendarService s, {required bool compact}) {
    final h = _headerStyle(s);
    return MonthHeader(
      month: widget.month,
      seasonText: h.text,
      color: context.liturgical.of(h.color),
      compact: compact,
      onPrevMonth: () => _goMonth(widget.month.previous),
      onNextMonth: () => _goMonth(widget.month.next),
      onPrevYear: () =>
          _goMonth(YearMonth(widget.month.year - 1, widget.month.month)),
      onNextYear: () =>
          _goMonth(YearMonth(widget.month.year + 1, widget.month.month)),
      onToday: _goToday,
    );
  }

  MonthGrid _grid(CalendarService s, {required bool compact}) => MonthGrid(
    calendar: s,
    month: widget.month,
    today: DateTime.now(),
    // 모바일은 하단 요약 카드가 가리키는 날(_focusDate)을 그리드에도 표시.
    selectedDate: compact ? _focusDate : _selected,
    compact: compact,
    onSelectDay: (date) {
      setState(() => _selected = date);
      if (!compact) _openDetail(s, date); // wide: tap opens dialog
    },
  );

  // --- wide layout: a floating rounded card (header + legend + grid) ---
  Widget _wide(CalendarService s) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1120, maxHeight: 900),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Card(
            elevation: 3,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              children: [
                _header(s, compact: false),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                    child: Column(
                      children: [
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Legend(),
                        ),
                        const WeekdayRow(),
                        Expanded(child: _grid(s, compact: false)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- narrow layout: header + compact grid + bottom summary card ---
  Widget _narrow(CalendarService s) {
    final focus = _focusDate;
    return Column(
      children: [
        _header(s, compact: true),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: _goToday,
          icon: const Icon(Icons.today, size: 18),
          label: const Text('오늘로 이동'),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Column(
            children: [const WeekdayRow(), _grid(s, compact: true)],
          ),
        ),
        const Spacer(),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
          child: DaySummaryCard(
            day: s.day(focus),
            onTap: () => _openDetailSheet(s, focus),
          ),
        ),
      ],
    );
  }

  void _openDetail(CalendarService s, DateTime date) {
    showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460, maxHeight: 620),
          child: DayDetailView(day: s.day(date)),
        ),
      ),
    );
  }

  void _openDetailSheet(CalendarService s, DateTime date) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.8,
        child: DayDetailView(day: s.day(date)),
      ),
    );
  }
}
