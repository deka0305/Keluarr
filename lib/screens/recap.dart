import 'package:flutter/material.dart';

import '../state.dart';
import '../theme.dart';
import '../widgets.dart';
import 'record.dart';
import 'share.dart';

/// 13 · REKAP · RIWAYAT PRIBADI ⇄ 15 · REKAP GRUP
class RecapScreen extends StatefulWidget {
  const RecapScreen({super.key});

  @override
  State<RecapScreen> createState() => _RecapScreenState();
}

class _RecapScreenState extends State<RecapScreen> {
  bool _groupTab = false;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final hasGroup = app.activeGroup != null;
    final month = app.monthActivities;

    return ListView(
      padding: const EdgeInsets.fromLTRB(K.pad, 8, K.pad, 20),
      children: [
        Text(_groupTab ? 'Rekap grup' : 'Rekap saya',
            style: Theme.of(context).textTheme.headlineSmall),
        if (_groupTab && hasGroup)
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Mono(
                '${app.activeGroup!.name.toUpperCase()} · ${fmtMonthYear(month.isEmpty ? DateTime.now() : month.first.startedAt)}',
                size: 10.5),
          ),
        const SizedBox(height: 12),
        Row(
          children: [
            Pill('SAYA',
                selected: !_groupTab, onTap: () => setState(() => _groupTab = false)),
            const SizedBox(width: 8),
            Pill('GRUP',
                selected: _groupTab,
                onTap: hasGroup ? () => setState(() => _groupTab = true) : null),
            const Spacer(),
            if (!_groupTab)
              Pill(
                  fmtMonthYear(
                      month.isEmpty ? DateTime.now() : month.first.startedAt),
                  onTap: null),
          ],
        ),
        const SizedBox(height: 12),
        if (_groupTab && hasGroup) ..._groupBody(context, app) else ..._myBody(context, app),
      ],
    );
  }

  List<Widget> _myBody(BuildContext context, AppState app) {
    final month = app.monthActivities;
    return [
      Row(
        children: [
          Expanded(
              child: Panel(
                  child: StatTile(
                      label: 'TOTAL JARAK', value: fmtKm(app.monthKm), unit: 'km', size: 23))),
          const SizedBox(width: 10),
          Expanded(
              child: Panel(
                  child: StatTile(
                      label: 'WAKTU', value: fmtSpan(app.monthSec), size: 23))),
          const SizedBox(width: 10),
          Expanded(
              child: Panel(
                  child: StatTile(
                      label: 'AKTIVITAS', value: '${month.length}', size: 23))),
        ],
      ),
      const SizedBox(height: K.gap),
      Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                L('JARAK PER MINGGU'),
              ],
            ),
            const SizedBox(height: 11),
            Bars(
                values: app.weeklyKm,
                labels: app.weeklyLabels,
                height: 52),
          ],
        ),
      ),
      const SizedBox(height: K.gap),
      L('AKTIVITAS · ${month.length}'),
      const SizedBox(height: 10),
      if (month.isEmpty)
        Panel(
          child: Text('Belum ada aktivitas bulan ini. Mulai rekam dari tab REKAM.',
              style: TextStyle(fontSize: 13, color: context.dim)),
        ),
      for (final a in month) ...[
        ActivityCard(a, onChanged: () => setState(() {})),
        const SizedBox(height: 10),
      ],
    ];
  }

  /// 15 · REKAP GRUP · LEADERBOARD
  List<Widget> _groupBody(BuildContext context, AppState app) {
    final g = app.activeGroup!;
    final board = [...app.members]..sort((a, b) => b.monthKm.compareTo(a.monthKm));
    final total = board.fold(0.0, (s, m) => s + m.monthKm);
    final activeWeek = app.members.where((m) => m.monthCount > 0).length;

    return [
      Row(
        children: [
          Expanded(
              child: Panel(
                  child: StatTile(
                      label: 'TOTAL GRUP', value: fmtKm(total), unit: 'km', size: 22))),
          const SizedBox(width: 10),
          Expanded(
            child: Panel(
                child: StatTile(
                    label: 'AKTIF PEKAN INI',
                    value: '$activeWeek',
                    unit: '/${app.members.length}',
                    size: 22)),
          ),
        ],
      ),
      const SizedBox(height: K.gap),
      Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            L('TARGET BULANAN GRUP · ${g.monthlyTargetKm.round()} KM'),
            const SizedBox(height: 11),
            Meter(total / g.monthlyTargetKm),
            const SizedBox(height: 7),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Mono('${fmtKm(total)} km', size: 10),
                Mono(
                    total >= g.monthlyTargetKm
                        ? 'target tercapai'
                        : '${fmtKm(g.monthlyTargetKm - total)} km lagi',
                    size: 10),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: K.gap),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const L('PERINGKAT · JARAK'),
          Row(children: [
            Mono('JARAK', size: 9.5, color: K.orange, weight: FontWeight.w700),
            const Icon(Icons.expand_more, size: 12, color: K.orange),
          ]),
        ],
      ),
      const SizedBox(height: 10),
      for (final (i, m) in board.indexed) ...[
        _BoardRow(rank: i + 1, member: m),
        const SizedBox(height: 10),
      ],
      const PrivacyNote(
          'Peringkat memakai angka total yang kamu pilih untuk dibagikan. '
          'Rute dan peta tetap tidak ikut dibagikan.',
          icon: Icons.info_outline),
    ];
  }
}

