import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myacrobat_app/src/api/myacrobat_api_client.dart';
import 'package:myacrobat_app/src/features/files/document_list_provider.dart';
import 'package:myacrobat_app/src/features/signature/saved_signature_repository.dart';
import 'package:myacrobat_app/src/features/viewer/pdf_signing_screen.dart';
import 'package:myacrobat_app/src/models/sign_document_result.dart';
import 'package:myacrobat_app/src/models/signature_placement.dart';
import 'package:myacrobat_app/src/models/vault_pdf_file.dart';

class _FakeSigningApiClient extends MyAcrobatApiClient {
  int fetchFilesCalls = 0;
  int signCalls = 0;
  String? lastSignedFileId;
  Uint8List? lastSignatureBytes;
  List<SignaturePlacement>? lastPlacements;
  bool shouldFailSign = false;

  final List<VaultPdfFile> _files = [
    VaultPdfFile(
      fileId: 'doc-1',
      name: 'Kontrak.pdf',
      size: 24000,
      updatedAt: DateTime.utc(2026, 2, 18),
      isSigned: false,
    ),
  ];

  @override
  Future<List<VaultPdfFile>> fetchFiles({String? search}) async {
    fetchFilesCalls++;
    return List.unmodifiable(_files);
  }

  @override
  Future<Uint8List> downloadPdfBytes(String fileId) async {
    return Uint8List.fromList([0x25, 0x50, 0x44, 0x46]);
  }

  @override
  Future<SignDocumentResult> signDocument({
    required String fileId,
    required Uint8List signaturePngBytes,
    required List<SignaturePlacement> placements,
  }) async {
    signCalls++;
    lastSignedFileId = fileId;
    lastSignatureBytes = signaturePngBytes;
    lastPlacements = List.unmodifiable(placements);

    if (shouldFailSign) {
      throw Exception('Koneksi ke Mega.nz terputus');
    }

    final signedFile = VaultPdfFile(
      fileId: 'doc-1-signed',
      name: 'Kontrak_signed.pdf',
      size: 29500,
      updatedAt: DateTime.utc(2026, 2, 18, 12),
      isSigned: true,
    );
    _files.add(signedFile);

    return SignDocumentResult(
      message: 'Dokumen berhasil ditandatangani dan diunggah ke Mega.nz.',
      sourceFileId: fileId,
      signedFile: signedFile,
    );
  }
}

void main() {
  final presetPng = Uint8List.fromList([
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
    0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
    0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
    0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
    0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41,
    0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
    0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
    0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
    0x42, 0x60, 0x82,
  ]);

  final sourceDoc = VaultPdfFile(
    fileId: 'doc-1',
    name: 'Kontrak.pdf',
    size: 24000,
    updatedAt: DateTime.utc(2026, 2, 18),
    isSigned: false,
  );

  group('Save Signed Document Flow (_signed.pdf)', () {
    testWidgets(
      '1. "Simpan Dokumen" button is disabled before placing a signature and enabled once 1 signature is placed',
      (tester) async {
        final fakeApi = _FakeSigningApiClient();
        final repo = SavedSignatureRepository(
          storage: InMemorySignatureStorage(initialBytes: presetPng),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              apiClientProvider.overrideWithValue(fakeApi),
              savedSignatureRepositoryProvider.overrideWithValue(repo),
            ],
            child: MaterialApp(
              home: PdfSigningScreen(
                document: sourceDoc,
                initialPageCount: 1,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final saveBtnFinder = find.byKey(const Key('save_signed_document_button'));
        expect(saveBtnFinder, findsOneWidget);

        final disabledBtn = tester.widget<ButtonStyleButton>(saveBtnFinder);
        expect(disabledBtn.onPressed, isNull);

        // Place 1 signature
        await tester.tap(find.text('Sign'));
        await tester.pumpAndSettle();

        final enabledBtn = tester.widget<ButtonStyleButton>(saveBtnFinder);
        expect(enabledBtn.onPressed, isNotNull);
      },
    );

    testWidgets(
      '2. Pressing "Simpan Dokumen" calls signDocument(), refreshes documentListProvider, and shows confirmation dialog with Kontrak_signed.pdf',
      (tester) async {
        final fakeApi = _FakeSigningApiClient();
        final repo = SavedSignatureRepository(
          storage: InMemorySignatureStorage(initialBytes: presetPng),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              apiClientProvider.overrideWithValue(fakeApi),
              savedSignatureRepositoryProvider.overrideWithValue(repo),
            ],
            child: MaterialApp(
              home: PdfSigningScreen(
                document: sourceDoc,
                initialPageCount: 1,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Sign'));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('save_signed_document_button')));
        await tester.pumpAndSettle();

        expect(fakeApi.signCalls, 1);
        expect(fakeApi.lastSignedFileId, 'doc-1');
        expect(fakeApi.lastSignatureBytes, equals(presetPng));
        expect(fakeApi.lastPlacements, hasLength(1));
        expect(fakeApi.fetchFilesCalls, greaterThanOrEqualTo(1));

        // Success dialog displays the new _signed.pdf name and action buttons
        expect(find.textContaining('Kontrak_signed.pdf'), findsWidgets);
        expect(find.text('Export PDF'), findsWidgets);
        expect(find.text('Buka File _signed.pdf'), findsOneWidget);
        expect(find.text('Kembali ke Daftar Dokumen'), findsOneWidget);
      },
    );

    testWidgets(
      '3. When server returns error on save, error feedback is shown and signature overlay remains intact on page for retry',
      (tester) async {
        final fakeApi = _FakeSigningApiClient()..shouldFailSign = true;
        final repo = SavedSignatureRepository(
          storage: InMemorySignatureStorage(initialBytes: presetPng),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              apiClientProvider.overrideWithValue(fakeApi),
              savedSignatureRepositoryProvider.overrideWithValue(repo),
            ],
            child: MaterialApp(
              home: PdfSigningScreen(
                document: sourceDoc,
                initialPageCount: 1,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Sign'));
        await tester.pumpAndSettle();
        expect(find.byType(DraggableSignatureOverlay), findsOneWidget);

        await tester.tap(find.byKey(const Key('save_signed_document_button')));
        await tester.pumpAndSettle();

        expect(fakeApi.signCalls, 1);
        expect(find.textContaining('Gagal menyimpan dokumen'), findsOneWidget);
        // Overlay must NOT be lost!
        expect(find.byType(DraggableSignatureOverlay), findsOneWidget);
      },
    );
  });
}
