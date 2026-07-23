import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/liturgical_colors.dart';
import '../../../../core/date/year_month.dart';
import '../../../ads/ads.dart';
import '../../../events/presentation/event_editor_sheet.dart';
import '../../../saints/presentation/saint_feast_editor_page.dart';
import '../../../settings/presentation/settings_page.dart';
import '../../../support/presentation/support_sheet.dart';
import '../../application/calendar_providers.dart';
import '../../data/calendar_service.dart';
import '../season_style.dart';
import '../widgets/day_info_bar.dart';
import '../widgets/legend.dart';
import '../widgets/month_grid.dart';
import '../widgets/month_header.dart';
import '../widgets/month_year_picker.dart';
import '../widgets/speed_dial_fab.dart';
import 'day_detail_page.dart';

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
  final _infoBarKey = GlobalKey();

  DateTime? _selected;
  double _infoBarHeight = 0;

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
    final remoteStatuses = ref.watch(remoteMonthStatusProvider);
    return Scaffold(
      body: SafeArea(
        // 상단 인셋은 헤더(전례색)가 상태바 뒤까지 직접 덮으므로 여기서는 끈다.
        top: false,
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
              _updateInfoBarHeight();
            });
            return LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= _wideBreakpoint;
                final body = GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onHorizontalDragStart: (_) => _dragDx = 0,
                  onHorizontalDragUpdate: (d) => _dragDx += d.delta.dx,
                  onHorizontalDragEnd: _onSwipeEnd,
                  child: wide ? _wide(service) : _narrow(service),
                );
                final fabPadding = _fabPadding(
                  constraints: constraints,
                  wide: wide,
                );
                return Stack(
                  children: [
                    body,
                    _debugRemoteStatusBadge(
                      remoteStatuses[widget.month.toString()],
                    ),
                    Positioned.fill(
                      child: _addEventFab(service, padding: fabPadding),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _debugRemoteStatusBadge(RemoteMonthState? state) {
    if (!kDebugMode) return const SizedBox.shrink();

    final status = state?.status ?? RemoteMonthStatus.idle;
    final (label, color) = switch (status) {
      RemoteMonthStatus.loading => ('서버 확인 중', Colors.blueGrey),
      RemoteMonthStatus.loaded => ('서버 갱신 완료', Colors.green),
      RemoteMonthStatus.unavailable => ('서버 데이터 없음', Colors.orange),
      RemoteMonthStatus.failed => ('서버 확인 실패', Colors.red),
      RemoteMonthStatus.skipped => ('최근 서버 확인됨', Colors.teal),
      RemoteMonthStatus.idle => ('서버 대기', Colors.grey),
    };
    final checkedAt = state == null
        ? ''
        : ' · ${state.checkedAt.hour.toString().padLeft(2, '0')}:'
              '${state.checkedAt.minute.toString().padLeft(2, '0')}:'
              '${state.checkedAt.second.toString().padLeft(2, '0')}';

    return Positioned(
      right: 12,
      // 헤더(상태바 + 제목줄) 아래에 두어 오늘/화살표 버튼을 가리지 않도록.
      top: MediaQuery.paddingOf(context).top + 60,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(999),
          boxShadow: const [
            BoxShadow(
              blurRadius: 8,
              offset: Offset(0, 2),
              color: Color(0x33000000),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Text(
            '$label$checkedAt',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  MonthHeader _header(CalendarService s, {required bool compact}) {
    final mid = s.day(DateTime(widget.month.year, widget.month.month, 15));
    final color = seasonColor(mid.season);
    return MonthHeader(
      month: widget.month,
      color: context.liturgical.of(color),
      compact: compact,
      // 오늘이 아닌 날짜(다른 달 포함)를 보고 있을 때만 `오늘` 버튼 노출.
      showToday: !_isSameDay(_focusDate, DateTime.now()),
      onPrevMonth: () => _goMonth(widget.month.previous),
      onNextMonth: () => _goMonth(widget.month.next),
      onTapTitle: _openPicker,
      onToday: _goToday,
    );
  }

  MonthGrid _grid(CalendarService s, {required bool compact}) => MonthGrid(
    calendar: s,
    month: widget.month,
    today: DateTime.now(),
    selectedDate: _focusDate, // 오늘=검정 원, 선택=연회색 원
    compact: compact,
    onSelectDay: (date) => setState(() => _selected = date),
  );

  DayInfoBar _infoBar(CalendarService s, {required bool compact}) => DayInfoBar(
    key: _infoBarKey,
    day: s.day(_focusDate),
    onSupportTap: () => showSupportSheet(context),
    onTapDetail: () => _openDetailPage(s, _focusDate),
  );

  EdgeInsets _fabPadding({
    required BoxConstraints constraints,
    required bool wide,
  }) {
    final infoBarHeight = _infoBarHeight;
    if (!wide) {
      return EdgeInsets.only(right: 16, bottom: infoBarHeight + 16);
    }

    final size = MediaQuery.sizeOf(context);
    final tabletLike =
        size.shortestSide >= 600 && size.longestSide <= _tabletMaxLogicalSide;
    final outerPadding = tabletLike ? 16.0 : 24.0;
    final maxWidth = tabletLike ? constraints.maxWidth : 1120.0;
    final maxHeight = tabletLike ? constraints.maxHeight : 940.0;
    final boxWidth = math.min(constraints.maxWidth, maxWidth);
    final boxHeight = math.min(constraints.maxHeight, maxHeight);
    final rightInset = ((constraints.maxWidth - boxWidth) / 2) + outerPadding;
    final bottomInset =
        ((constraints.maxHeight - boxHeight) / 2) + outerPadding;

    return EdgeInsets.only(
      right: rightInset + 28,
      bottom: bottomInset + infoBarHeight + 20,
    );
  }

  void _updateInfoBarHeight() {
    final height = _infoBarKey.currentContext?.size?.height;
    if (height == null || (height - _infoBarHeight).abs() < 0.5) return;
    setState(() => _infoBarHeight = height);
  }

  /// 스피드다이얼 추가 버튼. 색상 = 현재 월의 전례색(연중=녹색 등).
  Widget _addEventFab(CalendarService s, {required EdgeInsets padding}) {
    final mid = s.day(DateTime(widget.month.year, widget.month.month, 15));
    final color = context.liturgical.of(seasonColor(mid.season));
    return SpeedDialFab(
      color: color,
      padding: padding,
      onAddEvent: () => showEventEditor(context, date: _focusDate),
      onAddFeast: () => showSaintFeastEditor(context, date: _focusDate),
      onOpenSettings: () => Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => const SettingsPage())),
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
            ],
          ),
        ),
        _infoBar(s, compact: true),
      ],
    );
  }

  /// 하단 상세영역 탭 → 별도 화면으로 이동(iOS의 push 방식). 기존 바텀시트/다이얼로그
  /// 대신 전체 화면 라우트를 쌓는다.
  void _openDetailPage(CalendarService s, DateTime date) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => DayDetailPage(day: s.day(date))),
    );
  }
}
