import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart' hide Path;

import 'data/cloud.dart';
import 'data/location.dart';
import 'data/pack.dart';
import 'data/polyline.dart';
import 'data/store.dart';
import 'data/track.dart';
import 'theme.dart';

export 'data/cloud.dart' show Cloud;
export 'data/location.dart' show Gps, GpsResult;
export 'data/store.dart' show Store;
export 'data/track.dart' show Track, normalize;

enum Sport { run, hike, bike, walk }

extension SportInfo on Sport {
  String get key => name;
  String get label => const {
        Sport.run: 'Lari',
        Sport.hike: 'Hiking',
        Sport.bike: 'Sepeda',
        Sport.walk: 'Jalan kaki',
      }[this]!;
  String get metrics => const {
        Sport.run: 'PACE · SPLIT KM · KALORI',
        Sport.hike: 'ELEVASI · DURASI · KALORI',
        Sport.bike: 'KECEPATAN · ELEVASI · KALORI',
        Sport.walk: 'LANGKAH · DURASI · KALORI',
      }[this]!;
  IconData get icon => const {
        Sport.run: Icons.directions_run,
        Sport.hike: Icons.terrain,
        Sport.bike: Icons.directions_bike,
        Sport.walk: Icons.directions_walk,
      }[this]!;

  /// kkal per km per kg (kasar) — cukup untuk estimasi tanpa sensor HR.
  double get kcalPerKm => const {
        Sport.run: 1.03,
        Sport.hike: 0.90,
        Sport.bike: 0.35,
        Sport.walk: 0.55,
      }[this]!;
}

Sport sportFromKey(String? k) =>
    Sport.values.firstWhere((s) => s.name == k, orElse: () => Sport.run);

enum MemberState { moving, paused, offline }

/// Berat badan untuk estimasi kalori. Knob kalibrasi — pindahkan ke profil
/// pengguna kalau angka kalori mulai dipakai serius.
const kBodyWeightKg = 70.0;

class KmSplit {
  const KmSplit(this.km, this.paceSec, {this.elevM = 0});

  final int km;
  final int paceSec;
  final double elevM;
}

class Activity {
  Activity({
    required this.id,
    required this.sport,
    required this.title,
    required this.startedAt,
    required this.distanceM,
    required this.movingSec,
    this.elapsedSec = 0,
    this.elevGainM = 0,
    this.topKmh = 0,
    this.splits = const [],
    this.track = const [],
    this.secs = const [],
    this.note = '',
  });

  final String id;
  Sport sport;
  String title;
  final DateTime startedAt;
  final double distanceM;
  final int movingSec;
  final int elapsedSec;
  final double elevGainM;
  final double topKmh;
  final List<KmSplit> splits;

  /// Jejak GPS. **LOKAL SAJA** — tidak pernah diunggah; tidak ada method di
  /// [Cloud] yang bisa mengirimnya.
  final List<LatLng> track;

  /// Detik sejak mulai untuk tiap titik di [track].
  final List<int> secs;
  String note;

  DateTime get endedAt => startedAt.add(Duration(seconds: max(movingSec, elapsedSec)));
  double get km => distanceM / 1000;
  double get avgSpeedKmh => movingSec == 0 ? 0 : km / (movingSec / 3600);
  int get avgPaceSecPerKm => distanceM < 10 ? 0 : (movingSec / km).floor();
  int get calories => (sport.kcalPerKm * km * kBodyWeightKg).round();
  bool get isPrivate => true;

  /// Jejak dalam ruang 0..1 untuk digambar tanpa peta (thumbnail & kartu share).
  List<Offset> get shape => normalize(track);

  Map<String, dynamic> toJson() => {
        'id': id,
        'sport': sport.name,
        'title': title,
        'start': startedAt.toIso8601String(),
        'dist': distanceM,
        'moving': movingSec,
        'elapsed': elapsedSec,
        'elev': elevGainM,
        'top': topKmh,
        'splits': [
          for (final s in splits) {'km': s.km, 'p': s.paceSec, 'e': s.elevM},
        ],
        'geom': encodePolyline(track),
        'secs': secs,
        if (note.isNotEmpty) 'note': note,
      };

  static Activity fromJson(Map<String, dynamic> j) => Activity(
        id: j['id'] as String,
        sport: sportFromKey(j['sport'] as String?),
        title: j['title'] as String? ?? 'Aktivitas',
        startedAt: DateTime.parse(j['start'] as String),
        distanceM: (j['dist'] as num?)?.toDouble() ?? 0,
        movingSec: (j['moving'] as num?)?.toInt() ?? 0,
        elapsedSec: (j['elapsed'] as num?)?.toInt() ?? 0,
        elevGainM: (j['elev'] as num?)?.toDouble() ?? 0,
        topKmh: (j['top'] as num?)?.toDouble() ?? 0,
        splits: [
          for (final s in (j['splits'] as List? ?? []))
            KmSplit((s as Map)['km'] as int, s['p'] as int,
                elevM: (s['e'] as num?)?.toDouble() ?? 0),
        ],
        track: decodePolyline(j['geom'] as String? ?? ''),
        secs: [for (final v in (j['secs'] as List? ?? [])) v as int],
        note: j['note'] as String? ?? '',
      );
}

class Member {
  Member({
    required this.uid,
    required this.name,
    this.role = 'member',
    this.state = MemberState.offline,
    this.sport = Sport.run,
    this.speedKmh = 0,
    this.heading = 0,
    this.gapM = 0,
    this.at,
    this.lastPing = Duration.zero,
    this.sharesLocation = false,
    this.monthKm = 0,
    this.monthCount = 0,
    this.isMe = false,
  });

  final String uid;
  String name;
  String role;
  MemberState state;
  Sport sport;
  double speedKmh;
  double heading;

