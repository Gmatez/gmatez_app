import 'package:shared_preferences/shared_preferences.dart';

class PreferencesStore {
  PreferencesStore(this._prefs);

  final SharedPreferences _prefs;

  static const _themeKey = 'ui.theme_mode';

  String? get themeMode => _prefs.getString(_themeKey);

  Future<void> setThemeMode(String value) => _prefs.setString(_themeKey, value);
}
