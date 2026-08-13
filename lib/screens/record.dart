import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import '../state.dart';
import '../theme.dart';
import '../widgets.dart';
import 'share.dart';

/// 06 · PILIH AKTIVITAS (SHEET) → countdown 3-2-1 → 07 REKAM AKTIF
Future<void> startRecordFlow(BuildContext context) async {
  final app = AppScope.of(context);
  if (app.session != null) {
    _openRecorder(context);
    return;
  }
  final sport = await showModalBottomSheet<Sport>(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.fill,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
    builder: (_) => const _SportSheet(),
  );
  if (sport == null || !context.mounted) return;
  final go = await Navigator.push<bool>(
      context, MaterialPageRoute(builder: (_) => const _Countdown()));
  if (go != true || !context.mounted) return;
  app.startSession(sport);
  _openRecorder(context);
}

void _openRecorder(BuildContext context) => Navigator.push(
    context, MaterialPageRoute(builder: (_) => const RecordingScreen()));

class _SportSheet extends StatefulWidget {
  const _SportSheet();

  @override
  State<_SportSheet> createState() => _SportSheetState();
}

class _SportSheetState extends State<_SportSheet> {
  Sport? _sport;
  bool _shareStatus = true;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final sport = _sport ??= app.lastSport;
    return Padding(
      padding: const EdgeInsets.fromLTRB(K.pad, 12, K.pad, 22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 44,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                  color: context.line, borderRadius: BorderRadius.circular(99)),
            ),
          ),
          Text('Rekam apa hari ini?', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text('Metrik dan tampilan grafik menyesuaikan pilihan.',
              style: TextStyle(fontSize: 13, color: context.dim)),
          const SizedBox(height: 16),
          for (final s in Sport.values) ...[
            InkWell(
              onTap: () => setState(() => _sport = s),
              borderRadius: BorderRadius.circular(K.r),
              child: Panel(
                border: s == sport ? K.orange : null,
                padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: s == sport
                            ? (context.isDark ? const Color(0x29FF6A13) : K.orangeSoft)
                            : context.fill,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(s.icon,
                          size: 22, color: s == sport ? K.orange : context.fg),
                    ),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(s.label,
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: context.fg)),
                          Mono(s.metrics, size: 10.5),
                        ],
                      ),
                    ),
                    Icon(
                        s == sport
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                        size: 22,
                        color: s == sport ? K.orange : context.dim),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
          Panel(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 2),
            child: SwitchRow(
              title: 'Bagikan status ke grup',
              subtitle: 'Anggota lihat "sedang ${sport.label.toLowerCase()}", bukan rutenya',
              value: _shareStatus && app.activeGroup != null,
              divider: false,
              onChanged: app.activeGroup == null
                  ? null
                  : (v) => setState(() => _shareStatus = v),
            ),
          ),
          const SizedBox(height: 14),
          BigBtn('Mulai · ${sport.label}', onTap: () {
            app.set(() => app.shareStatus = _shareStatus);
            Navigator.pop(context, sport);
          }),
        ],
      ),
    );
  }
}

class _Countdown extends StatefulWidget {
  const _Countdown();

  @override
  State<_Countdown> createState() => _CountdownState();
}

class _CountdownState extends State<_Countdown> {
  int _n = 3;
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_n <= 1) {
        _t?.cancel();
        Navigator.pop(context, true);
      } else {
        setState(() => _n--);
      }
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: K.bgD,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('$_n',
                  style: const TextStyle(
                      fontSize: 140,
                      fontWeight: FontWeight.w800,
                      color: K.orange,
                      letterSpacing: -8,
                      height: 1)),
              const SizedBox(height: 12),
              Text('SIAP-SIAP', style: mono(12, color: K.dimD, track: 2.4)),
            ],
          ),
        ),
      );
}

/// 07 · REKAM AKTIF · 08 · REKAM DIJEDA (tema gelap, wakelock-style)
class RecordingScreen extends StatelessWidget {
  const RecordingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final s = app.session;
    if (s == null) return const SizedBox.shrink();
    return Theme(
      data: buildTheme(Brightness.dark),
      child: ListenableBuilder(
        listenable: s,
        builder: (context, _) => s.paused
            ? _PausedView(session: s)
            : _ActiveView(session: s),
      ),
    );
  }
}

class _ActiveView extends StatefulWidget {
  const _ActiveView({required this.session});

  final RecordSession session;

  @override
  State<_ActiveView> createState() => _ActiveViewState();
}

class _ActiveViewState extends State<_ActiveView> {
  final _map = MapController();
  late final _follower = MapFollower(_map);

