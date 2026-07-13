import 'dart:async';
import 'dart:io' show Platform;

import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

bool get _adsSupported => Platform.isAndroid || Platform.isIOS;

const bool adsEnabled = bool.fromEnvironment('ADS_ENABLED');

/// Sets up ads on mobile in the required order:
/// 1) UMP consent (EEA/GDPR), 2) iOS App Tracking Transparency, 3) SDK init.
///
/// Call after the first frame (UI/activity must exist for the consent form and
/// the ATT prompt). No-op off mobile.
Future<void> initAds() async {
  if (!adsEnabled) return;
  if (!_adsSupported) return;
  await _gatherConsent();
  await _requestAtt();
  await MobileAds.instance.initialize();
}

/// Requests the UMP consent info and shows the consent form if required.
Future<void> _gatherConsent() {
  final done = Completer<void>();
  ConsentInformation.instance.requestConsentInfoUpdate(
    ConsentRequestParameters(),
    () => ConsentForm.loadAndShowConsentFormIfRequired((_) {
      if (!done.isCompleted) done.complete();
    }),
    (error) {
      if (!done.isCompleted) done.complete();
    },
  );
  return done.future;
}

/// Shows the iOS ATT prompt once (when still undetermined).
Future<void> _requestAtt() async {
  if (!Platform.isIOS) return;
  final status = await AppTrackingTransparency.trackingAuthorizationStatus;
  if (status == TrackingStatus.notDetermined) {
    // Small delay so the app is active before the system prompt appears.
    await Future<void>.delayed(const Duration(milliseconds: 200));
    await AppTrackingTransparency.requestTrackingAuthorization();
  }
}

/// The banner ad unit id.
///
/// Release builds use the real per-platform units; debug builds always use
/// Google's test units, per AdMob policy (never click your own live ads in
/// development).
String get _bannerAdUnitId {
  final isIOS = Platform.isIOS;
  if (kReleaseMode) {
    return isIOS
        ? 'ca-app-pub-5980133283002959/3997553939' // iOS 실 배너
        : 'ca-app-pub-5980133283002959/6029655050'; // Android 실 배너
  }
  return isIOS
      ? 'ca-app-pub-3940256099942544/2934735716' // iOS 테스트 배너
      : 'ca-app-pub-3940256099942544/6300978111'; // Android 테스트 배너
}

/// Anchored adaptive banner pinned to the bottom of every screen, kept just
/// above the bottom safe-area inset (iOS home indicator).
class BottomAdBanner extends StatefulWidget {
  const BottomAdBanner({super.key});

  @override
  State<BottomAdBanner> createState() => _BottomAdBannerState();
}

class _BottomAdBannerState extends State<BottomAdBanner> {
  BannerAd? _ad;
  bool _loaded = false;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started && adsEnabled && _adsSupported) {
      _started = true;
      _load();
    }
  }

  void _load() {
    final ad = BannerAd(
      size: AdSize.banner,
      adUnitId: _bannerAdUnitId,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, error) => ad.dispose(),
      ),
    );
    _ad = ad;
    ad.load();
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!adsEnabled) return const SizedBox.shrink();
    if (!_adsSupported) return const SizedBox.shrink();
    final bannerHeight = AdSize.banner.height.toDouble();

    // SafeArea(top:false) keeps the ad just above the home indicator. Reserve
    // banner height before load so the calendar layout always has an ad slot.
    return SafeArea(
      top: false,
      child: (_loaded && _ad != null)
          ? SizedBox(
              height: _ad!.size.height.toDouble(),
              width: double.infinity,
              child: Center(
                child: SizedBox(
                  width: _ad!.size.width.toDouble(),
                  height: _ad!.size.height.toDouble(),
                  child: AdWidget(ad: _ad!),
                ),
              ),
            )
          : SizedBox(height: bannerHeight, width: double.infinity),
    );
  }
}
