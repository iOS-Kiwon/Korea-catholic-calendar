/// A single liturgical celebration (축일/기념일/주일/평일).
library;

import 'package:meta/meta.dart';

import 'enums.dart';
import 'precedence_code.dart';

@immutable
class Celebration {
  const Celebration({
    required this.id,
    required this.name,
    required this.rank,
    required this.color,
    required this.kind,
    required this.precedence,
    this.isProperToKorea = false,
    this.titles = const [],
  });

  /// Stable identifier, e.g. `korean_martyrs`, `advent_sunday_2`.
  final String id;

  /// Display name in the active locale, e.g. `연중 제15주일`,
  /// `성 김대건 안드레아 사제와 성 정하상 바오로와 동료 순교자 대축일`.
  final String name;

  final Rank rank;
  final LiturgicalColor color;
  final CelebrationKind kind;
  final PrecedenceCode precedence;

  /// True for celebrations proper to the Korean calendar (for UI/debugging).
  final bool isProperToKorea;

  /// Optional epithets, e.g. `순교자`, `사제`, `동정녀`.
  final List<String> titles;

  Celebration copyWith({
    String? id,
    String? name,
    Rank? rank,
    LiturgicalColor? color,
    CelebrationKind? kind,
    PrecedenceCode? precedence,
    bool? isProperToKorea,
    List<String>? titles,
  }) {
    return Celebration(
      id: id ?? this.id,
      name: name ?? this.name,
      rank: rank ?? this.rank,
      color: color ?? this.color,
      kind: kind ?? this.kind,
      precedence: precedence ?? this.precedence,
      isProperToKorea: isProperToKorea ?? this.isProperToKorea,
      titles: titles ?? this.titles,
    );
  }

  @override
  String toString() => 'Celebration($id, $name, $rank, $color)';
}
