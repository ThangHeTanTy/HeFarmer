import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hefarmer/services/price_fetcher.dart';
import 'package:hefarmer/services/price_server.dart';
import 'package:hefarmer/services/price_service.dart';
import 'package:hefarmer/services/price_parser.dart';

ServerItem _item(String day, {int buy = 98000}) => ServerItem(
      day: day,
      fetchedAt: DateTime.utc(2026, 11, 8, 2),
      source: 'giacaphe.com',
      rows: [PriceRow(region: 'Đắk Lắk', buy: buy, change: 500)],
      avgBuy: buy,
      avgChange: 500,
    );

void main() {
  const today = '2026-11-08';
  final coffee = findCommodity('caphe')!;

  group('Định dạng dữ liệu máy chủ', () {
    test('latest.json ghi ra rồi đọc lại đúng', () {
      final snap = ServerSnapshot(
        generatedAt: DateTime.utc(2026, 11, 8, 2),
        usdVnd: 26300,
        items: {'caphe': _item(today)},
      );
      final back = ServerSnapshot.tryParse(jsonEncode(snap.toJson()))!;
      expect(back.usdVnd, 26300);
      expect(back.items['caphe']!.day, today);
      expect(back.items['caphe']!.rows.single.region, 'Đắk Lắk');
      expect(back.items['caphe']!.avgChange, 500);
    });

    test('sai phiên bản hoặc JSON hỏng -> null (app tự tải như cũ)', () {
      expect(ServerSnapshot.tryParse('{"schema": 999, "items": {}}'), isNull);
      expect(ServerSnapshot.tryParse('<html>404</html>'), isNull);
    });

    test('một mặt hàng hỏng không làm hỏng cả file', () {
      final j = {
        'schema': priceSnapshotSchema,
        'generatedAt': '2026-11-08T02:00:00Z',
        'items': {
          'caphe': _item(today).toJson(),
          'hotieu': {'day': 'thiếu dữ liệu'},
        },
      };
      final s = ServerSnapshot.tryParse(jsonEncode(j))!;
      expect(s.items.keys, ['caphe']);
    });

    test('lịch sử: ghi/đọc, bỏ khoá rác, xếp cũ -> mới', () {
      final text = jsonEncode({
        ...historyToJson(const [
          DaySummary(date: '2026-11-07', avgBuy: 98000),
          DaySummary(date: '2026-11-06', avgBuy: 97000, estimated: true),
        ]),
        'rac': 1,
      });
      final days = parseHistoryJson(text);
      expect(days.map((d) => d.date), ['2026-11-06', '2026-11-07']);
      expect(days.first.estimated, isTrue);
      expect(parseHistoryJson('không phải json'), isEmpty);
    });

    test('ngày theo giờ Việt Nam: 20h UTC đã là sáng hôm sau ở VN', () {
      expect(vnTodayKey(DateTime.utc(2026, 11, 7, 20)), '2026-11-08');
      expect(vnTodayKey(DateTime.utc(2026, 11, 7, 16, 59)), '2026-11-07');
    });
  });

  group('Chọn nguồn giá', () {
    test('máy chủ có giá hôm nay -> dùng máy chủ, không cần tự tải', () {
      expect(serverHasToday(_item(today), today), isTrue);
      final c = choosePrice(
          commodity: coffee, server: _item(today), direct: null, today: today);
      expect(c.day, today);
      expect(c.error, isNull);
      expect(c.summary!.avgBuy, 98000);
    });

    test('máy chủ chỉ có giá cũ, tự tải được -> dùng giá tự tải', () {
      final direct = FetchedCommodity(
        commodity: coffee,
        rows: const [PriceRow(region: 'Lâm Đồng', buy: 99000)],
        sourceName: 'webgia.com',
        attempts: const [],
      );
      final c = choosePrice(
          commodity: coffee,
          server: _item('2026-11-05'),
          direct: direct,
          today: today);
      expect(c.day, today);
      expect(c.sourceName, 'webgia.com');
      expect(c.summary!.avgBuy, 99000);
    });

    test('tự tải lỗi -> dùng giá cũ của máy chủ và GHI RÕ ngày', () {
      final failed = FetchedCommodity(
          commodity: coffee, rows: const [], attempts: const [], error: 'HTTP 503');
      final c = choosePrice(
          commodity: coffee,
          server: _item('2026-11-05'),
          direct: failed,
          today: today);
      expect(c.day, '2026-11-05');
      expect(c.error, contains('05/11'));
    });

    test('không có gì cả -> báo lỗi, không có ngày', () {
      final failed = FetchedCommodity(
          commodity: coffee, rows: const [], attempts: const [], error: 'HTTP 503');
      final c = choosePrice(
          commodity: coffee, server: null, direct: failed, today: today);
      expect(c.day, isNull);
      expect(c.error, contains('HTTP 503'));
    });
  });

  group('Ghi lịch sử sau khi có giá', () {
    test('chưa có hôm qua mà biết mức tăng -> ước tính hôm qua', () {
      final e = historyEntriesFor(
          today, const PriceSummary(avgBuy: 98000, avgChange: 500),
          hasPreviousDay: false);
      expect(e, hasLength(2));
      expect(e[1].date, '2026-11-07');
      expect(e[1].avgBuy, 97500);
      expect(e[1].estimated, isTrue);
    });

    test('đã có hôm qua -> chỉ ghi hôm nay', () {
      final e = historyEntriesFor(
          today, const PriceSummary(avgBuy: 98000, avgChange: 500),
          hasPreviousDay: true);
      expect(e.single.date, today);
    });
  });
}
