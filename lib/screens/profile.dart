import 'package:flutter/material.dart';

import '../state.dart';
import '../theme.dart';
import '../widgets.dart';
import 'share.dart';

/// 18 · PROFIL & STATISTIK
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final bySport = app.kmBySport;
    final maxSport = bySport.values.fold(0.0, (a, b) => a > b ? a : b);
    final fast = app.fastest5k;
    final far = app.longest;

    return Scaffold(
      appBar: backBar(context, 'Profil'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(K.pad, 0, K.pad, 20),
        children: [
          Row(
            children: [
              Avatar(app.me.initials, size: 66, radius: 20),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(app.myName, style: Theme.of(context).textTheme.titleLarge),
                    Mono(
                        '${app.myCity} · GABUNG ${fmtMonthYear(app.joinedAt)}',
                        size: 10.5),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 20),
                color: context.fg,
                onPressed: _editName,
              ),
            ],
          ),
          const SizedBox(height: K.gap),
          Row(
            children: [
              Expanded(
                child: Panel(
                  color: K.ink,
                  border: Colors.transparent,
                  radius: 14,
                  child: StatTile(
                      label: 'TOTAL SEUMUR',
                      value: fmtKm(app.lifetimeKm),
                      unit: 'km',
                      onDark: true),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Panel(
                  radius: 14,
                  child: StatTile(
                      label: 'AKTIVITAS', value: '${app.activities.length}'),
                ),
              ),
            ],
          ),
          const SizedBox(height: K.gap),
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                L('PER OLAHRAGA · ${DateTime.now().year}'),
                const SizedBox(height: 12),
                for (final s in Sport.values)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 11),
                    child: Row(
                      children: [
                        SizedBox(
                            width: 62,
                            child: Mono(s.label.split(' ').first.toUpperCase(),
                                size: 10, color: context.fg)),
                        Expanded(
                          child: Meter(
                              maxSport == 0 ? 0 : bySport[s]! / maxSport,
                              height: 8,
                              color: bySport[s]! / (maxSport == 0 ? 1 : maxSport) > .6
                                  ? K.orange
                                  : (bySport[s]! / (maxSport == 0 ? 1 : maxSport) > .3
                                      ? K.orangeMid
                                      : K.orangePale)),
                        ),
                        const SizedBox(width: 11),
                        SizedBox(
                          width: 56,
                          child: Text('${bySport[s]!.round()} km',
                              textAlign: TextAlign.right,
                              style: mono(10.5,
                                  color: context.fg,
                                  weight: FontWeight.w700,
                                  track: .3)),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: K.gap),
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const L('REKOR PRIBADI'),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _Record('5K TERCEPAT',
                          fast == null ? '—' : fmtClock(fast.avgPaceSecPerKm * 5)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _Record(
                          'TERJAUH', far == null ? '—' : '${fmtKm(far.km)} km'),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                        child: _Record('ELEVASI', '${app.bestElev.round()} m')),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: K.gap),
          Panel(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 2),
            child: Column(
              children: [
                MenuRow('Privasi & berbagi',
                    icon: Icons.shield_outlined,
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const PrivacyScreen()))),
                MenuRow('Tema',
                    icon: Icons.dark_mode_outlined,
                    trailing: _themeLabel(app.themeMode),
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const PrivacyScreen(jumpToTampilan: true)))),
                MenuRow('Bahasa',
                    icon: Icons.language,
                    trailing: app.indonesian ? 'INDONESIA' : 'ENGLISH',
                    divider: false,
                    onTap: () => app.set(() => app.indonesian = !app.indonesian)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editName() async {
    final app = AppScope.of(context);
    final ctrl = TextEditingController(text: app.myName);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ubah nama'),
        content: TextField(controller: ctrl, autofocus: true),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          TextButton(
              onPressed: () => Navigator.pop(context, true), child: const Text('Simpan')),
        ],
      ),
    );
    if (ok == true && ctrl.text.trim().isNotEmpty) {
      app.set(() => app.myName = ctrl.text.trim());
    }
    ctrl.dispose();
  }
}

String _themeLabel(ThemeMode m) => switch (m) {
      ThemeMode.system => 'SISTEM',
      ThemeMode.light => 'TERANG',
      ThemeMode.dark => 'GELAP',
    };

class _Record extends StatelessWidget {
  const _Record(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
            color: context.fill, borderRadius: BorderRadius.circular(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            L(label, size: 9),
            Text(value,
                style: TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w800, color: context.fg)),
          ],
        ),
      );
}

/// 19 · PRIVASI, TEMA & BAHASA
class PrivacyScreen extends StatefulWidget {
  const PrivacyScreen({super.key, this.jumpToTampilan = false});

  /// True kalau dibuka dari menu "Tema" di Profil — langsung gulir ke bagian
  /// TAMPILAN supaya tidak terasa salah layar.
  final bool jumpToTampilan;

  @override
  State<PrivacyScreen> createState() => _PrivacyScreenState();
}

