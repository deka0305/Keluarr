import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../state.dart';
import '../theme.dart';
import '../widgets.dart';

/// 01 · ONBOARDING / GABUNG GRUP
class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 26, 22, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                        color: K.orange, borderRadius: BorderRadius.circular(17)),
                    child: const Text('KL',
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -.5)),
                  ),
                  const Spacer(),
                  Pill(app.indonesian ? 'ID / EN' : 'EN / ID',
                      onTap: () => app.set(() => app.indonesian = !app.indonesian)),
                  const SizedBox(width: 8),
                  _RoundIcon(
                    icon: Icons.dark_mode_outlined,
                    onTap: () => app.set(() => app.themeMode =
                        app.themeMode == ThemeMode.dark
                            ? ThemeMode.light
                            : ThemeMode.dark),
                  ),
                ],
              ),
              const SizedBox(height: 34),
              Text('Mulai dengan\ngrup kamu',
                  style: Theme.of(context).textTheme.headlineLarge),
              const SizedBox(height: 12),
              Text(
                  'Grup dipakai untuk berbagi lokasi live dan status aktivitas. '
                  'Rekaman rute GPS kamu tetap pribadi.',
                  style: TextStyle(fontSize: 14.5, height: 1.55, color: context.dim)),
              const SizedBox(height: 26),
              Row(
                children: [
                  Expanded(
                    child: _BigTile(
                      icon: Icons.add,
                      label: 'Buat grup',
                      filled: true,
                      onTap: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const CreateGroupScreen())),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _BigTile(
                      icon: Icons.download_outlined,
                      label: 'Gabung pakai kode',
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => JoinGroupScreen(
                                  initialName:
                                      app.myName == 'Saya' ? '' : app.myName))),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 30),
              const L('GRUP SAYA · 0'),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
                decoration: BoxDecoration(
                  border: Border.all(
                      color: context.isDark ? K.lineD : const Color(0xFFD6D0C4)),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Text('Belum ada grup',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600, color: context.fg)),
                    const SizedBox(height: 5),
                    Text('Kamu tetap bisa merekam rute sendiri tanpa grup.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12.5, height: 1.5, color: context.dim)),
                  ],
                ),
              ),
              const Spacer(),
              // FittedBox: label ini paling panjang di layar, dan harus tetap
              // utuh di HP kecil maupun saat ukuran font sistem diperbesar.
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.shield_outlined, size: 15, color: K.success),
                    const SizedBox(width: 8),
                    Text('JEJAK GPS PRIBADI · TIDAK DIBAGIKAN',
                        style: mono(10, color: const Color(0xFF4C8F6E), track: .8)),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Center(
                child: TextButton(
                  onPressed: app.skipGroup,
                  child: Text('Lanjut tanpa grup',
                      style: TextStyle(fontSize: 13, color: context.dim)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoundIcon extends StatelessWidget {
  const _RoundIcon({required this.icon, this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(99),
        child: Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: context.card,
            shape: BoxShape.circle,
            border: Border.all(color: context.line),
          ),
          child: Icon(icon, size: 16, color: context.fg),
        ),
      );
}

class _BigTile extends StatelessWidget {
  const _BigTile(
      {required this.icon, required this.label, this.filled = false, this.onTap});

  final IconData icon;
  final String label;
  final bool filled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          height: 104,
          decoration: BoxDecoration(
            color: filled ? K.orange : context.card,
            border: filled ? null : Border.all(color: context.line),
            borderRadius: BorderRadius.circular(18),
            boxShadow: filled ? K.shadowOrange : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 24, color: filled ? Colors.white : context.fg),
              const SizedBox(height: 9),
              Text(label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: filled ? Colors.white : context.fg)),
            ],
          ),
        ),
      );
}

