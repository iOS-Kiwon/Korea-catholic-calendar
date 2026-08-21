import 'dart:convert';

import 'package:catholic_calendar/app/theme/app_theme.dart';
import 'package:catholic_calendar/core/date/year_month.dart';
import 'package:catholic_calendar/features/calendar/application/calendar_providers.dart';
import 'package:catholic_calendar/features/calendar/data/calendar_service.dart';
import 'package:catholic_calendar/features/calendar/data/remote_calendar_source.dart';
import 'package:catholic_calendar/features/calendar/presentation/pages/calendar_page.dart';
import 'package:catholic_calendar/features/calendar/presentation/pages/day_detail_page.dart';
import 'package:catholic_calendar/features/calendar/presentation/widgets/day_detail_view.dart';
import 'package:catholic_calendar/features/calendar/presentation/widgets/day_info_bar.dart';
import 'package:catholic_calendar/features/calendar/presentation/widgets/day_cell.dart';
import 'package:catholic_calendar/features/calendar/presentation/widgets/month_grid.dart';
import 'package:catholic_calendar/features/calendar/presentation/widgets/month_header.dart';
import 'package:catholic_calendar/features/events/analytics/category_log_service.dart';
import 'package:catholic_calendar/features/events/application/event_providers.dart';
import 'package:catholic_calendar/features/events/application/recurrence_expander.dart';
import 'package:catholic_calendar/features/events/data/personal_cloud_backup_store.dart';
import 'package:catholic_calendar/features/events/model/calendar_event.dart';
import 'package:catholic_calendar/features/events/model/recurrence.dart';
import 'package:catholic_calendar/features/events/notifications/notifications.dart';
import 'package:catholic_calendar/features/events/presentation/category_manager_page.dart'
    show CategoryPickerPage;
import 'package:catholic_calendar/features/events/presentation/event_editor_sheet.dart';
import 'package:catholic_calendar/features/events/presentation/reminder_editor.dart';
import 'package:catholic_calendar/features/saints/presentation/saint_feast_editor_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liturgical_calendar/liturgical_calendar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/text_clip.dart';

/// A no-op notification service so tests never touch platform channels.
class _FakeNotifications implements NotificationService {
  _FakeNotifications({
    this.enabled = true,
    this.status,
    this.requestGranted = true,
    this.onRequestPermission,
    this.onOpenSettings,
  });

  final bool enabled;
  final NotificationPermissionStatus? status;
  final bool requestGranted;
  final VoidCallback? onRequestPermission;
  final VoidCallback? onOpenSettings;

  @override
  Future<void> init() async {}

  @override
  Future<bool> areNotificationsEnabled() async => enabled;

  @override
  Future<NotificationPermissionStatus> notificationPermissionStatus() async =>
      status ??
      (enabled
          ? NotificationPermissionStatus.authorized
          : NotificationPermissionStatus.denied);

  @override
  Future<bool> requestNotificationPermission() async {
    onRequestPermission?.call();
    return requestGranted;
  }

  @override
  Future<void> openNotificationSettings() async => onOpenSettings?.call();

  @override
  Future<void> sync(
    Map<String, List<CalendarEvent>> events, {
    RecurrenceExpander? expander,
  }) async {}
}

/// A backup store that never touches platform channels; reports cloud backup
/// as available so the first-run notice renders a simple 확인 dialog.
class _FakeBackupStore extends PersonalCloudBackupStore {
  const _FakeBackupStore();
  @override
  Future<CloudBackupAvailability> checkAvailability() async =>
      CloudBackupAvailability.available;
  @override
  Future<bool> promptSetup() async => false;
  @override
  Future<String?> loadSnapshotJson({
    bool promptIfNeeded = false,
    bool allowSilentGoogleDrive = false,
  }) async => null;
  @override
  Future<bool> saveSnapshotJson(
    String snapshotJson, {
    bool promptIfNeeded = false,
    bool allowSilentGoogleDrive = false,
  }) async => true;
}

Widget _wrap(
  Widget child, {
  NotificationService? notificationService,
}) => ProviderScope(
  // Inject the engine-only service (no CBCK snapshot) and disable the remote
  // gateway so tests never hit the network → falls back to the computed engine.
  // Notifications and cloud backup are stubbed to avoid platform channels.
  overrides: [
    liturgicalCalendarProvider.overrideWith(
      (ref) => CalendarService(engine: LiturgicalCalendar()),
    ),
    remoteCalendarSourceProvider.overrideWithValue(
      const RemoteCalendarSource(enabled: false),
    ),
    notificationServiceProvider.overrideWithValue(
      notificationService ?? _FakeNotifications(),
    ),
    categoryLogServiceProvider.overrideWithValue(
      const NoopCategoryLogService(),
    ),
    personalCloudBackupStoreProvider.overrideWithValue(
      const _FakeBackupStore(),
    ),
  ],
  child: MaterialApp(theme: AppTheme.light(), home: child),
);

