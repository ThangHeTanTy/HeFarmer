import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'history_store.dart';
import 'price_catalog.dart';
import 'price_fetcher.dart';
import 'price_parser.dart';
import 'price_server.dart';

export 'price_catalog.dart';
export 'price_fetcher.dart' show todayKey, shiftDay;

/// DỊCH VỤ GIÁ CỦA ỨNG DỤNG
///
/// Thứ tự lấy giá cho mỗi mặt hàng:
///  1. MÁY CHỦ HeFarmer (file JSON gọn, tổng hợp sẵn mỗi 30 phút) — nhanh,
///     đỡ tốn mạng 3G, và sửa nguồn hỏng không cần cập nhật app.
///  2. Máy chủ chưa có giá HÔM NAY -> app tự đọc các trang nguồn như trước
///     (nhiều nguồn dự phòng xếp tầng).
///  3. Cả hai đều lỗi -> hiện giá gần nhất và GHI RÕ là giá ngày nào.
///
/// Lịch sử giá được ghi vào SQLite (history_store.dart) để dựng bảng
/// "3 ngày gần nhất" và biểu đồ.

const _usdVndPrefsKey = 'usd_vnd_rate';

// ---------- Máy chủ giá (nhớ tạm 5 phút cho các tab dùng chung) ----------

Future<ServerSnapshot?>? _snapshotFuture;
DateTime? _snapshotAt;

Future<ServerSnapshot?> _serverSnapshot() {
  final at = _snapshotAt;
  if (_snapshotFuture == null ||
      at == null ||
      DateTime.now().difference(at) > const Duration(minutes: 5)) {
    _snapshotAt = DateTime.now();
    _snapshotFuture = fetchFromPriceServer('latest.json')
        .then((t) => t == null ? null : ServerSnapshot.tryParse(t));
  }
  return _snapshotFuture!;
}

// ---------- Tải giá ----------

/// Hàm chính cho màn hình Giá: truyền vào danh sách mặt hàng cần lấy.
///
/// - Các mặt hàng được tải SONG SONG (Future.wait).
/// - Kết quả hiển thị được lưu lại (cacheKey) để lần mở sau hiện NGAY
///   dữ liệu cũ trong lúc chờ dữ liệu mới về (stale-while-revalidate).
Future<List<CommodityResult>> fetchAllPrices(
  List<Commodity>? commodityList, {
  String? cacheKey,
}) async {
  final list = commodityList ?? commodities;
  final prefs = await SharedPreferences.getInstance();
  final today = todayKey();
  final snapshot = await _serverSnapshot();
  final fetcher = PriceFetcher();

  try {
    // Cần tỷ giá để quy đổi giá vàng/bạc thế giới sang VNĐ — chỉ khi phải
    // tự đọc trang nguồn (máy chủ đã quy đổi sẵn).
    final needRate = list.any((c) =>
        (c.id == 'vang' || c.id == 'bac') &&
        snapshot?.items[c.id]?.day != today);
    if (needRate) {
      final rate = await fetcher.fetchUsdVndRate() ?? snapshot?.usdVnd;
      if (rate != null) {
        usdVndRate = rate;
        await prefs.setDouble(_usdVndPrefsKey, rate);
      } else {
        usdVndRate ??= prefs.getDouble(_usdVndPrefsKey);
      }
    }

    final store = HistoryStore.instance;
    final results = await Future.wait(list.map((c) => _processCommodity(
        c, fetcher, snapshot?.items[c.id], store, today)));

    if (cacheKey != null) {
      await _saveResultsCache(prefs, cacheKey, results);
    }
    return results;
  } finally {
    fetcher.close();
  }
}

/// Chọn nguồn giá cho 1 mặt hàng (thuần, để test được)
class PriceChoice {
  final List<PriceRow> rows;
  final String? sourceName;
  final DateTime fetchedAt;
  final PriceSummary? summary;
  final String? day; // ngày của giá (null = không có giá nào)
  final String? error;
  const PriceChoice({
    required this.rows,
    required this.fetchedAt,
    this.sourceName,
    this.summary,
    this.day,
    this.error,
  });
}

/// Máy chủ có giá hôm nay -> dùng luôn, KHÔNG cần tự đọc trang nguồn.
bool serverHasToday(ServerItem? item, String today) =>
    item != null && item.day == today && item.rows.isNotEmpty;

