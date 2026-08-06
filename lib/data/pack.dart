import 'dart:math' as math;

import 'package:latlong2/latlong.dart' hide Path;

/// Posisi relatif dalam rombongan: siapa paling depan, siapa tertinggal, dan
/// berapa rentangnya.
///
/// Tanpa rute rencana, "depan" tidak bisa diambil dari kemajuan sepanjang rute
/// seperti app touring. Yang dipakai di sini: semua posisi diproyeksikan ke
/// **arah gerak rata-rata rombongan** (rata-rata heading anggota yang sedang
/// bergerak). Proyeksi terbesar = paling depan. Ini yang membuat "1,8 km di
/// belakang" berarti jarak sepanjang arah jalan, bukan jarak lurus antar dua
/// orang yang kebetulan berhenti di sisi jalan berbeda.
class Pack {
  const Pack({required this.offsets, required this.spreadM});

  /// uid → meter relatif terhadap titik terbelakang rombongan (selalu ≥ 0).
  final Map<String, double> offsets;
  final double spreadM;

  double get spreadKm => spreadM / 1000;

  String? get frontUid => _pick((a, b) => a >= b);
  String? get backUid => _pick((a, b) => a <= b);

  String? _pick(bool Function(double, double) better) {
    String? best;
    for (final e in offsets.entries) {
      if (best == null || better(e.value, offsets[best]!)) best = e.key;
    }
    return best;
  }

  static const empty = Pack(offsets: {}, spreadM: 0);
}

/// [positions] uid → posisi, [headings] uid → arah (derajat, 0 = utara) untuk
/// anggota yang sedang bergerak. Heading kosong → dipakai arah dari titik
/// terjauh ke terdekat sebagai sumbu, sehingga rombongan yang berhenti tetap
/// punya urutan yang stabil.
Pack computePack(Map<String, LatLng> positions, Map<String, double> headings) {
  if (positions.length < 2) {
    return positions.isEmpty
        ? Pack.empty
        : Pack(offsets: {positions.keys.first: 0}, spreadM: 0);
  }

  // Titik acuan untuk konversi lat/lng → meter (equirectangular; galatnya di
  // bawah 0,1% untuk rombongan sepanjang puluhan km).
  final lat0 = positions.values.map((p) => p.latitude).reduce((a, b) => a + b) /
      positions.length;
  final lng0 = positions.values.map((p) => p.longitude).reduce((a, b) => a + b) /
      positions.length;
  const mPerDegLat = 111320.0;
  final mPerDegLng = mPerDegLat * math.cos(lat0 * math.pi / 180);

  final xy = {
    for (final e in positions.entries)
      e.key: (
        (e.value.longitude - lng0) * mPerDegLng,
        (e.value.latitude - lat0) * mPerDegLat,
      ),
  };

  // Sumbu arah: rata-rata vektor heading (dijumlah sebagai vektor supaya 350°
  // dan 10° tidak jadi 180°).
  var ax = 0.0, ay = 0.0;
  for (final h in headings.values) {
    final r = h * math.pi / 180;
    ax += math.sin(r);
    ay += math.cos(r);
  }
  if (ax.abs() < 1e-9 && ay.abs() < 1e-9) {
    // Semua berhenti: pakai sumbu sebaran terpanjang.
    var bestD = -1.0;
    for (final a in xy.values) {
      for (final b in xy.values) {
        final dx = b.$1 - a.$1, dy = b.$2 - a.$2;
        final d = dx * dx + dy * dy;
        if (d > bestD) {
          bestD = d;
          ax = dx;
          ay = dy;
        }
      }
    }
  }
  final len = math.sqrt(ax * ax + ay * ay);
  if (len < 1e-9) {
    return Pack(offsets: {for (final k in positions.keys) k: 0}, spreadM: 0);
  }
  ax /= len;
  ay /= len;

  final proj = {for (final e in xy.entries) e.key: e.value.$1 * ax + e.value.$2 * ay};
  final min = proj.values.reduce(math.min);
  final max = proj.values.reduce(math.max);
  return Pack(
    offsets: {for (final e in proj.entries) e.key: e.value - min},
    spreadM: max - min,
  );
}
