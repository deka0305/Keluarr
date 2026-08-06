// Konfigurasi Firebase untuk proyek **familyRich** (familyrich-2575e).
//
// Berkas ini biasanya dibangkitkan FlutterFire CLI. Yang sudah pasti dari
// konsol: projectId, databaseURL, dan region (asia-southeast1). Yang HARUS
// diisi dari aplikasi Android yang didaftarkan di proyek itu: apiKey, appId,
// messagingSenderId.
//
// Cara mengisinya — pilih salah satu:
//
// A. Otomatis (disarankan):
//      dart pub global activate flutterfire_cli
//      flutterfire configure --project=familyrich-2575e --platforms=android
//    Perintah itu MENIMPA berkas ini dengan nilai yang benar dan sekaligus
//    menaruh android/app/google-services.json.
//
// B. Manual: di Firebase Console → Project settings → "Add app" → Android,
//    daftarkan package **com.keluarr.keluarr**, lalu salin dari
//    google-services.json:
//      apiKey   = api_key[0].current_key
//      appId    = client[0].client_info.mobilesdk_app_id
//      senderId = project_info.project_number
//
// Sampai diisi, [DefaultFirebaseOptions] melempar UnsupportedError,
// firebase_config.dart mengubahnya jadi null, dan app jalan di mode lokal:
// perekaman + penyimpanan penuh, hanya grup & lokasi live yang belum sinkron.
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Nilai untuk app Android "Keluarr" (com.keluarr.keluarr) di proyek
/// familyrich-2575e, diambil dari `firebase apps:sdkconfig`.
const _apiKey = 'AIzaSyDDWTMFg1Opr-vOb-QxmzCnDy_uS0sJ3jg';
const _appId = '1:344664945385:android:9e3c8e845a48aa42a33678';
const _senderId = '344664945385';

const _belumDiisi = _apiKey == 'ISI_API_KEY';

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (_belumDiisi) {
      throw UnsupportedError(
        'Firebase belum dikonfigurasi: jalankan '
        '`flutterfire configure --project=familyrich-2575e` atau isi nilai di '
        'lib/firebase_options.dart.',
      );
    }
    if (kIsWeb) {
      throw UnsupportedError('Web belum dikonfigurasi untuk Keluarr.');
    }
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => android,
      _ => throw UnsupportedError(
          'Platform $defaultTargetPlatform belum dikonfigurasi untuk Keluarr.'),
    };
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: _apiKey,
    appId: _appId,
    messagingSenderId: _senderId,
    projectId: 'familyrich-2575e',
    databaseURL:
        'https://familyrich-2575e-default-rtdb.asia-southeast1.firebasedatabase.app',
    storageBucket: 'familyrich-2575e.firebasestorage.app',
  );
}
