// CÔNG CỤ TỔNG HỢP GIÁ — chạy định kỳ trên GitHub Actions
// (.github/workflows/prices.yml), KHÔNG chạy trong app.
//
// Đọc tất cả trang nguồn MỘT LẦN, rồi ghi ra thư mục --out:
//   latest.json          giá mới nhất của mọi mặt hàng (app tải file này)
//   history/<id>.json    lịch sử giá trung bình theo ngày (~3 năm)
//   health.json          nguồn nào đang chạy / đang hỏng
//
// Cách chạy thử trên máy:
//   dart run tool/build_prices.dart --out build/price-data
// Có dữ liệu lần trước (để giữ lịch sử và giá cũ khi nguồn lỗi):
//   dart run tool/build_prices.dart --previous data-branch --out build/price-data
//
// Mã thoát: 0 = có ít nhất 1 mặt hàng tải được; 1 = mọi mặt hàng đều lỗi
// (khi đó KHÔNG nên đăng dữ liệu, giữ nguyên bản cũ).

import 'dart:convert';
import 'dart:io';

import 'package:hefarmer/services/price_catalog.dart';
import 'package:hefarmer/services/price_fetcher.dart';
import 'package:hefarmer/services/price_server.dart';

const _keepHistoryDays = 1100;

Future<void> main(List<String> args) async {
  final outDir = _arg(args, '--out') ?? 'build/price-data';
  final prevDir = _arg(args, '--previous');
  final summaryPath =
      _arg(args, '--summary') ?? Platform.environment['GITHUB_STEP_SUMMARY'];

  final now = DateTime.now().toUtc();
  final today = vnTodayKey(now);

  // ---- Dữ liệu lần trước ----
  ServerSnapshot? previous;
  if (prevDir != null) {
    final f = File('$prevDir/latest.json');
    if (f.existsSync()) previous = ServerSnapshot.tryParse(f.readAsStringSync());
  }

  // ---- Tải giá ----
  final fetcher = PriceFetcher(timeout: const Duration(seconds: 20));
  final rate = await fetcher.fetchUsdVndRate() ?? previous?.usdVnd;
  usdVndRate = rate;

  final fetched = await Future.wait(allCommodities.map(fetcher.fetchCommodity));
  fetcher.close();

  // ---- Ghép kết quả ----
  final items = <String, ServerItem>{};
  final health = <Map<String, dynamic>>[];
  var okCount = 0;

  for (final f in fetched) {
    final c = f.commodity;
    final history = _loadHistory(prevDir, c.id);

    if (f.ok) {
      okCount++;
      final s = summarizeRows(c, f.rows);
      items[c.id] = ServerItem(
        day: today,
        fetchedAt: now,
        source: f.sourceName,
        rows: f.rows,
        avgBuy: s.avgBuy,
        avgSell: s.avgSell,
        avgChange: s.avgChange,
      );
      final entries = historyEntriesFor(today, s,
          hasPreviousDay: history.containsKey(shiftDay(today, -1)));
      for (final e in entries) {
        // Dòng ước tính không được đè lên giá thật đã có
        if (e.estimated && history.containsKey(e.date)) continue;
        history[e.date] = e;
      }
    } else if (previous?.items[c.id] != null) {
      // Nguồn lỗi lần này: giữ giá cũ (app sẽ ghi rõ là giá ngày nào)
      items[c.id] = previous!.items[c.id]!;
    }

    _writeHistory(outDir, c.id, history);
    health.add({
      'id': c.id,
      'name': c.name,
      'ok': f.ok,
      'source': f.sourceName,
      'rows': f.rows.length,
      'lastGoodDay': items[c.id]?.day,
      'error': f.error,
      'attempts': f.attempts.map((a) => a.toJson()).toList(),
    });
  }

  // ---- Ghi file ----
  final snapshot =
      ServerSnapshot(generatedAt: now, usdVnd: rate, items: items);
  _write('$outDir/latest.json', jsonEncode(snapshot.toJson()));
  _write(
      '$outDir/health.json',
      const JsonEncoder.withIndent('  ').convert({
        'generatedAt': now.toIso8601String(),
        'day': today,
        'ok': okCount,
        'total': fetched.length,
        'usdVnd': rate,
        'commodities': health,
      }));
  _write('$outDir/README.md', _dataReadme);

  // ---- Báo cáo ----
  final report = _report(today, okCount, fetched);
  stdout.writeln(report);
  if (summaryPath != null && summaryPath.isNotEmpty) {
    File(summaryPath).writeAsStringSync(report, mode: FileMode.append);
  }

  exit(okCount == 0 ? 1 : 0);
}

String? _arg(List<String> args, String name) {
  final i = args.indexOf(name);
  return (i >= 0 && i + 1 < args.length) ? args[i + 1] : null;
}

Map<String, DaySummary> _loadHistory(String? prevDir, String id) {
  if (prevDir == null) return {};
  final f = File('$prevDir/history/$id.json');
  if (!f.existsSync()) return {};
  return {for (final d in parseHistoryJson(f.readAsStringSync())) d.date: d};
}

void _writeHistory(String outDir, String id, Map<String, DaySummary> history) {
  final keys = history.keys.toList()..sort();
  final keep = keys.length > _keepHistoryDays
      ? keys.sublist(keys.length - _keepHistoryDays)
      : keys;
  _write('$outDir/history/$id.json',
      jsonEncode(historyToJson(keep.map((k) => history[k]!))));
}

void _write(String path, String content) {
  final f = File(path);
  f.parent.createSync(recursive: true);
  f.writeAsStringSync(content);
}

String _report(String today, int okCount, List<FetchedCommodity> fetched) {
  final b = StringBuffer()
    ..writeln('## Giá ngày $today — $okCount/${fetched.length} mặt hàng OK')
    ..writeln()
    ..writeln('| Mặt hàng | Kết quả | Nguồn dùng | Nguồn lỗi trước đó |')
    ..writeln('|---|---|---|---|');
  for (final f in fetched) {
    final failed = f.attempts
        .where((a) => !a.ok)
        .map((a) => '${a.source} (${a.error})')
        .toSet()
        .join('<br>');
    b.writeln('| ${f.commodity.icon} ${f.commodity.name} '
        '| ${f.ok ? '✅ ${f.rows.length} dòng' : '❌ lỗi'} '
        '| ${f.sourceName ?? '—'} '
        '| ${failed.isEmpty ? '—' : failed} |');
  }
  return b.toString();
}

const _dataReadme = '''# Dữ liệu giá HeFarmer

Nhánh này do GitHub Actions (`.github/workflows/prices.yml`) tự sinh —
**đừng sửa tay**, lần chạy sau sẽ ghi đè.

- `latest.json` — giá mới nhất của mọi mặt hàng (ứng dụng tải file này)
- `history/<id>.json` — giá trung bình theo ngày
- `health.json` — tình trạng từng nguồn (nguồn nào đang hỏng)

Giá chỉ mang tính tham khảo, có thể chênh lệch với đại lý tại địa phương.
''';
