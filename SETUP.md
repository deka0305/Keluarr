# Keluarr — setup

App Flutter: rekam jejak GPS pribadi + berbagi lokasi live ke grup.
Aturan tetap: **jejak GPS tidak pernah keluar dari HP**, kecuali kamu ekspor
GPX atau bagikan gambar sendiri.

## Apa yang disimpan di mana

| Data | Tempat | Alasan |
|---|---|---|
| Aktivitas, jejak GPS, split, catatan | `SharedPreferences` (satu blob JSON, `lib/data/store.dart`) | Pribadi. Tidak ada salinan di server. |
| Preferensi (tema, bahasa, satuan, izin berbagi) | sama | Ikut satu blob, satu pintu simpan. |
| Grup: nama, kode, olahraga, target, admin | Firebase RTDB `keluarr/{kode}/meta` | Harus sama di semua HP. |
| Anggota | `keluarr/{kode}/members/{uid}` | |
| Lokasi live + status + kecepatan + arah | `keluarr/{kode}/live/{uid}` | Satu-satunya lokasi yang dibagikan. |
| Agregat leaderboard (km, jumlah, detik) | `keluarr/{kode}/stats/{uid}` | Angka saja, tanpa titik GPS. Opt-in di layar Privasi. |
| **Jejak GPS** | **tidak ada di server** | Tidak ada method-nya di `lib/data/cloud.dart`, dan Rules menolak node asing. |

App tetap jalan penuh tanpa Firebase (mode lokal): perekaman, penyimpanan,
riwayat, kartu share — hanya grup & lokasi live yang tidak sinkron.

## 1. Firebase — SUDAH TERSAMBUNG ✔

Proyek **familyrich-2575e**, app Android **Keluarr** (`com.keluarr.keluarr`),
App ID `1:344664945385:android:9e3c8e845a48aa42a33678`.

Sudah dikerjakan:
* App Android didaftarkan (`firebase apps:create android`).
* `android/app/google-services.json` diunduh.
* `lib/firebase_options.dart` diisi apiKey/appId/senderId.
* Security Rules dari `database.rules.json` di-deploy ke
  `familyrich-2575e-default-rtdb` (region asia-southeast1).

Kalau nanti proyeknya diganti, ulangi dengan:

```bash
dart pub global activate flutterfire_cli
flutterfire configure --project=<project-id> --platforms=android
```

## 2. Nyalakan Anonymous sign-in — MASIH PERLU KAMU KLIK

Console → **Authentication → Sign-in method → Anonymous → Enable**.
Ini satu-satunya langkah yang tidak bisa lewat CLI (firebase-tools tidak punya
perintahnya). Tanpa ini `Cloud.init()` gagal dan app jatuh ke mode lokal dengan
pesan "Anonymous sign-in belum diaktifkan di konsol Firebase".

<https://console.firebase.google.com/project/familyrich-2575e/authentication/providers>

## 3. Security Rules

Sudah ter-deploy. Kalau `database.rules.json` diubah:

```bash
firebase deploy --only database --project familyrich-2575e
```

Yang ditegakkan Rules:
* Grup hanya bisa dibaca anggotanya (`members/{auth.uid}` harus ada).
* `live/{uid}` dan `stats/{uid}` hanya bisa ditulis pemiliknya → tidak ada cara
  memalsukan posisi orang lain.
* Hanya admin (pembuat) yang boleh ubah `meta`, keluarkan anggota, dan hapus grup.
* Hapus grup diizinkan di level grup **hanya untuk penghapusan penuh**
  (`!newData.exists()`). Kalau ditulis sebagai izin tulis umum, izin itu menurun
  ke semua anaknya dan admin jadi bisa memalsukan `live/{uid}` anggota lain.
* `meta/adminUid` boleh dipindah admin, tapi hanya ke dirinya sendiri atau ke
  orang yang benar-benar anggota — supaya grup tidak jadi yatim. Cabang "diri
  sendiri" wajib ada: saat grup dibuat, `meta` ditulis sebelum `members/{uid}`.
* Anggota yang dikeluarkan masuk `banned/` supaya tidak bisa masuk lagi dengan
  kode yang masih dia pegang.
* Node yang tidak dikenal ditolak — termasuk percobaan menulis jejak GPS.

Rules-nya sudah diuji end-to-end dengan dua akun anonim sungguhan terhadap
database live (18 pemeriksaan: buat grup → gabung → kirim posisi → tolak
`track/`, tolak posisi orang lain, tolak ubah `meta` oleh non-admin, tolak hapus
grup oleh non-admin, admin keluarkan + cekal + hapus grup). Ulangi kapan saja
dengan skrip di bagian bawah berkas ini.

<details>
<summary>Skrip uji Rules (PowerShell)</summary>

Butuh dua akun anonim; ganti `$key` kalau apiKey berubah.

```powershell
$key='AIzaSyDDWTMFg1Opr-vOb-QxmzCnDy_uS0sJ3jg'
$db='https://familyrich-2575e-default-rtdb.asia-southeast1.firebasedatabase.app'
$a=(Invoke-WebRequest -Method Post -Uri "https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=$key" -ContentType 'application/json' -Body '{"returnSecureToken":true}' -UseBasicParsing).Content|ConvertFrom-Json
function Hit($tok,$m,$p,$b){try{Invoke-WebRequest -Method $m -Uri "$db/keluarr/$p.json?auth=$tok" -ContentType 'application/json' -Body $b -UseBasicParsing -EA Stop|Out-Null;"OK   $m $p"}catch{"DENY $m $p ($($_.Exception.Response.StatusCode.value__))"}}
Hit $a.idToken PUT "KLR-TEST/meta" "{`"name`":`"Uji`",`"adminUid`":`"$($a.localId)`"}"   # OK
Hit $a.idToken PUT "KLR-TEST/track/$($a.localId)" '{"geom":"abc"}'                        # DENY
Hit $a.idToken DELETE "KLR-TEST" $null                                                    # OK
```

</details>

## 4. Jalankan

```bash
flutter run -d <device-android>
```

Izin lokasi diminta saat pertama menekan **MULAI REKAM RUTE**. Di Android
perekaman memakai foreground service (notifikasi "Merekam rute") supaya jejak
tidak berhenti begitu layar mati.

## Peta

Tile OpenStreetMap, tanpa API key. Tema gelap dibuat dengan membalik warna tile
(`_darkTiles` di `lib/widgets.dart`). Atribusi "© OpenStreetMap" wajib tetap
terlihat — itu syarat pemakaian tile mereka.

## Uji

```bash
flutter test      # 23 tes: format angka, Track/jarak GPS, pack, polyline, GPX,
                  # penyimpanan, plus render semua layar (menangkap overflow)
flutter analyze
```

## Yang belum ada

* Scan QR undangan (kode masih diketik) — butuh `mobile_scanner`.
* iOS: `firebase_options.dart` baru dikonfigurasi untuk Android.
* Foto kartu share tidak ikut tersimpan di riwayat (hanya dipakai saat membuat
  kartu).
