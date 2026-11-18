import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/app_restriction.dart';
import '../../../data/models/device_capability.dart';
import '../../../data/models/digital_wellbeing.dart';
import '../../../providers/device_control_provider.dart';
import '../../widgets/skeleton_shimmer.dart';
import '../settings/permission_center_screen.dart';
import 'wellbeing_app_fast_tab.dart';
import 'wellbeing_app_picker_sheet.dart';
import 'wellbeing_focus_lock_tab.dart';
import 'wellbeing_intervention_dialog.dart';

/// Roo -> Time, Planning & Habits -> Digital Discipline & App Control.
///
/// Product-owned by Roo across five focused tabs:
/// 0. Overview (Dashboard: screen time, top apps, active fasts/focus, allowances, insights)
/// 1. App Fast (Long-term avoidance commitments)
/// 2. Focus Lock (Temporary restrictions synced with Roo Pomodoro)
/// 3. Usage Limits (Daily / weekday / weekend app allowances & graduated guards)
/// 4. Application Usage (Daily usage telemetry, honest device boundaries & audit logs)
class DigitalDisciplineScreen extends StatefulWidget {
  final int initialTab;
  final bool embedded;

  const DigitalDisciplineScreen({
    super.key,
    this.initialTab = 0,
    this.embedded = false,
  });

  @override
  State<DigitalDisciplineScreen> createState() =>
      _DigitalDisciplineScreenState();
}

