import 'package:shared_preferences/shared_preferences.dart';

const kRemoteRefreshTtlHours = int.fromEnvironment(
  'KCC_REMOTE_REFRESH_TTL_HOURS',
  defaultValue: 24,
);

class RemoteCalendarRefreshStore {
  const RemoteCalendarRefreshStore({
    required SharedPreferences prefs,
    this.ttl = const Duration(hours: kRemoteRefreshTtlHours),
    DateTime Function()? clock,
  }) : _prefs = prefs,
       _clock = clock;

  final SharedPreferences _prefs;
  final Duration ttl;
  final DateTime Function()? _clock;

  DateTime get _now => _clock?.call() ?? DateTime.now();

  bool shouldRefresh(String monthKey) {
    if (ttl <= Duration.zero) return true;

    final raw = _prefs.getString(_key(monthKey));
    if (raw == null) return true;

    final checkedAt = DateTime.tryParse(raw);
    if (checkedAt == null) return true;

    return _now.difference(checkedAt) >= ttl;
  }

  Future<void> markChecked(String monthKey) {
    return _prefs.setString(_key(monthKey), _now.toIso8601String());
  }

  static String _key(String monthKey) =>
      'calendar_remote_month_checked_v1_$monthKey';
}
