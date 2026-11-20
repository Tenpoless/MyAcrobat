import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'saved_signature_repository.dart';

Future<Uint8List?> resolveSignatureForPlacement({
  required BuildContext context,
  required SavedSignatureRepository repo,
  bool forceRedraw = false,
  Future<void> Function(Uint8List pngBytes)? onNewSignatureSaved,
}) async {
  if (!forceRedraw) {
    final existing = await repo.loadSavedSignature();
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }
  }

  if (!context.mounted) return null;

  return showModalBottomSheet<Uint8List>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => SignaturePadSheet(
      repository: repo,
      onNewSignatureSaved: onNewSignatureSaved,
    ),
  );
}

class SignaturePadSheet extends StatefulWidget {
  final SavedSignatureRepository repository;
  final Future<void> Function(Uint8List pngBytes)? onNewSignatureSaved;

  const SignaturePadSheet({
    super.key,
    required this.repository,
    this.onNewSignatureSaved,
  });

  @override
  State<SignaturePadSheet> createState() => _SignaturePadSheetState();
}

class _SignatureStroke {
  final List<Offset> points;
  final Color color;
  final double strokeWidth;

  _SignatureStroke({
    required this.points,
    required this.color,
    required this.strokeWidth,
  });
}

class _SignaturePadSheetState extends State<SignaturePadSheet> {
  static const Color _blackInk = Color(0xFF0F172A);
  static const Color _blueInk = Color(0xFF1D4ED8);

  final List<_SignatureStroke> _strokes = [];
  Color _selectedColor = _blackInk;
  double _strokeWidth = 3.0;
  Size _canvasSize = const Size(360, 180);
  bool _isSaving = false;

  bool get _hasStrokes =>
      _strokes.any((stroke) => stroke.points.isNotEmpty);

  void _startStroke(Offset localPosition) {
    setState(() {
      _strokes.add(
        _SignatureStroke(
          points: [localPosition],
          color: _selectedColor,
          strokeWidth: _strokeWidth,
        ),
      );
    });
  }

  void _appendPoint(Offset localPosition) {
    if (_strokes.isEmpty) {
      _startStroke(localPosition);
      return;
    }
    setState(() {
      _strokes.last.points.add(localPosition);
    });
  }

  void _clearCanvas() {
    setState(() {
      _strokes.clear();
    });
  }

