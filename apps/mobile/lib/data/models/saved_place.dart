import 'dart:math' as math;

enum PlaceCategory {
  home,
  work,
  store,
  gym,
  transit,
  school,
  custom,
}

extension PlaceCategoryExt on PlaceCategory {
  String get displayName {
    switch (this) {
      case PlaceCategory.home:
        return 'Home';
      case PlaceCategory.work:
        return 'Work';
      case PlaceCategory.store:
        return 'Store';
      case PlaceCategory.gym:
        return 'Gym';
      case PlaceCategory.transit:
        return 'Transit';
      case PlaceCategory.school:
        return 'Campus';
      case PlaceCategory.custom:
        return 'Custom';
    }
  }

  String get emoji {
    switch (this) {
      case PlaceCategory.home:
        return '🏠';
      case PlaceCategory.work:
        return '💼';
      case PlaceCategory.store:
        return '🛒';
      case PlaceCategory.gym:
        return '🏋️';
      case PlaceCategory.transit:
        return '🚉';
      case PlaceCategory.school:
        return '🎓';
      case PlaceCategory.custom:
        return '📍';
    }
  }

  double get defaultRadiusMeters {
    switch (this) {
      case PlaceCategory.home:
        return 120.0;
      case PlaceCategory.work:
        return 180.0;
      case PlaceCategory.store:
        return 150.0;
      case PlaceCategory.gym:
        return 150.0;
      case PlaceCategory.transit:
        return 250.0;
      case PlaceCategory.school:
        return 250.0;
      case PlaceCategory.custom:
        return 150.0;
    }
  }

  int get colorValue {
    switch (this) {
      case PlaceCategory.home:
        return 0xFF3B82F6;
      case PlaceCategory.work:
        return 0xFF8B5CF6;
      case PlaceCategory.store:
        return 0xFF10B981;
      case PlaceCategory.gym:
        return 0xFFE04A3A;
      case PlaceCategory.transit:
        return 0xFFF59E0B;
      case PlaceCategory.school:
        return 0xFF06B6D4;
      case PlaceCategory.custom:
        return 0xFF60A5FA;
    }
  }
}

/// Designated geographic zone monitored by native geofencing.
class SavedPlace {
  static const double minRadiusMeters = 50.0;
  static const double maxRadiusMeters = 5000.0;

  final String id;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final double radiusMeters;
  final PlaceCategory category;
  final DateTime createdAt;

  const SavedPlace({
    required this.id,
    required this.name,
    this.address = '',
    required this.latitude,
    required this.longitude,
    this.radiusMeters = 150.0,
    this.category = PlaceCategory.custom,
    required this.createdAt,
  });

  double get clampedLatitude => latitude.clamp(-90.0, 90.0).toDouble();

  double get clampedLongitude => longitude.clamp(-180.0, 180.0).toDouble();

  double get clampedRadiusMeters =>
      radiusMeters.clamp(minRadiusMeters, maxRadiusMeters).toDouble();

  String get formattedCoordinates =>
      '${clampedLatitude.toStringAsFixed(4)}, ${clampedLongitude.toStringAsFixed(4)}';

  String get formattedRadius {
    final meters = clampedRadiusMeters.round();
    if (meters >= 1000) {
      final km = meters / 1000.0;
      return '${km.toStringAsFixed(km % 1 == 0 ? 0 : 1)} km';
    }
    return '$meters m';
  }

  /// Great-circle Haversine distance in meters from this place's center to [lat]/[lon].
  double distanceToMeters(double lat, double lon) {
    return haversineMeters(clampedLatitude, clampedLongitude, lat, lon);
  }

  /// Whether [lat]/[lon] falls inside this geofence radius.
  bool containsCoordinate(double lat, double lon) {
    return distanceToMeters(lat, lon) <= clampedRadiusMeters;
  }

  static double haversineMeters(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadiusMeters = 6371000.0;
    final dLat = _degToRad(lat2 - lat1);
    final dLon = _degToRad(lon2 - lon1);
    final rLat1 = _degToRad(lat1);
    final rLat2 = _degToRad(lat2);

    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(rLat1) *
            math.cos(rLat2) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(math.max(0.0, 1 - a)));
    return earthRadiusMeters * c;
  }

  static double _degToRad(double deg) => deg * (math.pi / 180.0);

  SavedPlace copyWith({
    String? id,
    String? name,
    String? address,
    double? latitude,
    double? longitude,
    double? radiusMeters,
    PlaceCategory? category,
    DateTime? createdAt,
  }) {
    return SavedPlace(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      radiusMeters: radiusMeters ?? this.radiusMeters,
      category: category ?? this.category,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'latitude': clampedLatitude,
      'longitude': clampedLongitude,
      'radiusMeters': clampedRadiusMeters,
      'category': category.name,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory SavedPlace.fromJson(Map<String, dynamic> json) {
    final categoryName = json['category'] as String? ?? 'custom';
    final category = PlaceCategory.values.firstWhere(
      (c) => c.name == categoryName,
      orElse: () => PlaceCategory.custom,
    );
    final rawLat = (json['latitude'] as num?)?.toDouble() ?? 0.0;
    final rawLng = (json['longitude'] as num?)?.toDouble() ?? 0.0;
    final rawRadius =
        (json['radiusMeters'] as num?)?.toDouble() ?? category.defaultRadiusMeters;

    return SavedPlace(
      id: json['id'] as String? ?? 'place_unknown',
      name: json['name'] as String? ?? 'Saved Place',
      address: json['address'] as String? ?? '',
      latitude: rawLat.clamp(-90.0, 90.0).toDouble(),
      longitude: rawLng.clamp(-180.0, 180.0).toDouble(),
      radiusMeters:
          rawRadius.clamp(minRadiusMeters, maxRadiusMeters).toDouble(),
      category: category,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