/// Ghép kết quả: giá hôm nay của máy chủ > tự đọc trang nguồn > giá cũ của
/// máy chủ (kèm thông báo rõ ngày).
PriceChoice choosePrice({
  required Commodity commodity,
  required ServerItem? server,
  required FetchedCommodity? direct,
  required String today,
  DateTime? now,
}) {
  final t = now ?? DateTime.now();
  final item = server;
  PriceSummary fromServer(ServerItem s) => PriceSummary(
      avgBuy: s.avgBuy, avgSell: s.avgSell, avgChange: s.avgChange);

  if (item != null && serverHasToday(item, today)) {
    return PriceChoice(
      rows: item.rows,
      sourceName: item.source,
      fetchedAt: item.fetchedAt.toLocal(),
      summary: fromServer(item),
      day: today,
    );
  }
  if (direct != null && direct.ok) {
    return PriceChoice(
      rows: direct.rows,
      sourceName: direct.sourceName,
      fetchedAt: t,
      summary: summarizeRows(commodity, direct.rows),
      day: today,
    );
  }
  if (item != null && item.rows.isNotEmpty) {
    return PriceChoice(
      rows: item.rows,
      sourceName: item.source,
      fetchedAt: item.fetchedAt.toLocal(),
      summary: fromServer(item),
      day: item.day,
      error: 'Hôm nay các nguồn chưa đăng giá mới. '
          'Đang hiển thị giá ngày ${formatDateVn(item.day)}.',
    );
  }
  final reason = direct?.error ?? 'không có mạng';
  return PriceChoice(
    rows: const [],
    fetchedAt: t,
    error: 'Chưa lấy được giá mới ($reason). '
        'Đang hiển thị dữ liệu gần nhất đã lưu (nếu có).',
  );
}

/// Xử lý 1 mặt hàng (chạy song song với các mặt hàng khác)
Future<CommodityResult> _processCommodity(
  Commodity c,
  PriceFetcher fetcher,
  ServerItem? server,
  HistoryStore store,
  String today,
) async {
  final direct =
      serverHasToday(server, today) ? null : await fetcher.fetchCommodity(c);
  final choice = choosePrice(
      commodity: c, server: server, direct: direct, today: today);

  List<DaySummary> days = const [];
  try {
    final summary = choice.summary;
    final day = choice.day;
    if (summary != null && day != null) {
      final hasPrev = await store.has(c.id, shiftDay(day, -1));
      for (final e in historyEntriesFor(day, summary, hasPreviousDay: hasPrev)) {
        await store.put(c.id, e);
      }
    }
    days = await store.recent(c.id, 3);
  } catch (_) {
    // Không ghi/đọc được lịch sử (hiếm) -> vẫn hiện giá vừa tải
    final s = choice.summary;
    if (s != null && choice.day != null) {
      days = [DaySummary(date: choice.day!, avgBuy: s.avgBuy, avgSell: s.avgSell)];
    }
  }

  return CommodityResult(
    commodity: c,
    rows: choice.rows,
    days: days,
    sourceName: choice.sourceName,
    fetchedAt: choice.fetchedAt,
    error: choice.error,
  );
}

// ---------- Bộ nhớ kết quả hiển thị (để mở app là thấy ngay) ----------

Future<void> _saveResultsCache(
  SharedPreferences prefs,
  String cacheKey,
  List<CommodityResult> results,
) async {
  final data = results
      .map((r) => {
            'id': r.commodity.id,
            'rows': r.rows.map((x) => x.toJson()).toList(),
            'days': r.days
                .map((d) => {
                      'date': d.date,
                      'avgBuy': d.avgBuy,
                      'avgSell': d.avgSell,
                      'estimated': d.estimated,
                    })
                .toList(),
            'sourceName': r.sourceName,
            'fetchedAt': r.fetchedAt.toIso8601String(),
            'error': r.error,
          })
      .toList();
  await prefs.setString('results_cache_$cacheKey', jsonEncode(data));
}

