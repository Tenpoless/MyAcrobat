class VaultPdfFile {
  const VaultPdfFile({
    required this.fileId,
    required this.name,
    required this.size,
    required this.updatedAt,
    required this.isSigned,
  });

  final String fileId;
  final String name;
  final int size;
  final DateTime updatedAt;
  final bool isSigned;

  factory VaultPdfFile.fromJson(Map<String, dynamic> json) {
    return VaultPdfFile(
      fileId: json['fileId'] as String,
      name: json['name'] as String,
      size: (json['size'] as num).toInt(),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      isSigned: json['isSigned'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'fileId': fileId,
      'name': name,
      'size': size,
      'updatedAt': updatedAt.toUtc().toIso8601String(),
      'isSigned': isSigned,
    };
  }

  String get formattedSize {
    if (size < 1024) {
      return '$size B';
    }
    const kb = 1024;
    const mb = 1024 * 1024;
    if (size < mb) {
      return '${(size / kb).round()} KB';
    }
    return '${(size / mb).toStringAsFixed(1)} MB';
  }
}
