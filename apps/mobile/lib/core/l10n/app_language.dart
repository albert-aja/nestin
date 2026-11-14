import 'package:flutter/material.dart';

/// Supported display languages in Nestin (100% offline/local-first).
enum AppLanguage {
  en,
  id,
}

extension AppLanguageExt on AppLanguage {
  String get code => switch (this) {
        AppLanguage.en => 'en',
        AppLanguage.id => 'id',
      };

  Locale get locale => switch (this) {
        AppLanguage.en => const Locale('en', 'US'),
        AppLanguage.id => const Locale('id', 'ID'),
      };

  String get dateLocale => switch (this) {
        AppLanguage.en => 'en_US',
        AppLanguage.id => 'id_ID',
      };

  String get nativeName => switch (this) {
        AppLanguage.en => 'English',
        AppLanguage.id => 'Bahasa Indonesia',
      };

  String get englishName => switch (this) {
        AppLanguage.en => 'English',
        AppLanguage.id => 'Indonesian',
      };

  String get shortCode => switch (this) {
        AppLanguage.en => 'EN',
        AppLanguage.id => 'ID',
      };

  String get flag => switch (this) {
        AppLanguage.en => '🇺🇸',
        AppLanguage.id => '🇮🇩',
      };

  static AppLanguage fromCode(String? raw) {
    final norm = (raw ?? '').trim().toLowerCase();
    if (norm == 'id' ||
        norm == 'id_id' ||
        norm == 'id-id' ||
        norm == 'in' ||
        norm == 'indonesian' ||
        norm == 'bahasa indonesia' ||
        norm == 'bahasa') {
      return AppLanguage.id;
    }
    return AppLanguage.en;
  }
}
