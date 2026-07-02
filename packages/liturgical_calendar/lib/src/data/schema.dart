/// Data schema for the calendar dataset — the flexibility contract.
///
/// Celebration data and the national adaptation policy live as JSON (editable,
/// versionable, over-the-air-updatable). The engine defines the schema and the
/// codec here, and consumes a parsed [CalendarDataset]; it never reads bytes
/// itself, which keeps it pure and testable.
library;

import 'dart:convert';

import '../core/computus.dart';
import '../core/temporale.dart';
import '../model/celebration.dart';
import '../model/enums.dart';
import '../model/precedence_code.dart';

/// Thrown when a dataset document fails schema validation.
class CalendarDataFormatException implements Exception {
  CalendarDataFormatException(this.message);
  final String message;
  @override
  String toString() => 'CalendarDataFormatException: $message';
}

const _rankByName = {
  'solemnity': Rank.solemnity,
  'feastOfTheLord': Rank.feastOfTheLord,
  'feast': Rank.feast,
  'sunday': Rank.sunday,
  'obligatoryMemorial': Rank.obligatoryMemorial,
  'optionalMemorial': Rank.optionalMemorial,
  'privilegedFeria': Rank.privilegedFeria,
  'feria': Rank.feria,
};

const _colorByName = {
  'white': LiturgicalColor.white,
  'red': LiturgicalColor.red,
  'green': LiturgicalColor.green,
  'violet': LiturgicalColor.violet,
  'rose': LiturgicalColor.rose,
  'black': LiturgicalColor.black,
};

/// Derives the Table-of-Liturgical-Days precedence code for a [rank], given
/// whether the celebration is proper (national/local).
PrecedenceCode precedenceForRank(Rank rank, {required bool proper}) {
  switch (rank) {
    case Rank.solemnity:
      return proper
          ? PrecedenceCode.properSolemnity
          : PrecedenceCode.generalSolemnity;
    case Rank.feastOfTheLord:
      return PrecedenceCode.feastOfTheLord;
    case Rank.feast:
      return proper ? PrecedenceCode.properFeast : PrecedenceCode.generalFeast;
    case Rank.sunday:
      return PrecedenceCode.sunday;
    case Rank.obligatoryMemorial:
      return proper
          ? PrecedenceCode.properObligatoryMemorial
          : PrecedenceCode.generalObligatoryMemorial;
    case Rank.optionalMemorial:
      return PrecedenceCode.optionalMemorial;
    case Rank.privilegedFeria:
      return PrecedenceCode.privilegedWeekday;
    case Rank.feria:
      return PrecedenceCode.weekday;
  }
}

/// One entry in a calendar dataset — a celebration on a fixed date (month/day)
/// or a movable sanctorale date expressed as an offset from Easter.
class FixedCelebration {
  const FixedCelebration({
    required this.id,
    required this.name,
    required this.rank,
    required this.color,
    this.month,
    this.day,
    this.easterOffset,
    this.precedence,
    this.isProperToKorea = false,
    this.titles = const [],
  });

  factory FixedCelebration.fromJson(Map<String, dynamic> json) {
    T require<T>(String key) {
      final v = json[key];
      if (v is! T) {
        throw CalendarDataFormatException(
            'entry "${json['id']}" is missing or has invalid "$key"');
      }
      return v;
    }

    final id = require<String>('id');
    final rankName = require<String>('rank');
    final colorName = require<String>('color');
    final rank = _rankByName[rankName];
    final color = _colorByName[colorName];
    if (rank == null) {
      throw CalendarDataFormatException(
          'entry "$id" has unknown rank "$rankName"');
    }
    if (color == null) {
      throw CalendarDataFormatException(
          'entry "$id" has unknown color "$colorName"');
    }

    final month = json['month'] as int?;
    final day = json['day'] as int?;
    final easterOffset = json['easterOffset'] as int?;
    if (easterOffset == null && (month == null || day == null)) {
      throw CalendarDataFormatException(
          'entry "$id" must have either month+day or easterOffset');
    }
    if (month != null && (month < 1 || month > 12)) {
      throw CalendarDataFormatException('entry "$id" has invalid month $month');
    }
    if (day != null && (day < 1 || day > 31)) {
      throw CalendarDataFormatException('entry "$id" has invalid day $day');
    }

    final proper = json['properToKorea'] as bool? ?? false;
    final precedenceName = json['precedence'] as String?;
    final precedence = precedenceName != null
        ? PrecedenceCode.values.firstWhere(
            (p) => p.name == precedenceName,
            orElse: () => throw CalendarDataFormatException(
                'entry "$id" has unknown precedence "$precedenceName"'),
          )
        : precedenceForRank(rank, proper: proper);

    return FixedCelebration(
      id: id,
      name: require<String>('name'),
      rank: rank,
      color: color,
      month: month,
      day: day,
      easterOffset: easterOffset,
      precedence: precedence,
      isProperToKorea: proper,
      titles: (json['titles'] as List?)?.cast<String>() ?? const [],
    );
  }

