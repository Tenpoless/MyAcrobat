import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'src/features/auth/auth_controller.dart';
import 'src/features/auth/login_screen.dart';
import 'src/features/files/document_list_screen.dart';

void main() {
  runApp(
    const ProviderScope(
      child: MyAcrobatApp(),
    ),
  );
}

class MyAcrobatApp extends ConsumerStatefulWidget {
  const MyAcrobatApp({super.key});

  @override
  ConsumerState<MyAcrobatApp> createState() => _MyAcrobatAppState();
}

class _MyAcrobatAppState extends ConsumerState<MyAcrobatApp> {
  bool _restoring = true;

  @override
  void initState() {
    super.initState();
    _restoreAuth();
  }

  Future<void> _restoreAuth() async {
    await ref.read(authControllerProvider.notifier).restoreSession();
    if (mounted) {
      setState(() => _restoring = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);

    return MaterialApp(
      title: 'AgriSign',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFB91C1C),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: _restoring
          ? const Scaffold(
              backgroundColor: Color(0xFFF8FAFC),
              body: Center(
                child: CircularProgressIndicator(color: Color(0xFFB91C1C)),
              ),
            )
          : authState.isAuthenticated
              ? const DocumentListScreen()
              : const LoginScreen(navigateOnSuccess: false),
    );
  }
}