  /// Meter relatif ke anggota terbelakang (dari [computePack]).
  double gapM;

  /// Lokasi live. Null berarti tidak berbagi lokasi / belum pernah kirim.
  LatLng? at;
  Duration lastPing;
  bool sharesLocation;
  double monthKm;
  int monthCount;
  final bool isMe;

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length > 1 && parts[1].isNotEmpty) {
      return (parts[0][0] + parts[1][0]).toUpperCase();
    }
    return name.trim().padRight(2, name.isEmpty ? 'K' : name[0]).substring(0, 2).toUpperCase();
  }

  bool get isAdmin => role == 'admin';

  /// Warna marker: diturunkan dari uid supaya tiap anggota tetap sama warnanya
  /// di semua HP tanpa perlu disimpan di server.
  Color get color {
    if (isMe) return K.orange;
    const palette = [K.success, K.blue, K.warning, Color(0xFF8B5CF6), Color(0xFF0EA5A4)];
    return palette[uid.hashCode.abs() % palette.length];
  }

  String get stateLabel => switch (state) {
        MemberState.moving => 'BERGERAK',
        MemberState.paused => 'ISTIRAHAT',
        MemberState.offline => 'OFFLINE',
      };

  Color get stateColor => switch (state) {
        MemberState.moving => K.successInk,
        MemberState.paused => K.warningInk,
        MemberState.offline => K.muted,
      };
}

class Group {
  Group({
    required this.code,
    required this.name,
    required this.sport,
    required this.adminUid,
    this.monthlyTargetKm = 500,
  });

  final String code;
  String name;
  Sport sport;
  String? adminUid;
  double monthlyTargetKm;

  /// True kalau grup ini hanya ada di HP ini (Firebase mati / belum siap).
  bool localOnly = false;

  String get initials => name
      .split(' ')
      .where((w) => w.isNotEmpty)
      .take(2)
      .map((w) => w[0].toUpperCase())
      .join();

  Map<String, dynamic> toJson() => {
        'code': code,
        'name': name,
        'sport': sport.name,
        'admin': adminUid,
        'target': monthlyTargetKm,
        'local': localOnly,
      };

  static Group fromJson(Map<String, dynamic> j) => Group(
        code: j['code'] as String,
        name: j['name'] as String? ?? 'Grup',
        sport: sportFromKey(j['sport'] as String?),
        adminUid: j['admin'] as String?,
        monthlyTargetKm: (j['target'] as num?)?.toDouble() ?? 500,
      )..localOnly = j['local'] as bool? ?? false;
}

/// Jejak grup yang pernah dibuat sendiri di HP ini — bertahan walau grupnya
/// sudah ditinggalkan atau tidak lagi ada di [AppState.groups], supaya
/// kodenya tidak hilang begitu saja. `adminUid` di server tidak pernah
/// berubah saat admin keluar, jadi masuk lagi dengan kode yang sama otomatis
/// mengembalikan status admin ([AppState.isAdmin] membaca `adminUid`, bukan
/// baris keanggotaan) — cukup untuk menghapus grup itu kalau memang mau.
class CreatedGroupRef {
  CreatedGroupRef({
    required this.code,
    required this.name,
    required this.sport,
    required this.createdAt,
    this.leftAt,
  });

  final String code;
  String name;
  Sport sport;
  final DateTime createdAt;

  /// Null berarti masih jadi anggota (belum pernah keluar sejak dibuat).
  DateTime? leftAt;

  Map<String, dynamic> toJson() => {
        'code': code,
        'name': name,
        'sport': sport.name,
        'created': createdAt.toIso8601String(),
        if (leftAt != null) 'left': leftAt!.toIso8601String(),
      };

  static CreatedGroupRef fromJson(Map<String, dynamic> j) => CreatedGroupRef(
        code: j['code'] as String,
        name: j['name'] as String? ?? 'Grup',
        sport: sportFromKey(j['sport'] as String?),
        createdAt:
            DateTime.tryParse(j['created'] as String? ?? '') ?? DateTime.now(),
        leftAt: j['left'] == null ? null : DateTime.tryParse(j['left'] as String),
      );
}

enum CardStyle { photoOverlay, mapOnPhoto, plain }

enum CardRatio { r9x16, r1x1 }

enum CardTemplate { dark, light, orange, forest }

class SharePreset {
  CardStyle style = CardStyle.photoOverlay;
  CardRatio ratio = CardRatio.r9x16;
  CardTemplate template = CardTemplate.dark;
  bool showCalories = true;
  bool showGroupName = false; // default OFF supaya grup tidak terekspos
  bool showMap = true;

  /// Foto pilihan pengguna (path lokal), null → latar gradien.
  String? photoPath;
}

/// Titik awal peta kalau GPS belum memberi fix (Tangerang, sesuai mockup).
const kFallbackCenter = LatLng(-6.1783, 106.6319);

class AppState extends ChangeNotifier {
  AppState({this.cloud, Gps? gps, Store? store, bool demo = false})
      : gps = gps ?? Gps(cloud ?? Cloud()),
        _store = store {
    this.gps.onFix = _onFix;
    if (demo) _seedDemo();
  }

  final Cloud? cloud;
  final Gps gps;
  final Store? _store;

  // ── Identitas & preferensi ──────────────────────────────────────────────
  String myName = 'Saya';
  String myCity = '';
  DateTime joinedAt = DateTime.now();
  ThemeMode themeMode = ThemeMode.system;
  bool metric = true;
  bool indonesian = true;

  // Privasi (layar 19). Jejak GPS terkunci pribadi — tidak ada setter.
  bool shareLiveLocation = true;
  bool shareStatus = true;
  bool shareSpeed = false;
  bool shareTotals = true;
  Sport lastSport = Sport.run;

