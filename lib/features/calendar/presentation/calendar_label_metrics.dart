import 'package:flutter/widgets.dart';

/// 달력 grid 셀 안 전례명 라벨에만 적용하는 폰트 배율 상한.
///
/// 6줄 고정 grid는 셀 하나가 쓸 수 있는 세로 픽셀이 정해져 있어 OS 글꼴 확대를
/// 그대로 반영할 수 없다. 상한이 없으면 배율 2.0에서 폭 약 53px 라벨에 글자가
/// 2~3개만 들어가 오히려 정보가 줄어든다. 1.5로 묶으면 2줄을 확보한다.
///
/// WCAG 1.4.4("200% 확대 시 콘텐츠 손실 금지")를 위반하지 않는 근거: 같은 전례명이
/// 하단 정보 카드(`DayInfoBar`)와 날짜 상세 화면에서 **상한 없이** 전체 배율로
/// 제공된다. 두 화면은 이 상한을 쓰지 않는다.
///
/// 이 절충이 불필요하다면 `double.infinity`로 바꾸면 된다 - 줄 수 강등만으로도
/// 세로 클립은 발생하지 않는다.
const double kGridLabelMaxTextScale = 1.5;

/// 서브픽셀 반올림 여유. `precisionErrorTolerance`(1e-10)는 레이아웃 비교에 너무 작다.
const double kLabelLayoutSlack = 0.5;

/// grid 라벨 서브트리의 텍스트 기하를 결정론적으로 만든다.
///
/// - **배율에 상한을 씌운다.** `_ClampedTextScaler.scale`이 원본 스케일러를 호출한 뒤
///   clamp하므로(painting/text_scaler.dart:130) Android 14+ 비선형 곡선을 훼손하지 않는다.
/// - **굵은 글씨를 끈다.** `Text`는 `MediaQuery.boldTextOf`가 true면 `FontWeight.bold`를
///   자동 merge하는데(widgets/text.dart:722), 한글은 굵어지면 폭이 늘어 줄 수가 증가한다.
///   라벨은 이미 `w600`이라 굵기 대비가 충분하다. 같은 셀의 날짜 숫자와 그 밖 모든
///   화면은 굵게 적용을 그대로 유지한다.
/// - **플랫폼 줄간격/자간 오버라이드를 지운다.** `Text`가 이 값으로 `TextStyle.height`와
///   `StrutStyle.height`를 곱하지 않고 **교체**하므로(widgets/text.dart:1535, :742),
///   남겨두면 [gridLabelLineHeight]의 계산이 실제 렌더와 어긋난다.
///   `MediaQueryData.copyWith`에는 이 네 필드의 파라미터가 아예 없어 항상 기존 값이
///   전파되므로, 반드시 `applyTextStyleOverrides`로 지워야 한다.
class GridLabelTextScope extends StatelessWidget {
  const GridLabelTextScope({
    super.key,
    this.maxScaleFactor = kGridLabelMaxTextScale,
    required this.child,
  });

  final double maxScaleFactor;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return MediaQuery(
      data: media
          .applyTextStyleOverrides(
            lineHeightScaleFactorOverride: null,
            letterSpacingOverride: null,
            wordSpacingOverride: null,
            paragraphSpacingOverride: null,
          )
          .copyWith(
            textScaler: media.textScaler.clamp(maxScaleFactor: maxScaleFactor),
            boldText: false,
          ),
      child: child,
    );
  }
}

/// 라벨 한 줄의 실제 높이(논리 px).
///
/// Android 14+ 비선형 스케일링 때문에 `fontSize * textScaleFactor`는 틀린다.
/// 반드시 `TextScaler.scale()`을 통과시켜야 한다.
///
/// [gridLabelStrut]과 함께 쓰면 이 값이 정확한 줄 높이가 된다.
/// `StrutStyle.fontSize`도 `textScaler.scale()`을 통과하고 `height`는 순수 배수이기
/// 때문이다(painting/text_style.dart:1427-1434).
double gridLabelLineHeight(
  BuildContext context, {
  required double fontSize,
  required double heightFactor,
}) => MediaQuery.textScalerOf(context).scale(fontSize) * heightFactor;

/// [available] 안에 온전히 들어가는 줄 수. 0이면 한 줄도 못 넣는다는 뜻이다.
///
/// `RenderParagraph`는 박스보다 텍스트가 높으면 예외도 경고도 없이 세로로 잘라내고
/// (rendering/paragraph.dart:949, :964), `TextOverflow.ellipsis`는 `maxLines` 초과에만
/// `…`를 넣는다. 따라서 `maxLines`를 이렇게 역산하는 것이 잘림을 막는 유일한 방법이다.
int gridLabelFittingLines({
  required double available,
  required double lineHeight,
  required int maxLines,
}) {
  if (!available.isFinite || lineHeight <= 0 || !lineHeight.isFinite) {
    return maxLines;
  }
  final fits = ((available - kLabelLayoutSlack) / lineHeight).floor();
  return fits.clamp(0, maxLines);
}

/// 글꼴 대체(한글 fallback)와 무관하게 모든 줄 높이를
/// `scale(fontSize) * heightFactor`로 고정한다.
///
/// `leadingDistribution: even`은 M3 2021 geometry와 일치시켜 baseline 위치를
/// 유지하기 위한 것이다(material/typography.dart:2108, :2126).
StrutStyle gridLabelStrut({
  required double fontSize,
  required double heightFactor,
}) => StrutStyle(
  fontSize: fontSize,
  height: heightFactor,
  leading: 0,
  leadingDistribution: TextLeadingDistribution.even,
  forceStrutHeight: true,
);
