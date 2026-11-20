import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myacrobat_app/src/features/signature/saved_signature_repository.dart';
import 'package:myacrobat_app/src/features/viewer/pdf_signing_screen.dart';
import 'package:myacrobat_app/src/features/viewer/signature_placement_controller.dart';
import 'package:myacrobat_app/src/models/vault_pdf_file.dart';

void main() {
  group('SignaturePlacementController & Normalized Coordinates (0.0-1.0)', () {
    test(
      '1. Adding a signature on page 0 creates default placement within [0.0, 1.0]',
      () {
        final controller = SignaturePlacementController();
        final item = controller.addDefaultPlacement(pageIndex: 0);

        expect(item.id, isNotNull);
        expect(item.pageIndex, 0);
        expect(item.xRatio, closeTo(0.35, 1e-6));
        expect(item.yRatio, closeTo(0.45, 1e-6));
        expect(item.widthRatio, closeTo(0.30, 1e-6));
        expect(item.heightRatio, closeTo(0.10, 1e-6));
        expect(controller.placementsForPage(0), hasLength(1));
      },
    );

    test(
      '2. Dragging overlay by (+60px, +80px) on a 300x400 page container increases xRatio and yRatio by +0.20',
      () {
        final controller = SignaturePlacementController();
        final initial = controller.addDefaultPlacement(pageIndex: 0);

        final updated = applyDragDelta(
          placement: initial,
          dx: 60.0,
          dy: 80.0,
          pageRenderWidth: 300.0,
          pageRenderHeight: 400.0,
        );

        expect(updated.xRatio, closeTo(0.55, 1e-6));
        expect(updated.yRatio, closeTo(0.65, 1e-6));
        expect(updated.widthRatio, closeTo(0.30, 1e-6));
        expect(updated.heightRatio, closeTo(0.10, 1e-6));
      },
    );

    test(
      '3. Dragging overlay beyond page edges clamps ratios so xRatio + widthRatio <= 1.0 and yRatio + heightRatio <= 1.0',
      () {
        final controller = SignaturePlacementController();
        final initial = controller.addDefaultPlacement(pageIndex: 0);

        final clampedBottomRight = applyDragDelta(
          placement: initial,
          dx: 500.0,
          dy: 500.0,
          pageRenderWidth: 300.0,
          pageRenderHeight: 400.0,
        );
        expect(
          clampedBottomRight.xRatio + clampedBottomRight.widthRatio,
          closeTo(1.0, 1e-6),
        );
        expect(
          clampedBottomRight.yRatio + clampedBottomRight.heightRatio,
          closeTo(1.0, 1e-6),
        );

        final clampedTopLeft = applyDragDelta(
          placement: initial,
          dx: -500.0,
          dy: -500.0,
          pageRenderWidth: 300.0,
          pageRenderHeight: 400.0,
        );
        expect(clampedTopLeft.xRatio, closeTo(0.0, 1e-6));
        expect(clampedTopLeft.yRatio, closeTo(0.0, 1e-6));
      },
    );

    test(
      '4. Resizing via corner handle updates widthRatio and heightRatio proportionally with safe minimum bounds',
      () {
        final controller = SignaturePlacementController();
        final initial = controller.addDefaultPlacement(pageIndex: 0);
        final initialAspect = initial.heightRatio / initial.widthRatio;

        final grown = applyResizeDelta(
          placement: initial,
          dx: 45.0, // +0.15 widthRatio on 300px wide page
          dy: 20.0,
          pageRenderWidth: 300.0,
          pageRenderHeight: 400.0,
        );
        expect(grown.widthRatio, closeTo(0.45, 1e-6));
        expect(grown.heightRatio / grown.widthRatio, closeTo(initialAspect, 1e-4));
        expect(grown.xRatio + grown.widthRatio, lessThanOrEqualTo(1.0));
        expect(grown.yRatio + grown.heightRatio, lessThanOrEqualTo(1.0));

        final shrunk = applyResizeDelta(
          placement: initial,
          dx: -500.0,
          dy: -500.0,
          pageRenderWidth: 300.0,
          pageRenderHeight: 400.0,
        );
        expect(shrunk.widthRatio, greaterThanOrEqualTo(0.08));
        expect(shrunk.heightRatio, greaterThanOrEqualTo(0.02));
      },
    );

    testWidgets(
      '5. User can place signatures on page 0 and page 1 in one session and delete one overlay with × button',
      (tester) async {
        final presetPng = Uint8List.fromList([
          // Minimal 1x1 transparent PNG
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
        final storage = InMemorySignatureStorage(initialBytes: presetPng);
        final repo = SavedSignatureRepository(storage: storage);
        final doc = VaultPdfFile(
          fileId: 'doc-1',
          name: 'Kontrak.pdf',
          size: 24000,
          updatedAt: DateTime.utc(2026, 2, 18),
          isSigned: false,
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              savedSignatureRepositoryProvider.overrideWithValue(repo),
            ],
            child: MaterialApp(
              home: PdfSigningScreen(
                document: doc,
                initialPageCount: 2,
                pdfBytesLoader: (_) async => Uint8List.fromList([0x25, 0x50, 0x44, 0x46]),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Halaman 1 dari 2'), findsOneWidget);
        expect(find.text('Bubuhkan Tanda Tangan'), findsOneWidget);
        expect(find.text('Ganti TTD'), findsOneWidget);

        // Place signature on page 0 (Halaman 1)
        await tester.tap(find.text('Bubuhkan Tanda Tangan'));
        await tester.pumpAndSettle();

        expect(find.byType(DraggableSignatureOverlay), findsOneWidget);

        // Navigate to page 1 (Halaman 2)
        await tester.tap(find.byKey(const Key('next_page_button')));
        await tester.pumpAndSettle();

        expect(find.text('Halaman 2 dari 2'), findsOneWidget);
        // Page 1 has no signature yet
        expect(find.byType(DraggableSignatureOverlay), findsNothing);

        // Place two signatures on page 1
        await tester.tap(find.text('Bubuhkan Tanda Tangan'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Bubuhkan Tanda Tangan'));
        await tester.pumpAndSettle();

        expect(find.byType(DraggableSignatureOverlay), findsNWidgets(2));

        // Delete the topmost overlay on page 1 using its × button
        await tester.tap(find.byKey(const Key('delete_signature_overlay')).last);
        await tester.pumpAndSettle();

        expect(find.byType(DraggableSignatureOverlay), findsOneWidget);
      },
    );
  });
}
