import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;

import 'state.dart';
import 'theme.dart';

/// Kartu dasar: putih (atau #1B1F23 di gelap), border 1px, radius 16.
class Panel extends StatelessWidget {
  const Panel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
    this.radius = K.r,
    this.color,
    this.border,
    this.clip = false,
  });

  final Widget child;
  final EdgeInsets padding;
  final double radius;
  final Color? color;
  final Color? border;
  final bool clip;

  @override
  Widget build(BuildContext context) => Container(
        clipBehavior: clip ? Clip.antiAlias : Clip.none,
        padding: padding,
        decoration: BoxDecoration(
          color: color ?? context.card,
          border: Border.all(color: border ?? context.line, width: border == null ? 1 : 1.5),
          borderRadius: BorderRadius.circular(radius),
        ),
        child: child,
      );
}

/// Label data kapital Â· JetBrains Mono 9â€“11 Â· tracking 1.3.
class L extends StatelessWidget {
  const L(this.text, {super.key, this.size = 9.5, this.color, this.weight});

  final String text;
  final double size;
  final Color? color;
  final FontWeight? weight;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: mono(size,
            color: color ?? context.dim,
            track: 1.3,
            weight: weight ?? FontWeight.w500),
      );
}

class Mono extends StatelessWidget {
  const Mono(this.text,
      {super.key, this.size = 10.5, this.color, this.weight = FontWeight.w500, this.track = 0.5});

  final String text;
  final double size;
  final Color? color;
  final FontWeight weight;
  final double track;

  @override
  Widget build(BuildContext context) => Text(text,
      style: mono(size, color: color ?? context.dim, weight: weight, track: track));
}

/// Angka besar + label kecil di atasnya (kartu statistik).
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.label,
    required this.value,
    this.unit,
    this.size = 22,
    this.onDark = false,
  });

  final String label;
  final String value;
  final String? unit;
  final double size;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final fg = onDark ? Colors.white : context.fg;
    final dimC = onDark ? Colors.white70 : context.dim;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        L(label, size: 9, color: dimC),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(value,
                  style: TextStyle(
                      fontSize: size,
                      fontWeight: FontWeight.w800,
                      color: fg,
                      letterSpacing: -0.4)),
              if (unit != null) ...[
                const SizedBox(width: 4),
                Mono(unit!, size: 11, color: dimC),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Tombol utama tinggi 54, radius 16, shadow oranye.
class BigBtn extends StatelessWidget {
  const BigBtn(this.label,
      {super.key,
      this.onTap,
      this.icon,
      this.filled = true,
      this.height = K.btnH,
      this.monoLabel = false,
      this.color});

  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final bool filled;
  final double height;
  final bool monoLabel;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final bg = color ?? K.orange;
    final fg = filled ? Colors.white : context.fg;
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(K.r),
        child: Container(
          height: height,
          decoration: BoxDecoration(
            color: filled ? bg : context.card,
            border: filled ? null : Border.all(color: context.line),
            borderRadius: BorderRadius.circular(K.r),
            boxShadow: filled && bg == K.orange ? K.shadowOrange : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 19, color: fg),
                const SizedBox(width: 9),
              ],
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: monoLabel
                  ? Text(label,
                      style: mono(13.5, color: fg, weight: FontWeight.w700, track: 1.4))
                      : Text(label,
                          style: TextStyle(
                              fontSize: 15.5, fontWeight: FontWeight.w700, color: fg)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Chip pil (radius 99) â€” dipakai untuk filter, pilihan olahraga, toggle periode.
class Pill extends StatelessWidget {
  const Pill(this.label,
      {super.key,
      this.selected = false,
      this.onTap,
      this.selectedColor,
      this.color,
      this.monoStyle = true,
      this.size = 10.5});

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final Color? selectedColor;
  final Color? color;
  final bool monoStyle;
  final double size;

  @override
  Widget build(BuildContext context) {
    final sel = selectedColor ?? K.ink;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(99),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? sel : context.card,
          border: selected ? null : Border.all(color: context.line),
          borderRadius: BorderRadius.circular(99),
        ),
        child: monoStyle
            ? Text(label,
                style: mono(size,
                    color: selected ? Colors.white : (color ?? context.fg),
                    weight: selected ? FontWeight.w700 : FontWeight.w500,
                    track: 1))
            : Text(label,
                style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                    color: selected ? Colors.white : (color ?? context.fg))),
      ),
    );
  }
}

