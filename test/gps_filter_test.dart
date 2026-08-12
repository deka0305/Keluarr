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
}
