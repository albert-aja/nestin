import 'dart:convert';
import 'package:flutter/material.dart';

enum InspirationSubmissionStatus {
  draft,
  pending,
  approved,
  rejected,
  withdrawn;

  static InspirationSubmissionStatus fromApi(String? raw) {
    switch ((raw ?? '').toUpperCase()) {
      case 'PENDING':
        return InspirationSubmissionStatus.pending;
      case 'APPROVED':
        return InspirationSubmissionStatus.approved;
      case 'REJECTED':
        return InspirationSubmissionStatus.rejected;
      case 'WITHDRAWN':
        return InspirationSubmissionStatus.withdrawn;
      default:
        return InspirationSubmissionStatus.draft;
    }
  }

  String toApi() => name.toUpperCase();
}

enum InspirationNotificationFrequency {
  daily,
  weekdays,
  weekly;

  static InspirationNotificationFrequency fromApi(String? raw) {
    switch ((raw ?? '').toUpperCase()) {
      case 'WEEKDAYS':
        return InspirationNotificationFrequency.weekdays;
      case 'WEEKLY':
        return InspirationNotificationFrequency.weekly;
      default:
        return InspirationNotificationFrequency.daily;
    }
  }

  String toApi() => name.toUpperCase();
}

enum QuoteCardAspectRatio {
  square1x1('1:1', 1.0, 'quote_card_square'),
  portrait4x5('4:5', 0.8, 'quote_card_portrait'),
  lockScreen9x16('9:16', 9 / 16, 'lock_screen'),
  homeScreen9x16('9:16', 9 / 16, 'home_screen');

  final String ratioLabel;
  final double ratioValue;
  final String layoutType;

  const QuoteCardAspectRatio(this.ratioLabel, this.ratioValue, this.layoutType);
}

class InspirationAuthor {
  final String id;
  final String name;
  final String slug;
  final String bio;
  final String? mascotDomain;
  final bool isAnonymousOrUnknown;

  const InspirationAuthor({
    required this.id,
    required this.name,
    required this.slug,
    this.bio = '',
    this.mascotDomain,
    this.isAnonymousOrUnknown = false,
  });

