import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../core/l10n/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/alarm_category.dart';
import '../../data/models/location_reminder.dart';
import '../../data/models/saved_place.dart';
import '../../providers/geofence_provider.dart';

const Color _scoutBlue = AppColors.scout;
const Color _emerald = AppColors.pippin;
const Color _amber = AppColors.twill;
const Color _coral = AppColors.roo;

class LocationRemindersSheet extends StatefulWidget {
  final int initialTab;

  const LocationRemindersSheet({super.key, this.initialTab = 0});

  static Future<void> show(BuildContext context, {int initialTab = 0}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => LocationRemindersSheet(initialTab: initialTab),
    );
  }

  @override
  State<LocationRemindersSheet> createState() => _LocationRemindersSheetState();
}

class _LocationRemindersSheetState extends State<LocationRemindersSheet> {
  late int _tabIndex; // 0 = Reminders, 1 = Places, 2 = Activity
  int _reminderFilter = 0; // 0 = Active, 1 = Arrive, 2 = Leave, 3 = Done
  String? _simPlaceId;

  @override
  void initState() {
    super.initState();
    _tabIndex = widget.initialTab;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final provider = Provider.of<GeofenceProvider>(context);
    final maxHeight = MediaQuery.of(context).size.height * 0.90;

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: BoxDecoration(
        color: AppColors.sheetSurface(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag handle + Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 16, 10),
            child: Column(
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.scrimHandle(context),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _scoutBlue.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.explore_rounded,
                        color: _scoutBlue,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.tr('notif_channel_geofence_name'),
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary(context),
                            ),
                          ),
                          Text(
                            l10n.tr('native_geofence_arrival_departure_triggers'),
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: l10n.tr('close'),
                      icon: Icon(
                        Icons.close_rounded,
                        color: AppColors.textPrimary(context),
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Permission & Native Geofence Status Banner
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildPermissionBanner(context, provider),
          ),
          const SizedBox(height: 10),

          // Section Tabs
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _buildTabButton(
                  l10n.tr('triggers', {'provider_length': provider.pendingReminders.length}),
                  0,
                ),
                const SizedBox(width: 8),
                _buildTabButton(
                  l10n.tr('places', {'provider_length': provider.places.length}),
                  1,
                ),
                const SizedBox(width: 8),
                _buildTabButton(
                  l10n.tr('activity', {'provider_length': provider.logs.length}),
                  2,
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Body
          Expanded(
            child: _tabIndex == 0
                ? _buildRemindersTab(context, provider)
                : (_tabIndex == 1
                    ? _buildPlacesTab(context, provider)
                    : _buildActivityTab(context, provider)),
          ),

          // Bottom Action Bar
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
              decoration: BoxDecoration(
                color: AppColors.recessedSurface(context),
                border: Border(
                  top: BorderSide(color: AppColors.border(context)),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        if (_tabIndex == 1) {
                          showSavedPlaceEditorDialog(context);
                        } else {
                          showLocationReminderEditorDialog(context);
                        }
                      },
                      icon: Icon(
                        _tabIndex == 1
                            ? Icons.add_location_alt_rounded
                            : Icons.add_alert_rounded,
                        size: 18,
                        color: Colors.white,
                      ),
                      label: Text(
                        _tabIndex == 1
                            ? l10n.tr('add_saved_place')
                            : l10n.tr('new_location_reminder'),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _scoutBlue,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionBanner(
    BuildContext context,
    GeofenceProvider provider,
  ) {
    final l10n = context.l10n;
    final perm = provider.permissionState;
    final Color statusColor;
    final String message;
    final String actionLabel;
    VoidCallback? actionCallback;

    if (perm == LocationPermissionState.alwaysGranted) {
      statusColor = _emerald;
      message = l10n.tr('background_geofencing_armed_active_rules', {'provider_armedCount': provider.armedCount});
      actionLabel = 'GPS';
      actionCallback = () async {
        final coord = await provider.refreshCurrentLocation(
          evaluateTransitions: true,
        );
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                coord != null
                    ? l10n.tr('gps_updated', {'coord_4': coord.longitude.toStringAsFixed(4)})
                    : l10n.tr('no_recent_gps_fix_returned_by'),
              ),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      };
    } else if (perm == LocationPermissionState.whileInUse) {
      statusColor = _amber;
      message = l10n.tr('foreground_only_grant_always_allow_for');
      actionLabel = l10n.tr('always');
      actionCallback = () => provider.requestBackgroundPermission();
    } else if (perm == LocationPermissionState.deniedForever) {
      statusColor = _coral;
      message = l10n.tr('location_permission_disabled_enable_in_system');
      actionLabel = l10n.tr('settings');
      actionCallback = () => provider.openLocationSettings();
    } else {
      statusColor = _scoutBlue;
      message = l10n.tr('grant_location_permission_to_arm_native');
      actionLabel = l10n.tr('enable');
      actionCallback = () => provider.requestForegroundPermission();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(
            perm.isReadyForBackground
                ? Icons.verified_user_rounded
                : Icons.my_location_rounded,
            size: 16,
            color: statusColor,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: statusColor,
              ),
            ),
          ),
          TextButton(
            onPressed: actionCallback,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textPrimary(context),
              backgroundColor: statusColor.withValues(alpha: 0.25),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              actionLabel,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(String label, int index) {
    final isSelected = _tabIndex == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _tabIndex = index),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: isSelected ? _scoutBlue : AppColors.elevatedSurface(context),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? _scoutBlue : AppColors.border(context),
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isSelected ? Colors.white : AppColors.textSecondary(context),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRemindersTab(BuildContext context, GeofenceProvider provider) {
    final l10n = context.l10n;
    final List<LocationReminder> list;
    switch (_reminderFilter) {
      case 1:
        list = provider.arriveReminders;
        break;
      case 2:
        list = provider.leaveReminders;
        break;
      case 3:
        list = provider.completedReminders;
        break;
      default:
        list = provider.pendingReminders;
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _buildFilterChip(
                    l10n.tr('active_4', {'provider_length': provider.pendingReminders.length}),
                    0),
                _buildFilterChip(
                    l10n.tr('arrive', {'provider_length': provider.arriveReminders.length}),
                    1),
                _buildFilterChip(
                    l10n.tr('leave', {'provider_length': provider.leaveReminders.length}),
                    2),
                _buildFilterChip(
                    l10n.tr('done_3', {'provider_length': provider.completedReminders.length}),
                    3),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: list.isEmpty
              ? _buildEmptyBox(
                  icon: Icons.location_searching_rounded,
                  title: l10n.tr('no_matching_location_triggers'),
                  subtitle: l10n.tr('create_an_arrival_or_departure_reminder'),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (ctx, i) {
                    final item = list[i];
                    final place = provider.findPlaceById(item.placeId);
                    final dist = place != null
                        ? provider.distanceToPlaceMeters(place)
                        : null;
                    return _buildReminderTile(context, provider, item, place, dist);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, int index) {
    final selected = _reminderFilter == index;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: selected ? Colors.white : AppColors.textSecondary(context),
        ),
      ),
      selected: selected,
      selectedColor: _scoutBlue,
      backgroundColor: AppColors.elevatedSurface(context),
      side: BorderSide(
        color: selected ? _scoutBlue : AppColors.border(context),
      ),
      onSelected: (_) => setState(() => _reminderFilter = index),
    );
  }

  Widget _buildReminderTile(
    BuildContext context,
    GeofenceProvider provider,
    LocationReminder item,
    SavedPlace? place,
    double? distanceMeters,
  ) {
    final l10n = context.l10n;
    final placeName = place?.name ?? l10n.tr('unknown_place');
    final placeEmoji = place?.category.emoji ?? '📍';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.elevatedSurface(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: item.isArmed
              ? _scoutBlue.withValues(alpha: 0.35)
              : AppColors.border(context),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              InkWell(
                onTap: () => provider.toggleCompletion(item.id),
                child: Icon(
                  item.isCompleted
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: item.isCompleted ? _emerald : _scoutBlue,
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: item.isCompleted
                            ? AppColors.textSecondary(context)
                            : AppColors.textPrimary(context),
                        decoration: item.isCompleted
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.describeRule(placeName),
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary(context),
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: item.isEnabled,
                onChanged: (_) => provider.toggleEnabled(item.id),
              ),
            ],
          ),
          if (item.notes.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              item.notes,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary(context),
              ),
            ),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _metaPill(
                '${item.triggerType.emoji} ${item.triggerType.displayName}',
                _scoutBlue,
              ),
              _metaPill(
                '$placeEmoji $placeName${place != null ? ' • ${place.formattedRadius}' : ''}',
                AppColors.adaptive(
                  context,
                  dark: _emerald,
                  light: AppColors.pippinDark,
                ),
              ),
              _metaPill(
                item.oneTimeOnly
                    ? l10n.tr('k_1_time')
                    : l10n.tr('repeats_m_cooldown', {'item_safeCooldownMinutes': item.safeCooldownMinutes}),
                AppColors.textSecondary(context),
              ),
              if (item.checkDepartureChecklist)
                _metaPill(
                  '🗝️ BeforeYouGo',
                  AppColors.adaptive(
                    context,
                    dark: _amber,
                    light: AppColors.twillDark,
                  ),
                ),
              if (distanceMeters != null)
                _metaPill(
                  l10n.tr('m_away', {'distanceMeters_round': distanceMeters.round()}),
                  AppColors.textSecondary(context),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: () async {
                  await provider.simulateTrigger(item.id);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          l10n.tr('test_triggered_near', {'item_title': item.title, 'placeName': placeName}),
                        ),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.notifications_active_outlined, size: 15),
                label: Text(l10n.tr('test_trigger'),
                    style: const TextStyle(fontSize: 11)),
                style: TextButton.styleFrom(
                  foregroundColor: _scoutBlue,
                  visualDensity: VisualDensity.compact,
                ),
              ),
              const SizedBox(width: 4),
              TextButton.icon(
                onPressed: () => showLocationReminderEditorDialog(
                  context,
                  existing: item,
                ),
                icon: const Icon(Icons.edit_outlined, size: 15),
                label: Text(l10n.tr('edit_2'),
                    style: const TextStyle(fontSize: 11)),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textSecondary(context),
                  visualDensity: VisualDensity.compact,
                ),
              ),
              IconButton(
                tooltip: l10n.tr('delete_reminder'),
                icon: Icon(
                  Icons.delete_outline_rounded,
                  size: 18,
                  color: AppColors.textSecondary(context),
                ),
                onPressed: () => provider.deleteReminder(item.id),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPlacesTab(BuildContext context, GeofenceProvider provider) {
    final l10n = context.l10n;
    final places = provider.places;
    if (places.isEmpty) {
      return _buildEmptyBox(
        icon: Icons.add_location_alt_rounded,
        title: l10n.tr('no_designated_places_yet'),
        subtitle: l10n.tr('add_home_work_gym_or_stores'),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      itemCount: places.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (ctx, i) {
        final place = places[i];
        final armedForPlace = provider.armedReminderCountForPlace(place.id);
        final dist = provider.distanceToPlaceMeters(place);
        final inside = provider.isCurrentlyInsidePlace(place);
        final accent = Color(place.category.colorValue);

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.elevatedSurface(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: accent.withValues(alpha: 0.35)),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accent.withValues(alpha: 0.14),
                  border: Border.all(color: accent.withValues(alpha: 0.5)),
                ),
                alignment: Alignment.center,
                child: Text(
                  place.category.emoji,
                  style: const TextStyle(fontSize: 22),
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
                            place.name,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary(context),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        _metaPill(place.formattedRadius, accent),
                      ],
                    ),
                    if (place.address.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        place.address,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary(context),
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      '${place.formattedCoordinates} • ${l10n.tr('armed_3', {'armedForPlace': armedForPlace})}${dist != null ? ' • ${inside == true ? l10n.tr('inside') : '${dist.round()} m'}' : ''}',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary(context),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: l10n.tr('add_reminder_for', {'place_name': place.name}),
                icon: const Icon(Icons.add_alert_outlined,
                    size: 19, color: _scoutBlue),
                onPressed: () => showLocationReminderEditorDialog(
                  context,
                  initialPlaceId: place.id,
                ),
                visualDensity: VisualDensity.compact,
              ),
              IconButton(
                tooltip: l10n.tr('edit_place'),
                icon: Icon(Icons.edit_outlined,
                    size: 18, color: AppColors.textSecondary(context)),
                onPressed: () =>
                    showSavedPlaceEditorDialog(context, existing: place),
                visualDensity: VisualDensity.compact,
              ),
              IconButton(
                tooltip: l10n.tr('delete_place'),
                icon: Icon(Icons.delete_outline_rounded,
                    size: 18, color: AppColors.textSecondary(context)),
                onPressed: () => provider.deletePlace(place.id),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActivityTab(BuildContext context, GeofenceProvider provider) {
    final l10n = context.l10n;
    final places = provider.places;
    final selectedPlace = places.isEmpty
        ? null
        : places.firstWhere(
            (p) => p.id == _simPlaceId,
            orElse: () => places.first,
          );

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      children: [
        if (selectedPlace != null)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.elevatedSurface(context),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _scoutBlue.withValues(alpha: 0.35)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.radar_rounded, color: _scoutBlue, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l10n.tr('geofence_boundary_simulator'),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary(context),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  l10n.tr('test_arrival_and_departure_alerts_at'),
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary(context),
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: selectedPlace.id,
                  dropdownColor: AppColors.sheetSurface(context),
                  decoration: InputDecoration(
                    labelText: l10n.tr('target_place'),
                    isDense: true,
                  ),
                  items: places
                      .map(
                        (p) => DropdownMenuItem(
                          value: p.id,
                          child: Text('${p.category.emoji} ${p.name}'),
                        ),
                      )
                      .toList(),
                  onChanged: (val) => setState(() => _simPlaceId = val),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          // First ensure coordinate outside, then move inside center
                          await provider.evaluateCoordinateSweep(
                            selectedPlace.clampedLatitude + 0.05,
                            selectedPlace.clampedLongitude + 0.05,
                            isSimulated: true,
                          );
                          final fired = await provider.evaluateCoordinateSweep(
                            selectedPlace.clampedLatitude,
                            selectedPlace.clampedLongitude,
                            isSimulated: true,
                          );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  fired.isEmpty
                                      ? l10n.tr('simulated_arrival_at_no_matching_arrival', {'selectedPlace_name': selectedPlace.name})
                                      : l10n.tr('arrival_fired_reminder_s_at', {'fired_length': fired.length, 'selectedPlace_name': selectedPlace.name}),
                                ),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.login_rounded, size: 16),
                        label: Text(
                          l10n.tr('simulate_arrive'),
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          // First place coordinate inside, then move 5km away
                          await provider.evaluateCoordinateSweep(
                            selectedPlace.clampedLatitude,
                            selectedPlace.clampedLongitude,
                            isSimulated: true,
                          );
                          final fired = await provider.evaluateCoordinateSweep(
                            selectedPlace.clampedLatitude + 0.05,
                            selectedPlace.clampedLongitude + 0.05,
                            isSimulated: true,
                          );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  fired.isEmpty
                                      ? l10n.tr('simulated_departure_from_no_matching_departure', {'selectedPlace_name': selectedPlace.name})
                                      : l10n.tr('departure_fired_reminder_s_from', {'fired_length': fired.length, 'selectedPlace_name': selectedPlace.name}),
                                ),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.logout_rounded, size: 16),
                        label: Text(
                          l10n.tr('simulate_leave'),
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              l10n.tr('recent_trigger_log'),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
            if (provider.logs.isNotEmpty)
              TextButton(
                onPressed: provider.clearLogs,
                child: Text(l10n.tr('clear_3'),
                    style: const TextStyle(fontSize: 12)),
              ),
          ],
        ),
        if (provider.logs.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 24),
            child: _buildEmptyBox(
              icon: Icons.history_rounded,
              title: l10n.tr('no_geofence_events_recorded_yet'),
              subtitle: l10n.tr('arrival_and_departure_triggers_appear_here'),
            ),
          )
        else
          ...provider.logs.map((log) {
            final timeStr =
                l10n.formatDate(log.triggeredAt, 'MMM d • HH:mm');
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.elevatedSurface(context),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border(context)),
              ),
              child: Row(
                children: [
                  Text(log.event.emoji, style: const TextStyle(fontSize: 18)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          log.reminderTitle,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary(context),
                          ),
                        ),
                        Text(
                          '${log.event.displayName} ${log.placeName} • $timeStr',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                  _metaPill(
                    log.isSimulated
                        ? l10n.tr('simulated')
                        : l10n.tr('native_os'),
                    log.isSimulated
                        ? AppColors.adaptive(
                            context,
                            dark: _amber,
                            light: AppColors.twillDark,
                          )
                        : AppColors.adaptive(
                            context,
                            dark: _emerald,
                            light: AppColors.pippinDark,
                          ),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  Widget _metaPill(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  Widget _buildEmptyBox({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 42, color: _scoutBlue),
            const SizedBox(height: 10),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary(context),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Opens a modal dialog to create or edit a [LocationReminder].
Future<void> showLocationReminderEditorDialog(
  BuildContext context, {
  LocationReminder? existing,
  String? initialPlaceId,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => _LocationReminderEditorDialog(
      existing: existing,
      initialPlaceId: initialPlaceId,
    ),
  );
}

class _LocationReminderEditorDialog extends StatefulWidget {
  final LocationReminder? existing;
  final String? initialPlaceId;

  const _LocationReminderEditorDialog({
    this.existing,
    this.initialPlaceId,
  });

  @override
  State<_LocationReminderEditorDialog> createState() =>
      _LocationReminderEditorDialogState();
}

class _LocationReminderEditorDialogState
    extends State<_LocationReminderEditorDialog> {
  late TextEditingController _titleCtrl;
  late TextEditingController _notesCtrl;
  String? _selectedPlaceId;
  late GeofenceTriggerType _triggerType;
  late AlarmCategory _category;
  late bool _oneTimeOnly;
  late bool _checkDeparture;
  late int _cooldown;

  @override
  void initState() {
    super.initState();
    final provider = Provider.of<GeofenceProvider>(context, listen: false);
    final e = widget.existing;
    _titleCtrl = TextEditingController(text: e?.title ?? '');
    _notesCtrl = TextEditingController(text: e?.notes ?? '');
    _selectedPlaceId = e?.placeId ??
        widget.initialPlaceId ??
        (provider.places.isNotEmpty ? provider.places.first.id : null);
    _triggerType = e?.triggerType ?? GeofenceTriggerType.arrive;
    _category =
        e?.category ?? AlarmCategory.fromType(AlarmCategoryType.personal);
    _oneTimeOnly = e?.oneTimeOnly ?? false;
    _checkDeparture = e?.checkDepartureChecklist ?? false;
    _cooldown = e?.cooldownMinutes ?? 30;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final provider = Provider.of<GeofenceProvider>(context);
    final places = provider.places;
    if (_selectedPlaceId == null && places.isNotEmpty) {
      _selectedPlaceId = places.first.id;
    }

    return AlertDialog(
      backgroundColor: AppColors.sheetSurface(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      title: Text(
        widget.existing == null
            ? l10n.tr('new_location_reminder')
            : l10n.tr('edit_location_reminder'),
        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _titleCtrl,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: l10n.tr('remind_me_to'),
                  hintText: l10n.tr('e_g_take_gym_bag_buy'),
                  prefixIcon: const Icon(Icons.notifications_active_outlined),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _notesCtrl,
                decoration: InputDecoration(
                  labelText: l10n.tr('notes_optional'),
                  prefixIcon: const Icon(Icons.notes_rounded),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      l10n.tr('designated_place'),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary(context),
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () async {
                      final added = await showSavedPlaceEditorDialog(context);
                      if (added != null && mounted) {
                        setState(() => _selectedPlaceId = added.id);
                      }
                    },
                    icon: const Icon(Icons.add_location_rounded, size: 15),
                    label: Text(l10n.tr('new_place'),
                        style: const TextStyle(fontSize: 11)),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ),
              if (places.isEmpty)
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _amber.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    l10n.tr('add_a_place_first_using_new'),
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.adaptive(
                        context,
                        dark: _amber,
                        light: AppColors.twillDark,
                      ),
                    ),
                  ),
                )
              else
                DropdownButtonFormField<String>(
                  initialValue: places.any((p) => p.id == _selectedPlaceId)
                      ? _selectedPlaceId
                      : places.first.id,
                  isExpanded: true,
                  dropdownColor: AppColors.sheetSurface(context),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.place_rounded),
                    isDense: true,
                  ),
                  items: places
                      .map(
                        (p) => DropdownMenuItem(
                          value: p.id,
                          child: Text(
                            '${p.category.emoji} ${p.name} (${p.formattedRadius})',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (val) => setState(() => _selectedPlaceId = val),
                ),
              const SizedBox(height: 14),
              Text(
                l10n.tr('geofence_trigger_event'),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary(context),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: GeofenceTriggerType.values.map((t) {
                  final selected = _triggerType == t;
                  return ChoiceChip(
                    label: Text('${t.emoji} ${t.displayName}'),
                    selected: selected,
                    selectedColor: _scoutBlue,
                    onSelected: (_) => setState(() => _triggerType = t),
                  );
                }).toList(),
              ),
              const SizedBox(height: 10),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  l10n.tr('one_time_trigger'),
                  style: const TextStyle(fontSize: 13),
                ),
                subtitle: Text(
                  l10n.tr('automatically_complete_after_firing_once'),
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary(context),
                  ),
                ),
                value: _oneTimeOnly,
                onChanged: (val) => setState(() => _oneTimeOnly = val),
              ),
              if (!_oneTimeOnly)
                DropdownButtonFormField<int>(
                  initialValue: _cooldown,
                  isExpanded: true,
                  dropdownColor: AppColors.sheetSurface(context),
                  decoration: InputDecoration(
                    labelText: l10n.tr('re_trigger_cooldown'),
                    prefixIcon: const Icon(Icons.hourglass_bottom_rounded),
                    isDense: true,
                  ),
                  items: [
                    DropdownMenuItem(
                        value: 0,
                        child: Text(l10n.tr('no_cooldown'))),
                    DropdownMenuItem(
                        value: 15,
                        child: Text(l10n.tr('k_15_minutes'))),
                    DropdownMenuItem(
                        value: 30,
                        child: Text(l10n.tr('k_30_minutes'))),
                    DropdownMenuItem(
                        value: 60,
                        child: Text(l10n.tr('k_1_hour'))),
                    DropdownMenuItem(
                        value: 240,
                        child: Text(l10n.tr('k_4_hours'))),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _cooldown = val);
                  },
                ),
              if (_triggerType != GeofenceTriggerType.arrive)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    l10n.tr('include_beforeyougo_check'),
                    style: const TextStyle(fontSize: 13),
                  ),
                  subtitle: Text(
                    l10n.tr('remind_to_check_keys_wallet_essentials'),
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary(context),
                    ),
                  ),
                  value: _checkDeparture,
                  onChanged: (val) => setState(() => _checkDeparture = val),
                ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: AlarmCategory.predefined.map((cat) {
                    final selected = _category.type == cat.type;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        selected: selected,
                        label: Text(cat.displayName),
                        selectedColor: cat.color,
                        onSelected: (_) => setState(() => _category = cat),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.tr('cancel')),
        ),
        ElevatedButton(
          onPressed: _selectedPlaceId == null
              ? null
              : () async {
                  final title = _titleCtrl.text.trim();
                  if (title.isEmpty) return;

                  final now = DateTime.now();
                  final e = widget.existing;
                  final item = LocationReminder(
                    id: e?.id ?? const Uuid().v4(),
                    title: title,
                    notes: _notesCtrl.text.trim(),
                    placeId: _selectedPlaceId!,
                    triggerType: _triggerType,
                    category: _category,
                    isEnabled: e?.isEnabled ?? true,
                    isCompleted: e?.isCompleted ?? false,
                    oneTimeOnly: _oneTimeOnly,
                    cooldownMinutes: _cooldown,
                    checkDepartureChecklist: _checkDeparture,
                    lastTriggeredAt: e?.lastTriggeredAt,
                    completedAt: e?.completedAt,
                    createdAt: e?.createdAt ?? now,
                  );

                  if (e == null) {
                    await provider.addReminder(item);
                  } else {
                    await provider.updateReminder(item);
                  }
                  if (context.mounted) Navigator.of(context).pop();
                },
          style: ElevatedButton.styleFrom(backgroundColor: _scoutBlue),
          child: Text(
            widget.existing == null
                ? l10n.tr('save_trigger')
                : l10n.tr('update_trigger'),
            style: const TextStyle(color: Colors.white),
          ),
        ),
      ],
    );
  }
}

/// Opens a modal dialog to create or edit a designated [SavedPlace] geofence zone.
Future<SavedPlace?> showSavedPlaceEditorDialog(
  BuildContext context, {
  SavedPlace? existing,
}) {
  return showDialog<SavedPlace>(
    context: context,
    builder: (_) => _SavedPlaceEditorDialog(existing: existing),
  );
}

class _SavedPlaceEditorDialog extends StatefulWidget {
  final SavedPlace? existing;

  const _SavedPlaceEditorDialog({this.existing});

  @override
  State<_SavedPlaceEditorDialog> createState() =>
      _SavedPlaceEditorDialogState();
}

class _SavedPlaceEditorDialogState extends State<_SavedPlaceEditorDialog> {
  late TextEditingController _nameCtrl;
  late TextEditingController _addrCtrl;
  late TextEditingController _latCtrl;
  late TextEditingController _lngCtrl;
  late PlaceCategory _category;
  late double _radiusMeters;
  late double _defaultLat;
  late double _defaultLng;
  bool _isFetchingGps = false;

  @override
  void initState() {
    super.initState();
    final provider = Provider.of<GeofenceProvider>(context, listen: false);
    final e = widget.existing;
    _nameCtrl = TextEditingController(text: e?.name ?? '');
    _addrCtrl = TextEditingController(text: e?.address ?? '');
    _defaultLat = e?.latitude ??
        provider.lastKnownCoordinate?.latitude ??
        37.7749;
    _defaultLng = e?.longitude ??
        provider.lastKnownCoordinate?.longitude ??
        -122.4194;
    _latCtrl = TextEditingController(text: _defaultLat.toStringAsFixed(5));
    _lngCtrl = TextEditingController(text: _defaultLng.toStringAsFixed(5));
    _category = e?.category ?? PlaceCategory.home;
    _radiusMeters = e?.clampedRadiusMeters ?? _category.defaultRadiusMeters;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addrCtrl.dispose();
    _latCtrl.dispose();
    _lngCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final provider = Provider.of<GeofenceProvider>(context, listen: false);

    return AlertDialog(
      backgroundColor: AppColors.sheetSurface(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      title: Text(
        widget.existing == null
            ? l10n.tr('add_saved_place')
            : l10n.tr('edit_saved_place'),
        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _nameCtrl,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: l10n.tr('place_name'),
                  hintText: l10n.tr('e_g_home_supermarket_office'),
                  prefixIcon: const Icon(Icons.label_outline_rounded),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _addrCtrl,
                decoration: InputDecoration(
                  labelText: l10n.tr('address_or_landmark_optional'),
                  prefixIcon: const Icon(Icons.signpost_outlined),
                ),
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: PlaceCategory.values.map((cat) {
                    final selected = _category == cat;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        selected: selected,
                        label: Text('${cat.emoji} ${cat.displayName}'),
                        selectedColor: Color(cat.colorValue),
                        onSelected: (_) {
                          setState(() {
                            _category = cat;
                            if (widget.existing == null) {
                              _radiusMeters = cat.defaultRadiusMeters;
                            }
                          });
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _isFetchingGps
                    ? null
                    : () async {
                        setState(() => _isFetchingGps = true);
                        final coord = await provider.refreshCurrentLocation();
                        if (coord != null && mounted) {
                          _latCtrl.text = coord.latitude.toStringAsFixed(5);
                          _lngCtrl.text = coord.longitude.toStringAsFixed(5);
                        }
                        if (mounted) setState(() => _isFetchingGps = false);
                      },
                icon: const Icon(Icons.my_location_rounded, size: 16),
                label: Text(
                  _isFetchingGps
                      ? l10n.tr('locating_gps')
                      : l10n.tr('use_current_gps_location'),
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _latCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        signed: true,
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: l10n.tr('latitude'),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _lngCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        signed: true,
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: l10n.tr('longitude'),
                        isDense: true,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.tr('geofence_radius'),
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary(context),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    l10n.tr('meters', {'radiusMeters_round': _radiusMeters.round()}),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: _scoutBlue,
                    ),
                  ),
                ],
              ),
              Slider(
                value: _radiusMeters.clamp(50.0, 2000.0),
                min: 50.0,
                max: 2000.0,
                divisions: 39,
                activeColor: _scoutBlue,
                label: '${_radiusMeters.round()} m',
                onChanged: (val) => setState(() => _radiusMeters = val),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.tr('cancel')),
        ),
        ElevatedButton(
          onPressed: () async {
            final name = _nameCtrl.text.trim();
            if (name.isEmpty) return;
            final lat = double.tryParse(_latCtrl.text.trim()) ?? _defaultLat;
            final lng = double.tryParse(_lngCtrl.text.trim()) ?? _defaultLng;
            final e = widget.existing;

            final place = SavedPlace(
              id: e?.id ?? const Uuid().v4(),
              name: name,
              address: _addrCtrl.text.trim(),
              latitude: lat.clamp(-90.0, 90.0).toDouble(),
              longitude: lng.clamp(-180.0, 180.0).toDouble(),
              radiusMeters: _radiusMeters.clamp(
                SavedPlace.minRadiusMeters,
                SavedPlace.maxRadiusMeters,
              ),
              category: _category,
              createdAt: e?.createdAt ?? DateTime.now(),
            );

            if (e == null) {
              await provider.addPlace(place);
            } else {
              await provider.updatePlace(place);
            }
            if (context.mounted) Navigator.of(context).pop(place);
          },
          style: ElevatedButton.styleFrom(backgroundColor: _scoutBlue),
          child: Text(
            widget.existing == null
                ? l10n.tr('save_place')
                : l10n.tr('update_place'),
            style: const TextStyle(color: Colors.white),
          ),
        ),
      ],
    );
  }
}