  final List<Group> groups = [];

  /// Grup yang pernah dibuat sendiri di HP ini, termasuk yang sudah
  /// ditinggalkan — lihat [CreatedGroupRef].
  final List<CreatedGroupRef> createdGroups = [];
  String? activeGroupCode;
  bool skippedGroup = false;
  final List<Activity> activities = [];
  final SharePreset preset = SharePreset();
  RecordSession? session;

  /// Pesan status GPS/server terakhir untuk ditampilkan sekali di UI.
  String? notice;

  /// Posisiku terakhir dari GPS.
  LatLng? myPos;

  final Map<String, Member> _roster = {};
  StreamSubscription<CloudRoster>? _rosterSub;
  Pack _pack = Pack.empty;

  String get myUid => cloud?.uid ?? 'me';
  bool get online => cloud?.ready ?? false;
  String? get cloudError => cloud?.error;

  Group? get activeGroup {
    if (activeGroupCode == null) return null;
    try {
      return groups.firstWhere((g) => g.code == activeGroupCode);
    } catch (e) {
      return null;
    }
  }

  Member get me =>
      _roster[myUid] ??
      (_roster[myUid] = Member(uid: myUid, name: myName, isMe: true)
        ..role = activeGroup?.adminUid == myUid ? 'admin' : 'member');

  List<Member> get members {
    final list = _roster.values.toList()
      ..sort((a, b) => a.isMe
          ? -1
          : b.isMe
              ? 1
              : a.name.compareTo(b.name));
    return list;
  }

  bool get isAdmin => activeGroup != null && (activeGroup!.adminUid == myUid || activeGroup!.localOnly);
  List<Member> get tracked =>
      members.where((m) => m.sharesLocation && !m.isMe).toList();
  List<Member> get hidden => members.where((m) => !m.sharesLocation && !m.isMe).toList();
  List<Member> get live =>
      members.where((m) => m.sharesLocation && m.state != MemberState.offline).toList();

  // ── Muat & simpan ───────────────────────────────────────────────────────

  /// Dipanggil sekali saat app dibuka: sambung Firebase, baca simpanan lokal,
  /// lalu ikuti grup kalau ada.
  Future<void> boot() async {
    await cloud?.init();
    gps.cloud = cloud ?? Cloud();
    final saved = await _store?.load();
    if (saved != null) _restore(saved);
    me.name = myName;
    if (activeGroup != null) _followGroup();
    await _resumeCrashed();
    notifyListeners();
  }

  /// Rekaman yang tertinggal karena app dibunuh di tengah jalan — di Android
  /// itu kejadian biasa: layar mati, HP di kantong, proses dibersihkan sistem.
  Map<String, dynamic>? _crashed;

  Future<void> _resumeCrashed() async {
    final j = _crashed;
    _crashed = null;
    if (j == null || session != null) return;
    final RecordSession s;
    try {
      s = RecordSession.fromJson(j);
    } catch (e) {
      debugPrint('state: rekaman tertinggal tidak terbaca ($e)');
      return;
    }
    s.addListener(_onSessionTick);
    session = s;
    final idle = DateTime.now().difference(s.track.updatedAt ?? s.startedAt);
    if (idle > const Duration(hours: 6)) {
      // Terlalu basi untuk dilanjutkan — disimpan apa adanya, bukan dibuang.
      await finishSession();
      return;
    }
    notice = 'Rekaman ${fmtKm(s.km)} km dipulihkan — masih dijeda.';
  }

  void _restore(Map<String, dynamic> j) {
    myName = j['name'] as String? ?? myName;
    myCity = j['city'] as String? ?? '';
    joinedAt = j['joined'] == null
        ? joinedAt
        : DateTime.tryParse(j['joined'] as String) ?? joinedAt;
    themeMode = ThemeMode.values.firstWhere((m) => m.name == j['theme'],
        orElse: () => ThemeMode.system);
    metric = j['metric'] as bool? ?? true;
    indonesian = j['id'] as bool? ?? true;
    shareLiveLocation = j['shLoc'] as bool? ?? true;
    shareStatus = j['shStat'] as bool? ?? true;
    shareSpeed = j['shSpeed'] as bool? ?? false;
    shareTotals = j['shTotal'] as bool? ?? true;
    skippedGroup = j['skipped'] as bool? ?? false;
    lastSport = sportFromKey(j['lastSport'] as String?);
    activeGroupCode = j['activeGroup'] as String?;
    groups.addAll([
      for (final g in (j['groups'] as List? ?? []))
        Group.fromJson((g as Map).cast<String, dynamic>()),
    ]);
    activities
      ..clear()
      ..addAll([
        for (final a in (j['acts'] as List? ?? []))
          Activity.fromJson((a as Map).cast<String, dynamic>()),
      ]);
    activities.sort((a, b) => b.startedAt.compareTo(a.startedAt));
    createdGroups.addAll([
      for (final c in (j['created'] as List? ?? []))
        CreatedGroupRef.fromJson((c as Map).cast<String, dynamic>()),
    ]);
    _crashed = (j['session'] as Map?)?.cast<String, dynamic>();
  }

  Map<String, dynamic> _snapshot() => {
        'name': myName,
        'city': myCity,
        'joined': joinedAt.toIso8601String(),
        'theme': themeMode.name,
        'metric': metric,
        'id': indonesian,
        'shLoc': shareLiveLocation,
        'shStat': shareStatus,
        'shSpeed': shareSpeed,
        'shTotal': shareTotals,
        'skipped': skippedGroup,
        'lastSport': lastSport.name,
        'activeGroup': activeGroupCode,
        'groups': [for (final g in groups) g.toJson()],
        'created': [for (final c in createdGroups) c.toJson()],
        'acts': [for (final a in activities) a.toJson()],
        if (session != null) 'session': session!.toJson(),
      };

