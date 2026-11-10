import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/alarm.dart';
import '../../../providers/alarm_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../widgets/category_badge.dart';
import '../challenges/challenge_modal_dialog.dart';

class ActiveAlarmScreen extends StatefulWidget {
  final Alarm alarm;

  const ActiveAlarmScreen({super.key, required this.alarm});

  @override
  State<ActiveAlarmScreen> createState() => _ActiveAlarmScreenState();
}

class _ActiveAlarmScreenState extends State<ActiveAlarmScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Timer _clockTimer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _now = DateTime.now();
        });
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _clockTimer.cancel();
    super.dispose();
  }

  void _openChallenge(BuildContext context, AlarmProvider alarmProvider,
      SettingsProvider settingsProvider) {
    final challenge =
        widget.alarm.effectiveChallenge(settingsProvider.globalChallengeProfile);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => ChallengeModalDialog(
        challenge: challenge,
        onDismissAlarm: () {
          alarmProvider.dismissAlarm(widget.alarm.id);
        },
        onSnooze: widget.alarm.snoozeCount < widget.alarm.maxSnoozeCount
            ? () {
                alarmProvider.snoozeAlarm(widget.alarm.id);
              }
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final alarmProvider = Provider.of<AlarmProvider>(context, listen: false);
    final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
    final challenge =
        widget.alarm.effectiveChallenge(settingsProvider.globalChallengeProfile);
    final hasChallenge = challenge.isEnabled;
    final canSnooze =
        widget.alarm.maxSnoozeCount == 0 ||
        widget.alarm.snoozeCount < widget.alarm.maxSnoozeCount;

    final timeString = DateFormat('hh:mm').format(_now);
    final periodString = DateFormat('a').format(_now);
    final dateString = DateFormat('EEEE, MMMM d').format(_now);

    return Scaffold(
      backgroundColor: const Color(0xFF0F1014),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            children: [
              // Category & Tag
              CategoryBadge(category: widget.alarm.category),
              const SizedBox(height: 12),
              Text(
                dateString,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF8E929E),
                ),
              ),
              const Spacer(),

              // Glowing Pulse Graphic
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  final scale = 1.0 + (_pulseController.value * 0.12);
                  return Transform.scale(
                    scale: scale,
                    child: Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const RadialGradient(
                          colors: [
                            AppColors.accent,
                            AppColors.primary,
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.accent.withOpacity(0.45 * _pulseController.value),
                            blurRadius: 36,
                            spreadRadius: 8,
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.alarm_rounded,
                          size: 64,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 36),

              // Digital Time Display
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    timeString,
                    style: const TextStyle(
                      fontSize: 68,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -2,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    periodString,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: AppColors.accent,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Title & Description
              Text(
                widget.alarm.title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (widget.alarm.description.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  widget.alarm.description,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF9E9EA7),
                  ),
                ),
              ],

              if (widget.alarm.snoozeCount > 0) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Snooze ${widget.alarm.snoozeCount} of ${widget.alarm.maxSnoozeCount}',
                    style: const TextStyle(fontSize: 12, color: AppColors.accent),
                  ),
                ),
              ],

              const Spacer(),

              // Primary Dismiss Action
              if (hasChallenge) ...[
                SizedBox(
                  width: double.infinity,
                  height: 58,
                  child: ElevatedButton.icon(
                    onPressed: () =>
                        _openChallenge(context, alarmProvider, settingsProvider),
                    icon: const Icon(Icons.psychology_rounded,
                        color: Colors.white, size: 24),
                    label: Text(
                      'Solve ${challenge.typeLabel} to Dismiss',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 8,
                      shadowColor: AppColors.primary.withOpacity(0.5),
                    ),
                  ),
                ),
              ] else ...[
                SizedBox(
                  width: double.infinity,
                  height: 58,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      alarmProvider.dismissAlarm(widget.alarm.id);
                    },
                    icon: const Icon(Icons.alarm_off_rounded,
                        color: Colors.white, size: 24),
                    label: const Text(
                      'Dismiss Alarm',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 8,
                      shadowColor: AppColors.primary.withOpacity(0.5),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 14),

              // Snooze Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: canSnooze
                      ? () {
                          alarmProvider.snoozeAlarm(widget.alarm.id);
                        }
                      : null,
                  icon: const Icon(Icons.snooze_rounded, size: 20),
                  label: Text(
                    canSnooze
                        ? 'Snooze for ${widget.alarm.snoozeMinutes} mins'
                        : 'Snooze Limit Reached',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(
                      color: canSnooze ? const Color(0xFF333744) : Colors.white12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

