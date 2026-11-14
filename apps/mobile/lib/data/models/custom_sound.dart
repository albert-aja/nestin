class CustomSound {
  final String id;
  final String name;
  final String filePath;
  final int fileSizeBytes;
  final DateTime importedAt;

  const CustomSound({
    required this.id,
    required this.name,
    required this.filePath,
    required this.fileSizeBytes,
    required this.importedAt,
  });

  String get formattedSize {
    if (fileSizeBytes < 1024) return '$fileSizeBytes B';
    if (fileSizeBytes < 1024 * 1024) {
      return '${(fileSizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(fileSizeBytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'filePath': filePath,
      'fileSizeBytes': fileSizeBytes,
      'importedAt': importedAt.toIso8601String(),
    };
  }

  factory CustomSound.fromJson(Map<String, dynamic> json) {
    return CustomSound(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'Custom Sound',
      filePath: json['filePath'] as String? ?? '',
      fileSizeBytes: json['fileSizeBytes'] as int? ?? 0,
      importedAt: json['importedAt'] != null
          ? DateTime.parse(json['importedAt'] as String)
          : DateTime.now(),
    );
  }
}

