import 'package:material_ui/material_ui.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/services/storage_service.dart';
import '../../../data/services/weather_service.dart';
import '../../../providers/automation_provider.dart';
import '../../../providers/before_you_go_provider.dart';
import '../../../providers/device_control_provider.dart';
import '../../../providers/geofence_provider.dart';
import '../../widgets/before_you_go_sheet.dart';
import '../../widgets/before_you_go_weather_banner.dart';
import '../../widgets/location_reminders_sheet.dart';
import '../../widgets/oem_hardening_sheet.dart';
import '../../widgets/oem_warning_banner.dart';
import '../automation/automation_hub_screen.dart';
import '../scout/phone_modes_screen.dart';
import '../settings/permission_center_screen.dart';
import 'bird_house_shared.dart';

/// Scout's House — Everyday Assistance, BeforeYouGo, Weather & Device Utilities (`#3B82F6`).
class ScoutHouseScreen extends StatefulWidget {
  static const Color scoutColor = Color(0xFF3B82F6);

  const ScoutHouseScreen({super.key});

  @override
  State<ScoutHouseScreen> createState() => _ScoutHouseScreenState();
}

class _ScoutHouseScreenState extends State<ScoutHouseScreen> {
  WeatherProviderInterface? _weatherService;
  WeatherInfo? _weatherInfo;

  @override
  void initState() {
    super.initState();
    _weatherService =
        tryReadProvider<WeatherProviderInterface>(context) ??
            LocalWeatherService();
    final service = _weatherService;
    if (service is LocalWeatherService) {
      service.addWeatherListener(_onWeatherUpdated);
    }
    _loadWeather();
  }

  void _onWeatherUpdated() {
    if (mounted) _loadWeather();
  }

  Future<void> _loadWeather() async {
    final info =
        await (_weatherService ?? LocalWeatherService()).getCurrentWeather();
    if (mounted) setState(() => _weatherInfo = info);
  }

  @override
  void dispose() {
    final service = _weatherService;
    if (service is LocalWeatherService) {
      service.removeWeatherListener(_onWeatherUpdated);
    }
    super.dispose();
  }

