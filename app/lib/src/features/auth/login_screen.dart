import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../files/document_list_provider.dart';
import '../files/document_list_screen.dart';
import 'auth_controller.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({
    super.key,
    this.navigateOnSuccess = true,
  });

  final bool navigateOnSuccess;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  late final TextEditingController _identifierController;
  late final TextEditingController _passwordController;

  @override
  void initState() {
    super.initState();
    _identifierController = TextEditingController();
    _passwordController = TextEditingController();
  }

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _openServerSettingsDialog() async {
    final client = ref.read(apiClientProvider);
    var draftUrl = client.baseUrl;

    final updatedUrl = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          title: const Text(
            'Alamat Server Kantor',
            style: TextStyle(
              color: Color(0xFF0F172A),
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Masukkan alamat IP atau URL Server Kantor MyAcrobat di jaringan LAN/Wi-Fi.',
                style: TextStyle(
                  color: Color(0xFF475569),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('login_office_server_url_input'),
                initialValue: draftUrl,
                onChanged: (value) => draftUrl = value,
                keyboardType: TextInputType.url,
                style: const TextStyle(
                  color: Color(0xFF0F172A),
                  fontSize: 14,
                ),
                decoration: InputDecoration(
                  hintText: 'http://192.168.1.100:3000',
                  hintStyle: const TextStyle(color: Color(0xFF64748B)),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: const BorderSide(
                      color: Color(0xFFB91C1C),
                      width: 1.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF475569),
                minimumSize: const Size(44, 44),
              ),
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Batal'),
            ),
            FilledButton(
              key: const Key('login_save_office_server_url_button'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFB91C1C),
                foregroundColor: Colors.white,
                minimumSize: const Size(44, 44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              onPressed: () => Navigator.of(dialogContext).pop(draftUrl.trim()),
              child: const Text('Simpan Server'),
            ),
          ],
        );
      },
    );

    if (updatedUrl != null && updatedUrl.isNotEmpty) {
      await saveOfficeServerUrl(client, updatedUrl);
      if (mounted) {
        setState(() {});
      }
    }
  }

  Future<void> _handleLoginSubmit() async {
    final identifier = _identifierController.text.trim();
    final password = _passwordController.text;
    if (identifier.isEmpty || password.isEmpty) {
      return;
    }

    final ok = await ref.read(authControllerProvider.notifier).login(
          identifier: identifier,
          password: password,
        );

    if (!ok || !mounted) return;

    if (widget.navigateOnSuccess) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => const DocumentListScreen(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final apiClient = ref.watch(apiClientProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'MyAcrobat: Login Syncro ERP',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            key: const Key('login_server_settings_button'),
            tooltip: 'Pengaturan Alamat Server Kantor',
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            onPressed: _openServerSettingsDialog,
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Masuk dengan Akun Syncro ERP',
                    style: TextStyle(
                      color: Color(0xFF0F172A),
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Gunakan NIK (username) atau Email Syncro ERP untuk mengakses dokumen PDF Mega.nz dan menyinkronkan tanda tangan Anda.',
                    style: TextStyle(
                      color: Color(0xFF475569),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'NIK (Username) atau Email',
                    style: TextStyle(
                      color: Color(0xFF0F172A),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    key: const Key('login_identifier_input'),
                    controller: _identifierController,
                    textInputAction: TextInputAction.next,
                    style: const TextStyle(
                      color: Color(0xFF0F172A),
                      fontSize: 15,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Contoh: EMP-101 atau nama@perusahaan.com',
                      hintStyle: const TextStyle(color: Color(0xFF64748B)),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: const BorderSide(
                          color: Color(0xFFB91C1C),
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Password',
                    style: TextStyle(
                      color: Color(0xFF0F172A),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    key: const Key('login_password_input'),
                    controller: _passwordController,
                    obscureText: true,
                    onSubmitted: (_) => _handleLoginSubmit(),
                    style: const TextStyle(
                      color: Color(0xFF0F172A),
                      fontSize: 15,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Masukkan password Syncro ERP',
                      hintStyle: const TextStyle(color: Color(0xFF64748B)),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: const BorderSide(
                          color: Color(0xFFB91C1C),
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                  if (authState.errorMessage != null) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFFCA5A5)),
                      ),
                      child: Text(
                        authState.errorMessage!,
                        style: const TextStyle(
                          color: Color(0xFF991B1B),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 46,
                    child: FilledButton(
                      key: const Key('login_submit_button'),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFB91C1C),
                        disabledBackgroundColor: const Color(0xFFE2E8F0),
                        foregroundColor: Colors.white,
                        disabledForegroundColor: const Color(0xFF64748B),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      onPressed:
                          authState.isLoading ? null : _handleLoginSubmit,
                      child: Text(
                        authState.isLoading
                            ? 'Memverifikasi Akun...'
                            : 'Masuk ke MyAcrobat',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Server Kantor: ${apiClient.baseUrl}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF475569),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