class _DigitalDisciplineScreenState extends State<DigitalDisciplineScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 5,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 4),
    );
  }

  @override
  void didUpdateWidget(covariant DigitalDisciplineScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTab != widget.initialTab) {
      final target = widget.initialTab.clamp(0, 4);
      if (_tabController.index != target) {
        _tabController.animateTo(target);
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final provider = context.watch<DeviceControlProvider>();

    final tabBar = TabBar(
      controller: _tabController,
      isScrollable: true,
      tabAlignment: TabAlignment.start,
      tabs: [
        Tab(text: l10n.tr('overview')),
        Tab(text: l10n.tr('app_fast')),
        Tab(text: l10n.tr('focus_lock')),
        Tab(text: l10n.tr('usage_limits')),
        Tab(text: l10n.tr('application_usage')),
      ],
    );

    final tabViews = TabBarView(
      controller: _tabController,
      children: [
        _buildOverviewTab(context, provider),
        const WellbeingAppFastTab(),
        const WellbeingFocusLockTab(),
        _buildUsageLimitsTab(context, provider),
        _buildApplicationUsageTab(context, provider),
      ],
    );

    if (widget.embedded) {
      return Column(
        children: [
          Material(
            color: AppColors.cardSurface(context),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 8, 2),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.shield_moon_rounded,
                        color: AppColors.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l10n.tr('roo_digital_discipline'),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      ..._buildActionButtons(context, provider),
                    ],
                  ),
                ),
                tabBar,
              ],
            ),
          ),
          Expanded(child: tabViews),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.tr('roo_digital_discipline'),
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
        ),
        actions: _buildActionButtons(context, provider),
        bottom: tabBar,
      ),
      body: tabViews,
    );
  }

  List<Widget> _buildActionButtons(
    BuildContext context,
    DeviceControlProvider provider,
  ) {
    final l10n = context.l10n;
    return [
      IconButton(
        tooltip: l10n.tr('permission_center'),
        icon: const Icon(Icons.verified_user_outlined),
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const PermissionCenterScreen(),
            ),
          );
        },
      ),
      IconButton(
        tooltip: l10n.tr('refresh_usage_device_check'),
        icon: provider.isRefreshing
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.refresh_rounded),
        onPressed: provider.isRefreshing ? null : () => provider.refreshAll(),
      ),
    ];
  }

  // ---------------------------------------------------------------------------
  // Tab 0: Overview Dashboard
  // ---------------------------------------------------------------------------

  Widget _buildOverviewTab(
    BuildContext context,
    DeviceControlProvider provider,
  ) {
    if (provider.isRefreshing) {
      return const SkeletonCardList(
        itemCount: 4,
        lineCount: 3,
        showTrailingPill: true,
      );
    }
    final l10n = context.l10n;
    final now = DateTime.now();
    final snapshot = provider.usageSnapshot;
    final activeFasts = provider.appFastByStatus(AppFastStatus.active, now: now);
    final completedFasts =
        provider.appFastByStatus(AppFastStatus.completed, now: now);
    final activeSession = provider.activeFocusSession;
    final enabledRules = provider.appRules.where((r) => r.isEnabled).toList();
    final sortedUsage = [...snapshot.records]
      ..sort((a, b) => b.usedMinutesToday.compareTo(a.usedMinutesToday));

    var overLimitCount = 0;
    for (final rule in enabledRules) {
      final used =
          snapshot.recordForPackage(rule.packageName)?.usedMinutesToday ?? 0;
      if (used >= rule.effectiveLimitMinutesFor(now)) {
        overLimitCount++;
      }
    }

    final todayStart = DateTime(now.year, now.month, now.day);
    final interventionsToday = provider.interventionLogs
        .where((l) => !l.timestamp.isBefore(todayStart))
        .length;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Dashboard intro + top metrics
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.cardSurface(context),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.28),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.dashboard_rounded,
                    color: AppColors.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.tr('digital_discipline_title'),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                l10n.tr('discipline_overview_subtitle'),
                style: TextStyle(
                  fontSize: 12.5,
                  color: AppColors.textSecondary(context),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  _buildMetricTile(
                    context,
                    label: l10n.tr('daily_screen_time'),
                    value: _formatMinutes(snapshot.totalTrackedMinutes),
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 10),
                  _buildMetricTile(
                    context,
                    label: l10n.tr('active_app_fasts'),
                    value: '${activeFasts.length}',
                    color: AppColors.accent,
                  ),
                  const SizedBox(width: 10),
                  _buildMetricTile(
                    context,
                    label: l10n.tr('active_guards'),
                    value: '${enabledRules.length}',
                    color: AppColors.info,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        if (!snapshot.permissionGranted) ...[
          _buildUsagePermissionBanner(context, snapshot),
          const SizedBox(height: 12),
        ],

        // Active Focus Lock card
        _buildActiveFocusLockCard(context, provider, activeSession, now),
        const SizedBox(height: 12),

        // Active App Fast commitments card
        _buildOverviewSectionCard(
          context,
          title: l10n.tr('active_app_fasts'),
          icon: Icons.hourglass_top_rounded,
          color: AppColors.accent,
          actionLabel: l10n.tr('manage_app_fast'),
          onAction: () => _tabController.animateTo(1),
          child: activeFasts.isEmpty
              ? Text(
                  l10n.tr('no_active_app_fasts'),
                  style: TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textSecondary(context),
                  ),
                )
              : Column(
                  children: activeFasts.take(4).map((fast) {
                    final rem = fast.remainingDurationAt(now);
                    final remLabel = rem.inDays >= 1
                        ? '${rem.inDays}d'
                        : '${rem.inHours}h';
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  fast.title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13.5,
                                  ),
                                ),
                                Text(
                                  fast.targetAppNames.values.isNotEmpty
                                      ? fast.targetAppNames.values.join(', ')
                                      : fast.targetPackages.join(', '),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary(context),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Chip(
                            label: Text(
                              '${fast.mode.label} · $remLabel',
                              style: const TextStyle(fontSize: 11),
                            ),
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
        ),
        const SizedBox(height: 12),

        // Remaining App Allowances card
        _buildOverviewSectionCard(
          context,
          title: l10n.tr('remaining_app_allowances'),
          icon: Icons.timer_outlined,
          color: AppColors.info,
          actionLabel: l10n.tr('manage_usage_limits'),
          onAction: () => _tabController.animateTo(3),
          child: enabledRules.isEmpty
              ? Text(
                  l10n.tr('no_app_usage_recorded'),
                  style: TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textSecondary(context),
                  ),
                )
              : Column(
                  children: enabledRules.take(5).map((rule) {
                    final limit = rule.effectiveLimitMinutesFor(now);
                    final used = snapshot
                            .recordForPackage(rule.packageName)
                            ?.usedMinutesToday ??
                        0;
                    final remaining = (limit - used).clamp(0, limit);
                    final ratio =
                        limit > 0 ? (used / limit).clamp(0.0, 1.0) : 0.0;
                    final isOver = used >= limit;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  rule.displayName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              Text(
                                '${_formatMinutes(remaining)} / ${_formatMinutes(limit)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: isOver
                                      ? AppColors.error
                                      : AppColors.textSecondary(context),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: ratio,
                              minHeight: 6,
                              backgroundColor: AppColors.trackSurface(context),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                isOver
                                    ? AppColors.error
                                    : ratio >=
                                            (rule.warningThresholdPercent /
                                                100.0)
                                        ? AppColors.warning
                                        : AppColors.success,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
        ),
        const SizedBox(height: 12),

        // Most-Used Applications card
        _buildOverviewSectionCard(
          context,
          title: l10n.tr('most_used_apps'),
          icon: Icons.bar_chart_rounded,
          color: AppColors.primary,
          actionLabel: l10n.tr('application_usage'),
          onAction: () => _tabController.animateTo(4),
          child: sortedUsage.isEmpty
              ? Text(
                  l10n.tr('no_app_usage_recorded'),
                  style: TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textSecondary(context),
                  ),
                )
              : Column(
                  children: sortedUsage.take(5).map((r) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              r.appName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            _formatMinutes(r.usedMinutesToday),
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
        ),
        const SizedBox(height: 12),

        // Discipline Statistics & Insights card
        _buildOverviewSectionCard(
          context,
          title: l10n.tr('discipline_insights'),
          icon: Icons.insights_rounded,
          color: AppColors.success,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _buildMetricTile(
                    context,
                    label: l10n.tr('completed_fasts'),
                    value: '${completedFasts.length}',
                    color: AppColors.success,
                  ),
                  const SizedBox(width: 8),
                  _buildMetricTile(
                    context,
                    label: l10n.tr('interventions_today'),
                    value: '$interventionsToday',
                    color: AppColors.warning,
                  ),
                  const SizedBox(width: 8),
                  _buildMetricTile(
                    context,
                    label: l10n.tr('over_limit_apps'),
                    value: '$overLimitCount',
                    color: overLimitCount > 0
                        ? AppColors.error
                        : AppColors.success,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                overLimitCount > 0
                    ? l10n.tr('discipline_insight_attention', {
                        'count': overLimitCount,
                      })
                    : l10n.tr('discipline_insight_all_clear', {
                        'rules': enabledRules.length,
                      }),
                style: TextStyle(
                  fontSize: 12.5,
                  color: AppColors.textSecondary(context),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActiveFocusLockCard(
    BuildContext context,
    DeviceControlProvider provider,
    FocusLockSession? session,
    DateTime now,
  ) {
    final l10n = context.l10n;
    final config = provider.focusLockConfig;
    final isBreakRelaxed = session != null && !session.isRestrictingPhaseNow(now);

    return _buildOverviewSectionCard(
      context,
      title: l10n.tr('active_focus_lock'),
      icon: Icons.lock_clock_rounded,
      color: AppColors.primary,
      actionLabel: l10n.tr('manage_focus_lock'),
      onAction: () => _tabController.animateTo(2),
      child: session == null
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.tr('no_active_focus_lock_session'),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary(context),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  config.enabled
                      ? l10n.tr('roo_focus_lock_armed_count', {
                          'count': config.restrictedPackages.length,
                        })
                      : l10n.tr('roo_focus_lock_disabled_tap'),
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary(context),
                  ),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.tr('roo_focus_lock_active_count', {
                    'count': session.restrictedPackages.length,
                    'mode': session.enforcementMode.label,
                  }),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${session.taskLabel} · ${session.phase}',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary(context),
                  ),
                ),
                if (isBreakRelaxed) ...[
                  const SizedBox(height: 6),
                  Text(
                    l10n.tr('break_relaxation_active_temporary_focus_lock', {
                      'session_phase': session.phase,
                    }),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.info,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                if (session.allowManualEnd) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: OutlinedButton(
                      onPressed: () =>
                          provider.endFocusLockSession(reason: 'manual_end'),
                      child: Text(l10n.tr('end_focus_lock')),
                    ),
                  ),
                ],
              ],
            ),
    );
  }

  // ---------------------------------------------------------------------------
  // Tab 3: Usage Limits
  // ---------------------------------------------------------------------------

  Widget _buildUsageLimitsTab(
    BuildContext context,
    DeviceControlProvider provider,
  ) {
    final l10n = context.l10n;
    final now = DateTime.now();
    final rules = provider.appRules;
    final snapshot = provider.usageSnapshot;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.cardSurface(context),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.25),
            ),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.hourglass_bottom_rounded,
                color: AppColors.primary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.tr('app_restriction_manager'),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      l10n.tr('usage_limits'),
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary(context),
                      ),
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: () => _showRuleEditor(context, provider),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: Text(l10n.tr('add_app')),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        for (final rule in rules) ...[
          _buildUsageRuleCard(context, provider, rule, snapshot, now),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  Widget _buildUsageRuleCard(
    BuildContext context,
    DeviceControlProvider provider,
    TrackedAppRule rule,
    WellbeingDailySnapshot snapshot,
    DateTime now,
  ) {
    final l10n = context.l10n;
    final used =
        snapshot.recordForPackage(rule.packageName)?.usedMinutesToday ?? 0;
    final limit = rule.effectiveLimitMinutesFor(now);
    final remaining = (limit - used).clamp(0, limit);
    final ratio = limit > 0 ? (used / limit).clamp(0.0, 1.0) : 0.0;
    final resetStr =
        '${rule.dailyResetHour.toString().padLeft(2, '0')}:${rule.dailyResetMinute.toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardSurface(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: rule.isEnabled
              ? AppColors.border(context)
              : AppColors.border(context).withValues(alpha: 0.5),
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
                      rule.displayName,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      rule.packageName,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textMuted(context),
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: rule.isEnabled,
                onChanged: (v) =>
                    provider.addOrUpdateAppRule(rule.copyWith(isEnabled: v)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${_formatMinutes(used)} / ${_formatMinutes(limit)} (${_formatMinutes(remaining)})',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: used >= limit
                        ? AppColors.error
                        : AppColors.textPrimary(context),
                  ),
                ),
              ),
              Text(
                '${l10n.tr('daily_reset')} $resetStr',
                style: TextStyle(
                  fontSize: 11.5,
                  color: AppColors.textSecondary(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 6,
              backgroundColor: AppColors.trackSurface(context),
              valueColor: AlwaysStoppedAnimation<Color>(
                used >= limit ? AppColors.error : AppColors.primary,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              Chip(
                label: Text(
                  rule.resolvedLimitAction.label,
                  style: const TextStyle(fontSize: 11),
                ),
                visualDensity: VisualDensity.compact,
              ),
              Chip(
                label: Text(
                  '${rule.warningThresholdPercent}%',
                  style: const TextStyle(fontSize: 11),
                ),
                visualDensity: VisualDensity.compact,
              ),
              if (rule.weekdayLimitMinutes != null ||
                  rule.weekendLimitMinutes != null)
                Chip(
                  label: Text(
                    '${rule.weekdayLimitMinutes ?? rule.dailyLimitMinutes}m / ${rule.weekendLimitMinutes ?? rule.dailyLimitMinutes}m',
                    style: const TextStyle(fontSize: 11),
                  ),
                  visualDensity: VisualDensity.compact,
                ),
              if (rule.blockedScheduleStart != null &&
                  rule.blockedScheduleEnd != null)
                Chip(
                  label: Text(
                    '${rule.blockedScheduleStart}–${rule.blockedScheduleEnd}',
                    style: const TextStyle(fontSize: 11),
                  ),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                icon: const Icon(Icons.shield_outlined, size: 16),
                label: Text(l10n.tr('check_guard')),
                onPressed: () async {
                  final decision =
                      await provider.evaluateAndRecordLaunchAttempt(
                    rule.packageName,
                    appName: rule.displayName,
                  );
                  if (!context.mounted) return;
                  await WellbeingInterventionDialog.show(
                    context,
                    provider,
                    decision,
                  );
                },
              ),
              TextButton(
                onPressed: () =>
                    _showRuleEditor(context, provider, existing: rule),
                child: Text(l10n.tr('edit')),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Tab 4: Application Usage & Engine Logs
  // ---------------------------------------------------------------------------

  Widget _buildApplicationUsageTab(
    BuildContext context,
    DeviceControlProvider provider,
  ) {
    final l10n = context.l10n;
    final now = DateTime.now();
    final snapshot = provider.usageSnapshot;
    final sorted = [...snapshot.records]
      ..sort((a, b) => b.usedMinutesToday.compareTo(a.usedMinutesToday));
    final registry = provider.registry;
    final df = DateFormat('dd MMM HH:mm');

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (!snapshot.permissionGranted) ...[
          _buildUsagePermissionBanner(context, snapshot),
          const SizedBox(height: 12),
        ],
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.cardSurface(context),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border(context)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.apps_rounded,
                    color: AppColors.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.tr('application_usage'),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Text(
                    _formatMinutes(snapshot.totalTrackedMinutes),
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (sorted.isEmpty)
                Text(
                  l10n.tr('no_app_usage_recorded'),
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary(context),
                  ),
                )
              else
                for (final r in sorted) ...[
                  _buildUsageRecordTile(context, provider, r, now),
                  const Divider(height: 14),
                ],
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Honest Device Boundaries card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.cardSurface(context),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border(context)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.tr('honest_device_boundaries', {
                  'registry_toUpperCase': registry.platform.toUpperCase(),
                }),
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              _buildCapabilityRow(
                context,
                registry.recordFor(DeviceCapabilityRegistry.actionUsageStats),
              ),
              _buildCapabilityRow(
                context,
                registry
                    .recordFor(DeviceCapabilityRegistry.actionAppOverlayBanner),
              ),
              _buildCapabilityRow(
                context,
                registry.recordFor(
                  DeviceCapabilityRegistry.actionAppBlockingShield,
                ),
              ),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const PermissionCenterScreen(),
                      ),
                    );
                  },
                  child: Text(l10n.tr('open_permission_center')),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Restriction Engine Audit Log
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.cardSurface(context),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border(context)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.tr('restriction_engine_audit_log'),
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (provider.restrictionAuditLogs.isNotEmpty)
                    TextButton(
                      onPressed: () => provider.clearRestrictionAuditLogs(),
                      child: Text(l10n.tr('clear')),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              if (provider.restrictionAuditLogs.isEmpty)
                Text(
                  l10n.tr('no_restriction_engine_transitions_recorded_yet'),
                  style: TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textSecondary(context),
                  ),
                )
              else
                for (final log in provider.restrictionAuditLogs.take(25))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${log.appName} · ${log.effectiveStrength.label}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12.5,
                                ),
                              ),
                            ),
                            Text(
                              df.format(log.timestamp),
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textMuted(context),
                              ),
                            ),
                          ],
                        ),
                        if (log.detail.isNotEmpty)
                          Text(
                            log.detail,
                            style: TextStyle(
                              fontSize: 11.5,
                              color: AppColors.textSecondary(context),
                            ),
                          ),
                      ],
                    ),
                  ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Usage & Intervention History
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.cardSurface(context),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border(context)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.tr('usage_intervention_history'),
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              if (provider.interventionLogs.isEmpty)
                Text(
                  l10n.tr('no_intervention_events_logged_yet_today'),
                  style: TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textSecondary(context),
                  ),
                )
              else
                for (final log in provider.interventionLogs.take(25))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${log.appName} · ${log.level.label}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12.5,
                                ),
                              ),
                              Text(
                                '${log.reason} · ${log.outcome}',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: AppColors.textSecondary(context),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          df.format(log.timestamp),
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textMuted(context),
                          ),
                        ),
                      ],
                    ),
                  ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildUsageRecordTile(
    BuildContext context,
    DeviceControlProvider provider,
    AppUsageRecord record,
    DateTime now,
  ) {
    final l10n = context.l10n;
    final matchingRule = provider.appRules.cast<TrackedAppRule?>().firstWhere(
          (r) => r?.packageName == record.packageName,
          orElse: () => null,
        );
    final limit = matchingRule?.effectiveLimitMinutesFor(now);

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                record.appName,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13.5,
                ),
              ),
              Text(
                '${record.packageName} · ${record.launchCountToday}×',
                style: TextStyle(
                  fontSize: 11.5,
                  color: AppColors.textMuted(context),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              limit == null
                  ? _formatMinutes(record.usedMinutesToday)
                  : '${_formatMinutes(record.usedMinutesToday)} / ${_formatMinutes(limit)}',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 13,
                color: limit != null && record.usedMinutesToday >= limit
                    ? AppColors.error
                    : AppColors.textPrimary(context),
              ),
            ),
            if (matchingRule == null)
              TextButton(
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 24),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () => _showRuleEditor(
                  context,
                  provider,
                  presetAppName: record.appName,
                  presetPackageName: record.packageName,
                ),
                child: Text(
                  l10n.tr('set_limit'),
                  style: const TextStyle(fontSize: 11.5),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildCapabilityRow(
    BuildContext context,
    DeviceCapabilityRecord? record,
  ) {
    if (record == null) return const SizedBox.shrink();
    final color = switch (record.support) {
      ActionExecutionSupport.directlySupported => AppColors.success,
      ActionExecutionSupport.permissionRequired => AppColors.warning,
      ActionExecutionSupport.delegatedToSystemSettings => AppColors.info,
      ActionExecutionSupport.unsupported => AppColors.error,
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.circle, size: 8, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.label,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (record.oemNote.isNotEmpty)
                  Text(
                    record.oemNote,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: AppColors.textSecondary(context),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUsagePermissionBanner(
    BuildContext context,
    WellbeingDailySnapshot snapshot,
  ) {
    final l10n = context.l10n;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.warning.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.info_outline_rounded,
                color: AppColors.warning,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.tr('usage_telemetry_boundary'),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            snapshot.honestBoundaryMessage.isNotEmpty
                ? snapshot.honestBoundaryMessage
                : l10n.tr('grant_usage_access_in_permission_center'),
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary(context),
            ),
          ),
          const SizedBox(height: 8),
          FilledButton.tonal(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const PermissionCenterScreen(),
                ),
              );
            },
            child: Text(l10n.tr('open_permission_center')),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Rule Editor Modal
  // ---------------------------------------------------------------------------

  Future<void> _showRuleEditor(
    BuildContext context,
    DeviceControlProvider provider, {
    TrackedAppRule? existing,
    String? presetAppName,
    String? presetPackageName,
  }) async {
    final l10n = context.l10n;
    final nameController = TextEditingController(
      text: existing?.displayName ?? presetAppName ?? '',
    );
    final packageController = TextEditingController(
      text: existing?.packageName ?? presetPackageName ?? '',
    );
    final limitController = TextEditingController(
      text: '${existing?.dailyLimitMinutes ?? 45}',
    );
    final warningController = TextEditingController(
      text: '${existing?.warningThresholdPercent ?? 80}',
    );
    final weekdayController = TextEditingController(
      text: existing?.weekdayLimitMinutes?.toString() ?? '',
    );
    final weekendController = TextEditingController(
      text: existing?.weekendLimitMinutes?.toString() ?? '',
    );
    final startController = TextEditingController(
      text: existing?.blockedScheduleStart ?? '',
    );
    final endController = TextEditingController(
      text: existing?.blockedScheduleEnd ?? '',
    );

    var level =
        existing?.interventionLevel ?? WellbeingInterventionLevel.preLimitWarning;
    var limitAction = existing?.resolvedLimitAction ??
        UsageLimitAction.warningOnly;
    var resetTime = TimeOfDay(
      hour: existing?.dailyResetHour ?? 0,
      minute: existing?.dailyResetMinute ?? 0,
    );

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.sheetSurface(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                18,
                18,
                18,
                MediaQuery.of(ctx).viewInsets.bottom + 18,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            existing != null
                                ? existing.displayName
                                : l10n.tr('add_usage_limit_app'),
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        TextButton.icon(
                          icon: const Icon(Icons.apps_rounded, size: 18),
                          label: Text(l10n.tr('pick_installed')),
                          onPressed: () async {
                            final picked = await WellbeingAppPickerSheet.pickApps(
                              ctx,
                              multiSelect: false,
                              title: l10n.tr('pick_app_usage_limit'),
                            );
                            if (picked != null && picked.isNotEmpty) {
                              final entry = picked.entries.first;
                              setModalState(() {
                                packageController.text = entry.key;
                                nameController.text = entry.value;
                              });
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                        labelText: l10n.tr('app_name'),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: packageController,
                      decoration: InputDecoration(
                        labelText: l10n.tr('package_id_example'),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: limitController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: l10n.tr('daily_limit_min'),
                              border: const OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: warningController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: l10n.tr('warning_percent'),
                              border: const OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: weekdayController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: l10n.tr('weekday_limit_opt'),
                              border: const OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: weekendController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: l10n.tr('weekend_limit_opt'),
                              border: const OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<UsageLimitAction>(
                      initialValue: limitAction,
                      decoration: InputDecoration(
                        labelText: l10n.tr('action_when_limit_reached'),
                        border: const OutlineInputBorder(),
                      ),
                      items: UsageLimitAction.values
                          .map(
                            (a) => DropdownMenuItem(
                              value: a,
                              child: Text(a.label),
                            ),
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setModalState(() => limitAction = v);
                      },
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<WellbeingInterventionLevel>(
                      initialValue: level,
                      decoration: InputDecoration(
                        labelText: l10n.tr('intervention_level'),
                        border: const OutlineInputBorder(),
                      ),
                      items: WellbeingInterventionLevel.values
                          .map(
                            (lvl) => DropdownMenuItem(
                              value: lvl,
                              child: Text(lvl.label),
                            ),
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setModalState(() => level = v);
                      },
                    ),
                    const SizedBox(height: 10),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.schedule_rounded),
                      title: Text(l10n.tr('daily_reset_time')),
                      trailing: Text(
                        '${resetTime.hour.toString().padLeft(2, '0')}:${resetTime.minute.toString().padLeft(2, '0')}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      onTap: () async {
                        final picked = await showTimePicker(
                          context: ctx,
                          initialTime: resetTime,
                        );
                        if (picked != null) {
                          setModalState(() => resetTime = picked);
                        }
                      },
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: startController,
                            decoration: InputDecoration(
                              labelText: l10n.tr('schedule_start_hhmm'),
                              border: const OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: endController,
                            decoration: InputDecoration(
                              labelText: l10n.tr('schedule_end_hhmm'),
                              border: const OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        if (existing != null)
                          TextButton(
                            onPressed: () async {
                              await provider.deleteAppRule(existing.id);
                              if (sheetCtx.mounted) Navigator.pop(sheetCtx);
                            },
                            child: Text(
                              l10n.tr('delete'),
                              style: const TextStyle(color: AppColors.error),
                            ),
                          ),
                        const Spacer(),
                        TextButton(
                          onPressed: () => Navigator.pop(sheetCtx),
                          child: Text(l10n.tr('cancel')),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: () async {
                            final appName = nameController.text.trim();
                            final pkg = packageController.text.trim();
                            if (appName.isEmpty || pkg.isEmpty) return;

                            final dailyLimit =
                                int.tryParse(limitController.text.trim()) ?? 45;
                            final warnPct =
                                int.tryParse(warningController.text.trim()) ??
                                    80;
                            final weekdayLimit =
                                int.tryParse(weekdayController.text.trim());
                            final weekendLimit =
                                int.tryParse(weekendController.text.trim());
                            final startText = startController.text.trim();
                            final endText = endController.text.trim();

                            final rule = (existing ??
                                    TrackedAppRule(
                                      displayName: appName,
                                      packageName: pkg,
                                    ))
                                .copyWith(
                              displayName: appName,
                              packageName: pkg,
                              dailyLimitMinutes: dailyLimit.clamp(5, 1440),
                              warningThresholdPercent: warnPct.clamp(10, 99),
                              weekdayLimitMinutes: weekdayLimit,
                              clearWeekdayLimit: weekdayLimit == null,
                              weekendLimitMinutes: weekendLimit,
                              clearWeekendLimit: weekendLimit == null,
                              limitReachedAction: limitAction,
                              interventionLevel: level,
                              dailyResetHour: resetTime.hour,
                              dailyResetMinute: resetTime.minute,
                              blockedScheduleStart:
                                  startText.isEmpty ? null : startText,
                              clearScheduleStart: startText.isEmpty,
                              blockedScheduleEnd:
                                  endText.isEmpty ? null : endText,
                              clearScheduleEnd: endText.isEmpty,
                            );

                            await provider.addOrUpdateAppRule(rule);
                            if (sheetCtx.mounted) Navigator.pop(sheetCtx);
                          },
                          child: Text(l10n.tr('save')),
                        ),
                      ],
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

  // ---------------------------------------------------------------------------
  // Shared UI Builders
  // ---------------------------------------------------------------------------

  Widget _buildMetricTile(
    BuildContext context, {
    required String label,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewSectionCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required Widget child,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardSurface(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (actionLabel != null && onAction != null)
                TextButton(
                  onPressed: onAction,
                  child: Text(
                    actionLabel,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }

  String _formatMinutes(int minutes) {
    if (minutes >= 60) {
      final h = minutes ~/ 60;
      final m = minutes % 60;
      return m == 0 ? '${h}h' : '${h}h ${m}m';
    }
    return '${minutes}m';
  }
}
