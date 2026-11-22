import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const res = 'android/app/src/main/res';

  test('shortcuts.xml registers 4 launcher shortcuts + mental aid', () {
    final xml = File('$res/xml/shortcuts.xml').readAsStringSync();
    for (final id in [
      'launcher_quick_capture',
      'launcher_new_alarm',
      'launcher_water',
      'launcher_rain',
      'mental_aid_immediate_support',
    ]) {
      expect(xml, contains('android:shortcutId="$id"'));
    }
    expect(xml, contains('nestin://quick_capture?type=note'));
    expect(xml, contains('nestin://new_alarm'));
    expect(xml, contains('nestin://hydration?action=add_glass'));
    expect(xml, contains('nestin://play_sound?id=rain&amp;minutes=30'));
  });

  test('icons and EN/ID strings exist for every launcher shortcut', () {
    for (final n in ['quick_capture', 'new_alarm', 'water', 'rain']) {
      expect(File('$res/drawable/ic_shortcut_$n.xml').existsSync(), isTrue);
      for (final dir in ['values', 'values-id', 'values-in']) {
        final s = File('$res/$dir/strings.xml').readAsStringSync();
        for (final k in ['short_label', 'long_label', 'disabled_message']) {
          expect(s, contains('name="shortcut_${n}_$k"'));
        }
      }
    }
  });

  test('Dart deep-link router handles water and play_sound hosts', () {
    final src = File('lib/ui/screens/main_navigation_screen.dart')
        .readAsStringSync();
    expect(src, contains("uri.host == 'play_sound'"));
    expect(src, contains("== 'add_glass'"));
    expect(src, contains("uri.host == 'new_alarm'"));
    expect(src, contains("uri.host == 'quick_capture'"));
  });

  test('toast strings exist in EN/ID translations and ARBs', () {
    final t = File('lib/core/l10n/app_translations.dart').readAsStringSync();
    final en = File('assets/l10n/app_en.arb').readAsStringSync();
    final id = File('assets/l10n/app_id.arb').readAsStringSync();
    for (final k in ['shortcut_water_logged', 'shortcut_sound_playing']) {
      expect(RegExp("'$k'").allMatches(t).length, 2);
      expect(en, contains('"$k"'));
      expect(id, contains('"$k"'));
    }
  });
}