  void _openPermissionsAndBackupSheet(BuildContext context) {
    final l10n = context.l10n;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.sheetSurface(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.scrimHandle(sheetCtx),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                l10n.tr('house_scout_perm_sheet_title'),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary(sheetCtx),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                margin: EdgeInsets.zero,
                child: ListTile(
                  leading: const Icon(
                    Icons.verified_user_outlined,
                    color: AppColors.success,
                  ),
                  title: Text(
                    l10n.tr('permission_capability_center'),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  subtitle: Text(
                    l10n.tr('inspect_device_support_rationales_os_settings'),
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary(sheetCtx),
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    Navigator.of(sheetCtx).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const PermissionCenterScreen(),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              Card(
                margin: EdgeInsets.zero,
                child: ListTile(
                  leading: const Icon(
                    Icons.battery_saver_rounded,
                    color: ScoutHouseScreen.scoutColor,
                  ),
                  title: Text(
                    l10n.tr('house_scout_oem_guard_title'),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  subtitle: Text(
                    l10n.tr('house_scout_oem_guard_sub'),
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary(sheetCtx),
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    Navigator.of(sheetCtx).pop();
                    OemHardeningSheet.show(context);
                  },
                ),
              ),
              const SizedBox(height: 8),
              Card(
                margin: EdgeInsets.zero,
                child: ListTile(
                  leading: const Icon(
                    Icons.file_download_outlined,
                    color: AppColors.accent,
                  ),
                  title: Text(
                    l10n.tr('export_local_backup_json'),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  subtitle: Text(
                    l10n.tr('download_all_alarms_tasks_notes_journal'),
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary(sheetCtx),
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    Navigator.of(sheetCtx).pop();
                    _handleDataExport(context);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleDataExport(BuildContext context) {
    final storage = tryReadProvider<StorageService>(context);
    if (storage == null) return;
    final jsonStr = storage.exportFullBackupJson();
    final l10n = context.l10n;

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.tr('local_backup_export')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.tr('full_application_state_exported_as_local')),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.recessedSurface(ctx),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border(ctx)),
              ),
              child: Text(
                '${jsonStr.substring(0, jsonStr.length > 200 ? 200 : jsonStr.length)}...',
                style: TextStyle(
                  fontSize: 11,
                  fontFamily: 'monospace',
                  color: AppColors.textSecondary(ctx),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n.tr('done')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final bygProvider = tryWatchProvider<BeforeYouGoProvider>(context);
    final geofenceProvider = tryWatchProvider<GeofenceProvider>(context);
    final deviceControl = tryWatchProvider<DeviceControlProvider>(context);
    final automation = tryWatchProvider<AutomationProvider>(context);

    final armedCount = geofenceProvider?.armedCount ?? 0;
    final activeRules =
        automation?.rules.where((r) => r.isEnabled).length ?? 0;
    final activeModeName = deviceControl?.activePhoneMode?.name;

    return Scaffold(
      key: const Key('scout_house_screen'),
      appBar: buildBirdHouseAppBar(
        context,
        title: l10n.tr('house_scout_title'),
        subtitle: l10n.tr('nest_scout_subtitle'),
        spriteAsset: 'assets/mascots/sprites/scout/briefing.png',
        accentColor: ScoutHouseScreen.scoutColor,
        fallbackIcon: Icons.explore_rounded,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          _buildHeroCard(context, l10n, bygProvider),
          const SizedBox(height: 8),
          const OemWarningBanner(),
          const SizedBox(height: 14),
          BirdSectionLabel(
            text: l10n.tr('house_tools_section'),
            accentColor: ScoutHouseScreen.scoutColor,
          ),
          BirdToolGrid(
            tiles: [
              BirdToolTile(
                tileKey: const Key('scout_tool_location'),
                title: l10n.tr('house_scout_location_title'),
                subtitle: l10n.tr(
                  'house_scout_location_sub',
                  {'count': armedCount},
                ),
                icon: Icons.location_on_rounded,
                accentColor: ScoutHouseScreen.scoutColor,
                onTap: () => LocationRemindersSheet.show(context),
              ),
              BirdToolTile(
                tileKey: const Key('scout_tool_phone_modes'),
                title: l10n.tr('house_scout_modes_title'),
                subtitle: activeModeName != null
                    ? l10n.tr('mode_active_label', {'name': activeModeName})
                    : l10n.tr('house_scout_modes_sub'),
                icon: Icons.shield_moon_rounded,
                accentColor: const Color(0xFF0EA5E9),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const PhoneModesScreen(),
                  ),
                ),
              ),
              BirdToolTile(
                tileKey: const Key('scout_tool_automations'),
                title: l10n.tr('house_scout_auto_title'),
                subtitle: l10n.tr(
                  'house_scout_auto_sub',
                  {'count': activeRules},
                ),
                icon: Icons.auto_awesome_rounded,
                accentColor: AppColors.accent,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const AutomationHubScreen(),
                  ),
                ),
              ),
              BirdToolTile(
                tileKey: const Key('scout_tool_permissions_backup'),
                title: l10n.tr('house_scout_perm_backup_title'),
                subtitle: l10n.tr('house_scout_perm_backup_sub'),
                icon: Icons.verified_user_outlined,
                accentColor: AppColors.success,
                onTap: () => _openPermissionsAndBackupSheet(context),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeroCard(
    BuildContext context,
    AppLocalizations l10n,
    BeforeYouGoProvider? bygProvider,
  ) {
    final isDark = AppColors.isDark(context);
    final weather = bygProvider?.currentWeather ?? _weatherInfo;
    final preset = bygProvider?.activePreset;
    final visual = weather != null
        ? BeforeYouGoWeatherBanner.resolveWeatherVisual(context, weather)
        : null;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? const [Color(0xFF172233), Color(0xFF1A1B20)]
              : const [Color(0xFFEFF6FF), Color(0xFFF8FAFC)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: ScoutHouseScreen.scoutColor
              .withValues(alpha: isDark ? 0.38 : 0.28),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.tr('house_scout_hero_title'),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AppColors.adaptive(
                          context,
                          dark: const Color(0xFF93C5FD),
                          light: const Color(0xFF1D4ED8),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (weather != null)
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (visual != null)
                            Icon(visual.icon, color: visual.color, size: 24),
                          Text(
                            '${weather.temperatureCelsius.round()}°C',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              color: AppColors.textPrimary(context),
                            ),
                          ),
                          Text(
                            weather.condition,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary(context),
                            ),
                          ),
                        ],
                      ),
                    if (weather != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        weather.advice,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary(context),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 72,
                height: 72,
                child: Image.asset(
                  'assets/mascots/sprites/scout/before_you_go.png',
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => Icon(
                    Icons.door_front_door_outlined,
                    size: 44,
                    color: ScoutHouseScreen.scoutColor,
                  ),
                ),
              ),
            ],
          ),
          if (bygProvider != null) ...[
            const SizedBox(height: 10),
            BeforeYouGoWeatherBanner(provider: bygProvider, compact: true),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              if (preset != null)
                Expanded(
                  child: Text(
                    '${preset.name} • ${l10n.tr('nest_pill_scout_ready', {'checked': preset.checkedCount, 'total': preset.totalCount})}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary(context),
                    ),
                  ),
                ),
              FilledButton.icon(
                onPressed: () => BeforeYouGoSheet.show(context),
                style: FilledButton.styleFrom(
                  backgroundColor: ScoutHouseScreen.scoutColor,
                  foregroundColor: Colors.white,
                  visualDensity: VisualDensity.compact,
                ),
                icon: const Icon(Icons.checklist_rtl_rounded, size: 16),
                label: Text(
                  l10n.tr('house_scout_open_checklist'),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