  @override
  void dispose() {
    _follower.dispose();
    super.dispose();
  }

  void _autoFollow(AppState app) {
    final pos = app.myPos;
    if (pos == null) return;
    _follower.follow(pos, zoom: 16);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.session;
    final app = AppScope.of(context);
    _autoFollow(app);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            if (!app.online)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                color: const Color(0xFFE8A317),
                child: Row(
                  children: [
                    const Icon(Icons.cloud_off, size: 14, color: Color(0xFF12140F)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Offline · merekam lokal, sync nanti',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF12140F), fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 10),
              child: Row(
                children: [
                  Container(
                    width: 9,
                    height: 9,
                    decoration: const BoxDecoration(
                        color: Color(0xFFFF3B30), shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 9),
                  Text('MEREKAM · ${s.sport.label.toUpperCase()}',
                      style:
                          mono(11, color: K.orange, weight: FontWeight.w700, track: 1.6)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                        color: const Color(0x2917A867),
                        borderRadius: BorderRadius.circular(99)),
                    child: Row(
                      children: [
                        const Icon(Icons.shield, size: 12, color: Color(0xFF3ECF8E)),
                        const SizedBox(width: 6),
                        Text('PRIBADI',
                            style: mono(9, color: const Color(0xFF3ECF8E), track: .9)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 232,
              child: Stack(
                children: [
                  LiveMap(
                    controller: _map,
                    route: s.points,
                    center: s.points.isEmpty ? null : s.points.last,
                    zoom: 16,
                    interactive: true,
                    markers: [
                      if (app.myPos != null)
                        MapPin(
                            at: app.myPos!,
                            initials: app.me.initials,
                            color: K.orange,
                            size: 32,
                            highlight: true),
                    ],
                  ),
                  Positioned(
                    right: 12,
                    top: 12,
                    child: InkWell(
                      onTap: () async {
                        if (app.myPos == null) {
                          await app.gps.start();
                        }
                        if (mounted && app.myPos != null) {
                          _follower.follow(app.myPos!, zoom: 16, force: true);
                        }
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        width: 40,
                        height: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: K.cardD,
                          border: Border.all(color: K.lineD),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.my_location, size: 18, color: Color(0xFFC7CCD1)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    L('DURASI', size: 10, color: K.dimD),
                    Text(fmtClock(s.movingSec),
                        style: Theme.of(context).textTheme.displayLarge),
                    const SizedBox(height: 22),
                    Row(
                      children: [
                        Expanded(
                          child: StatTile(
                              label: 'JARAK',
                              value: fmtKm(s.km),
                              unit: 'km',
                              size: 34,
                              onDark: true),
                        ),
                        Expanded(
                          child: StatTile(
                              label: 'PACE',
                              value: fmtPace(s.paceSecPerKm),
                              unit: '/km',
                              size: 34,
                              onDark: true),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: Panel(
                            radius: 13,
                            border: Colors.transparent,
                            child: StatTile(
                                label: 'KECEPATAN',
                                value: num1(s.speedKmh),
                                unit: 'km/j',
                                size: 19,
                                onDark: true),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Panel(
                            radius: 13,
                            border: Colors.transparent,
                            child: StatTile(
                                label: 'KALORI',
                                value: '${s.calories}',
                                unit: 'kkal',
                                size: 19,
                                onDark: true),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Panel(
                      radius: 13,
                      border: Colors.transparent,
                      padding:
                          const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                      child: Row(
                        children: [
                          L('KM ${s.km.floor() + 1}', color: K.dimD),
                          const SizedBox(width: 10),
                          Expanded(child: Meter(s.splitProgress, height: 6)),
                          const SizedBox(width: 10),
                          Mono(
                              s.splits.isEmpty
                                  ? '--:--'
                                  : fmtPace(s.splits.last.paceSec),
                              size: 11,
                              color: K.inkD),
                        ],
                      ),
                    ),
                    if (s.laps.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Mono(
                            'LAP ${s.laps.length} · ${fmtClock(s.laps.last.$1)} '
                            '· ${fmtKm(s.laps.last.$2)} km',
                            size: 10,
                            color: K.dimD,
                            track: 1.2),
                      ),
                    const Spacer(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _CircleBtn(icon: Icons.pause, onTap: s.togglePause),
                        const SizedBox(width: 22),
                        _StopBtn(onHold: () => _finish(context)),
                        const SizedBox(width: 22),
                        _CircleBtn(icon: Icons.flag_outlined, onTap: s.lap),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Center(
                        child: Text('TAHAN TOMBOL STOP UNTUK SELESAI',
                            style: mono(9.5, color: const Color(0xFF6E757B), track: 1.1))),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 08 · REKAM DIJEDA
class _PausedView extends StatelessWidget {
  const _PausedView({required this.session});

  final RecordSession session;

  @override
  Widget build(BuildContext context) {
    final s = session;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 10),
              child: Row(
                children: [
                  Container(
                    width: 9,
                    height: 9,
                    decoration:
                        const BoxDecoration(color: K.warning, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 9),
                  Text('DIJEDA · ${s.sport.label.toUpperCase()}',
                      style: mono(11,
                          color: K.warning, weight: FontWeight.w700, track: 1.6)),
                  const Spacer(),
                  Mono('JEDA ${fmtClock(s.pausedSec)}', size: 9.5, color: K.dimD),
                ],
              ),
            ),
            Opacity(
              opacity: .55,
              child: SizedBox(
                height: 232,
                child: LiveMap(
                    route: s.points,
                    center: s.points.isEmpty ? null : s.points.last,
                    zoom: 16,
                    interactive: false),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    L('DURASI BERGERAK', size: 10, color: K.dimD),
                    Text(fmtClock(s.movingSec),
                        style: Theme.of(context)
                            .textTheme
                            .displayLarge!
                            .copyWith(color: const Color(0xFF6E757B))),
                    const SizedBox(height: 22),
                    Opacity(
                      opacity: .6,
                      child: Row(
                        children: [
                          Expanded(
                              child: StatTile(
                                  label: 'JARAK',
                                  value: fmtKm(s.km),
                                  unit: 'km',
                                  size: 34,
                                  onDark: true)),
                          Expanded(
                              child: StatTile(
                                  label: 'PACE RATA-RATA',
                                  value: fmtPace(s.paceSecPerKm),
                                  unit: '/km',
                                  size: 34,
                                  onDark: true)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
                      decoration: BoxDecoration(
                        color: const Color(0x1FE8A317),
                        border: Border.all(color: const Color(0x4DE8A317)),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                          s.autoPaused
                              ? 'Perekaman dijeda otomatis karena kamu berhenti. '
                                  'Titik GPS tidak dicatat selama jeda — lanjut sendiri '
                                  'begitu kamu bergerak lagi.'
                              : 'Perekaman dijeda. Titik GPS tidak dicatat selama jeda.',
                          style: const TextStyle(
                              fontSize: 12.5, height: 1.55, color: Color(0xFFE8C078))),
                    ),
                    const Spacer(),
                    BigBtn('LANJUTKAN',
                        icon: Icons.play_arrow_rounded,
                        monoLabel: true,
                        height: 56,
                        onTap: s.togglePause),
                    const SizedBox(height: 11),
                    BigBtn('SELESAI & SIMPAN',
                        icon: Icons.stop_rounded,
                        monoLabel: true,
                        filled: false,
                        height: 56,
                        onTap: () => _finish(context)),
                    Center(
                      child: TextButton(
                        onPressed: () => _confirmDiscard(context),
                        child: Text('Buang rekaman ini',
                            style: TextStyle(fontSize: 13, color: context.dim)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _finish(BuildContext context) async {
  final app = AppScope.of(context);
  final a = await app.finishSession();
  if (!context.mounted) return;
  if (a == null) {
    // Jarak nol (mis. izin GPS ditolak) — jangan simpan aktivitas kosong.
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(app.consumeNotice())));
    Navigator.pop(context);
    return;
  }
  Navigator.pushReplacement(
      context, MaterialPageRoute(builder: (_) => SummaryScreen(activity: a)));
}

Future<void> _confirmDiscard(BuildContext context) async {
  final app = AppScope.of(context);
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Buang rekaman ini?'),
      content: const Text(
          'Rute, durasi, dan statistik rekaman ini akan hilang dan tidak bisa dipulihkan.'),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Buang', style: TextStyle(color: K.danger)),
        ),
      ],
    ),
  );
  if (ok != true || !context.mounted) return;
  app.discardSession();
  Navigator.pop(context);
}

class _CircleBtn extends StatelessWidget {
  const _CircleBtn({required this.icon, this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 58,
          height: 58,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: K.cardD,
            shape: BoxShape.circle,
            border: Border.all(color: K.lineD),
          ),
          child: Icon(icon, size: 22, color: const Color(0xFFC7CCD1)),
        ),
      );
}

/// Tombol stop: harus ditahan (long press) supaya tidak selesai karena salah tap.
class _StopBtn extends StatelessWidget {
  const _StopBtn({required this.onHold});

  final VoidCallback onHold;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onLongPress: onHold,
        onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Tahan tombol stop untuk selesai'),
            duration: Duration(seconds: 2))),
        child: Container(
          width: 84,
          height: 84,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: K.orange,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: Color(0x5CFF6A13), blurRadius: 26, offset: Offset(0, 10))
            ],
          ),
          child: Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(6)),
          ),
        ),
      );
}

/// 09 · RINGKASAN SETELAH SELESAI
class SummaryScreen extends StatefulWidget {
  const SummaryScreen({super.key, required this.activity});

  final Activity activity;

  @override
  State<SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends State<SummaryScreen> {
  Activity get a => widget.activity;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: backBar(context, 'Aktivitas tersimpan', actions: [
        TextButton(
          onPressed: () => editActivity(context, a, () => setState(() {})),
          child: Text('EDIT',
              style: mono(11, color: K.orange, weight: FontWeight.w700, track: 1)),
        ),
      ]),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(K.pad, 0, K.pad, K.pad),
                children: [
                  Panel(
                    clip: true,
                    radius: 18,
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        SizedBox(
                          height: 170,
                          child: LiveMap(
                              route: a.track, fitRoute: true, interactive: false),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 15, 16, 17),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(a.title,
                                  style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                      color: context.fg,
                                      letterSpacing: -.3)),
                              const SizedBox(height: 3),
                              Mono(
                                  '${fmtDateYear(a.startedAt)} · ${fmtTime(a.startedAt)} '
                                  '· ${a.sport.label.toUpperCase()}',
                                  size: 10.5),
                              const SizedBox(height: 13),
                              _MetricRow(a),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: K.gap),
                  if (a.splits.isNotEmpty)
                    Panel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const L('KECEPATAN PER KM'),
                          const SizedBox(height: 12),
                          Bars(
                            values: [
                              for (final s in a.splits)
                                s.paceSec == 0 ? 0 : 3600 / s.paceSec
                            ],
                            labels: [for (final s in a.splits) 'KM${s.km}'],
                            height: 64,
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: K.gap),
                  const PrivacyNote(
                      'Rute ini tersimpan pribadi. Anggota grup tidak bisa melihatnya.'),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(K.pad, 0, K.pad, 8),
              child: Row(
                children: [
                  Expanded(
                    flex: 16,
                    child: BigBtn('Bagikan gambar',
                        icon: Icons.image_outlined,
                        onTap: () => Navigator.push(context,
                            MaterialPageRoute(builder: (_) => ShareScreen(activity: a)))),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    flex: 10,
                    child: BigBtn('Selesai',
                        filled: false,
                        onTap: () => Navigator.popUntil(context, (r) => r.isFirst)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow(this.a);

  final Activity a;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(
              child: StatTile(label: 'JARAK', value: fmtKm(a.km), unit: 'km', size: 20)),
          Expanded(
              child: StatTile(label: 'DURASI', value: fmtClock(a.movingSec), size: 20)),
          Expanded(
              child: StatTile(
                  label: a.sport == Sport.bike ? 'KM/J' : 'PACE',
                  value: a.sport == Sport.bike
                      ? num1(a.avgSpeedKmh)
                      : fmtPace(a.avgPaceSecPerKm),
                  size: 20)),
          Expanded(child: StatTile(label: 'KKAL', value: '${a.calories}', size: 20)),
        ],
      );
}

/// EDIT · ubah judul, jenis aktivitas, catatan.
Future<void> editActivity(
    BuildContext context, Activity a, VoidCallback onSaved) async {
  final app = AppScope.of(context);
  final title = TextEditingController(text: a.title);
  final note = TextEditingController(text: a.note);
  var sport = a.sport;

  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setLocal) => AlertDialog(
        title: const Text('Edit aktivitas'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: title,
                decoration: const InputDecoration(labelText: 'Judul')),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                for (final s in Sport.values)
                  Pill(s.label,
                      selected: s == sport,
                      selectedColor: K.orange,
                      monoStyle: false,
                      onTap: () => setLocal(() => sport = s)),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
                controller: note,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Catatan')),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          TextButton(
              onPressed: () => Navigator.pop(context, true), child: const Text('Simpan')),
        ],
      ),
    ),
  );
  if (ok == true) {
    app.set(() {
      a
        ..title = title.text.trim().isEmpty ? a.title : title.text.trim()
        ..sport = sport
        ..note = note.text.trim();
    });
    onSaved();
  }
  title.dispose();
  note.dispose();
}