  void _persist() => _store?.save(_snapshot());

  Future<void> _persistNow() async => _store?.flushNow(_snapshot());

  /// Tulis simpanan sekarang juga. Dipanggil saat app masuk latar: debounce
  /// satu detik di [Store] bisa keburu mati bersama prosesnya.
  Future<void> flush() => _persistNow();

  /// Ubah state + simpan + beri tahu UI. Satu pintu supaya tidak ada perubahan
  /// yang lupa dipersistensi — bug paling gampang lolos di app seperti ini.
  void set(void Function() change) {
    change();
    _persist();
    notifyListeners();
  }

  // ── Grup ────────────────────────────────────────────────────────────────

  Future<void> createGroup(String name, Sport sport,
      {double targetKm = 500}) async {
    final code = Cloud.newCode();
    final g = Group(code: code, name: name.trim().isEmpty ? 'Grup Baru' : name.trim(),
        sport: sport, adminUid: myUid);
    if (online) {
      try {
        await cloud!.createGroup(
            code: code,
            name: g.name,
            sport: sport.name,
            targetKm: targetKm,
            myName: myName);
      } catch (e) {
        g.localOnly = true;
        notice = 'Grup dibuat di HP ini saja: ${_short(e)}';
      }
    } else {
      g.localOnly = true;
      notice = cloudError ?? 'Server tidak terjangkau — grup hanya di HP ini.';
    }
    g.monthlyTargetKm = targetKm;
    groups.add(g);
    if (!g.localOnly) {
      createdGroups.add(CreatedGroupRef(
          code: g.code, name: g.name, sport: g.sport, createdAt: DateTime.now()));
    }
    activeGroupCode = code;
    skippedGroup = false;
    _roster.clear();
    me.role = 'admin';
    _followGroup();
    _persist();
    notifyListeners();
  }

  /// Pratinjau grup dari kode sebelum benar-benar bergabung.
  Future<Group?> previewCode(String code) async {
    if (!online) return null;
    try {
      final g = await cloud!.fetchGroup(_norm(code));
      if (g == null) return null;
      return Group(
          code: g.code,
          name: g.name,
          sport: sportFromKey(g.sport),
          adminUid: g.adminUid,
          monthlyTargetKm: g.targetKm);
    } catch (e) {
      notice = 'Gagal membaca kode: ${_short(e)}';
      return null;
    }
  }

  /// Bergabung. Mengembalikan null kalau berhasil, atau pesan kesalahan.
  Future<String?> joinGroup(String code) async {
    if (!online) {
      return cloudError ?? 'Butuh koneksi untuk gabung grup.';
    }
    try {
      final g = await cloud!.join(_norm(code), myName);
      if (g == null) return 'Kode tidak ditemukan';
      final newG = Group(
          code: g.code,
          name: g.name,
          sport: sportFromKey(g.sport),
          adminUid: g.adminUid,
          monthlyTargetKm: g.targetKm);
      groups.add(newG);
      activeGroupCode = newG.code;
      skippedGroup = false;
      _roster.clear();
      _followGroup();
      _persist();
      notifyListeners();
      return null;
    } catch (e) {
      if (Cloud.isPermissionDenied(e)) return 'Kamu dicekal dari grup ini';
      return 'Gagal gabung: ${_short(e)}';
    }
  }

  /// Masuk lagi ke grup yang pernah dibuat sendiri lalu ditinggalkan — bukan
  /// gabung sebagai anggota baru, cuma menulis baris keanggotaan sendiri lagi.
  /// Kalau ini satu-satunya admin yang tersisa, [isAdmin] otomatis benar lagi
  /// begitu masuk, karena itu dibaca dari `adminUid` di server, bukan dari
  /// baris keanggotaan yang tadi terhapus saat keluar.
  Future<String?> rejoinCreatedGroup(String code) async {
    if (groups.any((g) => g.code == code)) {
      switchGroup(code);
      return null;
    }
    final err = await joinGroup(code);
    if (err == null) {
      final idx = createdGroups.indexWhere((c) => c.code == code);
      if (idx != -1) createdGroups[idx].leftAt = null;
      _persist();
    }
    return err;
  }

  Future<void> leaveGroup({String? groupCode, bool deleteIfAdmin = false}) async {
    final code = groupCode ?? activeGroupCode;
    if (code == null) return;

    final g = groups.firstWhere((x) => x.code == code, orElse: () => Group(code: '', name: '', sport: Sport.run, adminUid: null));
    if (g.code.isEmpty) return;

    if (online && !g.localOnly) {
      try {
        if (deleteIfAdmin && (g.adminUid == myUid || g.localOnly)) {
          await cloud!.deleteGroup(g.code);
        } else {
          await cloud!.leave(g.code);
        }
      } catch (e) {
        notice = 'Gagal memberi tahu server: ${_short(e)}';
      }
    }

    groups.removeWhere((x) => x.code == code);
    final createdIdx = createdGroups.indexWhere((c) => c.code == code);
    if (createdIdx != -1) {
      if (deleteIfAdmin) {
        // Benar-benar dihapus dari server: tidak ada lagi yang bisa dimasuki.
        createdGroups.removeAt(createdIdx);
      } else {
        // Yatim, bukan hilang — adminUid di server tetap milikku, jadi kode
        // ini masih bisa dipakai masuk lagi.
        createdGroups[createdIdx].leftAt = DateTime.now();
      }
    }
    if (activeGroupCode == code) {
      _rosterSub?.cancel();
      _rosterSub = null;
      _roster.clear();
      activeGroupCode = groups.isNotEmpty ? groups.first.code : null;
      if (groups.isEmpty) {
        skippedGroup = false;
      } else {
        _followGroup();
      }
    }
    await gps.stop();
    _persist();
    notifyListeners();
  }

