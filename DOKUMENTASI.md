---
title: "Keluarr — Dokumentasi App"
tags:
  - flutter
  - dart
  - firebase
  - gps
  - dokumentasi
  - keluarr
platform: "Android"
versi: "1.0.0+1"
sdk: "Dart ^3.10.4"
repo: "d:/FLUTTER/Keluarr"
commit_terakhir: "355fc2e"
---

# Keluarr — Dokumentasi Lengkap

> **Keluarr** = rekam jejak GPS pribadi + berbagi lokasi live ke grup.
> Flutter · Android · Firebase Realtime Database · Peta OpenStreetMap.

## Aturan tetap app ini

> [!important] Jejak GPS TIDAK PERNAH keluar dari HP
> Yang naik ke server hanya: meta grup, daftar anggota, **satu titik lokasi terkini**, status, dan angka agregat bulanan.
> Ditegakkan **dua lapis**:
> 1. Tidak ada satu pun method di `lib/data/cloud.dart` yang bisa mengirim jejak.
> 2. Security Rules Firebase menolak node asing — termasuk percobaan menulis `track/`.
>
> Satu-satunya jalan keluar jejak: **ekspor GPX** atau **kartu gambar**, dan itu selalu atas perintah pengguna.

---

# BAGIAN 1 — ALUR CARA GUNAKAN APP

## 1.1 Alur boot (dari app dibuka)

```
runApp(KeluarrApp)
  │
  ├─ AppState.boot()
  │    1. cloud.init()            → Firebase + sign-in anonim (tidak pernah melempar)
  │    2. store.load()            → baca 1 blob JSON dari SharedPreferences
  │    3. _restore(saved)         → pulihkan nama, preferensi, grup, aktivitas
  │    4. _followGroup()          → langganan roster grup aktif (kalau ada)
  │    5. _resumeCrashed()        → pulihkan rekaman yang tertinggal
  │
  ├─ _Splash  ("KL" + tulisan MENYIAPKAN) selama boot berjalan
  │
  └─ Root (router)
```

## 1.2 Alur pertama kali pakai

```
Root
 │
 ├─ nama belum diisi (nameSet == false)
 │      └─→ [00] WelcomeScreen — "Halo! Siapa nama kamu?"
 │              · NAMA (wajib)
 │              · KOTA · OPSIONAL (otomatis jadi HURUF BESAR)
 │              · badge "DISIMPAN DI HP INI SAJA"
 │              · tombol "Lanjut" → setIdentity()
 │
 ├─ belum punya grup & belum skip
 │      └─→ [01] OnboardingScreen — "Mulai dengan grup kamu"
 │              ├─ Buat grup baru      → CreateGroupScreen
 │              ├─ Gabung pakai kode   → JoinGroupScreen
 │              └─ Lanjut tanpa grup   → skipGroup()  (mode solo)
 │
 └─ sudah siap
        └─→ HomeShell (bottom nav 5 tab)
```