/// Đọc kết quả đã lưu của lần tải trước — trả về ngay lập tức, không cần mạng.
Future<List<CommodityResult>?> loadCachedResults(String cacheKey) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('results_cache_$cacheKey');
    if (raw == null) return null;
    final data = jsonDecode(raw) as List;
    final results = <CommodityResult>[];
    for (final item in data) {
      final m = item as Map<String, dynamic>;
      final c = findCommodity(m['id'] as String);
      if (c == null) continue;
      results.add(CommodityResult(
        commodity: c,
        rows: (m['rows'] as List)
            .map((x) => PriceRow.fromJson(x as Map<String, dynamic>))
            .toList(),
        days: (m['days'] as List).map((d) {
          final e = d as Map<String, dynamic>;
          return DaySummary(
            date: e['date'] as String,
            avgBuy: (e['avgBuy'] as num?)?.toInt(),
            avgSell: (e['avgSell'] as num?)?.toInt(),
            estimated: (e['estimated'] as bool?) ?? false,
          );
        }).toList(),
        sourceName: m['sourceName'] as String?,
        fetchedAt:
            DateTime.tryParse(m['fetchedAt'] as String? ?? '') ?? DateTime.now(),
        error: m['error'] as String?,
      ));
    }
    return results.isEmpty ? null : results;
  } catch (_) {
    return null;
  }
}

// ---------- Định dạng ----------

String formatVnd(int? n) {
  if (n == null) return '—';
  final s = n.abs().toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    final left = s.length - i;
    buf.write(s[i]);
    if (left > 1 && left % 3 == 1) buf.write('.');
  }
  return (n < 0 ? '-' : '') + buf.toString();
}

String formatDateVn(String key) {
  final p = key.split('-');
  return '${p[2]}/${p[1]}';
}

// ---------- Lịch sử cho biểu đồ ----------

/// Đọc lịch sử giá đã lưu của 1 mặt hàng (tối đa `days` ngày gần nhất)
/// dùng cho biểu đồ. Không cần mạng.
Future<List<DaySummary>> loadPriceHistory(String commodityId,
    {int days = 30}) async {
  try {
    return await HistoryStore.instance.recent(commodityId, days);
  } catch (_) {
    return [];
  }
}

/// Tải lịch sử DÀI NGÀY từ máy chủ (mỗi mặt hàng tối đa 1 lần/ngày) rồi gộp
/// vào máy, nhờ vậy vừa cài app đã có biểu đồ nhiều tháng.
/// Trả về true nếu có dữ liệu mới.
Future<bool> syncServerHistory(String commodityId) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final key = 'server_history_synced_$commodityId';
    final today = todayKey();
    if (prefs.getString(key) == today) return false;
    final text = await fetchFromPriceServer('history/$commodityId.json');
    if (text == null) return false;
    final days = parseHistoryJson(text);
    final store = HistoryStore.instance;
    await store.mergeFromServer(commodityId, days);
    await store.prune();
    await prefs.setString(key, today);
    return days.isNotEmpty;
  } catch (_) {
    return false;
  }
}

// ---------- TẢI SẴN NGẦM cho các tab chưa mở ----------

bool _prefetchDone = false;

/// Sau khi tab đầu tiên có dữ liệu, gọi hàm này để LẦN LƯỢT tải sẵn dữ liệu
/// của các tab còn lại và cất vào bộ nhớ máy. Nhờ vậy khi bác bấm sang tab
/// khác là thấy giá NGAY, không phải chờ tải lại từ đầu.
///
/// Cố ý tải LẦN LƯỢT (không cùng lúc) và nghỉ giữa mỗi tab để máy còn sức
/// vẽ giao diện — tránh giật khi bà con đang cuộn xem giá.
Future<void> prefetchOtherTabs() async {
  if (_prefetchDone) return;
  _prefetchDone = true;

  final tabs = <(String, List<Commodity>)>[
    ('livestock', livestockCommodities),
    ('inputs', inputCommodities),
    ('metals', metalsCommodities),
  ];

  for (final tab in tabs) {
    try {
      await fetchAllPrices(tab.$2, cacheKey: tab.$1);
    } catch (_) {
      // tab nào lỗi thì bỏ qua, khi mở tab đó sẽ tự tải lại
    }
    // nghỉ một nhịp cho giao diện mượt
    await Future<void>.delayed(const Duration(milliseconds: 400));
  }
}
