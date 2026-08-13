import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' hide Path;

import 'cloud.dart';
import 'track.dart';

/// Hasil percobaan menyalakan GPS.
enum GpsResult {
  ok,

  /// GPS jalan, tapi posisi tidak dikirim ke grup (belum ada grup, server
  /// tidak terjangkau, atau berbagi lokasi dimatikan di layar 19). Perekaman
  /// rute tetap penuh — itu memang milik pribadi.
  tanpaServer,
  ditolak,
  ditolakPermanen,
  layananMati,
}

/// Pembaca GPS: satu-satunya sumber fix untuk perekaman rute **dan** untuk
/// kiriman lokasi live.
///
/// Dua kanal itu sengaja dipisah tegas:
/// * [onFix] → jejak lokal, dipanggil untuk **setiap** fix.
/// * [Cloud.putLive] → grup, disaring interval + jarak minimum supaya kuota
///   Firebase tetap kecil dan anggota yang berhenti hampir tidak memakai apa pun.
class Gps {
  Gps(this._cloud);

  Cloud _cloud;

  set cloud(Cloud c) => _cloud = c;

  static const _minInterval = Duration(seconds: 10);
  static const _minMeters = 20;

  /// Setelan pembacaan. distanceFilter dikerjakan OS — hemat baterai karena
  /// callback tidak dipanggil untuk pergeseran kecil.
  ///
  /// Di Android dipakai foreground service: tanpa itu sistem membekukan app
  /// beberapa menit setelah layar mati, dan jejaknya berhenti persis saat HP
  /// masuk kantong — kondisi normal sepanjang lari.
  @visibleForTesting
  static LocationSettings settings() {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return const LocationSettings(accuracy: LocationAccuracy.best, distanceFilter: 5);
    }
    return AndroidSettings(
      accuracy: LocationAccuracy.best,
      distanceFilter: 5,
      foregroundNotificationConfig: const ForegroundNotificationConfig(
        notificationTitle: 'Merekam rute',
        notificationText: 'Jejak GPS dicatat walau layar mati · tersimpan pribadi',
        notificationChannelName: 'Rekam rute',
        // Wake lock menjaga fix datang satu per satu. Tanpa itu Android
        // menahannya lalu mengirim menumpuk saat layar dinyalakan, dan jejak
        // di antaranya jadi garis lurus.
        enableWakeLock: true,
        setOngoing: true,
      ),
    );
  }

  StreamSubscription<Position>? _sub;
  Timer? _heartbeat;
  String? _code;
  LatLng? _lastSent;
  DateTime? _lastSentAt;

  /// Dipanggil untuk setiap fix — dipakai [Track] untuk merekam rute.
  void Function(LatLng at, double speedKmh, double? altitude)? onFix;

  /// Status yang dikirim ke grup: moving / paused.
  String state = 'moving';
  String sport = 'run';

  /// Sesuai layar 19: kalau dimatikan, anggota lain tetap lihat titikmu
  /// tapi tanpa status/kecepatan sungguhan.
  bool shareStatus = true;
  bool shareSpeed = true;

  bool get running => _sub != null;

  /// Kode grup yang posisinya sedang dikirim, null kalau hanya merekam lokal.
  String? get sharingCode => _code;

  /// Mulai membaca GPS. [code] null atau [share] false → GPS tetap jalan, tapi
  /// tidak ada yang dikirim ke anggota lain.
  Future<GpsResult> start({String? code, bool share = true}) async {
    await stop();

    if (!await Geolocator.isLocationServiceEnabled()) {
      return GpsResult.layananMati;
    }
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.deniedForever) {
      return GpsResult.ditolakPermanen;
    }
    if (perm == LocationPermission.denied) return GpsResult.ditolak;

    final bisaKirim = share && code != null && _cloud.ready;
    _code = bisaKirim ? code : null;
    if (bisaKirim) {
      // Titipkan penanda offline SEBELUM mulai mengirim, supaya sinyal yang
      // putus di kiriman pertama pun tetap terdeteksi anggota lain.
      try {
        await _cloud.markOfflineOnDisconnect(code);
      } catch (e) {
        debugPrint('gps: onDisconnect gagal ($e)');
      }
    }

    _sub = Geolocator.getPositionStream(locationSettings: settings())
        .listen(_onFix, onError: (Object e) => debugPrint('gps: stream error ($e)'));

    // Yang berhenti tidak menghasilkan fix baru, jadi posisinya dianggap
    // kedaluwarsa. Denyut ini menjaganya terlihat hidup tanpa harus bergerak.
    _heartbeat = Timer.periodic(const Duration(seconds: 45), (_) => _repeat());
    return bisaKirim ? GpsResult.ok : GpsResult.tanpaServer;
  }

  Future<void> stop() async {
    final code = _code;
    _code = null;
    _lastSent = null;
    _lastSentAt = null;
    _lastGood = null;
    await _sub?.cancel();
    _sub = null;
    _heartbeat?.cancel();
    _heartbeat = null;
    if (code == null) return;
    try {
      await _cloud.clearLive(code);
    } catch (e) {
      debugPrint('gps: gagal membersihkan live ($e)');
    }
  }

  /// Akurasi terburuk yang masih dipercaya. Di atas ini fix biasanya hasil
  /// triangulasi menara/WiFi dan letaknya meleset puluhan meter — itulah yang
  /// terlihat sebagai titik meloncat.
  static const _maxAccuracy = 30.0;

  /// 40 m/s ≈ 144 km/h. Di atas itu bukan orang berlari, tapi fix melenceng.
  static const _maxSpeedMps = 40.0;

  /// Kalau sinyal jelek berkepanjangan, fix buruk tetap diterima setelah jeda
  /// ini — lebih baik posisi kasar daripada peta yang membeku.
  static const _staleAfter = Duration(seconds: 30);

  Position? _lastGood;

  /// Fix yang jelas tidak masuk akal dibuang di sini, satu tempat, supaya
  /// jejak, kiriman ke grup, dan marker peta sama-sama bersih.
  @visibleForTesting
  static bool plausible(Position? prev, Position pos) {
    if (prev == null) return true;
    final secs =
        pos.timestamp.difference(prev.timestamp).inMilliseconds / 1000;
    if (secs <= 0) return false;
    if (secs > _staleAfter.inSeconds) return true;
    if (pos.accuracy.isFinite && pos.accuracy > _maxAccuracy) return false;
    final meters = Geolocator.distanceBetween(
        prev.latitude, prev.longitude, pos.latitude, pos.longitude);
    return meters / secs <= _maxSpeedMps;
  }

  /// Kecepatan fix dalam km/j.
  ///
  /// Tidak semua perangkat mengisi `speed` — fix dari fused/network provider
  /// tanpa lock GNSS sering mengembalikan 0. Kalau angka itu dipercaya apa
  /// adanya, seluruh deteksi gerak membaca "diam": auto-pause menyala setelah
  /// 20 detik lalu **tidak pernah lepas**, karena syarat lanjutnya juga
  /// kecepatan. Jarak dan jejak berhenti untuk sisa sesi.
  ///
  /// Jadi kalau perangkat diam soal kecepatan, turunkan sendiri dari jarak dan
  /// selisih waktu antar-fix — datanya memang sudah ada di tangan.
  @visibleForTesting
  static double speedKmh(Position? prev, Position pos) {
    if (pos.speed.isFinite && pos.speed > 0) return pos.speed * 3.6;
    if (prev == null) return 0;
    final secs = pos.timestamp.difference(prev.timestamp).inMilliseconds / 1000;
    if (secs <= 0) return 0;
    final meters = Geolocator.distanceBetween(
        prev.latitude, prev.longitude, pos.latitude, pos.longitude);
    return meters / secs * 3.6;
  }

  void _onFix(Position pos) {
    if (!plausible(_lastGood, pos)) return;
    final prev = _lastGood;
    _lastGood = pos;
    final at = LatLng(pos.latitude, pos.longitude);
    final kmh = speedKmh(prev, pos);
    if (pos.heading.isFinite) _lastHeading = pos.heading;

    // Jejak dicatat lebih dulu dan tanpa syarat: itu milik pengguna sendiri.
    onFix?.call(at, kmh, pos.altitude);

    if (_code == null) return;
    final now = DateTime.now();
    if (_lastSentAt != null && now.difference(_lastSentAt!) < _minInterval) return;
    if (_lastSent != null &&
        dist.as(LengthUnit.Meter, _lastSent!, at) < _minMeters) {
      return;
    }
    _lastSent = at;
    _lastSentAt = now;
    _push(at, kmh);
  }

  /// Kirim ulang posisi terakhir supaya anggota lain tahu aku masih hidup.
  /// Kecepatan 0 — bukan lewat _onFix, supaya titik yang sama tidak dicatat
  /// ulang ke jejak.
  void _repeat() {
    final at = _lastSent;
    if (at == null) return;
    _push(at, 0);
  }

  double _lastHeading = 0;

  void _push(LatLng at, double kmh) {
    final code = _code;
    if (code == null) return;
    _cloud
        .putLive(code,
            lat: at.latitude,
            lng: at.longitude,
            speedKmh: shareSpeed ? kmh : 0,
            heading: _lastHeading,
            sport: sport,
            state: shareStatus ? state : 'moving')
        .catchError((Object e) => debugPrint('gps: kirim gagal ($e)'));
  }

  static String pesan(GpsResult r) => switch (r) {
        GpsResult.ok => 'GPS aktif · lokasi dibagikan ke grup',
        GpsResult.tanpaServer => 'GPS aktif · rekaman lokal, lokasi tidak dibagikan',
        GpsResult.ditolak => 'Izin lokasi ditolak — perekaman tidak bisa jalan',
        GpsResult.ditolakPermanen =>
          'Izin lokasi diblokir. Buka Pengaturan aplikasi untuk mengizinkan.',
        GpsResult.layananMati => 'Nyalakan GPS/layanan lokasi dulu',
      };
}
