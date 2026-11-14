import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/l10n/app_language.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/user_preferences.dart';
import '../../../data/models/challenge_profile.dart';
import '../../../providers/settings_provider.dart';
import '../../../providers/sound_provider.dart';
import '../../../data/models/wearable_source.dart';
import '../../../providers/wearable_provider.dart';
import '../../../providers/oem_hardening_provider.dart';
import '../../../providers/geofence_provider.dart';
import '../../../providers/money_provider.dart';
import '../../../providers/device_control_provider.dart';
import '../../../data/models/location_reminder.dart';
import '../../widgets/wearable_sync_sheet.dart';
import '../../widgets/oem_hardening_sheet.dart';
import '../../widgets/location_reminders_sheet.dart';
import '../../widgets/money/money_editor_dialogs.dart';
import '../../widgets/nestin_brand_header.dart';
import '../../widgets/security_pin_gate_sheet.dart';
import '../../widgets/nestin_account_sheet.dart';
import '../alarms/sound_picker_sheet.dart';
import '../scout/digital_wellbeing_screen.dart';
import '../automation/automation_hub_screen.dart';
import 'permission_center_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  void _showGlobalChallengeEditor(
      BuildContext context, SettingsProvider provider) {
    final l10n = context.l10n;
    var profile = provider.globalChallengeProfile;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                left: 20,
                right: 20,
                top: 20,
              ),
              decoration: BoxDecoration(
                color: AppColors.sheetSurface(context),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          l10n.tr('global_challenge_profile'),
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w800),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                        border:
                            Border.all(color: AppColors.accent.withOpacity(0.3)),
                      ),
                      child: Text(
                        l10n.tr('global_challenge_banner'),
                        style: const TextStyle(fontSize: 12, color: AppColors.accent),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SwitchListTile(
                      title: Text(l10n.tr('wake_up_challenge_active')),
                      value: profile.isEnabled,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (val) {
                        setState(() {
                          profile = profile.copyWith(isEnabled: val);
                        });
                      },
                    ),
                    if (profile.isEnabled) ...[
                      const SizedBox(height: 10),
                      DropdownButtonFormField<ChallengeType>(
                        value: profile.type,
                        decoration: InputDecoration(
                          labelText: l10n.tr('default_challenge_type'),
                        ),
                        items: [
                          DropdownMenuItem(
                            value: ChallengeType.math,
                            child: Text(l10n.tr('challenge_math')),
                          ),
                          DropdownMenuItem(
                            value: ChallengeType.memory,
                            child: Text(l10n.tr('challenge_memory')),
                          ),
                          DropdownMenuItem(
                            value: ChallengeType.typing,
                            child: Text(l10n.tr('challenge_typing')),
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => profile = profile.copyWith(type: val));
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<ChallengeDifficulty>(
                        value: profile.difficulty,
                        decoration: InputDecoration(
                          labelText: l10n.tr('default_difficulty'),
                        ),
                        items: [
                          DropdownMenuItem(
                            value: ChallengeDifficulty.easy,
                            child: Text(l10n.tr('difficulty_easy')),
                          ),
                          DropdownMenuItem(
                            value: ChallengeDifficulty.medium,
                            child: Text(l10n.tr('difficulty_medium')),
                          ),
                          DropdownMenuItem(
                            value: ChallengeDifficulty.hard,
                            child: Text(l10n.tr('difficulty_hard')),
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setState(() =>
                                profile = profile.copyWith(difficulty: val));
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int>(
                        value: profile.questionsCount,
                        decoration: InputDecoration(
                          labelText: l10n.tr('questions_rounds'),
                        ),
                        items: [1, 2, 3, 5].map((cnt) {
                          return DropdownMenuItem(
                            value: cnt,
                            child: Text(
                              l10n.pick(
                                '$cnt ${cnt == 1 ? 'Round' : 'Rounds'}',
                                '$cnt Ronde',
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() =>
                                profile = profile.copyWith(questionsCount: val));
                          }
                        },
                      ),
                      SwitchListTile(
                        title: Text(l10n.tr('allow_snooze_challenge')),
                        value: profile.allowSnoozeDuringChallenge,
                        contentPadding: EdgeInsets.zero,
                        onChanged: (val) {
                          setState(() {
                            profile = profile.copyWith(
                                allowSnoozeDuringChallenge: val);
                          });
                        },
                      ),
                    ],
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () {
                        provider.updateGlobalChallengeProfile(profile);
                        Navigator.of(context).pop();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        l10n.tr('save_global_profile'),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final provider = Provider.of<SettingsProvider>(context);
    final prefs = provider.preferences;
    final globalProfile = prefs.globalChallengeProfile;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.tr('settings')),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          NestinBrandHeader(
            subtitle: l10n.tr('settings_subtitle'),
          ),
          const SizedBox(height: 16),

          // Wake-Up Challenge Global Defaults Card
          Card(
            child: InkWell(
              onTap: () => _showGlobalChallengeEditor(context, provider),
              borderRadius: BorderRadius.circular(18),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.accent.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.psychology_rounded,
                              color: AppColors.accent, size: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.tr('global_challenge_profile'),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                l10n.tr('global_challenge_subtitle'),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary(context),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right_rounded,
                            color: AppColors.textSecondary(context)),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.elevatedSurface(context),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              globalProfile.isEnabled
                                  ? l10n.pick(
                                      '${globalProfile.typeLabel} • ${globalProfile.difficultyLabel} (${globalProfile.questionsCount} rounds)',
                                      '${globalProfile.typeLabel} • ${globalProfile.difficultyLabel} (${globalProfile.questionsCount} ronde)',
                                    )
                                  : l10n.tr('disabled_by_default'),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: globalProfile.isEnabled
                                    ? AppColors.adaptive(
                                        context,
                                        dark: AppColors.accent,
                                        light: const Color(0xFFC26A00),
                                      )
                                    : AppColors.textSecondary(context),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            l10n.tr('edit'),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.adaptive(
                                context,
                                dark: AppColors.primaryLight,
                                light: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // General Preferences
          Text(
            l10n.tr('general_preferences'),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Card(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.translate_rounded),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.tr('language_title'),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  l10n.tr('language_subtitle'),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary(context),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: AppLanguage.values.map((lang) {
                          final selected = prefs.language == lang;
                          return ChoiceChip(
                            label: Text('${lang.flag} ${lang.nativeName}'),
                            selected: selected,
                            selectedColor:
                                AppColors.accent.withValues(alpha: 0.22),
                            backgroundColor: AppColors.elevatedSurface(context),
                            labelStyle: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: selected
                                  ? AppColors.accent
                                  : AppColors.textSecondary(context),
                            ),
                            side: BorderSide(
                              color: selected
                                  ? AppColors.accent
                                  : Colors.transparent,
                            ),
                            onSelected: (val) {
                              if (val) provider.setLanguage(lang);
                            },
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  secondary: const Icon(Icons.schedule_rounded),
                  title: Text(l10n.tr('time_format_24h')),
                  subtitle: Text(l10n.tr('time_format_subtitle')),
                  value: prefs.use24Hour,
                  onChanged: (val) => provider.toggle24Hour(val),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.palette_outlined),
                  title: Text(l10n.tr('theme_mode')),
                  subtitle: Text(l10n.themeModeLabel(prefs.themeMode).toUpperCase()),
                  trailing: DropdownButton<ThemeMode>(
                    value: prefs.themeMode,
                    underline: const SizedBox(),
                    items: [
                      DropdownMenuItem(
                        value: ThemeMode.dark,
                        child: Text(l10n.tr('theme_dark')),
                      ),
                      DropdownMenuItem(
                        value: ThemeMode.light,
                        child: Text(l10n.tr('theme_light')),
                      ),
                      DropdownMenuItem(
                        value: ThemeMode.system,
                        child: Text(l10n.tr('theme_system')),
                      ),
                    ],
                    onChanged: (mode) {
                      if (mode != null) provider.setThemeMode(mode);
                    },
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.snooze_rounded),
                  title: Text(l10n.tr('default_snooze')),
                  trailing: DropdownButton<int>(
                    value: prefs.defaultSnoozeMinutes,
                    underline: const SizedBox(),
                    items: [5, 9, 10, 15].map((m) {
                      return DropdownMenuItem(
                        value: m,
                        child: Text(
                          l10n.pick('$m mins', '$m menit'),
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) provider.updateDefaultSnooze(val);
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Sound Defaults
          Text(
            l10n.tr('audio_volume_defaults'),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        l10n.tr('default_alarm_volume'),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        '${(prefs.defaultVolume * 100).round()}%',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                  Slider(
                    value: prefs.defaultVolume,
                    min: 0.1,
                    max: 1.0,
                    divisions: 9,
                    activeColor: AppColors.primary,
                    onChanged: (val) => provider.updateDefaultVolume(val),
                  ),
                  SwitchListTile(
                    title: Text(l10n.tr('gradual_volume_ramp')),
                    subtitle: Text(
                      l10n.tr('rises_over_seconds', {
                        'seconds': prefs.defaultGradualSeconds,
                      }),
                    ),
                    value: prefs.defaultGradualVolume,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (val) {
                      provider.updateGradualVolume(
                        enabled: val,
                        durationSeconds: prefs.defaultGradualSeconds,
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Custom Sound Library Card
          Text(
            l10n.tr('custom_ringtone_library'),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Consumer<SoundProvider>(
            builder: (context, soundProvider, _) {
              final customSounds = soundProvider.customSounds;

              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.accent.withOpacity(0.18),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.audio_file_rounded,
                                color: AppColors.accent, size: 24),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.tr('imported_audio_files'),
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  l10n.pick(
                                    '${customSounds.length} custom ${customSounds.length == 1 ? 'sound' : 'sounds'} in library',
                                    '${customSounds.length} suara kustom di pustaka',
                                  ),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary(context),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            SoundPickerSheet.show(
                              context,
                              currentSoundId: prefs.defaultSound,
                            );
                          },
                          icon: const Icon(Icons.library_music_rounded, size: 18),
                          label: Text(l10n.tr('manage_import_sounds')),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.textPrimary(context),
                            side: BorderSide(color: AppColors.border(context)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 20),

          // Privacy & Security Lock
          Text(
            l10n.tr('privacy_security_journal'),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    secondary: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.lock_rounded,
                        color: AppColors.accent,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      l10n.tr('lock_private_diary'),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: Text(
                      l10n.tr('require_pin_biometric'),
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary(context),
                      ),
                    ),
                    value: provider.isDiaryLockEnabled,
                    activeColor: AppColors.accent,
                    onChanged: (val) async {
                      if (val && !provider.hasPin) {
                        await SecurityPinGateSheet.verifyOrPrompt(context);
                      } else {
                        provider.toggleDiaryLock(val);
                      }
                    },
                  ),
                  const Divider(height: 16),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    secondary: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.fingerprint_rounded,
                        color: AppColors.primaryLight,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      l10n.tr('biometric_quick_unlock'),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: Text(
                      l10n.tr('biometric_subtitle'),
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary(context),
                      ),
                    ),
                    value: provider.isBiometricEnabled,
                    activeColor: AppColors.accent,
                    onChanged: (val) => provider.toggleBiometric(val),
                  ),
                  const Divider(height: 16),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.elevatedSurface(context),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.pin_rounded,
                        color: AppColors.textPrimary(context),
                        size: 20,
                      ),
                    ),
                    title: Text(
                      provider.hasPin
                          ? l10n.pick(
                              'Change Security PIN (4–8 digits)',
                              'Ubah PIN Keamanan (4–8 digit)',
                            )
                          : l10n.pick(
                              'Set Security PIN (4–8 digits)',
                              'Atur PIN Keamanan (4–8 digit)',
                            ),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: Text(
                      provider.hasPin
                          ? (provider.hasPinHint
                              ? l10n.pick(
                                  'PIN & clue configured',
                                  'PIN & petunjuk sudah diatur',
                                )
                              : l10n.pick(
                                  'PIN configured • tap to change or add clue',
                                  'PIN aktif • ketuk untuk ubah atau tambah petunjuk',
                                ))
                          : l10n.pick(
                              'Not configured yet',
                              'Belum diatur',
                            ),
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary(context),
                      ),
                    ),
                    trailing: Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.textSecondary(context),
                    ),
                    onTap: () => SecurityPinGateSheet.setupGlobalPin(context),
                  ),
                  const Divider(height: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.timer_outlined,
                              color: AppColors.primaryLight,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.tr('diary_auto_lock_timeout'),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  provider.diaryAutoLockDelay
                                      .localizedDescription(l10n),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary(context),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: DiaryAutoLockDelay.values.map((delay) {
                          final selected =
                              provider.diaryAutoLockDelay == delay;
                          return ChoiceChip(
                            label: Text(delay.localizedLabel(l10n)),
                            selected: selected,
                            selectedColor:
                                AppColors.accent.withValues(alpha: 0.22),
                            backgroundColor:
                                AppColors.elevatedSurface(context),
                            labelStyle: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: selected
                                  ? AppColors.accent
                                  : AppColors.textSecondary(context),
                            ),
                            side: BorderSide(
                              color: selected
                                  ? AppColors.accent
                                  : Colors.transparent,
                            ),
                            onSelected: (val) {
                              if (val) {
                                provider.updateDiaryAutoLockDelay(delay);
                              }
                            },
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                  const Divider(height: 16),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    secondary: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withOpacity(0.18),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.history_toggle_off_rounded,
                        color: Color(0xFF10B981),
                        size: 20,
                      ),
                    ),
                    title: Text(
                      l10n.tr('show_throwbacks'),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: Text(
                      l10n.tr('show_throwbacks_sub'),
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary(context),
                      ),
                    ),
                    value: provider.showThrowbacks,
                    activeColor: AppColors.accent,
                    onChanged: (val) => provider.toggleThrowbacks(val),
                  ),
                  const Divider(height: 16),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    secondary: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.lightbulb_outline_rounded,
                        color: Color(0xFFF59E0B),
                        size: 20,
                      ),
                    ),
                    title: Text(
                      l10n.tr('show_journal_prompts'),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: Text(
                      l10n.tr('show_journal_prompts_sub'),
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary(context),
                      ),
                    ),
                    value: provider.showJournalPrompts,
                    activeColor: AppColors.accent,
                    onChanged: (val) => provider.toggleJournalPrompts(val),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Wearable & Health Platforms Integration
          Text(
            l10n.tr('wearable_health_platforms'),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Consumer<WearableProvider>(
            builder: (context, wearable, _) {
              final config = wearable.config;
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: config.isConnected
                                ? AppColors.success.withOpacity(0.18)
                                : AppColors.accent.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.watch_rounded,
                            color: config.isConnected
                                ? AppColors.success
                                : AppColors.accent,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          config.isConnected
                              ? config.selectedPlatform.displayName
                              : l10n.tr('connect_wearable'),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        subtitle: Text(
                          config.isConnected
                              ? l10n.tr('wearable_syncing_sub')
                              : l10n.tr('wearable_platforms_sub'),
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary(context),
                          ),
                        ),
                        trailing: Icon(
                          Icons.chevron_right_rounded,
                          color: AppColors.textSecondary(context),
                        ),
                        onTap: () => WearableSyncSheet.show(context),
                      ),
                      const Divider(height: 16),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        secondary: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF3A86FF).withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.sync_rounded,
                            color: Color(0xFF3A86FF),
                            size: 20,
                          ),
                        ),
                        title: Text(
                          l10n.tr('auto_sync_launch'),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        subtitle: Text(
                          l10n.tr('auto_sync_launch_sub'),
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary(context),
                          ),
                        ),
                        value: config.autoSyncOnLaunch,
                        activeColor: AppColors.accent,
                        onChanged: (val) => wearable.updateConfig(
                          config.copyWith(autoSyncOnLaunch: val),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 20),

          // Platform & Reliability Info
          Text(
            l10n.tr('platform_system_reliability'),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Consumer<OemHardeningProvider>(
            builder: (context, oem, _) {
              final status = oem.status;
              final isProt = oem.isProtected;

              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      InkWell(
                        onTap: () => OemHardeningSheet.show(context),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isProt
                                ? AppColors.success.withOpacity(0.12)
                                : const Color(0xFFE04A3A).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isProt
                                  ? AppColors.success.withOpacity(0.3)
                                  : const Color(0xFFE04A3A).withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                isProt
                                    ? Icons.verified_user_rounded
                                    : Icons.warning_amber_rounded,
                                color: isProt
                                    ? AppColors.success
                                    : const Color(0xFFE04A3A),
                                size: 22,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      status.brandDisplayName,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      isProt
                                          ? l10n.tr('protected_bg_kill')
                                          : l10n.pick(
                                              '${status.riskLabel} • Tap to configure',
                                              '${status.riskLabel} • Ketuk untuk atur',
                                            ),
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isProt
                                            ? AppColors.success
                                            : const Color(0xFFE04A3A),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.chevron_right_rounded,
                                color: AppColors.textSecondary(context),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        secondary: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: oem.isKeepAliveActive
                                ? AppColors.success.withValues(alpha: 0.18)
                                : const Color(0xFF3A86FF).withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.security_rounded,
                            color: oem.isKeepAliveActive
                                ? AppColors.success
                                : const Color(0xFF3A86FF),
                            size: 20,
                          ),
                        ),
                        title: Text(
                          l10n.tr('keep_alive_guard'),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        subtitle: Text(
                          l10n.tr('keep_alive_guard_sub'),
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary(context),
                          ),
                        ),
                        value: oem.config.keepAliveEnabledByUser,
                        activeColor: AppColors.accent,
                        onChanged: (val) => oem.toggleKeepAliveService(val),
                      ),
                      const Divider(height: 20),
                      _statusRow(
                        icon: Icons.notifications_active_outlined,
                        label: l10n.tr('notifications_engine'),
                        value: l10n.tr('active_high_priority'),
                        color: AppColors.success,
                      ),
                      const Divider(height: 20),
                      _statusRow(
                        icon: Icons.alarm_on_rounded,
                        label: l10n.tr('exact_alarm_scheduling'),
                        value: l10n.tr('enabled_label'),
                        color: AppColors.success,
                      ),
                      const Divider(height: 20),
                      _statusRow(
                        icon: Icons.battery_charging_full_rounded,
                        label: l10n.tr('background_wakelock'),
                        value: l10n.tr('supported_label'),
                        color: AppColors.accent,
                      ),
                      Builder(
                        builder: (ctx) {
                          GeofenceProvider? geo;
                          try {
                            geo = Provider.of<GeofenceProvider>(ctx);
                          } catch (_) {}
                          if (geo == null) return const SizedBox.shrink();
                          return Column(
                            children: [
                              const Divider(height: 20),
                              InkWell(
                                onTap: () => LocationRemindersSheet.show(ctx),
                                borderRadius: BorderRadius.circular(10),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 4,
                                  ),
                                  child: _statusRow(
                                    icon: Icons.location_on_rounded,
                                    label: l10n.tr('scout_native_geofencing'),
                                    value: l10n.pick(
                                      '${geo.armedCount} Armed • ${geo.permissionState.label}',
                                      '${geo.armedCount} Aktif • ${geo.permissionState.label}',
                                    ),
                                    color: geo.permissionState
                                            .isReadyForBackground
                                        ? AppColors.success
                                        : const Color(0xFF3B82F6),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      Builder(
                        builder: (ctx) {
                          MoneyProvider? money;
                          try {
                            money = Provider.of<MoneyProvider>(ctx);
                          } catch (_) {}
                          if (money == null) return const SizedBox.shrink();
                          return Column(
                            children: [
                              const Divider(height: 20),
                              InkWell(
                                onTap: () => showMoneySettingsDialog(ctx),
                                borderRadius: BorderRadius.circular(10),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 4,
                                  ),
                                  child: _statusRow(
                                    icon: Icons.account_balance_wallet_rounded,
                                    label: l10n.tr('twill_money_preferences'),
                                    value: l10n.pick(
                                      '${money.currency.symbol} (${money.currency.code}) • ${money.activeAccounts.length} Accounts',
                                      '${money.currency.symbol} (${money.currency.code}) • ${money.activeAccounts.length} Akun',
                                    ),
                                    color: kTwillAmber,
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      Builder(
                        builder: (ctx) {
                          DeviceControlProvider? dc;
                          try {
                            dc = Provider.of<DeviceControlProvider>(ctx);
                          } catch (_) {}
                          if (dc == null) return const SizedBox.shrink();
                          final missingReq =
                              dc.registry.requiredMissingPermissions.length;
                          final revokedCount =
                              dc.registry.revokedPermissions.length;
                          return Column(
                            children: [
                              const Divider(height: 20),
                              InkWell(
                                onTap: () {
                                  Navigator.of(ctx).push(
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          const PermissionCenterScreen(),
                                    ),
                                  );
                                },
                                borderRadius: BorderRadius.circular(10),
                                child: Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 4),
                                  child: _statusRow(
                                    icon: Icons.verified_user_rounded,
                                    label: l10n.pick(
                                      'Permission & Capability Center',
                                      'Pusat Izin & Kapabilitas',
                                    ),
                                    value: revokedCount > 0
                                        ? '$revokedCount Revoked'
                                        : (missingReq > 0
                                            ? '$missingReq Required Missing'
                                            : l10n.pick(
                                                '${dc.registry.platform.toUpperCase()} Inspected',
                                                '${dc.registry.platform.toUpperCase()} Terperiksa',
                                              )),
                                    color: revokedCount > 0
                                        ? AppColors.error
                                        : (missingReq > 0
                                            ? AppColors.warning
                                            : AppColors.success),
                                  ),
                                ),
                              ),
                              const Divider(height: 20),
                              InkWell(
                                onTap: () {
                                  Navigator.of(ctx).push(
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          const DigitalWellbeingScreen(),
                                    ),
                                  );
                                },
                                borderRadius: BorderRadius.circular(10),
                                child: Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 4),
                                  child: _statusRow(
                                    icon: Icons.phonelink_lock_rounded,
                                    label: l10n.pick(
                                      'Digital Wellbeing & Phone Modes',
                                      'Kesejahteraan Digital & Mode Ponsel',
                                    ),
                                    value: dc.activePhoneMode != null
                                        ? '${dc.activePhoneMode!.name} Active'
                                        : '${dc.appRules.where((r) => r.isEnabled).length} App Rules',
                                    color: AppColors.info,
                                  ),
                                ),
                              ),
                              const Divider(height: 20),
                              InkWell(
                                onTap: () {
                                  Navigator.of(ctx).push(
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          const AutomationHubScreen(),
                                    ),
                                  );
                                },
                                borderRadius: BorderRadius.circular(10),
                                child: Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 4),
                                  child: _statusRow(
                                    icon: Icons.auto_awesome_rounded,
                                    label: l10n.pick(
                                      'Nestin Automation Engine',
                                      'Mesin Otomasi Nestin',
                                    ),
                                    value: l10n.pick('Configure', 'Atur'),
                                    color: AppColors.accent,
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 20),

          // Optional Account & Guest Migration
          Text(
            l10n.pick('Optional Cloud Identity', 'Identitas Cloud Opsional'),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          const NestinAccountSettingsTile(),
          const SizedBox(height: 20),

          // About Nestin Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset(
                      'assets/logo.jpg',
                      width: 52,
                      height: 52,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 52,
                        height: 52,
                        color: AppColors.primary,
                        child: const Icon(Icons.home_rounded, color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Nestin',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          l10n.tr('about_version'),
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary(context),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          l10n.tr('about_tagline'),
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _statusRow({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }
}
