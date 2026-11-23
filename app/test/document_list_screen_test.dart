import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myacrobat_app/src/api/myacrobat_api_client.dart';
import 'package:myacrobat_app/src/features/files/document_list_provider.dart';
import 'package:myacrobat_app/src/features/files/document_list_screen.dart';
import 'package:myacrobat_app/src/models/sign_document_result.dart';
import 'package:myacrobat_app/src/models/signature_placement.dart';
import 'package:myacrobat_app/src/models/vault_pdf_file.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeApiClient extends MyAcrobatApiClient {
  _FakeApiClient(this._handler);

  final Future<List<VaultPdfFile>> Function({String? search}) _handler;
  int fetchCount = 0;

  @override
  Future<List<VaultPdfFile>> fetchFiles({String? search}) async {
    fetchCount += 1;
    return _handler(search: search);
  }

  @override
  Future<Uint8List> downloadPdfBytes(String fileId) async => Uint8List(0);

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

  final sampleFiles = <VaultPdfFile>[
    VaultPdfFile(
      fileId: 'file-1',
      name: 'Surat_Perjanjian.pdf',
      size: 245760,
      updatedAt: DateTime.parse('2026-11-20T02:00:00.000Z'),
      isSigned: false,
    ),
    VaultPdfFile(
      fileId: 'file-2',
      name: 'Surat_Perjanjian_signed.pdf',
      size: 256000,
      updatedAt: DateTime.parse('2026-11-20T02:15:00.000Z'),
      isSigned: true,
    ),
    VaultPdfFile(
      fileId: 'file-3',
      name: 'Memo_Internal.pdf',
      size: 102400,
      updatedAt: DateTime.parse('2026-11-20T01:00:00.000Z'),
      isSigned: false,
    ),
  ];

  testWidgets(
    'displays loaded PDF files, SIGNED badge on signed file, and counterpart indicator on source file',
    (tester) async {
      final fakeClient = _FakeApiClient(({search}) async => sampleFiles);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            apiClientProvider.overrideWithValue(fakeClient),
          ],
          child: const MaterialApp(
            home: DocumentListScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('AgriSign'), findsOneWidget);
      expect(find.textContaining('MyAcrobat'), findsNothing);

      expect(find.text('Surat_Perjanjian.pdf'), findsOneWidget);
      expect(find.text('Surat_Perjanjian_signed.pdf'), findsOneWidget);
      expect(find.text('Memo_Internal.pdf'), findsOneWidget);

      expect(find.text('SIGNED'), findsOneWidget);
      expect(find.text('Sudah Ada Versi _signed'), findsOneWidget);
      expect(find.textContaining('240 KB'), findsOneWidget);
    },
  );

  testWidgets(
    'filters document list in real-time when typing in search box',
    (tester) async {
      final fakeClient = _FakeApiClient(({search}) async => sampleFiles);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            apiClientProvider.overrideWithValue(fakeClient),
          ],
          child: const MaterialApp(
            home: DocumentListScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextField),
        'Memo',
      );
      await tester.pumpAndSettle();

      expect(find.text('Memo_Internal.pdf'), findsOneWidget);
      expect(find.text('Surat_Perjanjian.pdf'), findsNothing);
      expect(find.text('Surat_Perjanjian_signed.pdf'), findsNothing);
    },
  );

  testWidgets(
    'shows error state and retries when "Coba Lagi" button is pressed',
    (tester) async {
      var shouldFail = true;
      final fakeClient = _FakeApiClient(({search}) async {
        if (shouldFail) {
          throw Exception('Koneksi ke server Mega.nz terputus');
        }
        return sampleFiles;
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            apiClientProvider.overrideWithValue(fakeClient),
          ],
          child: const MaterialApp(
            home: DocumentListScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Coba Lagi'), findsOneWidget);
      expect(fakeClient.fetchCount, 1);

      shouldFail = false;
      await tester.tap(find.text('Coba Lagi'));
      await tester.pumpAndSettle();

      expect(fakeClient.fetchCount, 2);
      expect(find.text('Surat_Perjanjian.pdf'), findsOneWidget);
    },
  );

  testWidgets(
    'does not render office server settings button in AppBar',
    (tester) async {
      final fakeClient = _FakeApiClient(({search}) async => sampleFiles);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            apiClientProvider.overrideWithValue(fakeClient),
          ],
          child: const MaterialApp(
            home: DocumentListScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(fakeClient.fetchCount, 1);
      expect(
        find.byKey(const Key('office_server_settings_button')),
        findsNothing,
      );
    },
  );
}
