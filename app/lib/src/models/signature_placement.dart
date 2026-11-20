class SignaturePlacement {
  SignaturePlacement({
    this.id,
    required this.pageIndex,
    required this.xRatio,
    required this.yRatio,
    required this.widthRatio,
    required this.heightRatio,
  }) {
    if (pageIndex < 0) {
      throw ArgumentError.value(pageIndex, 'pageIndex', 'Harus >= 0');
    }
    if (xRatio < 0.0 || xRatio > 1.0 || xRatio.isNaN) {
      throw ArgumentError.value(xRatio, 'xRatio', 'Harus berada di rentang 0.0–1.0');
    }
    if (yRatio < 0.0 || yRatio > 1.0 || yRatio.isNaN) {
      throw ArgumentError.value(yRatio, 'yRatio', 'Harus berada di rentang 0.0–1.0');
    }
    if (widthRatio <= 0.0 || widthRatio > 1.0 || widthRatio.isNaN) {
      throw ArgumentError.value(widthRatio, 'widthRatio', 'Harus berada di rentang (0.0, 1.0]');
    }
    if (heightRatio <= 0.0 || heightRatio > 1.0 || heightRatio.isNaN) {
      throw ArgumentError.value(heightRatio, 'heightRatio', 'Harus berada di rentang (0.0, 1.0]');
    }
  }

  final String? id;
  final int pageIndex;
  final double xRatio;
  final double yRatio;
  final double widthRatio;
  final double heightRatio;

  SignaturePlacement copyWith({
    String? id,
    int? pageIndex,
    double? xRatio,
    double? yRatio,
    double? widthRatio,
    double? heightRatio,
  }) {
    return SignaturePlacement(
      id: id ?? this.id,
      pageIndex: pageIndex ?? this.pageIndex,
      xRatio: xRatio ?? this.xRatio,
      yRatio: yRatio ?? this.yRatio,
      widthRatio: widthRatio ?? this.widthRatio,
      heightRatio: heightRatio ?? this.heightRatio,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'pageIndex': pageIndex,
      'xRatio': xRatio,
      'yRatio': yRatio,
      'widthRatio': widthRatio,
      'heightRatio': heightRatio,
    };
  }
}
