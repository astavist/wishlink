import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _themePreferenceKey = 'wishlink.themeMode';

/// Manages the selected [ThemeMode] and persists it across launches.
class ThemeController extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;

  ThemeMode get themeMode => _themeMode;

  Future<void> loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final storedValue = prefs.getString(_themePreferenceKey);
    _themeMode = _stringToThemeMode(storedValue);
    notifyListeners();
  }

  Future<void> updateThemeMode(ThemeMode mode) async {
    if (mode == _themeMode) {
      return;
    }

    _themeMode = mode;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themePreferenceKey, _themeModeToString(mode));
  }

  static ThemeMode _stringToThemeMode(String? value) {
    switch (value) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
      default:
        return ThemeMode.system;
    }
  }

  static String _themeModeToString(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
      default:
        return 'system';
    }
  }
}

/// Provides access to the [ThemeController] down the widget tree.
class ThemeControllerProvider extends InheritedNotifier<ThemeController> {
  const ThemeControllerProvider({
    required ThemeController controller,
    required super.child,
    super.key,
  }) : super(notifier: controller);

  static ThemeController of(BuildContext context) {
    final provider = context.dependOnInheritedWidgetOfExactType<
        ThemeControllerProvider>();
    assert(
      provider != null,
      'ThemeControllerProvider is missing from the widget tree',
    );
    return provider!.notifier!;
  }

  @override
  bool updateShouldNotify(ThemeControllerProvider oldWidget) {
    return notifier != oldWidget.notifier;
  }
}
