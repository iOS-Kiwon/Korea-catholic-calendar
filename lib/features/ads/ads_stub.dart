import 'package:flutter/widgets.dart';

/// No-op ad support for platforms without AdMob (web/desktop).
Future<void> initAds() async {}

/// Renders nothing off mobile.
class BottomAdBanner extends StatelessWidget {
  const BottomAdBanner({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
