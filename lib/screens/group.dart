import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../state.dart';
import '../theme.dart';
import '../widgets.dart';
import 'onboarding.dart';

/// 16 · GRUP · ANGGOTA & KODE
class GroupScreen extends StatelessWidget {
  const GroupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final g = app.activeGroup;
    final admin = app.isAdmin;

    return ListView(
      padding: const EdgeInsets.fromLTRB(K.pad, 8, K.pad, 20),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Grup',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: context.fg,
                  letterSpacing: -.6,
                ),
              ),
            ),
            if (g != null)
              Badge2(
                admin ? 'ADMIN · PEMBUAT' : 'ANGGOTA',
                fg: admin ? K.orangeDeep : context.dim,
                bg: admin
                    ? (context.isDark ? const Color(0x29FF6A13) : K.orangeSoft)
                    : context.fill,
                radius: 99,
              ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _SquareBtn(
                icon: Icons.add,
                label: 'Buat grup',
                filled: true,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CreateGroupScreen()),
                ),
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: _SquareBtn(
                icon: Icons.download_outlined,
                label: 'Gabung kode',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => JoinGroupScreen(
                          initialName: app.myName == 'Saya' ? '' : app.myName)),
                ),
              ),
            ),
          ],
        ),
        if (app.createdGroups.isNotEmpty) ...[
          const SizedBox(height: 10),
          Panel(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 2),
            child: MenuRow(
              'Grup yang pernah kamu buat',
              icon: Icons.history,
              trailing: '${app.createdGroups.length}',
              divider: false,
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const MyCreatedGroupsScreen())),
            ),
          ),
        ],
        const SizedBox(height: 10),
        if (g == null)
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Belum ada grup aktif',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: context.fg,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Rekaman rute tetap jalan tanpa grup. Buat grup kalau mau '
                  'berbagi lokasi live saat jalan bareng.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          )
        else ...[
          if (app.groups.length > 1)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                L('PILIH GRUP AKTIF', size: 9),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final grp in app.groups)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: GestureDetector(
                            onTap: () => app.switchGroup(grp.code),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: grp.code == g?.code
                                    ? K.orange
                                    : context.card,
                                border: grp.code == g?.code
                                    ? null
                                    : Border.all(color: context.line),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                grp.name,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: grp.code == g?.code
                                      ? Colors.white
                                      : context.fg,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          Panel(
            radius: 18,
            border: K.success,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Avatar(g.initials, size: 44, radius: 12),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            g.name,
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: context.fg,
                            ),
                          ),
                          Mono(
                            '${g.sport.label.toUpperCase()} · ${app.members.length} anggota',
                            size: 10.5,
                          ),
                        ],
                      ),
                    ),
                    Badge2(
                      'AKTIF',
                      fg: K.successInk,
                      bg: context.isDark
                          ? const Color(0x2E17A867)
                          : K.successSoft,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 13,
                    vertical: 11,
                  ),
                  decoration: BoxDecoration(
                    color: context.fill,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const L('KODE UNDANGAN', size: 9),
                            Text(
                              g.code,
                              style: mono(
                                17,
                                color: context.fg,
                                weight: FontWeight.w700,
                                track: 2,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _SmallBtn(
                        icon: Icons.copy_rounded,
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: g.code));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Kode disalin')),
                          );
                        },
                      ),
                      const SizedBox(width: 10),
                      _SmallBtn(
                        icon: Icons.share_outlined,
                        filled: true,
                        onTap: () => SharePlus.instance.share(
                          ShareParams(
                            text:
                                'Undanggan Join!\n\nKode: ${g.code}\n\nDownload app: [link play store]',
                            subject: 'Undangan Grup - ${g.name}',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          L(
            'ANGGOTA · ${app.members.length}'
            '${admin ? " · ADMIN BISA MENGELUARKAN ANGGOTA" : ""}',
          ),
          const SizedBox(height: 10),
          Panel(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 2),
            child: Column(
              children: [
                for (final (i, m) in app.members.indexed)
                  _MemberLine(
                    m,
                    canKick: admin && !m.isMe,
                    divider: i < app.members.length - 1,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Panel(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 2),
            child: Column(
              children: [
                if (admin)
                  MenuRow(
                    'Pengaturan grup',
                    icon: Icons.settings_outlined,
                    onTap: () => _groupSettings(context, app, g),
                  ),
                if (admin)
                  MenuRow(
                    'Hapus grup',
                    icon: Icons.delete_outline,
                    color: K.danger,
                    divider: true,
                    chevron: false,
                    onTap: () => _confirm(
                      context,
                      'Hapus grup ${g.name}?',
                      'Grup akan terhapus selamanya. Semua anggota kehilangan akses.',
                      () => app.leaveGroup(
                        groupCode: g.code,
                        deleteIfAdmin: true,
                      ),
                    ),
                  ),
                if (!admin)
                  MenuRow(
                    'Keluar dari grup',
                    icon: Icons.logout,
                    divider: false,
                    chevron: false,
                    onTap: () => _confirm(
                      context,
                      'Keluar dari ${g.name}?',
                      'Kamu bisa gabung lagi pakai kode undangan.',
                      () => app.leaveGroup(groupCode: g.code),
                    ),
                  )
                else
                  MenuRow(
                    'Keluar sebagai admin',
                    icon: Icons.logout,
                    divider: false,
                    chevron: false,
                    onTap: () => _confirm(
                      context,
                      'Keluar dari ${g.name}?',
                      'Grup akan terhapus kalau tidak ada admin pengganti.',
                      () => app.leaveGroup(groupCode: g.code),
                    ),
                  ),
                if (g.localOnly)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(
                      'Grup ini belum ada di server, jadi anggota lain belum bisa '
                      'gabung. Cek koneksi lalu buat ulang.',
                      style: TextStyle(fontSize: 12, color: context.dim),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// Grup yang pernah dibuat sendiri di HP ini — termasuk yang sudah
/// ditinggalkan. Kode undangannya tersimpan lokal, jadi admin bisa masuk
/// lagi tanpa perlu diundang ulang, lalu (kalau memang mau) menghapusnya
/// lewat menu "Hapus grup" di layar Grup setelah masuk.
class MyCreatedGroupsScreen extends StatefulWidget {
  const MyCreatedGroupsScreen({super.key});

  @override
  State<MyCreatedGroupsScreen> createState() => _MyCreatedGroupsScreenState();
}

class _MyCreatedGroupsScreenState extends State<MyCreatedGroupsScreen> {
  String? _busyCode;

  Future<void> _open(AppState app, CreatedGroupRef c) async {
    setState(() => _busyCode = c.code);
    final err = await app.rejoinCreatedGroup(c.code);
    if (!mounted) return;
    setState(() => _busyCode = null);
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
      return;
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final list = [...app.createdGroups]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return Scaffold(
      appBar: backBar(context, 'Grup yang pernah kamu buat'),
      body: list.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text('Belum ada grup yang kamu buat.',
                    style: TextStyle(fontSize: 14, color: context.dim)),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(K.pad, 8, K.pad, 20),
              children: [
                for (final c in list) ...[
                  _CreatedGroupRow(
                    ref: c,
                    aktif: app.groups.any((g) => g.code == c.code),
                    busy: _busyCode == c.code,
                    onTap: () => _open(app, c),
                  ),
                  const SizedBox(height: 10),
                ],
              ],
            ),
    );
  }
}

class _CreatedGroupRow extends StatelessWidget {
  const _CreatedGroupRow(
      {required this.ref, required this.aktif, required this.busy, required this.onTap});

  final CreatedGroupRef ref;
  final bool aktif;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Panel(
        child: Row(
          children: [
            Avatar(ref.name.isEmpty ? '??' : ref.name.substring(0, 1).toUpperCase(),
                size: 40, radius: 12),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(ref.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700, color: context.fg)),
                  const SizedBox(height: 3),
                  Mono('${ref.code} · ${ref.sport.label.toUpperCase()}', size: 10),
                  const SizedBox(height: 3),
                  Text(
                      aktif
                          ? 'Kamu masih anggota'
                          : 'Kamu keluar ${fmtAgo(DateTime.now().difference(ref.leftAt ?? ref.createdAt))} lalu',
                      style: TextStyle(fontSize: 11.5, color: context.dim)),
                ],
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 84,
              child: BigBtn(
                busy ? '…' : (aktif ? 'Buka' : 'Masuk lagi'),
                height: 38,
                onTap: busy ? null : onTap,
              ),
            ),
          ],
        ),
      );
}

Future<void> _confirm(
  BuildContext context,
  String title,
  String body,
  Future<void> Function() onOk,
) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Batal'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Lanjut', style: TextStyle(color: K.danger)),
        ),
      ],
    ),
  );
  if (ok == true) {
    await onOk();
  }
}

