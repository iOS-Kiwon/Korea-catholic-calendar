import 'package:flutter/services.dart' show rootBundle;
import 'package:liturgical_calendar/liturgical_calendar.dart';

import 'calendar_service.dart';

/// Loads the calendar data from bundled assets and builds a [CalendarService].
///
/// Two layers, both offline:
///  1. The computed engine — from the editable `general/korea/adaptation.json`
///     dataset (any year, no network).
///  2. The authoritative CBCK snapshot — `cbck_days.json`, imported at dev time
///     (`tool/import_cbck.dart`). Used for the exact 명칭·전례색·특별 주일·성경 구절
///     참조·매일미사 링크, falling back to the engine outside its range.
///
/// If any asset fails to load, the engine's built-in fallback is used so the
/// app still works. This is also the seam for a future OTA refresh.
class CalendarDataRepository {
  const CalendarDataRepository();

  Future<CalendarService> load() async {
    final engine = await _loadEngine();
    final cbck = await _loadCbck();
    return CalendarService(engine: engine, cbck: cbck);
  }

  Future<LiturgicalCalendar> _loadEngine() async {
    try {
      final results = await Future.wait([
        rootBundle.loadString('assets/calendar/general.json'),
        rootBundle.loadString('assets/calendar/korea.json'),
        rootBundle.loadString('assets/calendar/adaptation.json'),
      ]);
      final dataset = CalendarDataset.fromJson(
        baseJson: results[0],
        overlayJson: results[1],
        adaptationJson: results[2],
      );
      return LiturgicalCalendar(dataset: dataset);
    } catch (_) {
      return LiturgicalCalendar();
    }
  }

  Future<Map<String, CbckDay>> _loadCbck() async {
    try {
      final json = await rootBundle.loadString(
        'assets/calendar/cbck_days.json',
      );
      return CalendarService.parseSnapshot(json);
    } catch (_) {
      return const {};
    }
  }
}