  Future<void> _handleConfirm() async {
    if (!_hasStrokes || _isSaving) return;
    setState(() => _isSaving = true);

    final pngBytes = _encodeStrokesToTransparentPng(
      strokes: _strokes,
      sourceSize: _canvasSize,
    );
    await widget.repository.saveSignature(pngBytes);
    if (widget.onNewSignatureSaved != null) {
      await widget.onNewSignatureSaved!(pngBytes);
    }

    if (!mounted) return;
    Navigator.of(context).pop(pngBytes);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFFFFFFF),
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Buat Tanda Tangan',
                    style: TextStyle(
                      color: Color(0xFF0F172A),
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Color(0xFF475569)),
                  tooltip: 'Tutup',
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text(
                  'Warna Pena:',
                  style: TextStyle(
                    color: Color(0xFF475569),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 8),
                _PenColorChip(
                  label: 'Hitam',
                  color: _blackInk,
                  selected: _selectedColor == _blackInk,
                  onTap: () => setState(() => _selectedColor = _blackInk),
                ),
                const SizedBox(width: 8),
                _PenColorChip(
                  label: 'Biru',
                  color: _blueInk,
                  selected: _selectedColor == _blueInk,
                  onTap: () => setState(() => _selectedColor = _blueInk),
                ),
                const Spacer(),
                TextButton(
                  onPressed: _clearCanvas,
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF475569),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  child: const Text('Bersihkan'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth.isFinite &&
                        constraints.maxWidth > 0
                    ? constraints.maxWidth
                    : 360.0;
                _canvasSize = Size(width, 180);
                return Container(
                  height: 180,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: GestureDetector(
                      key: const Key('signature_pad_canvas'),
                      behavior: HitTestBehavior.opaque,
                      onPanDown: (details) =>
                          _startStroke(details.localPosition),
                      onPanUpdate: (details) =>
                          _appendPoint(details.localPosition),
                      onTapDown: (details) =>
                          _startStroke(details.localPosition),
                      child: CustomPaint(
                        size: Size(width, 180),
                        painter: _SignatureCanvasPainter(strokes: _strokes),
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _hasStrokes && !_isSaving ? _handleConfirm : null,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFB91C1C),
                disabledBackgroundColor: const Color(0xFFE2E8F0),
                foregroundColor: Colors.white,
                disabledForegroundColor: const Color(0xFF64748B),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              child: const Text(
                'Gunakan Tanda Tangan',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PenColorChip extends StatelessWidget {
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _PenColorChip({
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFF1F5F9) : Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: selected ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: const Color(0xFF0F172A),
                fontSize: 13,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SignatureCanvasPainter extends CustomPainter {
  final List<_SignatureStroke> strokes;

  _SignatureCanvasPainter({required this.strokes});

  @override
  void paint(Canvas canvas, Size size) {
    for (final stroke in strokes) {
      if (stroke.points.isEmpty) continue;
      final paint = Paint()
        ..color = stroke.color
        ..strokeWidth = stroke.strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      if (stroke.points.length == 1) {
        canvas.drawCircle(
          stroke.points.first,
          stroke.strokeWidth / 2,
          paint..style = PaintingStyle.fill,
        );
      } else {
        final path = Path()
          ..moveTo(stroke.points.first.dx, stroke.points.first.dy);
        for (var i = 1; i < stroke.points.length; i++) {
          path.lineTo(stroke.points[i].dx, stroke.points[i].dy);
        }
        canvas.drawPath(path, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SignatureCanvasPainter oldDelegate) => true;
}

Uint8List _encodeStrokesToTransparentPng({
  required List<_SignatureStroke> strokes,
  required Size sourceSize,
}) {
  const outWidth = 360;
  const outHeight = 180;
  final scaleX = sourceSize.width > 0 ? outWidth / sourceSize.width : 1.0;
  final scaleY = sourceSize.height > 0 ? outHeight / sourceSize.height : 1.0;

  final pixels = Uint8List(outWidth * outHeight * 4);

  void plotCircle(double cx, double cy, double radius, Color color) {
    final r = math.max(1, radius.round());
    final minX = math.max(0, (cx - r).floor());
    final maxX = math.min(outWidth - 1, (cx + r).ceil());
    final minY = math.max(0, (cy - r).floor());
    final maxY = math.min(outHeight - 1, (cy + r).ceil());
    final rSq = radius * radius;

    final red = (color.r * 255.0).round() & 0xff;
    final green = (color.g * 255.0).round() & 0xff;
    final blue = (color.b * 255.0).round() & 0xff;
    final alpha = (color.a * 255.0).round() & 0xff;

    for (var y = minY; y <= maxY; y++) {
      for (var x = minX; x <= maxX; x++) {
        final dx = x - cx;
        final dy = y - cy;
        if (dx * dx + dy * dy <= rSq) {
          final idx = (y * outWidth + x) * 4;
          pixels[idx] = red;
          pixels[idx + 1] = green;
          pixels[idx + 2] = blue;
          pixels[idx + 3] = alpha;
        }
      }
    }
  }

  for (final stroke in strokes) {
    final radius = math.max(1.0, (stroke.strokeWidth * scaleX) / 2);
    for (var i = 0; i < stroke.points.length; i++) {
      final p0 = stroke.points[i];
      final x0 = p0.dx * scaleX;
      final y0 = p0.dy * scaleY;
      plotCircle(x0, y0, radius, stroke.color);

      if (i + 1 < stroke.points.length) {
        final p1 = stroke.points[i + 1];
        final x1 = p1.dx * scaleX;
        final y1 = p1.dy * scaleY;
        final dist = math.sqrt((x1 - x0) * (x1 - x0) + (y1 - y0) * (y1 - y0));
        final steps = math.max(1, dist.ceil());
        for (var s = 1; s < steps; s++) {
          final t = s / steps;
          plotCircle(
            x0 + (x1 - x0) * t,
            y0 + (y1 - y0) * t,
            radius,
            stroke.color,
          );
        }
      }
    }
  }

  final rawScanlines = BytesBuilder(copy: false);
  for (var y = 0; y < outHeight; y++) {
    rawScanlines.addByte(0); // filter: None
    final rowStart = y * outWidth * 4;
    rawScanlines.add(pixels.sublist(rowStart, rowStart + outWidth * 4));
  }

  final compressedIdat = zlib.encode(rawScanlines.toBytes());

  final png = BytesBuilder(copy: false);
  png.add(const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);

  final ihdr = ByteData(13)
    ..setUint32(0, outWidth, Endian.big)
    ..setUint32(4, outHeight, Endian.big)
    ..setUint8(8, 8) // bit depth
    ..setUint8(9, 6) // color type: RGBA
    ..setUint8(10, 0)
    ..setUint8(11, 0)
    ..setUint8(12, 0);
  _writePngChunk(png, 'IHDR', ihdr.buffer.asUint8List());
  _writePngChunk(png, 'IDAT', Uint8List.fromList(compressedIdat));
  _writePngChunk(png, 'IEND', Uint8List(0));

  return png.toBytes();
}

void _writePngChunk(BytesBuilder out, String type, Uint8List data) {
  final lenBytes = ByteData(4)..setUint32(0, data.length, Endian.big);
  final typeBytes = Uint8List.fromList(type.codeUnits);
  out.add(lenBytes.buffer.asUint8List());
  out.add(typeBytes);
  out.add(data);

  final crc = _crc32([
    ...typeBytes,
    ...data,
  ]);
  final crcBytes = ByteData(4)..setUint32(0, crc, Endian.big);
  out.add(crcBytes.buffer.asUint8List());
}

int _crc32(List<int> bytes) {
  var crc = 0xFFFFFFFF;
  for (final b in bytes) {
    crc ^= b & 0xFF;
    for (var i = 0; i < 8; i++) {
      if ((crc & 1) != 0) {
        crc = (crc >>> 1) ^ 0xEDB88320;
      } else {
        crc = crc >>> 1;
      }
    }
  }
  return (crc ^ 0xFFFFFFFF) & 0xFFFFFFFF;
}