Future<void> _groupSettings(BuildContext context, AppState app, Group g) async {
  final name = TextEditingController(text: g.name);
  final target = TextEditingController(
    text: g.monthlyTargetKm.round().toString(),
  );
  var sport = g.sport;

  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setLocal) => AlertDialog(
        title: const Text('Pengaturan grup'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              decoration: const InputDecoration(labelText: 'Nama grup'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: target,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Target bulanan (km)',
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                for (final s in Sport.values)
                  Pill(
                    s.label,
                    selected: s == sport,
                    selectedColor: K.orange,
                    monoStyle: false,
                    onTap: () => setLocal(() => sport = s),
                  ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Simpan'),
          ),
        ],
      ),
    ),
  );
  if (ok == true) {
    await app.saveGroupSettings(
      name: name.text.trim().isEmpty ? g.name : name.text.trim(),
      sport: sport,
      targetKm: double.tryParse(target.text) ?? g.monthlyTargetKm,
    );
  }
  name.dispose();
  target.dispose();
}

class _MemberLine extends StatelessWidget {
  const _MemberLine(this.m, {required this.canKick, required this.divider});

  final Member m;
  final bool canKick;
  final bool divider;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final me = m.isMe;
    final sub = me
        ? (m.isAdmin ? 'ADMIN · PEMBUAT GRUP' : 'ANGGOTA')
        : (m.sharesLocation
              ? '${m.state == MemberState.paused ? "istirahat" : "sedang ${m.sport.label.toLowerCase()}"} · ${fmtAgo(m.lastPing)}'
              : 'berbagi lokasi mati');
    final tag = me
        ? 'BAGI LOKASI'
        : switch (m.state) {
            MemberState.moving => 'LIVE',
            MemberState.paused => 'JEDA',
            MemberState.offline => 'OFFLINE',
          };

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: divider
          ? BoxDecoration(
              border: Border(bottom: BorderSide(color: context.hair)),
            )
          : null,
      child: Row(
        children: [
          Avatar(m.initials, color: m.color, size: 34),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        m.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: context.fg,
                        ),
                      ),
                    ),
                    if (me)
                      Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: Mono('· SAYA', size: 9),
                      ),
                  ],
                ),
                Mono(sub, size: 9.5),
              ],
            ),
          ),
          Mono(
            tag,
            size: 9.5,
            color: me ? K.successInk : m.stateColor,
            weight: FontWeight.w700,
            track: .8,
          ),
          if (canKick)
            IconButton(
              icon: const Icon(Icons.close, size: 14, color: K.danger),
              onPressed: () => _confirm(
                context,
                'Keluarkan ${m.name}?',
                'Dia berhenti berbagi lokasi ke grup ini dan harus diundang ulang.',
                () => app.kick(m),
              ),
            ),
        ],
      ),
    );
  }
}

class _SquareBtn extends StatelessWidget {
  const _SquareBtn({
    required this.icon,
    required this.label,
    this.filled = false,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final bool filled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(K.r),
    child: Container(
      height: 70,
      decoration: BoxDecoration(
        color: filled ? K.orange : context.card,
        border: filled ? null : Border.all(color: context.line),
        borderRadius: BorderRadius.circular(K.r),
        boxShadow: filled ? K.shadowOrange : null,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 19, color: filled ? Colors.white : context.fg),
          const SizedBox(height: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: filled ? Colors.white : context.fg,
            ),
          ),
        ],
      ),
    ),
  );
}

class _SmallBtn extends StatelessWidget {
  const _SmallBtn({required this.icon, this.onTap, this.filled = false});

  final IconData icon;
  final VoidCallback? onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(10),
    child: Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: filled ? K.orange : context.card,
        border: filled ? null : Border.all(color: context.line),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, size: 16, color: filled ? Colors.white : context.fg),
    ),
  );
}
