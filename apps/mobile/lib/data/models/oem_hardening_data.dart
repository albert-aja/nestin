enum OemBrand {
  xiaomi,
  samsung,
  huawei,
  oppo,
  vivo,
  oneplus,
  stock,
  apple,
  other,
}

enum OemRiskLevel {
  critical,
  high,
  moderate,
  low,
}

class OemInstructionStep {
  final int stepNumber;
  final String title;
  final String description;
  final String actionLabel;
  final String actionType; // 'battery_opt', 'autostart', 'keep_alive'

  const OemInstructionStep({
    required this.stepNumber,
    required this.title,
    required this.description,
    required this.actionLabel,
    required this.actionType,
  });

  Map<String, dynamic> toJson() => {
        'stepNumber': stepNumber,
        'title': title,
        'description': description,
        'actionLabel': actionLabel,
        'actionType': actionType,
      };

  factory OemInstructionStep.fromJson(Map<String, dynamic> json) =>
      OemInstructionStep(
        stepNumber: json['stepNumber'] as int? ?? 1,
        title: json['title'] as String? ?? '',
        description: json['description'] as String? ?? '',
        actionLabel: json['actionLabel'] as String? ?? '',
        actionType: json['actionType'] as String? ?? '',
      );
}

class OemHardeningStatus {
  final String manufacturer;
  final String brand;
  final String model;
  final int sdkInt;
  final bool isIgnoringBatteryOptimizations;
  final bool isKeepAliveServiceRunning;
  final bool isAggressiveOem;
  final OemBrand oemBrand;
  final OemRiskLevel riskLevel;

  const OemHardeningStatus({
    required this.manufacturer,
    required this.brand,
    required this.model,
    required this.sdkInt,
    required this.isIgnoringBatteryOptimizations,
    required this.isKeepAliveServiceRunning,
    required this.isAggressiveOem,
    required this.oemBrand,
    required this.riskLevel,
  });

  static OemBrand resolveBrand(String manufacturer) {
    final m = manufacturer.toLowerCase();
    if (m.contains('xiaomi') || m.contains('redmi') || m.contains('poco')) {
      return OemBrand.xiaomi;
    }
    if (m.contains('samsung')) {
      return OemBrand.samsung;
    }
    if (m.contains('huawei') || m.contains('honor')) {
      return OemBrand.huawei;
    }
    if (m.contains('oppo') || m.contains('realme')) {
      return OemBrand.oppo;
    }
    if (m.contains('vivo') || m.contains('iqoo')) {
      return OemBrand.vivo;
    }
    if (m.contains('oneplus')) {
      return OemBrand.oneplus;
    }
    if (m.contains('google') ||
        m.contains('motorola') ||
        m.contains('nokia') ||
        m.contains('sony') ||
        m.contains('lge')) {
      return OemBrand.stock;
    }
    if (m.contains('apple')) {
      return OemBrand.apple;
    }
    return OemBrand.other;
  }

  static bool isBrandAggressive(OemBrand brand) {
    return brand == OemBrand.xiaomi ||
        brand == OemBrand.samsung ||
        brand == OemBrand.huawei ||
        brand == OemBrand.oppo ||
        brand == OemBrand.vivo ||
        brand == OemBrand.oneplus;
  }

  static OemRiskLevel calculateRiskLevel({
    required OemBrand brand,
    required bool isIgnoringBattery,
    required bool isKeepAliveActive,
  }) {
    if (isIgnoringBattery && isKeepAliveActive) {
      return OemRiskLevel.low;
    }
    if (brand == OemBrand.apple) {
      return OemRiskLevel.low;
    }
    if (brand == OemBrand.xiaomi ||
        brand == OemBrand.samsung ||
        brand == OemBrand.huawei) {
      return isIgnoringBattery ? OemRiskLevel.moderate : OemRiskLevel.critical;
    }
    if (brand == OemBrand.oppo ||
        brand == OemBrand.vivo ||
        brand == OemBrand.oneplus) {
      return isIgnoringBattery ? OemRiskLevel.low : OemRiskLevel.high;
    }
    return isIgnoringBattery ? OemRiskLevel.low : OemRiskLevel.moderate;
  }

  String get brandDisplayName {
    switch (oemBrand) {
      case OemBrand.xiaomi:
        return 'Xiaomi (MIUI / HyperOS)';
      case OemBrand.samsung:
        return 'Samsung (OneUI)';
      case OemBrand.huawei:
        return 'Huawei (EMUI / HarmonyOS)';
      case OemBrand.oppo:
        return 'Oppo / Realme (ColorOS)';
      case OemBrand.vivo:
        return 'Vivo (FuntouchOS / OriginOS)';
      case OemBrand.oneplus:
        return 'OnePlus (OxygenOS)';
      case OemBrand.stock:
        return 'Stock Android';
      case OemBrand.apple:
        return 'Apple iOS';
      case OemBrand.other:
        return manufacturer.isNotEmpty ? manufacturer : 'Android';
    }
  }