class _PrivacyScreenState extends State<PrivacyScreen> {
  final _tampilanKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    if (widget.jumpToTampilan) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final ctx = _tampilanKey.currentContext;
        if (ctx != null) {
          Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 300));
        }
      });
    }
  }

  /// Ubah izin berbagi lalu terapkan ke server (kirim/hapus node live &
  /// agregat) — tanpa ini togglenya hanya kosmetik.
  void _apply(AppState app, void Function() change) {
    app.set(change);
    app.applySharing();
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return Scaffold(
      appBar: backBar(context, 'Privasi & berbagi'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(K.pad, 0, K.pad, 20),
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
            decoration: BoxDecoration(
              color: context.isDark ? const Color(0x2317A867) : const Color(0xFFEEF7F1),
              border: Border.all(
                  color: context.isDark ? const Color(0x4417A867) : const Color(0xFFCDE9DA)),
              borderRadius: BorderRadius.circular(K.r),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(Icons.shield, size: 16, color: K.successInk),
                  const SizedBox(width: 9),
                  Text('ATURAN TETAP',
                      style: mono(9.5,
                          color: K.successInk, weight: FontWeight.w700, track: 1.2)),
                ]),
                const SizedBox(height: 7),
                Text(
                    'Jejak GPS rute kamu tidak pernah dikirim ke grup atau server. '
                    'Hanya kamu yang bisa melihat dan membagikannya.',
                    style: TextStyle(
                        fontSize: 12.5,
                        height: 1.5,
                        color: context.isDark
                            ? const Color(0xFF8FD9B6)
                            : const Color(0xFF2F6B51))),
              ],
            ),
          ),
          const SizedBox(height: 10),
          const L('YANG SAYA BAGIKAN KE GRUP'),
          const SizedBox(height: 10),
          Panel(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 2),
            child: Column(
              children: [
                SwitchRow(
                    title: 'Lokasi live',
                    subtitle: 'Titik posisi saat grup aktif',
                    value: app.shareLiveLocation,
                    onChanged: (v) => _apply(app, () => app.shareLiveLocation = v)),
                SwitchRow(
                    title: 'Status aktivitas',
                    subtitle: '"sedang lari" / "istirahat"',
                    value: app.shareStatus,
                    onChanged: (v) => _apply(app, () => app.shareStatus = v)),
                SwitchRow(
                    title: 'Kecepatan saat ini',
                    value: app.shareSpeed,
                    onChanged: (v) => _apply(app, () => app.shareSpeed = v)),
                SwitchRow(
                    title: 'Total km untuk leaderboard',
                    subtitle: 'Angka agregat, tanpa rute',
                    value: app.shareTotals,
                    onChanged: (v) => _apply(app, () => app.shareTotals = v)),
                const SwitchRow(
                    title: 'Jejak GPS rute',
                    subtitle: 'Terkunci pribadi',
                    value: false,
                    locked: true,
                    divider: false),
              ],
            ),
          ),
          const SizedBox(height: 10),
          L('TAMPILAN', key: _tampilanKey),
          const SizedBox(height: 10),
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Tema',
                    style: TextStyle(
                        fontSize: 14.5, fontWeight: FontWeight.w600, color: context.fg)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    for (final (i, m) in ThemeMode.values.indexed) ...[
                      if (i > 0) const SizedBox(width: 7),
                      Expanded(
                        child: _Choice(_themeLabel(m), app.themeMode == m,
                            () => app.set(() => app.themeMode = m)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 14),
                _Divided(
                  label: 'Bahasa',
                  children: [
                    _Choice('ID', app.indonesian,
                        () => app.set(() => app.indonesian = true),
                        dark: true, tight: true),
                    const SizedBox(width: 7),
                    _Choice('EN', !app.indonesian,
                        () => app.set(() => app.indonesian = false),
                        dark: true, tight: true),
                  ],
                ),
                const SizedBox(height: 14),
                _Divided(
                  label: 'Satuan',
                  children: [
                    _Choice('KM', app.metric, () => app.set(() => app.metric = true),
                        dark: true, tight: true),
                    const SizedBox(width: 7),
                    _Choice('MIL', !app.metric, () => app.set(() => app.metric = false),
                        dark: true, tight: true),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: BigBtn('Ekspor GPX',
                    filled: false,
                    height: 48,
                    onTap: () => exportGpx(context, app.activities)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: InkWell(
                  onTap: () => _confirmWipe(context, app),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: context.card,
                      border: Border.all(color: const Color(0xFFF0CFCF)),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Text('Hapus semua',
                        style: TextStyle(
                            fontSize: 13.5, fontWeight: FontWeight.w600, color: K.danger)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

Future<void> _confirmWipe(BuildContext context, AppState app) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Hapus semua rekaman?'),
      content: Text('${app.activities.length} aktivitas dan seluruh jejak GPS di '
          'perangkat ini akan hilang permanen.'),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
        TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus semua', style: TextStyle(color: K.danger))),
      ],
    ),
  );
  if (ok == true) app.wipeAll();
}

class _Divided extends StatelessWidget {
  const _Divided({required this.label, required this.children});

  final String label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.only(top: 13),
        decoration: BoxDecoration(border: Border(top: BorderSide(color: context.hair))),
        child: Row(
          children: [
            Expanded(
              child: Text(label,
                  style: TextStyle(
                      fontSize: 14.5, fontWeight: FontWeight.w600, color: context.fg)),
            ),
            ...children,
          ],
        ),
      );
}

class _Choice extends StatelessWidget {
  const _Choice(this.label, this.selected, this.onTap,
      {this.dark = false, this.tight = false});

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool dark;
  final bool tight;

  @override
  Widget build(BuildContext context) {
    final bg = selected ? (dark ? K.ink : K.orange) : context.fill;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: 36,
        alignment: Alignment.center,
        padding: tight ? const EdgeInsets.symmetric(horizontal: 14) : null,
        decoration: BoxDecoration(
          color: bg,
          border: selected ? null : Border.all(color: context.line),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(label,
            style: mono(10,
                color: selected ? Colors.white : context.fg,
                weight: selected ? FontWeight.w700 : FontWeight.w500,
                track: .8)),
      ),
    );
  }
}
