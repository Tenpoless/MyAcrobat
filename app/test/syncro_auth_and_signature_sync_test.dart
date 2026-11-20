import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myacrobat_app/src/api/myacrobat_api_client.dart';
import 'package:myacrobat_app/src/features/auth/auth_controller.dart';
import 'package:myacrobat_app/src/features/auth/login_screen.dart';
import 'package:myacrobat_app/src/features/files/document_list_provider.dart';
import 'package:myacrobat_app/src/features/signature/saved_signature_repository.dart';
import 'package:myacrobat_app/src/features/viewer/pdf_signing_screen.dart';
import 'package:myacrobat_app/src/models/sign_document_result.dart';
import 'package:myacrobat_app/src/models/signature_placement.dart';
import 'package:myacrobat_app/src/models/syncro_user.dart';
import 'package:myacrobat_app/src/models/vault_pdf_file.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _kSamplePngBase64 =
    'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGP4z8DwHwAFAAH/iZk9HQAAAABJRU5ErkJggg==';

final Uint8List _kSamplePngBytes = base64Decode(
  _kSamplePngBase64.replaceFirst('data:image/png;base64,', ''),
);

class _FakeSyncroApiClient extends MyAcrobatApiClient {
  _FakeSyncroApiClient({
    required this.onLogin,
  });

  final Future<AuthLoginResult> Function(String identifier, String password)
      onLogin;

  String? appliedAuthToken;
  Uint8List? uploadedSignatureBytes;
  int uploadSignatureCallCount = 0;

  @override
  void setAuthToken(String? token) {
    appliedAuthToken = token;
    super.setAuthToken(token);
  }

  @override
  Future<AuthLoginResult> login({
    required String identifier,
    required String password,
  }) {
    return onLogin(identifier, password);
  }

  @override
  Future<void> uploadUserSignature(Uint8List pngBytes) async {
    uploadSignatureCallCount += 1;
    uploadedSignatureBytes = Uint8List.fromList(pngBytes);
  }

  @override
  Future<List<VaultPdfFile>> fetchFiles({String? search}) async {
    return <VaultPdfFile>[
      VaultPdfFile(
        fileId: 'doc-1',
        name: 'SOP_Keuangan.pdf',
        size: 120000,
        updatedAt: DateTime.parse('2026-11-20T03:00:00.000Z'),
        isSigned: false,
      ),
    ];
  }

  @override
  Future<Uint8List> downloadPdfBytes(String fileId) async {
    return Uint8List.fromList('/Type /Page'.codeUnits);
  }