  void switchGroup(String groupCode) {
    if (!groups.any((g) => g.code == groupCode)) return;
    activeGroupCode = groupCode;
    _rosterSub?.cancel();
    _rosterSub = null;
    _roster.clear();
    _followGroup();
    _persist();
    notifyListeners();
  }

  Future<void> kick(Member m) async {
    final g = activeGroup;
    if (g == null) return;
    if (online && !g.localOnly) {
      try {
        await cloud!.removeMember(g.code, m.uid, ban: true);
      } catch (e) {
        notice = 'Gagal mengeluarkan: ${_short(e)}';
        notifyListeners();
        return;
      }
    }
    _roster.remove(m.uid);
    notifyListeners();
  }

  Future<void> saveGroupSettings(
      {required String name, required Sport sport, required double targetKm}) async {
    final g = activeGroup;
    if (g == null) return;
    set(() {
      g
        ..name = name
        ..sport = sport
        ..monthlyTargetKm = targetKm;
      // Ikut disamakan supaya "Grup yang pernah kamu buat" tidak menampilkan
      // nama basi kalau grup ini nanti ditinggalkan.
      final created = createdGroups.where((c) => c.code == g.code);
      for (final c in created) {
        c
          ..name = name
          ..sport = sport;
      }
    });
    if (online && !g.localOnly) {
      try {
        await cloud!
            .putMeta(g.code, name: name, sport: sport.name, targetKm: targetKm);
      } catch (e) {
        notice = 'Perubahan belum sampai ke server: ${_short(e)}';
        notifyListeners();
      }
    }
  }

  void skipGroup() => set(() => skippedGroup = true);

  /// Ikuti anggota + lokasi live + agregat grup aktif.
  void _followGroup() {
    _rosterSub?.cancel();
    _rosterSub = null;
    final g = activeGroup;
    if (g == null || !online || g.localOnly) return;
    _rosterSub = cloud!.watchRoster(g.code).listen(_onRoster, onError: (Object e) {
      if (Cloud.isPermissionDenied(e)) {
        notice = 'Akses ke grup ini dicabut admin.';
        groups.removeWhere((x) => x.code == g.code);
        activeGroupCode = groups.isNotEmpty ? groups.first.code : null;
        skippedGroup = groups.isEmpty;
        _persist();
      } else {
        notice = 'Data grup tidak tersinkron: ${_short(e)}';
      }
      notifyListeners();
    });
    _pushStats();
  }

  void _onRoster(CloudRoster r) {
    final now = DateTime.now();
    // Anggota yang sudah tidak ada di server dibuang, termasuk markernya.
    _roster.removeWhere((uid, m) => !m.isMe && !r.members.containsKey(uid));

    for (final cm in r.members.values) {
      final m = _roster.putIfAbsent(
          cm.uid,
          () => Member(uid: cm.uid, name: cm.name, isMe: cm.uid == myUid));
      m
        ..name = cm.uid == myUid ? myName : cm.name
        ..role = cm.role;

      final pos = r.live[cm.uid];
      if (pos == null) {
        m
          ..sharesLocation = false
          ..at = null
          ..state = MemberState.offline;
      } else {
        final age = now.difference(pos.when);
        m
          ..sharesLocation = true
          ..at = pos.at
          ..speedKmh = pos.speedKmh
          ..heading = pos.heading
          ..sport = sportFromKey(pos.sport)
          ..lastPing = age
          // Lebih dari 2 menit tanpa denyut = sinyal hilang, walau server belum
          // menandai offline (mis. app dibunuh saat mode pesawat).
          ..state = (!pos.online || age > const Duration(minutes: 2))
              ? MemberState.offline
              : (pos.state == 'paused' ? MemberState.paused : MemberState.moving);
      }

      final st = r.stats[cm.uid];
      m
        ..monthKm = st?.km ?? (cm.uid == myUid ? monthKm : 0)
        ..monthCount = st?.count ?? (cm.uid == myUid ? monthActivities.length : 0);
    }
    _recomputePack();
    notifyListeners();
  }

  void _recomputePack() {
    final pos = <String, LatLng>{};
    final head = <String, double>{};
    for (final m in members) {
      final at = m.isMe ? (myPos ?? m.at) : m.at;
      if (at == null || m.state == MemberState.offline) continue;
      pos[m.uid] = at;
      if (m.state == MemberState.moving && m.speedKmh > 1) head[m.uid] = m.heading;
    }
    _pack = computePack(pos, head);
    for (final m in members) {
      m.gapM = _pack.offsets[m.uid] ?? 0;
    }
  }

  /// Rentang rombongan (km) — jarak sepanjang arah gerak, bukan garis lurus.
  double get spreadKm => _pack.spreadKm;

  Member? get leader => _byUid(_pack.frontUid);
  Member? get trailer => _byUid(_pack.backUid);

  Member? _byUid(String? uid) =>
      uid == null ? null : _roster[uid];

  /// Selisih meter anggota ini terhadap aku (+ = di depan).
  double gapFromMe(Member m) => m.gapM - me.gapM;

  List<Member> get needWatch => members
      .where((m) => !m.isMe && m.sharesLocation && m.state != MemberState.moving)
      .toList();

  int countByState(MemberState s) =>
      members.where((m) => m.sharesLocation && m.state == s).length;

  // ── Statistik pribadi ───────────────────────────────────────────────────