/// Badge kecil (AKTIF, LIVE, ADMINâ€¦).
class Badge2 extends StatelessWidget {
  const Badge2(this.label,
      {super.key, required this.fg, required this.bg, this.radius = 8});

  final String label;
  final Color fg;
  final Color bg;
  final double radius;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration:
            BoxDecoration(color: bg, borderRadius: BorderRadius.circular(radius)),
        child: Text(label,
            style: mono(9.5, color: fg, weight: FontWeight.w700, track: 1)),
      );
}

class Avatar extends StatelessWidget {
  const Avatar(this.initials,
      {super.key, this.color = K.orange, this.size = 40, this.radius, this.ring});

  final String initials;
  final Color color;
  final double size;
  final double? radius;
  final Color? ring;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(radius ?? size / 2),
          border: ring == null ? null : Border.all(color: ring!, width: 3),
        ),
        child: Text(initials,
            style: mono(size * .28,
                color: Colors.white, weight: FontWeight.w700, track: .5)),
      );
}

/// Baris switch. `locked` = tampil tapi permanen mati (janji privasi).
class SwitchRow extends StatelessWidget {
  const SwitchRow({
    super.key,
    required this.title,
    this.subtitle,
    required this.value,
    this.onChanged,
    this.locked = false,
    this.divider = true,
  });

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final bool locked;
  final bool divider;

  @override
  Widget build(BuildContext context) {
    final fg = locked ? context.dim : context.fg;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: divider
          ? BoxDecoration(border: Border(bottom: BorderSide(color: context.hair)))
          : null,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontSize: 14.5, fontWeight: FontWeight.w600, color: fg)),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(subtitle!,
                        style: TextStyle(fontSize: 11.5, color: context.dim)),
                  ),
              ],
            ),
          ),
          if (locked)
            Row(children: [
              Icon(Icons.lock_outline, size: 14, color: context.dim),
              const SizedBox(width: 6),
              L('OFF', color: context.dim),
            ])
          else
            Switch(
              value: value,
              onChanged: onChanged,
              activeThumbColor: Colors.white,
              activeTrackColor: K.orange,
              inactiveThumbColor: Colors.white,
              inactiveTrackColor: context.isDark ? K.lineD : const Color(0xFFE6E2DA),
              trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
            ),
        ],
      ),
    );
  }
}

/// Baris menu dengan chevron / nilai di kanan.
class MenuRow extends StatelessWidget {
  const MenuRow(this.title,
      {super.key,
      this.icon,
      this.trailing,
      this.onTap,
      this.color,
      this.divider = true,
      this.chevron = true});

  final String title;
  final IconData? icon;
  final String? trailing;
  final VoidCallback? onTap;
  final Color? color;
  final bool divider;
  final bool chevron;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 13),
          decoration: divider
              ? BoxDecoration(border: Border(bottom: BorderSide(color: context.hair)))
              : null,
          child: Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: color ?? context.fg),
                const SizedBox(width: 11),
              ],
              Expanded(
                child: Text(title,
                    style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: color ?? context.fg)),
              ),
              if (trailing != null) Mono(trailing!, size: 10.5),
              if (chevron && trailing == null)
                Icon(Icons.chevron_right, size: 18, color: context.dim),
            ],
          ),
        ),
      );
}

/// Bar chart kecil (kecepatan per km, jarak per minggu).
class Bars extends StatelessWidget {
  const Bars({super.key, required this.values, required this.labels, this.height = 60});

  final List<double> values;
  final List<String> labels;
  final double height;

