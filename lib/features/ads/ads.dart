// AdMob integration entry point.
//
// Resolves to the mobile implementation on iOS/Android (where
// `google_mobile_ads` is available) and to a no-op stub everywhere else
// (web/desktop), so the web build never imports the mobile-only plugin.
export 'ads_stub.dart' if (dart.library.io) 'ads_mobile.dart';
