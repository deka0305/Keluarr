import 'dart:async';
import 'dart:math' as math;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart' hide Path;

/// Satu-satunya tempat yang tahu tentang Firebase.
///
/// Yang naik ke server HANYA: meta grup, daftar anggota, lokasi live, status,
/// dan angka agregat untuk leaderboard. **Tidak ada method untuk mengirim
/// jejak GPS** — itu bukan kelalaian, itu batas privasi app ini (layar 19).
/// Kalau nanti ada yang ingin "share rute ke grup", ia harus menambah method
/// baru di sini secara sadar.
///
/// App wajib tetap jalan tanpa Firebase: [ready] false berarti grup hanya hidup
/// di HP ini, dan tak satu pun panggilan di bawah dilakukan.
class Cloud {
  Cloud({FirebaseOptions? options}) : _options = options;

  final FirebaseOptions? _options;

  /// Subtree terpisah dari app lain di proyek Firebase yang sama.
  static const rootPath = 'keluarr';

  DatabaseReference? _root;
  String? _uid;
  String? _error;

  bool get ready => _root != null && _uid != null;
  String? get uid => _uid;

  /// Alasan kegagalan terakhir untuk ditampilkan di UI. Null berarti aman.
  String? get error => _error;

  /// Tidak pernah melempar — kegagalan hanya membuat [ready] tetap false.
  Future<void> init() async {
    try {
      if (_options == null) throw StateError('Firebase belum dikonfigurasi.');
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(options: _options);
      }
      final cred = await FirebaseAuth.instance.signInAnonymously();
      _uid = cred.user?.uid;
      if (_uid == null) throw StateError('Firebase tidak memberi uid.');

      final db = FirebaseDatabase.instance;
      // Cache lokal: grup yang sudah dibuka tetap terbaca saat sinyal hilang.
      db.setPersistenceEnabled(true);
      _root = db.ref(rootPath);
      _error = null;
    } catch (e) {
      _root = null;
      _uid = null;
      _error = _readable(e);
      debugPrint('cloud: mode lokal ($e)');
    }
  }

  String _readable(Object e) {
    final s = e.toString();
    if (s.contains('dikonfigurasi') ||
        s.contains('configuration') ||
        s.contains('options')) {
      return 'Firebase belum dikonfigurasi — grup hanya di HP ini.';
    }
    if (s.contains('operation-not-allowed') || s.contains('ADMIN_ONLY')) {
      return 'Anonymous sign-in belum diaktifkan di konsol Firebase.';
    }
    if (s.contains('network') || s.contains('unavailable')) {
      return 'Tidak ada koneksi ke server.';
    }
    return 'Gagal menyambung ke server.';
  }

  /// Kode undangan yang diketik anggota: 8 karakter, huruf/angka yang tidak
  /// gampang tertukar (tanpa I, O, 0, 1). Sekaligus kunci node grup, jadi kode
  /// itu memang rahasianya.
  static String newCode() {
    const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rnd = math.Random.secure();
    return 'KLR-${List.generate(4, (_) => alphabet[rnd.nextInt(alphabet.length)]).join()}';
  }

  // ── Grup ─────────────────────────────────────────────────────────────────

  /// Daftarkan grup baru; penulis jadi adminUid.
  Future<void> createGroup({
    required String code,
    required String name,
    required String sport,
    required double targetKm,
    required String myName,
  }) async {
    final ref = _need(code);
    await ref.child('meta').set({
      'name': name,
      'sport': sport,
      'targetKm': targetKm,
      'adminUid': _uid,
      'createdMs': DateTime.now().millisecondsSinceEpoch,
    });
    // Baris admin WAJIB ada di members/{auth.uid}: aturan `.read` memeriksa
    // tepat kunci itu, jadi tanpa ini pembuatnya sendiri tidak bisa membaca.
    await putMember(code, name: myName, role: 'admin');
  }

  Future<void> putMember(String code,
          {required String name, String role = 'member'}) =>
      _need(code).child('members/$_uid').update({
        'name': name,
        'role': role,
        'joinedMs': DateTime.now().millisecondsSinceEpoch,
      });

  /// Bergabung: tulis diri dulu (Rules mengizinkan tanpa keanggotaan
  /// sebelumnya), baru grupnya bisa dibaca. Null kalau kode tidak ada.
  Future<CloudGroup?> join(String code, String myName) async {
    await putMember(code, name: myName);
    final g = await fetchGroup(code);
    if (g == null) {
      // Kode salah: bersihkan baris yang baru ditulis supaya tidak
      // meninggalkan anggota nyangkut di node kosong.
      await _need(code).child('members/$_uid').remove();
    }
    return g;
  }

  Future<CloudGroup?> fetchGroup(String code) async {
    final snap = await _need(code).child('meta').get();
    if (!snap.exists) return null;
    final m = _map(snap.value);
    if ((m['name'] as String? ?? '').isEmpty) return null;
    return CloudGroup(
      code: code,
      name: m['name'] as String,
      sport: m['sport'] as String? ?? 'run',
      adminUid: m['adminUid'] as String?,
      targetKm: (m['targetKm'] as num?)?.toDouble() ?? 500,
    );
  }

  Future<void> putMeta(String code,
          {required String name, required String sport, required double targetKm}) =>
      _need(code)
          .child('meta')
          .update({'name': name, 'sport': sport, 'targetKm': targetKm});

  /// Keluarkan anggota. [ban] mencekalnya supaya tidak bisa mendaftar ulang
  /// dengan kode yang masih dia pegang — tanpa itu, mengeluarkan tidak berlaku.
  Future<void> removeMember(String code, String memberUid, {bool ban = false}) async {
    final ref = _need(code);
    await ref.child('members/$memberUid').remove();
    // Posisinya juga dihapus; kalau tidak markernya menggantung di peta
    // anggota lain sampai ada yang menimpanya.
    await ref.child('live/$memberUid').remove();
    await ref.child('stats/$memberUid').remove();
    if (ban) await ref.child('banned/$memberUid').set(true);
  }

  Future<void> leave(String code) => removeMember(code, _uid!);

  Future<void> deleteGroup(String code) => _need(code).remove();

  /// Anggota + lokasi live + agregat, satu stream. Tiga node diawasi terpisah
  /// lalu digabung: mengawasi `keluarr/$code` utuh berarti tiap kiriman posisi
  /// mengirim ulang seluruh daftar anggota dan statistik ke semua orang.
  Stream<CloudRoster> watchRoster(String code) {
    final ref = _need(code);
    return _combine3(
      ref.child('members').onValue,
      ref.child('live').onValue,
      ref.child('stats').onValue,
      (members, live, stats) {
        final pos = <String, LivePos>{};
        for (final e in _map(live).entries) {
          final p = _parseLive(e.value);
          if (p != null) pos[e.key] = p;
        }
        return CloudRoster(
          members: {
            for (final e in _map(members).entries)
              e.key: CloudMember(
                uid: e.key,
                name: _map(e.value)['name'] as String? ?? '—',
                role: _map(e.value)['role'] as String? ?? 'member',
              ),
          },
          live: pos,
          stats: {
            for (final e in _map(stats).entries)
              e.key: CloudStat(
                km: (_map(e.value)['km'] as num?)?.toDouble() ?? 0,
                count: (_map(e.value)['n'] as num?)?.toInt() ?? 0,
                sec: (_map(e.value)['sec'] as num?)?.toInt() ?? 0,
              ),
          },
        );
      },
    );
  }

  LivePos? _parseLive(Object? raw) {
    final v = _map(raw);
    final lat = (v['lat'] as num?)?.toDouble();
    final lng = (v['lng'] as num?)?.toDouble();
    if (lat == null || lng == null) return null;
    return LivePos(
      at: LatLng(lat, lng),
      speedKmh: (v['s'] as num?)?.toDouble() ?? 0,
      heading: (v['h'] as num?)?.toDouble() ?? 0,
      sport: v['sport'] as String? ?? 'run',
      state: v['st'] as String? ?? 'moving',
      atMs: (v['t'] as num?)?.toInt() ?? 0,
      online: v['online'] as bool? ?? false,
    );
  }

  // ── Lokasi live ──────────────────────────────────────────────────────────

  /// Kirim posisiku. Rules hanya mengizinkan menulis `live/{uid-ku}`, jadi
  /// tidak ada cara memalsukan posisi orang lain.
  Future<void> putLive(
    String code, {
    required double lat,
    required double lng,
    required double speedKmh,
    required double heading,
    required String sport,
    required String state,
  }) =>
      _need(code).child('live/$_uid').set({
        'lat': lat,
        'lng': lng,
        's': speedKmh.clamp(0, 200).roundToDouble(),
        'h': (heading % 360).clamp(0, 359).roundToDouble(),
        'sport': sport,
        'st': state,
        't': DateTime.now().millisecondsSinceEpoch,
        'online': true,
      });

  /// Titipkan ke server: begitu koneksiku putus, tandai aku offline. Server
  /// yang mengeksekusi, jadi tetap jalan walau app mati mendadak — inti dari
  /// deteksi "ada yang tertinggal / sinyal hilang".
  Future<void> markOfflineOnDisconnect(String code) =>
      _need(code).child('live/$_uid/online').onDisconnect().set(false);

  Future<void> clearLive(String code) async {
    final ref = _need(code).child('live/$_uid');
    await ref.onDisconnect().cancel();
    await ref.remove();
  }

  /// Agregat bulanan untuk leaderboard: angka saja, tanpa titik GPS.
  /// Hanya dipanggil kalau pengguna mengizinkan (layar 19 · "Total km").
  Future<void> putStats(String code,
          {required double km, required int count, required int sec}) =>
      _need(code)
          .child('stats/$_uid')
          .set({'km': double.parse(km.toStringAsFixed(2)), 'n': count, 'sec': sec});

  Future<void> clearStats(String code) =>
      _need(code).child('stats/$_uid').remove();

  static bool isPermissionDenied(Object e) {
    if (e is FirebaseException) {
      if (e.code.contains('permission-denied')) return true;
      return (e.message ?? '').toLowerCase().contains('permission denied');
    }
    return e.toString().toLowerCase().contains('permission denied');
  }

  DatabaseReference _need(String? code) {
    final r = _root;
    if (r == null) throw StateError('Firebase belum siap.');
    if (code == null || code.isEmpty) {
      throw StateError('Grup ini belum ada di server.');
    }
    return r.child(code);
  }

  /// RTDB mengembalikan `Map<Object?, Object?>`; rapikan jadi berkunci String.
  Map<String, Object?> _map(Object? v) => v is Map
      ? {for (final e in v.entries) e.key.toString(): e.value}
      : const {};
}

