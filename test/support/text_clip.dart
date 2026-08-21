import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// OS의 글꼴 크기 / 굵은 글씨 / 줄간격 접근성 설정을 주입한다.
/// `addTearDown`으로 테스트가 끝나면 자동 복원한다.
void setSystemTextSettings(
  WidgetTester tester, {
  double textScaleFactor = 1.0,
  bool boldText = false,
  double? lineHeightScaleFactorOverride,
  double? letterSpacingOverride,
}) {
  final dispatcher = tester.platformDispatcher;
  dispatcher.textScaleFactorTestValue = textScaleFactor;
  dispatcher.accessibilityFeaturesTestValue = FakeAccessibilityFeatures(
    boldText: boldText,
  );
  dispatcher.lineHeightScaleFactorOverrideTestValue =
      lineHeightScaleFactorOverride;
  dispatcher.letterSpacingOverrideTestValue = letterSpacingOverride;
  addTearDown(dispatcher.clearAllTestValues);
}

/// 그려진 텍스트 중 세로로 잘린 것이 없음을 단정한다.
///
/// `RenderParagraph`는 박스보다 텍스트가 높으면 예외도 경고도 없이 잘라낸다.
/// `rendering/paragraph.dart:949`
/// ```dart
/// final bool didOverflowHeight = size.height < textSize.height || didExceedMaxLines;
/// ```
/// → `TextOverflow.ellipsis` case에서 `_needsClipping = true`
///
/// 즉 `TextOverflow.ellipsis`는 `maxLines` 초과에만 `…`를 넣고 박스 높이 초과는
/// 조용히 잘라낸다. `RenderFlex` overflow와 달리 아무것도 던지지 않으므로
/// `takeException()`으로는 잡히지 않고, 이렇게 명시적으로 단정해야 한다.
///
/// 위 판정식의 **첫 항만** 재현한다. `didExceedMaxLines`는 정상적인 가로 `…`이고
/// 클립 사각형이 박스와 같아 시각적 손실이 없으므로 포함하면 오탐이 쏟아진다.
void expectNoVerticalTextClip(
  WidgetTester tester, {
  Finder? within,
  double slack = 0.5,
  bool Function(String text)? ignore,
}) {
  final finder = within == null
      ? find.byType(RichText)
      : find.descendant(of: within, matching: find.byType(RichText));

  final clipped = <String>[];
  for (final element in finder.evaluate()) {
    final paragraph = element.renderObject;
    if (paragraph is! RenderParagraph || paragraph.debugNeedsLayout) continue;
    if (ignore != null && ignore(paragraph.text.toPlainText())) continue;
    final box = paragraph.size.height;
    final text = paragraph.textSize.height;
    if (text > box + slack) {
      clipped.add(
        '"${paragraph.text.toPlainText()}" '
        'box=${box.toStringAsFixed(1)} < text=${text.toStringAsFixed(1)} '
        '(maxLines=${paragraph.maxLines})',
      );
    }
  }

  expect(
    clipped,
    isEmpty,
    reason: '세로로 잘린 텍스트 ${clipped.length}건:\n  ${clipped.join('\n  ')}',
  );
}

/// [text]를 그리는 문단 하나만 세로 클립을 확인한다.
void expectTextFits(WidgetTester tester, String text) =>
    expectNoVerticalTextClip(tester, within: find.text(text));

/// 날짜 숫자 문단(`DayNumber`)인지. 순수 숫자만으로 이루어진 텍스트다.
///
/// `DayNumber`는 `bodyLarge`의 M3 `height: 1.50`을 물려받아 18px 글자가 27px
/// 줄 박스를 요구하는데, 원 지름은 고정 34/28px(오늘·선택일은 −4)이다.
/// 와이드 레이아웃의 선택 셀(지름 24)은 **배율 1.0에서도 이미 세로 클립 중**이며,
/// 이는 전례명 라벨과 별개의 알려진 문제로 이번 수정 범위 밖이다.
/// 전례명 라벨 검증이 이 문제에 가려지지 않도록 명시적으로 제외한다.
bool isDateNumber(String text) => RegExp(r'^\d+$').hasMatch(text);
