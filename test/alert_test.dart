import 'package:flutter_test/flutter_test.dart';
import 'package:hefarmer/services/alert_service.dart';
import 'package:hefarmer/services/price_service.dart';

CommodityResult _result(String id, List<DaySummary> days, {String? error}) =>
    CommodityResult(
      commodity: findCommodity(id)!,
      rows: const [],
      days: days,
      fetchedAt: DateTime(2026, 11, 8),
      error: error,
    );

const _alert = PriceAlert(
  commodityId: 'caphe',
  commodityName: 'Cà phê nhân xô',
  threshold: 100000,
  above: true,
);

void main() {
  const today = '2026-11-08';

  group('Cảnh báo giá chỉ dùng giá THẬT của hôm nay', () {
    test('giá hôm nay vượt mức -> báo', () {
      final hits = alertsToFire([_alert], [
        _result('caphe', [
          const DaySummary(date: '2026-11-07', avgBuy: 98000),
          const DaySummary(date: today, avgBuy: 101000),
        ]),
      ], today, {});
      expect(hits, hasLength(1));
      expect(hits.first.price, 101000);
    });

    test('mạng lỗi, chỉ còn giá CŨ đạt mức -> KHÔNG báo', () {
      final hits = alertsToFire([_alert], [
        _result('caphe', [const DaySummary(date: '2026-11-05', avgBuy: 105000)],
            error: 'Chưa lấy được giá mới'),
      ], today, {});
      expect(hits, isEmpty);
    });

    test('có dòng hôm nay nhưng kèm lỗi (giá dự phòng cũ) -> KHÔNG báo', () {
      final hits = alertsToFire([_alert], [
        _result('caphe', [const DaySummary(date: today, avgBuy: 105000)],
            error: 'Đang hiển thị giá ngày 05/11'),
      ], today, {});
      expect(hits, isEmpty);
    });

    test('giá ƯỚC TÍNH -> KHÔNG báo', () {
      final hits = alertsToFire([_alert], [
        _result('caphe',
            [const DaySummary(date: today, avgBuy: 105000, estimated: true)]),
      ], today, {});
      expect(hits, isEmpty);
    });

    test('đã báo hôm nay rồi -> không báo lại', () {
      final hits = alertsToFire([_alert], [
        _result('caphe', [const DaySummary(date: today, avgBuy: 105000)]),
      ], today, {'caphe': today});
      expect(hits, isEmpty);
    });

    test('báo khi XUỐNG DƯỚI mức', () {
      final down = _alert.copyWith(above: false, threshold: 90000);
      final hits = alertsToFire([down], [
        _result('caphe', [const DaySummary(date: today, avgBuy: 89000)]),
      ], today, {});
      expect(hits, hasLength(1));
    });

    test('cảnh báo đang tắt -> không báo', () {
      final off = _alert.copyWith(enabled: false);
      final hits = alertsToFire([off], [
        _result('caphe', [const DaySummary(date: today, avgBuy: 150000)]),
      ], today, {});
      expect(hits, isEmpty);
    });

    test('vật tư đầu vào (phân bón) cũng tìm được để cảnh báo', () {
      expect(findCommodity('phanbon'), isNotNull);
      expect(allCommodities.map((c) => c.id), contains('thucanchannuoi'));
    });
  });
}
