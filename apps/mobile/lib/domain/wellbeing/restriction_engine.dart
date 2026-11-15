import '../../data/models/app_restriction.dart';
import '../../data/models/device_capability.dart';
import '../../data/models/digital_wellbeing.dart';

/// Shared modular Restriction Engine serving Roo Digital Discipline & App Control
/// (plus shared cross-family automations).
///
/// Evaluates all active sources simultaneously (App Fast commitments, Focus
/// Lock sessions triggered by Roo Pomodoro or manual sessions, Daily Usage Limits,
/// Scheduled Blocks, and Automations) without letting any weaker or ending
/// rule accidentally clear a stronger active restriction.
class RestrictionEngine {
  const RestrictionEngine();

  /// Emergency dialers, core OS UI, and Nestin itself must NEVER be locked.
  static const Set<String> essentialSystemPackages = {
    'com.nestin.app',
    'com.roodoo.app.roodoo',
    'com.android.dialer',
    'com.google.android.dialer',
    'com.samsung.android.dialer',
    'com.android.server.telecom',
    'com.android.phone',
    'com.android.emergency',
    'com.android.incallui',
    'com.android.settings',
    'com.android.systemui',
    'com.apple.mobilephone',
    'com.apple.Preferences',
  };

  static bool isEssentialSystemPackage(String packageName) {
    final normalized = packageName.trim().toLowerCase();
    if (normalized.isEmpty) return true;
    if (essentialSystemPackages.contains(normalized)) return true;
    if (normalized.contains('emergency') ||
        normalized.contains('telecom') ||
        normalized.endsWith('.dialer')) {
      return true;
    }
    return false;
  }

  /// Resolves the active 5-level platform capability report for strict vs
  /// reminder enforcement on the current host platform.
  PlatformSupportLevel resolvePlatformSupport(
    DeviceCapabilityRegistry registry, {
    required RestrictionStrength strength,
  }) {
    final shieldSupport = registry.supportFor(
      DeviceCapabilityRegistry.actionAppBlockingShield,
    );
    final overlaySupport = registry.supportFor(
      DeviceCapabilityRegistry.actionAppOverlayBanner,
    );

    if (registry.platform == 'ios') {
      if (registry.hasFamilyControlsEntitlement) {
        return shieldSupport == ActionExecutionSupport.directlySupported
            ? PlatformSupportLevel.supported
            : PlatformSupportLevel.supportedWithPermission;
      }
      return PlatformSupportLevel.supportedWithEntitlement;
    }

    if (registry.platform != 'android') {
      return PlatformSupportLevel.unsupported;
    }

    switch (strength) {
      case RestrictionStrength.none:
        return PlatformSupportLevel.supported;
      case RestrictionStrength.warning:
        final notifGranted = registry
                .permissionFor(NestinPermissionKind.notifications)
                ?.isGranted ??
            true;
        return notifGranted
            ? PlatformSupportLevel.supported
            : PlatformSupportLevel.supportedWithPermission;
      case RestrictionStrength.reminder:
        if (shieldSupport == ActionExecutionSupport.directlySupported ||
            overlaySupport == ActionExecutionSupport.directlySupported) {
          return PlatformSupportLevel.supported;
        }
        return PlatformSupportLevel.supportedWithPermission;
      case RestrictionStrength.strict:
        if (shieldSupport == ActionExecutionSupport.directlySupported) {
          return PlatformSupportLevel.supported;
        }
        if (overlaySupport == ActionExecutionSupport.directlySupported) {
          return PlatformSupportLevel.limitedSupport;
        }
        return PlatformSupportLevel.supportedWithPermission;
    }
  }

