import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/challenge_profile.dart';
import '../../../providers/settings_provider.dart';
import '../../../providers/sound_provider.dart';
import '../../widgets/roodoo_brand_header.dart';
import '../alarms/sound_picker_sheet.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  void _showGlobalChallengeEditor(
      BuildContext context, SettingsProvider provider) {
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
              decoration: const BoxDecoration(
                color: Color(0xFF181A20),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Global Challenge Profile',
                          style: TextStyle(
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
                      child: const Text(
                        'Changes here automatically apply to all wake-up alarms that inherit the global profile. Custom overrides on individual alarms remain protected.',
                        style: TextStyle(fontSize: 12, color: AppColors.accent),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SwitchListTile(
                      title: const Text('Wake-Up Challenge Active by Default'),
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
                        decoration:
                            const InputDecoration(labelText: 'Default Challenge Type'),
                        items: const [
                          DropdownMenuItem(
                            value: ChallengeType.math,
                            child: Text('Math Problems'),
                          ),
                          DropdownMenuItem(
                            value: ChallengeType.memory,
                            child: Text('Pattern Memory'),
                          ),
                          DropdownMenuItem(
                            value: ChallengeType.typing,
                            child: Text('Word Typing'),
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
                        decoration:
                            const InputDecoration(labelText: 'Default Difficulty'),
                        items: const [
                          DropdownMenuItem(
                            value: ChallengeDifficulty.easy,
                            child: Text('Easy'),
                          ),
                          DropdownMenuItem(
                            value: ChallengeDifficulty.medium,
                            child: Text('Medium'),
                          ),
                          DropdownMenuItem(
                            value: ChallengeDifficulty.hard,
                            child: Text('Hard'),
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
                        decoration:
                            const InputDecoration(labelText: 'Questions / Rounds'),
                        items: [1, 2, 3, 5].map((cnt) {
                          return DropdownMenuItem(
                            value: cnt,
                            child: Text('$cnt ${cnt == 1 ? 'Round' : 'Rounds'}'),
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
                        title: const Text('Allow Snooze during Challenge'),
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
                      child: const Text(
                        'Save Global Profile',
                        style: TextStyle(
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
    final provider = Provider.of<SettingsProvider>(context);
    final prefs = provider.preferences;
    final globalProfile = prefs.globalChallengeProfile;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const RooDooBrandHeader(
            subtitle: 'Time management & alert preferences',
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
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Global Challenge Profile',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                'Default wake-up requirement across alarms',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF8E929E),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded,
                            color: Color(0xFF8E929E)),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF23252E),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            globalProfile.isEnabled
                                ? '${globalProfile.typeLabel} • ${globalProfile.difficultyLabel} (${globalProfile.questionsCount} rounds)'
                                : 'Disabled by default',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: globalProfile.isEnabled
                                  ? AppColors.accent
                                  : const Color(0xFF8E929E),
                            ),
                          ),
                          const Text(
                            'Edit',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primaryLight,
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
          const Text(
            'General Preferences',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.schedule_rounded),
                  title: const Text('24-Hour Time Format'),
                  subtitle: const Text('e.g. 14:30 instead of 2:30 PM'),
                  value: prefs.use24Hour,
                  onChanged: (val) => provider.toggle24Hour(val),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.palette_outlined),
                  title: const Text('Theme Mode'),
                  subtitle: Text(prefs.themeMode.name.toUpperCase()),
                  trailing: DropdownButton<ThemeMode>(
                    value: prefs.themeMode,
                    underline: const SizedBox(),
                    items: const [
                      DropdownMenuItem(
                        value: ThemeMode.dark,
                        child: Text('Dark'),
                      ),
                      DropdownMenuItem(
                        value: ThemeMode.light,
                        child: Text('Light'),
                      ),
                      DropdownMenuItem(
                        value: ThemeMode.system,
                        child: Text('System'),
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
                  title: const Text('Default Snooze Duration'),
                  trailing: DropdownButton<int>(
                    value: prefs.defaultSnoozeMinutes,
                    underline: const SizedBox(),
                    items: [5, 9, 10, 15].map((m) {
                      return DropdownMenuItem(
                        value: m,
                        child: Text('$m mins'),
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
          const Text(
            'Audio & Volume Defaults',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
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
                      const Text(
                        'Default Alarm Volume',
                        style: TextStyle(fontWeight: FontWeight.w600),
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
                    title: const Text('Gradual Volume Ramp by Default'),
                    subtitle: Text(
                      'Rises over ${prefs.defaultGradualSeconds} seconds',
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
          const Text(
            'Custom Ringtone Library',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
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
                                const Text(
                                  'Imported Audio Files',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  '${customSounds.length} custom ${customSounds.length == 1 ? 'sound' : 'sounds'} in library',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF8E929E),
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
                          label: const Text('Manage & Import Sounds (MP3 / WAV)'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Color(0xFF333744)),
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

          // Platform & Reliability Info
          const Text(
            'Platform & System Reliability',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _statusRow(
                    icon: Icons.notifications_active_outlined,
                    label: 'Notifications Engine',
                    value: 'Active (High Priority)',
                    color: AppColors.success,
                  ),
                  const Divider(height: 20),
                  _statusRow(
                    icon: Icons.alarm_on_rounded,
                    label: 'Exact Alarm Scheduling',
                    value: 'Enabled',
                    color: AppColors.success,
                  ),
                  const Divider(height: 20),
                  _statusRow(
                    icon: Icons.battery_charging_full_rounded,
                    label: 'Background WakeLock',
                    value: 'Supported',
                    color: AppColors.accent,
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
