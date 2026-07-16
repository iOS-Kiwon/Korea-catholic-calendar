// Local-notification entry point.
//
// Resolves to the mobile implementation on iOS/Android (where
// `flutter_local_notifications` is available) and to a no-op stub everywhere
// else (web/desktop), so the web build never imports the mobile-only plugin.
// Mirrors the conditional-import pattern in `lib/features/ads/ads.dart`.
export 'notification_service.dart';
export 'notifications_stub.dart'
    if (dart.library.io) 'notifications_mobile.dart';
