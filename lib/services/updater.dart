import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// CẬP NHẬT APP TỪ GITHUB RELEASES (giống HeDeck).
///
/// Android không cho app ngoài Play Store tự cài im lặng: app chỉ tải APK về,
/// kiểm mã SHA-256, rồi mở trình cài đặt của hệ thống — bác bấm "Cài đặt" để
/// xác nhận. Phần mở trình cài đặt nằm trong MainActivity.kt (kênh
/// `hefarmer/update`). Cài đè bản mới KHÔNG mất hồ sơ, vị trí, cảnh báo hay
/// lịch sử giá.
class Updater {
  static const repo = 'ThangHeTanTy/HeFarmer';
  static const releasesPage = 'https://github.com/$repo/releases';

  /// Số phiên bản, do GitHub Actions truyền vào lúc build từ thẻ v1.2.3.
  /// Rỗng nghĩa là bản tự build trên máy.
  static const version = String.fromEnvironment('HEFARMER_VERSION');

  /// Bản tự build không biết số phiên bản của mình.
  static bool get selfBuilt => version.isEmpty;

  static const _channel = MethodChannel('hefarmer/update');

  static List<int>? parseVersion(String text) {
    final m = RegExp(r'^v?(\d+)\.(\d+)\.(\d+)$').firstMatch(text.trim());
    if (m == null) return null;
    return [for (var i = 1; i <= 3; i++) int.parse(m.group(i)!)];
  }

  /// a mới hơn b?
  static bool isNewer(List<int> a, List<int> b) {
    for (var i = 0; i < 3; i++) {
      if (a[i] != b[i]) return a[i] > b[i];
    }
    return false;
  }

  /// Bản mới nhất trên GitHub nếu mới hơn bản đang chạy, null nếu không có.
  /// Bản tự build không biết số phiên bản nên luôn nhận bản mới nhất.
  static Future<Release?> check() async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10);
    try {
      final req = await client.getUrl(
          Uri.parse('https://api.github.com/repos/$repo/releases/latest'));
      req.headers
        ..set(HttpHeaders.userAgentHeader, 'HeFarmer-App')
        ..set(HttpHeaders.acceptHeader, 'application/vnd.github+json');
      final resp = await req.close().timeout(const Duration(seconds: 15));
      final body = await resp.transform(utf8.decoder).join();
      if (resp.statusCode == 404) return null; // chưa có bản phát hành nào
      if (resp.statusCode != 200) {
        throw HttpException('GitHub ${resp.statusCode}');
      }
      final rel = Release.fromJson(jsonDecode(body) as Map<String, dynamic>);
      if (rel == null) return null;
      final current = parseVersion(version);
      if (current != null && !isNewer(rel.parts, current)) return null;
      return rel;
    } finally {
      client.close(force: true);
    }
  }

  /// Tải APK về bộ nhớ đệm của app, kiểm SHA-256 nếu GitHub có ghi.
  /// [onProgress] nhận 0..1, hoặc -1 khi không biết dung lượng.
  static Future<File> download(Release rel,
      {void Function(double)? onProgress}) async {
    final dir = await _channel.invokeMethod<String>('apkDir');
    final file = File('$dir/HeFarmer-${rel.version}.apk');
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15);
    try {
      final req = await client.getUrl(Uri.parse(rel.apkUrl));
      req.headers.set(HttpHeaders.userAgentHeader, 'HeFarmer-App');
      final resp = await req.close();
      if (resp.statusCode != 200) {
        throw HttpException('GitHub ${resp.statusCode}');
      }
      final total = resp.contentLength > 0 ? resp.contentLength : rel.apkSize;
      final digest = _DigestSink();
      final hash = sha256.startChunkedConversion(digest);
      final out = file.openWrite();
      var done = 0;
      try {
        await for (final chunk in resp.timeout(const Duration(seconds: 30))) {
          out.add(chunk);
          hash.add(chunk);
          done += chunk.length;
          onProgress?.call(total > 0 ? done / total : -1);
        }
      } finally {
        await out.close();
      }
      hash.close();
      if (rel.apkSha256.isNotEmpty && digest.value.toString() != rel.apkSha256) {
        await file.delete();
        throw const FormatException('sha256');
      }
      return file;
    } finally {
      client.close(force: true);
    }
  }

  /// Mở trình cài đặt của Android. Lần đầu Android sẽ hỏi cho phép HeFarmer
  /// cài ứng dụng — bật lên rồi quay lại là cài tiếp.
  static Future<void> install(File apk) =>
      _channel.invokeMethod('install', {'path': apk.path});

  // ---------- Tự hỏi khi mở app ----------

  static const _lastCheckKey = 'update_last_check_v1';
  static const _snoozeKey = 'update_snooze_v1'; // "1.2.0|2026-11-09"

  /// Mở app thì tự hỏi GitHub tối đa 1 lần/ngày. Bác bấm "Để sau" thì cùng
  /// bản đó 3 ngày sau mới nhắc lại. Bản tự build không tự hỏi (luôn coi
  /// bản trên GitHub là mới -> nhắc mãi).
  static Future<Release?> autoCheck({DateTime? now}) async {
    if (selfBuilt) return null;
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = _day(now ?? DateTime.now());
      if (prefs.getString(_lastCheckKey) == today) return null;
      await prefs.setString(_lastCheckKey, today);
      final rel = await check();
      if (rel == null) return null;
      if (isSnoozed(prefs.getString(_snoozeKey), rel.version,
          now ?? DateTime.now())) {
        return null;
      }
      return rel;
    } catch (_) {
      return null; // mất mạng: lần mở sau hỏi lại
    }
  }

  /// Ghi nhớ bác vừa bấm "Để sau" cho bản [ver]
  static Future<void> snooze(String ver, {DateTime? now}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_snoozeKey, '$ver|${_day(now ?? DateTime.now())}');
  }

  /// Thuần (test được): bản [ver] có đang được hoãn nhắc không (3 ngày)
  static bool isSnoozed(String? saved, String ver, DateTime now) {
    if (saved == null) return false;
    final parts = saved.split('|');
    if (parts.length != 2 || parts[0] != ver) return false;
    final day = DateTime.tryParse(parts[1]);
    if (day == null) return false;
    return now.difference(day).inDays < 3;
  }

  static String _day(DateTime d) => '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