/// Gabung tiga stream: keluarkan hasil begitu ketiganya pernah datang, lalu
/// tiap perubahan berikutnya. Tanpa menunggu ketiganya, roster setengah jadi
/// (anggota ada, posisi belum) sempat terlihat dan markernya berkedip.
Stream<R> _combine3<A, B, C, R>(
  Stream<A> a,
  Stream<B> b,
  Stream<C> c,
  R Function(Object?, Object?, Object?) build,
) {
  Object? va, vb, vc;
  var seen = 0;
  final out = StreamController<R>();
  final subs = <StreamSubscription<Object?>>[];
  void emit() {
    if (seen < 3) return;
    out.add(build(va, vb, vc));
  }

  out.onListen = () {
    subs.addAll([
      a.listen((e) {
        if (va == null) seen++;
        va = (e as DatabaseEvent).snapshot.value ?? const {};
        emit();
      }, onError: out.addError),
      b.listen((e) {
        if (vb == null) seen++;
        vb = (e as DatabaseEvent).snapshot.value ?? const {};
        emit();
      }, onError: out.addError),
      c.listen((e) {
        if (vc == null) seen++;
        vc = (e as DatabaseEvent).snapshot.value ?? const {};
        emit();
      }, onError: out.addError),
    ]);
  };
  out.onCancel = () async {
    for (final s in subs) {
      await s.cancel();
    }
    subs.clear();
  };
  return out.stream;
}

