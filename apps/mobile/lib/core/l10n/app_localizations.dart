import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../data/models/alarm_category.dart';
import '../../providers/settings_provider.dart';
import 'app_language.dart';
import 'app_translations.dart';

/// Offline-first bilingual localization helper supporting English (`en`) and
/// Bahasa Indonesia (`id`).
class AppLocalizations {
  final AppLanguage language;

  const AppLocalizations(this.language);

  static AppLanguage currentLanguage = AppLanguage.en;
  static bool _dateSymbolsInitialized = false;

  static AppLocalizations get current => AppLocalizations(currentLanguage);

  static const List<Locale> supportedLocales = [
    Locale('en', 'US'),
    Locale('id', 'ID'),
  ];

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = [
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ];

  static Future<void> ensureDateFormatting() async {
    if (_dateSymbolsInitialized) return;
    try {
      await Future.wait([
        initializeDateFormatting('en_US'),
        initializeDateFormatting('id_ID'),
      ]);
      _dateSymbolsInitialized = true;
    } catch (_) {}
  }

  /// Resolves the active [AppLocalizations] safely even inside isolated widget
  /// tests that omit [localizationsDelegates] or [SettingsProvider].
  static AppLocalizations of(BuildContext context) {
    final inherited =
        Localizations.of<AppLocalizations>(context, AppLocalizations);
    if (inherited != null) return inherited;

    try {
      final settings = Provider.of<SettingsProvider>(context, listen: true);
      return AppLocalizations(settings.language);
    } catch (_) {
      return current;
    }
  }

  bool get isIndonesian => language == AppLanguage.id;
  bool get isEnglish => language == AppLanguage.en;
  String get dateLocale => language.dateLocale;

  /// Concise inline selector between English and Bahasa Indonesia strings.
  String pick(String en, String id) => isIndonesian ? id : en;

  /// Dictionary lookup with optional `{placeholder}` interpolation.
  String tr(String key, [Map<String, Object?>? params]) {
    var result = kNestinTranslations[language.code]?[key] ??
        kNestinTranslations['en']?[key] ??
        key;
    if (params != null && params.isNotEmpty) {
      params.forEach((pKey, pVal) {
        result = result.replaceAll('{$pKey}', '${pVal ?? ''}');
      });
    }
    return result;
  }

  /// Formats [date] with the active locale and safely falls back if symbols
  /// have not yet loaded in an isolated sync unit test.
  String formatDate(DateTime date, String pattern) {
    try {
      return DateFormat(pattern, dateLocale).format(date);
    } catch (_) {
      return DateFormat(pattern).format(date);
    }
  }

  String greetingForHour(int hour) {
    if (hour < 12) return tr('greeting_morning');
    if (hour < 17) return tr('greeting_afternoon');
    return tr('greeting_evening');
  }

  String categoryName(AlarmCategoryType type) {
    switch (type) {
      case AlarmCategoryType.wakeUp:
        return tr('cat_wake_up');
      case AlarmCategoryType.work:
        return tr('cat_work');
      case AlarmCategoryType.personal:
        return tr('cat_personal');
      case AlarmCategoryType.health:
        return tr('cat_health');
      case AlarmCategoryType.activities:
        return tr('cat_activities');
      case AlarmCategoryType.other:
        return tr('cat_other');
    }
  }

  String themeModeLabel(ThemeMode mode) => switch (mode) {
        ThemeMode.dark => tr('theme_dark'),
        ThemeMode.light => tr('theme_light'),
        ThemeMode.system => tr('theme_system'),
      };
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      locale.languageCode == 'en' ||
      locale.languageCode == 'id' ||
      locale.languageCode == 'in';

  @override
  Future<AppLocalizations> load(Locale locale) async {
    final lang = AppLanguageExt.fromCode(locale.languageCode);
    AppLocalizations.currentLanguage = lang;
    await AppLocalizations.ensureDateFormatting();
    return SynchronousFuture(AppLocalizations(lang));
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

extension NestinLocalizationContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