  @override
  Widget build(BuildContext context) {
    final maxV = values.isEmpty ? 1.0 : values.reduce((a, b) => a > b ? a : b);
    Color tone(double v) {
      final r = maxV == 0 ? 0 : v / maxV;
      return r > .8 ? K.orange : (r > .55 ? K.orangeMid : K.orangePale);
    }

    return Column(
      children: [
        SizedBox(
          height: height,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final (i, v) in values.indexed) ...[
                if (i > 0) const SizedBox(width: 7),
                Expanded(
                  child: Container(
                    height: maxV == 0 ? 2 : (v / maxV * height).clamp(2, height),
                    decoration: BoxDecoration(
                      color: tone(v),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 7),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [for (final l in labels) L(l, size: 9)],
        ),
      ],
    );
  }
}

/// Baris progres split per km.
class SplitRow extends StatelessWidget {
  const SplitRow(this.split, {super.key, required this.best, this.divider = true});

  final KmSplit split;
  final int best;
  final bool divider;

  @override
  Widget build(BuildContext context) {
    final ratio = split.paceSec == 0 ? 0.0 : (best / split.paceSec).clamp(0.2, 1.0);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: divider
          ? BoxDecoration(border: Border(bottom: BorderSide(color: context.hair)))
          : null,
      child: Row(
        children: [
          SizedBox(width: 44, child: Mono('KM ${split.km}', size: 10.5)),
          Expanded(
            child: Container(
              height: 7,
              margin: const EdgeInsets.only(right: 11),
              decoration: BoxDecoration(
                  color: context.fill, borderRadius: BorderRadius.circular(99)),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: ratio,
                child: Container(
                  decoration: BoxDecoration(
                      color: ratio > .9
                          ? K.orange
                          : (ratio > .7 ? K.orangeMid : K.orangePale),
                      borderRadius: BorderRadius.circular(99)),
                ),
              ),
            ),
          ),
          Text(fmtPace(split.paceSec),
              style: mono(11.5, color: context.fg, weight: FontWeight.w700, track: .4)),
        ],
      ),
    );
  }
}

/// Bar progres tipis (target grup, distribusi olahraga).
class Meter extends StatelessWidget {
  const Meter(this.ratio, {super.key, this.height = 10, this.color = K.orange});

  final double ratio;
  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        height: height,
        decoration:
            BoxDecoration(color: context.fill, borderRadius: BorderRadius.circular(99)),
        child: FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: ratio.clamp(0, 1),
          child: Container(
            decoration:
                BoxDecoration(color: color, borderRadius: BorderRadius.circular(99)),
          ),
        ),
      );
}

class KNav extends StatelessWidget {
  const KNav({super.key, required this.index, required this.onTap});

  final int index;
  final ValueChanged<int> onTap;

  static const items = [
    (0, 'PETA', Icons.my_location),
    (1, 'TIM', Icons.groups_outlined),
    (2, 'REKAM', Icons.radio_button_checked),
    (3, 'GRUP', Icons.add_circle_outline),
    (4, 'REKAP', Icons.history),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.isDark ? const Color(0xFF15181B) : Colors.white,
        border: Border(
            top: BorderSide(
                color: context.isDark ? const Color(0xFF282D32) : const Color(0xFFE6E2DA))),
      ),
      padding: const EdgeInsets.fromLTRB(6, 6, 6, 8),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            for (final (i, label, icon) in items)
              Expanded(
                child: InkWell(
                  onTap: () => onTap(i),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(0, 7, 0, 4),
                    decoration: BoxDecoration(
                      color: i == index
                          ? (context.isDark ? const Color(0x29FF6A13) : K.orangeSoft)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icon,
                            size: 20,
                            color: i == index ? K.orange : context.dim),
                        const SizedBox(height: 3),
                        Text(label,
                            style: mono(9,
                                color: i == index ? K.orange : context.dim,
                                track: 1.2)),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Peta ────────────────────────────────────────────────────────────────────

/// Peta OSM: gratis dan tanpa API key. Kebijakan tile mereka menuntut
/// User-Agent yang jelas dan atribusi terlihat — keduanya dipenuhi di bawah.
const _tileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
const _tileUa = 'com.keluarr.keluarr';

/// Matriks pembalik warna untuk tema gelap. Jauh lebih murah daripada
/// berlangganan tile gelap berbayar, dan hasilnya cukup dekat dengan mockup 05.
const _darkTiles = ColorFilter.matrix(<double>[
  -0.95, 0, 0, 0, 245,
  0, -0.95, 0, 0, 245,
  0, 0, -0.95, 0, 245,
  0, 0, 0, 1, 0,
]);

/// Marker anggota / titik di peta. `at` = lokasi live — **bukan** jejak rute
/// mereka; jejak hanya digambar untuk diri sendiri.
class MapPin {
  const MapPin({
    required this.at,
    required this.initials,
    required this.color,
    this.label,
    this.size = 34,
    this.labelBelow = true,
    this.highlight = false,
    this.onTap,
  });

  final LatLng at;
  final String initials;
  final Color color;
  final String? label;
  final double size;
  final bool labelBelow;
  final bool highlight;
  final VoidCallback? onTap;
}

class _Pin extends StatelessWidget {
  const _Pin(this.pin);

  final MapPin pin;

  @override
  Widget build(BuildContext context) {
    final chip = pin.label == null
        ? const SizedBox.shrink()
        : Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: pin.highlight ? K.ink : context.card,
              border: pin.highlight ? null : Border.all(color: context.line),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Text(pin.label!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: mono(9,
                    color: pin.highlight ? Colors.white : context.fg, track: .3)),
          );
    final dot = Container(
      width: pin.size,
      height: pin.size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: pin.color,
        shape: BoxShape.circle,
        border: Border.all(color: context.isDark ? K.bgD : Colors.white, width: 3),
        boxShadow: const [
          BoxShadow(color: Color(0x38141618), blurRadius: 12, offset: Offset(0, 4))
        ],
      ),
      child: Text(pin.initials,
          style:
              mono(pin.size * .3, color: Colors.white, weight: FontWeight.w700, track: .3)),
    );
    return GestureDetector(
      onTap: pin.onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: pin.labelBelow
            ? [dot, const SizedBox(height: 4), Flexible(child: chip)]
            : [Flexible(child: chip), const SizedBox(height: 4), dot],
      ),
    );
  }
}

