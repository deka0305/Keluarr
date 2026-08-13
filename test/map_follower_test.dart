import 'dart:ui' show Size;

import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keluarr/widgets.dart';
import 'package:latlong2/latlong.dart' hide Path;

/// Mencatat tiap panggilan move() supaya bisa diperiksa berapa animasi yang
/// benar-benar hidup — inti bug-nya dulu: timer bertumpuk saling berebut kamera.
class _SpyController implements MapController {
  final moves = <LatLng>[];

  @override
  MapCamera get camera => MapCamera(
        crs: const Epsg3857(),
        center: moves.isEmpty ? const LatLng(0, 0) : moves.last,
        zoom: 16,
        rotation: 0,
        nonRotatedSize: const Size(400, 400),
      );

  @override
  bool move(LatLng center, double zoom,
      {Offset? offset, String? id, bool Function(MapCamera, MapCamera)? cancel}) {
    moves.add(center);
    return true;
  }

  @override
  void dispose() {}

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

void main() {
  testWidgets('animasi mencapai tujuan lalu berhenti sendiri', (t) async {
    final c = _SpyController();
    final f = MapFollower(c);
    addTearDown(f.dispose);

    f.follow(const LatLng(-6.2, 106.8));
    await t.pump(const Duration(milliseconds: 500));

    expect(c.moves, isNotEmpty);
    expect(c.moves.last.latitude, closeTo(-6.2, 1e-9));

    final sesudahSelesai = c.moves.length;
    await t.pump(const Duration(milliseconds: 500));
    expect(c.moves.length, sesudahSelesai,
        reason: 'timer harus berhenti sendiri setelah sampai');
  });

  testWidgets('tujuan baru membatalkan animasi lama, tidak menumpuk', (t) async {
    final c = _SpyController();
    final f = MapFollower(c);
    addTearDown(f.dispose);

    f.follow(const LatLng(-6.2, 106.8));
    await t.pump(const Duration(milliseconds: 80)); // animasi masih jalan
    f.follow(const LatLng(-6.9, 107.5)); // datang lebih cepat dari 400 ms
    await t.pump(const Duration(milliseconds: 500));

    // Kalau timer lama masih hidup, titik akhirnya akan tarik-menarik antara
    // dua tujuan. Yang benar: berhenti tepat di tujuan terbaru.
    expect(c.moves.last.latitude, closeTo(-6.9, 1e-9));
    expect(c.moves.last.longitude, closeTo(107.5, 1e-9));
  });

  testWidgets('tujuan yang sama diabaikan — rebuild tidak memicu animasi baru',
      (t) async {
    final c = _SpyController();
    final f = MapFollower(c);
    addTearDown(f.dispose);

    f.follow(const LatLng(-6.2, 106.8));
    await t.pump(const Duration(milliseconds: 500));
    final sesudah = c.moves.length;

    f.follow(const LatLng(-6.2, 106.8));
    await t.pump(const Duration(milliseconds: 500));
    expect(c.moves.length, sesudah);

    // Tapi tombol "pusatkan" tetap bisa memaksa.
    f.follow(const LatLng(-6.2, 106.8), force: true);
    await t.pump(const Duration(milliseconds: 500));
    expect(c.moves.length, greaterThan(sesudah));
  });

  testWidgets('stop() menghentikan animasi yang sedang jalan', (t) async {
    final c = _SpyController();
    final f = MapFollower(c);
    addTearDown(f.dispose);

    f.follow(const LatLng(-6.2, 106.8));
    await t.pump(const Duration(milliseconds: 80));
    f.stop();
    final sesudahStop = c.moves.length;

    await t.pump(const Duration(milliseconds: 500));
    expect(c.moves.length, sesudahStop);
  });
}
