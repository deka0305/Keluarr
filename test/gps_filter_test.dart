import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:keluarr/data/location.dart';

void main() {
  group('saringan fix GPS', () {
    final t0 = DateTime(2026, 1, 1, 8);
    Position fix(double lat, double lng, double acc, int detik) => Position(
          latitude: lat,
          longitude: lng,
          timestamp: t0.add(Duration(seconds: detik)),
          accuracy: acc,
          altitude: 0,
          altitudeAccuracy: 0,
          heading: 0,
          headingAccuracy: 0,
          speed: 0,
          speedAccuracy: 0,
        );

    final awal = fix(-6.2000, 106.8000, 5, 0);

    test('fix pertama selalu diterima', () {
      expect(Gps.plausible(null, awal), isTrue);
    });

    test('langkah wajar diterima', () {
      // ~11 m dalam 2 detik.
      expect(Gps.plausible(awal, fix(-6.2001, 106.8000, 5, 2)), isTrue);
    });

    test('akurasi buruk dibuang', () {
      expect(Gps.plausible(awal, fix(-6.2001, 106.8000, 80, 2)), isFalse);
    });

    test('loncatan jauh dibuang', () {
      // ~1,1 km dalam 2 detik.
      expect(Gps.plausible(awal, fix(-6.2100, 106.8000, 5, 2)), isFalse);
    });

    test('setelah lama tanpa fix, yang buruk pun diterima', () {
      expect(Gps.plausible(awal, fix(-6.2100, 106.8000, 80, 60)), isTrue);
    });
  });

  group('kecepatan fix', () {
    final t0 = DateTime(2026, 1, 1, 8);
    Position fix(double lat, int detik, {double speed = 0}) => Position(
          latitude: lat,
          longitude: 106.8,
          timestamp: t0.add(Duration(seconds: detik)),
          accuracy: 5,
          altitude: 0,
          altitudeAccuracy: 0,
          heading: 0,
          headingAccuracy: 0,
          speed: speed,
          speedAccuracy: 0,
        );

    test('pakai kecepatan perangkat kalau tersedia', () {
      // 3 m/s = 10,8 km/j.
      expect(Gps.speedKmh(fix(-6.2000, 0), fix(-6.2001, 2, speed: 3)),
          closeTo(10.8, 0.01));
    });

    test('perangkat diam soal kecepatan → diturunkan dari jarak/waktu', () {
      // ~11,1 m dalam 4 detik ≈ 2,78 m/s ≈ 10 km/j.
      final v = Gps.speedKmh(fix(-6.2000, 0), fix(-6.2001, 4));
      expect(v, greaterThan(8));
      expect(v, lessThan(12));
    });

    test('tanpa fix sebelumnya kecepatannya nol, bukan tak hingga', () {
      expect(Gps.speedKmh(null, fix(-6.2000, 0)), 0);
    });

    test('dua fix berwaktu sama tidak membagi nol', () {
      expect(Gps.speedKmh(fix(-6.2000, 5), fix(-6.2001, 5)), 0);
    });
  });
}
