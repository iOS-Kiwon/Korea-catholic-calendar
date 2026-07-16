import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

import 'app/app.dart';
import 'core/firebase/firebase_bootstrap.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FirebaseBootstrap.init();
  // Clean web URLs (/2026/07) instead of hash-based routing.
  if (kIsWeb) {
    usePathUrlStrategy();
  }
  // Ads are initialized after the first frame (see CatholicCalendarApp), so the
  // UMP consent form and iOS ATT prompt have a live activity to attach to.
  runApp(const ProviderScope(child: CatholicCalendarApp()));
}