/// Peta live: tile OSM + jejak GPS pribadi + marker anggota.
class LiveMap extends StatelessWidget {
  const LiveMap({
    super.key,
    this.route = const [],
    this.markers = const [],
    this.controller,
    this.center,
    this.zoom = 15,
    this.showRoute = true,
    this.dashed = false,
    this.interactive = true,
    this.fitRoute = false,
    this.overlays = const [],
    this.dim = false,
    this.attribution = true,
  });

  /// Matikan unduhan tile — dipakai widget test supaya tidak ada permintaan
  /// jaringan (di test HTTP diblokir dan tiap tile jadi error).
  static bool tilesEnabled = true;

  /// Jejakku sendiri. Kosong = belum merekam.
  final List<LatLng> route;
  final List<MapPin> markers;
  final MapController? controller;
  final LatLng? center;
  final double zoom;
  final bool showRoute;

  /// Putus-putus = jejak rekaman lampau (mockup 04), penuh = sedang merekam.
  final bool dashed;
  final bool interactive;

  /// Pas-kan kamera ke seluruh jejak saat dibuka (ringkasan & detail).
  final bool fitRoute;
  final List<Widget> overlays;
  final bool dim;
  final bool attribution;

  @override
  Widget build(BuildContext context) {
    final pts = showRoute ? route : const <LatLng>[];
    final focus = center ??
        (route.isNotEmpty ? route.last : null) ??
        (markers.isNotEmpty ? markers.first.at : kFallbackCenter);

    return Stack(
      clipBehavior: Clip.hardEdge,
      children: [
        Positioned.fill(
          child: FlutterMap(
            mapController: controller,
            options: MapOptions(
              initialCenter: focus,
              initialZoom: zoom,
              minZoom: 3,
              maxZoom: 18,
              initialCameraFit: fitRoute && pts.length > 1
                  ? CameraFit.bounds(
                      bounds: LatLngBounds.fromPoints(pts),
                      padding: const EdgeInsets.all(36),
                    )
                  : null,
              interactionOptions: InteractionOptions(
                flags: interactive
                    ? InteractiveFlag.all & ~InteractiveFlag.rotate
                    : InteractiveFlag.none,
              ),
              backgroundColor: context.isDark ? K.bgD : K.bgL,
            ),
            children: [
              if (!tilesEnabled)
                const SizedBox.shrink()
              else if (context.isDark)
                ColorFiltered(
                  colorFilter: _darkTiles,
                  child: TileLayer(
                      urlTemplate: _tileUrl, userAgentPackageName: _tileUa),
                )
              else
                TileLayer(urlTemplate: _tileUrl, userAgentPackageName: _tileUa),
              if (pts.length > 1)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: pts,
                      color: dashed ? K.orange.withValues(alpha: .55) : K.orange,
                      strokeWidth: dashed ? 4 : 5.5,
                      pattern: dashed
                          ? StrokePattern.dotted(spacingFactor: 2.4)
                          : const StrokePattern.solid(),
                      strokeCap: StrokeCap.round,
                    ),
                  ],
                ),
              if (pts.isNotEmpty)
                MarkerLayer(markers: [
                  Marker(
                    point: pts.first,
                    width: 16,
                    height: 16,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: K.ink, width: 2),
                      ),
                    ),
                  ),
                ]),
              if (markers.isNotEmpty)
                MarkerLayer(
                  markers: [
                    for (final m in markers)
                      Marker(
                        point: m.at,
                        width: 150,
                        height: m.size + 26,
                        alignment:
                            m.labelBelow ? Alignment.topCenter : Alignment.bottomCenter,
                        child: _Pin(m),
                      ),
                  ],
                ),
            ],
          ),
        ),
        if (dim) Positioned.fill(child: ColoredBox(color: const Color(0x6B101214))),
        if (attribution)
          Positioned(
            right: 4,
            bottom: 2,
            child: Text('© OpenStreetMap',
                style: mono(8,
                    color: context.isDark ? Colors.white38 : Colors.black38,
                    track: .2)),
          ),
        ...overlays,
      ],
    );
  }
}