  final String id;
  final String name;
  final Rank rank;
  final LiturgicalColor color;
  final int? month;
  final int? day;
  final int? easterOffset;
  final PrecedenceCode? precedence;
  final bool isProperToKorea;
  final List<String> titles;

  /// The concrete date this celebration falls on in [year].
  DateTime dateIn(int year) {
    if (easterOffset != null) {
      return addDays(gregorianEaster(year), easterOffset!);
    }
    return DateTime(year, month!, day!);
  }

  Celebration toCelebration() => Celebration(
        id: id,
        name: name,
        rank: rank,
        color: color,
        kind: CelebrationKind.sanctorale,
        precedence:
            precedence ?? precedenceForRank(rank, proper: isProperToKorea),
        isProperToKorea: isProperToKorea,
        titles: titles,
      );
}

/// The national adaptation policy — how Korea adjusts the universal calendar.
class CalendarAdaptation {
  const CalendarAdaptation({
    this.epiphanyOnSunday = true,
    this.ascensionOnSunday = true,
    this.corpusChristiOnSunday = true,
    this.holyDaysOfObligation = const {},
  });

  factory CalendarAdaptation.fromJson(Map<String, dynamic> json) {
    return CalendarAdaptation(
      epiphanyOnSunday: json['epiphanyOnSunday'] as bool? ?? true,
      ascensionOnSunday: json['ascensionOnSunday'] as bool? ?? true,
      corpusChristiOnSunday: json['corpusChristiOnSunday'] as bool? ?? true,
      holyDaysOfObligation:
          ((json['holyDaysOfObligation'] as List?)?.cast<String>() ?? const [])
              .toSet(),
    );
  }

  /// 주님 공현 대축일을 주일(1/2~1/8)로 옮기는지.
  final bool epiphanyOnSunday;

  /// 주님 승천 대축일을 부활 제7주일로 옮기는지.
  final bool ascensionOnSunday;

  /// 성체 성혈 대축일을 삼위일체 다음 주일로 옮기는지.
  final bool corpusChristiOnSunday;

  /// Celebration ids that are holy days of obligation (의무 축일).
  final Set<String> holyDaysOfObligation;
}

/// A full calendar dataset: the General Roman base, a national overlay and the
/// adaptation policy. The [merged] list applies overlay-over-base by id.
class CalendarDataset {
  CalendarDataset({
    required this.base,
    this.overlay = const [],
    this.adaptation = const CalendarAdaptation(),
  });

  /// Parses a dataset from JSON documents. Each celebrations document is
  /// `{"celebrations": [ ... ]}`; the adaptation document is the policy object.
  factory CalendarDataset.fromJson({
    required String baseJson,
    String? overlayJson,
    String? adaptationJson,
  }) {
    return CalendarDataset(
      base: _parseCelebrations(baseJson),
      overlay: overlayJson == null ? const [] : _parseCelebrations(overlayJson),
      adaptation: adaptationJson == null
          ? const CalendarAdaptation()
          : CalendarAdaptation.fromJson(
              jsonDecode(adaptationJson) as Map<String, dynamic>),
    );
  }

  final List<FixedCelebration> base;
  final List<FixedCelebration> overlay;
  final CalendarAdaptation adaptation;

  /// Base entries with overlay entries applied on top: overlay entries with the
  /// same id override base entries; new ids are added.
  List<FixedCelebration> get merged {
    final byId = <String, FixedCelebration>{for (final c in base) c.id: c};
    for (final c in overlay) {
      byId[c.id] = c;
    }
    return byId.values.toList(growable: false);
  }
}

List<FixedCelebration> _parseCelebrations(String source) {
  final doc = jsonDecode(source);
  if (doc is! Map || doc['celebrations'] is! List) {
    throw CalendarDataFormatException(
        'dataset document must be an object with a "celebrations" array');
  }
  return [
    for (final e in doc['celebrations'] as List)
      FixedCelebration.fromJson(e as Map<String, dynamic>),
  ];
}
