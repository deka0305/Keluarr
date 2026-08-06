import 'dart:math' as math;
import 'dart:ui' show Offset;

import 'package:latlong2/latlong.dart' hide Path;

import 'polyline.dart';

// roundResult:false WAJIB. Default Distance() membulatkan hasil ke satuan
// bulat, jadi as(Kilometer) pada segmen 40 m mengembalikan 0 — dan fix GPS
// datang tiap beberapa detik, sehingga total jaraknya jadi 0 km.
const dist = Distance(roundResult: false);

/// Jejak GPS satu aktivitas: yang benar-benar dilalui.
///
/// **Lokal saja** — tidak pernah dikirim ke grup atau server (aturan tetap di
/// layar 19). Titik diperkecil ke satu per [_minMeters] supaya rute 40 km jadi
/// ~500 titik ≈ 10 KB sebagai encoded polyline; menyimpan tiap fix mentah jadi
/// puluhan ribu titik tanpa menambah ketelitian garis yang terlihat.
class Track {
  Track({List<LatLng>? points, double km = 0, this.startedAt})
      : points = points ?? [],
        _km = km;

  /// 25 m — lebih rapat dari touring (200 m) karena rute lari cuma beberapa km
  /// dan tikungannya kecil; 6 km lari ≈ 240 titik ≈ 5 KB.
  static const _minMeters = 25.0;

  /// Jeda antar-fix lebih lama dari ini bukan waktu bergerak: app ditutup,
  /// HP dikantongi tanpa sinyal, atau berhenti panjang.
  static const _maxGap = Duration(minutes: 2);

  /// Auto-pause: di bawah kecepatan ini dianggap berhenti (rule desain 07).
  static const autoPauseKmh = 1.0;

  final List<LatLng> points;

  /// Detik sejak [startedAt] untuk tiap titik di [points], sejajar indeksnya.
  final List<int> secs = [];

  double _km;
  double _secsMoving = 0;
  double _elevGain = 0;
  double? _lastAlt;
  DateTime? startedAt;
  DateTime? updatedAt;
  DateTime? _lastFixAt;
  LatLng? _lastFix;

  /// Kecepatan tertinggi (km/j) dan kecepatan fix terakhir.
  double topKmh = 0;
  double lastKmh = 0;

  /// Jarak tempuh (km), dijumlahkan dari semua fix — termasuk yang tidak
  /// disimpan sebagai titik, jadi lebih teliti daripada menjumlahkan [points].
  double get km => _km;
  double get elevGainM => _elevGain;
  bool get isEmpty => points.length < 2;

  /// Lama bergerak: jumlah jeda antar-fix, tanpa jeda yang lebih panjang dari
  /// [_maxGap]. Sengaja BUKAN `updatedAt - startedAt`.
  Duration get moving => Duration(seconds: _secsMoving.round());

  double get avgKmh {
    final h = moving.inSeconds / 3600;
    return h <= 0 ? 0 : _km / h;
  }

  /// Split per km: detik yang dipakai untuk km ke-1, ke-2, dst. Diturunkan dari
  /// [secs] supaya angkanya berasal dari waktu nyata, bukan interpolasi jarak.
  List<(int km, int paceSec)> get splits {
    if (points.length < 2) return const [];
    final out = <(int, int)>[];
    var acc = 0.0, prevSec = 0, nextKm = 1;
    for (var i = 1; i < points.length; i++) {
      acc += dist.as(LengthUnit.Meter, points[i - 1], points[i]) / 1000;
      if (acc >= nextKm) {
        final sec = i < secs.length ? secs[i] : prevSec;
        out.add((nextKm, sec - prevSec));
        prevSec = sec;
        nextKm++;
      }
    }
    return out;
  }

