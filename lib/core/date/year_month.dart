import 'package:flutter/foundation.dart';

/// An immutable (year, month) pair used to drive the visible month.
@immutable
class YearMonth {
  const YearMonth(this.year, this.month);

  factory YearMonth.of(DateTime date) => YearMonth(date.year, date.month);

  final int year;
  final int month; // 1..12

  /// Serial index used for [PageView] paging.
  int get serial => year * 12 + (month - 1);

  static YearMonth fromSerial(int serial) =>
      YearMonth(serial ~/ 12, (serial % 12) + 1);

  YearMonth get next => fromSerial(serial + 1);
  YearMonth get previous => fromSerial(serial - 1);

  DateTime get firstDay => DateTime(year, month, 1);
  int get daysInMonth => DateTime(year, month + 1, 0).day;

  @override
  bool operator ==(Object other) =>
      other is YearMonth && other.year == year && other.month == month;

  @override
  int get hashCode => Object.hash(year, month);

  @override
  String toString() => '$year-${month.toString().padLeft(2, '0')}';
}