  List<Activity> get monthActivities {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month);
    return activities.where((a) => !a.startedAt.isBefore(start)).toList()
      ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
  }

  double get monthKm => monthActivities.fold(0.0, (s, a) => s + a.km);
  int get monthSec => monthActivities.fold(0, (s, a) => s + a.movingSec);
  double get lifetimeKm => activities.fold(0.0, (s, a) => s + a.km);

  /// 4 bar "JARAK PER MINGGU".
  List<double> get weeklyKm {
    final out = List<double>.filled(4, 0);
    for (final a in monthActivities) {
      out[min(3, (a.startedAt.day - 1) ~/ 7)] += a.km;
    }
    return out;
  }

  Map<Sport, double> get kmBySport {
    final out = {for (final s in Sport.values) s: 0.0};
    for (final a in activities) {
      out[a.sport] = out[a.sport]! + a.km;
    }
    return out;
  }

  Activity? get fastest5k {
    final c = activities.where((a) => a.distanceM >= 5000).toList()
      ..sort((a, b) => a.avgPaceSecPerKm.compareTo(b.avgPaceSecPerKm));
    return c.isEmpty ? null : c.first;
  }

  Activity? get longest => activities.isEmpty
      ? null
      : activities.reduce((a, b) => a.distanceM >= b.distanceM ? a : b);

  double get bestElev => activities.fold(0.0, (s, a) => max(s, a.elevGainM));

  /// Kirim agregat bulanan ke grup — angka saja, tanpa titik GPS, dan hanya
  /// kalau pengguna mengizinkannya di layar 19.
  Future<void> _pushStats() async {
    final g = activeGroup;
    if (g == null || !online || g.localOnly) return;
    try {
      if (shareTotals) {
        await cloud!.putStats(g.code,
            km: monthKm, count: monthActivities.length, sec: monthSec);
      } else {
        await cloud!.clearStats(g.code);
      }
    } catch (e) {
      debugPrint('state: gagal kirim agregat ($e)');
    }
  }

  /// Dipanggil layar Privasi setelah toggle berbagi diubah.
  Future<void> applySharing() async {
    await _pushStats();
    gps
      ..shareStatus = shareStatus
      ..shareSpeed = shareSpeed;
    final g = activeGroup;
    if (session != null && g != null) {
      // Berhenti/mulai kirim posisi sesuai izin terbaru, tanpa memutus rekaman.
      await gps.start(code: g.code, share: shareLiveLocation);
    } else if (!shareLiveLocation && g != null && online && !g.localOnly) {
      try {
        await cloud!.clearLive(g.code);
      } catch (_) {
        // Tidak apa: node live akan kedaluwarsa sendiri di sisi anggota lain.
      }
    }
  }

  // ── Rekam ───────────────────────────────────────────────────────────────

  /// Mulai merekam. Mengembalikan hasil izin GPS supaya UI bisa menjelaskan
  /// kalau ditolak.
  Future<GpsResult> startSession(Sport sport, {bool shareStatusToGroup = true}) async {
    session?.dispose();
    session = RecordSession(sport)..addListener(_onSessionTick);
    lastSport = sport;
    gps
      ..sport = sport.name
      ..state = 'moving'
      ..shareStatus = shareStatus
      ..shareSpeed = shareSpeed;
    final g = activeGroup;
    final res = await gps.start(
        code: g?.code,
        share: shareLiveLocation && shareStatusToGroup && g != null && !g.localOnly);
    if (res == GpsResult.ditolak ||
        res == GpsResult.ditolakPermanen ||
        res == GpsResult.layananMati) {
      session?.dispose();
      session = null;
    }
    notice = Gps.pesan(res);
    me
      ..sport = sport
      ..state = MemberState.moving;
    _persist();
    notifyListeners();
    return res;
  }

  void _onFix(LatLng at, double speedKmh, double? altitude) {
    myPos = at;
    me
      ..at = at
      ..speedKmh = speedKmh
      ..lastPing = Duration.zero
      ..sharesLocation = gps.sharingCode != null;
    final s = session;
    if (s != null) {
      s.onFix(at, speedKmh, altitude);
      // Titipkan sesi ke simpanan tiap 10 detik. Jauh lebih jarang dari fix
      // (blob-nya ditulis ulang utuh), tapi cukup rapat: paling banyak 10 detik
      // rekaman yang hilang kalau sistem membunuh app.
      final now = DateTime.now();
      if (_sessionSavedAt == null ||
          now.difference(_sessionSavedAt!) > const Duration(seconds: 10)) {
        _sessionSavedAt = now;
        _persist();
      }
    }
    _recomputePack();
    notifyListeners();
  }

  DateTime? _sessionSavedAt;

  void _onSessionTick() {
    final s = session;
    if (s == null) return;
    gps.state = s.paused ? 'paused' : 'moving';
    me.state = s.paused ? MemberState.paused : MemberState.moving;
    notifyListeners();
  }

  /// Selesai & simpan. Null kalau jaraknya nol (tidak ada yang layak disimpan).
  Future<Activity?> finishSession() async {
    final s = session;
    if (s == null) return null;
    final a = s.toActivity();
    await gps.stop();
    _closeSession();
    if (a.distanceM < 10) {
      notice = 'Rekaman terlalu pendek — tidak disimpan.';
      notifyListeners();
      return null;
    }
    activities.insert(0, a);
    await _persistNow();
    await _pushStats();
    notifyListeners();
    return a;
  }

  Future<void> discardSession() async {
    await gps.stop();
    _closeSession();
    await _persistNow();
    notifyListeners();
  }

  void _closeSession() {
    session?.removeListener(_onSessionTick);
    session?.dispose();
    session = null;
    _sessionSavedAt = null;
    me
      ..state = MemberState.moving
      ..speedKmh = 0;
    // Wajib: tanpa ini sesi yang sudah selesai tetap ada di simpanan dan
    // dipulihkan lagi saat app dibuka berikutnya.
    _persist();
  }

  void deleteActivity(Activity a) {
    activities.remove(a);
    _persistNow();
    _pushStats();
    notifyListeners();
  }

  void wipeAll() {
    activities.clear();
    _persistNow();
    _pushStats();
    notifyListeners();
  }

  String consumeNotice() {
    final n = notice ?? '';
    notice = null;
    return n;
  }

  String _norm(String code) {
    final c = code.toUpperCase().replaceAll(RegExp('[^A-Z0-9]'), '');
    return c.startsWith('KLR') ? 'KLR-${c.substring(3)}' : 'KLR-$c';
  }

  String _short(Object e) {
    final s = e.toString().replaceFirst('Exception: ', '');
    return s.length > 60 ? '${s.substring(0, 60)}…' : s;
  }

  /// Data contoh untuk pratinjau desain & test — bukan dipakai app sungguhan.
  void _seedDemo() {
    myName = 'Ari Ramdani';
    myCity = 'TANGERANG';
    joinedAt = DateTime(2026, 3, 1);
    final demoGroup = Group(
        code: 'KLR-4821', name: 'Keluarr Pagi', sport: Sport.run, adminUid: 'me')
      ..localOnly = true;
    groups.add(demoGroup);
    activeGroupCode = demoGroup.code;
    final route = [
      for (var i = 0; i < 60; i++)
        LatLng(-6.1783 + i * 0.0004, 106.6319 + sin(i / 9) * 0.0025),
    ];
    activities.addAll([
      Activity(
        id: 'a1',
        sport: Sport.run,
        title: 'Lari pagi Cigemuk',
        startedAt: DateTime.now().subtract(const Duration(days: 1, hours: 8)),
        distanceM: 6080,
        movingSec: 2162,
        elapsedSec: 2260,
        splits: const [
          KmSplit(1, 364),
          KmSplit(2, 347),
          KmSplit(3, 372),
          KmSplit(4, 338),
          KmSplit(5, 341),
          KmSplit(6, 352),
        ],
        track: route,
        secs: [for (var i = 0; i < 60; i++) i * 36],
      ),
      Activity(
        id: 'a2',
        sport: Sport.bike,
        title: 'Sepeda ke Legok',
        startedAt: DateTime.now().subtract(const Duration(days: 3)),
        distanceM: 24600,
        movingSec: 4080,
        elevGainM: 168,
        track: route,
      ),
      Activity(
        id: 'a3',
        sport: Sport.hike,
        title: 'Hiking Gn. Batu',
        startedAt: DateTime.now().subtract(const Duration(days: 5)),
        distanceM: 8400,
        movingSec: 12120,
        elevGainM: 742,
        track: route,
      ),
    ]);
    _roster[myUid] = Member(
        uid: myUid, name: myName, role: 'admin', isMe: true, monthKm: monthKm);
  }

  @override
  void dispose() {
    _rosterSub?.cancel();
    session?.dispose();
    gps.stop();
    super.dispose();
  }
}