  /// Catat satu fix. Mengembalikan true kalau fix ini dianggap bergerak
  /// (di atas [autoPauseKmh]) — dipakai untuk auto-pause.
  bool add(LatLng at, double speedKmh, DateTime now, {double? altitude}) {
    startedAt ??= now;
    updatedAt = now;
    if (speedKmh.isFinite && speedKmh >= 0) {
      lastKmh = speedKmh;
      topKmh = math.max(topKmh, speedKmh);
    }

    if (altitude != null && altitude.isFinite) {
      final prevAlt = _lastAlt;
      // Ambang 2 m menyaring derau altimeter; tanpa itu jalan datar pun
      // menumpuk elevasi ratusan meter.
      if (prevAlt != null && altitude - prevAlt > 2) {
        _elevGain += altitude - prevAlt;
      }
      if (prevAlt == null || (altitude - prevAlt).abs() > 2) _lastAlt = altitude;
    }

    final prevAt = _lastFixAt;
    _lastFixAt = now;
    if (prevAt != null) {
      final gap = now.difference(prevAt);
      if (gap > Duration.zero && gap <= _maxGap) {
        _secsMoving += gap.inMilliseconds / 1000;
      }
    }

    final prev = _lastFix;
    if (prev == null) {
      _lastFix = at;
      if (points.isEmpty) _push(at, now);
      return speedKmh >= autoPauseKmh;
    }

    final meters = dist.as(LengthUnit.Meter, prev, at);
    // Lompatan liar dari GPS yang baru fix — jangan dihitung sebagai jarak.
    if (meters > 2000) return false;

    _km += meters / 1000;
    _lastFix = at;
    if (points.isEmpty || dist.as(LengthUnit.Meter, points.last, at) >= _minMeters) {
      _push(at, now);
    }
    return speedKmh >= autoPauseKmh;
  }

  void _push(LatLng at, DateTime now) {
    points.add(at);
    secs.add(now.difference(startedAt!).inSeconds);
  }

  Map<String, dynamic> toJson() => {
        'geom': encodePolyline(points),
        'secs': secs,
        'km': _km,
        'top': topKmh,
        'moving': _secsMoving,
        'elev': _elevGain,
        if (startedAt != null) 'start': startedAt!.toIso8601String(),
        if (updatedAt != null) 'end': updatedAt!.toIso8601String(),
      };

  static Track fromJson(Map<String, dynamic> j) {
    final t = Track(
      points: decodePolyline(j['geom'] as String? ?? ''),
      km: (j['km'] as num?)?.toDouble() ?? 0,
      startedAt:
          j['start'] == null ? null : DateTime.parse(j['start'] as String),
    );
    t.secs.addAll([for (final v in (j['secs'] as List? ?? [])) v as int]);
    t.topKmh = (j['top'] as num?)?.toDouble() ?? 0;
    t._secsMoving = (j['moving'] as num?)?.toDouble() ?? 0;
    t._elevGain = (j['elev'] as num?)?.toDouble() ?? 0;
    t.updatedAt = j['end'] == null ? null : DateTime.parse(j['end'] as String);
    if (t.points.isNotEmpty) t._lastFix = t.points.last;
    return t;
  }
}

/// Kotak pembatas + proyeksi titik ke ruang 0..1 untuk digambar CustomPaint
/// (thumbnail riwayat & kartu share). Dipakai supaya jejak apa pun tetap pas
/// di kanvas tanpa peta.
List<Offset> normalize(List<LatLng> pts) {
  if (pts.isEmpty) return const [];
  var minLat = pts.first.latitude, maxLat = minLat;
  var minLng = pts.first.longitude, maxLng = minLng;
  for (final p in pts) {
    minLat = math.min(minLat, p.latitude);
    maxLat = math.max(maxLat, p.latitude);
    minLng = math.min(minLng, p.longitude);
    maxLng = math.max(maxLng, p.longitude);
  }
  // Jaga rasio aspek: tanpa ini rute lurus utara-selatan jadi melar melebar.
  final spanLat = math.max(maxLat - minLat, 1e-5);
  final spanLng = math.max(maxLng - minLng, 1e-5);
  final span = math.max(spanLat, spanLng);
  final padX = (span - spanLng) / 2, padY = (span - spanLat) / 2;
  return [
    for (final p in pts)
      Offset(
        (p.longitude - minLng + padX) / span,
        // Lintang naik ke utara, sumbu-y kanvas naik ke bawah.
        1 - (p.latitude - minLat + padY) / span,
      ),
  ];
}