class _BoardRow extends StatelessWidget {
  const _BoardRow({required this.rank, required this.member});

  final int rank;
  final Member member;

  @override
  Widget build(BuildContext context) {
    final me = member.isMe;
    final first = rank == 1;
    final bg = me
        ? (context.isDark ? const Color(0x29FF6A13) : K.orangeSoft)
        : (first ? K.ink : context.card);
    final fg = first && !me ? Colors.white : context.fg;
    final dimC = first && !me ? Colors.white70 : (me ? K.orangeDeep : context.dim);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
      decoration: BoxDecoration(
        color: bg,
        border: me ? Border.all(color: K.orange, width: 1.5) : null,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 20,
            child: Text('$rank',
                style: mono(15,
                    color: first ? K.orange : dimC, weight: FontWeight.w700, track: .4)),
          ),
          const SizedBox(width: 12),
          Avatar(member.initials, color: member.color, size: 38),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Flexible(
                    child: Text(member.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700, color: fg)),
                  ),
                  if (me)
                    Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: Mono('· SAYA',
                          size: 9, color: K.orangeDeep, weight: FontWeight.w700),
                    ),
                ]),
                Mono('${member.monthCount} aktivitas', size: 10, color: dimC),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(fmtKm(member.monthKm),
                  style:
                      TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: fg)),
              Mono('km', size: 9, color: dimC),
            ],
          ),
        ],
      ),
    );
  }
}

/// Kartu riwayat. Swipe kiri → hapus, swipe kanan → bagikan.
class ActivityCard extends StatelessWidget {
  const ActivityCard(this.a, {super.key, required this.onChanged});

  final Activity a;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return Dismissible(
      key: ValueKey(a.id),
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        decoration: BoxDecoration(
            color: K.orange, borderRadius: BorderRadius.circular(15)),
        child: const Icon(Icons.share, color: Colors.white),
      ),
      secondaryBackground: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
            color: K.danger, borderRadius: BorderRadius.circular(15)),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      confirmDismiss: (dir) async {
        if (dir == DismissDirection.startToEnd) {
          Navigator.push(context,
              MaterialPageRoute(builder: (_) => ShareScreen(activity: a)));
          return false;
        }
        return await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: Text('Hapus "${a.title}"?'),
                content: const Text('Rekaman rute ini akan hilang dari perangkat.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Batal')),
                  TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Hapus', style: TextStyle(color: K.danger))),
                ],
              ),
            ) ??
            false;
      },
      onDismissed: (_) => app.deleteActivity(a),
      child: InkWell(
        onTap: () async {
          await Navigator.push(context,
              MaterialPageRoute(builder: (_) => ActivityDetailScreen(activity: a)));
          onChanged();
        },
        borderRadius: BorderRadius.circular(15),
        child: Panel(
          radius: 15,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              RouteThumb(a.track),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(a.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700, color: context.fg)),
                    Mono(
                        '${fmtDate(a.startedAt)} · ${fmtTime(a.startedAt)} · ${a.sport.label.toUpperCase()}',
                        size: 10),
                    const SizedBox(height: 5),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Row(
                        children: [
                          Mono('${fmtKm(a.km)} km', size: 10.5, color: context.fg),
                          const SizedBox(width: 11),
                          Mono(fmtSpanOrClock(a.movingSec),
                              size: 10.5, color: context.fg),
                          const SizedBox(width: 11),
                          Mono(thirdMetric(a), size: 10.5, color: context.fg),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, size: 16, color: context.dim),
            ],
          ),
        ),
      ),
    );
  }
}

