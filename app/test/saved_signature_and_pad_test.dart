import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myacrobat_app/src/features/signature/saved_signature_repository.dart';
import 'package:myacrobat_app/src/features/signature/signature_pad_sheet.dart';

void main() {
  group('SavedSignatureRepository & SignaturePadSheet (One-Tap Reuse)', () {
    testWidgets(
      '1. First-time draw opens SignaturePadSheet and auto-saves transparent PNG to repository',
      (tester) async {
        final storage = InMemorySignatureStorage();
        final repo = SavedSignatureRepository(storage: storage);
        Uint8List? resolvedBytes;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () async {
                    resolvedBytes = await resolveSignatureForPlacement(
                      context: context,
                      repo: repo,
                    );
                  },
                  child: const Text('Tanda Tangan'),
                ),
              ),
            ),
          ),
        );

        expect(await repo.hasSavedSignature(), isFalse);

        // Tap "Tanda Tangan" for the first time
        await tester.tap(find.text('Tanda Tangan'));
        await tester.pumpAndSettle();

        // Modal SignaturePadSheet should open
        expect(find.byType(SignaturePadSheet), findsOneWidget);
        expect(find.text('Hitam'), findsOneWidget);
        expect(find.text('Biru'), findsOneWidget);
        expect(find.text('Bersihkan'), findsOneWidget);
        expect(find.text('Gunakan Tanda Tangan'), findsOneWidget);

        // Draw a stroke on the signature canvas
        final canvasFinder = find.byKey(const Key('signature_pad_canvas'));
        expect(canvasFinder, findsOneWidget);
        await tester.drag(canvasFinder, const Offset(80, 30));
        await tester.pump();

        // Tap "Gunakan Tanda Tangan"
        await tester.tap(find.text('Gunakan Tanda Tangan'));
        await tester.pumpAndSettle();

        // Modal closes, bytes returned, and repository auto-saved the PNG
        expect(find.byType(SignaturePadSheet), findsNothing);
        expect(resolvedBytes, isNotNull);
        expect(resolvedBytes!.length, greaterThan(8));
        // PNG magic header: 0x89 0x50 0x4E 0x47
        expect(resolvedBytes!.sublist(0, 4), equals([0x89, 0x50, 0x4E, 0x47]));
        expect(await repo.hasSavedSignature(), isTrue);
        expect(await repo.loadSavedSignature(), equals(resolvedBytes));
      },
    );

    testWidgets(
      '2. Second call (forceRedraw: false) returns saved signature immediately without opening SignaturePadSheet',
      (tester) async {
        final presetPng = Uint8List.fromList([
          0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 1, 2, 3, 4,
        ]);
        final storage = InMemorySignatureStorage(initialBytes: presetPng);
        final repo = SavedSignatureRepository(storage: storage);
        Uint8List? resolvedBytes;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () async {
                    resolvedBytes = await resolveSignatureForPlacement(
                      context: context,
                      repo: repo,
                      forceRedraw: false,
                    );
                  },
                  child: const Text('Tanda Tangan'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Tanda Tangan'));
        await tester.pumpAndSettle();

        // Modal must NOT open (One-Tap Reuse)
        expect(find.byType(SignaturePadSheet), findsNothing);
        expect(resolvedBytes, equals(presetPng));
      },
    );

    testWidgets(
      '3. Calling with forceRedraw: true ("Gambar Ulang / Ganti TTD") opens SignaturePadSheet and overwrites saved signature',
      (tester) async {
        final oldPng = Uint8List.fromList([
          0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 9, 9, 9,
        ]);
        final storage = InMemorySignatureStorage(initialBytes: oldPng);
        final repo = SavedSignatureRepository(storage: storage);
        Uint8List? updatedBytes;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () async {
                    updatedBytes = await resolveSignatureForPlacement(
                      context: context,
                      repo: repo,
                      forceRedraw: true,
                    );
                  },
                  child: const Text('Ganti TTD'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Ganti TTD'));
        await tester.pumpAndSettle();

        // Modal opens even though a signature was already saved
        expect(find.byType(SignaturePadSheet), findsOneWidget);

        // Select "Biru" pen color, draw, clear, draw again, and save
        await tester.tap(find.text('Biru'));
        await tester.pump();

        final canvasFinder = find.byKey(const Key('signature_pad_canvas'));
        await tester.drag(canvasFinder, const Offset(60, 20));
        await tester.pump();

        await tester.tap(find.text('Bersihkan'));
        await tester.pump();

        await tester.drag(canvasFinder, const Offset(100, 40));
        await tester.pump();

        await tester.tap(find.text('Gunakan Tanda Tangan'));
        await tester.pumpAndSettle();

        expect(find.byType(SignaturePadSheet), findsNothing);
        expect(updatedBytes, isNotNull);
        expect(updatedBytes, isNot(equals(oldPng)));
        expect(await repo.loadSavedSignature(), equals(updatedBytes));
      },
    );

    test(
      '4. FileSignatureStorage persists and clears saved_signature.png on disk',
      () async {
        final tempDir = await Directory.systemTemp.createTemp('myacrobat_sig_');
        addTearDown(() async {
          if (await tempDir.exists()) {
            await tempDir.delete(recursive: true);
          }
        });

        final repo = SavedSignatureRepository(
          storage: FileSignatureStorage(directoryProvider: () async => tempDir),
        );
        final samplePng = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 1, 2, 3]);

        expect(await repo.hasSavedSignature(), isFalse);
        expect(await repo.loadSavedSignature(), isNull);

        await repo.saveSignature(samplePng);
        expect(await repo.hasSavedSignature(), isTrue);
        expect(await repo.loadSavedSignature(), equals(samplePng));

        await repo.clearSavedSignature();
        expect(await repo.hasSavedSignature(), isFalse);
        expect(await repo.loadSavedSignature(), isNull);
      },
    );
  });
}
