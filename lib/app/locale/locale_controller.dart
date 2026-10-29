import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../l10n/app_strings.dart';

final localeControllerProvider = NotifierProvider<LocaleController, Locale>(
  LocaleController.new,
);

class LocaleController extends Notifier<Locale> {
  static const storageKey = 'ui.locale';

  @override
  Locale build() => const Locale('en');

  Future<void> restore() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(storageKey);
    if (code != null && AppStrings.languageNames.containsKey(code)) {
      state = Locale(code);
    }
  }

  Future<void> setLanguage(String code) async {
    if (!AppStrings.languageNames.containsKey(code)) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(storageKey, code);
    state = Locale(code);
  }
}
