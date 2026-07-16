import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class FirebaseBootstrap {
  FirebaseBootstrap._();

  static bool _enabled = false;

  static bool get enabled => _enabled;

  static Future<void> init() async {
    try {
      await Firebase.initializeApp();
      if (!kIsWeb) {
        await FirebaseAppCheck.instance.activate(
          providerAndroid: kDebugMode
              ? const AndroidDebugProvider()
              : const AndroidPlayIntegrityProvider(),
          providerApple: kDebugMode
              ? const AppleDebugProvider()
              : const AppleAppAttestWithDeviceCheckFallbackProvider(),
        );
      }
      _enabled = true;
    } catch (e) {
      _enabled = false;
      if (kDebugMode) {
        debugPrint('Firebase disabled: $e');
      }
    }
  }
}
