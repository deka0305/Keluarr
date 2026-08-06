import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;

import '../state.dart';
import '../theme.dart';
import '../widgets.dart';
import 'profile.dart';

/// 04 · PETA LIVE (terang) / 05 · PETA LIVE (gelap)
class MapScreen extends StatefulWidget {
  const MapScreen({super.key, required this.onStartRecord});

  final VoidCallback onStartRecord;

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final _map = MapController();

  /// FAB oranye: tampilkan/sembunyikan jejak pribadi (hanya di device ini).
  bool _showTrail = true;
  double _sheet = 1; // 0 = tertutup, 1 = ringkas, 2 = penuh
  bool _follow = true;
  LatLng? _lastFollowed;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final group = app.activeGroup;
    final solo = group == null;
    _autoFollow(app);

    return Column(
      children: [
        if (!app.online)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            color: const Color(0xFFE8A317),
            child: Row(
              children: [
                const Icon(Icons.cloud_off, size: 16, color: Color(0xFF12140F)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    app.cloudError ?? 'Offline · data akan sync saat online',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF12140F), fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        _Header(solo: solo),
        Expanded(
          child: Stack(
            children: [
              Positioned.fill(
                child: LiveMap(
                  controller: _map,
                  route: app.session?.points ?? const [],
                  dashed: false,
                  showRoute: _showTrail,
                  center: app.myPos,
                  markers: [
                    for (final m in app.members)
                      if (m.at != null && (m.sharesLocation || m.isMe))
                        MapPin(
                          at: m.at!,
                          initials: m.initials,
                          color: m.color,
                          size: m.isMe ? 38 : 34,
                          highlight: m.isMe,
                          labelBelow: m.state != MemberState.paused,
                          label: _pinLabel(app, m),
                          onTap: () => _focus(app, m),
                        ),
                  ],
                ),
              ),
              Positioned(
                left: 16,
                top: 16,
                child: Panel(
                  radius: 14,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: solo
                      ? const StatTile(label: 'MODE', value: 'Solo', size: 18)
                      : StatTile(
                          label: 'RENTANG ROMBONGAN',
                          value: app.live.length < 2 ? '—' : num1(app.spreadKm),
                          unit: app.live.length < 2 ? null : 'km',
                          size: 24),
                ),
              ),
              Positioned(
                right: 14,
                top: 16,
                child: Column(
                  children: [
                    _MapBtn(
                      icon: Icons.my_location,
                      active: _follow,
                      onTap: () async {
                        if (app.myPos == null) {
                          await app.gps.start();
                        }
                        if (mounted && app.myPos != null) {
                          setState(() => _follow = true);
                          _map.move(app.myPos!, 16);
                        }
                      },
                    ),
                    const SizedBox(height: 10),
                    _MapBtn(
                      icon: Icons.groups_2_outlined,
                      onTap: () => _fitGroup(app),
                    ),
                    const SizedBox(height: 10),
                    _MapBtn(
                      icon: Icons.timeline,
                      active: _showTrail,
                      onTap: () => setState(() => _showTrail = !_showTrail),
                    ),
                  ],
                ),
              ),
              if (app.myPos == null)
                Positioned(
                  left: 20,
                  right: 20,
                  bottom: 84,
                  child: Panel(
                    radius: 14,
                    child: Row(
                      children: [
                        Icon(Icons.gps_off, size: 16, color: context.dim),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                              'Posisi belum terbaca. Mulai rekam untuk menyalakan GPS.',
                              style: TextStyle(fontSize: 12.5, color: context.dim)),
                        ),
                      ],
                    ),
                  ),
                ),
              Positioned(
                left: 20,
                right: 20,
                bottom: 16,
                child: BigBtn(
                  app.session == null ? 'MULAI REKAM RUTE' : 'LANJUT KE REKAMAN',
                  icon: Icons.play_arrow_rounded,
                  monoLabel: true,
                  height: 56,
                  onTap: widget.onStartRecord,
                ),
              ),
            ],
          ),
        ),
        if (!solo) _GroupSheet(level: _sheet, onLevel: (v) => setState(() => _sheet = v)),
      ],
    );
  }

  /// Ikuti posisiku selama pengguna belum menggeser peta sendiri.
  void _autoFollow(AppState app) {
    final pos = app.myPos;
    if (!_follow || pos == null || pos == _lastFollowed) return;
    _lastFollowed = pos;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _follow) _map.move(pos, _map.camera.zoom);
    });
  }

  void _fitGroup(AppState app) {
    final pts = [
      for (final m in app.members)
        if (m.at != null) m.at!,
    ];
    if (pts.isEmpty) return;
    setState(() => _follow = false);
    if (pts.length == 1) {
      _map.move(pts.first, 16);
      return;
    }
    _map.fitCamera(CameraFit.bounds(
        bounds: LatLngBounds.fromPoints(pts), padding: const EdgeInsets.all(60)));
  }

  String? _pinLabel(AppState app, Member m) {
    if (m.isMe) {
      final s = app.session;
      return s == null
          ? 'Kamu'
          : 'Kamu · ${m.sport.label.toLowerCase()} ${fmtClock(s.movingSec)}';
    }
    return switch (m.state) {
      MemberState.paused => '${m.name} · istirahat',
      MemberState.offline => '${m.name} · sinyal hilang',
      MemberState.moving =>
        '${m.name} · ${m.sport.label.toLowerCase()} ${num1(m.speedKmh)} km/j',
    };
  }

  void _focus(AppState app, Member m) {
    final at = m.at;
    if (at == null) return;
    setState(() => _follow = false);
    _map.move(at, 16);
    if (m.isMe) return;
    final gap = app.gapFromMe(m);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      duration: const Duration(seconds: 3),
      content: Text('${m.name} · ${fmtGap(gap)} '
          '${gap >= 0 ? "di depan" : "di belakang"} kamu — rutenya tetap pribadi'),
    ));
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.solo});

  final bool solo;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final g = app.activeGroup;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 8, 12),
      child: Row(
        children: [
          Avatar(g?.initials ?? 'KL', size: 42, radius: 12),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(g?.name ?? 'Solo',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: context.fg,
                        letterSpacing: -.2)),
                Mono(
                    solo
                        ? 'TANPA GRUP · REKAM PRIBADI'
                        : '${g!.sport.label.toUpperCase()} · ${app.members.length} anggota'
                            '${g.localOnly ? " · LOKAL" : ""}',
                    size: 10.5),
              ],
            ),
          ),
          if (!solo) ...[
            _Count(app.countByState(MemberState.moving), K.successInk,
                context.isDark ? const Color(0x2E17A867) : K.successSoft),
            const SizedBox(width: 5),
            _Count(app.countByState(MemberState.paused), K.warningInk,
                context.isDark ? const Color(0x2EE8A317) : const Color(0xFFFBEEDA)),
            const SizedBox(width: 5),
            _Count(app.members.length - app.live.length, context.dim, context.fill),
          ],
          IconButton(
            icon: Icon(
                context.isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                size: 19),
            color: context.isDark ? const Color(0xFFE8C64F) : context.fg,
            onPressed: () => app.set(() =>
                app.themeMode = context.isDark ? ThemeMode.light : ThemeMode.dark),
          ),
          GestureDetector(
            onTap: () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => const ProfileScreen())),
            child: Avatar(app.me.initials, size: 30),
          ),
        ],
      ),
    );
  }
}

