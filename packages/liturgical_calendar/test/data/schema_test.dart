import 'package:liturgical_calendar/liturgical_calendar.dart';
import 'package:liturgical_calendar/src/data/schema.dart';
import 'package:test/test.dart';

void main() {
  group('FixedCelebration.fromJson', () {
    test('parses a fixed-date entry and derives precedence from rank', () {
      final c = FixedCelebration.fromJson({
        'id': 'assumption',
        'month': 8,
        'day': 15,
        'name': '성모 승천 대축일',
        'rank': 'solemnity',
        'color': 'white',
      });
      expect(c.dateIn(2026), DateTime(2026, 8, 15));
      expect(c.rank, Rank.solemnity);
      expect(c.color, LiturgicalColor.white);
      expect(c.precedence, PrecedenceCode.generalSolemnity);
    });

    test('proper solemnity derives properSolemnity precedence', () {
      final c = FixedCelebration.fromJson({
        'id': 'korean_martyrs',
        'month': 9,
        'day': 20,
        'name': '성 김대건 안드레아 사제와 성 정하상 바오로와 동료 순교자 대축일',
        'rank': 'solemnity',
        'color': 'red',
        'properToKorea': true,
        'titles': ['순교자'],
      });
      expect(c.precedence, PrecedenceCode.properSolemnity);
      expect(c.isProperToKorea, isTrue);
      final cel = c.toCelebration();
      expect(cel.kind, CelebrationKind.sanctorale);
      expect(cel.titles, ['순교자']);
    });

    test('easterOffset entry resolves relative to Easter', () {
      final c = FixedCelebration.fromJson({
        'id': 'sacred_heart',
        'easterOffset': 68,
        'name': '예수 성심 대축일',
        'rank': 'solemnity',
        'color': 'white',
      });
      expect(c.dateIn(2026), DateTime(2026, 6, 12)); // Easter 2026 = Apr 5
    });

    test('rejects unknown rank', () {
      expect(
        () => FixedCelebration.fromJson({
          'id': 'x',
          'month': 1,
          'day': 1,
          'name': 'x',
          'rank': 'bogus',
          'color': 'white',
        }),
        throwsA(isA<CalendarDataFormatException>()),
      );
    });

    test('rejects entry without date info', () {
      expect(
        () => FixedCelebration.fromJson({
          'id': 'x',
          'name': 'x',
          'rank': 'feast',
          'color': 'white',
        }),
        throwsA(isA<CalendarDataFormatException>()),
      );
    });
  });

  group('CalendarDataset', () {
    const baseJson = '''
    {"celebrations": [
      {"id":"a","month":1,"day":1,"name":"base A","rank":"feast","color":"white"},
      {"id":"korean_martyrs","month":9,"day":20,"name":"기념일","rank":"obligatoryMemorial","color":"red"}
    ]}''';
    const overlayJson = '''
    {"celebrations": [
      {"id":"korean_martyrs","month":9,"day":20,"name":"대축일","rank":"solemnity","color":"red","properToKorea":true},
      {"id":"new_kr","month":5,"day":29,"name":"새 성인","rank":"optionalMemorial","color":"red","properToKorea":true}
    ]}''';
    const adaptationJson =
        '{"epiphanyOnSunday":true,"ascensionOnSunday":true,"corpusChristiOnSunday":true,"holyDaysOfObligation":["assumption"]}';

    test('overlay overrides base by id and adds new ids', () {
      final ds = CalendarDataset.fromJson(
        baseJson: baseJson,
        overlayJson: overlayJson,
        adaptationJson: adaptationJson,
      );
      final byId = {for (final c in ds.merged) c.id: c};
      expect(byId.length, 3); // a, korean_martyrs (overridden), new_kr
      expect(byId['korean_martyrs']!.rank, Rank.solemnity); // overridden
      expect(byId['korean_martyrs']!.name, '대축일');
      expect(byId['new_kr'], isNotNull);
      expect(ds.adaptation.holyDaysOfObligation, contains('assumption'));
    });
  });
}