/// Sesi perekaman: jam + [Track] dari fix GPS nyata.
///
/// Timer 1 detik hanya untuk jam berjalan dan auto-pause; jarak & jejak datang
/// dari GPS lewat [onFix]. Kalau tak ada fix sama sekali (emulator tanpa GPS),
/// jaraknya nol — itu jujur, bukan angka palsu.
class RecordSession extends ChangeNotifier {
  RecordSession(
    this.sport, {
    Track? track,
    DateTime? startedAt,
    this.elapsedSec = 0,
    this.pausedSec = 0,
    List<(int, double)>? laps,
  })  : track = track ?? Track(),
        startedAt = startedAt ?? DateTime.now(),
        laps = laps ?? [] {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  final Sport sport;
  final DateTime startedAt;
  final Track track;

  Timer? _timer;
  int elapsedSec = 0;
  int pausedSec = 0;
  bool paused = false;

  /// Auto-pause: kalau tidak ada fix bergerak selama ini, dijeda sendiri
  /// (rule desain 07: kecepatan < 1 km/j lebih dari 20 detik).
  static const _idleLimit = Duration(seconds: 20);
  DateTime _lastMoveAt = DateTime.now();
  bool _autoPaused = false;

  double get distanceM => track.km * 1000;
  double get km => track.km;
  int get movingSec => track.moving.inSeconds;
  double get speedKmh => paused ? 0 : track.lastKmh;
  double get avgSpeedKmh => track.avgKmh;
  double get elevGainM => track.elevGainM;
  int get paceSecPerKm => distanceM < 50 ? 0 : (movingSec / km).floor();
  int get calories => (sport.kcalPerKm * km * kBodyWeightKg).round();
  double get splitProgress => km - km.floorToDouble();
  List<KmSplit> get splits =>
      [for (final s in track.splits) KmSplit(s.$1, s.$2)];
  List<LatLng> get points => track.points;

  /// True kalau jeda ini dipicu sendiri oleh app, bukan oleh tombol.
  bool get autoPaused => _autoPaused;

  void onFix(LatLng at, double speedKmh, double? altitude) {
    if (paused) {
      // Bergerak lagi setelah auto-pause → lanjut sendiri, seperti Strava.
      if (_autoPaused && speedKmh >= Track.autoPauseKmh) {
        paused = false;
        _autoPaused = false;
        _lastMoveAt = DateTime.now();
        notifyListeners();
      } else {
        return;
      }
    }
    final moving = track.add(at, speedKmh, DateTime.now(), altitude: altitude);
    if (moving) _lastMoveAt = DateTime.now();
    notifyListeners();
  }

  void _tick() {
    elapsedSec++;
    if (paused) {
      pausedSec++;
    } else if (DateTime.now().difference(_lastMoveAt) > _idleLimit &&
        track.points.isNotEmpty) {
      paused = true;
      _autoPaused = true;
    }
    notifyListeners();
  }

  void togglePause() {
    paused = !paused;
    _autoPaused = false;
    if (!paused) _lastMoveAt = DateTime.now();
    notifyListeners();
  }

  /// Lap manual: detik-bergerak dan km saat tombol ditekan. Terpisah dari
  /// [splits] yang dihitung per km — lap itu penanda pengguna, bukan jarak.
  final List<(int sec, double km)> laps;

  void lap() {
    laps.add((movingSec, km));
    notifyListeners();
  }

  Activity toActivity() => Activity(
        id: 's${startedAt.millisecondsSinceEpoch}',
        sport: sport,
        title: '${sport.label} ${_partOfDay(startedAt)}',
        startedAt: startedAt,
        distanceM: distanceM,
        movingSec: movingSec,
        elapsedSec: elapsedSec,
        elevGainM: elevGainM,
        topKmh: track.topKmh,
        splits: splits,
        track: List.of(track.points),
        secs: List.of(track.secs),
      );

  /// Potret sesi yang sedang berjalan, supaya rekaman selamat kalau sistem
  /// membunuh app di tengah lari.
  Map<String, dynamic> toJson() => {
        'sport': sport.name,
        'start': startedAt.toIso8601String(),
        'elapsed': elapsedSec,
        'paused': pausedSec,
        'laps': [
          for (final l in laps) [l.$1, l.$2],
        ],
        'track': track.toJson(),
      };

  /// Sesi yang dipulihkan selalu mulai dalam keadaan **dijeda**: waktu selama
  /// app mati bukan waktu bergerak, dan melanjutkan harus keputusan sadar.
  static RecordSession fromJson(Map<String, dynamic> j) => RecordSession(
        sportFromKey(j['sport'] as String?),
        track: Track.fromJson(
            ((j['track'] as Map?) ?? const {}).cast<String, dynamic>()),
        startedAt: DateTime.parse(j['start'] as String),
        elapsedSec: (j['elapsed'] as num?)?.toInt() ?? 0,
        pausedSec: (j['paused'] as num?)?.toInt() ?? 0,
        laps: [
          for (final l in (j['laps'] as List? ?? []))
            ((l as List)[0] as int, (l[1] as num).toDouble()),
        ],
      )..paused = true;

  static String _partOfDay(DateTime t) => t.hour < 10
      ? 'pagi'
      : t.hour < 15
          ? 'siang'
          : t.hour < 18
              ? 'sore'
              : 'malam';

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState super.notifier, required super.child});

  static AppState of(BuildContext c) =>
      c.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;
}