  factory InspirationAuthor.fromJson(Map<String, dynamic> json) {
    return InspirationAuthor(
      id: json['id'] as String,
      name: json['name'] as String,
      slug: (json['slug'] as String?) ?? '',
      bio: (json['bio'] as String?) ?? '',
      mascotDomain: json['mascotDomain'] as String?,
      isAnonymousOrUnknown: json['isAnonymousOrUnknown'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'slug': slug,
        'bio': bio,
        'mascotDomain': mascotDomain,
        'isAnonymousOrUnknown': isAnonymousOrUnknown,
      };
}

class InspirationCategory {
  final String id;
  final String slug;
  final String name;
  final String description;
  final Map<String, String> localizedNames;
  final String? mascotDomain;
  final int sortOrder;

  const InspirationCategory({
    required this.id,
    required this.slug,
    required this.name,
    this.description = '',
    this.localizedNames = const {},
    this.mascotDomain,
    this.sortOrder = 0,
  });

  String labelForLocale(String locale) => localizedNames[locale] ?? name;

  factory InspirationCategory.fromJson(Map<String, dynamic> json) {
    final parsedNames = <String, String>{};
    final rawTrans = json['translations'];
    if (rawTrans is Map) {
      rawTrans.forEach((key, value) {
        if (value is Map && value['name'] is String) {
          parsedNames[key.toString()] = value['name'] as String;
        }
      });
    }
    return InspirationCategory(
      id: json['id'] as String,
      slug: json['slug'] as String,
      name: json['name'] as String,
      description: (json['description'] as String?) ?? '',
      localizedNames: parsedNames,
      mascotDomain: json['mascotDomain'] as String?,
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'slug': slug,
        'name': name,
        'description': description,
        'translations': localizedNames.map(
          (k, v) => MapEntry(k, {'name': v}),
        ),
        'mascotDomain': mascotDomain,
        'sortOrder': sortOrder,
      };
}

class InspirationQuote {
  final String id;
  final String quoteText;
  final String author;
  final String? authorId;
  final String category;
  final String? categoryId;
  final String locale;
  final String? mascotDomain;
  final String originType;
  final bool isFeatured;
  final String? scheduledFor;
  final String? sourceReference;
  final String? backgroundAssetUrl;
  final DateTime? updatedAt;

  const InspirationQuote({
    required this.id,
    required this.quoteText,
    required this.author,
    this.authorId,
    required this.category,
    this.categoryId,
    this.locale = 'en',
    this.mascotDomain,
    this.originType = 'SYSTEM',
    this.isFeatured = false,
    this.scheduledFor,
    this.sourceReference,
    this.backgroundAssetUrl,
    this.updatedAt,
  });

  factory InspirationQuote.fromJson(Map<String, dynamic> json) {
    return InspirationQuote(
      id: json['id'] as String,
      quoteText: json['quoteText'] as String,
      author: (json['author'] as String?) ?? 'Nestin',
      authorId: json['authorId'] as String?,
      category: (json['category'] as String?) ?? 'motivation',
      categoryId: json['categoryId'] as String?,
      locale: (json['locale'] as String?) ?? 'en',
      mascotDomain: json['mascotDomain'] as String?,
      originType: (json['originType'] as String?) ?? 'SYSTEM',
      isFeatured: json['isFeatured'] as bool? ?? false,
      scheduledFor: json['scheduledFor'] as String?,
      sourceReference: json['sourceReference'] as String?,
      backgroundAssetUrl: json['backgroundAssetUrl'] as String?,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'quoteText': quoteText,
        'author': author,
        'authorId': authorId,
        'category': category,
        'categoryId': categoryId,
        'locale': locale,
        'mascotDomain': mascotDomain,
        'originType': originType,
        'isFeatured': isFeatured,
        'scheduledFor': scheduledFor,
        'sourceReference': sourceReference,
        'backgroundAssetUrl': backgroundAssetUrl,
        'updatedAt': updatedAt?.toUtc().toIso8601String(),
      };
}

class InspirationUserQuote {
  final String id;
  final String quoteText;
  final String? authorName;
  final String categoryId;
  final String categorySlug;
  final String locale;
  final String? sourceReference;
  final String displayPreference;
  final bool rightsConfirmed;
  final bool isPersonalOnly;
  final bool isLocalOnlyDraft;
  final DateTime createdAt;
  final DateTime updatedAt;

  const InspirationUserQuote({
    required this.id,
    required this.quoteText,
    this.authorName,
    required this.categoryId,
    required this.categorySlug,
    this.locale = 'en',
    this.sourceReference,
    this.displayPreference = 'anonymous',
    this.rightsConfirmed = false,
    this.isPersonalOnly = true,
    this.isLocalOnlyDraft = false,
    required this.createdAt,
    required this.updatedAt,
  });

  InspirationUserQuote copyWith({
    String? quoteText,
    String? authorName,
    String? categoryId,
    String? categorySlug,
    String? locale,
    String? sourceReference,
    String? displayPreference,
    bool? rightsConfirmed,
    bool? isPersonalOnly,
    bool? isLocalOnlyDraft,
    DateTime? updatedAt,
  }) {
    return InspirationUserQuote(
      id: id,
      quoteText: quoteText ?? this.quoteText,
      authorName: authorName ?? this.authorName,
      categoryId: categoryId ?? this.categoryId,
      categorySlug: categorySlug ?? this.categorySlug,
      locale: locale ?? this.locale,
      sourceReference: sourceReference ?? this.sourceReference,
      displayPreference: displayPreference ?? this.displayPreference,
      rightsConfirmed: rightsConfirmed ?? this.rightsConfirmed,
      isPersonalOnly: isPersonalOnly ?? this.isPersonalOnly,
      isLocalOnlyDraft: isLocalOnlyDraft ?? this.isLocalOnlyDraft,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory InspirationUserQuote.fromJson(Map<String, dynamic> json) {
    return InspirationUserQuote(
      id: json['id'] as String,
      quoteText: json['quoteText'] as String,
      authorName: json['authorName'] as String?,
      categoryId: json['categoryId'] as String,
      categorySlug: (json['categorySlug'] as String?) ?? 'motivation',
      locale: (json['locale'] as String?) ?? 'en',
      sourceReference: json['sourceReference'] as String?,
      displayPreference: (json['displayPreference'] as String?) ?? 'anonymous',
      rightsConfirmed: json['rightsConfirmed'] as bool? ?? false,
      isPersonalOnly: json['isPersonalOnly'] as bool? ?? true,
      isLocalOnlyDraft: json['isLocalOnlyDraft'] as bool? ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now().toUtc(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : DateTime.now().toUtc(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'quoteText': quoteText,
        'authorName': authorName,
        'categoryId': categoryId,
        'categorySlug': categorySlug,
        'locale': locale,
        'sourceReference': sourceReference,
        'displayPreference': displayPreference,
        'rightsConfirmed': rightsConfirmed,
        'isPersonalOnly': isPersonalOnly,
        'isLocalOnlyDraft': isLocalOnlyDraft,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'updatedAt': updatedAt.toUtc().toIso8601String(),
      };
}

class InspirationSubmission {
  final String id;
  final String userQuoteId;
  final InspirationSubmissionStatus status;
  final bool anonymousPublication;
  final String quoteText;
  final String? authorName;
  final String categoryId;
  final String categorySlug;
  final String locale;
  final String? rejectionReason;
  final String? publishedQuoteId;
  final DateTime? submittedAt;
  final DateTime? reviewedAt;
  final bool isConfirmedByServer;

  const InspirationSubmission({
    required this.id,
    required this.userQuoteId,
    required this.status,
    required this.anonymousPublication,
    required this.quoteText,
    this.authorName,
    required this.categoryId,
    required this.categorySlug,
    this.locale = 'en',
    this.rejectionReason,
    this.publishedQuoteId,
    this.submittedAt,
    this.reviewedAt,
    this.isConfirmedByServer = true,
  });

  factory InspirationSubmission.fromJson(Map<String, dynamic> json) {
    return InspirationSubmission(
      id: json['id'] as String,
      userQuoteId: json['userQuoteId'] as String,
      status: InspirationSubmissionStatus.fromApi(json['status'] as String?),
      anonymousPublication: json['anonymousPublication'] as bool? ?? true,
      quoteText: json['quoteText'] as String,
      authorName: json['authorName'] as String?,
      categoryId: json['categoryId'] as String,
      categorySlug: (json['categorySlug'] as String?) ?? 'motivation',
      locale: (json['locale'] as String?) ?? 'en',
      rejectionReason: json['rejectionReason'] as String?,
      publishedQuoteId: json['publishedQuoteId'] as String?,
      submittedAt: json['submittedAt'] != null
          ? DateTime.tryParse(json['submittedAt'] as String)
          : null,
      reviewedAt: json['reviewedAt'] != null
          ? DateTime.tryParse(json['reviewedAt'] as String)
          : null,
      isConfirmedByServer: json['isConfirmedByServer'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'userQuoteId': userQuoteId,
        'status': status.toApi(),
        'anonymousPublication': anonymousPublication,
        'quoteText': quoteText,
        'authorName': authorName,
        'categoryId': categoryId,
        'categorySlug': categorySlug,
        'locale': locale,
        'rejectionReason': rejectionReason,
        'publishedQuoteId': publishedQuoteId,
        'submittedAt': submittedAt?.toUtc().toIso8601String(),
        'reviewedAt': reviewedAt?.toUtc().toIso8601String(),
        'isConfirmedByServer': isConfirmedByServer,
      };
}

class InspirationWallpaperTemplate {
  final String id;
  final String slug;
  final String name;
  final String layoutType;
  final String aspectRatio;
  final String backgroundType;
  final List<String> gradientColors;
  final String textColor;
  final String fontFamily;
  final String textAlignment;
  final bool showBranding;
  final String? mascotIllustration;

  const InspirationWallpaperTemplate({
    required this.id,
    required this.slug,
    required this.name,
    required this.layoutType,
    required this.aspectRatio,
    this.backgroundType = 'gradient',
    this.gradientColors = const ['#161822', '#2B3040'],
    this.textColor = '#FFFFFF',
    this.fontFamily = 'serif',
    this.textAlignment = 'center',
    this.showBranding = true,
    this.mascotIllustration,
  });

  List<Color> get parsedGradientColors {
    final parsed = gradientColors.map(_parseHexColor).toList();
    if (parsed.isEmpty) {
      return const [Color(0xFF161822), Color(0xFF2B3040)];
    }
    if (parsed.length == 1) {
      return [parsed.first, parsed.first];
    }
    return parsed;
  }

  Color get parsedTextColor => _parseHexColor(textColor, fallback: Colors.white);

  factory InspirationWallpaperTemplate.fromJson(Map<String, dynamic> json) {
    final rawColors = json['gradientColors'];
    final colors = rawColors is List
        ? rawColors.map((e) => e.toString()).toList()
        : const ['#161822', '#2B3040'];
    return InspirationWallpaperTemplate(
      id: json['id'] as String,
      slug: (json['slug'] as String?) ?? 'template',
      name: (json['name'] as String?) ?? 'Template',
      layoutType: (json['layoutType'] as String?) ?? 'quote_card_portrait',
      aspectRatio: (json['aspectRatio'] as String?) ?? '4:5',
      backgroundType: (json['backgroundType'] as String?) ?? 'gradient',
      gradientColors: colors,
      textColor: (json['textColor'] as String?) ?? '#FFFFFF',
      fontFamily: (json['fontFamily'] as String?) ?? 'serif',
      textAlignment: (json['textAlignment'] as String?) ?? 'center',
      showBranding: json['showBranding'] as bool? ?? true,
      mascotIllustration: json['mascotIllustration'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'slug': slug,
        'name': name,
        'layoutType': layoutType,
        'aspectRatio': aspectRatio,
        'backgroundType': backgroundType,
        'gradientColors': gradientColors,
        'textColor': textColor,
        'fontFamily': fontFamily,
        'textAlignment': textAlignment,
        'showBranding': showBranding,
        'mascotIllustration': mascotIllustration,
      };
}

class QuoteCardDesignConfig {
  final String templateId;
  final QuoteCardAspectRatio aspectRatio;
  final bool useGradient;
  final List<Color> gradientColors;
  final Color solidColor;
  final Color textColor;
  final String fontFamily;
  final TextAlign textAlign;
  final double fontSize;
  final double verticalPosition; // 0.25 top safe-zone .. 0.75 bottom safe-zone
  final bool showAuthor;
  final bool showBranding;
  final String? mascotDomain;

  const QuoteCardDesignConfig({
    required this.templateId,
    this.aspectRatio = QuoteCardAspectRatio.portrait4x5,
    this.useGradient = true,
    this.gradientColors = const [Color(0xFF1F1627), Color(0xFF3A1D2E), Color(0xFFE04A3A)],
    this.solidColor = const Color(0xFF1A1B20),
    this.textColor = Colors.white,
    this.fontFamily = 'serif',
    this.textAlign = TextAlign.center,
    this.fontSize = 22.0,
    this.verticalPosition = 0.5,
    this.showAuthor = true,
    this.showBranding = true,
    this.mascotDomain = 'pippin',
  });

  QuoteCardDesignConfig copyWith({
    String? templateId,
    QuoteCardAspectRatio? aspectRatio,
    bool? useGradient,
    List<Color>? gradientColors,
    Color? solidColor,
    Color? textColor,
    String? fontFamily,
    TextAlign? textAlign,
    double? fontSize,
    double? verticalPosition,
    bool? showAuthor,
    bool? showBranding,
    String? mascotDomain,
    bool clearMascot = false,
  }) {
    return QuoteCardDesignConfig(
      templateId: templateId ?? this.templateId,
      aspectRatio: aspectRatio ?? this.aspectRatio,
      useGradient: useGradient ?? this.useGradient,
      gradientColors: gradientColors ?? this.gradientColors,
      solidColor: solidColor ?? this.solidColor,
      textColor: textColor ?? this.textColor,
      fontFamily: fontFamily ?? this.fontFamily,
      textAlign: textAlign ?? this.textAlign,
      fontSize: fontSize ?? this.fontSize,
      verticalPosition: verticalPosition ?? this.verticalPosition,
      showAuthor: showAuthor ?? this.showAuthor,
      showBranding: showBranding ?? this.showBranding,
      mascotDomain: clearMascot ? null : (mascotDomain ?? this.mascotDomain),
    );
  }
}

class InspirationNotificationPreferences {
  final bool dailyEnabled;
  final bool submissionUpdatesEnabled;
  final String preferredTime;
  final String timezone;
  final InspirationNotificationFrequency frequency;
  final String preferredLocale;
  final List<String> preferredCategoryIds;

  const InspirationNotificationPreferences({
    this.dailyEnabled = false,
    this.submissionUpdatesEnabled = true,
    this.preferredTime = '08:00',
    this.timezone = 'UTC',
    this.frequency = InspirationNotificationFrequency.daily,
    this.preferredLocale = 'en',
    this.preferredCategoryIds = const [],
  });

  int get preferredHour {
    final parts = preferredTime.split(':');
    return parts.isNotEmpty ? (int.tryParse(parts[0]) ?? 8) : 8;
  }

  int get preferredMinute {
    final parts = preferredTime.split(':');
    return parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
  }

  InspirationNotificationPreferences copyWith({
    bool? dailyEnabled,
    bool? submissionUpdatesEnabled,
    String? preferredTime,
    String? timezone,
    InspirationNotificationFrequency? frequency,
    String? preferredLocale,
    List<String>? preferredCategoryIds,
  }) {
    return InspirationNotificationPreferences(
      dailyEnabled: dailyEnabled ?? this.dailyEnabled,
      submissionUpdatesEnabled:
          submissionUpdatesEnabled ?? this.submissionUpdatesEnabled,
      preferredTime: preferredTime ?? this.preferredTime,
      timezone: timezone ?? this.timezone,
      frequency: frequency ?? this.frequency,
      preferredLocale: preferredLocale ?? this.preferredLocale,
      preferredCategoryIds: preferredCategoryIds ?? this.preferredCategoryIds,
    );
  }

  factory InspirationNotificationPreferences.fromJson(
    Map<String, dynamic> json,
  ) {
    final rawCats = json['preferredCategoryIds'];
    return InspirationNotificationPreferences(
      dailyEnabled: json['dailyEnabled'] as bool? ?? false,
      submissionUpdatesEnabled:
          json['submissionUpdatesEnabled'] as bool? ?? true,
      preferredTime: (json['preferredTime'] as String?) ?? '08:00',
      timezone: (json['timezone'] as String?) ?? 'UTC',
      frequency: InspirationNotificationFrequency.fromApi(
        json['frequency'] as String?,
      ),
      preferredLocale: (json['preferredLocale'] as String?) ?? 'en',
      preferredCategoryIds: rawCats is List
          ? rawCats.map((e) => e.toString()).toList()
          : const [],
    );
  }

  Map<String, dynamic> toJson() => {
        'dailyEnabled': dailyEnabled,
        'submissionUpdatesEnabled': submissionUpdatesEnabled,
        'preferredTime': preferredTime,
        'timezone': timezone,
        'frequency': frequency.toApi(),
        'preferredLocale': preferredLocale,
        'preferredCategoryIds': preferredCategoryIds,
      };

  static InspirationNotificationPreferences decodeOrDefault(String? raw) {
    if (raw == null || raw.isEmpty) {
      return const InspirationNotificationPreferences();
    }
    try {
      return InspirationNotificationPreferences.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      return const InspirationNotificationPreferences();
    }
  }
}

Color _parseHexColor(String hex, {Color fallback = const Color(0xFF1F2937)}) {
  final clean = hex.trim().replaceFirst('#', '');
  if (clean.length == 6) {
    final value = int.tryParse('FF$clean', radix: 16);
    if (value != null) return Color(value);
  } else if (clean.length == 8) {
    final value = int.tryParse(clean, radix: 16);
    if (value != null) return Color(value);
  }
  return fallback;
}
