import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';

import '../../models/signature_placement.dart';
import '../../models/vault_pdf_file.dart';
import '../auth/auth_controller.dart';
import '../files/document_list_provider.dart';
import '../signature/saved_signature_repository.dart';
import '../signature/signature_pad_sheet.dart';
import 'signature_placement_controller.dart';

class PdfSigningScreen extends ConsumerStatefulWidget {
  final VaultPdfFile document;
  final int? initialPageCount;
  final Future<Uint8List> Function(String fileId)? pdfBytesLoader;
  final Future<Uint8List?> Function(Uint8List pdfBytes, int pageIndex)?
      pdfPageRenderer;
  final Future<void> Function(Uint8List pdfBytes, String fileName)? pdfExporter;
  final SignaturePlacementController? placementController;

  const PdfSigningScreen({
    super.key,
    required this.document,
    this.initialPageCount,
    this.pdfBytesLoader,
    this.pdfPageRenderer,
    this.pdfExporter,
    this.placementController,
  });

  @override
  ConsumerState<PdfSigningScreen> createState() => _PdfSigningScreenState();
}

class _PdfSigningScreenState extends ConsumerState<PdfSigningScreen> {
  late final SignaturePlacementController _controller;
  late final bool _ownsController;

  Uint8List? _pdfBytes;
  final Map<int, Uint8List> _renderedPages = <int, Uint8List>{};
  final Map<int, double> _pageAspectRatios = <int, double>{};
  final Set<int> _renderingPages = <int>{};
  Uint8List? _signatureBytes;
  bool _isLoadingPdf = true;
  bool _isSaving = false;
  bool _isExporting = false;
  String? _loadError;
  int _pageCount = 1;
  int _currentPageIndex = 0;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.placementController == null;
    _controller = widget.placementController ?? SignaturePlacementController();
    _controller.addListener(_onPlacementsChanged);
    _pageCount = widget.initialPageCount ?? 1;
    _loadInitialState();
  }

  @override
  void dispose() {
    _controller.removeListener(_onPlacementsChanged);
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  void _onPlacementsChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _loadInitialState() async {
    setState(() {
      _isLoadingPdf = true;
      _loadError = null;
    });

    try {
      final repo = ref.read(savedSignatureRepositoryProvider);
      final savedSig = await repo.loadSavedSignature();

      final loader = widget.pdfBytesLoader ??
          (String id) => ref.read(apiClientProvider).downloadPdfBytes(id);
      final pdfBytes = await loader(widget.document.fileId);

      final detectedPages =
          widget.initialPageCount ?? _detectPdfPageCount(pdfBytes);

      if (!mounted) return;
      setState(() {
        _signatureBytes = savedSig;
        _pdfBytes = pdfBytes;
        _renderedPages.clear();
        _pageAspectRatios.clear();
        _renderingPages.clear();
        _pageCount = detectedPages < 1 ? 1 : detectedPages;
        _currentPageIndex = 0;
        _isLoadingPdf = false;
      });
      await _renderPageIfNeeded(0);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e.toString();
        _isLoadingPdf = false;
      });
    }
  }

  int _detectPdfPageCount(Uint8List bytes) {
    try {
      final text = latin1.decode(bytes, allowInvalid: true);
      final matches = RegExp(r'/Type\s*/Page\b').allMatches(text).length;
      return matches > 0 ? matches : 1;
    } catch (_) {
      return 1;
    }
  }

  Future<void> _handleAddSignature() async {
    final repo = ref.read(savedSignatureRepositoryProvider);
    final authNotifier = ref.read(authControllerProvider.notifier);
    final bytes = await resolveSignatureForPlacement(
      context: context,
      repo: repo,
      forceRedraw: false,
      onNewSignatureSaved: authNotifier.syncLocalSignatureToServer,
    );
    if (bytes == null || bytes.isEmpty || !mounted) return;

    setState(() {
      _signatureBytes = bytes;
    });
    _controller.addDefaultPlacement(pageIndex: _currentPageIndex);
  }

  Future<void> _handleRedrawSignature() async {
    final repo = ref.read(savedSignatureRepositoryProvider);
    final authNotifier = ref.read(authControllerProvider.notifier);
    final bytes = await resolveSignatureForPlacement(
      context: context,
      repo: repo,
      forceRedraw: true,
      onNewSignatureSaved: authNotifier.syncLocalSignatureToServer,
    );
    if (bytes == null || bytes.isEmpty || !mounted) return;

    setState(() {
      _signatureBytes = bytes;
    });
  }

  Future<void> _exportPdfBytes({
    required Uint8List bytes,
    required String fileName,
  }) async {
    if (_isExporting || bytes.isEmpty) return;
    setState(() => _isExporting = true);
    try {
      if (widget.pdfExporter != null) {
        await widget.pdfExporter!(bytes, fileName);
      } else {
        await Printing.sharePdf(bytes: bytes, filename: fileName);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF0F172A),
          content: Text('Gagal mengekspor PDF: $e'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  Future<void> _handleExportCurrentPdf() async {
    final bytes = _pdfBytes;
    if (bytes == null || bytes.isEmpty) return;
    await _exportPdfBytes(bytes: bytes, fileName: widget.document.name);
  }

  Future<void> _handleExportSignedFile(VaultPdfFile signedFile) async {
    if (_isExporting) return;
    try {
      final loader = widget.pdfBytesLoader ??
          (String id) => ref.read(apiClientProvider).downloadPdfBytes(id);
      final signedBytes = await loader(signedFile.fileId);
      await _exportPdfBytes(bytes: signedBytes, fileName: signedFile.name);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF0F172A),
          content: Text('Gagal mengunduh PDF untuk diekspor: $e'),
        ),
      );
    }
  }

  Future<void> _handleSaveSignedDocument() async {
    final placements = _controller.placements;
    final signatureBytes = _signatureBytes;
    if (_isSaving ||
        placements.isEmpty ||
        signatureBytes == null ||
        signatureBytes.isEmpty) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final api = ref.read(apiClientProvider);
      final result = await api.signDocument(
        fileId: widget.document.fileId,
        signaturePngBytes: signatureBytes,
        placements: placements,
      );

      await ref.read(documentListProvider.notifier).refresh();

      if (!mounted) return;
      setState(() {
        _isSaving = false;
      });

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          title: const Text(
            'Dokumen Berhasil Disimpan',
            style: TextStyle(
              color: Color(0xFF0F172A),
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          content: Text(
            'File baru ${result.signedFile.name} telah disimpan ke Mega.nz.',
            style: const TextStyle(
              color: Color(0xFF475569),
              fontSize: 14,
            ),
          ),
          actions: [
            OutlinedButton.icon(
              key: const Key('export_signed_pdf_dialog_button'),
              onPressed: () {
                _handleExportSignedFile(result.signedFile);
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF0F172A),
                side: const BorderSide(color: Color(0xFFCBD5E1)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              icon: const Icon(Icons.ios_share_outlined, size: 16),
              label: const Text('Export PDF'),
            ),
            OutlinedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                }
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF0F172A),
                side: const BorderSide(color: Color(0xFFCBD5E1)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              child: const Text('Kembali ke Daftar Dokumen'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        PdfSigningScreen(document: result.signedFile),
                  ),
                );
              },
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFB91C1C),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              child: const Text('Buka File _signed.pdf'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
      });
      final errorMsg = (e is DioException &&
              e.response?.data is Map &&
              (e.response?.data as Map)['error'] != null)
          ? (e.response?.data as Map)['error'].toString()
          : e.toString();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF0F172A),
          content: Text('Gagal menyimpan dokumen: $errorMsg'),
          action: SnackBarAction(
            label: 'Coba Simpan Lagi',
            textColor: const Color(0xFFFCA5A5),
            onPressed: _handleSaveSignedDocument,
          ),
        ),
      );
    }
  }

  Future<void> _renderPageIfNeeded(int pageIndex) async {
    final pdfBytes = _pdfBytes;
    if (pdfBytes == null ||
        pdfBytes.isEmpty ||
        _renderedPages.containsKey(pageIndex) ||
        _renderingPages.contains(pageIndex)) {
      return;
    }

    _renderingPages.add(pageIndex);
    try {
      if (widget.pdfPageRenderer != null) {
        final customBytes = await widget.pdfPageRenderer!(pdfBytes, pageIndex);
        if (customBytes != null && customBytes.isNotEmpty && mounted) {
          setState(() {
            _renderedPages[pageIndex] = customBytes;
          });
        }
        return;
      }

      final hasPdfHeader = pdfBytes.length >= 5 &&
          pdfBytes[0] == 0x25 &&
          pdfBytes[1] == 0x50 &&
          pdfBytes[2] == 0x44 &&
          pdfBytes[3] == 0x46 &&
          pdfBytes[4] == 0x2D;
      if (!hasPdfHeader) {
        return;
      }

      await for (final page in Printing.raster(
        pdfBytes,
        pages: <int>[pageIndex],
        dpi: 144,
      )) {
        final pngBytes = await page.toPng();
        if (!mounted) return;
        setState(() {
          _renderedPages[pageIndex] = pngBytes;
          if (page.height > 0) {
            _pageAspectRatios[pageIndex] = page.width / page.height;
          }
        });
        break;
      }
    } catch (_) {
      // Fallback to text metadata preview when native PDF rasterizer is unavailable
    } finally {
      _renderingPages.remove(pageIndex);
    }
  }

  Widget _buildPdfViewerArea({
    required BuildContext context,
    required List<SignaturePlacement> pagePlacements,
  }) {
    final renderedPageBytes = _renderedPages[_currentPageIndex];
    final pageAspectRatio =
        _pageAspectRatios[_currentPageIndex] ?? (1 / 1.4142);

    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                key: const Key('prev_page_button'),
                tooltip: 'Halaman sebelumnya',
                onPressed: _currentPageIndex > 0
                    ? () {
                        final nextIndex = _currentPageIndex - 1;
                        setState(() => _currentPageIndex = nextIndex);
                        _renderPageIfNeeded(nextIndex);
                      }
                    : null,
                icon: const Icon(Icons.chevron_left),
                color: const Color(0xFF0F172A),
              ),
              const SizedBox(width: 8),
              Text(
                'Halaman ${_currentPageIndex + 1} dari $_pageCount',
                style: const TextStyle(
                  color: Color(0xFF0F172A),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                key: const Key('next_page_button'),
                tooltip: 'Halaman berikutnya',
                onPressed: _currentPageIndex + 1 < _pageCount
                    ? () {
                        final nextIndex = _currentPageIndex + 1;
                        setState(() => _currentPageIndex = nextIndex);
                        _renderPageIfNeeded(nextIndex);
                      }
                    : null,
                icon: const Icon(Icons.chevron_right),
                color: const Color(0xFF0F172A),
              ),
            ],
          ),
        ),
        const Divider(
          height: 1,
          thickness: 1,
          color: Color(0xFFE2E8F0),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: AspectRatio(
                aspectRatio: pageAspectRatio,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final pageWidth = constraints.maxWidth;
                    final pageHeight = constraints.maxHeight;

                    return Container(
                      key: const Key('pdf_page_canvas'),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: const Color(0xFFCBD5E1),
                        ),
                      ),
                      child: Stack(
                        clipBehavior: Clip.hardEdge,
                        children: [
                          if (renderedPageBytes != null)
                            Positioned.fill(
                              child: Image.memory(
                                renderedPageBytes,
                                key: ValueKey(
                                  'pdf_rendered_page_${widget.document.fileId}_$_currentPageIndex',
                                ),
                                fit: BoxFit.fill,
                              ),
                            )
                          else
                            Positioned.fill(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      widget.document.name,
                                      style: const TextStyle(
                                        color: Color(0xFF475569),
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Pratinjau Halaman ${_currentPageIndex + 1} (${_pdfBytes?.length ?? 0} B)',
                                      style: const TextStyle(
                                        color: Color(0xFF64748B),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          for (final placement in pagePlacements)
                            DraggableSignatureOverlay(
                              key: ValueKey(
                                placement.id ??
                                    '${placement.pageIndex}_${placement.xRatio}_${placement.yRatio}',
                              ),
                              placement: placement,
                              pageWidth: pageWidth,
                              pageHeight: pageHeight,
                              signatureBytes: _signatureBytes,
                              onDragDelta: (delta) {
                                if (placement.id == null) return;
                                _controller.dragPlacement(
                                  id: placement.id!,
                                  dx: delta.dx,
                                  dy: delta.dy,
                                  pageRenderWidth: pageWidth,
                                  pageRenderHeight: pageHeight,
                                );
                              },
                              onResizeDelta: (delta) {
                                if (placement.id == null) return;
                                _controller.resizePlacement(
                                  id: placement.id!,
                                  dx: delta.dx,
                                  dy: delta.dy,
                                  pageRenderWidth: pageWidth,
                                  pageRenderHeight: pageHeight,
                                );
                              },
                              onDelete: () {
                                if (placement.id == null) return;
                                _controller.removePlacement(placement.id!);
                              },
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final isViewerRole = authState.isViewer;
    final pagePlacements = _controller.placementsForPage(_currentPageIndex);
    final hasSavedSignature =
        _signatureBytes != null && _signatureBytes!.isNotEmpty;
    final canSaveDocument = !isViewerRole &&
        !_isLoadingPdf &&
        !_isSaving &&
        hasSavedSignature &&
        _controller.placements.isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          widget.document.name,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            key: const Key('export_pdf_button'),
            tooltip: 'Export PDF',
            onPressed: (_isLoadingPdf ||
                    _isExporting ||
                    _pdfBytes == null ||
                    _pdfBytes!.isEmpty)
                ? null
                : _handleExportCurrentPdf,
            icon: const Icon(Icons.file_download_outlined),
          ),
        ],
      ),
      body: _isLoadingPdf
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFB91C1C)),
            )
          : _loadError != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Gagal memuat dokumen PDF.',
                          style: TextStyle(
                            color: Color(0xFF0F172A),
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _loadError!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFF475569),
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: _loadInitialState,
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFFB91C1C),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          child: const Text('Coba Lagi'),
                        ),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: [
                    Expanded(
                      child: _buildPdfViewerArea(
                        context: context,
                        pagePlacements: pagePlacements,
                      ),
                    ),
                    const Divider(
                      height: 1,
                      thickness: 1,
                      color: Color(0xFFE2E8F0),
                    ),
                    Container(
                      color: Colors.white,
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                      child: SafeArea(
                        top: false,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_isSaving)
                              const Padding(
                                padding: EdgeInsets.only(bottom: 10),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Color(0xFFB91C1C),
                                      ),
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      'Menyimpan & Mengunggah ke Mega.nz...',
                                      style: TextStyle(
                                        color: Color(0xFF475569),
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            if (isViewerRole)
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: const Color(0xFFCBD5E1),
                                  ),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(
                                      Icons.visibility_outlined,
                                      size: 18,
                                      color: Color(0xFF475569),
                                    ),
                                    SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Mode Baca (Viewer): Akun Anda hanya memiliki akses baca dokumen.',
                                        style: TextStyle(
                                          color: Color(0xFF334155),
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: _isSaving
                                          ? null
                                          : _handleAddSignature,
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor:
                                            const Color(0xFF0F172A),
                                        side: const BorderSide(
                                          color: Color(0xFFCBD5E1),
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 12,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                      ),
                                      icon: const Icon(
                                        Icons.draw_outlined,
                                        size: 18,
                                      ),
                                      label: const Text(
                                        'Sign',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (hasSavedSignature) ...[
                                    const SizedBox(width: 8),
                                    OutlinedButton(
                                      onPressed: _isSaving
                                          ? null
                                          : _handleRedrawSignature,
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor:
                                            const Color(0xFF0F172A),
                                        side: const BorderSide(
                                          color: Color(0xFFCBD5E1),
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 12,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                      ),
                                      child: const Text(
                                        'Change sign',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                  const SizedBox(width: 8),
                                  FilledButton.icon(
                                    key: const Key(
                                        'save_signed_document_button'),
                                    onPressed: canSaveDocument
                                        ? _handleSaveSignedDocument
                                        : null,
                                    style: FilledButton.styleFrom(
                                      backgroundColor: const Color(0xFFB91C1C),
                                      disabledBackgroundColor:
                                          const Color(0xFFE2E8F0),
                                      foregroundColor: Colors.white,
                                      disabledForegroundColor:
                                          const Color(0xFF64748B),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 12,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                    ),
                                    icon: const Icon(
                                      Icons.cloud_upload_outlined,
                                      size: 18,
                                    ),
                                    label: const Text(
                                      'Simpan Dokumen',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}

class DraggableSignatureOverlay extends StatelessWidget {
  final SignaturePlacement placement;
  final double pageWidth;
  final double pageHeight;
  final Uint8List? signatureBytes;
  final ValueChanged<Offset> onDragDelta;
  final ValueChanged<Offset> onResizeDelta;
  final VoidCallback onDelete;

  const DraggableSignatureOverlay({
    super.key,
    required this.placement,
    required this.pageWidth,
    required this.pageHeight,
    required this.signatureBytes,
    required this.onDragDelta,
    required this.onResizeDelta,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final left = placement.xRatio * pageWidth;
    final top = placement.yRatio * pageHeight;
    final width = placement.widthRatio * pageWidth;
    final height = placement.heightRatio * pageHeight;

    return Positioned(
      left: left,
      top: top,
      width: width,
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: GestureDetector(
              key: const Key('drag_signature_overlay'),
              behavior: HitTestBehavior.opaque,
              onPanUpdate: (details) => onDragDelta(details.delta),
              child: CustomPaint(
                painter: _DashedBorderPainter(
                  color: const Color(0xFFB91C1C),
                ),
                child: Container(
                  color: const Color(0x14B91C1C),
                  padding: const EdgeInsets.all(4),
                  child: signatureBytes != null && signatureBytes!.isNotEmpty
                      ? Image.memory(
                          signatureBytes!,
                          fit: BoxFit.contain,
                          errorBuilder: (_, _, _) => const Center(
                            child: Text(
                              'TTD',
                              style: TextStyle(
                                color: Color(0xFF0F172A),
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        )
                      : const Center(
                          child: Text(
                            'TTD',
                            style: TextStyle(
                              color: Color(0xFF0F172A),
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 0,
            right: 0,
            child: GestureDetector(
              key: const Key('delete_signature_overlay'),
              behavior: HitTestBehavior.opaque,
              onTap: onDelete,
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                alignment: Alignment.center,
                child: const Text(
                  '×',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    height: 1.0,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: GestureDetector(
              key: const Key('resize_signature_overlay'),
              behavior: HitTestBehavior.opaque,
              onPanUpdate: (details) => onResizeDelta(details.delta),
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: const Color(0xFFB91C1C),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                child: const Icon(
                  Icons.open_in_full,
                  size: 10,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  final Color color;

  _DashedBorderPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    const dashWidth = 5.0;
    const dashSpace = 3.0;

    void drawDashedLine(Offset start, Offset end) {
      final totalLength = (end - start).distance;
      if (totalLength <= 0) return;
      final dir = (end - start) / totalLength;
      var distance = 0.0;
      while (distance < totalLength) {
        final next = (distance + dashWidth).clamp(0.0, totalLength);
        canvas.drawLine(start + dir * distance, start + dir * next, paint);
        distance += dashWidth + dashSpace;
      }
    }

    final topLeft = Offset.zero;
    final topRight = Offset(size.width, 0);
    final bottomRight = Offset(size.width, size.height);
    final bottomLeft = Offset(0, size.height);

    drawDashedLine(topLeft, topRight);
    drawDashedLine(topRight, bottomRight);
    drawDashedLine(bottomRight, bottomLeft);
    drawDashedLine(bottomLeft, topLeft);
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color;
}