// ── Format angka gaya Indonesia (koma desimal) ──────────────────────────────

String num1(double v) => v.toStringAsFixed(1).replaceAll('.', ',');

String num2(double v) => v.toStringAsFixed(2).replaceAll('.', ',');

/// Jarak: <10 km pakai 2 desimal, sisanya 1 (seperti mockup: 6,08 / 24,6).
String fmtKm(double km) => km < 10 ? num2(km) : num1(km);

/// mm:ss, atau h:mm:ss kalau ≥ 1 jam.
String fmtClock(int sec) {
  final h = sec ~/ 3600, m = (sec % 3600) ~/ 60, s = sec % 60;
  final mm = m.toString().padLeft(2, '0'), ss = s.toString().padLeft(2, '0');
  return h > 0 ? '$h:$mm:$ss' : '$mm:$ss';
}

/// "9j 14m" untuk total panjang.
String fmtSpan(int sec) {
  final h = sec ~/ 3600, m = (sec % 3600) ~/ 60;
  return h > 0 ? '${h}j ${m.toString().padLeft(2, '0')}m' : '${m}m';
}

/// Pace m:ss (tanpa nol depan, seperti mockup: 5:55).
String fmtPace(int secPerKm) => secPerKm <= 0
    ? '--:--'
    : '${secPerKm ~/ 60}:${(secPerKm % 60).toString().padLeft(2, '0')}';

const _months = [
  'JAN', 'FEB', 'MAR', 'APR', 'MEI', 'JUN',
  'JUL', 'AGU', 'SEP', 'OKT', 'NOV', 'DES'
];
const _days = ['SENIN', 'SELASA', 'RABU', 'KAMIS', 'JUMAT', 'SABTU', 'MINGGU'];

String fmtDate(DateTime d) => '${d.day} ${_months[d.month - 1]}';

String fmtDateYear(DateTime d) => '${fmtDate(d)} ${d.year}';

String fmtTime(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}.${d.minute.toString().padLeft(2, '0')}';

String fmtLongDate(DateTime d) => '${_days[d.weekday - 1]}, ${fmtDateYear(d)}';

String fmtMonthYear(DateTime d) => '${_months[d.month - 1]} ${d.year}';

String fmtAgo(Duration d) {
  if (d.inSeconds < 5) return 'baru saja';
  if (d.inMinutes < 1) return '${d.inSeconds} dtk lalu';
  if (d.inHours < 1) return '${d.inMinutes} mnt lalu';
  return '${d.inHours} jam lalu';
}

String fmtGap(double meters) => meters.abs() >= 1000
    ? '${num1(meters.abs() / 1000)} km'
    : '${meters.abs().round()} m';

/// Ringkasan metrik ketiga di kartu riwayat, sesuai jenis olahraga.
String thirdMetric(Activity a) => switch (a.sport) {
      Sport.run || Sport.walk => '${fmtPace(a.avgPaceSecPerKm)}/km',
      Sport.bike => '${num1(a.avgSpeedKmh)} km/j',
      Sport.hike => '+${a.elevGainM.round()} m',
    };
