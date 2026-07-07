import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

import 'app/app.dart';
import 'features/ads/ads.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Clean web URLs (/2026/07) instead of hash-based routing.
  if (kIsWeb) {
    usePathUrlStrategy();
  }
  await initAds(); // no-op off mobile
  runApp(const ProviderScope(child: CatholicCalendarApp()));
}
