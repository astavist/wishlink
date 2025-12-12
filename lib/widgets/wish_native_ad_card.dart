import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class WishNativeAdCard extends StatefulWidget {
  const WishNativeAdCard({super.key});

  @override
  State<WishNativeAdCard> createState() => _WishNativeAdCardState();
}

class _WishNativeAdCardState extends State<WishNativeAdCard> {
  static const String _iosAdUnitId = String.fromEnvironment(
    'ADMOB_IOS_AD_UNIT_ID',
  );
  static const String _androidAdUnitId = String.fromEnvironment(
    'ADMOB_ANDROID_AD_UNIT_ID',
  );
  static const String _iosTestAdUnitId =
      'ca-app-pub-3940256099942544/3986624511';
  static const String _androidTestAdUnitId =
      'ca-app-pub-3940256099942544/2247696110';

  NativeAd? _nativeAd;
  bool _isLoaded = false;
  bool _hasError = false;
  bool _isLoading = false;
  Brightness? _currentBrightness;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final brightness = Theme.of(context).brightness;
    if (_currentBrightness != brightness) {
      _currentBrightness = brightness;
      _reloadAd();
    }
  }

  @override
  void dispose() {
    _nativeAd?.dispose();
    super.dispose();
  }

  void _reloadAd() {
    _nativeAd?.dispose();
    _nativeAd = null;
    _isLoaded = false;
    _hasError = false;
    _isLoading = false;
    _loadAd();
  }

  void _loadAd() {
    if (_isLoading) {
      return;
    }
    final brightness = _currentBrightness;
    if (brightness == null) {
      return;
    }

    final adUnitId = _resolveAdUnitId();
    if (adUnitId.isEmpty) {
      setState(() => _hasError = true);
      return;
    }

    _isLoading = true;
    final isDark = brightness == Brightness.dark;
    final nativeAd = NativeAd(
      adUnitId: adUnitId,
      factoryId: 'wishlinkActivity',
      request: const AdRequest(),
      customOptions: {'isDark': isDark},
      listener: NativeAdListener(
        onAdLoaded: (ad) {
          if (!mounted) return;
          setState(() {
            _nativeAd = ad as NativeAd;
            _isLoaded = true;
            _isLoading = false;
          });
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          if (!mounted) return;
          setState(() {
            _nativeAd = null;
            _isLoaded = false;
            _hasError = true;
            _isLoading = false;
          });
        },
      ),
    );
    nativeAd.load();
    _nativeAd = nativeAd;
  }

  String _resolveAdUnitId() {
    if (Platform.isIOS) {
      return kDebugMode ? _iosTestAdUnitId : _iosAdUnitId;
    }
    if (Platform.isAndroid) {
      return kDebugMode ? _androidTestAdUnitId : _androidAdUnitId;
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return const SizedBox.shrink();
    }
    if (!_isLoaded || _nativeAd == null) {
      return const SizedBox(
        height: 280,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.of(context).size.width;
        final contentHeight = (availableWidth * 0.95 + 60).clamp(360.0, 600.0);
        return ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: SizedBox(
            height: contentHeight,
            width: double.infinity,
            child: AdWidget(ad: _nativeAd!),
          ),
        );
      },
    );
  }
}
