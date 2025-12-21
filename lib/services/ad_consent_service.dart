import 'dart:async';

import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Handles ATT + UMP consent flow and exposes ad request preferences.
class AdConsentService {
  AdConsentService._();

  static final AdConsentService instance = AdConsentService._();

  bool _initialized = false;
  bool _canServePersonalizedAds = false;

  bool get initialized => _initialized;
  bool get canServePersonalizedAds => _canServePersonalizedAds;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }
    TrackingStatus trackingStatus = TrackingStatus.notSupported;
    if (_isIOS) {
      trackingStatus = await _requestTrackingAuthorization();
    }
    final consentStatus = await _requestUserMessagingConsent();
    final trackingAllowed =
        !_isIOS || trackingStatus == TrackingStatus.authorized;
    _canServePersonalizedAds =
        trackingAllowed && _isConsentSufficient(consentStatus);
    _initialized = true;
  }

  AdRequest buildAdRequest() {
    if (!_initialized) {
      return const AdRequest(nonPersonalizedAds: true);
    }
    return AdRequest(
      nonPersonalizedAds: !_canServePersonalizedAds,
    );
  }

  bool get _isIOS =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  Future<TrackingStatus> _requestTrackingAuthorization() async {
    try {
      var status = await AppTrackingTransparency.trackingAuthorizationStatus;
      if (status == TrackingStatus.notDetermined) {
        status = await AppTrackingTransparency.requestTrackingAuthorization();
      }
      return status;
    } catch (_) {
      return TrackingStatus.notSupported;
    }
  }

  Future<ConsentStatus> _requestUserMessagingConsent() async {
    final consentInfo = ConsentInformation.instance;
    final updateCompleter = Completer<void>();
    try {
      consentInfo.requestConsentInfoUpdate(
        ConsentRequestParameters(),
        () => updateCompleter.complete(),
        (_) => updateCompleter.complete(),
      );
      await updateCompleter.future;
      await ConsentForm.loadAndShowConsentFormIfRequired((_) {});
    } catch (_) {
      // Ignore and fall back to non-personalized ads.
    }

    try {
      return await consentInfo.getConsentStatus();
    } catch (_) {
      return ConsentStatus.unknown;
    }
  }

  bool _isConsentSufficient(ConsentStatus status) {
    return status == ConsentStatus.obtained ||
        status == ConsentStatus.notRequired;
  }
}
