import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Penyimpanan lokal: aktivitas (termasuk jejak GPS), grup aktif, dan
/// preferensi, sebagai satu blob JSON di SharedPreferences.
///
/// Ini satu-satunya tempat jejak GPS bertahan — tidak ada salinan di server.
///
/// ponytail: satu key, tulis-ulang seluruhnya tiap simpan, dan penulisannya
/// dijadwalkan (debounce) supaya perekaman per-detik tidak menulis 3.600 kali
/// per jam. Blob ~10 KB per aktivitas; kalau nanti ribuan aktivitas atau butuh
/// query per tanggal, pindah ke sqflite — bentuk JSON-nya sudah per-baris.
const _key = 'keluarr_state_v1';

class Store {
  SharedPreferences? _prefs;
  Map<String, dynamic>? _pending;
  Future<void>? _writing;

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

  Future<void> _flush() async {
    _writing = null;
    final body = _pending;
    _pending = null;
    if (body == null) return;
    try {
      _prefs ??= await SharedPreferences.getInstance();
      await _prefs!.setString(_key, jsonEncode(body));
    } catch (e) {
      debugPrint('store: gagal menyimpan ($e)');
    }
  }

  /// Tulis sekarang — dipakai sebelum app ditutup atau setelah aktivitas
  /// disimpan, supaya rekaman yang baru selesai tidak hilang kalau app dibunuh.
  Future<void> flushNow(Map<String, dynamic> state) async {
    _pending = state;
    await _flush();
  }
}