  /// Evaluates every active restriction source for [packageName] at [now].
  RestrictionDecision evaluateApp({
    required String packageName,
    String? appName,
    required DateTime now,
    required DeviceCapabilityRegistry registry,
    required List<AppFastCommitment> appFastCommitments,
    required FocusLockSession? activeFocusSession,
    required List<TrackedAppRule> usageRules,
    required WellbeingDailySnapshot usageSnapshot,
    List<RestrictionRule> extraRules = const [],
  }) {
    final displayAppName = appName ?? packageName;

    if (isEssentialSystemPackage(packageName)) {
      return RestrictionDecision(
        packageName: packageName,
        appName: displayAppName,
        effectiveStrength: RestrictionStrength.none,
        winningRule: null,
        activeRules: const [],
        outcome: RestrictionExecutionOutcome.allowedEssential,
        platformSupport: PlatformSupportLevel.supported,
        canProceedAnyway: true,
        explanation:
            'Essential system and emergency calling functionality is always preserved.',
        evaluatedAt: now,
      );
    }

    final matchingRules = <RestrictionRule>[];

    // 1. App Fast Commitments
    for (final commitment in appFastCommitments) {
      if (!commitment.isActiveAt(now)) continue;
      if (!commitment.targetPackages.contains(packageName)) continue;

      final strength = commitment.mode == RestrictionEnforcementMode.strict
          ? RestrictionStrength.strict
          : RestrictionStrength.reminder;
      matchingRules.add(
        RestrictionRule(
          id: 'app_fast_${commitment.id}_$packageName',
          sourceType: RestrictionSourceType.appFast,
          sourceId: commitment.id,
          title: commitment.title,
          packageName: packageName,
          appName: commitment.displayNameForPackage(packageName),
          strength: strength,
          reason: commitment.interventionMessage?.trim().isNotEmpty == true
              ? commitment.interventionMessage!
              : 'Active App Fast commitment until ${_shortDate(commitment.endAt)}.',
          motivation: commitment.motivation,
          expiresAt: commitment.endAt,
        ),
      );
    }

    // 2. Focus Lock Session (triggered by Roo Pomodoro, Roo manual Focus Lock, or Automation)
    if (activeFocusSession != null &&
        activeFocusSession.isRestrictingPhaseNow(now) &&
        activeFocusSession.restrictedPackages.contains(packageName) &&
        !activeFocusSession.allowedPackages.contains(packageName)) {
      final strength =
          activeFocusSession.enforcementMode == RestrictionEnforcementMode.strict
              ? RestrictionStrength.strict
              : RestrictionStrength.reminder;
      matchingRules.add(
        RestrictionRule(
          id: 'focus_lock_${activeFocusSession.id}_$packageName',
          sourceType: RestrictionSourceType.focusLock,
          sourceId: activeFocusSession.id,
          title: 'Focus Lock · ${activeFocusSession.taskLabel}',
          packageName: packageName,
          appName: displayAppName,
          strength: strength,
          reason: activeFocusSession.customMessage?.trim().isNotEmpty == true
              ? activeFocusSession.customMessage!
              : 'Focus session "${activeFocusSession.taskLabel}" in progress.',
          expiresAt: activeFocusSession.expectedEndAt,
        ),
      );
    }

    // 3. Daily Usage Allowances & Scheduled Block Windows
    for (final rule in usageRules) {
      if (!rule.isEnabled || rule.packageName != packageName) continue;

      if (rule.isWithinBlockedWindow(now) &&
          rule.interventionLevel != WellbeingInterventionLevel.trackOnly) {
        final scheduleStrength =
            (rule.interventionLevel == WellbeingInterventionLevel.strictModeGuard ||
                    rule.interventionLevel ==
                        WellbeingInterventionLevel.blockingSchedule)
                ? RestrictionStrength.strict
                : (rule.interventionLevel ==
                        WellbeingInterventionLevel.timedSoftPause
                    ? RestrictionStrength.reminder
                    : RestrictionStrength.warning);

        matchingRules.add(
          RestrictionRule(
            id: 'schedule_${rule.id}_$packageName',
            sourceType: RestrictionSourceType.scheduledBlock,
            sourceId: rule.id,
            title: '${rule.displayName} Schedule Guard',
            packageName: packageName,
            appName: rule.displayName,
            strength: scheduleStrength,
            reason:
                'Quiet hours ${rule.blockedScheduleStart}–${rule.blockedScheduleEnd} are active.',
          ),
        );
      }

      if (usageSnapshot.permissionGranted) {
        final record = usageSnapshot.recordForPackage(packageName);
        final usedMinutes = record?.usedMinutesToday ?? 0;
        final limitMinutes = rule.effectiveLimitMinutesFor(now);
        final warningMinutes = rule.warningMinutesFor(now);

        if (limitMinutes > 0 && usedMinutes >= limitMinutes) {
          final actionStrength = switch (rule.resolvedLimitAction) {
            UsageLimitAction.strictBlock => RestrictionStrength.strict,
            UsageLimitAction.reminderPause => RestrictionStrength.reminder,
            UsageLimitAction.warningOnly => RestrictionStrength.warning,
          };
          matchingRules.add(
            RestrictionRule(
              id: 'usage_limit_${rule.id}_$packageName',
              sourceType: RestrictionSourceType.usageLimit,
              sourceId: rule.id,
              title: '${rule.displayName} Daily Limit',
              packageName: packageName,
              appName: rule.displayName,
              strength: actionStrength,
              reason:
                  'Daily allowance reached ($usedMinutes/${limitMinutes}m used).',
            ),
          );
        } else if (limitMinutes > 0 &&
            usedMinutes >= warningMinutes &&
            rule.interventionLevel != WellbeingInterventionLevel.trackOnly) {
          matchingRules.add(
            RestrictionRule(
              id: 'usage_warning_${rule.id}_$packageName',
              sourceType: RestrictionSourceType.usageLimit,
              sourceId: rule.id,
              title: '${rule.displayName} Limit Warning',
              packageName: packageName,
              appName: rule.displayName,
              strength: RestrictionStrength.warning,
              reason:
                  'Approaching daily limit ($usedMinutes/${limitMinutes}m used).',
            ),
          );
        }
      }
    }

    // 4. Extensible Automation / Scheduled Rules
    for (final extra in extraRules) {
      if (extra.packageName == packageName && extra.isActiveAt(now)) {
        matchingRules.add(extra);
      }
    }

    if (matchingRules.isEmpty) {
      return RestrictionDecision(
        packageName: packageName,
        appName: displayAppName,
        effectiveStrength: RestrictionStrength.none,
        winningRule: null,
        activeRules: const [],
        outcome: RestrictionExecutionOutcome.none,
        platformSupport: PlatformSupportLevel.supported,
        canProceedAnyway: true,
        explanation: 'No active restrictions for $displayAppName.',
        evaluatedAt: now,
      );
    }

    // Monotonic priority resolution: strongest strength wins; tie-break by sourcePriority.
    matchingRules.sort((a, b) {
      final strengthCmp =
          b.strength.severityOrder.compareTo(a.strength.severityOrder);
      if (strengthCmp != 0) return strengthCmp;
      return b.sourceType.sourcePriority
          .compareTo(a.sourceType.sourcePriority);
    });

    final winner = matchingRules.first;
    final platformSupport = resolvePlatformSupport(
      registry,
      strength: winner.strength,
    );

    final outcome = _resolveOutcome(
      strength: winner.strength,
      platformSupport: platformSupport,
      registry: registry,
    );

    final canProceed = winner.strength != RestrictionStrength.strict;
    final explanation = _buildExplanation(
      winner: winner,
      coexistingCount: matchingRules.length,
      outcome: outcome,
      platformSupport: platformSupport,
    );

    return RestrictionDecision(
      packageName: packageName,
      appName: winner.appName,
      effectiveStrength: winner.strength,
      winningRule: winner,
      activeRules: List.unmodifiable(matchingRules),
      outcome: outcome,
      platformSupport: platformSupport,
      canProceedAnyway: canProceed,
      explanation: explanation,
      evaluatedAt: now,
    );
  }

