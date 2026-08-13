import 'package:flutter/material.dart';

import 'firebase_config.dart';
import 'screens/group.dart';
import 'screens/map_screen.dart';
import 'screens/onboarding.dart';
import 'screens/recap.dart';
import 'screens/record.dart';
import 'screens/team.dart';
import 'state.dart';
import 'theme.dart';
import 'widgets.dart';

void main() {
  runApp(KeluarrApp(
    app: AppState(cloud: Cloud(options: defaultOptions), store: Store()),
  ));
}

class KeluarrApp extends StatefulWidget {
  const KeluarrApp({super.key, required this.app});

  final AppState app;

  @override
  State<KeluarrApp> createState() => _KeluarrAppState();
}

class _KeluarrAppState extends State<KeluarrApp> with WidgetsBindingObserver {
  bool _booted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.app.boot().whenComplete(() {
      if (mounted) setState(() => _booted = true);
    });
  }

  /// Simpan segera begitu app masuk latar. [dispose] tidak bisa diandalkan:
  /// sistem membunuh proses tanpa memanggilnya, dan itu justru yang terjadi
  /// saat HP dikantongi selama merekam.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      widget.app.flush();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.app.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = widget.app;
    return AppScope(
      notifier: app,
      child: ListenableBuilder(
        listenable: app,
        builder: (context, _) => MaterialApp(
          title: 'Keluarr',
          debugShowCheckedModeBanner: false,
          themeMode: app.themeMode,
          theme: buildTheme(Brightness.light),
          darkTheme: buildTheme(Brightness.dark),
          home: AppScope(
            notifier: app,
            child: _booted ? const Root() : const _Splash(),
          ),
        ),
      ),
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 64,
                height: 64,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                    color: K.orange, borderRadius: BorderRadius.circular(19)),
                child: const Text('KL',
                    style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -.5)),
              ),
              const SizedBox(height: 18),
              Text('MENYIAPKAN', style: mono(10, color: context.dim, track: 2)),
            ],
          ),
        ),
      );
}

/// START · belum punya nama ? → sambutan (00) · ada grup aktif ? ya → PETA ·
/// tidak → onboarding (01)
class Root extends StatelessWidget {
  const Root({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    // Nama ditanya sekali di awal, terlepas dari jalur grup mana yang dipilih.
    if (!app.nameSet) return const WelcomeScreen();
    if (app.activeGroup == null && !app.skippedGroup) return const OnboardingScreen();
    return const HomeShell();
  }
}

/// BOTTOM NAV (5): PETA · TIM · REKAM · GRUP · REKAP
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;

  void _onTab(int i) {
    if (i == 2) {
      startRecordFlow(context); // REKAM = sheet 06, bukan halaman tab
      return;
    }
    setState(() => _tab = i);
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    // Pesan status GPS/server ditampilkan sekali, lalu dikonsumsi.
    if (app.notice != null) {
      final msg = app.consumeNotice();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && msg.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
        }
      });
    }
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: IndexedStack(
          index: _tab,
          children: [
            MapScreen(onStartRecord: () => startRecordFlow(context)),
            const TeamScreen(),
            const SizedBox.shrink(),
            const GroupScreen(),
            const RecapScreen(),
          ],
        ),
      ),
      bottomNavigationBar: KNav(index: _tab, onTap: _onTab),
    );
  }
}