/// Kurva halus lewat titik ternormalisasi 0..1 (Catmull-Rom sederhana).
/// Dipakai thumbnail riwayat dan kartu share — keduanya menggambar jejak tanpa
/// peta, jadi tetap tergambar walau tile tidak bisa diunduh.
Path routePath(List<Offset> pts, Size size) {
  Offset at(int i) => Offset(
      pts[i.clamp(0, pts.length - 1)].dx * size.width,
      pts[i.clamp(0, pts.length - 1)].dy * size.height);
  final path = Path()..moveTo(at(0).dx, at(0).dy);
  for (var i = 0; i < pts.length - 1; i++) {
    final p0 = at(i - 1), p1 = at(i), p2 = at(i + 1), p3 = at(i + 2);
    path.cubicTo(
      p1.dx + (p2.dx - p0.dx) / 6, p1.dy + (p2.dy - p0.dy) / 6,
      p2.dx - (p3.dx - p1.dx) / 6, p2.dy - (p3.dy - p1.dy) / 6,
      p2.dx, p2.dy,
    );
  }
  return path;
}

/// Thumbnail rute di kartu riwayat.
class RouteThumb extends StatelessWidget {
  const RouteThumb(this.track, {super.key, this.size = 52});

  final List<LatLng> track;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration:
            BoxDecoration(color: context.fill, borderRadius: BorderRadius.circular(12)),
        child: track.length < 2
            ? Icon(Icons.timeline, size: size * .4, color: context.dim)
            : CustomPaint(painter: _ThumbPainter(normalize(track))),
      );
}

class _ThumbPainter extends CustomPainter {
  _ThumbPainter(this.shape);

  final List<Offset> shape;

  @override
  void paint(Canvas canvas, Size size) {
    if (shape.length < 2) return;
    final inset = Size(size.width * .7, size.height * .7);
    canvas.translate(size.width * .15, size.height * .15);
    canvas.drawPath(
      routePath(shape, inset),
      Paint()
        ..color = K.orange
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_ThumbPainter old) => old.shape != shape;
}

/// Header layar dengan tombol kembali.
AppBar backBar(BuildContext context, String title, {List<Widget> actions = const []}) =>
    AppBar(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      titleSpacing: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, size: 22),
        color: context.fg,
        onPressed: () => Navigator.maybePop(context),
      ),
      title: Text(title,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: context.fg)),
      actions: actions,
    );

/// Catatan privasi hijau (dipakai di ringkasan, detail, rekap grup).
class PrivacyNote extends StatelessWidget {
  const PrivacyNote(this.text, {super.key, this.icon = Icons.shield_outlined});

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: dark ? const Color(0x2317A867) : const Color(0xFFEEF7F1),
        border: Border.all(color: dark ? const Color(0x4417A867) : const Color(0xFFCDE9DA)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: dark ? const Color(0xFF3ECF8E) : K.successInk),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: TextStyle(
                    fontSize: 12.5,
                    height: 1.5,
                    color: dark ? const Color(0xFF8FD9B6) : const Color(0xFF2F6B51))),
          ),
        ],
      ),
    );
  }
}