  RestrictionExecutionOutcome _resolveOutcome({
    required RestrictionStrength strength,
    required PlatformSupportLevel platformSupport,
    required DeviceCapabilityRegistry registry,
  }) {
    if (platformSupport == PlatformSupportLevel.unsupported) {
      return RestrictionExecutionOutcome.unsupported;
    }

    switch (strength) {
      case RestrictionStrength.none:
        return RestrictionExecutionOutcome.none;
      case RestrictionStrength.warning:
        return RestrictionExecutionOutcome.warningNotificationOnly;
      case RestrictionStrength.reminder:
        if (registry.platform == 'ios' &&
            !registry.hasFamilyControlsEntitlement) {
          return RestrictionExecutionOutcome.delegatedToSystemSettings;
        }
        return RestrictionExecutionOutcome.reminderOverlayShown;
      case RestrictionStrength.strict:
        if (platformSupport == PlatformSupportLevel.supported) {
          return RestrictionExecutionOutcome.enforcedViaShield;
        }
        return RestrictionExecutionOutcome.delegatedToSystemSettings;
    }
  }

  String _buildExplanation({
    required RestrictionRule winner,
    required int coexistingCount,
    required RestrictionExecutionOutcome outcome,
    required PlatformSupportLevel platformSupport,
  }) {
    final suffix = coexistingCount > 1
        ? ' (+${coexistingCount - 1} more active rule${coexistingCount > 2 ? 's' : ''})'
        : '';
    if (outcome == RestrictionExecutionOutcome.delegatedToSystemSettings ||
        outcome == RestrictionExecutionOutcome.unsupported) {
      return '${winner.reason}$suffix · ${platformSupport.label}: OS permission/entitlement required for automatic shield.';
    }
    return '${winner.reason}$suffix';
  }