class _DigestSink implements Sink<Digest> {
  late Digest value;
  @override
  void add(Digest data) => value = data;
  @override
  void close() {}
}

class Release {
  final String version;
  final List<int> parts;
  final String notes;
  final String apkUrl;
  final int apkSize;
  final String apkSha256;

  const Release({
    required this.version,
    required this.parts,
    required this.notes,
    required this.apkUrl,
    required this.apkSize,
    required this.apkSha256,
  });

  /// Null nếu thẻ không đúng dạng v1.2.3 hoặc bản phát hành không có APK.
  static Release? fromJson(Map<String, dynamic> j) {
    final parts = Updater.parseVersion('${j['tag_name'] ?? ''}');
    if (parts == null) return null;
    final assets = (j['assets'] as List? ?? []).cast<Map<String, dynamic>>();
    final apk = assets
        .where((a) => '${a['name']}'.toLowerCase().endsWith('.apk'))
        .firstOrNull;
    if (apk == null) return null;
    final digest = '${apk['digest'] ?? ''}';
    return Release(
      version: parts.join('.'),
      parts: parts,
      // Phần dưới dòng --- là hướng dẫn cài lần đầu, không phải thay đổi.
      notes: '${j['body'] ?? ''}'
          .split(RegExp(r'^---\s*$', multiLine: true))[0]
          .trim(),
      apkUrl: '${apk['browser_download_url']}',
      apkSize: (apk['size'] as num?)?.toInt() ?? 0,
      // GitHub tự tính SHA-256 cho mọi file đính kèm, dạng "sha256:…".
      apkSha256: digest.startsWith('sha256:') ? digest.substring(7) : '',
    );
  }
}
