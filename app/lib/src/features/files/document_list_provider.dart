import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/myacrobat_api_client.dart';
import '../../models/vault_folder.dart';
import '../../models/vault_pdf_file.dart';

final apiClientProvider = Provider<MyAcrobatApiClient>((ref) {
  return MyAcrobatApiClient();
});

final searchQueryProvider = StateProvider<String>((ref) => '');

/// Jejak folder dari root ke folder yang sedang dibuka (kosong = root).
final folderPathProvider = StateProvider<List<VaultFolder>>((ref) => const []);

class DocumentListNotifier extends AsyncNotifier<VaultDirectoryListing> {
  @override
  Future<VaultDirectoryListing> build() => _load();

  Future<VaultDirectoryListing> _load() {
    final client = ref.read(apiClientProvider);
    final path = ref.read(folderPathProvider);
    client.activeFolderId = path.isEmpty ? null : path.last.folderId;
    return client.fetchDirectory();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_load);
  }

  Future<void> openFolder(VaultFolder folder) {
    ref.read(folderPathProvider.notifier).update((p) => [...p, folder]);
    return refresh();
  }

  /// Naik ke folder ke-[depth] pada jejak (0 = root).
  Future<void> goToDepth(int depth) {
    ref.read(folderPathProvider.notifier).update((p) => p.sublist(0, depth));
    return refresh();
  }
}

final documentListProvider =
    AsyncNotifierProvider<DocumentListNotifier, VaultDirectoryListing>(
  DocumentListNotifier.new,
);

final filteredDocumentsProvider =
    Provider<AsyncValue<VaultDirectoryListing>>((ref) {
  final docsAsync = ref.watch(documentListProvider);
  final query = ref.watch(searchQueryProvider).trim().toLowerCase();

  return docsAsync.whenData((listing) {
    if (query.isEmpty) {
      return listing;
    }
    return VaultDirectoryListing(
      folders: listing.folders
          .where((f) => f.name.toLowerCase().contains(query))
          .toList(),
      files: listing.files
          .where((f) => f.name.toLowerCase().contains(query))
          .toList(),
    );
  });
});

bool hasSignedCounterpart(VaultPdfFile file, List<VaultPdfFile> allFiles) {
  if (file.isSigned) {
    return false;
  }
  final lowerName = file.name.toLowerCase();
  final baseName = lowerName.endsWith('.pdf')
      ? lowerName.substring(0, lowerName.length - 4)
      : lowerName;
  final expectedPrefix = '${baseName}_signed';

  for (final candidate in allFiles) {
    if (!candidate.isSigned || candidate.fileId == file.fileId) {
      continue;
    }
    final candidateLower = candidate.name.toLowerCase();
    if (candidateLower == '$expectedPrefix.pdf' ||
        candidateLower.startsWith('${expectedPrefix}_')) {
      return true;
    }
  }
  return false;
}
