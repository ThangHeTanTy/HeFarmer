/// MÁY CHỦ GIÁ HeFarmer — định dạng dữ liệu dùng chung giữa
///  - công cụ tổng hợp giá (tool/build_prices.dart) chạy định kỳ trên
///    GitHub Actions, đọc các trang nguồn MỘT LẦN rồi đăng file JSON, và
///  - ứng dụng, tải file JSON gọn đó thay vì mỗi máy tự đọc ~80 trang web.
///
/// Thuần Dart (chỉ cần gói http) để chạy được cả trên máy chủ.
library;

import 'dart:convert';

import 'package:http/http.dart' as http;

import 'price_catalog.dart';
import 'price_parser.dart';

/// Phiên bản định dạng. Đổi cấu trúc JSON theo kiểu không tương thích thì
/// tăng số này; app gặp phiên bản lạ sẽ bỏ qua máy chủ và tự tải như cũ.
const priceSnapshotSchema = 1;

/// Địa chỉ gốc của dữ liệu. Mặc định là nhánh `data` của kho mã trên GitHub;
/// đổi khi build bằng:  --dart-define=PRICE_DATA_URL=https://...
const priceDataBaseUrl = String.fromEnvironment(
  'PRICE_DATA_URL',
  defaultValue: 'https://raw.githubusercontent.com/ThangHeTanTy/HeFarmer/data',
);

/// Giá 1 mặt hàng trên máy chủ
class ServerItem {
  final String day; // yyyy-MM-dd (giờ VN) của lần tải thành công gần nhất
  final DateTime fetchedAt;
  final String? source;
  final List<PriceRow> rows;
  final int? avgBuy;
  final int? avgSell;
  final int? avgChange;

  const ServerItem({
    required this.day,
    required this.fetchedAt,
    required this.rows,
    this.source,
    this.avgBuy,
    this.avgSell,
    this.avgChange,
  });

  Map<String, dynamic> toJson() => {
        'day': day,
        'fetchedAt': fetchedAt.toUtc().toIso8601String(),
        'source': source,
        'avgBuy': avgBuy,
        'avgSell': avgSell,
        'avgChange': avgChange,
        'rows': rows.map((r) => r.toJson()).toList(),
      };

  factory ServerItem.fromJson(Map<String, dynamic> j) => ServerItem(
        day: j['day'] as String,
        fetchedAt: DateTime.parse(j['fetchedAt'] as String),
        source: j['source'] as String?,
        avgBuy: (j['avgBuy'] as num?)?.toInt(),
        avgSell: (j['avgSell'] as num?)?.toInt(),
        avgChange: (j['avgChange'] as num?)?.toInt(),
        rows: (j['rows'] as List)
            .map((e) => PriceRow.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

/// Toàn bộ giá mới nhất trên máy chủ (file latest.json)
class ServerSnapshot {
  final DateTime generatedAt;
  final double? usdVnd;
  final Map<String, ServerItem> items;

  const ServerSnapshot({
    required this.generatedAt,
    required this.items,
    this.usdVnd,
  });

  Map<String, dynamic> toJson() => {
        'schema': priceSnapshotSchema,
        'generatedAt': generatedAt.toUtc().toIso8601String(),
        'usdVnd': usdVnd,
        'items': items.map((k, v) => MapEntry(k, v.toJson())),
      };

  /// Trả về null nếu JSON sai định dạng hoặc khác phiên bản
  static ServerSnapshot? tryParse(String text) {
    try {
      final j = jsonDecode(text) as Map<String, dynamic>;
      if (j['schema'] != priceSnapshotSchema) return null;
      final items = <String, ServerItem>{};
      (j['items'] as Map<String, dynamic>).forEach((k, v) {
        try {
          items[k] = ServerItem.fromJson(v as Map<String, dynamic>);
        } catch (_) {/* bỏ mặt hàng hỏng, giữ phần còn lại */}
      });
      return ServerSnapshot(
        generatedAt: DateTime.parse(j['generatedAt'] as String),
        usdVnd: (j['usdVnd'] as num?)?.toDouble(),
        items: items,
      );
    } catch (_) {
      return null;
    }
  }
}

/// Lịch sử giá dài ngày của 1 mặt hàng (file `history/<id>.json`):
/// { "yyyy-MM-dd": {"avgBuy": .., "avgSell": .., "estimated": true?}, ... }
Map<String, dynamic> historyToJson(Iterable<DaySummary> days) => {
      for (final d in days)
        d.date: {
          'avgBuy': d.avgBuy,
          'avgSell': d.avgSell,
          if (d.estimated) 'estimated': true,
        },
    };

/// Đọc lịch sử; dòng hỏng bị bỏ qua. Xếp CŨ -> MỚI.
List<DaySummary> parseHistoryJson(String text) {
  try {
    final j = jsonDecode(text) as Map<String, dynamic>;
    final keys = j.keys.where(_isDayKey).toList()..sort();
    return [
      for (final k in keys)
        if (j[k] is Map<String, dynamic>)
          DaySummary(
            date: k,
            avgBuy: ((j[k] as Map)['avgBuy'] as num?)?.toInt(),
            avgSell: ((j[k] as Map)['avgSell'] as num?)?.toInt(),
            estimated: (j[k] as Map)['estimated'] == true,
          ),
    ];
  } catch (_) {
    return [];
  }
}

final _dayRe = RegExp(r'^\d{4}-\d{2}-\d{2}$');
bool _isDayKey(String s) => _dayRe.hasMatch(s);

/// Tải file từ máy chủ giá. Lỗi mạng/HTTP -> null (app tự xoay xở tiếp).
Future<String?> fetchFromPriceServer(
  String path, {
  http.Client? client,
  Duration timeout = const Duration(seconds: 8),
  String baseUrl = priceDataBaseUrl,
}) async {
  if (baseUrl.isEmpty) return null;
  final c = client ?? http.Client();
  try {
    final res = await c.get(Uri.parse('$baseUrl/$path')).timeout(timeout);
    if (res.statusCode != 200) return null;
    return utf8.decode(res.bodyBytes, allowMalformed: true);
  } catch (_) {
    return null;
  } finally {
    if (client == null) c.close();
  }
}
