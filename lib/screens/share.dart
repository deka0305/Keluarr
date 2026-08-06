import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../data/gpx.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';

/// 10 · BAGIKAN · ATUR KARTU (preview live, gaya + ukuran + template)
class ShareScreen extends StatefulWidget {
  const ShareScreen({super.key, required this.activity});

  final Activity activity;

  @override
  State<ShareScreen> createState() => _ShareScreenState();
}

class _ShareScreenState extends State<ShareScreen> {
  final _cardKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final p = app.preset;
    return Scaffold(
      appBar: backBar(context, 'Bagikan'),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(K.pad, 0, K.pad, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const L('GAYA KARTU'),
              const SizedBox(height: 8),
              Row(
                children: [
                  for (final (i, s) in CardStyle.values.indexed) ...[
                    if (i > 0) const SizedBox(width: 8),
                    Expanded(
                      child: _StyleTile(
                        style: s,
                        selected: p.style == s,
                        onTap: () => setState(() => p.style = s),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const L('UKURAN'),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            for (final (i, r) in CardRatio.values.indexed) ...[
                              if (i > 0) const SizedBox(width: 7),
                              Expanded(
                                child: _Seg(
                                  label: r == CardRatio.r9x16 ? '9:16' : '1:1',
                                  selected: p.ratio == r,
                                  onTap: () => setState(() => p.ratio = r),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const L('GARIS'),
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: () => setState(() => p.showMap = !p.showMap),
                          child: Container(
                            height: 36,
                            padding: const EdgeInsets.symmetric(horizontal: 11),
                            decoration: BoxDecoration(
                              color: context.card,
                              border: Border.all(color: context.line),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Mono(p.showMap ? 'JEJAK GPS' : 'TANPA GARIS',
                                    size: 10.5, color: context.fg),
                                Icon(Icons.expand_more, size: 14, color: context.dim),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (p.style == CardStyle.plain)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: MenuRow('Template & isi kartu polos',
                      icon: Icons.tune,
                      divider: false,
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  PlainCardScreen(activity: widget.activity)))),
                ),
              const SizedBox(height: 14),
              Expanded(
                child: Center(
                  child: AspectRatio(
                    aspectRatio: p.ratio == CardRatio.r9x16 ? 9 / 16 : 1,
                    child: RepaintBoundary(
                      key: _cardKey,
                      child: ShareCard(activity: widget.activity, preset: p, app: app),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: BigBtn(p.photoPath == null ? 'Pilih foto' : 'Ganti foto',
                        icon: Icons.image_outlined,
                        filled: false,
                        height: 46,
                        onTap: () => _pickPhoto(context, p, ImageSource.gallery,
                            () => setState(() {}))),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: BigBtn('Kamera',
                        icon: Icons.photo_camera_outlined,
                        filled: false,
                        height: 46,
                        onTap: () => _pickPhoto(context, p, ImageSource.camera,
                            () => setState(() {}))),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              BigBtn('Bagikan gambar',
                  height: 52,
                  onTap: () => _preview(context, widget.activity, p, _cardKey)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Ambil foto dari galeri/kamera untuk latar kartu.
Future<void> _pickPhoto(BuildContext context, SharePreset p, ImageSource src,
    VoidCallback onDone) async {
  try {
    final x = await ImagePicker().pickImage(
      source: src,
      // Batasi ke ukuran kartu terbesar (1080×1920): foto 12 MP tidak membuat
      // kartunya lebih tajam, hanya bikin render PNG-nya lambat dan berat.
      maxWidth: 1440,
      maxHeight: 2560,
      imageQuality: 92,
    );
    if (x == null) return;
    p
      ..photoPath = x.path
      ..style = p.style == CardStyle.plain ? CardStyle.photoOverlay : p.style;
    onDone();
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Gagal ambil foto: $e')));
  }
}

/// 11 · PRATINJAU STORY 9:16 · 12 · KARTU POLOS 1:1
Future<void> _preview(
    BuildContext context, Activity a, SharePreset p, GlobalKey cardKey) async {
  final bytes = await renderCard(cardKey, p.ratio);
  if (!context.mounted) return;
  Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => PreviewScreen(activity: a, preset: p, png: bytes)));
}

/// Simpan PNG ke berkas sementara lalu serahkan ke sheet share sistem.
/// Berkasnya perlu ada di disk: share_plus mengirim URI, bukan byte.
Future<void> _sharePng(BuildContext context, Uint8List png, Activity a) async {
  try {
    final dir = await getTemporaryDirectory();
    final file = File(
        '${dir.path}/keluarr-${a.startedAt.millisecondsSinceEpoch}.png');
    await file.writeAsBytes(png, flush: true);
    final text = '${a.title} · ${fmtKm(a.km)} km · ${fmtClock(a.movingSec)} — Keluarr';
    await SharePlus.instance.share(ShareParams(
      files: [XFile(file.path, mimeType: 'image/png')],
      text: text,
      subject: a.title,
    ));
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Gagal membagikan: $e')));
  }
}

/// Ekspor jejak ke GPX lalu serahkan ke sheet share sistem (simpan ke Drive,
/// kirim ke Strava, dsb). Satu-satunya jalan keluar jejak dari HP, dan selalu
/// atas perintah pengguna.
Future<void> exportGpx(BuildContext context, List<Activity> list) async {
  final withTrack = list.where((a) => a.track.length > 1).toList();
  if (withTrack.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Belum ada jejak GPS untuk diekspor.')));
    return;
  }
  try {
    final dir = await getTemporaryDirectory();
    final files = <XFile>[];
    for (final a in withTrack) {
      final f = File('${dir.path}/keluarr-${a.id}.gpx');
      await f.writeAsString(toGpx(
        title: a.title,
        startedAt: a.startedAt,
        points: a.track,
        secs: a.secs,
      ));
      files.add(XFile(f.path, mimeType: 'application/gpx+xml'));
    }
    await SharePlus.instance.share(ShareParams(
      files: files,
      subject: withTrack.length == 1 ? withTrack.first.title : 'Jejak Keluarr',
    ));
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Gagal ekspor GPX: $e')));
  }
}

/// Simpan PNG ke folder dokumen app (bisa dibuka lewat file manager).
Future<void> _savePng(BuildContext context, Uint8List png, Activity a) async {
  try {
    final dir = await getApplicationDocumentsDirectory();
    final file =
        File('${dir.path}/keluarr-${a.startedAt.millisecondsSinceEpoch}.png');
    await file.writeAsBytes(png, flush: true);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Disimpan: ${file.path}')));
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Gagal menyimpan: $e')));
  }
}

/// Render kartu ke PNG 1080×1920 (9:16) atau 1080×1080 (1:1).
Future<Uint8List?> renderCard(GlobalKey key, CardRatio ratio) async {
  final boundary = key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
  if (boundary == null) return null;
  final targetW = 1080.0;
  final pixelRatio = targetW / boundary.size.width;
  final image = await boundary.toImage(pixelRatio: pixelRatio);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return data?.buffer.asUint8List();
}

class PreviewScreen extends StatelessWidget {
  const PreviewScreen(
      {super.key, required this.activity, required this.preset, this.png});

  final Activity activity;
  final SharePreset preset;
  final Uint8List? png;

  @override
  Widget build(BuildContext context) {
    final wide = preset.ratio == CardRatio.r1x1;
    return Theme(
      data: buildTheme(wide ? Theme.of(context).brightness : Brightness.dark),
      child: Builder(
        builder: (context) => Scaffold(
          backgroundColor: wide ? null : const Color(0xFF0B0C0D),
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            leading: IconButton(
                icon: const Icon(Icons.close, size: 22),
                color: context.fg,
                onPressed: () => Navigator.pop(context)),
            titleSpacing: 0,
            title: Text(wide ? 'Kartu polos' : 'Pratinjau',
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700, color: context.fg)),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Center(
                    child: Mono(wide ? '1080×1080' : '1080×1920',
                        size: 10, color: context.dim)),
              ),
            ],
          ),
          body: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: AspectRatio(
                        aspectRatio: wide ? 1 : 9 / 16,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: png == null
                              ? ShareCard(
                                  activity: activity,
                                  preset: preset,
                                  app: AppScope.of(context))
                              : Image.memory(png!, fit: BoxFit.contain),
                        ),
                      ),
                    ),
                  ),
                ),
                if (png != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Mono('PNG ${(png!.lengthInBytes / 1024).round()} KB siap dibagikan',
                        size: 10, color: context.dim),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
                  child: Row(
                    children: [
                      // WhatsApp/Story/Lainnya semuanya lewat sheet share
                      // sistem: memaksa satu app tertentu butuh package
                      // visibility per-app dan pecah kalau app itu tidak ada.
                      for (final (i, item) in const [
                        ('SIMPAN', Icons.download_rounded, Color(0xFFC7CCD1)),
                        ('WHATSAPP', Icons.chat_bubble, Color(0xFF3ECF8E)),
                        ('STORY', Icons.camera_alt_outlined, Color(0xFFE06AA8)),
                        ('LAINNYA', Icons.share_outlined, Color(0xFFC7CCD1)),
                      ].indexed) ...[
                        if (i > 0) const SizedBox(width: 9),
                        Expanded(
                          child: InkWell(
                            onTap: png == null
                                ? null
                                : () => item.$1 == 'SIMPAN'
                                    ? _savePng(context, png!, activity)
                                    : _sharePng(context, png!, activity),
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              height: 64,
                              decoration: BoxDecoration(
                                color: context.card,
                                border: Border.all(color: context.line),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(item.$2, size: 19, color: item.$3),
                                  const SizedBox(height: 5),
                                  Text(item.$1,
                                      style: mono(9, color: context.dim, track: .8)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Kartu share. Satu widget dipakai untuk preview live dan render PNG.
class ShareCard extends StatelessWidget {
  const ShareCard(
      {super.key, required this.activity, required this.preset, required this.app});

  final Activity activity;
  final SharePreset preset;
  final AppState app;

  /// Lebar kanvas logis kartu. Semua ukuran di bawah ditulis untuk lebar ini.
  static const _w = 360.0;

  @override
  Widget build(BuildContext context) {
    final square = preset.ratio == CardRatio.r1x1;
    final h = square ? _w : _w * 16 / 9;
    // Kartu digambar di kanvas logis tetap lalu diskalakan utuh. Tanpa ini
    // ukuran font absolut (judul 20, angka 64) jadi raksasa saat kotak
    // pratinjau kecil — judul terpotong "Ja…", subjudul pecah empat baris —
    // dan PNG-nya tidak sama dengan yang terlihat di pratinjau.
    return FittedBox(
      fit: BoxFit.contain,
      child: SizedBox(width: _w, height: h, child: _canvas(square, h)),
    );
  }

  Widget _canvas(bool square, double h) {
    final t = _template(preset.template, preset.style);
    final fg = t.onDark ? Colors.white : K.ink;
    final dim = t.onDark ? Colors.white70 : K.dimL;
    final pad = square ? 18.0 : 22.0;
    final photo = preset.style != CardStyle.plain;

    return DecoratedBox(
      decoration: BoxDecoration(gradient: t.gradient, color: t.color),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Foto menembus sampai tepi kartu. Sebelumnya ia berada di dalam
          // padding, jadi ada bingkai gradien selebar 18 px di sekelilingnya.
          if (photo && preset.photoPath != null)
            Image.file(
              File(preset.photoPath!),
              fit: BoxFit.cover,
              // Foto bisa sudah dihapus dari galeri sejak dipilih.
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            )
          else if (photo)
            Center(
              child: Text('PILIH FOTO DI BAWAH',
                  style: mono(9.5, color: Colors.white24, track: 1.6)),
            ),
          // Tiga perhentian, bukan dua: bagian tengah dibiarkan hampir bening
          // supaya fotonya tetap terlihat, sementara atas dan bawah cukup gelap
          // untuk menahan teks putih di foto yang terang.
          if (photo)
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x8C000000), Color(0x33000000), Color(0xD9000000)],
                  stops: [0, .42, 1],
                ),
              ),
            ),
          Padding(
            padding: EdgeInsets.all(pad),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _header(square, fg, dim),
                const Spacer(),
                _stats(square, fg, dim),
                SizedBox(height: square ? 10 : 16),
                _footer(square, h, dim),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _header(bool square, Color fg, Color dim) {
    final a = activity;
    final sub = '${app.me.name.toUpperCase()} · ${fmtDate(a.startedAt)} '
        '· ${fmtTime(a.startedAt)}'
        '${preset.showGroupName && app.activeGroup != null ? " · ${app.activeGroup!.name.toUpperCase()}" : ""}';
    return Row(
      children: [
        Avatar(app.me.initials, size: square ? 38 : 44, radius: 12),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(a.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: square ? 16 : 19,
                      fontWeight: FontWeight.w800,
                      color: fg,
                      height: 1.15,
                      letterSpacing: -.3)),
              Text(sub,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: mono(9.5, color: dim, track: .4)),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration:
              BoxDecoration(color: K.orange, borderRadius: BorderRadius.circular(99)),
          child: Text(a.sport.label.toUpperCase(),
              style: mono(9, color: Colors.white, weight: FontWeight.w700, track: 1.1)),
        ),
      ],
    );
  }

  Widget _stats(bool square, Color fg, Color dim) {
    final a = activity;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('JARAK',
            style: mono(square ? 9 : 11, color: dim, track: square ? 2 : 2.6)),
        // Dua baris angka ini saja yang boleh menyusut: jarak 3 digit
        // (104,8 km) dan durasi berjam (1:08:00) lebih lebar dari kartu.
        // Sisanya tetap di ukuran kanvas supaya proporsinya konsisten.
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(fmtKm(a.km),
                  style: TextStyle(
                      fontSize: square ? 46 : 64,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -3,
                      height: 1,
                      color: fg)),
              const SizedBox(width: 6),
              Text('km', style: mono(square ? 12 : 16, color: dim, track: .4)),
            ],
          ),
        ),
        SizedBox(height: square ? 10 : 14),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(
            children: [
              _CardStat('DURASI', fmtClock(a.movingSec), fg, dim, square),
              const SizedBox(width: 18),
              _CardStat(
                  a.sport == Sport.bike ? 'KM/J' : 'PACE',
                  a.sport == Sport.bike
                      ? num1(a.avgSpeedKmh)
                      : fmtPace(a.avgPaceSecPerKm),
                  fg,
                  dim,
                  square),
              if (preset.showCalories) ...[
                const SizedBox(width: 18),
                _CardStat('KKAL', '${a.calories}', fg, dim, square),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _footer(bool square, double h, Color dim) {
    final a = activity;
    final boxH = square ? 84.0 : 96.0;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Jejak < 3 titik hanya jadi batang lurus, dan itu terlihat seperti
        // kerusakan — lebih baik dikatakan apa adanya.
        if (preset.showMap && a.track.length >= 3)
          SizedBox(
            width: square ? 88 : 116,
            height: boxH,
            child: CustomPaint(painter: _CardRoutePainter(a.shape)),
          )
        else if (preset.showMap)
          SizedBox(
            width: square ? 88 : 116,
            height: boxH,
            child: Align(
              alignment: Alignment.bottomLeft,
              child: Text('Jejak terlalu pendek\nuntuk digambar',
                  style: mono(9, color: dim, track: .4)),
            ),
          )
        else
          const SizedBox.shrink(),
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text('KELUARR',
              style: mono(square ? 9 : 10, color: dim, track: square ? 3 : 3.4)),
        ),
      ],
    );
  }
}

class _CardStat extends StatelessWidget {
  const _CardStat(this.label, this.value, this.fg, this.dim, this.square);

  final String label;
  final String value;
  final Color fg;
  final Color dim;
  final bool square;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Mono(label, size: square ? 8.5 : 9.5, color: dim, track: 1.6),
          Text(value,
              style: TextStyle(
                  fontSize: square ? 17 : 25, fontWeight: FontWeight.w800, color: fg)),
        ],
      );
}

class _CardRoutePainter extends CustomPainter {
  _CardRoutePainter(this.track);

  final List<Offset> track;

  @override
  void paint(Canvas canvas, Size size) {
    if (track.length < 3) return;
    final path = routePath(track, size);
    // Halo gelap di bawah garis oranye: tanpa ini jejaknya hilang di atas foto
    // yang terang, dan foto pagi di jalan aspal hampir selalu terang.
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.black.withValues(alpha: .45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 12
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = K.orange
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    final start = Offset(track.first.dx * size.width, track.first.dy * size.height);
    final end = Offset(track.last.dx * size.width, track.last.dy * size.height);
    canvas.drawCircle(end, 6, Paint()..color = Colors.white);
    canvas.drawCircle(start, 9, Paint()..color = Colors.white);
    canvas.drawCircle(start, 6.5, Paint()..color = K.orange);
  }

  @override
  bool shouldRepaint(_CardRoutePainter old) => old.track != track;
}

class _Tpl {
  const _Tpl(this.color, this.gradient, this.onDark);

  final Color? color;
  final Gradient? gradient;
  final bool onDark;
}

_Tpl _template(CardTemplate t, CardStyle style) {
  if (style != CardStyle.plain) {
    return const _Tpl(
        null,
        LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF8A7666), Color(0xFF4A3F36), Color(0xFF191A1B)],
            stops: [0, .48, 1]),
        true);
  }
  return switch (t) {
    CardTemplate.dark => const _Tpl(K.ink, null, true),
    CardTemplate.light => const _Tpl(K.bgL, null, false),
    CardTemplate.orange => const _Tpl(K.orange, null, true),
    CardTemplate.forest => const _Tpl(
        null,
        LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1D3B33), Color(0xFF0E1A17)]),
        true),
  };
}

class _StyleTile extends StatelessWidget {
  const _StyleTile({required this.style, required this.selected, this.onTap});

  final CardStyle style;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final (label, swatch) = switch (style) {
      CardStyle.photoOverlay => ('FOTO +\nOVERLAY', const Color(0xFF3A322C)),
      CardStyle.mapOnPhoto => ('PETA DI\nATAS FOTO', const Color(0xFF52483F)),
      CardStyle.plain => ('KARTU\nPOLOS', K.ink),
    };
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(13),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: selected
              ? (context.isDark ? const Color(0x29FF6A13) : K.orangeSoft)
              : context.card,
          border: Border.all(color: selected ? K.orange : context.line, width: selected ? 2 : 1),
          borderRadius: BorderRadius.circular(13),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 34,
              decoration:
                  BoxDecoration(color: swatch, borderRadius: BorderRadius.circular(7)),
            ),
            const SizedBox(height: 7),
            Text(label,
                style: mono(8.5,
                    color: selected ? K.orangeDeep : context.dim, track: .6)),
          ],
        ),
      ),
    );
  }
}

