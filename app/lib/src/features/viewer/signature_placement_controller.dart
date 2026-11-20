import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../models/signature_placement.dart';

SignaturePlacement applyDragDelta({
  required SignaturePlacement placement,
  required double dx,
  required double dy,
  required double pageRenderWidth,
  required double pageRenderHeight,
}) {
  if (pageRenderWidth <= 0 || pageRenderHeight <= 0) {
    return placement;
  }

  final maxX = math.max(0.0, 1.0 - placement.widthRatio);
  final maxY = math.max(0.0, 1.0 - placement.heightRatio);

  final nextX = (placement.xRatio + (dx / pageRenderWidth)).clamp(0.0, maxX);
  final nextY = (placement.yRatio + (dy / pageRenderHeight)).clamp(0.0, maxY);

  return placement.copyWith(
    xRatio: nextX,
    yRatio: nextY,
  );
}

SignaturePlacement applyResizeDelta({
  required SignaturePlacement placement,
  required double dx,
  required double dy,
  required double pageRenderWidth,
  required double pageRenderHeight,
  double minWidthRatio = 0.08,
  double minHeightRatio = 0.02,
}) {
  if (pageRenderWidth <= 0 || pageRenderHeight <= 0) {
    return placement;
  }

  final aspect = placement.widthRatio > 0
      ? placement.heightRatio / placement.widthRatio
      : (0.10 / 0.30);

  final maxAllowedWidthByX = math.max(minWidthRatio, 1.0 - placement.xRatio);
  final maxAllowedHeightByY = math.max(minHeightRatio, 1.0 - placement.yRatio);
  final maxAllowedWidthByY =
      aspect > 0 ? maxAllowedHeightByY / aspect : maxAllowedWidthByX;
  final maxWidth = math.min(maxAllowedWidthByX, maxAllowedWidthByY);

  final effectiveMinWidth =
      math.min(minWidthRatio, maxWidth);
  final rawWidth = placement.widthRatio + (dx / pageRenderWidth);
  final nextWidth = rawWidth.clamp(effectiveMinWidth, maxWidth);
  final nextHeight =
      (nextWidth * aspect).clamp(minHeightRatio, maxAllowedHeightByY);

  return placement.copyWith(
    widthRatio: nextWidth,
    heightRatio: nextHeight,
  );
}

class SignaturePlacementController extends ChangeNotifier {
  final List<SignaturePlacement> _placements = [];
  int _nextId = 1;

  List<SignaturePlacement> get placements => List.unmodifiable(_placements);

  List<SignaturePlacement> placementsForPage(int pageIndex) {
    return _placements
        .where((item) => item.pageIndex == pageIndex)
        .toList(growable: false);
  }

  SignaturePlacement addDefaultPlacement({required int pageIndex}) {
    final placement = SignaturePlacement(
      id: 'sig_${_nextId++}',
      pageIndex: pageIndex,
      xRatio: 0.35,
      yRatio: 0.45,
      widthRatio: 0.30,
      heightRatio: 0.10,
    );
    _placements.add(placement);
    notifyListeners();
    return placement;
  }

  void dragPlacement({
    required String id,
    required double dx,
    required double dy,
    required double pageRenderWidth,
    required double pageRenderHeight,
  }) {
    final index = _placements.indexWhere((item) => item.id == id);
    if (index == -1) return;
    _placements[index] = applyDragDelta(
      placement: _placements[index],
      dx: dx,
      dy: dy,
      pageRenderWidth: pageRenderWidth,
      pageRenderHeight: pageRenderHeight,
    );
    notifyListeners();
  }

  void resizePlacement({
    required String id,
    required double dx,
    required double dy,
    required double pageRenderWidth,
    required double pageRenderHeight,
  }) {
    final index = _placements.indexWhere((item) => item.id == id);
    if (index == -1) return;
    _placements[index] = applyResizeDelta(
      placement: _placements[index],
      dx: dx,
      dy: dy,
      pageRenderWidth: pageRenderWidth,
      pageRenderHeight: pageRenderHeight,
    );
    notifyListeners();
  }

  void removePlacement(String id) {
    _placements.removeWhere((item) => item.id == id);
    notifyListeners();
  }

  void clear() {
    _placements.clear();
    notifyListeners();
  }
}