  @override
  Future<SignDocumentResult> signDocument({
    required String fileId,
    required Uint8List signaturePngBytes,
    required List<SignaturePlacement> placements,
  }) {
    throw UnimplementedError();
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('Ticket 13: Syncro ERP Login, Role Guard, & Two-Way Signature Sync', () {
    testWidgets(
      '1. Login with valid NIK & password saves user session and pre-populates SavedSignatureRepository from Syncro signature_path without opening SignaturePadSheet',
      (tester) async {
        final sigRepo = SavedSignatureRepository(
          storage: InMemorySignatureStorage(),
        );
        final fakeClient = _FakeSyncroApiClient(
          onLogin: (identifier, password) async {
            expect(identifier, 'EMP-101');
            expect(password, 'secret123');
            return const AuthLoginResult(
              token: 'syncro-token-101',
              user: SyncroUser(
                id: 101,
                name: 'Budi Santoso',
                username: 'EMP-101',
                email: 'budi@syncro.co.id',
                position: 'Manager Operasional',
                role: 'signer',
                hasSavedSignature: true,
                signatureImageBase64: _kSamplePngBase64,
              ),
            );
          },
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              apiClientProvider.overrideWithValue(fakeClient),
              savedSignatureRepositoryProvider.overrideWithValue(sigRepo),
            ],
            child: const MaterialApp(
              home: LoginScreen(),
            ),
          ),
        );

        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const Key('login_identifier_input')),
          'EMP-101',
        );
        await tester.enterText(
          find.byKey(const Key('login_password_input')),
          'secret123',
        );
        await tester.tap(find.byKey(const Key('login_submit_button')));
        await tester.pumpAndSettle();

        expect(fakeClient.appliedAuthToken, 'syncro-token-101');
        expect(await sigRepo.hasSavedSignature(), isTrue);
        final savedBytes = await sigRepo.loadSavedSignature();
        expect(savedBytes, equals(_kSamplePngBytes));

        // DocumentListScreen should now be visible with user profile info
        expect(find.textContaining('Budi Santoso'), findsOneWidget);
        expect(find.text('SOP_Keuangan.pdf'), findsOneWidget);
      },
    );

    testWidgets(
      '2. When user without existing signature draws in SignaturePadSheet, app saves locally and calls PUT /api/me/signature to sync with syncro_erp',
      (tester) async {
        final sigRepo = SavedSignatureRepository(
          storage: InMemorySignatureStorage(),
        );
        final fakeClient = _FakeSyncroApiClient(
          onLogin: (identifier, password) async {
            return const AuthLoginResult(
              token: 'syncro-token-202',
              user: SyncroUser(
                id: 202,
                name: 'Siti Rahma',
                username: 'EMP-202',
                email: 'siti@syncro.co.id',
                position: 'Supervisor',
                role: 'signer',
                hasSavedSignature: false,
                signatureImageBase64: null,
              ),
            );
          },
        );

        final doc = VaultPdfFile(
          fileId: 'doc-1',
          name: 'SOP_Keuangan.pdf',
          size: 120000,
          updatedAt: DateTime.parse('2026-11-20T03:00:00.000Z'),
          isSigned: false,
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              apiClientProvider.overrideWithValue(fakeClient),
              savedSignatureRepositoryProvider.overrideWithValue(sigRepo),
            ],
            child: MaterialApp(
              home: PdfSigningScreen(
                document: doc,
                initialPageCount: 1,
                pdfBytesLoader: (_) async =>
                    Uint8List.fromList('/Type /Page'.codeUnits),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Tap "Bubuhkan Tanda Tangan" -> since no saved signature, opens SignaturePadSheet
        await tester.tap(find.text('Bubuhkan Tanda Tangan'));
        await tester.pumpAndSettle();

        expect(find.text('Buat Tanda Tangan'), findsOneWidget);

        // Draw a stroke on the signature canvas
        final canvasFinder = find.byKey(const Key('signature_pad_canvas'));
        await tester.drag(canvasFinder, const Offset(60, 25));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Gunakan Tanda Tangan'));
        await tester.pumpAndSettle();

        expect(await sigRepo.hasSavedSignature(), isTrue);
        expect(fakeClient.uploadSignatureCallCount, 1);
        expect(fakeClient.uploadedSignatureBytes, isNotNull);
        expect(fakeClient.uploadedSignatureBytes!.length, greaterThan(8));
      },
    );

    testWidgets(
      '3. Role guard: viewer sees read-only indicator and cannot tap "Bubuhkan Tanda Tangan", while signer/admin has active signing controls',
      (tester) async {
        final sigRepo = SavedSignatureRepository(
          storage: InMemorySignatureStorage(initialBytes: _kSamplePngBytes),
        );
        final fakeClient = _FakeSyncroApiClient(
          onLogin: (_, _) => throw UnimplementedError(),
        );

        final doc = VaultPdfFile(
          fileId: 'doc-1',
          name: 'SOP_Keuangan.pdf',
          size: 120000,
          updatedAt: DateTime.parse('2026-11-20T03:00:00.000Z'),
          isSigned: false,
        );

        const viewerUser = SyncroUser(
          id: 301,
          name: 'Auditor Viewer',
          username: 'EMP-301',
          email: 'viewer@syncro.co.id',
          position: 'Internal Audit',
          role: 'viewer',
          hasSavedSignature: false,
          signatureImageBase64: null,
        );

        await tester.pumpWidget(
          ProviderScope(
            key: const ValueKey('viewer_scope'),
            overrides: [
              apiClientProvider.overrideWithValue(fakeClient),
              savedSignatureRepositoryProvider.overrideWithValue(sigRepo),
              authControllerProvider.overrideWith(
                (ref) => AuthController(
                  apiClient: fakeClient,
                  signatureRepository: sigRepo,
                  initialState: const AuthState(
                    token: 'viewer-token',
                    user: viewerUser,
                  ),
                ),
              ),
            ],
            child: MaterialApp(
              home: PdfSigningScreen(
                document: doc,
                initialPageCount: 1,
                pdfBytesLoader: (_) async =>
                    Uint8List.fromList('/Type /Page'.codeUnits),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.textContaining('Mode Baca (Viewer)'), findsOneWidget);
        expect(find.text('Bubuhkan Tanda Tangan'), findsNothing);

        // Now test with admin/signer role
        const adminUser = SyncroUser(
          id: 302,
          name: 'Admin Legal',
          username: 'EMP-302',
          email: 'admin@syncro.co.id',
          position: 'Head of Legal',
          role: 'admin',
          hasSavedSignature: true,
          signatureImageBase64: _kSamplePngBase64,
        );

        await tester.pumpWidget(
          ProviderScope(
            key: const ValueKey('admin_scope'),
            overrides: [
              apiClientProvider.overrideWithValue(fakeClient),
              savedSignatureRepositoryProvider.overrideWithValue(sigRepo),
              authControllerProvider.overrideWith(
                (ref) => AuthController(
                  apiClient: fakeClient,
                  signatureRepository: sigRepo,
                  initialState: const AuthState(
                    token: 'admin-token',
                    user: adminUser,
                  ),
                ),
              ),
            ],
            child: MaterialApp(
              home: PdfSigningScreen(
                document: doc,
                initialPageCount: 1,
                pdfBytesLoader: (_) async =>
                    Uint8List.fromList('/Type /Page'.codeUnits),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.text('Bubuhkan Tanda Tangan'), findsOneWidget);
        expect(find.text('Simpan Dokumen'), findsOneWidget);
      },
    );
  });
}
