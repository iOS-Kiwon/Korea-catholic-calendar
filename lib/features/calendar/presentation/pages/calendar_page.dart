import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/liturgical_colors.dart';
import '../../../../core/date/year_month.dart';
import '../../../ads/ads.dart';
import '../../../events/presentation/event_editor_sheet.dart';
import '../../../support/presentation/support_sheet.dart';
import '../../application/calendar_providers.dart';
import '../../data/calendar_service.dart';
import '../season_style.dart';
import '../widgets/day_detail_view.dart';
import '../widgets/day_info_bar.dart';
import '../widgets/legend.dart';
import '../widgets/month_grid.dart';
import '../widgets/month_header.dart';
import '../widgets/month_year_picker.dart';
import '../widgets/today_button.dart';

String monthPath(YearMonth ym) =>
    '/${ym.year}/${ym.month.toString().padLeft(2, '0')}';

/// Width at/above which the "wide" (web/desktop) layout is used.
const _wideBreakpoint = 720.0;
const _tabletMaxLogicalSide = 1400.0;

class CalendarPage extends ConsumerStatefulWidget {
  const CalendarPage({super.key, required this.month, this.initialSelected});

  final YearMonth month;
  final DateTime? initialSelected;

  @override
  ConsumerState<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends ConsumerState<CalendarPage> {
  DateTime? _selected;

  double _dragDx = 0;
  static const _swipeDistance = 72.0;
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
    if (old.month != widget.month) _selected = null;
  }

  bool _inMonth(DateTime d) =>
      d.year == widget.month.year && d.month == widget.month.month;

  /// 하단 정보/그리드 강조가 가리키는 날: 선택한 날, 없으면 오늘(그 달에 있으면), 없으면 1일.
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

  Future<void> _openPicker() async {
    final result = await showMonthYearPicker(context, widget.month);
    if (result != null && mounted) _goMonth(result);
  }

  /// 좌→우 스와이프 → 이전 달, 우→좌 → 다음 달 (이동 거리 기준).
  void _onSwipeEnd(DragEndDetails details) {
    final dx = _dragDx;
    final v = details.primaryVelocity ?? 0;
    final isSwipe =
        dx.abs() >= _swipeDistance ||
        (v.abs() >= _flickVelocity && dx.abs() >= _flickMinDistance);
    if (!isSwipe) return;
    _goMonth(dx > 0 ? widget.month.previous : widget.month.next);
  }

  @override
  Widget build(BuildContext context) {
    final calendarAsync = ref.watch(calendarControllerProvider);
    return Scaffold(
      body: SafeArea(
        bottom: !adsEnabled,
        child: calendarAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('전례력을 불러오지 못했습니다.\n$e')),
          data: (service) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              ref
                  .read(calendarControllerProvider.notifier)
                  .preloadAround(widget.month);
            });
            return LayoutBuilder(
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
            );
          },
        ),
      ),
    );
  }

  MonthHeader _header(CalendarService s, {required bool compact}) {
    final mid = s.day(DateTime(widget.month.year, widget.month.month, 15));
    final color = seasonColor(mid.season);
    return MonthHeader(
      month: widget.month,
      seasonText:
          '${seasonLabel(mid.season)} · ${LiturgicalColors.label(color)}',
      color: context.liturgical.of(color),
      compact: compact,
      onPrevMonth: () => _goMonth(widget.month.previous),
      onNextMonth: () => _goMonth(widget.month.next),
      onTapTitle: _openPicker,
    );
  }

  Widget _todayButton() => Align(
    alignment: Alignment.centerRight,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: TodayButton(onPressed: _goToday),
    ),
  );

  MonthGrid _grid(CalendarService s, {required bool compact}) => MonthGrid(
    calendar: s,
    month: widget.month,
    today: DateTime.now(),
    selectedDate: _focusDate, // 오늘=검정 원, 선택=연회색 원
    compact: compact,
    onSelectDay: (date) => setState(() => _selected = date),
  );

  DayInfoBar _infoBar(CalendarService s, {required bool compact}) => DayInfoBar(
    day: s.day(_focusDate),
    onSupportTap: () => showSupportSheet(context),
    onTapDetail: () =>
        compact ? _openDetailSheet(s, _focusDate) : _openDetail(s, _focusDate),
  );

  /// 일정 추가 플로팅 버튼. 색상 = 현재 월의 전례색(연중=녹색 등).
  Widget _addEventFab(CalendarService s) {
    final mid = s.day(DateTime(widget.month.year, widget.month.month, 15));
    final color = context.liturgical.of(seasonColor(mid.season));
    return FloatingActionButton(
      heroTag: null,
      backgroundColor: color,
      foregroundColor: color.computeLuminance() > 0.55
          ? Colors.black87
          : Colors.white,
      tooltip: '일정 추가',
      onPressed: () => showEventEditor(context, date: _focusDate),
      child: const Icon(Icons.add),
    );
  }

  // --- wide (web/desktop) ---
  Widget _wide(CalendarService s) {
    final size = MediaQuery.sizeOf(context);
    final tabletLike =
        size.shortestSide >= 600 && size.longestSide <= _tabletMaxLogicalSide;
    final outerPadding = tabletLike ? 16.0 : 24.0;
    final maxWidth = tabletLike ? double.infinity : 1120.0;
    final maxHeight = tabletLike ? double.infinity : 940.0;

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth, maxHeight: maxHeight),
        child: Padding(
          padding: EdgeInsets.all(outerPadding),
          child: Card(
            elevation: 3,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              children: [
                _header(s, compact: false),
                _todayButton(),
                Expanded(
                  child: Stack(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
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
                      Positioned(right: 28, bottom: 20, child: _addEventFab(s)),
                    ],
                  ),
                ),
                _infoBar(s, compact: false),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- narrow (phone) ---
  Widget _narrow(CalendarService s) {
    return Column(
      children: [
        _header(s, compact: true),
        _todayButton(),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: WeekdayRow(),
        ),
        Expanded(
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: _grid(s, compact: true),
              ),
              Positioned(right: 16, bottom: 16, child: _addEventFab(s)),
            ],
          ),
        ),
        _infoBar(s, compact: true),
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
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.8,
        minChildSize: 0.25,
        maxChildSize: 0.95,
        builder: (context, scrollController) =>
            DayDetailView(day: s.day(date), scrollController: scrollController),
      ),
    );
  }
}
