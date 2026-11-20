import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

abstract class SignatureStorage {
  Future<Uint8List?> loadSavedSignature();
  Future<void> saveSignature(Uint8List pngBytes);
  Future<void> clearSavedSignature();
  Future<bool> hasSavedSignature();
}

class InMemorySignatureStorage implements SignatureStorage {
  Uint8List? _bytes;

  InMemorySignatureStorage({Uint8List? initialBytes})
      : _bytes = initialBytes != null ? Uint8List.fromList(initialBytes) : null;

  @override
  Future<Uint8List?> loadSavedSignature() async =>
      _bytes != null ? Uint8List.fromList(_bytes!) : null;

  @override
  Future<void> saveSignature(Uint8List pngBytes) async {
    _bytes = Uint8List.fromList(pngBytes);
  }

  @override
  Future<void> clearSavedSignature() async {
    _bytes = null;
  }

  @override
  Future<bool> hasSavedSignature() async =>
      _bytes != null && _bytes!.isNotEmpty;
}

class FileSignatureStorage implements SignatureStorage {
  final Future<Directory> Function() _directoryProvider;
  final String fileName;

  FileSignatureStorage({
    Future<Directory> Function()? directoryProvider,
    this.fileName = 'saved_signature.png',
  }) : _directoryProvider =
            directoryProvider ?? getApplicationDocumentsDirectory;

  Future<File> _resolveFile() async {
    final dir = await _directoryProvider();
    return File('${dir.path}${Platform.pathSeparator}$fileName');
  }

  @override
  Future<Uint8List?> loadSavedSignature() async {
    final file = await _resolveFile();
    if (!await file.exists()) return null;
    final bytes = await file.readAsBytes();
    return bytes.isEmpty ? null : bytes;
  }

  @override
  Future<void> saveSignature(Uint8List pngBytes) async {
    final file = await _resolveFile();
    await file.writeAsBytes(pngBytes, flush: true);
  }

  @override
  Future<void> clearSavedSignature() async {
    final file = await _resolveFile();
    if (await file.exists()) {
      await file.delete();
    }
  }

  @override
  Future<bool> hasSavedSignature() async {
    final file = await _resolveFile();
    if (!await file.exists()) return false;
    return (await file.length()) > 0;
  }
}

class SavedSignatureRepository {
  final SignatureStorage _storage;

  SavedSignatureRepository({SignatureStorage? storage})
      : _storage = storage ??
            (kIsWeb ? InMemorySignatureStorage() : FileSignatureStorage());

  Future<Uint8List?> loadSavedSignature() => _storage.loadSavedSignature();

  Future<void> saveSignature(Uint8List pngBytes) =>
      _storage.saveSignature(pngBytes);

  Future<void> clearSavedSignature() => _storage.clearSavedSignature();

  Future<bool> hasSavedSignature() => _storage.hasSavedSignature();
}

final savedSignatureRepositoryProvider =
    Provider<SavedSignatureRepository>((ref) {
  return SavedSignatureRepository();
});