String fmtSpanOrClock(int sec) => sec >= 3600 ? fmtSpan(sec) : fmtClock(sec);

/// 14 · DETAIL AKTIVITAS
class ActivityDetailScreen extends StatefulWidget {
  const ActivityDetailScreen({super.key, required this.activity});

  final Activity activity;

  @override
  State<ActivityDetailScreen> createState() => _ActivityDetailScreenState();
}

class _ActivityDetailScreenState extends State<ActivityDetailScreen> {
  bool _elev = false;

  Activity get a => widget.activity;

  @override
  Widget build(BuildContext context) {
    final best = a.splits.isEmpty
        ? 0
        : a.splits.map((s) => s.paceSec).reduce((x, y) => x < y ? x : y);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: 216,
              child: Stack(
                children: [
                  Positioned.fill(
                      child: LiveMap(route: a.track, fitRoute: true)),
                  Positioned(
                    left: 14,
                    top: 12,
                    child: _MapChipBtn(
                        icon: Icons.arrow_back, onTap: () => Navigator.pop(context)),
                  ),
                  Positioned(
                    right: 14,
                    top: 12,
                    child: Row(
                      children: [
                        _MapChipBtn(
                            icon: Icons.share_outlined,
                            onTap: () => Navigator.push(context,
                                MaterialPageRoute(builder: (_) => ShareScreen(activity: a)))),
                        const SizedBox(width: 8),
                        _MapChipBtn(icon: Icons.more_vert, onTap: _menu),
                      ],
                    ),
                  ),
                  Positioned(
                    left: 14,
                    bottom: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: context.card,
                        border: Border.all(color: context.line),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.shield, size: 13, color: K.successInk),
                          const SizedBox(width: 7),
                          Text('HANYA SAYA',
                              style: mono(9, color: K.successInk, track: 1)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(K.pad, 15, K.pad, K.pad),
                children: [
                  Text(a.title, style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 3),
                  Mono(
                      '${fmtLongDate(a.startedAt)} · ${fmtTime(a.startedAt)} – ${fmtTime(a.endedAt)}',
                      size: 10.5),
                  const SizedBox(height: K.gap),
                  Panel(
                    radius: 15,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
                    child: Row(
                      children: [
                        _Cell('JARAK', fmtKm(a.km), 'km', divider: true),
                        _Cell('DURASI', fmtClock(a.movingSec), 'bergerak', divider: true),
                        _Cell(
                            a.sport == Sport.bike ? 'KM/J' : 'PACE',
                            a.sport == Sport.bike
                                ? num1(a.avgSpeedKmh)
                                : fmtPace(a.avgPaceSecPerKm),
                            a.sport == Sport.bike ? 'rata-rata' : '/km',
                            divider: true),
                        _Cell('KKAL', '${a.calories}', 'kkal'),
                      ],
                    ),
                  ),
                  const SizedBox(height: K.gap),
                  Panel(
                    radius: 15,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            _Tab('KECEPATAN', !_elev, () => setState(() => _elev = false)),
                            const SizedBox(width: 14),
                            _Tab('ELEVASI', _elev, () => setState(() => _elev = true)),
                          ],
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 82,
                          child: CustomPaint(
                            painter: _LinePainter(
                              _elev ? _elevSeries() : _speedSeries(),
                              context.line,
                            ),
                            child: const SizedBox.expand(),
                          ),
                        ),
                        const SizedBox(height: 5),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Mono('0 km', size: 9),
                            Mono('${fmtKm(a.km / 2)} km', size: 9),
                            Mono('${fmtKm(a.km)} km', size: 9),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (a.splits.isNotEmpty) ...[
                    const SizedBox(height: K.gap),
                    Panel(
                      radius: 15,
                      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 4),
                      child: Column(
                        children: [
                          for (final (i, s) in a.splits.indexed)
                            SplitRow(s,
                                best: best, divider: i < a.splits.length - 1),
                        ],
                      ),
                    ),
                  ],
                  if (a.note.isNotEmpty) ...[
                    const SizedBox(height: K.gap),
                    Panel(
                      radius: 15,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const L('CATATAN'),
                          const SizedBox(height: 6),
                          Text(a.note, style: Theme.of(context).textTheme.bodyMedium),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(K.pad, 0, K.pad, 14),
              child: BigBtn('Bagikan sebagai gambar',
                  icon: Icons.image_outlined,
                  height: 50,
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => ShareScreen(activity: a)))),
            ),
          ],
        ),
      ),
    );
  }

  List<double> _speedSeries() {
    if (a.splits.isEmpty) return [a.avgSpeedKmh, a.avgSpeedKmh];
    return [for (final s in a.splits) s.paceSec == 0 ? 0 : 3600 / s.paceSec];
  }

  List<double> _elevSeries() {
    if (a.splits.isEmpty) return [0, a.elevGainM];
    final step = a.elevGainM / a.splits.length;
    return [for (var i = 1; i <= a.splits.length; i++) step * i];
  }

  Future<void> _menu() async {
    final app = AppScope.of(context);
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: context.fill,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: K.pad, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              MenuRow('Ubah judul / jenis',
                  icon: Icons.edit_outlined,
                  onTap: () => Navigator.pop(context, 'edit')),
              MenuRow('Ekspor GPX',
                  icon: Icons.file_download_outlined,
                  onTap: () => Navigator.pop(context, 'gpx')),
              MenuRow('Hapus aktivitas',
                  icon: Icons.delete_outline,
                  color: K.danger,
                  divider: false,
                  onTap: () => Navigator.pop(context, 'delete')),
            ],
          ),
        ),
      ),
    );
    if (!mounted) return;
    switch (choice) {
      case 'edit':
        await editActivity(context, a, () => setState(() {}));
      case 'gpx':
        await exportGpx(context, [a]);
      case 'delete':
        app.deleteActivity(a);
        if (mounted) Navigator.pop(context);
    }
  }
}