class _Count extends StatelessWidget {
  const _Count(this.n, this.fg, this.bg);

  final int n;
  final Color fg;
  final Color bg;

  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(minWidth: 26),
        height: 26,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 7),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
        child:
            Text('$n', style: mono(11, color: fg, weight: FontWeight.w700, track: .4)),
      );
}

class _MapBtn extends StatelessWidget {
  const _MapBtn({required this.icon, this.onTap, this.active = false});

  final IconData icon;
  final VoidCallback? onTap;
  final bool active;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(13),
        child: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? K.orange : context.card,
            border: active ? null : Border.all(color: context.line),
            borderRadius: BorderRadius.circular(13),
            boxShadow: active
                ? K.shadowOrange
                : const [
                    BoxShadow(
                        color: Color(0x14141618), blurRadius: 14, offset: Offset(0, 5))
                  ],
          ),
          child: Icon(icon, size: 20, color: active ? Colors.white : context.fg),
        ),
      );
}

/// Sheet rombongan: bisa di-drag 3 posisi (tertutup / ringkas / penuh).
class _GroupSheet extends StatelessWidget {
  const _GroupSheet({required this.level, required this.onLevel});

  final double level;
  final ValueChanged<double> onLevel;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final leader = app.leader;
    final trailer = app.trailer;
    final enough = app.live.length > 1;
    return GestureDetector(
      onVerticalDragEnd: (d) {
        final up = d.primaryVelocity != null && d.primaryVelocity! < 0;
        onLevel((level + (up ? 1 : -1)).clamp(0, 2));
      },
      child: Container(
        decoration: BoxDecoration(
          color: context.isDark ? const Color(0xFF15181B) : Colors.white,
          border: Border(top: BorderSide(color: context.line)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 9, 16, 4),
        child: Column(
          children: [
            Container(
              width: 44,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                  color: context.line, borderRadius: BorderRadius.circular(99)),
            ),
            if (level > 0)
              Row(
                children: [
                  Expanded(
                    child: _SheetBox(
                        label: 'PALING DEPAN',
                        name: enough ? (leader?.name ?? '—') : '—',
                        detail: enough && leader != null
                            ? '${num1(leader.speedKmh)} km/j'
                            : 'belum ada anggota live',
                        tone: K.successInk),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _SheetBox(
                        label: 'PALING BELAKANG',
                        name: enough ? (trailer?.name ?? '—') : '—',
                        detail: enough && trailer != null
                            ? '${fmtGap(app.spreadKm * 1000)} di belakang'
                            : 'butuh 2 orang berbagi lokasi',
                        tone: K.warningInk),
                  ),
                ],
              ),
            if (level > 1 && app.needWatch.isNotEmpty) ...[
              const SizedBox(height: 13),
              const Align(alignment: Alignment.centerLeft, child: L('PERLU DIPANTAU')),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final m in app.needWatch)
                      Padding(
                        padding: const EdgeInsets.only(right: 9),
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(5, 5, 12, 5),
                          decoration: BoxDecoration(
                            border: Border.all(
                                color: m.state == MemberState.paused
                                    ? const Color(0xFFF3C9A8)
                                    : context.line),
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Row(
                            children: [
                              Avatar(m.initials, color: m.color, size: 26),
                              const SizedBox(width: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(m.name,
                                      style: TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w700,
                                          color: context.fg)),
                                  Mono(
                                      m.state == MemberState.paused
                                          ? 'istirahat ${m.lastPing.inMinutes} mnt'
                                          : 'sinyal hilang ${fmtAgo(m.lastPing)}',
                                      size: 9.5,
                                      color: m.state == MemberState.paused
                                          ? K.warningInk
                                          : context.dim),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );
  }
}

class _SheetBox extends StatelessWidget {
  const _SheetBox(
      {required this.label,
      required this.name,
      required this.detail,
      required this.tone});

  final String label;
  final String name;
  final String detail;
  final Color tone;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
        decoration: BoxDecoration(
            color: context.isDark ? K.cardD : K.bgL,
            borderRadius: BorderRadius.circular(13)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            L(label, size: 9),
            Text(name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w700, color: context.fg)),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Mono(detail, size: 11, color: tone),
            ),
          ],
        ),
      );
}
