import 'package:latlong2/latlong.dart' hide Path;

/// GPX 1.1 dari jejak lokal. Dipakai untuk ekspor manual (layar 14 & 19) —
/// satu-satunya cara jejak keluar dari HP, dan itu selalu atas perintah
/// pengguna.
String toGpx({
  required String title,
  required DateTime startedAt,
  required List<LatLng> points,
  List<int> secs = const [],
}) {
  final b = StringBuffer()
    ..writeln('<?xml version="1.0" encoding="UTF-8"?>')
    ..writeln('<gpx version="1.1" creator="Keluarr" '
        'xmlns="http://www.topografix.com/GPX/1/1">')
    ..writeln('  <metadata><name>${_esc(title)}</name>'
        '<time>${startedAt.toUtc().toIso8601String()}</time></metadata>')
    ..writeln('  <trk><name>${_esc(title)}</name><trkseg>');
  for (var i = 0; i < points.length; i++) {
    final p = points[i];
    b.write('    <trkpt lat="${p.latitude.toStringAsFixed(6)}" '
        'lon="${p.longitude.toStringAsFixed(6)}">');
    if (i < secs.length) {
      final t = startedAt.add(Duration(seconds: secs[i])).toUtc();
      b.write('<time>${t.toIso8601String()}</time>');
    }
    b.writeln('</trkpt>');
  }
  b
    ..writeln('  </trkseg></trk>')
    ..writeln('</gpx>');
  return b.toString();
}

String _esc(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');
