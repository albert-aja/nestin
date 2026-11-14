import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/alarm.dart';
import '../../../data/models/alarm_category.dart';
import '../../../data/models/alarm_schedule.dart';
import '../../../data/models/challenge_profile.dart';
import '../../../data/services/audio_service.dart';
import '../../../providers/alarm_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../providers/sound_provider.dart';
import 'sound_picker_sheet.dart';

class AlarmEditScreen extends StatefulWidget {
  final Alarm? initialAlarm;

  const AlarmEditScreen({super.key, this.initialAlarm});

  @override
  State<AlarmEditScreen> createState() => _AlarmEditScreenState();
}

class _AlarmEditScreenState extends State<AlarmEditScreen> {
  late int _hour;
  late int _minute;
  late TextEditingController _titleController;
  late TextEditingController _descController;
  late AlarmCategory _category;
  late ScheduleType _scheduleType;
  late Set<int> _selectedDays;

  late String _sound;
  late String? _soundFilePath;
  late double _volume;
  late bool _gradualVolume;
  late int _gradualDuration;
  late bool _vibration;

  late int _snoozeMinutes;
  late int _maxSnoozeCount;

  // Challenge settings
  late bool _challengeInherited;
  late bool _challengeEnabled;
  late ChallengeType _challengeType;
  late ChallengeDifficulty _challengeDifficulty;
  late int _questionsCount;
  late bool _allowSnoozeDuringChallenge;