class _Cell extends StatelessWidget {
  const _Cell(this.label, this.value, this.unit, {this.divider = false});

  final String label;
  final String value;
  final String unit;
  final bool divider;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          decoration: divider
              ? BoxDecoration(
                  border: Border(right: BorderSide(color: context.hair)))
              : null,
          child: Column(
            children: [
              L(label, size: 9),
              Text(value,
                  style: TextStyle(
                      fontSize: 19, fontWeight: FontWeight.w800, color: context.fg)),
              Mono(unit, size: 9),
            ],
          ),
        ),
      );
}

class _Tab extends StatelessWidget {
  const _Tab(this.label, this.active, this.onTap);

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.only(bottom: 4),
          decoration: active
              ? const BoxDecoration(
                  border: Border(bottom: BorderSide(color: K.orange, width: 2)))
              : null,
          child: Text(label,
              style: mono(9.5,
                  color: active ? K.orange : context.dim,
                  weight: active ? FontWeight.w700 : FontWeight.w500,
                  track: 1.2)),
        ),
      );
}

class _MapChipBtn extends StatelessWidget {
  const _MapChipBtn({required this.icon, this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(11),
        child: Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: context.card,
            border: Border.all(color: context.line),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon, size: 19, color: context.fg),
        ),
      );
}

class _LinePainter extends CustomPainter {
  _LinePainter(this.values, this.gridColor);

  final List<double> values;
  final Color gridColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final maxV = values.reduce((a, b) => a > b ? a : b);
    final minV = values.reduce((a, b) => a < b ? a : b);
    final span = (maxV - minV).abs() < 0.001 ? 1 : maxV - minV;
    Offset at(int i) => Offset(
          i / (values.length - 1) * size.width,
          size.height - ((values[i] - minV) / span) * (size.height * .8) - size.height * .1,
        );

    final line = Path()..moveTo(at(0).dx, at(0).dy);
    for (var i = 1; i < values.length; i++) {
      line.lineTo(at(i).dx, at(i).dy);
    }
    final fill = Path.from(line)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(fill, Paint()..color = K.orange.withValues(alpha: .1));
    canvas.drawPath(
        line,
        Paint()
          ..color = K.orange
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5);
    canvas.drawLine(Offset(0, size.height * .25), Offset(size.width, size.height * .25),
        Paint()..color = gridColor);
  }

  @override
  bool shouldRepaint(_LinePainter old) => old.values != values;
}