class CloudGroup {
  const CloudGroup({
    required this.code,
    required this.name,
    required this.sport,
    required this.adminUid,
    required this.targetKm,
  });

  final String code;
  final String name;
  final String sport;
  final String? adminUid;
  final double targetKm;
}

class CloudMember {
  const CloudMember({required this.uid, required this.name, required this.role});

  final String uid;
  final String name;
  final String role;
}

class CloudStat {
  const CloudStat({required this.km, required this.count, required this.sec});

  final double km;
  final int count;
  final int sec;
}

class LivePos {
  const LivePos({
    required this.at,
    required this.speedKmh,
    required this.heading,
    required this.sport,
    required this.state,
    required this.atMs,
    required this.online,
  });

  final LatLng at;
  final double speedKmh;

  /// Derajat, 0 = utara. Dipakai menghitung siapa paling depan (lihat pack.dart).
  final double heading;
  final String sport;

  /// moving · paused
  final String state;
  final int atMs;
  final bool online;

  DateTime get when => DateTime.fromMillisecondsSinceEpoch(atMs);
}

class CloudRoster {
  const CloudRoster(
      {required this.members, required this.live, required this.stats});

  final Map<String, CloudMember> members;
  final Map<String, LivePos> live;
  final Map<String, CloudStat> stats;
}
