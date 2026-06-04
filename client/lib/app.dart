import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/router/router.dart';
import 'core/api/api_client.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/biometric_lock_screen.dart';

class TelpoztApp extends ConsumerStatefulWidget {
  const TelpoztApp({super.key});
  @override
  ConsumerState<TelpoztApp> createState() => _TelpoztAppState();
}

class _TelpoztAppState extends ConsumerState<TelpoztApp> with WidgetsBindingObserver {
  bool _isLocked = false;
  DateTime? _pausedTime;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final prefs = ref.read(prefsStorageProvider);
    if (prefs.isBiometricEnabled) _isLocked = true;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final prefs = ref.read(prefsStorageProvider);
    if (!prefs.isBiometricEnabled) return;
    if (state == AppLifecycleState.paused) {
      _pausedTime = DateTime.now();
    } else if (state == AppLifecycleState.resumed && _pausedTime != null) {
      if (DateTime.now().difference(_pausedTime!).inSeconds > 60) {
        setState(() => _isLocked = true);
      }
    }
  }

  void _unlock() => setState(() => _isLocked = false);

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    final prefs = ref.watch(prefsStorageProvider);
    return MaterialApp.router(
      title: 'Telpozt',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: prefs.isDarkMode ? ThemeMode.dark : ThemeMode.light,
      routerConfig: router,
      builder: (context, child) => _isLocked ? BiometricLockScreen(onUnlock: _unlock) : (child ?? const SizedBox.shrink()),
    );
  }
}
