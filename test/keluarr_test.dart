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
    // Jumlah batang mengikuti panjang bulan (4 atau 5), bukan dipatok 4.
    expect(app.weeklyKm.length, inInclusiveRange(4, 5));
    expect(app.weeklyKm.reduce((a, b) => a + b), closeTo(app.monthKm, 0.001));
  });

  group('logika metrik', () {
    test('kalori hiking memperhitungkan tanjakan, bukan cuma jarak', () {
      final datar = estimateKcal(Sport.hike, 8.4, 0);
      final nanjak = estimateKcal(Sport.hike, 8.4, 742);
      expect(nanjak, greaterThan(datar));
      // m·g·h / (0,25 efisiensi · 4184 J/kkal) ≈ 70 · 742 · 0,0094 ≈ 488 kkal.
      expect(nanjak - datar, closeTo(488, 15));
    });

    test('elevasi turun tidak mengurangi kalori', () {
      expect(estimateKcal(Sport.run, 5, -300), estimateKcal(Sport.run, 5, 0));
    });

    test('kalori mengacu berat badan di profil, bukan angka hardcode', () {
      final app = AppState();
      addTearDown(app.dispose);
      final a = Activity(
          id: 'x',
          sport: Sport.run,
          title: 'x',
          startedAt: DateTime(2026, 8, 1),
          distanceM: 10000,
          movingSec: 3000);

      final default70 = a.calories;
      app.bodyWeightKg = 90;
      expect(a.calories, greaterThan(default70));
      expect(a.calories / default70, closeTo(90 / 70, 0.01));
    });

    test('berat & tinggi dijaga di rentang wajar', () {
      final app = AppState();
      addTearDown(app.dispose);
      app.bodyWeightKg = 700; // salah ketik
      expect(app.bodyWeightKg, Body.maxWeightKg);
      app.bodyWeightKg = 1;
      expect(app.bodyWeightKg, Body.minWeightKg);
      app.heightCm = 5;
      expect(app.heightCm, Body.minHeightCm);
    });

    test('BMI hanya muncul kalau tinggi diisi', () {
      final app = AppState();
      addTearDown(app.dispose);
      expect(app.bmi, isNull);
      expect(app.bmiLabel, isNull);

      app
        ..bodyWeightKg = 70
        ..heightCm = 175;
      expect(app.bmi, closeTo(22.86, 0.01));
      expect(app.bmiLabel, 'NORMAL');
    });

    test('berat & tinggi ikut tersimpan dan dipulihkan', () async {
      final store = _MemStore();
      final asal = AppState(store: store);
      addTearDown(asal.dispose);
      asal.set(() {
        asal
          ..bodyWeightKg = 62.5
          ..heightCm = 168;
      });
      await asal.flush();

      final lagi = AppState(store: store);
      addTearDown(lagi.dispose);
      await lagi.boot();

      expect(lagi.bodyWeightKg, 62.5);
      expect(lagi.heightCm, 168);
    });

    test('5K tercepat diambil dari jendela nyata, bukan pace rata-rata', () {
      // 10 km lurus: 5 km pertama lambat (1500 dtk), 5 km kedua cepat (900 dtk).
      // Pace rata-rata × 5 = 1200 dtk — angka yang tidak pernah ditempuh.
      final pts = <LatLng>[];
      final secs = <int>[];
      for (var i = 0; i <= 100; i++) {
        pts.add(LatLng(-6.2 + i * 0.000899, 106.8)); // ~100 m per langkah
        secs.add(i <= 50 ? i * 30 : 1500 + (i - 50) * 18);
      }
      final a = Activity(
          id: 'x',
          sport: Sport.run,
          title: 'x',
          startedAt: DateTime(2026, 8, 1),
          distanceM: 10000,
          movingSec: 2400,
          track: pts,
          secs: secs);

      final best = AppState.best5kOf(a);
      expect(best, isNotNull);
      expect(best, closeTo(900, 60), reason: 'harus menemukan paruh cepatnya');
      expect(best, lessThan(1200), reason: 'lebih baik dari pace rata-rata × 5');
    });

    test('aktivitas tanpa jejak cukup tidak mengarang rekor 5K', () {
      final a = Activity(
          id: 'y',
          sport: Sport.run,
          title: 'y',
          startedAt: DateTime(2026, 8, 1),
          distanceM: 8000,
          movingSec: 2400);
      expect(AppState.best5kOf(a), isNull);
    });

    test('batang mingguan: tiap batang 7 hari, sisa hari dapat batang sendiri', () {
      final app = AppState();
      addTearDown(app.dispose);
      final now = DateTime.now();
      final hari = DateTime(now.year, now.month + 1, 0).day;

      expect(app.weeklyKm.length, (hari / 7).ceil());
      expect(app.weeklyLabels.length, app.weeklyKm.length);
    });

    test('warna anggota stabil, tidak bergantung String.hashCode', () {
      final a = Member(uid: 'abc123', name: 'A');
      final b = Member(uid: 'abc123', name: 'B');
      expect(a.color, b.color);
      // Nilainya ditentukan FNV-1a, jadi tetap sama lintas versi Dart SDK.
      expect(Member(uid: 'zzz', name: 'Z').color,
          Member(uid: 'zzz', name: 'Lain').color);
    });
  });

  group('identitas awal', () {
    test('app baru belum punya nama, jadi sambutan ditampilkan', () {
      final app = AppState();
      addTearDown(app.dispose);
      expect(app.nameSet, isFalse);
      expect(app.myName, 'Saya');
    });

    test('setIdentity menyimpan nama, kota kapital, dan menyetel penanda', () {
      final app = AppState();
      addTearDown(app.dispose);
      app.setIdentity(name: '  Ari Ramdani ', city: ' tangerang ');
      expect(app.myName, 'Ari Ramdani');
      expect(app.myCity, 'TANGERANG');
      expect(app.nameSet, isTrue);
      expect(app.me.name, 'Ari Ramdani', reason: 'baris roster ikut disamakan');
    });

    test('kota boleh dilewati', () {
      final app = AppState();
      addTearDown(app.dispose);
      app.setIdentity(name: 'Budi');
      expect(app.myCity, isEmpty);
      expect(app.nameSet, isTrue);
    });

    test('nama & kota bertahan setelah app dibuka lagi', () async {
      final store = _MemStore();
      final asal = AppState(store: store);
      addTearDown(asal.dispose);
      asal.setIdentity(name: 'Ari', city: 'Bandung');
      await asal.flush();

      final lagi = AppState(store: store);
      addTearDown(lagi.dispose);
      await lagi.boot();

      expect(lagi.myName, 'Ari');
      expect(lagi.myCity, 'BANDUNG');
      expect(lagi.nameSet, isTrue, reason: 'tidak ditanya ulang');
    });

    test('pemakai lama yang sudah punya nama tidak ditanya ulang', () async {
      // Simpanan dari versi sebelum penanda `nameSet` ada.
      final store = _MemStore()..last = {'name': 'Ari Lama'};
      final app = AppState(store: store);
      addTearDown(app.dispose);
      await app.boot();

      expect(app.nameSet, isTrue);
      expect(app.myName, 'Ari Lama');
    });
  });

  group('riwayat lengkap di Profil', () {
    Activity act(String id, DateTime kapan, Sport s, double km) => Activity(
          id: id,
          sport: s,
          title: id,
          startedAt: kapan,
          distanceM: km * 1000,
          movingSec: 600,
        );

    test('dikelompokkan per bulan, terbaru dulu, tidak ada yang hilang', () {
      final app = AppState();
      addTearDown(app.dispose);
      app.activities.addAll([
        act('a', DateTime(2026, 8, 3), Sport.run, 5),
        act('b', DateTime(2026, 8, 20), Sport.bike, 20),
        act('c', DateTime(2026, 6, 9), Sport.run, 7),
        act('d', DateTime(2025, 12, 1), Sport.hike, 9),
      ]);

      final byMonth = app.activitiesByMonth;

      expect(byMonth.map((e) => e.$1).toList(),
          [DateTime(2026, 8), DateTime(2026, 6), DateTime(2025, 12)]);
      // Dalam satu bulan juga terbaru dulu.
      expect(byMonth.first.$2.map((a) => a.id).toList(), ['b', 'a']);
      // Semua aktivitas ikut, tidak ada yang tersaring hilang.
      expect(byMonth.fold(0, (s, e) => s + e.$2.length), app.activities.length);
    });

    test('kmBySport bisa dibatasi per tahun — label Profil tidak lagi bohong', () {
      final app = AppState();
      addTearDown(app.dispose);
      app.activities.addAll([
        act('a', DateTime(2026, 8, 3), Sport.run, 5),
        act('b', DateTime(2025, 8, 3), Sport.run, 100),
      ]);

      expect(app.kmBySport(year: 2026)[Sport.run], closeTo(5, 0.001));
      expect(app.kmBySport()[Sport.run], closeTo(105, 0.001),
          reason: 'tanpa year tetap seumur hidup');
    });
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
