import 'vault_pdf_file.dart';

class SignDocumentResult {
  const SignDocumentResult({
    required this.message,
    required this.sourceFileId,
    required this.signedFile,
  });

  final String message;
  final String sourceFileId;
  final VaultPdfFile signedFile;

  factory SignDocumentResult.fromJson(Map<String, dynamic> json) {
    return SignDocumentResult(
      message: json['message'] as String? ?? '',
      sourceFileId: json['sourceFileId'] as String,
      signedFile: VaultPdfFile.fromJson(
        Map<String, dynamic>.from(json['signedFile'] as Map),
      ),
    );
  }
}