  @override
  void initState() {
    super.initState();
    final a = widget.initialAlarm;

    _hour = a?.hour ?? 7;
    _minute = a?.minute ?? 0;
    _titleController = TextEditingController(text: a?.title ?? 'Wake Up');
    _descController = TextEditingController(text: a?.description ?? '');
    _category = a?.category ?? AlarmCategory.fromType(AlarmCategoryType.wakeUp);
    _scheduleType = a?.schedule.type ?? ScheduleType.weekdays;
    _selectedDays = Set.from(a?.schedule.selectedDays ?? {1, 2, 3, 4, 5});

    _sound = a?.sound ?? 'rooster_dawn';
    _soundFilePath = a?.soundFilePath;
    _volume = a?.volume ?? 0.85;
    _gradualVolume = a?.gradualVolume ?? true;
    _gradualDuration = a?.gradualDurationSeconds ?? 60;
    _vibration = a?.vibration ?? true;

    _snoozeMinutes = a?.snoozeMinutes ?? 9;
    _maxSnoozeCount = a?.maxSnoozeCount ?? 3;

    _challengeInherited = a?.challengeInherited ?? true;
    final override = a?.challengeOverride;
    _challengeEnabled = override?.isEnabled ?? true;
    _challengeType = override?.type ?? ChallengeType.math;
    _challengeDifficulty = override?.difficulty ?? ChallengeDifficulty.easy;
    _questionsCount = override?.questionsCount ?? 3;
    _allowSnoozeDuringChallenge = override?.allowSnoozeDuringChallenge ?? true;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _hour, minute: _minute),
    );
    if (picked != null) {
      setState(() {
        _hour = picked.hour;
        _minute = picked.minute;
      });
    }
  }

  void _saveAlarm() {
    final alarmProvider = Provider.of<AlarmProvider>(context, listen: false);

    AlarmSchedule schedule;
    if (_scheduleType == ScheduleType.customDays) {
      schedule = AlarmSchedule.customDays(_selectedDays);
    } else if (_scheduleType == ScheduleType.weekdays) {
      schedule = AlarmSchedule.weekdays();
    } else if (_scheduleType == ScheduleType.daily) {
      schedule = AlarmSchedule.daily();
    } else {
      schedule = AlarmSchedule.oneTime();
    }

    WakeUpChallengeProfile? challengeOverride;
    if (!_challengeInherited) {
      challengeOverride = WakeUpChallengeProfile(
        id: const Uuid().v4(),
        isEnabled: _challengeEnabled,
        type: _challengeType,
        difficulty: _challengeDifficulty,
        questionsCount: _questionsCount,
        allowSnoozeDuringChallenge: _allowSnoozeDuringChallenge,
      );
    }

    final now = DateTime.now();
    final isNew = widget.initialAlarm == null;
    final alarm = Alarm(
      id: widget.initialAlarm?.id ?? const Uuid().v4(),
      title: _titleController.text.trim().isEmpty
          ? 'Alarm'
          : _titleController.text.trim(),
      description: _descController.text.trim(),
      hour: _hour,
      minute: _minute,
      isEnabled: widget.initialAlarm?.isEnabled ?? true,
      category: _category,
      schedule: schedule,
      sound: _sound,
      soundFilePath: _soundFilePath,
      volume: _volume,
      gradualVolume: _gradualVolume,
      gradualDurationSeconds: _gradualDuration,
      vibration: _vibration,
      snoozeMinutes: _snoozeMinutes,
      maxSnoozeCount: _maxSnoozeCount,
      challengeInherited: _challengeInherited,
      challengeOverride: challengeOverride,
      createdAt: widget.initialAlarm?.createdAt ?? now,
      updatedAt: now,
    );

    if (isNew) {
      alarmProvider.addAlarm(alarm);
    } else {
      alarmProvider.updateAlarm(alarm);
    }

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final globalProfile = settingsProvider.globalChallengeProfile;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final formattedHour = _hour.toString().padLeft(2, '0');
    final formattedMinute = _minute.toString().padLeft(2, '0');

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.initialAlarm == null ? 'New Alarm' : 'Edit Alarm'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton.icon(
              onPressed: _saveAlarm,
              icon: const Icon(Icons.check_rounded, size: 18),
              label: const Text('Save'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Big Interactive Time Banner
            InkWell(
              onTap: _pickTime,
              borderRadius: BorderRadius.circular(24),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 28),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? [const Color(0xFF1F2128), const Color(0xFF16171C)]
                        : [Colors.white, const Color(0xFFF1F3F5)],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: AppColors.accent.withOpacity(0.3),
                    width: 1.2,
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      'Tap to change time',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? const Color(0xFF8E929E) : const Color(0xFF6C757D),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '$formattedHour:$formattedMinute',
                      style: const TextStyle(
                        fontSize: 64,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Title & Description
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Alarm Title',
                prefixIcon: Icon(Icons.label_outline_rounded),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _descController,
              decoration: const InputDecoration(
                labelText: 'Description / Notes (Optional)',
                prefixIcon: Icon(Icons.notes_rounded),
              ),
            ),
            const SizedBox(height: 24),

            // Category Picker
            const Text(
              'Category',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: AlarmCategory.predefined.map((cat) {
                  final isSelected = _category.type == cat.type;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      selected: isSelected,
                      avatar: Icon(
                        cat.icon,
                        size: 16,
                        color: isSelected ? Colors.white : cat.color,
                      ),
                      label: Text(cat.name),
                      selectedColor: cat.color,
                      onSelected: (selected) {
                        if (selected) {
                          setState(() => _category = cat);
                        }
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 24),

            // Recurrence Configuration
            const Text(
              'Repeat Schedule',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1A1B20) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? const Color(0xFF2C2F3A) : const Color(0xFFE9ECEF),
                ),
              ),
              child: Column(
                children: [
                  DropdownButtonFormField<ScheduleType>(
                    value: _scheduleType,
                    decoration: const InputDecoration(
                      labelText: 'Recurrence',
                      prefixIcon: Icon(Icons.repeat_rounded),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: ScheduleType.oneTime,
                        child: Text('Once (No recurrence)'),
                      ),
                      DropdownMenuItem(
                        value: ScheduleType.daily,
                        child: Text('Every day'),
                      ),
                      DropdownMenuItem(
                        value: ScheduleType.weekdays,
                        child: Text('Weekdays (Mon - Fri)'),
                      ),
                      DropdownMenuItem(
                        value: ScheduleType.customDays,
                        child: Text('Custom Days'),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _scheduleType = val);
                    },
                  ),
                  if (_scheduleType == ScheduleType.customDays) ...[
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        for (int day = 1; day <= 7; day++)
                          _buildDayToggle(day),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Sound, Volume & Vibration Card
            const Text(
              'Sound & Audio Ramping',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1A1B20) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? const Color(0xFF2C2F3A) : const Color(0xFFE9ECEF),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Sound Picker Interactive Card
                  Consumer<SoundProvider>(
                    builder: (context, soundProvider, _) {
                      final soundName = soundProvider.getSoundDisplayName(_sound);
                      final isCustom = _soundFilePath != null || _sound.startsWith('custom_');

                      return InkWell(
                        onTap: () async {
                          final result = await SoundPickerSheet.show(
                            context,
                            currentSoundId: _sound,
                            currentSoundFilePath: _soundFilePath,
                          );
                          if (result != null) {
                            setState(() {
                              _sound = result.soundId;
                              _soundFilePath = result.soundFilePath;
                            });
                          }
                        },
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF23252E) : const Color(0xFFF1F3F5),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isDark ? const Color(0xFF333744) : const Color(0xFFE2E5EA),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: (isCustom ? AppColors.accent : AppColors.primary).withOpacity(0.16),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  isCustom ? Icons.audio_file_rounded : Icons.music_note_rounded,
                                  color: isCustom ? AppColors.accent : AppColors.primaryLight,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            soundName,
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: isCustom
                                                ? AppColors.accent.withOpacity(0.18)
                                                : Colors.white10,
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            isCustom ? 'CUSTOM' : 'BUILT-IN',
                                            style: TextStyle(
                                              fontSize: 9,
                                              fontWeight: FontWeight.w800,
                                              color: isCustom
                                                  ? AppColors.adaptive(
                                                      context,
                                                      dark: AppColors.accent,
                                                      light: const Color(0xFFB45309),
                                                    )
                                                  : AppColors.textSecondary(context),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Tap to change or import MP3 / WAV',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textSecondary(context),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.play_circle_fill_rounded,
                                    size: 28, color: AppColors.accent),
                                tooltip: 'Preview Tone',
                                onPressed: () {
                                  AudioService().previewTone(
                                    _sound,
                                    _volume,
                                    customFilePath: _soundFilePath,
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(Icons.volume_up_rounded, size: 20),
                      const SizedBox(width: 10),
                      Text('Volume: ${(_volume * 100).round()}%'),
                    ],
                  ),
                  Slider(
                    value: _volume,
                    min: 0.1,
                    max: 1.0,
                    divisions: 9,
                    activeColor: AppColors.primary,
                    onChanged: (val) => setState(() => _volume = val),
                  ),
                  SwitchListTile(
                    title: const Text('Gradual Volume Ramp'),
                    subtitle: Text('Gently rises over $_gradualDuration seconds'),
                    value: _gradualVolume,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (val) => setState(() => _gradualVolume = val),
                  ),
                  SwitchListTile(
                    title: const Text('Vibration'),
                    value: _vibration,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (val) => setState(() => _vibration = val),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Snooze Settings Card
            const Text(
              'Snooze Configuration',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1A1B20) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? const Color(0xFF2C2F3A) : const Color(0xFFE9ECEF),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          value: _snoozeMinutes,
                          decoration: const InputDecoration(
                            labelText: 'Snooze Length',
                          ),
                          items: [5, 9, 10, 15].map((m) {
                            return DropdownMenuItem(
                              value: m,
                              child: Text('$m minutes'),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _snoozeMinutes = val);
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          value: _maxSnoozeCount,
                          decoration: const InputDecoration(
                            labelText: 'Max Snoozes',
                          ),
                          items: [1, 2, 3, 5, 0].map((count) {
                            return DropdownMenuItem(
                              value: count,
                              child: Text(count == 0 ? 'Unlimited' : '$count times'),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _maxSnoozeCount = val);
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Wake-Up Challenge Section & Inheritance Engine
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1A1B20) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.accent.withOpacity(0.4),
                  width: 1.2,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.psychology_rounded,
                          color: AppColors.accent, size: 22),
                      const SizedBox(width: 8),
                      const Text(
                        'Wake-Up Challenge Gate',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Requires solving mental tasks before alarm can be dismissed.',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? const Color(0xFF8E929E) : const Color(0xFF6C757D),
                    ),
                  ),
                  const Divider(height: 24),

                  // Mode: Inherit vs Override
                  RadioListTile<bool>(
                    title: const Text('Inherit Global Default Profile'),
                    subtitle: Text(
                      'Uses settings from Settings tab (${globalProfile.typeLabel} • ${globalProfile.difficultyLabel} • ${globalProfile.questionsCount} rounds)',
                      style: const TextStyle(fontSize: 12),
                    ),
                    value: true,
                    groupValue: _challengeInherited,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (val) {
                      setState(() => _challengeInherited = val ?? true);
                    },
                  ),
                  RadioListTile<bool>(
                    title: const Text('Custom Challenge Override for this Alarm'),
                    subtitle: const Text(
                      'Set unique challenge rules specifically for this alarm',
                      style: TextStyle(fontSize: 12),
                    ),
                    value: false,
                    groupValue: _challengeInherited,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (val) {
                      setState(() => _challengeInherited = val ?? false);
                    },
                  ),

                  // Custom Challenge Controls (shown when override selected)
                  if (!_challengeInherited) ...[
                    const Divider(height: 20),
                    SwitchListTile(
                      title: const Text('Enable Challenge'),
                      value: _challengeEnabled,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (val) => setState(() => _challengeEnabled = val),
                    ),
                    if (_challengeEnabled) ...[
                      const SizedBox(height: 10),
                      DropdownButtonFormField<ChallengeType>(
                        value: _challengeType,
                        decoration: const InputDecoration(labelText: 'Challenge Type'),
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
                          if (val != null) setState(() => _challengeType = val);
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<ChallengeDifficulty>(
                        value: _challengeDifficulty,
                        decoration: const InputDecoration(labelText: 'Difficulty'),
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
                            setState(() => _challengeDifficulty = val);
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int>(
                        value: _questionsCount,
                        decoration: const InputDecoration(labelText: 'Questions / Rounds'),
                        items: [1, 2, 3, 5].map((cnt) {
                          return DropdownMenuItem(
                            value: cnt,
                            child: Text('$cnt ${cnt == 1 ? 'Round' : 'Rounds'}'),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _questionsCount = val);
                        },
                      ),
                      SwitchListTile(
                        title: const Text('Allow Snooze during Challenge'),
                        value: _allowSnoozeDuringChallenge,
                        contentPadding: EdgeInsets.zero,
                        onChanged: (val) =>
                            setState(() => _allowSnoozeDuringChallenge = val),
                      ),
                    ],
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _challengeInherited = true;
                        });
                      },
                      icon: const Icon(Icons.restart_alt_rounded, size: 18),
                      label: const Text('Reset to Inherit Global Default'),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildDayToggle(int day) {
    const dayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final isSelected = _selectedDays.contains(day);

    return InkWell(
      onTap: () {
        setState(() {
          if (isSelected) {
            _selectedDays.remove(day);
          } else {
            _selectedDays.add(day);
          }
        });
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary
              : AppColors.adaptive(
                  context,
                  dark: const Color(0xFF282A32),
                  light: AppColors.lightCardElevated,
                ),
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Text(
          dayLabels[day - 1],
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color:
                isSelected ? Colors.white : AppColors.textSecondary(context),
          ),
        ),
      ),
    );
  }
}

