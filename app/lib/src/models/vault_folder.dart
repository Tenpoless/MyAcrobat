import 'vault_pdf_file.dart';

class VaultFolder {
  const VaultFolder({required this.folderId, required this.name});

  final String folderId;
  final String name;

  factory VaultFolder.fromJson(Map<String, dynamic> json) {
    return VaultFolder(
      folderId: json['folderId'] as String,
      name: json['name'] as String,
    );
  }
}

/// Isi satu folder Google Drive: subfolder dan PDF.
class VaultDirectoryListing {
  const VaultDirectoryListing({
    this.folders = const <VaultFolder>[],
    this.files = const <VaultPdfFile>[],
  });

  final List<VaultFolder> folders;
  final List<VaultPdfFile> files;
}
