import 'dart:convert';
import 'dart:typed_data';

class SyncroUser {
  const SyncroUser({
    required this.id,
    required this.name,
    required this.username,
    required this.email,
    required this.position,
    required this.role,
    required this.hasSavedSignature,
    required this.signatureImageBase64,
  });

  final int id;
  final String name;
  final String username;
  final String email;
  final String? position;
  final String role;
  final bool hasSavedSignature;
  final String? signatureImageBase64;

  bool get isViewer => role.trim().toLowerCase() == 'viewer';
  bool get canSign => !isViewer;

  Uint8List? decodeSignatureBytes() {
    final raw = signatureImageBase64?.trim();
    if (raw == null || raw.isEmpty) {
      return null;
    }
    final cleaned = raw.replaceFirst(
      RegExp(r'^data:image\/png;base64,', caseSensitive: false),
      '',
    );
    if (cleaned.isEmpty) {
      return null;
    }
    try {
      return base64Decode(cleaned);
    } catch (_) {
      return null;
    }
  }

  factory SyncroUser.fromJson(Map<String, dynamic> json) {
    return SyncroUser(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: (json['name'] as String?) ?? '',
      username: (json['username'] as String?) ?? '',
      email: (json['email'] as String?) ?? '',
      position: json['position'] as String?,
      role: (json['role'] as String?) ?? 'signer',
      hasSavedSignature: (json['hasSavedSignature'] as bool?) ?? false,
      signatureImageBase64: json['signatureImageBase64'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'username': username,
      'email': email,
      'position': position,
      'role': role,
      'hasSavedSignature': hasSavedSignature,
      'signatureImageBase64': signatureImageBase64,
    };
  }
}

class AuthLoginResult {
  const AuthLoginResult({
    required this.token,
    required this.user,
  });

  final String token;
  final SyncroUser user;

  factory AuthLoginResult.fromJson(Map<String, dynamic> json) {
    return AuthLoginResult(
      token: (json['token'] as String?) ?? '',
      user: SyncroUser.fromJson(
        Map<String, dynamic>.from(
          (json['user'] as Map?) ?? const <String, dynamic>{},
        ),
      ),
    );
  }
}
