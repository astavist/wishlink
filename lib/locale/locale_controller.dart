import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _localePreferenceKey = 'wishlink.locale';

const Locale _turkishLocale = Locale('tr', 'TR');
const Locale _englishLocale = Locale('en', 'US');

/// Manages the active [Locale] selection and persists it between launches.
class LocaleController extends ChangeNotifier {
  Locale _locale = _englishLocale;

  Locale get locale => _locale;

  Future<void> loadPreferredLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final storedValue = prefs.getString(_localePreferenceKey);

    if (storedValue != null) {
      _locale = _stringToLocale(storedValue);
    } else {
      _locale = _resolveLocaleFromDevice();
      await prefs.setString(_localePreferenceKey, _localeToString(_locale));
    }
    notifyListeners();
  }

  Future<void> updateLocale(Locale locale) async {
    if (_locale == locale) {
      return;
    }

    _locale = locale;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localePreferenceKey, _localeToString(locale));
  }

  static const supportedLocales = [_turkishLocale, _englishLocale];

  Locale _resolveLocaleFromDevice() {
    final deviceLocale = WidgetsBinding.instance.platformDispatcher.locale;
    if (deviceLocale.languageCode.toLowerCase() == 'tr') {
      return _turkishLocale;
    }
    return _englishLocale;
  }

  static Locale _stringToLocale(String value) {
    switch (value) {
      case 'tr_TR':
        return _turkishLocale;
      case 'en_US':
      default:
        return _englishLocale;
    }
  }

  static String _localeToString(Locale locale) {
    final code = locale.languageCode.toLowerCase();
    return code == 'tr' ? 'tr_TR' : 'en_US';
  }
}

/// Provides access to the [LocaleController] down the widget tree.
class LocaleControllerProvider extends InheritedNotifier<LocaleController> {
  const LocaleControllerProvider({
    required LocaleController controller,
    required super.child,
    super.key,
  }) : super(notifier: controller);

  static LocaleController of(BuildContext context) {
    final provider = context
        .dependOnInheritedWidgetOfExactType<LocaleControllerProvider>();
    assert(
      provider != null,
      'LocaleControllerProvider is missing from the widget tree',
    );
    return provider!.notifier!;
  }

  @override
  bool updateShouldNotify(LocaleControllerProvider oldWidget) {
    return notifier != oldWidget.notifier;
  }
}