/// 02 · BUAT GRUP
class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final _myName = TextEditingController();
  final _groupName = TextEditingController(text: 'Keluarr Pagi');
  Sport _sport = Sport.run;
  bool _loc = true;
  bool _status = true;
  bool _busy = false;

  @override
  void dispose() {
    _myName.dispose();
    _groupName.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return Scaffold(
      appBar: backBar(context, 'Buat grup'),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(K.pad, 6, K.pad, K.pad),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    const L('NAMA ANDA'),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _myName,
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600, color: context.fg),
                      decoration: InputDecoration(
                        hintText: 'Masukkan nama kamu',
                        filled: true,
                        fillColor: context.card,
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: context.line),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: K.orange, width: 2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const L('NAMA GRUP'),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _groupName,
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600, color: context.fg),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: context.card,
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: context.line),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: K.orange, width: 2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const L('AKTIVITAS UTAMA'),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 9,
                      runSpacing: 9,
                      children: [
                        for (final s in Sport.values)
                          Pill(s.label,
                              selected: _sport == s,
                              selectedColor: K.orange,
                              monoStyle: false,
                              onTap: () => setState(() => _sport = s)),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const L('YANG DILIHAT ANGGOTA'),
                    const SizedBox(height: 10),
                    Panel(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: Column(
                        children: [
                          SwitchRow(
                              title: 'Lokasi live',
                              subtitle: 'Titik posisi & nama',
                              value: _loc,
                              onChanged: (v) => setState(() => _loc = v)),
                          SwitchRow(
                              title: 'Status aktivitas',
                              subtitle: '"Sedang lari", "istirahat"',
                              value: _status,
                              onChanged: (v) => setState(() => _status = v)),
                          const SwitchRow(
                              title: 'Jejak GPS rute',
                              subtitle: 'Selalu pribadi · tidak bisa dinyalakan',
                              value: false,
                              locked: true,
                              divider: false),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
                      decoration: BoxDecoration(
                        color: context.isDark
                            ? const Color(0x1FE8A317)
                            : const Color(0xFFFDF4E7),
                        border: Border.all(
                            color: context.isDark
                                ? const Color(0x44E8A317)
                                : const Color(0xFFF0DDBC)),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                          'Anggota hanya melihat posisi dan status kamu selama grup '
                          'aktif. Rekaman rute, kecepatan, dan kalori tersimpan di '
                          'perangkat kamu.',
                          style: TextStyle(
                              fontSize: 12.5,
                              height: 1.55,
                              color: context.isDark
                                  ? const Color(0xFFE8C078)
                                  : const Color(0xFF8A6320))),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              BigBtn(_busy ? 'Membuat…' : 'Buat grup',
                  onTap: _busy
                      ? null
                      : () async {
                          setState(() => _busy = true);
                          app.myName = _myName.text.trim().isEmpty ? 'Saya' : _myName.text.trim();
                          app.shareLiveLocation = _loc;
                          app.shareStatus = _status;
                          await app.createGroup(_groupName.text, _sport);
                          if (!context.mounted) return;
                          setState(() => _busy = false);
                          Navigator.pop(context);
                          _showCodeSheet(context, app.activeGroup!);
                        }),
            ],
          ),
        ),
      ),
    );
  }
}

void _showCodeSheet(BuildContext context, Group g) {
  showModalBottomSheet(
    context: context,
    backgroundColor: context.fill,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
    builder: (context) => Padding(
      padding: const EdgeInsets.fromLTRB(K.pad, 12, K.pad, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                    color: context.line, borderRadius: BorderRadius.circular(99))),
          ),
          const SizedBox(height: 16),
          Text('Grup ${g.name} dibuat',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text('Bagikan kode ini ke anggota supaya mereka bisa gabung.',
              style: TextStyle(fontSize: 13, color: context.dim)),
          const SizedBox(height: 16),
          Panel(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const L('KODE UNDANGAN'),
                      Text(g.code,
                          style: mono(19,
                              color: context.fg, weight: FontWeight.w700, track: 2)),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  color: context.fg,
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: g.code));
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Kode disalin')));
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          BigBtn('Ke peta', onTap: () => Navigator.pop(context)),
        ],
      ),
    ),
  );
}

/// 03 · GABUNG PAKAI KODE
class JoinGroupScreen extends StatefulWidget {
  const JoinGroupScreen({super.key, this.initialName = ''});

  /// Nama yang sudah pernah diisi pengguna, supaya gabung grup kedua tidak
  /// menimpanya jadi kosong lagi.
  final String initialName;

  @override
  State<JoinGroupScreen> createState() => _JoinGroupScreenState();
}