  /// Evaluates all known tracked, App Fast, Focus Lock, and extra packages
  /// and produces lightweight serializable policy entries for native shields.
  List<Map<String, dynamic>> buildNativePolicyEntries({
    required DateTime now,
    required DeviceCapabilityRegistry registry,
    required List<AppFastCommitment> appFastCommitments,
    required FocusLockSession? activeFocusSession,
    required List<TrackedAppRule> usageRules,
    required WellbeingDailySnapshot usageSnapshot,
    List<RestrictionRule> extraRules = const [],
  }) {
    final packages = <String>{};
    final nameMap = <String, String>{};

    for (final c in appFastCommitments) {
      if (!c.isActiveAt(now)) continue;
      for (final pkg in c.targetPackages) {
        packages.add(pkg);
        nameMap[pkg] = c.displayNameForPackage(pkg);
      }
    }
    if (activeFocusSession != null &&
        activeFocusSession.isRestrictingPhaseNow(now)) {
      packages.addAll(activeFocusSession.restrictedPackages);
    }
    for (final r in usageRules) {
      if (r.isEnabled) {
        packages.add(r.packageName);
        nameMap[r.packageName] = r.displayName;
      }
    }
    for (final e in extraRules) {
      if (e.isActiveAt(now)) {
        packages.add(e.packageName);
        nameMap[e.packageName] = e.appName;
      }
    }

    final policies = <Map<String, dynamic>>[];
    for (final pkg in packages) {
      final decision = evaluateApp(
        packageName: pkg,
        appName: nameMap[pkg],
        now: now,
        registry: registry,
        appFastCommitments: appFastCommitments,
        activeFocusSession: activeFocusSession,
        usageRules: usageRules,
        usageSnapshot: usageSnapshot,
        extraRules: extraRules,
      );
      if (!decision.isRestricted || decision.winningRule == null) continue;
      final winner = decision.winningRule!;
      policies.add({
        'packageName': pkg,
        'appName': decision.appName,
        'strength': decision.effectiveStrength.name,
        'sourceType': winner.sourceType.name,
        'sourceLabel': winner.sourceType.label,
        'title': winner.title,
        'reason': winner.reason,
        'motivation': winner.motivation ?? '',
        'canContinue': decision.canProceedAnyway,
        'expiresAtMs': winner.expiresAt?.millisecondsSinceEpoch ?? 0,
      });
    }
    return policies;
  }

  static String _shortDate(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}