Kode router — [main.dart:115](lib/main.dart#L115):

```dart
/// START · belum punya nama ? → sambutan (00) · ada grup aktif ? ya → PETA ·
/// tidak → onboarding (01)
class Root extends StatelessWidget {
  const Root({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    // Nama ditanya sekali di awal, terlepas dari jalur grup mana yang dipilih.
    if (!app.nameSet) return const WelcomeScreen();
    if (app.activeGroup == null && !app.skippedGroup) return const OnboardingScreen();
    return const HomeShell();
  }
}
```

## 1.3 Navigasi utama — 5 tab

| # | Tab | Layar | Isi |
|---|-----|-------|-----|
| 0 | **PETA** | `MapScreen` | Peta OSM, marker anggota live, tombol follow / fit-grup / rekam |
| 1 | **TIM** | `TeamScreen` | Daftar anggota, filter SEMUA/BERGERAK/JEDA/OFF, jarak relatif |
| 2 | **REKAM** | *(bukan halaman)* | Membuka sheet pilih olahraga → hitung mundur → layar rekam |
| 3 | **GRUP** | `GroupScreen` | Kode undangan, ganti grup aktif, pengaturan, grup buatan sendiri |
| 4 | **REKAP** | `RecapScreen` | Tab SAYA / GRUP, bar mingguan, daftar aktivitas bulan ini |

Tab 2 sengaja bukan halaman — [main.dart:139](lib/main.dart#L139):

```dart
void _onTab(int i) {
  if (i == 2) {
    startRecordFlow(context); // REKAM = sheet 06, bukan halaman tab
    return;
  }
  setState(() => _tab = i);
}
```

Body-nya `IndexedStack` — state tiap tab (posisi peta, scroll) tidak hilang saat pindah tab:

```dart
body: SafeArea(
  bottom: false,
  child: IndexedStack(
    index: _tab,
    children: [
      MapScreen(onStartRecord: () => startRecordFlow(context)),
      const TeamScreen(),
      const SizedBox.shrink(),   // slot REKAM, tidak pernah tampil
      const GroupScreen(),
      const RecapScreen(),
    ],
  ),
),
```

## 1.4 Alur merekam aktivitas

```
Tekan REKAM (tab tengah)
  │
  ├─ [06] _SportSheet  — bottom sheet
  │        Lari         · PACE · SPLIT KM · KALORI
  │        Hiking       · ELEVASI · DURASI · KALORI
  │        Sepeda       · KECEPATAN · ELEVASI · KALORI
  │        Jalan kaki   · JARAK · DURASI · KALORI
  │        → tombol "Mulai · <olahraga>"
  │
  ├─ [07] _Countdown — 3 · 2 · 1 · "SIAP-SIAP"
  │        (izin GPS diminta di sini; kalau ditolak, sesi dibatalkan
  │         dan pesan alasannya ditampilkan lewat `notice`)
  │
  ├─ [08] RecordingScreen
  │        · jam berjalan (elapsed)
  │        · jarak · pace atau kecepatan · elevasi · kalori
  │        · progres split km berjalan
  │        · tombol: JEDA / LANJUT · LAP · SELESAI
  │        · AUTO-PAUSE: diam <1 km/j selama 20 detik → dijeda sendiri
  │          lanjut sendiri begitu bergerak lagi (seperti Strava)
  │        · Android: notifikasi "Merekam rute" (foreground service)
  │        · sesi ditulis ke simpanan tiap 10 detik
  │
  ├─ SELESAI → finishSession()
  │        · jarak < 10 m → TIDAK disimpan ("Rekaman terlalu pendek")
  │        · selain itu → Activity masuk ke riwayat + agregat dikirim
  │
  └─ [09] SummaryScreen → bisa lanjut ke ShareScreen / ekspor GPX
```

## 1.5 Alur grup

```
BUAT GRUP  (CreateGroupScreen)
  input: nama grup · olahraga · target km per bulan
  → Cloud.newCode()          → "KLR-XXXX" (4 karakter acak aman)
  → meta ditulis dulu (adminUid = uid-ku)
  → baru members/{uid} role=admin
  → Firebase mati? grup tetap dibuat, ditandai localOnly = true

GABUNG     (JoinGroupScreen)
  ketik kode → previewCode()  → tampilkan nama grup DULU sebelum benar gabung
             → joinGroup()    → tulis members/{uid}, lalu baca meta
             → kode salah?    → baris keanggotaan yang baru ditulis dibersihkan
             → uid ada di banned/ → "Kamu dicekal dari grup ini"

ADMIN
  · ubah nama / olahraga / target      (putMeta)
  · keluarkan anggota + cekal          (removeMember ban:true)
  · hapus grup                         (deleteGroup)

KELUAR
  · anggota biasa       → members/{uid} dihapus
  · pembuat grup keluar → kode tetap tersimpan di createdGroups (leftAt diisi)
                          adminUid di server TIDAK berubah
                          → masuk lagi dengan kode yang sama = admin lagi
```

## 1.6 Alur privasi

Layar `PrivacyScreen`. Jejak GPS **tidak punya sakelar** — memang tidak bisa dibagikan.

| Sakelar | Field | Default | Efek |
|---|---|---|---|
| Lokasi live | `shareLiveLocation` | ON | Titik dikirim ke `live/{uid}` |
| Status | `shareStatus` | ON | Status moving/paused ikut dikirim |
| Kecepatan | `shareSpeed` | **OFF** | Kalau OFF, terkirim sebagai `0` |
| Total km | `shareTotals` | ON | Agregat bulanan masuk leaderboard grup |
| Jejak GPS | — | **terkunci** | Tidak ada setter, tidak ada method upload |

Perubahan langsung berlaku tanpa memutus rekaman — [state.dart:1067](lib/state.dart#L1067):

```dart
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
```

---

# BAGIAN 2 — FUNGSI & FITUR (BESERTA KODE)

## 2.1 Arsitektur

```
main.dart          → runApp, lifecycle, router, bottom nav
   │
   ├── state.dart  → AppState (satu ChangeNotifier) + AppScope (InheritedNotifier)
   │                  RecordSession, Activity, Member, Group, Body, Sport
   │                  semua fungsi format angka/tanggal
   │
   ├── data/       → lapisan murni tanpa Flutter UI
   │     cloud.dart     Firebase (satu-satunya tempat yang tahu Firebase)
   │     location.dart  GPS: izin, stream, filter, foreground service
   │     track.dart     jarak, elevasi, waktu bergerak, split, kompresi titik
   │     polyline.dart  encode/decode jejak
   │     store.dart     SharedPreferences, 1 blob JSON, debounce
   │     pack.dart      posisi relatif rombongan
   │     gpx.dart       ekspor GPX 1.1
   │
   ├── theme.dart  → token desain (kelas K) + buildTheme + extension Tone
   ├── widgets.dart→ 19 komponen pakai-ulang
   └── screens/    → 20 layar
```

> [!note] Tanpa paket state-management pihak ketiga
> Satu `ChangeNotifier` + `InheritedNotifier` bawaan Flutter sudah cukup. Tidak ada Provider/Riverpod/Bloc.

## 2.2 Satu pintu perubahan state

[state.dart:628](lib/state.dart#L628) — mencegah bug paling gampang lolos di app seperti ini: perubahan yang lupa disimpan.

```dart
/// Ubah state + simpan + beri tahu UI. Satu pintu supaya tidak ada perubahan
/// yang lupa dipersistensi — bug paling gampang lolos di app seperti ini.
void set(void Function() change) {
  change();
  _persist();
  notifyListeners();
}
```

## 2.3 Perekaman — `RecordSession`

[state.dart:1293](lib/state.dart#L1293). Timer 1 detik **hanya** untuk jam berjalan dan auto-pause. Jarak & jejak datang dari GPS lewat `onFix`. Kalau tak ada fix sama sekali (emulator tanpa GPS), jaraknya nol — itu jujur, bukan angka palsu.

```dart
class RecordSession extends ChangeNotifier {
  /// Auto-pause: kalau tidak ada fix bergerak selama ini, dijeda sendiri.
  static const _idleLimit = Duration(seconds: 20);
  DateTime _lastMoveAt = DateTime.now();
  bool _autoPaused = false;

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

  /// Lap manual: detik-bergerak dan km saat tombol ditekan. Terpisah dari
  /// [splits] yang dihitung per km — lap itu penanda pengguna, bukan jarak.
  final List<(int sec, double km)> laps;

  void lap() {
    laps.add((movingSec, km));
    notifyListeners();
  }
}
```

## 2.4 Filter GPS — buang fix ngawur

[location.dart:163](lib/data/location.dart#L163). Satu tempat, supaya jejak, kiriman ke grup, dan marker peta sama-sama bersih.

```dart
/// Akurasi terburuk yang masih dipercaya. Di atas ini fix biasanya hasil
/// triangulasi menara/WiFi dan letaknya meleset puluhan meter — itulah yang
/// terlihat sebagai titik meloncat.
static const _maxAccuracy = 30.0;

/// 40 m/s ≈ 144 km/h. Di atas itu bukan orang berlari, tapi fix melenceng.
static const _maxSpeedMps = 40.0;

/// Kalau sinyal jelek berkepanjangan, fix buruk tetap diterima setelah jeda
/// ini — lebih baik posisi kasar daripada peta yang membeku.
static const _staleAfter = Duration(seconds: 30);

@visibleForTesting
static bool plausible(Position? prev, Position pos) {
  if (prev == null) return true;
  final secs = pos.timestamp.difference(prev.timestamp).inMilliseconds / 1000;
  if (secs <= 0) return false;
  if (secs > _staleAfter.inSeconds) return true;
  if (pos.accuracy.isFinite && pos.accuracy > _maxAccuracy) return false;
  final meters = Geolocator.distanceBetween(
      prev.latitude, prev.longitude, pos.latitude, pos.longitude);
  return meters / secs <= _maxSpeedMps;
}
```

## 2.5 Kecepatan — jangan percaya `pos.speed` buta

[location.dart:186](lib/data/location.dart#L186). Kalau angka 0 dari fused provider dipercaya apa adanya, auto-pause menyala lalu **tidak pernah lepas** — jarak dan jejak berhenti untuk sisa sesi.

```dart
@visibleForTesting
static double speedKmh(Position? prev, Position pos) {
  if (pos.speed.isFinite && pos.speed > 0) return pos.speed * 3.6;
  if (prev == null) return 0;
  final secs = pos.timestamp.difference(prev.timestamp).inMilliseconds / 1000;
  if (secs <= 0) return 0;
  final meters = Geolocator.distanceBetween(
      prev.latitude, prev.longitude, pos.latitude, pos.longitude);
  return meters / secs * 3.6;
}
```

## 2.6 Foreground service Android

[location.dart:47](lib/data/location.dart#L47). Tanpa ini jejak berhenti persis saat HP masuk kantong — kondisi normal sepanjang lari.

```dart
@visibleForTesting
static LocationSettings settings() {
  if (defaultTargetPlatform != TargetPlatform.android) {
    return const LocationSettings(accuracy: LocationAccuracy.best, distanceFilter: 5);
  }
  return AndroidSettings(
    accuracy: LocationAccuracy.best,
    distanceFilter: 5,   // dikerjakan OS → hemat baterai
    foregroundNotificationConfig: const ForegroundNotificationConfig(
      notificationTitle: 'Merekam rute',
      notificationText: 'Jejak GPS dicatat walau layar mati · tersimpan pribadi',
      notificationChannelName: 'Rekam rute',
      // Wake lock menjaga fix datang satu per satu. Tanpa itu Android
      // menahannya lalu mengirim menumpuk saat layar dinyalakan, dan jejak
      // di antaranya jadi garis lurus.
      enableWakeLock: true,
      setOngoing: true,
    ),
  );
}
```

## 2.7 Throttle kiriman + heartbeat

Fix masuk tiap beberapa detik, tapi tidak semuanya perlu dikirim ke server:

```dart
void _onFix(Position pos) {
  if (!plausible(_lastGood, pos)) return;
  ...
  // Jejak dicatat lebih dulu dan tanpa syarat: itu milik pengguna sendiri.
  onFix?.call(at, kmh, pos.altitude);

  if (_code == null) return;
  final now = DateTime.now();
  if (_lastSentAt != null && now.difference(_lastSentAt!) < _minInterval) return;
  if (_lastSent != null &&
      dist.as(LengthUnit.Meter, _lastSent!, at) < _minMeters) return;
  _lastSent = at; _lastSentAt = now;
  _push(at, kmh);
}

/// Kirim ulang posisi terakhir supaya anggota lain tahu aku masih hidup.
/// Kecepatan 0 — bukan lewat _onFix, supaya titik yang sama tidak dicatat
/// ulang ke jejak.
void _repeat() {
  final at = _lastSent;
  if (at == null) return;
  _push(at, 0);
}
```

Heartbeat tiap 45 detik: yang berhenti tidak menghasilkan fix baru, jadi posisinya dianggap kedaluwarsa. Denyut ini menjaganya terlihat hidup tanpa harus bergerak.

## 2.8 Jejak & jarak — `Track`

[track.dart](lib/data/track.dart). Konstanta-konstanta penting:

```dart
// roundResult:false WAJIB. Default Distance() membulatkan hasil ke satuan
// bulat, jadi as(Kilometer) pada segmen 40 m mengembalikan 0 — dan fix GPS
// datang tiap beberapa detik, sehingga total jaraknya jadi 0 km.
const dist = Distance(roundResult: false);

/// 25 m — 6 km lari ≈ 240 titik ≈ 5 KB.
static const _minMeters = 25.0;

/// Jeda antar-fix lebih lama dari ini bukan waktu bergerak.
static const _maxGap = Duration(minutes: 2);

static const autoPauseKmh = 1.0;
```

Inti `add()`:

```dart
bool add(LatLng at, double speedKmh, DateTime now, {double? altitude}) {
  startedAt ??= now;
  updatedAt = now;
  if (speedKmh.isFinite && speedKmh >= 0) {
    lastKmh = speedKmh;
    topKmh = math.max(topKmh, speedKmh);
  }

  if (altitude != null && altitude.isFinite) {
    final prevAlt = _lastAlt;
    // Ambang 2 m menyaring derau altimeter; tanpa itu jalan datar pun
    // menumpuk elevasi ratusan meter.
    if (prevAlt != null && altitude - prevAlt > 2) _elevGain += altitude - prevAlt;
    if (prevAlt == null || (altitude - prevAlt).abs() > 2) _lastAlt = altitude;
  }

  final prevAt = _lastFixAt;
  _lastFixAt = now;
  if (prevAt != null) {
    final gap = now.difference(prevAt);
    if (gap > Duration.zero && gap <= _maxGap) _secsMoving += gap.inMilliseconds / 1000;
  }

  final prev = _lastFix;
  if (prev == null) {
    _lastFix = at;
    if (points.isEmpty) _push(at, now);
    return speedKmh >= autoPauseKmh;
  }

  final meters = dist.as(LengthUnit.Meter, prev, at);
  // Lompatan liar dari GPS yang baru fix — jangan dihitung sebagai jarak.
  if (meters > 2000) return false;

  _km += meters / 1000;
  _lastFix = at;
  if (points.isEmpty || dist.as(LengthUnit.Meter, points.last, at) >= _minMeters) {
    _push(at, now);
  }
  return speedKmh >= autoPauseKmh;
}
```

Waktu bergerak — sengaja **bukan** `updatedAt - startedAt`:

```dart
/// Lama bergerak: jumlah jeda antar-fix, tanpa jeda yang lebih panjang dari
/// [_maxGap]. Sengaja BUKAN `updatedAt - startedAt`.
Duration get moving => Duration(seconds: _secsMoving.round());
```

Split per km diturunkan dari waktu nyata, bukan interpolasi jarak:

```dart
List<(int km, int paceSec)> get splits {
  if (points.length < 2) return const [];
  final out = <(int, int)>[];
  var acc = 0.0, prevSec = 0, nextKm = 1;
  for (var i = 1; i < points.length; i++) {
    acc += dist.as(LengthUnit.Meter, points[i - 1], points[i]) / 1000;
    if (acc >= nextKm) {
      final sec = i < secs.length ? secs[i] : prevSec;
      out.add((nextKm, sec - prevSec));
      prevSec = sec;
      nextKm++;
    }
  }
  return out;
}
```

## 2.9 Estimasi kalori (dengan suku elevasi)

[state.dart:115](lib/state.dart#L115). Suku elevasi berasal dari fisika, bukan tebakan: energi potensial m·g·h joule, dibagi efisiensi otot ~25% dan 4184 J/kkal → `kg · m · 9,81 / (0,25 · 4184)` ≈ `kg · m · 0,0094` kkal.

```dart
int estimateKcal(Sport sport, double km, double elevGainM, {double? weightKg}) {
  final kg = weightKg ?? Body.weightKg;
  final datar = sport.kcalPerKm * km * kg;
  final naik = elevGainM <= 0 ? 0.0 : kg * elevGainM * 0.0094;
  return (datar + naik).round();
}
```

Tanpa suku ini, hiking 8 km dengan tanjakan 700 m dihitung nyaris sama dengan jalan kaki 8 km di jalan datar.

| Olahraga | `kcalPerKm` | Metrik yang ditampilkan |
|---|---:|---|
| Lari | 1.03 | PACE · SPLIT KM · KALORI |
| Hiking | 0.90 | ELEVASI · DURASI · KALORI |
| Sepeda | 0.35 | KECEPATAN · ELEVASI · KALORI |
| Jalan kaki | 0.55 | JARAK · DURASI · KALORI |

> [!warning] Kenapa tidak ada "LANGKAH"
> `SportInfo.metrics` sengaja tidak menyebut langkah — tanpa pedometer, itu hanya angka karangan.

## 2.10 Data tubuh & BMI — `Body`

[state.dart:67](lib/state.dart#L67). Nilai tingkat-modul, bukan diteruskan sebagai parameter ke mana-mana: satu pemasangan app = satu pemakai, dan kartu share sengaja tidak punya akses ke `AppState`.

```dart
class Body {
  static const defaultWeightKg = 70.0;

  /// Batas wajar, sekaligus penjaga dari ketikan salah (misal 700 kg) yang
  /// akan membuat angka kalori ngawur di seluruh riwayat.
  static const minWeightKg = 25.0;
  static const maxWeightKg = 250.0;
  static const minHeightCm = 90.0;
  static const maxHeightCm = 230.0;

  static double weightKg = defaultWeightKg;

  /// Null berarti belum diisi — BMI tidak ditampilkan, bukan ditebak.
  static double? heightCm;

  static double? get bmi {
    final h = heightCm;
    if (h == null || h <= 0) return null;
    final m = h / 100;
    return weightKg / (m * m);
  }

  /// Kategori BMI menurut ambang WHO.
  static String? get bmiLabel {
    final v = bmi;
    if (v == null) return null;
    if (v < 18.5) return 'KURANG';
    if (v < 25) return 'NORMAL';
    if (v < 30) return 'BERLEBIH';
    return 'OBESITAS';
  }
}
```

## 2.11 Rekor 5K yang benar-benar pernah terjadi

[state.dart:1016](lib/state.dart#L1016). Dulu ini `pace rata-rata × 5` dari aktivitas mana pun ≥5 km — angka yang tidak pernah sungguh dicatat.

```dart
/// Jendela 5 km tercepat di satu aktivitas, null kalau jejaknya tidak cukup.
static int? best5kOf(Activity a) {
  final pts = a.track;
  final secs = a.secs;
  if (pts.length < 2 || secs.length != pts.length) return null;

  // Jarak kumulatif tiap titik, supaya jendela bisa digeser tanpa menghitung
  // ulang jarak dari awal setiap kali.
  final cum = List<double>.filled(pts.length, 0);
  for (var i = 1; i < pts.length; i++) {
    cum[i] = cum[i - 1] + dist.as(LengthUnit.Meter, pts[i - 1], pts[i]);
  }
  if (cum.last < 5000) return null;

  int? best;
  var j = 0;
  for (var i = 0; i < pts.length; i++) {
    if (j < i) j = i;
    while (j < pts.length - 1 && cum[j] - cum[i] < 5000) j++;
    if (cum[j] - cum[i] < 5000) break;
    final t = secs[j] - secs[i];
    if (t > 0 && (best == null || t < best)) best = t;
  }
  return best;
}
```

## 2.12 Bar mingguan yang bisa dibandingkan

[state.dart:960](lib/state.dart#L960). Dulu tanggal 29–31 dipaksa masuk batang ke-4, jadi batang itu mewakili 10 hari sementara sisanya 7 — tingginya tidak bisa dibandingkan.

```dart
List<double> get weeklyKm {
  final now = DateTime.now();
  final hari = DateTime(now.year, now.month + 1, 0).day;  // hari dalam bulan ini
  final out = List<double>.filled((hari / 7).ceil(), 0);
  for (final a in monthActivities) {
    out[(a.startedAt.day - 1) ~/ 7] += a.km;
  }
  return out;
}

List<String> get weeklyLabels =>
    [for (var i = 0; i < weeklyKm.length; i++) 'M${i + 1}'];
```

## 2.13 Riwayat per bulan

[state.dart:986](lib/state.dart#L986). Supaya rekaman bulan lalu tidak ikut hilang tiap ganti bulan.

```dart
List<(DateTime month, List<Activity> items)> get activitiesByMonth {
  final buckets = <DateTime, List<Activity>>{};
  for (final a in activities) {
    buckets.putIfAbsent(DateTime(a.startedAt.year, a.startedAt.month), () => []).add(a);
  }
  final keys = buckets.keys.toList()..sort((a, b) => b.compareTo(a));
  return [
    for (final k in keys)
      (k, buckets[k]!..sort((a, b) => b.startedAt.compareTo(a.startedAt))),
  ];
}
```

## 2.14 Rombongan — `computePack`

[pack.dart:41](lib/data/pack.dart#L41). Tanpa rute rencana, "depan" tidak bisa diambil dari kemajuan sepanjang rute seperti app touring. Yang dipakai: semua posisi diproyeksikan ke **arah gerak rata-rata rombongan**. Proyeksi terbesar = paling depan.

```dart
// Sumbu arah: rata-rata vektor heading (dijumlah sebagai vektor supaya 350°
// dan 10° tidak jadi 180°).
var ax = 0.0, ay = 0.0;
for (final h in headings.values) {
  final r = h * math.pi / 180;
  ax += math.sin(r);
  ay += math.cos(r);
}
if (ax.abs() < 1e-9 && ay.abs() < 1e-9) {
  // Semua berhenti: pakai sumbu sebaran terpanjang.
  var bestD = -1.0;
  for (final a in xy.values) {
    for (final b in xy.values) {
      final dx = b.$1 - a.$1, dy = b.$2 - a.$2;
      final d = dx * dx + dy * dy;
      if (d > bestD) { bestD = d; ax = dx; ay = dy; }
    }
  }
}
...
final proj = {for (final e in xy.entries) e.key: e.value.$1 * ax + e.value.$2 * ay};
final min = proj.values.reduce(math.min);
final max = proj.values.reduce(math.max);
return Pack(
  offsets: {for (final e in proj.entries) e.key: e.value - min},
  spreadM: max - min,
);
```

Hasilnya dipakai di `AppState`: `spreadKm`, `leader`, `trailer`, `gapFromMe(m)`.

Konversi lat/lng → meter pakai equirectangular (galat < 0,1% untuk rombongan sepanjang puluhan km):

```dart
const mPerDegLat = 111320.0;
final mPerDegLng = mPerDegLat * math.cos(lat0 * math.pi / 180);
```

## 2.15 Deteksi anggota hilang / tertinggal

Dua lapis. **Lapis server** — `onDisconnect` dititipkan sebelum kiriman pertama:

```dart
/// Titipkan ke server: begitu koneksiku putus, tandai aku offline. Server
/// yang mengeksekusi, jadi tetap jalan walau app mati mendadak.
Future<void> markOfflineOnDisconnect(String code) =>
    _need(code).child('live/$_uid/online').onDisconnect().set(false);
```

**Lapis klien** — umur ping, untuk kasus yang server pun tidak tahu (mode pesawat):

```dart
..state = (!pos.online || age > const Duration(minutes: 2))
    ? MemberState.offline
    : (pos.state == 'paused' ? MemberState.paused : MemberState.moving);
```

## 2.16 Penyimpanan lokal — `Store`

[store.dart](lib/data/store.dart). Satu key, blob JSON, debounce 1 detik supaya perekaman per-detik tidak menulis 3.600 kali per jam.

```dart
const _key = 'keluarr_state_v1';

class Store {
  Future<Map<String, dynamic>?> load() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      final raw = _prefs!.getString(_key);
      if (raw == null) return null;
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (e) {
      // Data rusak atau dari versi lama: mulai bersih daripada gagal buka app.
      debugPrint('store: gagal baca simpanan, mulai baru ($e)');
      return null;
    }
  }

  /// Simpan. Pemanggilan berulang dalam satu detik digabung jadi satu tulisan.
  void save(Map<String, dynamic> state) {
    _pending = state;
    _writing ??= Future<void>.delayed(const Duration(seconds: 1), _flush);
  }

  /// Tulis sekarang — dipakai sebelum app ditutup atau setelah aktivitas
  /// disimpan, supaya rekaman yang baru selesai tidak hilang kalau app dibunuh.
  Future<void> flushNow(Map<String, dynamic> state) async {
    _pending = state;
    await _flush();
  }
}
```

## 2.17 Rekaman selamat dari app yang dibunuh

Tiga mekanisme bersama:

**(a) Simpan tiap 10 detik saat merekam** — [state.dart:1127](lib/state.dart#L1127):

```dart
// Titipkan sesi ke simpanan tiap 10 detik. Jauh lebih jarang dari fix
// (blob-nya ditulis ulang utuh), tapi cukup rapat: paling banyak 10 detik
// rekaman yang hilang kalau sistem membunuh app.
final now = DateTime.now();
if (_sessionSavedAt == null ||
    now.difference(_sessionSavedAt!) > const Duration(seconds: 10)) {
  _sessionSavedAt = now;
  _persist();
}
```

**(b) Tulis segera saat app masuk latar** — [main.dart:44](lib/main.dart#L44):

```dart
/// Simpan segera begitu app masuk latar. [dispose] tidak bisa diandalkan:
/// sistem membunuh proses tanpa memanggilnya, dan itu justru yang terjadi
/// saat HP dikantongi selama merekam.
@override
void didChangeAppLifecycleState(AppLifecycleState state) {
  if (state == AppLifecycleState.paused ||
      state == AppLifecycleState.detached ||
      state == AppLifecycleState.hidden) {
    widget.app.flush();
  }
}
```

**(c) Pulihkan saat boot** — [state.dart:533](lib/state.dart#L533):

```dart
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
```

Sesi yang dipulihkan **selalu mulai dalam keadaan dijeda**:

```dart
/// Sesi yang dipulihkan selalu mulai dalam keadaan **dijeda**: waktu selama
/// app mati bukan waktu bergerak, dan melanjutkan harus keputusan sadar.
static RecordSession fromJson(Map<String, dynamic> j) => RecordSession(...)..paused = true;
```

## 2.18 Firebase — `Cloud`

[cloud.dart](lib/data/cloud.dart). Satu-satunya tempat yang tahu tentang Firebase. **Tidak pernah melempar saat init** — kegagalan hanya membuat `ready` tetap false.

```dart
Future<void> init() async {
  try {
    if (_options == null) throw StateError('Firebase belum dikonfigurasi.');
    if (Firebase.apps.isEmpty) await Firebase.initializeApp(options: _options);
    final cred = await FirebaseAuth.instance.signInAnonymously();
    _uid = cred.user?.uid;
    if (_uid == null) throw StateError('Firebase tidak memberi uid.');

    final db = FirebaseDatabase.instance;
    // Cache lokal: grup yang sudah dibuka tetap terbaca saat sinyal hilang.
    db.setPersistenceEnabled(true);
    _root = db.ref(rootPath);
    _error = null;
  } catch (e) {
    _root = null; _uid = null;
    _error = _readable(e);
    debugPrint('cloud: mode lokal ($e)');
  }
}
```

Pesan error diterjemahkan jadi bahasa manusia:

| Penyebab | Pesan |
|---|---|
| options null / config | "Firebase belum dikonfigurasi — grup hanya di HP ini." |
| `operation-not-allowed` | "Anonymous sign-in belum diaktifkan di konsol Firebase." |
| network / unavailable | "Tidak ada koneksi ke server." |
| lainnya | "Gagal menyambung ke server." |

### Kode undangan

```dart
/// Kode undangan yang diketik anggota: 8 karakter, huruf/angka yang tidak
/// gampang tertukar (tanpa I, O, 0, 1). Sekaligus kunci node grup, jadi kode
/// itu memang rahasianya.
static String newCode() {
  const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  final rnd = math.Random.secure();
  return 'KLR-${List.generate(4, (_) => alphabet[rnd.nextInt(alphabet.length)]).join()}';
}
```

Normalisasi input di sisi `AppState` — pengguna boleh ketik apa saja:

```dart
String _norm(String code) {
  final c = code.toUpperCase().replaceAll(RegExp('[^A-Z0-9]'), '');
  return c.startsWith('KLR') ? 'KLR-${c.substring(3)}' : 'KLR-$c';
}
```

### Urutan penulisan saat buat grup — WAJIB

```dart
Future<void> createGroup({...}) async {
  final ref = _need(code);
  await ref.child('meta').set({
    'name': name, 'sport': sport, 'targetKm': targetKm,
    'adminUid': _uid, 'createdMs': DateTime.now().millisecondsSinceEpoch,
  });
  // Baris admin WAJIB ada di members/{auth.uid}: aturan `.read` memeriksa
  // tepat kunci itu, jadi tanpa ini pembuatnya sendiri tidak bisa membaca.
  await putMember(code, name: myName, role: 'admin');
}
```

### Gabung: tulis diri dulu, baru baca

```dart
Future<CloudGroup?> join(String code, String myName) async {
  await putMember(code, name: myName);
  final g = await fetchGroup(code);
  if (g == null) {
    // Kode salah: bersihkan baris yang baru ditulis supaya tidak
    // meninggalkan anggota nyangkut di node kosong.
    await _need(code).child('members/$_uid').remove();
  } else if (g.adminUid == _uid) {
    // Admin lama masuk lagi pakai kodenya sendiri: baris keanggotaan yang
    // baru ditulis default 'member', padahal adminUid masih menunjuk dia.
    await putMember(code, name: myName, role: 'admin');
  }
  return g;
}
```

### Keluarkan anggota harus ikut cekal

```dart
/// [ban] mencekalnya supaya tidak bisa mendaftar ulang dengan kode yang masih
/// dia pegang — tanpa itu, mengeluarkan tidak berlaku.
Future<void> removeMember(String code, String memberUid, {bool ban = false}) async {
  final ref = _need(code);
  await ref.child('members/$memberUid').remove();
  // Posisinya juga dihapus; kalau tidak markernya menggantung di peta
  // anggota lain sampai ada yang menimpanya.
  await ref.child('live/$memberUid').remove();
  await ref.child('stats/$memberUid').remove();
  if (ban) await ref.child('banned/$memberUid').set(true);
}
```

### Tiga node diawasi terpisah, bukan satu node induk

```dart
/// Anggota + lokasi live + agregat, satu stream. Tiga node diawasi terpisah
/// lalu digabung: mengawasi `keluarr/$code` utuh berarti tiap kiriman posisi
/// mengirim ulang seluruh daftar anggota dan statistik ke semua orang.
Stream<CloudRoster> watchRoster(String code) => _combine3(
  ref.child('members').onValue,
  ref.child('live').onValue,
  ref.child('stats').onValue,
  (members, live, stats) { ... },
);
```

`_combine3` menunggu ketiganya pernah datang dulu — tanpa itu, roster setengah jadi (anggota ada, posisi belum) sempat terlihat dan markernya berkedip.

## 2.19 Grup yang pernah dibuat sendiri

[state.dart:345](lib/state.dart#L345). Kode grup buatanmu tidak hilang begitu saja walau kamu keluar.

```dart
class CreatedGroupRef {
  final String code;
  String name;
  Sport sport;
  final DateTime createdAt;

  /// Null berarti masih jadi anggota (belum pernah keluar sejak dibuat).
  DateTime? leftAt;
}
```

Saat keluar — [state.dart:757](lib/state.dart#L757):

```dart
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
```

Masuk lagi:

```dart
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
```

## 2.20 Warna marker stabil antar-HP

[state.dart:269](lib/state.dart#L269). Sengaja **bukan** `uid.hashCode`: nilainya tidak dijamin sama antar versi Dart SDK.

```dart
Color get color {
  if (isMe) return K.orange;
  const palette = [K.success, K.blue, K.warning, Color(0xFF8B5CF6), Color(0xFF0EA5A4)];
  return palette[_stableHash(uid) % palette.length];
}

static int _stableHash(String s) {   // FNV-1a
  var h = 0x811c9dc5;
  for (final unit in s.codeUnits) {
    h = ((h ^ unit) * 0x01000193) & 0x7fffffff;
  }
  return h;
}
```

## 2.21 Polyline

[polyline.dart](lib/data/polyline.dart). Google polyline presisi `1e5`. Rute 40 km ≈ 500 titik ≈ 10 KB. Melempar `FormatException` kalau data terpotong — tidak diam-diam menghasilkan rute salah.

```dart
String encodePolyline(List<LatLng> points, {double precision = 1e5});
List<LatLng> decodePolyline(String encoded, {double precision = 1e5});
```

## 2.22 Ekspor GPX

[gpx.dart](lib/data/gpx.dart). GPX 1.1, dengan timestamp per titik.

```dart
String toGpx({
  required String title,
  required DateTime startedAt,
  required List<LatLng> points,
  List<int> secs = const [],
}) { ... }

String _esc(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');
```

## 2.23 Kartu share PNG

[share.dart](lib/screens/share.dart) + `SharePreset` di state.

```dart
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
```

Bentuk jejak digambar tanpa peta (thumbnail & kartu), lewat `normalize()` ke ruang 0..1:

```dart
/// Jejak dalam ruang 0..1 untuk digambar tanpa peta (thumbnail & kartu share).
List<Offset> get shape => normalize(track);
```

## 2.24 Tema & token desain

[theme.dart](lib/theme.dart). Diambil dari spec `KELUARR.dc.html`.

```dart
class K {
  static const orange = Color(0xFFFF6A13);      // warna utama
  static const success = Color(0xFF17A867);
  static const warning = Color(0xFFE8A317);
  static const danger  = Color(0xFFD14343);
  static const blue    = Color(0xFF3C6DF0);

  static const bgL = Color(0xFFF4F2ED);   static const bgD = Color(0xFF0F1113);
  static const cardL = Color(0xFFFFFFFF); static const cardD = Color(0xFF1B1F23);
  static const lineL = Color(0xFFE0DBD1); static const lineD = Color(0xFF2A3035);

  // padding halaman 18 · gap antar kartu 13 · radius kartu 16 · tombol 54
  static const pad = 18.0;
  static const gap = 13.0;
  static const r = 16.0;
  static const btnH = 54.0;
}
```

Font mono tidak dibundel — pakai fallback sistem:

```dart
/// Archivo / JetBrains Mono tidak dibundel — pakai sans sistem + monospace sistem.
const _monoFallback = ['JetBrains Mono', 'Consolas', 'monospace', 'Courier New'];
```

Warna turunan lewat extension, dipakai di semua layar:

```dart
extension Tone on BuildContext {
  ColorScheme get cs => Theme.of(this).colorScheme;
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
  Color get card => isDark ? K.cardD : K.cardL;
  Color get line => isDark ? K.lineD : K.lineL;
  Color get dim  => isDark ? K.dimD : K.dimL;
  Color get fg   => isDark ? K.inkD : K.ink;
  Color get fill => isDark ? const Color(0xFF15181B) : K.bgL;
}
```

## 2.24b Logo & ikon app

Satu berkas sumber: `assets/logo.png` (1200×1200, RGBA dengan latar **transparan**).

Dipakai di tiga tempat:

| Tempat | Berkas | Cara |
|---|---|---|
| Ikon peluncur | `android/app/src/main/res/mipmap-*/ic_launcher.png` | Dihasilkan `flutter_launcher_icons` (48 · 72 · 96 · 144 · 192 px) |
| Adaptive icon (Android 8+) | `mipmap-anydpi-v26/ic_launcher.xml` + `drawable-*/ic_launcher_foreground.png` | Latar `#FFFFFF`, foreground logo, inset 16% |
| Splash native | `drawable/launch_background.xml` + `drawable-v21/…` | `layer-list`: warna latar + bitmap logo di tengah |
| Splash Flutter | `_Splash` di `lib/main.dart` | `Image.asset('assets/logo.png', width: 96, height: 96)` |

```dart
// Logo app. Latar putihnya sudah bagian dari berkas, jadi tidak
// perlu kotak berwarna di belakangnya lagi.
Image.asset('assets/logo.png',
    width: 96, height: 96, filterQuality: FilterQuality.medium),
```

> [!note] Kenapa latar transparan penting
> `launch_background.xml` ada dua versi: `drawable/` pakai putih, `drawable-v21/` pakai `?android:colorBackground` (ikut tema sistem). Karena logonya transparan, **satu berkas PNG** benar di tema terang maupun gelap — tidak perlu dua aset.

> [!tip] Regenerasi ikon
> Ganti `assets/logo.png`, lalu:
> ```bash
> flutter pub run flutter_launcher_icons
> ```
> Konfigurasinya ada di blok `flutter_launcher_icons:` paling bawah `pubspec.yaml`.

## 2.25 Peta

- Tile **OpenStreetMap**, tanpa API key.
- Tema gelap dibuat dengan **membalik warna tile** (`_darkTiles` di `widgets.dart`).
- Atribusi "© OpenStreetMap" **wajib** tetap terlihat — syarat pemakaian tile mereka.
- Titik awal kalau GPS belum fix: Tangerang.

```dart
/// Titik awal peta kalau GPS belum memberi fix (Tangerang, sesuai mockup).
const kFallbackCenter = LatLng(-6.1783, 106.6319);
```

## 2.26 Format angka gaya Indonesia

[state.dart:1450](lib/state.dart#L1450) — koma desimal, singkatan Indonesia.

```dart
String num1(double v) => v.toStringAsFixed(1).replaceAll('.', ',');
String num2(double v) => v.toStringAsFixed(2).replaceAll('.', ',');

/// Jarak: <10 km pakai 2 desimal, sisanya 1 (6,08 / 24,6).
String fmtKm(double km) => km < 10 ? num2(km) : num1(km);

/// mm:ss, atau h:mm:ss kalau ≥ 1 jam.
String fmtClock(int sec);

/// "9j 14m" untuk total panjang.
String fmtSpan(int sec);

/// Pace m:ss tanpa nol depan (5:55); "--:--" kalau belum ada.
String fmtPace(int secPerKm);

String fmtDate(DateTime d);       // "3 AGU"
String fmtDateYear(DateTime d);   // "3 AGU 2026"
String fmtTime(DateTime d);       // "06.14"
String fmtLongDate(DateTime d);   // "SENIN, 3 AGU 2026"
String fmtMonthYear(DateTime d);  // "AGU 2026"
String fmtAgo(Duration d);        // "baru saja" / "12 dtk lalu" / "3 mnt lalu"
String fmtGap(double meters);     // "180 m" / "1,8 km"

/// Metrik ketiga di kartu riwayat, menyesuaikan olahraga.
String thirdMetric(Activity a) => switch (a.sport) {
  Sport.run || Sport.walk => '${fmtPace(a.avgPaceSecPerKm)}/km',
  Sport.bike => '${num1(a.avgSpeedKmh)} km/j',
  Sport.hike => '+${a.elevGainM.round()} m',
};
```

## 2.27 Mode lokal (tanpa Firebase)

App **jalan penuh** tanpa Firebase. Yang tidak jalan hanya grup & lokasi live.

| Fitur | Tanpa Firebase |
|---|---|
| Rekam GPS | ✅ jalan |
| Simpan aktivitas | ✅ jalan |
| Riwayat & rekap | ✅ jalan |
| Kartu share | ✅ jalan |
| Ekspor GPX | ✅ jalan |
| Buat grup | ⚠️ jadi `localOnly` (hanya di HP ini) |
| Gabung grup | ❌ "Butuh koneksi untuk gabung grup." |
| Lokasi live | ❌ |
| Leaderboard | ❌ |

```dart
Future<void> createGroup(String name, Sport sport, {double targetKm = 500}) async {
  ...
  } else {
    g.localOnly = true;
    notice = cloudError ?? 'Server tidak terjangkau — grup hanya di HP ini.';
  }
}
```

---

# BAGIAN 3 — LANGKAH PEMBANGUNAN APP DARI AWAL

## Tahap 1 — Fondasi (commit `9f59905`, "Initial commit")

1. **Scaffold** — `flutter create keluarr`, paket `com.keluarr.keluarr`.
2. **Tetapkan aturan tetap** sebelum menulis kode: *jejak GPS lokal saja*. Ini yang membentuk seluruh arsitektur setelahnya — `Cloud` sengaja dibuat tanpa method upload jejak, dan Rules dibuat menolak node asing.
3. **Pasang dependensi** (lihat tabel 4.5). Pilihan sadar: `flutter_map` + OSM supaya **tanpa API key**; tanpa paket state-management.
4. **Bangun lapisan data lebih dulu**, urutan dari yang paling tidak bergantung:
   `polyline.dart` → `track.dart` → `store.dart` → `pack.dart` → `gpx.dart` → `location.dart` → `cloud.dart`
5. **Bangun `state.dart`** — `AppState` sebagai satu `ChangeNotifier`, `AppScope` sebagai `InheritedNotifier`, dengan satu pintu `set()`.
6. **Bangun `theme.dart`** (token `K` dari spec HTML) dan **`widgets.dart`** (19 komponen pakai-ulang) — supaya 20 layar tidak menduplikasi gaya.
7. **Bangun 20 layar** di `screens/`.
8. **Setup Firebase**:
   - `firebase apps:create android` → daftar app Android
   - unduh `android/app/google-services.json`
   - isi `lib/firebase_options.dart` (apiKey/appId/senderId)
   - tulis `database.rules.json` lalu deploy ke region `asia-southeast1`
9. **Uji Rules end-to-end** dengan **dua akun anonim sungguhan** terhadap database live — 18 pemeriksaan: buat grup → gabung → kirim posisi → tolak `track/` → tolak posisi orang lain → tolak ubah `meta` oleh non-admin → tolak hapus grup oleh non-admin → admin keluarkan + cekal + hapus grup. Skrip PowerShell-nya ada di `SETUP.md`.
10. **Tulis tes** — `keluarr_test.dart` + `smoke_test.dart` (render semua layar, menangkap overflow).

## Tahap 2 — Tahan banting (commit `bd0b2e3`)

> "Add session persistence, GPS filter & created-groups" — **+784 / −44**, 12 berkas.

Masalah nyata yang ditemukan saat dipakai:

| Masalah | Perbaikan |
|---|---|
| Android membunuh proses saat layar mati & HP di kantong → rekaman hilang | Simpan sesi tiap 10 detik + `flush()` di `didChangeAppLifecycleState` + `_resumeCrashed()` di boot |
| Titik GPS meloncat mengacaukan jarak & marker | `Gps.plausible()` — akurasi >30 m dan >144 km/j dibuang |
| Kode grup buatan sendiri hilang setelah keluar | `CreatedGroupRef` + `createdGroups` + `rejoinCreatedGroup()` |
| Sesi yang sudah selesai dipulihkan lagi saat buka app | `_persist()` di `_closeSession()` |

Berkas berubah: `cloud.dart`, `location.dart`, `main.dart`, `group.dart`, `map_screen.dart`, `onboarding.dart`, `profile.dart`, `record.dart`, `state.dart`, `widgets.dart` + tes baru `gps_filter_test.dart`.

## Tahap 3 — Identitas & perbaikan logika (commit `355fc2e`, HEAD)

> "menambahkan input nama di awal dan perbaikan logika" — **+1080 / −98**, 14 berkas.

**Fitur baru:**

- `WelcomeScreen` — nama ditanya **sebelum** jalur grup. Sebelumnya orang yang memilih "Lanjut tanpa grup" tidak pernah ditanya nama, profilnya selamanya "Saya".
- Penanda `nameSet` dengan migrasi mulus untuk pemakai lama:
  ```dart
  // Pemakai lama yang namanya sudah terisi lewat alur grup tidak perlu
  // ditanya ulang hanya karena penanda ini baru ada.
  nameSet = j['nameSet'] as bool? ?? (myName.isNotEmpty && myName != 'Saya');
  ```
- Data tubuh (`Body`): berat + tinggi → BMI berlabel WHO, kalori jadi personal.

**Perbaikan logika:**

| Sebelum | Sesudah |
|---|---|
| Batang minggu ke-4 mewakili 10 hari | Sisa hari dapat batangnya sendiri (`weeklyKm`) |
| "5K tercepat" = pace rata-rata × 5 (tak pernah terjadi) | Jendela geser 5 km nyata (`best5kOf`) |
| Riwayat bulan lalu hilang tiap ganti bulan | `activitiesByMonth` |
| `pos.speed = 0` dipercaya → auto-pause nyangkut selamanya | `Gps.speedKmh` turunkan dari jarak/waktu |
| Nama grup basi di daftar "pernah dibuat" | `saveGroupSettings` ikut menyamakan `createdGroups` |
| `kmBySport` tanpa filter tahun, label Profil bohong | `kmBySport({int? year})` |

Tes baru: `map_follower_test.dart`; `keluarr_test.dart` diperluas jadi 230 baris lebih.

---

# BAGIAN 4 — DAFTAR SEMUA BERKAS & YANG DIPAKAI

## 4.1 Struktur direktori

```
d:\FLUTTER\Keluarr\
├── assets\
│   └── logo.png
├── lib\
│   ├── main.dart
│   ├── state.dart
│   ├── theme.dart
│   ├── widgets.dart
│   ├── firebase_config.dart
│   ├── firebase_options.dart
│   ├── data\
│   │   ├── cloud.dart
│   │   ├── gpx.dart
│   │   ├── location.dart
│   │   ├── pack.dart
│   │   ├── polyline.dart
│   │   ├── store.dart
│   │   └── track.dart
│   └── screens\
│       ├── group.dart
│       ├── map_screen.dart
│       ├── onboarding.dart
│       ├── profile.dart
│       ├── recap.dart
│       ├── record.dart
│       ├── share.dart
│       └── team.dart
├── test\
│   ├── gps_filter_test.dart
│   ├── keluarr_test.dart
│   ├── map_follower_test.dart
│   └── smoke_test.dart
├── android\
│   ├── app\google-services.json
│   ├── app\build.gradle.kts
│   ├── app\src\main\AndroidManifest.xml
│   └── ...
├── database.rules.json
├── firebase.json
├── pubspec.yaml
├── analysis_options.yaml
├── SETUP.md
├── README.md
└── DOKUMENTASI.md      ← berkas ini
```

## 4.2 Berkas inti

| Berkas | Baris | Isi utama |
|---|---:|---|
| [main.dart](lib/main.dart) | 177 | `main()`, `KeluarrApp`, `_KeluarrAppState` (lifecycle), `_Splash`, `Root` (router), `HomeShell`, `_HomeShellState` |
| [state.dart](lib/state.dart) | 1509 | `AppState`, `RecordSession`, `AppScope`, `Activity`, `Member`, `Group`, `CreatedGroupRef`, `Body`, `KmSplit`, `SharePreset`, enum `Sport`/`MemberState`/`CardStyle`/`CardRatio`/`CardTemplate`, `estimateKcal()`, semua fungsi format |
| [theme.dart](lib/theme.dart) | 115 | `K` (token), `mono()`, `buildTheme()`, `extension Tone on BuildContext` |
| [widgets.dart](lib/widgets.dart) | 1050 | 19 komponen (tabel 4.4) |
| [firebase_config.dart](lib/firebase_config.dart) | 20 | `defaultOptions` |
| [firebase_options.dart](lib/firebase_options.dart) | 67 | Hasil FlutterFire (Android saja) |

## 4.3 Lapisan data

| Berkas | Baris | Kelas / fungsi publik |
|---|---:|---|
| [cloud.dart](lib/data/cloud.dart) | 407 | `Cloud`, `CloudGroup`, `CloudMember`, `CloudStat`, `CloudRoster`, `LivePos` |
| [location.dart](lib/data/location.dart) | 252 | `Gps`, `GpsResult`, `Gps.plausible()`, `Gps.speedKmh()`, `Gps.settings()`, `Gps.pesan()` |
| [track.dart](lib/data/track.dart) | 193 | `Track`, `normalize()`, `dist` |
| [polyline.dart](lib/data/polyline.dart) | 70 | `encodePolyline()`, `decodePolyline()` |
| [store.dart](lib/data/store.dart) | 60 | `Store` |
| [pack.dart](lib/data/pack.dart) | 102 | `Pack`, `computePack()` |
| [gpx.dart](lib/data/gpx.dart) | 39 | `toGpx()` |

### Method `Cloud` lengkap

| Method | Guna |
|---|---|
| `init()` | Firebase + sign-in anonim, tidak pernah melempar |
| `newCode()` | Kode undangan `KLR-XXXX` (static) |
| `createGroup()` | Tulis `meta` lalu `members/{uid}` role admin |
| `putMember()` | Tulis/perbarui baris keanggotaan |
| `join()` | Gabung + koreksi role admin + bersihkan kalau kode salah |
| `fetchGroup()` | Baca `meta` (dipakai pratinjau kode) |
| `putMeta()` | Ubah nama/olahraga/target (admin saja) |
| `removeMember()` | Keluarkan + hapus live & stats + opsi cekal |
| `leave()` | `removeMember(uid-ku)` |
| `deleteGroup()` | Hapus seluruh node grup |
| `watchRoster()` | Stream gabungan members + live + stats |
| `putLive()` | Kirim posisiku (clamp kecepatan 0–200, heading 0–359) |
| `markOfflineOnDisconnect()` | Titip penanda offline ke server |
| `clearLive()` | Hapus posisiku + batalkan onDisconnect |
| `putStats()` / `clearStats()` | Agregat leaderboard (opt-in) |
| `isPermissionDenied()` | Deteksi penolakan Rules (static) |

## 4.4 Komponen `widgets.dart`

| Komponen | Guna |
|---|---|
| `Panel` | Kartu dasar (radius 16, border, warna tema) |
| `L` | Label kapital kecil bertracking |
| `Mono` | Teks monospace |
| `StatTile` | Angka besar + label + unit, auto-shrink |
| `BigBtn` | Tombol utama tinggi 54, ada `Semantics` |
| `Pill` | Chip/filter yang bisa diklik |
| `Badge2` | Badge kecil berwarna |
| `Avatar` | Inisial dalam kotak berwarna |
| `SwitchRow` | Baris sakelar privasi/preferensi |
| `MenuRow` | Baris menu dengan panah |
| `Bars` | Diagram batang (jarak per minggu) |
| `SplitRow` | Satu baris split km |
| `Meter` | Progress bar target bulanan |
| `KNav` | Bottom nav 5 slot dengan tombol REKAM di tengah |
| `MapPin` | Marker anggota di peta |
| `LiveMap` | Pembungkus `FlutterMap` + tile OSM + tema gelap |
| `RouteThumb` | Thumbnail jejak tanpa peta |
| `PrivacyNote` | Catatan privasi berulang |
| `MapFollower` | Logika auto-follow kamera peta (ada tesnya) |

## 4.5 Layar (`lib/screens/`)

| Berkas | Baris | Kelas publik |
|---|---:|---|
| [onboarding.dart](lib/screens/onboarding.dart) | 803 | `WelcomeScreen`, `OnboardingScreen`, `CreateGroupScreen`, `JoinGroupScreen` |
| [map_screen.dart](lib/screens/map_screen.dart) | 494 | `MapScreen` |
| [team.dart](lib/screens/team.dart) | 223 | `TeamScreen` |
| [record.dart](lib/screens/record.dart) | 888 | `startRecordFlow()`, `RecordingScreen`, `SummaryScreen` (+ privat `_SportSheet`, `_Countdown`) |
| [group.dart](lib/screens/group.dart) | 710 | `GroupScreen`, `MyCreatedGroupsScreen` |
| [recap.dart](lib/screens/recap.dart) | 716 | `RecapScreen`, `ActivityCard`, `ActivityDetailScreen` |
| [profile.dart](lib/screens/profile.dart) | 718 | `ProfileScreen`, `HistoryScreen`, `PrivacyScreen` |
| [share.dart](lib/screens/share.dart) | 903 | `ShareScreen`, `PreviewScreen`, `ShareCard`, `PlainCardScreen` |

**Total: 20 layar/komponen layar publik.**

## 4.6 Dependensi (`pubspec.yaml`)

| Paket | Versi | Guna | Kenapa dipilih |
|---|---|---|---|
| `flutter_map` | ^8.3.1 | Peta | Tile OSM, **tanpa API key** |
| `latlong2` | ^0.10.1 | `LatLng`, `Distance` | Tipe koordinat + jarak haversine |
| `geolocator` | ^14.0.3 | GPS | Punya `ForegroundNotificationConfig` untuk Android |
| `firebase_core` | ^4.12.1 | Inisialisasi Firebase | |
| `firebase_auth` | ^6.5.6 | Sign-in anonim | Tanpa daftar/login — uid saja sudah cukup |
| `firebase_database` | ^12.4.6 | RTDB | Realtime + `onDisconnect` + cache offline |
| `shared_preferences` | ^2.5.5 | Simpanan lokal | Cukup untuk 1 blob JSON |
| `share_plus` | ^13.3.0 | Bagikan PNG | |
| `path_provider` | ^2.1.6 | Direktori file sementara | |
| `image_picker` | ^1.2.3 | Foto latar kartu | |
| `cupertino_icons` | ^1.0.8 | Ikon | |
| `flutter_lints` | ^6.0.0 | dev — lint | |
| `flutter_launcher_icons` | ^0.14.4 | dev — generator ikon | Satu PNG → semua kerapatan mipmap + adaptive icon |
| `flutter_test` | sdk | dev — tes | |

## 4.7 Izin Android (`AndroidManifest.xml`)

```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
<uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_LOCATION"/>
<uses-permission android:name="android.permission.WAKE_LOCK"/>
```

## 4.8 Skema Firebase RTDB

```
keluarr/
  {KLR-XXXX}/
    meta/
      name        String, ≤60 karakter
      sport       'run' | 'hike' | 'bike' | 'walk'
      targetKm    Number, 0..100000
      adminUid    String
      createdMs   Number
    members/
      {uid}/  name · role ('admin'|'member') · joinedMs
    live/
      {uid}/  lat · lng · s (kecepatan) · h (heading) · sport · st (state) · t (ms) · online
    stats/
      {uid}/  km · n (jumlah) · sec
    banned/
      {uid}/  true
    ⛔ track/  — DITOLAK Rules. Tidak ada method-nya di Cloud.
```

## 4.9 Apa disimpan di mana

| Data | Tempat | Alasan |
|---|---|---|
| Aktivitas, jejak GPS, split, catatan | `SharedPreferences` (1 blob JSON) | Pribadi. Tidak ada salinan di server. |
| Preferensi (tema, bahasa, satuan, izin berbagi) | sama | Ikut satu blob, satu pintu simpan. |
| Nama, kota, berat, tinggi | sama | Identitas lokal. |
| Sesi rekam berjalan | sama | Selamat dari app yang dibunuh sistem. |
| `createdGroups` | sama | Kode grup buatan sendiri tidak hilang. |
| Grup: nama, kode, olahraga, target, admin | RTDB `keluarr/{kode}/meta` | Harus sama di semua HP. |
| Anggota | `keluarr/{kode}/members/{uid}` | |
| Lokasi live + status + kecepatan + arah | `keluarr/{kode}/live/{uid}` | Satu-satunya lokasi yang dibagikan. |
| Agregat leaderboard | `keluarr/{kode}/stats/{uid}` | Angka saja, opt-in. |
| **Jejak GPS** | **tidak ada di server** | Tidak ada method-nya, dan Rules menolak. |

## 4.10 Security Rules — yang ditegakkan

Berkas: `database.rules.json` (97 baris), deploy ke `familyrich-2575e-default-rtdb` region `asia-southeast1`.

1. **Baca grup hanya untuk anggota**
   `".read": "auth != null && data.child('members').child(auth.uid).exists()"`
   Kode undangan = kunci node, jadi orang luar tidak bisa menebak jalan masuk; tapi membaca tetap butuh baris di `members/{uid}`.

2. **Hapus grup dibatasi `!newData.exists()`**
   ```json
   ".write": "auth != null && data.child('meta/adminUid').val() === auth.uid && !newData.exists()"
   ```
   > [!danger] Kenapa harus dibatasi
   > Kalau ditulis sebagai izin tulis umum, izin itu **menurun ke semua anaknya** — dan admin jadi bisa menimpa `live/{uid}` orang lain, artinya **memalsukan posisi anggota**.

3. **`live/{uid}` & `stats/{uid}` hanya bisa ditulis pemiliknya** → tidak ada cara memalsukan posisi orang lain.

4. **`meta/adminUid` boleh dipindah, tapi hanya ke diri sendiri atau anggota nyata**
   ```json
   ".validate": "newData.isString() && (newData.val() === auth.uid || root.child('keluarr').child($code).child('members').child(newData.val()).exists())"
   ```
   Cabang "diri sendiri" **wajib ada**: saat grup dibuat, `meta` ditulis sebelum `members/{uid}` — ayam dan telur. Tanpa syarat keanggotaan, satu salah tulis membuat grup **yatim**: `adminUid` menunjuk uid yang tidak ada, dan tidak seorang pun bisa mengubah atau menghapusnya lagi.

5. **Anggota yang dikeluarkan masuk `banned/`** supaya tidak bisa masuk lagi dengan kode yang masih dia pegang.

6. **Node yang tidak dikenal ditolak** (`"$other": { ".validate": false }`) — termasuk percobaan menulis jejak GPS.

## 4.11 Tes (`flutter test` — 60 tes)

| Berkas | Cakupan |
|---|---|
| `gps_filter_test.dart` | Saringan fix GPS (fix pertama, langkah wajar, akurasi buruk, loncatan jauh, fix basi) · kecepatan (pakai perangkat, turunkan dari jarak, tanpa prev, bagi nol) |
| `keluarr_test.dart` | Format angka · metrik aktivitas · bagi-nol · JSON bolak-balik · `Track` · lompatan liar · rombongan · polyline · GPX · rekap bulanan · kalori tanjakan · rentang berat/tinggi · BMI · rekor 5K · batang mingguan · warna stabil · identitas awal · riwayat per bulan · tanpa Firebase · sesi rekam · `CreatedGroupRef` · pulih dari crash |
| `map_follower_test.dart` | Logika auto-follow kamera peta |
| `smoke_test.dart` | Render semua layar (menangkap overflow) |

## 4.12 Konfigurasi & platform

| Berkas | Guna |
|---|---|
| `pubspec.yaml` | Dependensi & metadata (`publish_to: none`) |
| `analysis_options.yaml` | `flutter_lints ^6.0.0` |
| `database.rules.json` | Security Rules RTDB |
| `firebase.json` | Menunjuk ke `database.rules.json` |
| `android/app/google-services.json` | Kredensial Firebase Android |
| `android/app/build.gradle.kts` · `settings.gradle.kts` | Build Android |
| `android/app/src/main/AndroidManifest.xml` | Izin + konfigurasi app |
| `android/app/src/main/kotlin/com/keluarr/keluarr/MainActivity.kt` | Activity host Flutter |
| `SETUP.md` | Panduan setup + skrip uji Rules PowerShell |
| `README.md` | ⚠️ masih template bawaan Flutter |

---

# BAGIAN 5 — MEMORY: PERUBAHAN DARI AWAL SAMPAI SEKARANG

## 5.1 Riwayat commit

| Commit | Judul | Diff | Tanggal relatif |
|---|---|---|---|
| `9f59905` | Initial commit | fondasi lengkap: 6 berkas inti + 7 modul data + 8 berkas layar + Rules + Android | awal |
| `bd0b2e3` | Add session persistence, GPS filter & created-groups | +784 / −44 · 12 berkas | tahap 2 |
| `355fc2e` | menambahkan input nama di awal dan perbaikan logika | +1080 / −98 · 14 berkas | **HEAD** |

## 5.2 Keputusan desain & alasannya

> Bagian ini yang paling mudah hilang kalau tidak dicatat — kode menunjukkan *apa*, bukan *kenapa*.

| Keputusan | Alasan |
|---|---|
| Jejak GPS lokal saja | Privasi. Ditegakkan dua lapis: tidak ada method di `Cloud`, dan Rules menolak node asing. |
| Tanpa paket state-management | Satu `ChangeNotifier` + `InheritedNotifier` sudah cukup untuk app sebesar ini. |
| Satu pintu `set()` | Mencegah perubahan yang lupa dipersistensi. |
| `Distance(roundResult: false)` | Default membulatkan → segmen 40 m dibaca 0 km → total jarak jadi 0. |
| FNV-1a, bukan `hashCode`, untuk warna anggota | `hashCode` tidak dijamin sama antar versi Dart SDK → warna bergeser antar-HP. |
| Kompresi titik 25 m | 6 km lari ≈ 240 titik ≈ 5 KB, tanpa kehilangan ketelitian garis yang terlihat. |
| Ambang elevasi 2 m | Derau altimeter; tanpa itu jalan datar menumpuk ratusan meter. |
| Waktu bergerak dari jeda antar-fix (`_maxGap` 2 menit) | `selesai − mulai` menghitung waktu app mati sebagai waktu berlari. |
| Sesi dipulihkan dalam keadaan **dijeda** | Waktu selama app mati bukan waktu bergerak; melanjutkan harus keputusan sadar. |
| Rekaman menganggur >6 jam → diselesaikan, bukan dibuang | Data pengguna tidak boleh dibuang diam-diam. |
| Auto-pause 20 detik di bawah 1 km/j | Mengikuti perilaku Strava. |
| Alfabet kode tanpa `I O 0 1` | Kode diketik manual — jangan bikin tertukar. |
| `Random.secure()` untuk kode | Kode = kunci node grup, jadi harus tidak bisa ditebak. |
| Tiga node diawasi terpisah (`_combine3`) | Mengawasi node grup utuh berarti tiap kiriman posisi mengirim ulang seluruh daftar anggota ke semua orang. |
| `_combine3` tunggu ketiganya | Tanpa itu roster setengah jadi terlihat dan marker berkedip. |
| Heartbeat 45 detik | Yang berhenti tidak menghasilkan fix baru → posisinya dikira kedaluwarsa. |
| Keluarkan anggota harus ikut cekal | Tanpa `banned/`, dia bisa masuk lagi dengan kode yang masih dia pegang. |
| Nama grup default OFF di kartu share | Supaya grup tidak terekspos tanpa sengaja. |
| Metrik per olahraga tidak menyebut "LANGKAH" | Tanpa pedometer, itu hanya angka karangan. |
| `heightCm` null = BMI tidak ditampilkan | Lebih baik tidak menampilkan daripada menebak. |
| Batas berat 25–250 kg, tinggi 90–230 cm | Penjaga ketikan salah (700 kg) yang akan merusak kalori seluruh riwayat. |
| `Body` sebagai nilai tingkat-modul | Kartu share sengaja tidak punya akses ke `AppState`. |
| `Cloud.init()` tidak pernah melempar | App wajib tetap jalan tanpa Firebase. |
| Tema gelap peta = membalik warna tile | OSM tidak menyediakan tile gelap gratis. |
| Font mono pakai fallback sistem | Tidak membundel font → ukuran APK lebih kecil. |

## 5.3 Bug yang sudah diperbaiki

| # | Bug | Perbaikan | Commit |
|---|---|---|---|
| 1 | Rekaman hilang saat app dibunuh sistem | Simpan tiap 10 detik + `flush()` lifecycle + `_resumeCrashed()` | `bd0b2e3` |
| 2 | Titik GPS meloncat mengacaukan jarak | `Gps.plausible()` + batas lompatan 2000 m di `Track.add` | `bd0b2e3` |
| 3 | Kode grup buatan sendiri hilang setelah keluar | `createdGroups` + `rejoinCreatedGroup()` | `bd0b2e3` |
| 4 | Sesi yang sudah selesai dipulihkan lagi | `_persist()` di `_closeSession()` | `bd0b2e3` |
| 5 | Pemakai "Lanjut tanpa grup" tak pernah ditanya nama | `WelcomeScreen` + penanda `nameSet` | `355fc2e` |
| 6 | Auto-pause nyangkut selamanya di perangkat yang lapor `speed = 0` | `Gps.speedKmh` turunkan dari jarak/waktu | `355fc2e` |
| 7 | Batang minggu ke-4 mewakili 10 hari, tidak bisa dibandingkan | `weeklyKm` panjang dinamis | `355fc2e` |
| 8 | Rekor "5K" tidak pernah sungguh terjadi | `best5kOf()` jendela geser | `355fc2e` |
| 9 | Riwayat bulan lalu hilang tiap ganti bulan | `activitiesByMonth` | `355fc2e` |
| 10 | Nama grup basi di daftar "pernah dibuat" | `saveGroupSettings` menyamakan `createdGroups` | `355fc2e` |
| 11 | Label "per olahraga" di Profil menyebut tahun tapi datanya seumur hidup | `kmBySport({int? year})` | `355fc2e` |
| 12 | Marker anggota yang dikeluarkan menggantung di peta | `removeMember` ikut hapus `live/` & `stats/` | `9f59905` |
| 13 | Kode salah meninggalkan anggota nyangkut di node kosong | `join()` bersihkan `members/{uid}` kalau `meta` tidak ada | `9f59905` |
| 14 | Admin masuk lagi jadi role 'member' padahal `adminUid` masih dia | `join()` koreksi role | `9f59905` |
| 15 | Total jarak selalu 0 km | `Distance(roundResult: false)` | `9f59905` |

## 5.3b Perubahan setelah commit `355fc2e` (belum di-commit)

| Perubahan | Berkas |
|---|---|
| Logo app dipasang: ikon peluncur, adaptive icon, splash native, splash Flutter | `assets/logo.png` (baru), `pubspec.yaml`, `lib/main.dart`, `mipmap-*/`, `drawable-*/`, `values/colors.xml` |
| Kotak "KL" di splash diganti logo asli | `lib/main.dart` |
| `flutter_launcher_icons` ditambahkan sebagai dev_dependency | `pubspec.yaml` |
| Dokumentasi ini dibuat | `DOKUMENTASI.md` |

## 5.4 Status saat ini

**Sudah selesai ✔**
- Firebase tersambung: proyek `familyrich-2575e`, app Android `com.keluarr.keluarr`, App ID `1:344664945385:android:9e3c8e845a48aa42a33678`, RTDB region `asia-southeast1`.
- Security Rules ter-deploy & **teruji 18 pemeriksaan** dengan dua akun anonim sungguhan terhadap database live.
- 60 tes lulus (`flutter test`), `flutter analyze` bersih.
- 20 layar utuh, 19 komponen pakai-ulang, 7 modul data.

**Masih perlu diklik manual ⚠️**
> Console → **Authentication → Sign-in method → Anonymous → Enable**
> Satu-satunya langkah yang tidak bisa lewat CLI (firebase-tools tidak punya perintahnya).
> Tanpa ini `Cloud.init()` gagal dan app jatuh ke mode lokal dengan pesan "Anonymous sign-in belum diaktifkan di konsol Firebase".
> https://console.firebase.google.com/project/familyrich-2575e/authentication/providers

## 5.5 Yang belum ada

- [ ] Scan QR undangan (kode masih diketik) — butuh `mobile_scanner`
- [ ] iOS — `firebase_options.dart` baru dikonfigurasi untuk Android
- [ ] Foto kartu share tidak ikut tersimpan di riwayat (hanya dipakai saat membuat kartu)
- [ ] `README.md` masih template bawaan Flutter
- [ ] Pindah `Store` ke sqflite kalau nanti ribuan aktivitas (ditandai `ponytail:` di `store.dart:11`)

## 5.6 Perintah harian

```bash
# Jalankan
flutter run -d <device-android>

# Tes & analisis
flutter test        # 60 tes
flutter analyze

# Deploy Rules setelah database.rules.json diubah
firebase deploy --only database --project familyrich-2575e

# Konfigurasi ulang Firebase (kalau proyeknya diganti)
dart pub global activate flutterfire_cli
flutterfire configure --project=<project-id> --platforms=android
```

## 5.7 Catatan untuk pengembangan berikutnya

> [!tip] Kalau mau menambah "share rute ke grup"
> Kamu harus menambah method baru di `lib/data/cloud.dart` **secara sadar**, dan mengubah `database.rules.json` supaya node `track/` diterima. Kedua penghalang itu sengaja ada — bukan kelalaian.

> [!tip] Kalau mau menambah metrik baru
> Cek dulu: apakah benar-benar diukur? `SportInfo.metrics` sengaja tidak menjanjikan yang tidak diukur.

> [!tip] Kalau mau mengubah `Track._minMeters`
> Ini trade-off ukuran simpanan vs ketelitian garis. 25 m dipilih karena rute lari cuma beberapa km dan tikungannya kecil; app touring pakai 200 m.

---

*Dokumentasi ini dibuat dari pembacaan kode langsung pada commit `355fc2e`.*
