import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../domain/sleep/sleep_cycle_calculator.dart';
import '../../../data/services/weather_service.dart';
import '../../../data/services/storage_service.dart';
import '../settings/settings_screen.dart';
import '../search/universal_search_screen.dart';

class ExploreHubScreen extends StatefulWidget {
  const ExploreHubScreen({super.key});

  @override
  State<ExploreHubScreen> createState() => _ExploreHubScreenState();
}

class _ExploreHubScreenState extends State<ExploreHubScreen> {
  int _waterGlasses = 4; // 250ml each = 1000ml
  final WeatherProviderInterface _weatherService = LocalWeatherService();
  WeatherInfo? _weatherInfo;

  // BeforeYouGo checklist
  final Map<String, bool> _departureChecklist = {
    'Keys & Wallet': true,
    'Phone & Charger': true,
    'Water bottle': false,
    'Turn off appliances': false,
    'Lock windows & doors': false,
  };

  @override
  void initState() {
    super.initState();
    _loadWeather();
  }

  Future<void> _loadWeather() async {
    final info = await _weatherService.getCurrentWeather();
    if (mounted) setState(() => _weatherInfo = info);
  }

  void _showSleepCycleSheet() {
    final now = DateTime.now();
    final wakeOptions = SleepCycleCalculator.calculateWakeUpTimes(now);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Color(0xFF16171D),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.bedtime_rounded, color: AppColors.accent, size: 24),
                const SizedBox(width: 10),
                const Text('Sleep Cycle Calculator', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                const Spacer(),
                IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.of(ctx).pop()),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'If you go to sleep right now, set your alarm for the end of a 90-minute cycle to wake up refreshed and prevent sleep inertia:',
              style: TextStyle(fontSize: 12, color: Color(0xFF8E929E)),
            ),
            const SizedBox(height: 16),
            ...wakeOptions.map((opt) {
              final h = opt.targetTime.hour.toString().padLeft(2, '0');
              final m = opt.targetTime.minute.toString().padLeft(2, '0');

              return Card(
                color: opt.isRecommended ? AppColors.accent.withOpacity(0.14) : const Color(0xFF1E2028),
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: Icon(
                    opt.isRecommended ? Icons.stars_rounded : Icons.alarm_outlined,
                    color: opt.isRecommended ? AppColors.accent : const Color(0xFF8E929E),
                  ),
                  title: Text(
                    '$h:$m',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                  subtitle: Text(opt.label),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  void _handleDataExport(BuildContext context) {
    final storage = Provider.of<StorageService>(context, listen: false);
    final jsonStr = storage.exportFullBackupJson();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Local Backup Export'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Full application state exported as local-first JSON format. All modules, alarms, and settings included:'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF121316),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${jsonStr.substring(0, jsonStr.length > 200 ? 200 : jsonStr.length)}...',
                style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: Color(0xFF8E929E)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Done')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Everyday Life & Wellness'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded),
            tooltip: 'Universal Search',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const UniversalSearchScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.tune_rounded),
            tooltip: 'Settings',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Weather & Context Card
          if (_weatherInfo != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.wb_sunny_rounded, color: AppColors.accent, size: 32),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                '${_weatherInfo!.temperatureCelsius.round()}°C',
                                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _weatherInfo!.condition,
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFFE2E4E9)),
                              ),
                            ],
                          ),
                          Text(
                            _weatherInfo!.advice,
                            style: const TextStyle(fontSize: 12, color: Color(0xFF8E929E)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 16),

          // Wellness Row
          const Text('Personal Wellness & Sleep', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),

          Row(
            children: [
              // Sleep Cycles Card
              Expanded(
                child: InkWell(
                  onTap: _showSleepCycleSheet,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E2028),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF2C2F3A)),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.bedtime_rounded, color: Color(0xFF8338EC), size: 24),
                        SizedBox(height: 10),
                        Text('Sleep Cycles', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                        SizedBox(height: 2),
                        Text('Optimal Bedtime', style: TextStyle(fontSize: 11, color: Color(0xFF8E929E))),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Water Tracker Card
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E2028),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF2C2F3A)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Icon(Icons.water_drop_rounded, color: Color(0xFF3A86FF), size: 24),
                          Text('${_waterGlasses * 250}ml', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF3A86FF))),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Water Goal', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                          InkWell(
                            onTap: () {
                              if (_waterGlasses < 12) setState(() => _waterGlasses++);
                            },
                            child: const Icon(Icons.add_circle_rounded, color: AppColors.accent, size: 20),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text('$_waterGlasses / 8 glasses', style: const TextStyle(fontSize: 11, color: Color(0xFF8E929E))),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // BeforeYouGo Departure Assistant
          const Text('BeforeYouGo — Departure Assistant', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.door_front_door_outlined, color: AppColors.primary, size: 20),
                      SizedBox(width: 8),
                      Text('Leaving the house checklist', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ..._departureChecklist.entries.map((entry) => InkWell(
                        onTap: () {
                          setState(() {
                            _departureChecklist[entry.key] = !entry.value;
                          });
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Icon(
                                entry.value ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                                size: 18,
                                color: entry.value ? AppColors.success : const Color(0xFF8E929E),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                entry.key,
                                style: TextStyle(
                                  fontSize: 13,
                                  decoration: entry.value ? TextDecoration.lineThrough : null,
                                  color: entry.value ? const Color(0xFF8E929E) : Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Local-First Data Export
          const Text('Local-First Data Portability', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Card(
            child: ListTile(
              leading: const Icon(Icons.file_download_outlined, color: AppColors.success),
              title: const Text('Export Local Backup (JSON)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              subtitle: const Text('Download all alarms, tasks, notes, journal & settings', style: TextStyle(fontSize: 12, color: Color(0xFF8E929E))),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => _handleDataExport(context),
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }
}