class _JoinGroupScreenState extends State<JoinGroupScreen> {
  late final _myName = TextEditingController(text: widget.initialName);
  String _code = '';
  String? _error;
  bool _busy = false;

  static const _len = 7; // KLR + 4 karakter

  @override
  void dispose() {
    _myName.dispose();
    super.dispose();
  }

  bool get _nameOk => _myName.text.trim().isNotEmpty;

  Future<void> _submit(AppState app) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    app.myName = _myName.text.trim();
    final err = await app.joinGroup(_code);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = err;
    });
    if (err == null) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return Scaffold(
      appBar: backBar(context, 'Gabung grup'),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(K.pad, 6, K.pad, K.pad),
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
              const L('NAMA ANDA'),
              const SizedBox(height: 8),
              TextField(
                controller: _myName,
                onChanged: (_) => setState(() {}),
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w600, color: context.fg),
                decoration: InputDecoration(
                  hintText: 'Masukkan nama kamu',
                  filled: true,
                  fillColor: context.card,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: context.line),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: K.orange, width: 2),
                  ),
                ),
              ),
              if (!_nameOk)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text('Anggota lain melihat nama ini di grup.',
                      style: TextStyle(fontSize: 11.5, color: context.dim)),
                ),
              const SizedBox(height: 20),
              Text('Masukkan kode dari admin grup, atau scan QR undangannya.',
                  style: TextStyle(fontSize: 14.5, height: 1.55, color: context.dim)),
              const SizedBox(height: 18),
              _CodeBoxes(
                code: _code,
                length: _len,
                error: _error != null,
                onChanged: (v) => setState(() {
                  _code = v;
                  _error = null;
                }),
              ),
              if (!app.online)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(app.cloudError ?? 'Butuh koneksi untuk gabung grup.',
                      style: mono(11, color: K.warningInk, track: .5)),
                ),
              const SizedBox(height: 18),
              Panel(
                child: Row(
                  children: [
                    Icon(Icons.qr_code_2, size: 20, color: context.fg),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text('Scan QR undangan',
                          style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w600,
                              color: context.fg)),
                    ),
                    Icon(Icons.chevron_right, size: 18, color: context.dim),
                  ],
                ),
              ),
                    ],
                  ),
                ),
              ),
              BigBtn(_busy ? 'Menggabungkan…' : 'Gabung grup',
                  onTap: _code.length == _len && _nameOk && !_busy
                      ? () => _submit(app)
                      : null,
                  color: _code.length == _len && _nameOk ? null : context.line),
            ],
          ),
        ),
      ),
    );
  }
}

/// Enam kotak kode + keyboard tersembunyi (satu TextField menyetir semuanya).
class _CodeBoxes extends StatefulWidget {
  const _CodeBoxes(
      {required this.code,
      required this.length,
      required this.onChanged,
      this.error = false});

  final String code;
  final int length;
  final ValueChanged<String> onChanged;
  final bool error;

  @override
  State<_CodeBoxes> createState() => _CodeBoxesState();
}

class _CodeBoxesState extends State<_CodeBoxes> {
  final _focus = FocusNode();
  late final _ctrl = TextEditingController(text: widget.code);

  @override
  void dispose() {
    _focus.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Row(
          children: [
            for (var i = 0; i < widget.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(
                child: Container(
                  height: 60,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: context.card,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: widget.error
                          ? K.danger
                          : (i == widget.code.length ? K.orange : context.line),
                      width: i == widget.code.length || widget.error ? 2 : 1,
                    ),
                  ),
                  child: Text(
                    i < widget.code.length ? widget.code[i] : '·',
                    style: mono(24,
                        color: i < widget.code.length
                            ? context.fg
                            : const Color(0xFFC4C8CC),
                        weight: FontWeight.w700,
                        track: 0),
                  ),
                ),
              ),
            ],
          ],
        ),
        Positioned.fill(
          child: Opacity(
            opacity: 0,
            child: TextField(
              controller: _ctrl,
              focusNode: _focus,
              autofocus: true,
              maxLength: widget.length,
              textCapitalization: TextCapitalization.characters,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9]')),
              ],
              onChanged: (v) => widget.onChanged(v.toUpperCase()),
            ),
          ),
        ),
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () => _focus.requestFocus(),
          ),
        ),
      ],
    );
  }
}