class _Seg extends StatelessWidget {
  const _Seg({required this.label, required this.selected, this.onTap});

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? K.orange : context.card,
            border: selected ? null : Border.all(color: context.line),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(label,
              style: mono(11,
                  color: selected ? Colors.white : context.fg,
                  weight: FontWeight.w700,
                  track: .6)),
        ),
      );
}

/// 12 · KARTU POLOS 1:1 — pengaturan template & isi kartu.
class PlainCardScreen extends StatefulWidget {
  const PlainCardScreen({super.key, required this.activity});

  final Activity activity;

  @override
  State<PlainCardScreen> createState() => _PlainCardScreenState();
}

class _PlainCardScreenState extends State<PlainCardScreen> {
  final _cardKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final p = app.preset
      ..style = CardStyle.plain
      ..ratio = CardRatio.r1x1;
    return Scaffold(
      appBar: backBar(context, 'Kartu polos', actions: [
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: Center(child: Mono('1080×1080', size: 10)),
        ),
      ]),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(K.pad, 6, K.pad, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: SizedBox(
                  width: 272,
                  height: 272,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: RepaintBoundary(
                      key: _cardKey,
                      child: ShareCard(activity: widget.activity, preset: p, app: app),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const L('TEMPLATE'),
              const SizedBox(height: 10),
              Row(
                children: [
                  for (final t in CardTemplate.values)
                    Padding(
                      padding: const EdgeInsets.only(right: 9),
                      child: InkWell(
                        onTap: () => setState(() => p.template = t),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          width: 58,
                          height: 58,
                          decoration: BoxDecoration(
                            color: _template(t, CardStyle.plain).color,
                            gradient: _template(t, CardStyle.plain).gradient,
                            border: Border.all(
                                color: p.template == t ? K.orange : context.line,
                                width: p.template == t ? 2 : 1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              const L('TAMPILKAN DI KARTU'),
              const SizedBox(height: 10),
              Panel(
                padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 2),
                child: Column(
                  children: [
                    SwitchRow(
                        title: 'Kalori',
                        value: p.showCalories,
                        onChanged: (v) => setState(() => p.showCalories = v)),
                    SwitchRow(
                        title: 'Nama grup',
                        value: p.showGroupName,
                        onChanged: app.activeGroup == null
                            ? null
                            : (v) => setState(() => p.showGroupName = v)),
                    SwitchRow(
                        title: 'Peta rute',
                        value: p.showMap,
                        divider: false,
                        onChanged: (v) => setState(() => p.showMap = v)),
                  ],
                ),
              ),
              const Spacer(),
              BigBtn('Bagikan gambar',
                  height: 52,
                  onTap: () => _preview(context, widget.activity, p, _cardKey)),
            ],
          ),
        ),
      ),
    );
  }
}
