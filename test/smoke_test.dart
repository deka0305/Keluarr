import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keluarr/main.dart';
import 'package:keluarr/screens/profile.dart';
import 'package:keluarr/screens/recap.dart';
import 'package:keluarr/screens/record.dart';
import 'package:keluarr/screens/share.dart';
import 'package:keluarr/state.dart';
import 'package:keluarr/widgets.dart';
import 'package:latlong2/latlong.dart' hide Path;

/// Merender tiap layar di ukuran ponsel dan gagal kalau ada overflow / crash.
void main() {
  setUpAll(() => LiveMap.tilesEnabled = false); // jangan unduh tile di test

  Widget host(AppState app, Widget child) => AppScope(
        notifier: app,
        child: MaterialApp(home: AppScope(notifier: app, child: child)),
      );

  void phone(WidgetTester t, {double height = 780}) {
    t.view.physicalSize = Size(360 * 3, height * 3);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
  }

  testWidgets('peta → semua tab → sheet rekam', (t) async {
    phone(t);
    final app = AppState(demo: true);
    addTearDown(app.dispose);
    await t.pumpWidget(host(app, const HomeShell()));
    await t.pumpAndSettle();

    // Grup aktif dari data contoh → langsung PETA.
    expect(find.text('Keluarr Pagi'), findsWidgets);
    expect(find.text('MULAI REKAM RUTE'), findsOneWidget);

    for (final tab in ['TIM', 'GRUP', 'REKAP', 'PETA']) {
      await t.tap(find.text(tab));
      await t.pumpAndSettle();
    }

    // REKAM membuka sheet pilih olahraga (06).
    await t.tap(find.text('REKAM'));
    await t.pumpAndSettle();
    expect(find.text('Rekam apa hari ini?'), findsOneWidget);
  });

  testWidgets('rekap grup, detail, kartu share, profil, privasi', (t) async {
    phone(t, height: 900);
    final app = AppState(demo: true);
    addTearDown(app.dispose);
    final a = app.activities.first;

    await t.pumpWidget(host(app, const Scaffold(body: RecapScreen())));
    await t.pumpAndSettle();
    await t.tap(find.text('GRUP'));
    await t.pumpAndSettle();
    expect(find.text('Rekap grup'), findsOneWidget);

    await t.pumpWidget(host(app, ActivityDetailScreen(activity: a)));
    await t.pumpAndSettle();
    expect(find.text(a.title), findsOneWidget);
    await t.tap(find.text('ELEVASI'));
    await t.pumpAndSettle();

    await t.pumpWidget(host(app, ShareScreen(activity: a)));
    await t.pumpAndSettle();
    expect(find.text('Bagikan gambar'), findsOneWidget);
    await t.tap(find.text('KARTU\nPOLOS'));
    await t.pumpAndSettle();

    await t.pumpWidget(host(app, PlainCardScreen(activity: a)));
    await t.pumpAndSettle();

    await t.pumpWidget(host(app, const ProfileScreen()));
    await t.pumpAndSettle();
    expect(find.text('Ari Ramdani'), findsOneWidget);

    await t.pumpWidget(host(app, const PrivacyScreen()));
    await t.pumpAndSettle();
    expect(find.text('Jejak GPS rute'), findsOneWidget);
  });

  testWidgets('rekaman aktif menampilkan angka dari fix GPS', (t) async {
    phone(t);
    final app = AppState(demo: true);
    addTearDown(app.dispose);
    final s = RecordSession(Sport.run);
    app.session = s;
    for (var i = 0; i < 30; i++) {
      s.onFix(LatLng(-6.1783 + i * 0.0003, 106.6319), 10.5, null);
    }
    await t.pumpWidget(host(app, const RecordingScreen()));
    await t.pumpAndSettle();
    expect(find.textContaining('MEREKAM'), findsOneWidget);
    expect(find.text('JARAK'), findsOneWidget);

    s.togglePause();
    await t.pumpAndSettle();
    expect(find.textContaining('DIJEDA'), findsOneWidget);

    // Timer sesi harus mati sebelum test selesai, kalau tidak framework
    // menolaknya sebagai timer menggantung.
    app.session = null;
    s.dispose();
  });

  testWidgets('kartu share memakai kanvas logis sama di kotak kecil & besar',
      (t) async {
    phone(t);
    final app = AppState(demo: true);
    addTearDown(app.dispose);
    final a = app.activities.first;

    // Kartu dipakai di dua tempat berukuran sangat beda: pratinjau 9:16 penuh
    // layar dan kotak 272 px di layar kartu polos. Keduanya HARUS memakai
    // kanvas logis 360 — kalau tidak, font absolutnya jadi raksasa di kotak
    // kecil (judulnya terpotong "Ja…", subjudul pecah empat baris) dan PNG-nya
    // beda dari yang terlihat di pratinjau.
    //
    // Render PNG-nya sendiri tidak diuji di sini: `toImage()` menggantung di
    // lingkungan flutter_test yang headless. Itu jalur yang harus dicoba di HP.
    for (final w in [140.0, 320.0]) {
      await t.pumpWidget(host(
        app,
        Scaffold(
          body: Center(
            child: SizedBox(
              width: w,
              height: w * 16 / 9,
              child: ShareCard(activity: a, preset: app.preset, app: app),
            ),
          ),
        ),
      ));
      await t.pumpAndSettle();
      final canvas = t.widget<SizedBox>(find
          .descendant(of: find.byType(ShareCard), matching: find.byType(SizedBox))
          .first);
      expect(canvas.width, 360, reason: 'kanvas kartu harus tetap 360 px');
      expect(canvas.height, 640, reason: '9:16 dari 360');
      expect(find.text(a.title), findsOneWidget);
    }
  });

  testWidgets('tanpa grup: onboarding dulu, tab GRUP menawarkan buat/gabung',
      (t) async {
    phone(t);
    final app = AppState();
    addTearDown(app.dispose);
    await t.pumpWidget(host(app, const Root()));
    await t.pumpAndSettle();
    expect(find.text('Belum ada grup'), findsOneWidget);

    app.skipGroup();
    await t.pumpAndSettle();
    await t.tap(find.text('GRUP'));
    await t.pumpAndSettle();
    expect(find.text('Belum ada grup aktif'), findsOneWidget);
  });
}
