import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../api/myacrobat_api_client.dart';
import '../../models/syncro_user.dart';
import '../files/document_list_provider.dart';
import '../signature/saved_signature_repository.dart';

const String kAuthTokenPrefKey = 'myacrobat.auth_token';
const String kAuthUserJsonPrefKey = 'myacrobat.auth_user_json';

class AuthState {
  const AuthState({
    this.token,
    this.user,
    this.isLoading = false,
    this.errorMessage,
  });

  final String? token;
  final SyncroUser? user;
  final bool isLoading;
  final String? errorMessage;

  bool get isAuthenticated =>
      token != null && token!.isNotEmpty && user != null;

  bool get isViewer => user?.isViewer ?? false;

  AuthState copyWith({
    String? token,
    SyncroUser? user,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
    bool clearSession = false,
  }) {
    if (clearSession) {
      return const AuthState();
    }
    return AuthState(
      token: token ?? this.token,
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class AuthController extends StateNotifier<AuthState> {
  AuthController({
    required MyAcrobatApiClient apiClient,
    required SavedSignatureRepository signatureRepository,
    AuthState? initialState,
  })  : _apiClient = apiClient,
        _signatureRepository = signatureRepository,
        super(initialState ?? const AuthState()) {
    if (initialState?.token != null) {
      _apiClient.setAuthToken(initialState!.token);
    }
  }

  final MyAcrobatApiClient _apiClient;
  final SavedSignatureRepository _signatureRepository;

  Future<void> restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final savedToken = prefs.getString(kAuthTokenPrefKey)?.trim();
    final savedUserJson = prefs.getString(kAuthUserJsonPrefKey);
    if (savedToken == null ||
        savedToken.isEmpty ||
        savedUserJson == null ||
        savedUserJson.isEmpty) {
      return;
    }

    try {
      final decoded =
          Map<String, dynamic>.from(jsonDecode(savedUserJson) as Map);
      final user = SyncroUser.fromJson(decoded);
      _apiClient.setAuthToken(savedToken);
      await _syncSignatureFromServerUser(user);
      state = AuthState(token: savedToken, user: user);
    } catch (_) {
      await logout();
    }
  }

  Future<bool> login({
    required String identifier,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final result = await _apiClient.login(
        identifier: identifier,
        password: password,
      );
      _apiClient.setAuthToken(result.token);
      await _syncSignatureFromServerUser(result.user);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(kAuthTokenPrefKey, result.token);
      await prefs.setString(
        kAuthUserJsonPrefKey,
        jsonEncode(result.user.toJson()),
      );

      state = AuthState(
        token: result.token,
        user: result.user,
        isLoading: false,
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Email atau Password salah',
      );
      return false;
    }
  }

  Future<void> _syncSignatureFromServerUser(SyncroUser user) async {
    final sigBytes = user.decodeSignatureBytes();
    if (sigBytes != null && sigBytes.isNotEmpty) {
      await _signatureRepository.saveSignature(sigBytes);
    }
  }

  Future<void> syncLocalSignatureToServer(Uint8List pngBytes) async {
    try {
      await _apiClient.uploadUserSignature(pngBytes);
    } catch (_) {
      // Tetap lanjut memakai tanda tangan lokal meskipun sinkronisasi jaringan tertunda.
    }
  }

  Future<void> logout() async {
    _apiClient.setAuthToken(null);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(kAuthTokenPrefKey);
    await prefs.remove(kAuthUserJsonPrefKey);
    state = const AuthState();
  }
}

final authControllerProvider =
    StateNotifierProvider<AuthController, AuthState>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  final sigRepo = ref.watch(savedSignatureRepositoryProvider);
  return AuthController(
    apiClient: apiClient,
    signatureRepository: sigRepo,
  );
});
