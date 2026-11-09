import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hefarmer/services/history_store.dart';
import 'package:hefarmer/services/price_catalog.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  late HistoryStore store;

  Future<HistoryStore> openStore({SharedPreferences? prefs}) async =>
      HistoryStore.open(databaseFactoryFfi, inMemoryDatabasePath,
          migrateFrom: prefs);

  tearDown(() async => store.close());

  group('Lịch sử giá trong SQLite', () {
    test('chuyển lịch sử cũ từ SharedPreferences rồi xoá bản cũ', () async {
      SharedPreferences.setMockInitialValues({
        'price_history_v2': jsonEncode({
          'caphe': {
            '2026-11-06': {'avgBuy': 97000, 'avgSell': null, 'estimated': true},
            '2026-11-07': {'avgBuy': 98000, 'avgSell': null},
          },
        }),
      });
      final prefs = await SharedPreferences.getInstance();
      store = await openStore(prefs: prefs);

      final days = await store.recent('caphe', 10);
      expect(days.map((d) => d.date), ['2026-11-06', '2026-11-07']);
      expect(days.first.estimated, isTrue);
      expect(prefs.getString('price_history_v2'), isNull);
    });

    test('giá ƯỚC TÍNH không đè giá thật; giá thật đè giá ước tính', () async {
      store = await openStore();
      await store.put('caphe',
          const DaySummary(date: '2026-11-07', avgBuy: 98000));
      await store.put('caphe',
          const DaySummary(date: '2026-11-07', avgBuy: 1, estimated: true));
      expect((await store.recent('caphe', 1)).single.avgBuy, 98000);

      await store.put('tieu',
          const DaySummary(date: '2026-11-07', avgBuy: 1, estimated: true));
      await store.put('tieu',
          const DaySummary(date: '2026-11-07', avgBuy: 150000));
      final t = (await store.recent('tieu', 1)).single;
      expect(t.avgBuy, 150000);
      expect(t.estimated, isFalse);
    });

    test('lịch sử máy chủ chỉ điền ngày thiếu hoặc đang ước tính', () async {
      store = await openStore();
      await store.put('caphe',
          const DaySummary(date: '2026-11-07', avgBuy: 98000));
      await store.put('caphe',
          const DaySummary(date: '2026-11-06', avgBuy: 1, estimated: true));
      await store.mergeFromServer('caphe', const [
        DaySummary(date: '2026-11-05', avgBuy: 96000),
        DaySummary(date: '2026-11-06', avgBuy: 97000),
        DaySummary(date: '2026-11-07', avgBuy: 11111),
      ]);
      final days = await store.recent('caphe', 10);
      expect(days.map((d) => d.avgBuy), [96000, 97000, 98000]);
    });

    test('recent trả về N ngày gần nhất, cũ -> mới; has() đúng', () async {
      store = await openStore();
      for (var i = 1; i <= 9; i++) {
        await store.put('ngo',
            DaySummary(date: '2026-11-0$i', avgBuy: 6000 + i));
      }
      final last3 = await store.recent('ngo', 3);
      expect(last3.map((d) => d.date),
          ['2026-11-07', '2026-11-08', '2026-11-09']);
      expect(await store.has('ngo', '2026-11-01'), isTrue);
      expect(await store.has('ngo', '2026-10-31'), isFalse);
    });

    test('prune giữ đúng số ngày gần nhất cho từng mặt hàng', () async {
      store = await openStore();
      for (var i = 1; i <= 9; i++) {
        await store.put('ngo', DaySummary(date: '2026-11-0$i', avgBuy: i));
        await store.put('san', DaySummary(date: '2026-10-0$i', avgBuy: i));
      }
      await store.prune(keepDays: 4);
      expect((await store.recent('ngo', 100)).map((d) => d.date),
          ['2026-11-06', '2026-11-07', '2026-11-08', '2026-11-09']);
      expect(await store.recent('san', 100), hasLength(4));
    });
  });
}
