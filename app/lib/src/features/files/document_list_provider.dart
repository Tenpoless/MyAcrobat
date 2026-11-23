import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/myacrobat_api_client.dart';
import '../../models/vault_pdf_file.dart';

final apiClientProvider = Provider<MyAcrobatApiClient>((ref) {
  return MyAcrobatApiClient();
});

final searchQueryProvider = StateProvider<String>((ref) => '');

class DocumentListNotifier extends AsyncNotifier<List<VaultPdfFile>> {
  @override
  Future<List<VaultPdfFile>> build() async {
    final client = ref.watch(apiClientProvider);
    return client.fetchFiles();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final client = ref.read(apiClientProvider);
      return client.fetchFiles();
    });
  }
}

final documentListProvider =
    AsyncNotifierProvider<DocumentListNotifier, List<VaultPdfFile>>(
  DocumentListNotifier.new,
);

final filteredDocumentsProvider =
    Provider<AsyncValue<List<VaultPdfFile>>>((ref) {
  final docsAsync = ref.watch(documentListProvider);
  final query = ref.watch(searchQueryProvider).trim().toLowerCase();

  return docsAsync.whenData((files) {
    if (query.isEmpty) {
      return files;
    }
    return files
        .where((file) => file.name.toLowerCase().contains(query))
        .toList();
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
