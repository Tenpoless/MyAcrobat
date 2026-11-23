import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../models/sign_document_result.dart';
import '../models/signature_placement.dart';
import '../models/syncro_user.dart';
import '../models/vault_pdf_file.dart';

class MyAcrobatApiClient {
  MyAcrobatApiClient({
    Dio? dio,
    String baseUrl = defaultBaseUrl,
  }) : _dio = dio ?? Dio(BaseOptions(baseUrl: baseUrl));

  static const String defaultBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://syncro.saraswanti.co.id/agrisign',
  );

  final Dio _dio;
  String? _authToken;

  String get baseUrl => _dio.options.baseUrl;
  String? get authToken => _authToken;

  void updateBaseUrl(String newBaseUrl) {
    _dio.options.baseUrl = newBaseUrl.trim();
  }

  void setAuthToken(String? token) {
    final trimmed = token?.trim();
    _authToken = (trimmed != null && trimmed.isNotEmpty) ? trimmed : null;
    if (_authToken != null) {
      _dio.options.headers['Authorization'] = 'Bearer $_authToken';
    } else {
      _dio.options.headers.remove('Authorization');
    }
  }

  Future<AuthLoginResult> login({
    required String identifier,
    required String password,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/auth/login',
      data: <String, dynamic>{
        'identifier': identifier.trim(),
        'password': password,
      },
    );
    final result = AuthLoginResult.fromJson(
      Map<String, dynamic>.from(response.data ?? const <String, dynamic>{}),
    );
    setAuthToken(result.token);
    return result;
  }

  Future<SyncroUser> fetchCurrentUser() async {
    final response = await _dio.get<Map<String, dynamic>>('/api/me');
    final rawUser = response.data?['user'] as Map?;
    return SyncroUser.fromJson(
      Map<String, dynamic>.from(rawUser ?? const <String, dynamic>{}),
    );
  }

  Future<void> uploadUserSignature(Uint8List pngBytes) async {
    final signatureDataUri =
        'data:image/png;base64,${base64Encode(pngBytes)}';
    await _dio.put<Map<String, dynamic>>(
      '/api/me/signature',
      data: <String, dynamic>{
        'signatureImageBase64': signatureDataUri,
      },
    );
  }

  Future<List<VaultPdfFile>> fetchFiles({String? search}) async {
    final trimmedSearch = search?.trim();
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/files',
      queryParameters: (trimmedSearch != null && trimmedSearch.isNotEmpty)
          ? <String, dynamic>{'search': trimmedSearch}
          : null,
    );

    final rawFiles = response.data?['files'] as List<dynamic>? ?? const [];
    return rawFiles
        .map(
          (item) => VaultPdfFile.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList();
  }

  Future<Uint8List> downloadPdfBytes(String fileId) async {
    final encodedId = Uri.encodeComponent(fileId);
    final response = await _dio.get<List<int>>(
      '/api/files/$encodedId/download',
      options: Options(responseType: ResponseType.bytes),
    );

    final data = response.data;
    if (data == null) {
      return Uint8List(0);
    }
    return data is Uint8List ? data : Uint8List.fromList(data);
  }

  Future<SignDocumentResult> signDocument({
    required String fileId,
    required Uint8List signaturePngBytes,
    required List<SignaturePlacement> placements,
  }) async {
    final encodedId = Uri.encodeComponent(fileId);
    final signatureDataUri =
        'data:image/png;base64,${base64Encode(signaturePngBytes)}';

    final response = await _dio.post<Map<String, dynamic>>(
      '/api/files/$encodedId/sign',
      data: <String, dynamic>{
        'signatureImageBase64': signatureDataUri,
        'placements': placements.map((p) => p.toJson()).toList(),
      },
    );

    return SignDocumentResult.fromJson(
      Map<String, dynamic>.from(response.data ?? const <String, dynamic>{}),
    );
  }
}
