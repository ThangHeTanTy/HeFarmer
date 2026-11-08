/// BỘ TẢI GIÁ — thuần Dart (chỉ cần gói http), dùng chung cho:
///  - ứng dụng (khi máy chủ chưa có giá hôm nay thì tự đọc trang nguồn),
///  - công cụ tổng hợp giá trên máy chủ (tool/build_prices.dart).
library;

import 'dart:convert';

import 'package:http/http.dart' as http;

import 'price_catalog.dart';
import 'price_parser.dart';

/// Khoá ngày dạng yyyy-MM-dd
String todayKey([DateTime? d]) {
  final t = d ?? DateTime.now();
  return '${t.year.toString().padLeft(4, '0')}-'
      '${t.month.toString().padLeft(2, '0')}-'
      '${t.day.toString().padLeft(2, '0')}';
}

/// Ngày hôm nay THEO GIỜ VIỆT NAM (UTC+7) — máy chủ chạy giờ UTC nên phải
/// quy đổi, không thì 0h–7h sáng ở VN sẽ bị tính là ngày hôm trước.
String vnTodayKey([DateTime? nowUtc]) => todayKey(
    (nowUtc ?? DateTime.now()).toUtc().add(const Duration(hours: 7)));

String shiftDay(String key, int delta) {
  final d = DateTime.parse(key).add(Duration(days: delta));
  return todayKey(d);
}

/// Một lần thử đọc 1 URL của 1 nguồn (để báo cáo nguồn nào đang hỏng)
class SourceAttempt {
  final String source;
  final String url;
  final int rows;
  final String? error;
  const SourceAttempt({
    required this.source,
    required this.url,
    this.rows = 0,
    this.error,
  });

  bool get ok => error == null && rows > 0;

  Map<String, dynamic> toJson() =>
      {'source': source, 'url': url, 'rows': rows, 'error': error};
}

/// Kết quả tải 1 mặt hàng. Không bao giờ ném lỗi: lỗi nằm trong [error].
class FetchedCommodity {
  final Commodity commodity;
  final List<PriceRow> rows;
  final String? sourceName;
  final String? error;
  final List<SourceAttempt> attempts;
  const FetchedCommodity({
    required this.commodity,
    required this.rows,
    required this.attempts,
    this.sourceName,
    this.error,
  });

  bool get ok => error == null && rows.isNotEmpty;
}

/// Giá trung bình của 1 mặt hàng
class PriceSummary {
  final int? avgBuy;
  final int? avgSell;
  final int? avgChange;
  const PriceSummary({this.avgBuy, this.avgSell, this.avgChange});
}

/// CHỈ tính trung bình trên các dòng CÙNG ĐƠN VỊ với mặt hàng.
/// Ví dụ mủ cao su: chỉ lấy các dòng đ/độ TSC, không trộn với đ/kg
/// (trộn vào sẽ ra con số vô nghĩa).
PriceSummary summarizeRows(Commodity c, List<PriceRow> rows) {
  final sameUnit =
      rows.where((r) => r.unit == null || r.unit == c.unit).toList();
  final base = sameUnit.isEmpty ? rows : sameUnit;
  return PriceSummary(
    avgBuy: average(base.map((r) => r.buy)),
    avgSell: average(base.map((r) => r.sell)),
    avgChange: average(base.map((r) => r.change)),
  );
}

/// Các dòng lịch sử cần ghi sau khi có giá của ngày [day]:
///  - giá của ngày [day],
///  - nếu CHƯA có ngày hôm trước mà nguồn có ghi mức tăng/giảm, thì ước
///    tính luôn giá hôm trước (đánh dấu estimated).
List<DaySummary> historyEntriesFor(
  String day,
  PriceSummary s, {
  required bool hasPreviousDay,
}) {
  final out = <DaySummary>[
    DaySummary(date: day, avgBuy: s.avgBuy, avgSell: s.avgSell),
  ];
  if (!hasPreviousDay && s.avgChange != null && s.avgBuy != null) {
    out.add(DaySummary(
      date: shiftDay(day, -1),
      avgBuy: s.avgBuy! - s.avgChange!,
      estimated: true,
    ));
  }
  return out;
}

const _userAgent =
    'Mozilla/5.0 (Linux; Android 12) AppleWebKit/537.36 (KHTML, like Gecko) '
    'Chrome/120 Mobile Safari/537.36';

class PriceFetcher {
  final http.Client _client;
  final Duration timeout;

  /// Nhiều mặt hàng dùng chung một trang nguồn -> nhớ tạm theo Future để khi
  /// tải SONG SONG, cùng một trang chỉ được tải đúng 1 lần (đỡ tốn mạng).
  /// Mỗi PriceFetcher là một lượt tải, nên tạo mới mỗi lượt để lấy giá mới.
  final Map<String, Future<String>> _cache = {};

  PriceFetcher({http.Client? client, this.timeout = const Duration(seconds: 15)})
      : _client = client ?? http.Client();

  void close() => _client.close();

  Future<String> fetchText(String url) =>
      _cache.putIfAbsent(url, () => _doFetch(url));

  Future<String> _doFetch(String url) async {
    final res = await _client.get(
      Uri.parse(url),
      headers: {
        'User-Agent': _userAgent,
        'Accept': 'text/html,application/xhtml+xml,application/json,*/*',
      },
    ).timeout(timeout);
    if (res.statusCode != 200) {
      throw Exception('HTTP ${res.statusCode}');
    }
    return utf8.decode(res.bodyBytes, allowMalformed: true);
  }

  /// Tỷ giá USD/VND (null nếu không tải được)
  Future<double?> fetchUsdVndRate() async {
    try {
      final res = await _client
          .get(Uri.parse('https://open.er-api.com/v6/latest/USD'))
          .timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return null;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final v = ((data['rates'] as Map<String, dynamic>?)?['VND'] as num?)
          ?.toDouble();
      if (v != null && v > 15000 && v < 60000) return v;
    } catch (_) {/* không có tỷ giá */}
    return null;
  }

  /// Thử lần lượt các nguồn (và các URL ứng viên của mỗi nguồn)
  /// cho tới khi bóc được dữ liệu.
  Future<FetchedCommodity> fetchCommodity(Commodity c) async {
    final attempts = <SourceAttempt>[];
    for (final source in c.sources) {
      final urls = source.urlCandidates?.call() ?? [source.url];
      for (final url in urls) {
        try {
          final text = await fetchText(url);
          final rows = source.parse(source.raw ? text : htmlToText(text));
          if (rows.isNotEmpty) {
            attempts.add(SourceAttempt(
                source: source.name, url: url, rows: rows.length));
            return FetchedCommodity(
              commodity: c,
              rows: rows,
              sourceName: source.name,
              attempts: attempts,
            );
          }
          attempts.add(SourceAttempt(
              source: source.name,
              url: url,
              error: 'Không bóc được dữ liệu'));
        } catch (e) {
          attempts.add(SourceAttempt(
              source: source.name,
              url: url,
              error: e.toString().replaceFirst('Exception: ', '')));
        }
      }
    }
    final last = attempts.isEmpty ? 'không có nguồn' : attempts.last.error;
    final tried = c.sources.map((e) => e.name).join(', ');
    return FetchedCommodity(
      commodity: c,
      rows: const [],
      attempts: attempts,
      error: '$last — đã thử: $tried',
    );
  }
}