  String get riskLabel {
    switch (riskLevel) {
      case OemRiskLevel.critical:
        return 'Critical Risk of Sleep Kill';
      case OemRiskLevel.high:
        return 'High Risk of Missed Alarms';
      case OemRiskLevel.moderate:
        return 'Moderate Risk';
      case OemRiskLevel.low:
        return 'Protected & Whitelisted';
    }
  }

  bool get isProtected =>
      isIgnoringBatteryOptimizations || isKeepAliveServiceRunning;

  List<OemInstructionStep> get guidanceSteps {
    switch (oemBrand) {
      case OemBrand.xiaomi:
        return const [
          OemInstructionStep(
            stepNumber: 1,
            title: 'Turn Off Battery Saver',
            description:
                'Set Battery saver to "No restrictions" in App info so MIUI does not freeze alarms.',
            actionLabel: 'Disable Battery Restrictions',
            actionType: 'battery_opt',
          ),
          OemInstructionStep(
            stepNumber: 2,
            title: 'Allow Autostart',
            description:
                'Turn ON "Autostart" in Security > Permissions so Nestin launches on wake events.',
            actionLabel: 'Open MIUI Autostart',
            actionType: 'autostart',
          ),
          OemInstructionStep(
            stepNumber: 3,
            title: 'Keep-Alive Foreground Guard',
            description:
                'Run a persistent low-power foreground notification so the kernel never kills alarms.',
            actionLabel: 'Enable Keep-Alive Guard',
            actionType: 'keep_alive',
          ),
        ];

      case OemBrand.samsung:
        return const [
          OemInstructionStep(
            stepNumber: 1,
            title: 'Exclude from Sleeping Apps',
            description:
                'Go to Device Care > Battery > Background usage limits > Never sleeping apps > Add Nestin.',
            actionLabel: 'Open Battery Settings',
            actionType: 'battery_opt',
          ),
          OemInstructionStep(
            stepNumber: 2,
            title: 'Unrestricted Battery Usage',
            description:
                'In App info > Battery, select "Unrestricted" so OneUI never delays alarms.',
            actionLabel: 'Open Device Care',
            actionType: 'autostart',
          ),
          OemInstructionStep(
            stepNumber: 3,
            title: 'Keep-Alive Foreground Guard',
            description:
                'Activate Nestin Foreground Service to bypass Samsung Adaptive Battery killing.',
            actionLabel: 'Enable Keep-Alive Guard',
            actionType: 'keep_alive',
          ),
        ];

      case OemBrand.huawei:
        return const [
          OemInstructionStep(
            stepNumber: 1,
            title: 'Manage App Launch Manually',
            description:
                'Go to Settings > Battery > App launch > Nestin > Turn OFF "Manage automatically".',
            actionLabel: 'Open App Launch Settings',
            actionType: 'autostart',
          ),
          OemInstructionStep(
            stepNumber: 2,
            title: 'Enable All 3 Permissions',
            description:
                'Turn ON "Auto-launch", "Secondary launch", and "Run in background" for Nestin.',
            actionLabel: 'Disable Battery Optimization',
            actionType: 'battery_opt',
          ),
          OemInstructionStep(
            stepNumber: 3,
            title: 'Keep-Alive Foreground Guard',
            description:
                'Keep Nestin active in memory with a high-reliability foreground service.',
            actionLabel: 'Enable Keep-Alive Guard',
            actionType: 'keep_alive',
          ),
        ];

      case OemBrand.oppo:
      case OemBrand.vivo:
      case OemBrand.oneplus:
        return const [
          OemInstructionStep(
            stepNumber: 1,
            title: 'Disable Battery Optimization',
            description:
                'Set App battery management to "Don\'t optimize" and allow high background power usage.',
            actionLabel: 'Disable Battery Restrictions',
            actionType: 'battery_opt',
          ),
          OemInstructionStep(
            stepNumber: 2,
            title: 'Allow Background Startup',
            description:
                'Open Startup Manager in Phone Manager and enable Nestin to auto-start in background.',
            actionLabel: 'Open Startup Manager',
            actionType: 'autostart',
          ),
          OemInstructionStep(
            stepNumber: 3,
            title: 'Keep-Alive Foreground Guard',
            description:
                'Enable foreground service for uninterrupted alarms and countdown timers.',
            actionLabel: 'Enable Keep-Alive Guard',
            actionType: 'keep_alive',
          ),
        ];

      default:
        return const [
          OemInstructionStep(
            stepNumber: 1,
            title: 'Disable Battery Optimization',
            description:
                'Set Battery usage to "Unrestricted" so Android never puts Nestin into deep sleep.',
            actionLabel: 'Disable Battery Optimization',
            actionType: 'battery_opt',
          ),
          OemInstructionStep(
            stepNumber: 2,
            title: 'Keep-Alive Foreground Guard',
            description:
                'Enable persistent foreground service for 100% alarm and reminder reliability.',
            actionLabel: 'Enable Keep-Alive Guard',
            actionType: 'keep_alive',
          ),
        ];
    }
  }

