import 'dart:convert';

import 'package:flutter/foundation.dart' show visibleForTesting;

import '../events/model/calendar_event.dart';

const String kShareHost = 'kcc.sidore.org';
const String kShareScheme = 'catholiccalendar';
const int kShareSchemaVersion = 1;
const int _memoMax = 100;

/// 공유 링크에 담긴 단건 개인 일정. categoryName/categoryColor는 전달용이며
/// 받는 화면에서는 사용하지 않는다(향후 사용 대비).
class SharedEventDraft {
  const SharedEventDraft({
    required this.date,
    this.endDate,
    this.time,
    this.endTime,
    this.memo,
    this.categoryName,
    this.categoryColor,
  });
  final String date; // YYYY-MM-DD
  final String? endDate;
  final String? time; // HH:mm
  final String? endTime;
  final String? memo;
  final String? categoryName;
  final int? categoryColor;
}

sealed class ShareLinkOutcome {
  const ShareLinkOutcome();
}

class ShareLinkDraft extends ShareLinkOutcome {
  const ShareLinkDraft(this.draft);
  final SharedEventDraft draft;
}

class ShareLinkInvalid extends ShareLinkOutcome {
  const ShareLinkInvalid();
}

class ShareLinkNeedsUpdate extends ShareLinkOutcome {
  const ShareLinkNeedsUpdate();
}

final RegExp _ymd = RegExp(r'^\d{4}-\d{2}-\d{2}$');
final RegExp _hm = RegExp(r'^\d{2}:\d{2}$');

String _encode(Map<String, dynamic> json) =>
    base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');

Map<String, dynamic>? _decode(String payload) {
  try {
    var p = payload;
    final pad = p.length % 4;
    if (pad != 0) p += '=' * (4 - pad);
    final obj = jsonDecode(utf8.decode(base64Url.decode(p)));
    return obj is Map<String, dynamic> ? obj : null;
  } catch (_) {
    return null;
  }
}

Uri buildShareUri(CalendarEvent e) {
  final memo = e.memo?.trim();
  final json = <String, dynamic>{
    'v': kShareSchemaVersion,
    'd': e.date,
    if (e.effectiveEndDate != e.date) 'ed': e.effectiveEndDate,
    if (e.time != null) 't': e.time,
    if (e.endTime != null && e.endTime != e.time) 'et': e.endTime,
    'n': e.categoryName,
    'c': e.categoryColor,
    if (memo != null && memo.isNotEmpty) 'm': memo,
  };
  return Uri.parse('https://$kShareHost/e/${_encode(json)}');
}

String buildShareText(CalendarEvent e) {
  final label = _humanDateLabel(e.date, e.time);
  final memo = e.memo?.trim();
  final b = StringBuffer('[가톨릭 달력] $label 일정을 공유했어요');
  if (memo != null && memo.isNotEmpty) b.write('\n(메모: $memo)');
  b.write('\n내 달력에 추가: ${buildShareUri(e)}');
  return b.toString();
}

String _humanDateLabel(String ymd, String? time) {
  final parts = ymd.split('-');
  final m = int.tryParse(parts.length > 1 ? parts[1] : '') ?? 0;
  final d = int.tryParse(parts.length > 2 ? parts[2] : '') ?? 0;
  final base = '$m월 $d일';
  if (time == null) return '$base 종일';
  return '$base $time';
}

String? _extractPayload(Uri uri) {
  if (uri.host == kShareHost) {
    final s = uri.pathSegments;
    if (s.length >= 2 && s[0] == 'e') return s.sublist(1).join('/');
    return null;
  }
  if (uri.scheme == kShareScheme) {
    if (uri.host == 'e') return uri.pathSegments.join('/');
    final s = uri.pathSegments;
    if (s.isNotEmpty && s[0] == 'e') return s.sublist(1).join('/');
    return null;
  }
  return null;
}

ShareLinkOutcome resolveIncomingLink(Uri uri) {
  final payload = _extractPayload(uri);
  if (payload == null || payload.isEmpty) return const ShareLinkInvalid();
  final json = _decode(payload);
  if (json == null) return const ShareLinkInvalid();

  final v = json['v'];
  if (v is! int || v < 1) return const ShareLinkInvalid();
  if (v > kShareSchemaVersion) return const ShareLinkNeedsUpdate();

  final d = json['d'];
  if (d is! String || !_ymd.hasMatch(d)) return const ShareLinkInvalid();
  final t = json['t'];
  final et = json['et'];
  if (t != null && (t is! String || !_hm.hasMatch(t))) return const ShareLinkInvalid();
  if (et != null && (et is! String || !_hm.hasMatch(et))) return const ShareLinkInvalid();

  final ed = json['ed'];
  final m = json['m'];
  final memo = m is String ? (m.length > _memoMax ? m.substring(0, _memoMax) : m) : null;

  return ShareLinkDraft(SharedEventDraft(
    date: d,
    endDate: (ed is String && _ymd.hasMatch(ed)) ? ed : null,
    time: t as String?,
    endTime: et as String?,
    memo: memo,
    categoryName: json['n'] is String ? json['n'] as String : null,
    categoryColor: json['c'] is int ? json['c'] as int : null,
  ));
}

@visibleForTesting
String encodeTestPayload(Map<String, dynamic> json) => _encode(json);