void main() {
  setUp(() {
    // Fresh, empty on-device event store unless a test seeds it below.
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('month header and notable day names render', (tester) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _wrap(const CalendarPage(month: YearMonth(2026, 7))),
    );
    await tester.pumpAndSettle(); // resolve async month service

    expect(find.text('2026년 7월'), findsOneWidget); // colored header
    // Sundays are "notable" and show their abbreviated name in the wide grid.
    expect(find.text('연중 제15주일'), findsWidgets); // 2026-07-12
  });

  testWidgets('compact month grid hides liturgical color dots', (tester) async {
    final service = CalendarService(engine: LiturgicalCalendar());

    await tester.pumpWidget(
      _wrap(
        Scaffold(
          body: SizedBox(
            width: 390,
            height: 360,
            child: MonthGrid(
              calendar: service,
              month: const YearMonth(2026, 7),
              today: DateTime(2026, 7, 1),
              selectedDate: null,
              onSelectDay: (_) {},
              compact: true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final liturgicalDots = tester
        .widgetList<Container>(find.byType(Container))
        .where(
          (widget) =>
              widget.constraints?.minWidth == 6 &&
              widget.constraints?.maxWidth == 6 &&
              widget.constraints?.minHeight == 6 &&
              widget.constraints?.maxHeight == 6,
        );
    expect(liturgicalDots, isEmpty);
  });

  testWidgets('fixed calendar row heights keep compact and wide cells stable', (
    tester,
  ) async {
    // 이 테스트의 픽셀 값들은 모두 "폰트 배율 1.0 기준선"이다. 호스트 환경의
    // 접근성 설정이 새어들지 않도록 명시적으로 고정한다.
    setSystemTextSettings(tester);
    final service = CalendarService(engine: LiturgicalCalendar());

    await tester.pumpWidget(
      _wrap(
        Scaffold(
          body: SizedBox(
            width: 390,
            height: 420,
            child: MonthGrid(
              calendar: service,
              month: const YearMonth(2026, 5),
              today: DateTime(2026, 5, 1),
              selectedDate: null,
              onSelectDay: (_) {},
              compact: true,
              fixedRowHeight: 70,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.getSize(find.byType(MonthGrid)).height, 420);
    expect(tester.getSize(find.byType(CompactDayCell).first).height, 70);
    expect(tester.widget<Text>(find.text('주님 승천')).maxLines, 3);
    // `maxLines: 3`인데 세로로 잘리는 것이 정확히 OS 글꼴 확대 시의 버그였다.
    // 줄 수만 보면 그 상태를 통과시키므로 클립 여부를 함께 단정한다.
    expectNoVerticalTextClip(
      tester,
      within: find.byType(MonthGrid),
      ignore: isDateNumber,
    );

    await tester.pumpWidget(
      _wrap(
        Scaffold(
          body: SizedBox(
            width: 1200,
            height: 558,
            child: MonthGrid(
              calendar: service,
              month: const YearMonth(2026, 8),
              today: DateTime(2026, 8, 1),
              selectedDate: null,
              onSelectDay: (_) {},
              fixedRowHeight: 93,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.getSize(find.byType(DayCell).first).height, 93);
    expectNoVerticalTextClip(
      tester,
      within: find.byType(MonthGrid),
      ignore: isDateNumber,
    );
  });

  testWidgets('phone calendar reserves a fixed six-row grid slot', (
    tester,
  ) async {
    setSystemTextSettings(tester); // 아래 픽셀 값은 배율 1.0 기준선
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _wrap(
        CalendarPage(
          month: YearMonth(2026, 8),
          initialSelected: DateTime(2026, 8, 6),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.getSize(find.byType(WeekdayRow)).height, 36);
    expect(tester.getSize(find.byType(MonthGrid)).height, 420);
  });

  testWidgets('compact month grid shows transferred solemnity short label', (
    tester,
  ) async {
    final service = CalendarService(engine: LiturgicalCalendar());

    await tester.pumpWidget(
      _wrap(
        Scaffold(
          body: SizedBox(
            width: 390,
            height: 360,
            child: MonthGrid(
              calendar: service,
              month: const YearMonth(2026, 5),
              today: DateTime(2026, 5, 1),
              selectedDate: null,
              onSelectDay: (_) {},
              compact: true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('주님 승천'), findsOneWidget);
    expect(service.day(DateTime(2026, 5, 17)).celebration.id, 'ascension');
    expect(
      service.day(DateTime(2026, 5, 14)).celebration.id,
      isNot('ascension'),
    );
  });

  // OS 글꼴 확대 / 굵은 글씨에서 실제 달력 화면의 전례명이 세로로 잘리지 않는지.
  // 셀 단위 검증은 test/calendar_label_scale_test.dart에 있고, 여기서는 실제 화면
  // 조립 경로(헤더 + 요일줄 + 6줄 고정 그리드 + 하단 카드)를 통과했을 때의 행 높이로
  // 확인한다. 그리드 subtree만 단정한다 - 날짜 숫자/요일줄/헤더의 고정 높이 문제는
  // 전례명과 별개의 알려진 문제로 이번 수정 범위 밖이다.
  for (final (scale, bold) in const [
    (1.0, false),
    (1.15, true),
    (1.5, true),
    (2.0, true),
    (3.0, true),
  ]) {
    testWidgets(
      'phone calendar grid labels never clip vertically (배율 $scale, 굵게 $bold)',
      (tester) async {
        setSystemTextSettings(
          tester,
          textScaleFactor: scale,
          boldText: bold,
        );
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          _wrap(const CalendarPage(month: YearMonth(2026, 5))),
        );
        await tester.pumpAndSettle();

        expectNoVerticalTextClip(
          tester,
          within: find.byType(MonthGrid),
          ignore: isDateNumber,
        );
      },
    );
  }

  testWidgets(
    'compact month grid uses up to three title lines when space allows',
    (tester) async {
      // 아래 임계값(행 높이 72/60/50)은 배율 1.0 기준이며, 라벨 박스
      // `행 높이 - (3 + DayNumber 34 + 1)`을 줄 높이 10px로 나눈 결과다.
      // 셀 상단 여백이나 `DayNumber.size`를 바꾸면 기대값도 바뀐다.
      setSystemTextSettings(tester);
      final service = CalendarService(engine: LiturgicalCalendar());

      Future<void> pumpGrid(double height) async {
        await tester.pumpWidget(
          _wrap(
            Scaffold(
              body: SizedBox(
                width: 390,
                height: height,
                child: MonthGrid(
                  calendar: service,
                  month: const YearMonth(2026, 5),
                  today: DateTime(2026, 5, 1),
                  selectedDate: null,
                  onSelectDay: (_) {},
                  compact: true,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      await pumpGrid(450);
      expect(tester.widget<Text>(find.text('주님 승천')).maxLines, 3);
      expectTextFits(tester, '주님 승천');

      await pumpGrid(360);
      expect(tester.widget<Text>(find.text('주님 승천')).maxLines, 2);
      expectTextFits(tester, '주님 승천');

      await pumpGrid(300);
      expect(tester.widget<Text>(find.text('주님 승천')).maxLines, 1);
      expectTextFits(tester, '주님 승천');
    },
  );

  testWidgets('day detail shows the 전례력 and 일정 sections', (tester) async {
    // 2026-12-25 — Christmas.
    final day = LiturgicalCalendar().day(DateTime(2026, 12, 25));
    await tester.pumpWidget(_wrap(Scaffold(body: DayDetailView(day: day))));
    await tester.pumpAndSettle();

    expect(find.text('전례력'), findsOneWidget);
    // The liturgical title appears in the 전례력 section.
    expect(find.text('주님 성탄 대축일'), findsOneWidget);
    expect(find.text('일정'), findsOneWidget);
  });

  testWidgets('liturgical feast detail shows saint feast add button', (
    tester,
  ) async {
    final day = LiturgicalCalendar()
        .day(DateTime(2026, 7, 25))
        .copyWith(
          title: '성 야고보 사도 축일',
          celebration: const Celebration(
            id: 'james_apostle',
            name: '성 야고보 사도 축일',
            rank: Rank.feast,
            color: LiturgicalColor.red,
            kind: CelebrationKind.sanctorale,
            precedence: PrecedenceCode.generalFeast,
          ),
        );
    expect(day.celebration.rank, Rank.feast);

    await tester.pumpWidget(_wrap(Scaffold(body: DayDetailView(day: day))));
    await tester.pumpAndSettle();

    expect(find.text('성 야고보 사도 축일'), findsOneWidget);
    expect(find.widgetWithText(TextButton, '축일 추가'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, '축일 추가'));
    await tester.pumpAndSettle();

    expect(find.text('새 축일'), findsOneWidget);
    expect(find.text('성인을 선택하세요'), findsOneWidget);
  });

  testWidgets('day detail shows saint information link when available', (
    tester,
  ) async {
    final day = LiturgicalCalendar()
        .day(DateTime(2026, 7, 25))
        .copyWith(saintInfoUrl: 'https://example.com/saint/james');

    await tester.pumpWidget(_wrap(Scaffold(body: DayDetailView(day: day))));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextButton, '성인 정보 보기'), findsOneWidget);
  });

  testWidgets('non-feast detail hides saint feast add button', (tester) async {
    final day = LiturgicalCalendar().day(DateTime(2026, 7, 16));
    expect(day.celebration.rank, isNot(Rank.feast));
    expect(day.celebration.rank, isNot(Rank.feastOfTheLord));
    expect(day.celebration.rank, isNot(Rank.solemnity));

    await tester.pumpWidget(_wrap(Scaffold(body: DayDetailView(day: day))));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextButton, '축일 추가'), findsNothing);
  });

  testWidgets('the add-event speed dial opens the event editor', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844); // phone (narrow) layout
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _wrap(const CalendarPage(month: YearMonth(2026, 7))),
    );
    await tester.pumpAndSettle();

    // Tap the speed-dial main button to expand the mini actions.
    await tester.tap(find.byKey(const ValueKey('speed_dial_main')));
    await tester.pumpAndSettle();

    expect(find.text('일정 추가'), findsOneWidget);

    // Tap '일정 추가' to open the editor.
    await tester.tap(find.text('일정 추가'));
    await tester.pumpAndSettle();

    expect(find.text('새 일정'), findsOneWidget);
    // Title is now chosen on the category screen, not typed here.
    expect(find.text('카테고리를 선택하세요'), findsOneWidget);
  });

  testWidgets('event editor shows start/end times when all-day is off', (
    tester,
  ) async {
    final day = LiturgicalCalendar().day(DateTime(2026, 7, 16));
    await tester.pumpWidget(_wrap(Scaffold(body: DayDetailView(day: day))));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(TextButton, '추가'));
    await tester.pumpAndSettle();

    expect(find.text('시작'), findsOneWidget);
    expect(find.text('종료'), findsOneWidget);
    final allDayButtonCount = find.byType(TextButton).evaluate().length;

    await tester.tap(find.widgetWithText(SwitchListTile, '종일'));
    await tester.pumpAndSettle();

    final timedButtonCount = find.byType(TextButton).evaluate().length;
    expect(timedButtonCount, allDayButtonCount + 2);
  });

  testWidgets('event memo wraps while return key stays done', (tester) async {
    final day = LiturgicalCalendar().day(DateTime(2026, 7, 16));
    await tester.pumpWidget(_wrap(Scaffold(body: DayDetailView(day: day))));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(TextButton, '추가'));
    await tester.pumpAndSettle();

    final memo = _memoTextField(tester);
    expect(memo.minLines, 1);
    expect(memo.maxLines, isNull);
    expect(memo.keyboardType, TextInputType.text);
    expect(memo.textInputAction, TextInputAction.done);
    expect(memo.inputFormatters, contains(isA<FilteringTextInputFormatter>()));
  });

  testWidgets('open speed dial scrim blocks month navigation', (tester) async {
    tester.view.physicalSize = const Size(390, 844); // phone (narrow) layout
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _wrap(const CalendarPage(month: YearMonth(2026, 7))),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('speed_dial_main')));
    await tester.pumpAndSettle();
    expect(find.text('일정 추가'), findsOneWidget);

    final fabBottom = tester
        .getBottomLeft(find.byKey(const ValueKey('speed_dial_main')))
        .dy;
    final infoTop = tester.getTopLeft(find.byType(DayInfoBar)).dy;
    expect(fabBottom, lessThan(infoTop));

    await tester.tap(find.byTooltip('다음 달'), warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(find.text('2026년 7월'), findsOneWidget);
    expect(find.text('일정 추가'), findsNothing);
  });

  testWidgets('disabled system notifications prompt only when turning on', (
    tester,
  ) async {
    var openedSettings = false;
    final day = LiturgicalCalendar().day(DateTime(2026, 7, 16));
    await tester.pumpWidget(
      _wrap(
        Scaffold(body: DayDetailView(day: day)),
        notificationService: _FakeNotifications(
          enabled: false,
          status: NotificationPermissionStatus.denied,
          onOpenSettings: () => openedSettings = true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(TextButton, '추가'));
    await tester.pumpAndSettle();

    const message = '시스템 알림이 꺼져있어 알림을 보낼수 없습니다. 알림을 설정하시겠습니까?';
    expect(find.text(message), findsNothing);

    await tester.tap(find.widgetWithText(SwitchListTile, '알림'));
    await tester.pumpAndSettle();

    expect(find.text(message), findsOneWidget);
    expect(find.text('아니오'), findsOneWidget);
    expect(find.text('예'), findsOneWidget);

    await tester.tap(find.text('예'));
    await tester.pumpAndSettle();

    expect(openedSettings, isTrue);
  });

  testWidgets('notification toggle requests permission before settings', (
    tester,
  ) async {
    var requestedPermission = false;
    var openedSettings = false;
    final day = LiturgicalCalendar().day(DateTime(2026, 7, 16));
    await tester.pumpWidget(
      _wrap(
        Scaffold(body: DayDetailView(day: day)),
        notificationService: _FakeNotifications(
          enabled: false,
          status: NotificationPermissionStatus.notDetermined,
          requestGranted: true,
          onRequestPermission: () => requestedPermission = true,
          onOpenSettings: () => openedSettings = true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(TextButton, '추가'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(SwitchListTile, '알림'));
    await tester.pumpAndSettle();

    expect(requestedPermission, isTrue);
    expect(openedSettings, isFalse);
    expect(find.text('시스템 알림이 꺼져있어 알림을 보낼수 없습니다. 알림을 설정하시겠습니까?'), findsNothing);
    expect(find.byType(ReminderEditor), findsOneWidget);
  });

  testWidgets('day detail lists stored personal events', (tester) async {
    SharedPreferences.setMockInitialValues({
      'events_v1': jsonEncode({
        '2026-07-16': [
          {
            'id': '1',
            'date': '2026-07-16',
            'categoryId': 'c1',
            'categoryName': '성경 공부',
            'categoryColor': 0xFF2E7D32,
            'time': '19:30',
            'notify': true,
          },
        ],
      }),
    });

    final day = LiturgicalCalendar().day(DateTime(2026, 7, 16));
    await tester.pumpWidget(_wrap(Scaffold(body: DayDetailView(day: day))));
    await tester.pumpAndSettle();

    expect(find.text('일정'), findsOneWidget);
    expect(find.text('성경 공부'), findsOneWidget);
    expect(find.text('19:30'), findsOneWidget);
  });

  testWidgets('day detail hides all-day label text for personal events', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'events_v1': jsonEncode({
        '2026-07-16': [
          {
            'id': '1',
            'date': '2026-07-16',
            'categoryId': 'c1',
            'categoryName': '성경 공부',
            'categoryColor': 0xFF2E7D32,
            'memo': '루카복음',
            'notify': true,
          },
        ],
      }),
    });

    final day = LiturgicalCalendar().day(DateTime(2026, 7, 16));
    await tester.pumpWidget(_wrap(Scaffold(body: DayDetailView(day: day))));
    await tester.pumpAndSettle();

    expect(find.text('성경 공부'), findsOneWidget);
    expect(find.text('루카복음'), findsOneWidget);
    expect(find.text('종일'), findsNothing);
  });

  testWidgets('share button hides for recurring personal events', (
    tester,
  ) async {
    // 반복 일정은 RecurrenceExpander가 앵커 날짜를 그대로 담아 전개하므로,
    // 미래 발생일 상세에서 공유하면 잘못된(최초) 날짜가 공유된다 - 공유 버튼을 숨긴다.
    // 단건(비반복) 일정은 공유 버튼이 그대로 보인다.
    SharedPreferences.setMockInitialValues({
      'events_v1': jsonEncode({
        '2026-07-16': [
          {
            'id': '1',
            'date': '2026-07-16',
            'categoryId': 'c1',
            'categoryName': '성경 공부',
            'categoryColor': 0xFF2E7D32,
            'time': '19:30',
            'notify': true,
            'recurrence': 'weekly',
          },
          {
            'id': '2',
            'date': '2026-07-16',
            'categoryId': 'c2',
            'categoryName': '단건 모임',
            'categoryColor': 0xFF2E7D32,
            'time': '20:00',
            'notify': true,
          },
        ],
      }),
    });

    final day = LiturgicalCalendar().day(DateTime(2026, 7, 16));
    await tester.pumpWidget(_wrap(Scaffold(body: DayDetailView(day: day))));
    await tester.pumpAndSettle();

    expect(find.text('성경 공부'), findsOneWidget);
    expect(find.text('단건 모임'), findsOneWidget);
    // 두 일정 중 반복인 것은 공유 버튼이 없고, 단건 일정만 공유 버튼이 보인다.
    expect(find.byIcon(Icons.ios_share), findsOneWidget);
  });

  testWidgets('bottom info bar summarizes event time category and memo', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'events_v1': jsonEncode({
        '2026-07-16': [
          {
            'id': '1',
            'date': '2026-07-16',
            'categoryId': 'c1',
            'categoryName': '성경 공부',
            'categoryColor': 0xFF2E7D32,
            'memo': '루카복음 긴 메모',
            'time': '19:30',
            'notify': true,
          },
        ],
      }),
    });

    final day = LiturgicalCalendar().day(DateTime(2026, 7, 16));
    await tester.pumpWidget(
      _wrap(
        Scaffold(
          body: DayInfoBar(day: day, onTapDetail: () {}),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('성경 공부'), findsOneWidget);
    final summary = tester.widget<Text>(find.text('19:30 루카복음 긴 메모'));
    expect(summary.maxLines, 1);
    expect(summary.overflow, TextOverflow.ellipsis);
    expect(find.text('[녹]'), findsOneWidget);
    expect(find.text(day.title), findsOneWidget);
    expect(find.text('축일'), findsNothing);
  });

  testWidgets('bottom info bar hides all-day event label text', (tester) async {
    SharedPreferences.setMockInitialValues({
      'events_v1': jsonEncode({
        '2026-07-16': [
          {
            'id': '1',
            'date': '2026-07-16',
            'categoryId': 'c1',
            'categoryName': '성경 공부',
            'categoryColor': 0xFF2E7D32,
            'memo': '루카복음',
            'notify': true,
          },
        ],
      }),
    });

    final day = LiturgicalCalendar().day(DateTime(2026, 7, 16));
    await tester.pumpWidget(
      _wrap(
        Scaffold(
          body: DayInfoBar(day: day, onTapDetail: () {}),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('성경 공부'), findsOneWidget);
    expect(find.text('루카복음'), findsOneWidget);
    expect(find.text('종일'), findsNothing);
  });

  testWidgets('bottom info bar shows a visible 백색 badge for saint memorials', (
    tester,
  ) async {
    // 2026-08-19: 연중 제20주간 수요일(녹색) + 선택 기념 성 요한 외드 사제(백색).
    // 예전에는 이 행에 `축일` 칩을 쓰고 배경으로 백색 토큰(#F8F9FA)을 24% 알파로
    // 깔았다. 카드 표면(#F8F6F0)과 채널당 0~2 차이라 배경이 보이지 않았다.
    // 이제 전례색 배지를 쓰므로 백색은 회색 배경 + 흰 글자가 되어 확실히 보인다.
    final service = CalendarService(
      engine: LiturgicalCalendar(),
      cbck: CalendarService.parseDays(const [
        {
          'date': '2026-08-19',
          'color': 'green',
          'title': '연중 제20주간 수요일',
          'alternatives': [
            {'name': '성 요한 외드 사제', 'color': 'white'},
          ],
        },
      ]),
    );

    await tester.pumpWidget(
      _wrap(
        Scaffold(
          body: DayInfoBar(
            day: service.day(DateTime(2026, 8, 19)),
            onTapDetail: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('[녹]'), findsOneWidget);
    expect(find.text('[백]'), findsOneWidget);
    expect(find.text('연중 제20주간 수요일'), findsOneWidget);
    expect(find.text('성 요한 외드 사제'), findsOneWidget);
    // 종류(축일/전례)는 더 이상 칩에 쓰지 않는다 - 배지는 전례색만 보여준다.
    expect(find.text('축일'), findsNothing);
    expect(find.text('전례'), findsNothing);

    // 백색 배지의 배경이 '거의 흰색'이 아니라 회색이어야 한다.
    final badge = tester.widget<DecoratedBox>(
      find
          .ancestor(of: find.text('[백]'), matching: find.byType(DecoratedBox))
          .first,
    );
    expect(
      (badge.decoration as BoxDecoration).color,
      const Color(0xFF666666).withValues(alpha: 0.92),
    );
  });

  testWidgets('bottom info bar shows the fetched liturgical color', (
    tester,
  ) async {
    final service = CalendarService(
      engine: LiturgicalCalendar(),
      cbck: CalendarService.parseDays(const [
        {'date': '2026-07-25', 'color': 'red', 'title': '성 야고보 사도 축일'},
      ]),
    );

    await tester.pumpWidget(
      _wrap(
        Scaffold(
          body: DayInfoBar(
            day: service.day(DateTime(2026, 7, 25)),
            onTapDetail: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // CBCK가 준 홍색(사도·순교)이 배지로 그대로 드러난다.
    expect(find.text('[홍]'), findsOneWidget);
    expect(find.text('성 야고보 사도 축일'), findsOneWidget);
    expect(find.text('축일'), findsNothing);
    expect(find.text('전례'), findsNothing);
  });

  testWidgets('bottom info bar shows each memorial\'s own liturgical color', (
    tester,
  ) async {
    final service = CalendarService(
      engine: LiturgicalCalendar(),
      cbck: CalendarService.parseDays(const [
        {
          'date': '2026-08-25',
          'color': 'green',
          'title': '연중 제21주간 화요일',
          'alternatives': [
            {'name': '성 루도비코', 'color': 'white'},
            {'name': '성 요셉 데 갈라산즈 사제', 'color': 'white'},
          ],
        },
      ]),
    );

    await tester.pumpWidget(
      _wrap(
        Scaffold(
          body: DayInfoBar(
            day: service.day(DateTime(2026, 8, 25)),
            onTapDetail: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 주 전례는 그날 색(녹), 선택 기념일 둘은 각자의 색(백)을 쓴다.
    expect(find.text('[녹]'), findsOneWidget);
    expect(find.text('[백]'), findsNWidgets(2));
    expect(find.text('연중 제21주간 화요일'), findsOneWidget);
    expect(find.text('성 루도비코'), findsOneWidget);
    expect(find.text('성 요셉 데 갈라산즈 사제'), findsOneWidget);
  });

  testWidgets('bottom info bar shows 백색 badge for a solemnity', (tester) async {
    final day = LiturgicalCalendar().day(DateTime(2026, 12, 25));
    expect(day.celebration.rank, Rank.solemnity);

    await tester.pumpWidget(
      _wrap(
        Scaffold(
          body: DayInfoBar(day: day, onTapDetail: () {}),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('[백]'), findsOneWidget);
    expect(find.text('주님 성탄 대축일'), findsOneWidget);
    expect(find.text('축일'), findsNothing);
  });

  testWidgets('bottom info bar shows 자색 badge for All Souls Day', (tester) async {
    final day = LiturgicalCalendar()
        .day(DateTime(2026, 11, 2))
        .copyWith(title: '죽은 모든 이를 기억하는 위령의 날');
    expect(day.celebration.id, 'all_souls');
    expect(day.celebration.rank, Rank.feast);

    await tester.pumpWidget(
      _wrap(
        Scaffold(
          body: DayInfoBar(day: day, onTapDetail: () {}),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('[자]'), findsOneWidget);
    expect(find.text('죽은 모든 이를 기억하는 위령의 날'), findsOneWidget);
    expect(find.text('축일'), findsNothing);
  });

  testWidgets('bottom info bar badge follows the day color, not celebration color', (
    tester,
  ) async {
    final day = LiturgicalCalendar()
        .day(DateTime(2026, 7, 16))
        .copyWith(
          title: '전례 전용 기념 축일',
          celebration: const Celebration(
            id: 'liturgical_only_feast',
            name: '전례 전용 기념 축일',
            rank: Rank.feast,
            color: LiturgicalColor.white,
            kind: CelebrationKind.sanctorale,
            precedence: PrecedenceCode.generalFeast,
          ),
        );

    await tester.pumpWidget(
      _wrap(
        Scaffold(
          body: DayInfoBar(day: day, onTapDetail: () {}),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('[녹]'), findsOneWidget);
    expect(find.text('전례 전용 기념 축일'), findsOneWidget);
    expect(find.text('축일'), findsNothing);
  });

  testWidgets('bottom info bar badge ignores displayType and rank heuristics', (
    tester,
  ) async {
    final day = LiturgicalCalendar()
        .day(DateTime(2026, 7, 25))
        .copyWith(
          title: '성 야고보 사도 축일',
          celebration: const Celebration(
            id: 'james_apostle',
            name: '성 야고보 사도 축일',
            rank: Rank.feast,
            color: LiturgicalColor.red,
            kind: CelebrationKind.sanctorale,
            precedence: PrecedenceCode.generalFeast,
            displayType: LiturgicalDisplayType.liturgy,
          ),
        );

    await tester.pumpWidget(
      _wrap(
        Scaffold(
          body: DayInfoBar(day: day, onTapDetail: () {}),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('[녹]'), findsOneWidget);
    expect(find.text('성 야고보 사도 축일'), findsOneWidget);
    expect(find.text('축일'), findsNothing);
  });

  testWidgets('day detail uses displayType for 축일 추가 visibility', (
    tester,
  ) async {
    final liturgyRankFeast = LiturgicalCalendar()
        .day(DateTime(2026, 7, 25))
        .copyWith(
          title: '성 야고보 사도 축일',
          celebration: const Celebration(
            id: 'james_apostle',
            name: '성 야고보 사도 축일',
            rank: Rank.feast,
            color: LiturgicalColor.red,
            kind: CelebrationKind.sanctorale,
            precedence: PrecedenceCode.generalFeast,
            displayType: LiturgicalDisplayType.liturgy,
          ),
        );

    await tester.pumpWidget(
      _wrap(Scaffold(body: DayDetailView(day: liturgyRankFeast))),
    );
    await tester.pumpAndSettle();

    expect(find.text('[녹]'), findsOneWidget);
    expect(find.widgetWithText(TextButton, '축일 추가'), findsNothing);

    final saintFeast = liturgyRankFeast.copyWith(
      celebration: liturgyRankFeast.celebration.copyWith(
        displayType: LiturgicalDisplayType.saintFeast,
      ),
    );
    await tester.pumpWidget(
      _wrap(Scaffold(body: DayDetailView(day: saintFeast))),
    );
    await tester.pumpAndSettle();

    // 배지는 종류가 아니라 전례색이므로 displayType과 무관하게 그대로다.
    // `축일 추가` 버튼의 노출만 displayType으로 갈린다.
    expect(find.text('[녹]'), findsOneWidget);
    expect(find.widgetWithText(TextButton, '축일 추가'), findsOneWidget);
  });

  testWidgets('day detail aligns the color badge with the title baseline', (
    tester,
  ) async {
    // 배지는 내부에 vertical 1px 패딩이 있어 `CrossAxisAlignment.start`로 두면
    // 배지 글자가 제목보다 2px 아래로 내려갔다. 상세 화면 제목은 축약하지 않은
    // 전례명이라 두 줄로 넘어갈 수 있어 `center`도 못 쓴다(배지가 두 줄 전체의
    // 중앙에 걸린다). 그래서 첫 줄 베이스라인 정렬이어야 한다.
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final service = CalendarService(
      engine: LiturgicalCalendar(),
      cbck: CalendarService.parseDays(const [
        {
          'date': '2026-08-19',
          'color': 'green',
          'title': '연중 제20주간 수요일',
          'alternatives': [
            {'name': '성 요한 외드 사제', 'color': 'white'},
          ],
        },
      ]),
    );
    final day = service.day(DateTime(2026, 8, 19));

    await tester.pumpWidget(_wrap(Scaffold(body: DayDetailView(day: day))));
    await tester.pumpAndSettle();

    // 두 행 모두 배지 글자와 제목 글자의 위쪽이 같아야 한다(같은 스타일이므로
    // 베이스라인이 맞으면 top도 맞는다).
    expect(
      tester.getRect(find.text('[녹]')).top,
      tester.getRect(find.text('연중 제20주간 수요일')).top,
    );
    expect(
      tester.getRect(find.text('[백]')).top,
      tester.getRect(find.text('성 요한 외드 사제')).top,
    );

    // 제목이 두 줄로 넘어가도 배지는 첫 줄에 붙어 있어야 한다.
    const longTitle = '죽은 모든 이를 기억하는 위령의 날 아주 긴 제목';
    await tester.pumpWidget(
      _wrap(Scaffold(body: DayDetailView(day: day.copyWith(title: longTitle)))),
    );
    await tester.pumpAndSettle();

    final badge = tester.getRect(find.text('[녹]'));
    final title = tester.getRect(find.text(longTitle));
    expect(title.height, greaterThan(badge.height), reason: '두 줄 케이스가 아니다');
    expect(badge.top, title.top);
  });

  testWidgets('adding an event by picking a category persists and shows it', (
    tester,
  ) async {
    final day = LiturgicalCalendar().day(DateTime(2026, 7, 16));
    await tester.pumpWidget(_wrap(Scaffold(body: DayDetailView(day: day))));
    await tester.pumpAndSettle();

    // No events yet.
    expect(find.text('등록된 일정이 없습니다.'), findsOneWidget);

    // Open the editor from the "일정" section.
    await tester.tap(find.widgetWithText(TextButton, '추가'));
    await tester.pumpAndSettle();

    // Open the category screen, tap a seeded category → auto-selected + back.
    await tester.tap(find.text('카테고리를 선택하세요'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('전례'));
    await tester.pumpAndSettle();
    expect(find.text('전례'), findsOneWidget);

    // Save the event.
    await tester.tap(find.widgetWithText(FilledButton, '추가'));
    await tester.pumpAndSettle();

    // Back on the detail view, the new event is listed under its category name.
    expect(find.textContaining('전례'), findsAtLeastNWidgets(1));
    expect(find.text('등록된 일정이 없습니다.'), findsNothing);
  });

  testWidgets('deleting an edited event asks for confirmation', (tester) async {
    final event = CalendarEvent(
      id: '1',
      date: '2026-07-16',
      categoryId: 'c1',
      categoryName: '성경 공부',
      categoryColor: 0xFF2E7D32,
      notify: true,
    );

    await tester.pumpWidget(
      _wrap(
        Builder(
          builder: (context) => FilledButton(
            onPressed: () => showEventEditor(
              context,
              date: DateTime(2026, 7, 16),
              existing: event,
            ),
            child: const Text('열기'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('삭제'));
    await tester.pumpAndSettle();

    expect(
      find.descendant(of: find.byType(AlertDialog), matching: find.text('알림')),
      findsOneWidget,
    );
    expect(find.text('정말로 삭제하시겠습니까?'), findsOneWidget);
    expect(find.text('취소'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, '삭제'), findsOneWidget);
  });

  testWidgets('deleting an edited saint feast asks for confirmation', (
    tester,
  ) async {
    final feast = CalendarEvent(
      id: '1',
      date: '2026-07-16',
      categoryId: 'saint_feast',
      categoryName: '축일',
      categoryColor: kSaintFeastEventColor,
      notify: true,
      type: CalendarEventType.saintFeast,
      saintId: 1,
      saintName: '성 마르코',
      saintUrl: 'https://example.com',
      recurrence: RecurrenceType.yearlyDate,
    );

    await tester.pumpWidget(
      _wrap(SaintFeastEditorPage(date: DateTime(2026, 7, 16), existing: feast)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('삭제'));
    await tester.pumpAndSettle();

    expect(
      find.descendant(of: find.byType(AlertDialog), matching: find.text('알림')),
      findsOneWidget,
    );
    expect(find.text('정말로 삭제하시겠습니까?'), findsOneWidget);
    expect(find.text('취소'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, '삭제'), findsOneWidget);
  });

  testWidgets('saint feast memo wraps while return key stays done', (
    tester,
  ) async {
    final feast = CalendarEvent(
      id: '1',
      date: '2026-07-16',
      categoryId: 'saint_feast',
      categoryName: '축일',
      categoryColor: kSaintFeastEventColor,
      notify: true,
      type: CalendarEventType.saintFeast,
      saintId: 1,
      saintName: '성 마르코',
      saintUrl: 'https://example.com',
      recurrence: RecurrenceType.yearlyDate,
    );

    await tester.pumpWidget(
      _wrap(SaintFeastEditorPage(date: DateTime(2026, 7, 16), existing: feast)),
    );
    await tester.pumpAndSettle();

    final memo = _memoTextField(tester);
    expect(memo.minLines, 1);
    expect(memo.maxLines, isNull);
    expect(memo.keyboardType, TextInputType.text);
    expect(memo.textInputAction, TextInputAction.done);
    expect(memo.inputFormatters, contains(isA<FilteringTextInputFormatter>()));
  });

  testWidgets('category screen lists seeded categories and adds a new one', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(const CategoryPickerPage()));
    await tester.pumpAndSettle();

    expect(find.text('본당 행사'), findsOneWidget);
    expect(find.text('교리'), findsOneWidget);

    await tester.tap(find.widgetWithText(FloatingActionButton, '카테고리 추가'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, '레지오');
    await tester.tap(find.widgetWithText(FilledButton, '추가'));
    await tester.pumpAndSettle();

    expect(find.text('레지오'), findsOneWidget);
  });

  testWidgets('category names are limited to 15 characters', (tester) async {
    await tester.pumpWidget(_wrap(const CategoryPickerPage()));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FloatingActionButton, '카테고리 추가'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextField).first,
      '12345678901234567890',
    );
    await tester.tap(find.widgetWithText(FilledButton, '추가'));
    await tester.pumpAndSettle();

    expect(find.text('123456789012345'), findsOneWidget);
    expect(find.text('1234567890123456'), findsNothing);
  });

  testWidgets('tapping the bottom info area pushes the day detail page', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _wrap(const CalendarPage(month: YearMonth(2026, 7))),
    );
    await tester.pumpAndSettle();

    // The bottom detail area is a tappable InkWell inside the info bar.
    final detailTap = find.descendant(
      of: find.byType(DayInfoBar),
      matching: find.byType(InkWell),
    );
    await tester.tap(detailTap.first);
    await tester.pumpAndSettle();

    // Opens as a pushed full-screen page (not a bottom sheet).
    expect(find.byType(DayDetailPage), findsOneWidget);
  });

  testWidgets('backup notice shows once, when the first add completes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final day = LiturgicalCalendar().day(DateTime(2026, 7, 16));
    await tester.pumpWidget(_wrap(Scaffold(body: DayDetailView(day: day))));
    await tester.pumpAndSettle();

    Future<void> addEventViaEditor() async {
      await tester.tap(find.widgetWithText(TextButton, '추가')); // 상세의 일정 추가
      await tester.pumpAndSettle();
      await tester.tap(find.text('카테고리를 선택하세요')); // 카테고리 화면 열기
      await tester.pumpAndSettle();
      await tester.tap(find.text('전례')); // 선택 → 편집 화면으로 복귀
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, '추가')); // 저장
      await tester.pumpAndSettle();
    }

    // 첫 추가 완료 시점에 백업 안내 노출.
    await addEventViaEditor();
    expect(find.text('내 일정 백업'), findsOneWidget);
    await tester.tap(find.text('확인'));
    await tester.pumpAndSettle();

    // 두 번째 추가부터는 다시 뜨지 않는다.
    await addEventViaEditor();
    expect(find.text('내 일정 백업'), findsNothing);
  });

  testWidgets('category screen edit mode deletes an unused category on save', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(const CategoryPickerPage()));
    await tester.pumpAndSettle();

    // Enter edit mode via the settings button.
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextButton, '저장'), findsOneWidget);

    // Delete '기도' (unused) from the draft, then save.
    final row = find.ancestor(
      of: find.text('기도'),
      matching: find.byType(ListTile),
    );
    await tester.tap(
      find.descendant(of: row, matching: find.byIcon(Icons.delete_outline)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, '저장'));
    await tester.pumpAndSettle();

    expect(find.text('기도'), findsNothing);
    expect(find.text('본당 행사'), findsOneWidget); // 나머지는 유지
  });
}

TextField _memoTextField(WidgetTester tester) {
  return tester.widget<TextField>(
    find.byWidgetPredicate(
      (widget) =>
          widget is TextField && widget.decoration?.labelText == '메모 (선택)',
    ),
  );
}
