import 'package:flutter/services.dart' show rootBundle;
import 'package:liturgical_calendar/liturgical_calendar.dart';

/// Loads the calendar dataset from bundled JSON assets and builds the engine.
///
/// The JSON files under `assets/calendar/` are the editable source of truth
/// (general 로마력 + 한국 overlay + 조정 정책). If loading or parsing fails, the
/// engine's built-in fallback dataset is used so the app still works offline.
///
/// This is the seam where a future over-the-air (OTA) update would fetch a
/// newer versioned dataset before falling back to the bundled assets.
class CalendarDataRepository {
  const CalendarDataRepository();

  Future<LiturgicalCalendar> load() async {
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
      // Fallback to the engine's built-in dataset.
      return LiturgicalCalendar();
    }
  }
}
