import 'package:flutter_test/flutter_test.dart';
import 'package:keluarr/data/gpx.dart';
import 'package:keluarr/data/pack.dart';
import 'package:keluarr/data/polyline.dart';
import 'package:keluarr/state.dart';
import 'package:latlong2/latlong.dart' hide Path;

void main() {
  test('format angka gaya Indonesia', () {
    expect(fmtKm(6.08), '6,08');
    expect(fmtKm(24.6), '24,6');
    expect(fmtClock(2162), '36:02');
    expect(fmtClock(4080), '1:08:00');
    expect(fmtSpan(33240), '9j 14m');
    expect(fmtPace(355), '5:55');
    expect(fmtPace(0), '--:--');
    expect(fmtGap(320), '320 m');
    expect(fmtGap(-1800), '1,8 km');
  });

  test('metrik aktivitas dihitung dari jarak + durasi', () {
    final a = Activity(
      id: 't',
      sport: Sport.run,
      title: 'Lari pagi Cigemuk',
      startedAt: DateTime(2026, 8, 5, 5, 42),
      distanceM: 6080,
      movingSec: 2162,
    );
    expect(fmtKm(a.km), '6,08');
    expect(fmtPace(a.avgPaceSecPerKm), '5:55');
    expect(a.avgSpeedKmh, closeTo(10.1, 0.05));
    expect(a.calories, 438); // 1.03 kkal/km/kg × 6,08 km × 70 kg
    expect(a.isPrivate, isTrue);
  });

  test('aktivitas kosong tidak bikin pace / km bagi nol', () {
    final a = Activity(
      id: 't0',
      sport: Sport.walk,
      title: 'batal',
      startedAt: DateTime(2026, 8, 5),
      distanceM: 0,
      movingSec: 0,
    );
    expect(a.avgPaceSecPerKm, 0);
    expect(a.avgSpeedKmh, 0);
    expect(fmtPace(a.avgPaceSecPerKm), '--:--');
    expect(a.shape, isEmpty);
  });

  test('aktivitas bolak-balik JSON tanpa kehilangan jejak', () {
    final a = Activity(
      id: 'rt',
      sport: Sport.bike,
      title: 'Sepeda ke Legok',
      startedAt: DateTime(2026, 8, 3, 6, 10),
      distanceM: 24600,
      movingSec: 4080,
      elevGainM: 168,
      splits: const [KmSplit(1, 200), KmSplit(2, 190)],
      track: const [LatLng(-6.1783, 106.6319), LatLng(-6.1700, 106.6400)],
      secs: const [0, 120],
      note: 'ban depan bocor',
    );
    final b = Activity.fromJson(a.toJson());
    expect(b.id, a.id);
    expect(b.sport, Sport.bike);
    expect(b.distanceM, a.distanceM);
    expect(b.splits.length, 2);
    expect(b.note, 'ban depan bocor');
    expect(b.track.length, 2);
    // Polyline presisi 5 desimal ≈ 1 m.
    expect(b.track.first.latitude, closeTo(-6.1783, 0.00001));
    expect(b.secs, [0, 120]);
  });

  test('Track: jarak dari fix, titik diperkecil, jeda panjang tidak dihitung', () {
    final t = Track();
    final t0 = DateTime(2026, 8, 5, 5, 42);
    // 12 fix, tiap ~9 m ke utara, 3 detik sekali.
    for (var i = 0; i < 12; i++) {
      t.add(LatLng(-6.1783 + i * 0.00008, 106.6319), 10.5,
          t0.add(Duration(seconds: i * 3)));
    }
    expect(t.km, closeTo(0.098, 0.01));
    // Titik hanya disimpan tiap 25 m → jauh lebih sedikit dari 12 fix.
    expect(t.points.length, lessThan(8));
    expect(t.moving.inSeconds, 33);

    // Jeda 20 menit (app ditutup) tidak boleh masuk waktu bergerak.
    t.add(const LatLng(-6.1773, 106.6319), 10.5,
        t0.add(const Duration(minutes: 20)));
    expect(t.moving.inSeconds, 33);
    expect(t.topKmh, closeTo(10.5, 0.01));
  });

  test('Track: lompatan GPS liar tidak dihitung sebagai jarak', () {
    final t = Track();
    final t0 = DateTime(2026, 8, 5);
    t.add(const LatLng(-6.1783, 106.6319), 5, t0);
    t.add(const LatLng(-6.1783, 106.6320), 5, t0.add(const Duration(seconds: 3)));
    final before = t.km;
    // Lompat ~55 km — fix palsu saat GPS baru nyala.
    t.add(const LatLng(-6.6783, 106.6320), 5, t0.add(const Duration(seconds: 6)));
    expect(t.km, before);
  });

  test('rombongan: rentang & urutan sepanjang arah gerak', () {
    // Tiga orang di garis utara-selatan, semua menuju utara (heading 0).
    final pos = {
      'a': const LatLng(-6.1800, 106.6319),
      'b': const LatLng(-6.1780, 106.6319), // ~222 m di utara a
      'c': const LatLng(-6.1790, 106.6319),
    };
    final pack = computePack(pos, {'a': 0, 'b': 0, 'c': 0});
    expect(pack.frontUid, 'b');
    expect(pack.backUid, 'a');
    expect(pack.spreadM, closeTo(222, 8));
    expect(pack.offsets['a'], 0);
  });

  test('rombongan: satu orang atau kosong tidak melempar', () {
    expect(computePack(const {}, const {}).spreadM, 0);
    expect(computePack(const {'a': LatLng(-6.1, 106.6)}, const {}).frontUid, 'a');
  });

  test('polyline bolak-balik', () {
    const pts = [LatLng(-6.17832, 106.63195), LatLng(-6.17700, 106.64000)];
    final back = decodePolyline(encodePolyline(pts));
    expect(back.length, 2);
    expect(back[1].longitude, closeTo(106.64, 0.00001));
  });

  test('GPX punya trkpt dan judul yang di-escape', () {
    final gpx = toGpx(
      title: 'Lari & <pagi>',
      startedAt: DateTime.utc(2026, 8, 5, 5, 42),
      points: const [LatLng(-6.1783, 106.6319), LatLng(-6.1780, 106.6320)],
      secs: const [0, 30],
    );
    expect(gpx, contains('<trkpt lat="-6.178300" lon="106.631900">'));
    expect(gpx, contains('Lari &amp; &lt;pagi&gt;'));
    expect(gpx, contains('2026-08-05T05:42:30.000Z'));
  });

  test('rekap bulanan konsisten dengan daftar aktivitas', () {
    final app = AppState(demo: true);
    final month = app.monthActivities;
    expect(month, isNotEmpty);
    expect(app.monthKm, closeTo(month.fold(0.0, (s, a) => s + a.km), 0.001));
    expect(app.weeklyKm.length, 4);
    expect(app.weeklyKm.reduce((a, b) => a + b), closeTo(app.monthKm, 0.001));
  });

  test('tanpa Firebase: app tetap punya diri sendiri, grup jadi lokal', () async {
    final app = AppState();
    expect(app.online, isFalse);
    expect(app.me.isMe, isTrue);
    await app.createGroup('Grup Uji', Sport.bike);
    expect(app.activeGroup!.localOnly, isTrue);
    expect(app.isAdmin, isTrue);
    // Tanpa server, gabung kode selalu mengembalikan pesan kesalahan.
    expect(await app.joinGroup('KLR-ABCD'), isNotNull);
  });

  test('sesi rekam: fix GPS mengisi jarak, selesai menyimpan aktivitas', () async {
    final app = AppState(demo: true);
    final before = app.activities.length;
    final s = RecordSession(Sport.run);
    app.session = s;
    for (var i = 0; i < 40; i++) {
      s.onFix(LatLng(-6.1783 + i * 0.0002, 106.6319), 10.5, null);
    }
    expect(s.km, greaterThan(0.7));
    expect(s.points.length, greaterThan(3));
    final a = await app.finishSession();
    expect(a, isNotNull);
    expect(app.session, isNull);
    expect(app.activities.length, before + 1);
    expect(app.activities.first.track.length, greaterThan(3));
  });

  test('rekaman tanpa jarak tidak disimpan', () async {
    final app = AppState();
    app.session = RecordSession(Sport.walk);
    expect(await app.finishSession(), isNull);
    expect(app.activities, isEmpty);
    expect(app.notice, contains('terlalu pendek'));
  });

  group('grup yang pernah dibuat sendiri', () {
    test('CreatedGroupRef bolak-balik JSON tanpa kehilangan leftAt', () {
      final c = CreatedGroupRef(
          code: 'KLR-AB12',
          name: 'Keluarr Pagi',
          sport: Sport.run,
          createdAt: DateTime(2026, 1, 1),
          leftAt: DateTime(2026, 2, 1));
      final back = CreatedGroupRef.fromJson(c.toJson());
      expect(back.code, c.code);
      expect(back.name, c.name);
      expect(back.sport, c.sport);
      expect(back.createdAt, c.createdAt);
      expect(back.leftAt, c.leftAt);
    });

    test('keluar biasa: ditandai yatim (leftAt), bukan dihapus', () async {
      final app = AppState();
      addTearDown(app.dispose);
      final g = Group(code: 'KLR-AB12', name: 'Grup Uji', sport: Sport.run, adminUid: app.myUid);
      app.groups.add(g);
      app.activeGroupCode = g.code;
      app.createdGroups.add(CreatedGroupRef(
          code: g.code, name: g.name, sport: g.sport, createdAt: DateTime.now()));

      await app.leaveGroup(groupCode: g.code);

      expect(app.groups, isEmpty);
      expect(app.createdGroups, hasLength(1));
      expect(app.createdGroups.first.leftAt, isNotNull);
    });

    test('hapus grup sebagai admin: entrinya ikut hilang, bukan cuma yatim', () async {
      final app = AppState();
      addTearDown(app.dispose);
      final g = Group(code: 'KLR-AB12', name: 'Grup Uji', sport: Sport.run, adminUid: app.myUid);
      app.groups.add(g);
      app.activeGroupCode = g.code;
      app.createdGroups.add(CreatedGroupRef(
          code: g.code, name: g.name, sport: g.sport, createdAt: DateTime.now()));

      await app.leaveGroup(groupCode: g.code, deleteIfAdmin: true);

      expect(app.createdGroups, isEmpty);
    });

    test('masuk lagi ke grup yang masih diikuti cuma memindahkan tab aktif', () async {
      final app = AppState();
      addTearDown(app.dispose);
      final g = Group(code: 'KLR-AB12', name: 'Grup Uji', sport: Sport.run, adminUid: app.myUid);
      final lain = Group(code: 'KLR-ZZ99', name: 'Grup Lain', sport: Sport.bike, adminUid: 'x');
      app.groups.addAll([g, lain]);
      app.activeGroupCode = lain.code;

      final err = await app.rejoinCreatedGroup(g.code);

      expect(err, isNull);
      expect(app.activeGroupCode, g.code);
    });

    test('masuk lagi tanpa koneksi memberi pesan error, bukan diam-diam gagal', () async {
      final app = AppState();
      addTearDown(app.dispose);
      app.createdGroups.add(CreatedGroupRef(
          code: 'KLR-AB12',
          name: 'Grup Uji',
          sport: Sport.run,
          createdAt: DateTime.now(),
          leftAt: DateTime.now()));

      final err = await app.rejoinCreatedGroup('KLR-AB12');

      expect(err, isNotNull);
      expect(app.createdGroups.first.leftAt, isNotNull,
          reason: 'gagal masuk tidak boleh menghapus status yatimnya');
    });

    test('ganti nama/olahraga grup ikut disamakan di daftar pernah-dibuat', () async {
      final app = AppState();
      addTearDown(app.dispose);
      final g = Group(code: 'KLR-AB12', name: 'Nama Lama', sport: Sport.run, adminUid: app.myUid);
      app.groups.add(g);
      app.activeGroupCode = g.code;
      app.createdGroups.add(CreatedGroupRef(
          code: g.code, name: 'Nama Lama', sport: Sport.run, createdAt: DateTime.now()));

      await app.saveGroupSettings(name: 'Nama Baru', sport: Sport.bike, targetKm: 300);

      expect(app.createdGroups.first.name, 'Nama Baru');
      expect(app.createdGroups.first.sport, Sport.bike);
    });
  });

  group('rekaman selamat dari app yang dibunuh', () {
    RecordSession berlari() {
      final s = RecordSession(Sport.run);
      for (var i = 0; i < 40; i++) {
        s.onFix(LatLng(-6.1783 + i * 0.0002, 106.6319), 10.5, null);
      }
      s.lap();
      return s;
    }

    test('potret sesi bolak-balik tanpa kehilangan jejak & lap', () {
      final s = berlari();
      addTearDown(s.dispose);
      final pulih = RecordSession.fromJson(s.toJson());
      addTearDown(pulih.dispose);

      expect(pulih.km, closeTo(s.km, 0.001));
      expect(pulih.points.length, s.points.length);
      expect(pulih.points.last.latitude, closeTo(s.points.last.latitude, 1e-6));
      expect(pulih.movingSec, s.movingSec);
      expect(pulih.laps, s.laps);
      expect(pulih.startedAt, s.startedAt);
      // Selalu dijeda: waktu selama app mati bukan waktu bergerak.
      expect(pulih.paused, isTrue);
    });

    test('sesi berjalan ikut tersimpan, sesi selesai tidak', () async {
      final store = _MemStore();
      final app = AppState(store: store);
      addTearDown(app.dispose);
      app.session = berlari();

      await app.flush();
      expect(store.last!['session'], isNotNull);

      await app.finishSession();
      expect(store.last!['session'], isNull,
          reason: 'kalau tertinggal, sesi yang sudah selesai dipulihkan lagi');
    });

    test('boot memulihkan rekaman yang tertinggal', () async {
      final store = _MemStore();
      final asal = AppState(store: store);
      addTearDown(asal.dispose);
      asal.session = berlari();
      await asal.flush();

      final lagi = AppState(store: store);
      addTearDown(lagi.dispose);
      await lagi.boot();

      expect(lagi.session, isNotNull);
      expect(lagi.session!.km, closeTo(asal.session!.km, 0.001));
      expect(lagi.session!.paused, isTrue);
      expect(lagi.notice, contains('dipulihkan'));
    });

    test('rekaman basi disimpan jadi aktivitas, bukan dibuang', () async {
      final store = _MemStore();
      final asal = AppState(store: store);
      addTearDown(asal.dispose);
      asal.session = berlari();
      await asal.flush();
      // Mundurkan waktu fix terakhir lewat ambang 6 jam.
      final sesi = (store.last!['session'] as Map).cast<String, dynamic>();
      final trek = (sesi['track'] as Map).cast<String, dynamic>();
      trek['end'] =
          DateTime.now().subtract(const Duration(hours: 9)).toIso8601String();

      final lagi = AppState(store: store);
      addTearDown(lagi.dispose);
      await lagi.boot();

      expect(lagi.session, isNull);
      expect(lagi.activities, hasLength(1));
      expect(lagi.activities.first.km, closeTo(asal.session!.km, 0.001));
    });
  });
}

/// Store di memori — menghindari SharedPreferences di unit test.
class _MemStore implements Store {
  Map<String, dynamic>? last;

  @override
  Future<Map<String, dynamic>?> load() async => last;

  @override
  void save(Map<String, dynamic> state) => last = state;

  @override
  Future<void> flushNow(Map<String, dynamic> state) async => last = state;

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}