  factory OemHardeningStatus.fromPlatformMap(Map<dynamic, dynamic> map) {
    final m = map['manufacturer']?.toString() ?? '';
    final brand = resolveBrand(m);
    final isIgnoring = map['isIgnoringBatteryOptimizations'] as bool? ?? false;
    final isRunning = map['isKeepAliveRunning'] as bool? ?? false;

    return OemHardeningStatus(
      manufacturer: m,
      brand: map['brand']?.toString() ?? '',
      model: map['model']?.toString() ?? '',
      sdkInt: map['sdkInt'] as int? ?? 0,
      isIgnoringBatteryOptimizations: isIgnoring,
      isKeepAliveServiceRunning: isRunning,
      isAggressiveOem: isBrandAggressive(brand),
      oemBrand: brand,
      riskLevel: calculateRiskLevel(
        brand: brand,
        isIgnoringBattery: isIgnoring,
        isKeepAliveActive: isRunning,
      ),
    );
  }

  factory OemHardeningStatus.defaultSafe() => const OemHardeningStatus(
        manufacturer: 'Google',
        brand: 'Android',
        model: 'Generic',
        sdkInt: 34,
        isIgnoringBatteryOptimizations: true,
        isKeepAliveServiceRunning: false,
        isAggressiveOem: false,
        oemBrand: OemBrand.stock,
        riskLevel: OemRiskLevel.low,
      );

  Map<String, dynamic> toJson() => {
        'manufacturer': manufacturer,
        'brand': brand,
        'model': model,
        'sdkInt': sdkInt,
        'isIgnoringBatteryOptimizations': isIgnoringBatteryOptimizations,
        'isKeepAliveServiceRunning': isKeepAliveServiceRunning,
        'isAggressiveOem': isAggressiveOem,
        'oemBrand': oemBrand.name,
        'riskLevel': riskLevel.name,
      };

  factory OemHardeningStatus.fromJson(Map<String, dynamic> json) {
    final brand = OemBrand.values.firstWhere(
      (e) => e.name == json['oemBrand'],
      orElse: () => OemBrand.other,
    );
    final risk = OemRiskLevel.values.firstWhere(
      (e) => e.name == json['riskLevel'],
      orElse: () => OemRiskLevel.low,
    );
    return OemHardeningStatus(
      manufacturer: json['manufacturer'] as String? ?? '',
      brand: json['brand'] as String? ?? '',
      model: json['model'] as String? ?? '',
      sdkInt: json['sdkInt'] as int? ?? 0,
      isIgnoringBatteryOptimizations:
          json['isIgnoringBatteryOptimizations'] as bool? ?? false,
      isKeepAliveServiceRunning:
          json['isKeepAliveServiceRunning'] as bool? ?? false,
      isAggressiveOem: json['isAggressiveOem'] as bool? ?? false,
      oemBrand: brand,
      riskLevel: risk,
    );
  }

  OemHardeningStatus copyWith({
    String? manufacturer,
    String? brand,
    String? model,
    int? sdkInt,
    bool? isIgnoringBatteryOptimizations,
    bool? isKeepAliveServiceRunning,
    bool? isAggressiveOem,
    OemBrand? oemBrand,
    OemRiskLevel? riskLevel,
  }) {
    return OemHardeningStatus(
      manufacturer: manufacturer ?? this.manufacturer,
      brand: brand ?? this.brand,
      model: model ?? this.model,
      sdkInt: sdkInt ?? this.sdkInt,
      isIgnoringBatteryOptimizations:
          isIgnoringBatteryOptimizations ?? this.isIgnoringBatteryOptimizations,
      isKeepAliveServiceRunning:
          isKeepAliveServiceRunning ?? this.isKeepAliveServiceRunning,
      isAggressiveOem: isAggressiveOem ?? this.isAggressiveOem,
      oemBrand: oemBrand ?? this.oemBrand,
      riskLevel: riskLevel ?? this.riskLevel,
    );
  }
}

class OemHardeningConfig {
  final bool keepAliveEnabledByUser;
  final bool bannerDismissed;
  final DateTime? lastChecked;

  const OemHardeningConfig({
    this.keepAliveEnabledByUser = false,
    this.bannerDismissed = false,
    this.lastChecked,
  });

  Map<String, dynamic> toJson() => {
        'keepAliveEnabledByUser': keepAliveEnabledByUser,
        'bannerDismissed': bannerDismissed,
        'lastChecked': lastChecked?.toIso8601String(),
      };

  factory OemHardeningConfig.fromJson(Map<String, dynamic> json) =>
      OemHardeningConfig(
        keepAliveEnabledByUser:
            json['keepAliveEnabledByUser'] as bool? ?? false,
        bannerDismissed: json['bannerDismissed'] as bool? ?? false,
        lastChecked: json['lastChecked'] != null
            ? DateTime.tryParse(json['lastChecked'] as String)
            : null,
      );

  OemHardeningConfig copyWith({
    bool? keepAliveEnabledByUser,
    bool? bannerDismissed,
    DateTime? lastChecked,
  }) {
    return OemHardeningConfig(
      keepAliveEnabledByUser:
          keepAliveEnabledByUser ?? this.keepAliveEnabledByUser,
      bannerDismissed: bannerDismissed ?? this.bannerDismissed,
      lastChecked: lastChecked ?? this.lastChecked,
    );
  }
}

