import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/vault_pdf_file.dart';
import '../auth/auth_controller.dart';
import '../auth/login_screen.dart';
import '../viewer/pdf_signing_screen.dart';
import 'document_list_provider.dart';

class DocumentListScreen extends ConsumerStatefulWidget {
  const DocumentListScreen({
    super.key,
    this.onDocumentSelected,
  });

  final void Function(VaultPdfFile file)? onDocumentSelected;

  @override
  ConsumerState<DocumentListScreen> createState() => _DocumentListScreenState();
}

class _DocumentListScreenState extends ConsumerState<DocumentListScreen> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _clearSearch() {
    _searchController.clear();
    ref.read(searchQueryProvider.notifier).state = '';
  }

  String _formatDate(DateTime dateTime) {
    final local = dateTime.toLocal();
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $hh:$mm';
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final currentUser = authState.user;
    final allDocsAsync = ref.watch(documentListProvider);
    final filteredDocsAsync = ref.watch(filteredDocumentsProvider);
    final searchQuery = ref.watch(searchQueryProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'AgriSign',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Muat ulang daftar dokumen',
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            onPressed: () {
              ref.read(documentListProvider.notifier).refresh();
            },
            icon: const Icon(Icons.refresh),
          ),
          if (currentUser != null)
            IconButton(
              key: const Key('logout_button'),
              tooltip: 'Keluar Akun Syncro ERP',
              constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
              onPressed: () async {
                final navigator = Navigator.of(context);
                await ref.read(authControllerProvider.notifier).logout();
                if (!mounted) return;
                navigator.pushReplacement(
                  MaterialPageRoute<void>(
                    builder: (_) => const LoginScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.logout),
            ),
        ],
      ),
      body: Column(
        children: [
          if (currentUser != null) ...[
            Container(
              width: double.infinity,
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      currentUser.position != null &&
                              currentUser.position!.trim().isNotEmpty
                          ? '${currentUser.name} (${currentUser.position})'
                          : currentUser.name,
                      style: const TextStyle(
                        color: Color(0xFF0F172A),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: currentUser.isViewer
                          ? const Color(0xFFF1F5F9)
                          : const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: currentUser.isViewer
                            ? const Color(0xFFCBD5E1)
                            : const Color(0xFFFCA5A5),
                      ),
                    ),
                    child: Text(
                      currentUser.role.toUpperCase(),
                      style: TextStyle(
                        color: currentUser.isViewer
                            ? const Color(0xFF334155)
                            : const Color(0xFF991B1B),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, thickness: 1, color: Color(0xFFE2E8F0)),
          ],
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                ref.read(searchQueryProvider.notifier).state = value;
              },
              style: const TextStyle(
                color: Color(0xFF0F172A),
                fontSize: 15,
              ),
              decoration: InputDecoration(
                hintText: 'Cari nama dokumen PDF...',
                hintStyle: const TextStyle(color: Color(0xFF475569)),
                prefixIcon: const Icon(
                  Icons.search,
                  color: Color(0xFF475569),
                ),
                suffixIcon: searchQuery.isNotEmpty
                    ? IconButton(
                        tooltip: 'Bersihkan pencarian',
                        constraints: const BoxConstraints(
                          minWidth: 44,
                          minHeight: 44,
                        ),
                        onPressed: _clearSearch,
                        icon: const Icon(
                          Icons.close,
                          color: Color(0xFF475569),
                        ),
                      )
                    : null,
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(
                    color: Color(0xFFB91C1C),
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ),
          const Divider(height: 1, thickness: 1, color: Color(0xFFE2E8F0)),
          Expanded(
            child: filteredDocsAsync.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(
                        color: Color(0xFFB91C1C),
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Memuat daftar dokumen PDF dari Mega.nz...',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF334155),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              error: (error, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: Color(0xFFB91C1C),
                        size: 40,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Gagal memuat daftar dokumen dari server.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF0F172A),
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        error.toString(),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFF475569),
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 44,
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFFB91C1C),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          onPressed: () {
                            ref.read(documentListProvider.notifier).refresh();
                          },
                          icon: const Icon(Icons.refresh, size: 18),
                          label: const Text('Coba Lagi'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              data: (files) {
                final allFiles = allDocsAsync.valueOrNull ?? files;

                if (files.isEmpty) {
                  final hasQuery = searchQuery.trim().isNotEmpty;
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.folder_open_outlined,
                            color: Color(0xFF475569),
                            size: 40,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            hasQuery
                                ? 'Tidak ada dokumen PDF dengan nama "$searchQuery".'
                                : 'Belum ada dokumen PDF di folder Mega.nz.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Color(0xFF0F172A),
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            hasQuery
                                ? 'Periksa ejaan kata kunci atau bersihkan kolom pencarian.'
                                : 'Unggah file PDF ke folder Mega.nz lalu muat ulang halaman ini.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Color(0xFF475569),
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            height: 44,
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF0F172A),
                                side: const BorderSide(color: Color(0xFF94A3B8)),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                              onPressed: hasQuery
                                  ? _clearSearch
                                  : () {
                                      ref
                                          .read(documentListProvider.notifier)
                                          .refresh();
                                    },
                              child: Text(
                                hasQuery ? 'Reset Pencarian' : 'Muat Ulang',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return RefreshIndicator(
                  color: const Color(0xFFB91C1C),
                  onRefresh: () =>
                      ref.read(documentListProvider.notifier).refresh(),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: files.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final file = files[index];
                      final hasCounterpart =
                          hasSignedCounterpart(file, allFiles);

                      return Material(
                        color: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () {
                            if (widget.onDocumentSelected != null) {
                              widget.onDocumentSelected!(file);
                              return;
                            }
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => PdfSigningScreen(document: file),
                              ),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: file.isSigned
                                        ? const Color(0xFFD1FAE5)
                                        : const Color(0xFFFEE2E2),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Icon(
                                    Icons.picture_as_pdf_outlined,
                                    color: file.isSigned
                                        ? const Color(0xFF065F46)
                                        : const Color(0xFFB91C1C),
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        file.name,
                                        style: const TextStyle(
                                          color: Color(0xFF0F172A),
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${file.formattedSize} • Diperbarui ${_formatDate(file.updatedAt)}',
                                        style: const TextStyle(
                                          color: Color(0xFF475569),
                                          fontSize: 13,
                                        ),
                                      ),
                                      if (file.isSigned || hasCounterpart) ...[
                                        const SizedBox(height: 8),
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 6,
                                          children: [
                                            if (file.isSigned)
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 3,
                                                ),
                                                decoration: BoxDecoration(
                                                  color:
                                                      const Color(0xFFD1FAE5),
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                  border: Border.all(
                                                    color:
                                                        const Color(0xFF6EE7B7),
                                                  ),
                                                ),
                                                child: const Text(
                                                  'SIGNED',
                                                  style: TextStyle(
                                                    color: Color(0xFF065F46),
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                              ),
                                            if (!file.isSigned &&
                                                hasCounterpart)
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 3,
                                                ),
                                                decoration: BoxDecoration(
                                                  color:
                                                      const Color(0xFFFEF3C7),
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                  border: Border.all(
                                                    color:
                                                        const Color(0xFFFCD34D),
                                                  ),
                                                ),
                                                child: const Text(
                                                  'Sudah Ada Versi _signed',
                                                  style: TextStyle(
                                                    color: Color(0xFF92400E),
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
