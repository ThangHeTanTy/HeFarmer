import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import 'price_catalog.dart';

/// LỊCH SỬ GIÁ — lưu trong cơ sở dữ liệu SQLite trên máy.
///
/// Trước đây lịch sử nằm chung trong 1 chuỗi JSON của SharedPreferences:
/// mỗi lần ghi phải đọc–sửa–ghi lại toàn bộ, và khi 2 tab cùng tải giá một
/// lúc thì tab ghi sau có thể đè mất dữ liệu của tab trước. SQLite ghi từng
/// dòng nên không còn lỗi đó, và chứa được lịch sử nhiều năm (tải từ máy chủ)
/// mà không làm chậm lúc mở app.

const _legacyPrefsKey = 'price_history_v2';
const _table = 'price_history';

/// Giữ tối đa chừng này ngày cho mỗi mặt hàng (~3 năm)
const historyKeepDays = 1100;

class HistoryStore {
  final Future<Database> _db;
  HistoryStore._(this._db) {
    // Mở CSDL lỗi (hiếm) thì để từng lệnh đọc/ghi tự bắt lỗi — không để lỗi
    // nổ ra ngoài trước khi có ai kịp chờ.
    _db.ignore();
  }

  /// Kho dùng chung của app (mở 1 lần, dùng mãi)
  static HistoryStore? _instance;
  static HistoryStore get instance =>
      _instance ??= HistoryStore._(_openDefault());

  /// Dùng trong test: truyền factory (sqflite_common_ffi) + đường dẫn riêng
  static HistoryStore open(DatabaseFactory factory, String path,
          {SharedPreferences? migrateFrom}) =>
      HistoryStore._(_open(factory, path, migrateFrom));

  static Future<Database> _openDefault() async {
    final dir = await getDatabasesPath();
    final prefs = await SharedPreferences.getInstance();
    return _open(databaseFactory, p.join(dir, 'hefarmer.db'), prefs);
  }

  static Future<Database> _open(
      DatabaseFactory factory, String path, SharedPreferences? prefs) async {
    final db = await factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, _) async {
          await db.execute('''
            CREATE TABLE $_table (
              commodity_id TEXT NOT NULL,
              day TEXT NOT NULL,
              avg_buy INTEGER,
              avg_sell INTEGER,
              estimated INTEGER NOT NULL DEFAULT 0,
              PRIMARY KEY (commodity_id, day)
            )''');
        },
      ),
    );
    if (prefs != null) await _migrateFromPrefs(db, prefs);
    return db;
  }

  /// Chuyển lịch sử cũ (JSON trong SharedPreferences) vào SQLite, 1 lần.
  static Future<void> _migrateFromPrefs(
      Database db, SharedPreferences prefs) async {
    final raw = prefs.getString(_legacyPrefsKey);
    if (raw == null) return;
    try {
      final history = jsonDecode(raw) as Map<String, dynamic>;
      final batch = db.batch();
      for (final id in history.keys) {
        final store = history[id] as Map<String, dynamic>;
        for (final day in store.keys) {
          final e = store[day] as Map<String, dynamic>;
          batch.insert(
            _table,
            {
              'commodity_id': id,
              'day': day,
              'avg_buy': (e['avgBuy'] as num?)?.toInt(),
              'avg_sell': (e['avgSell'] as num?)?.toInt(),
              'estimated': (e['estimated'] as bool? ?? false) ? 1 : 0,
            },
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );
        }
      }
      await batch.commit(noResult: true);
    } catch (_) {
      // dữ liệu cũ hỏng -> bỏ qua
    }
    await prefs.remove(_legacyPrefsKey);
  }

  Future<void> close() async => (await _db).close();

  /// Ghi giá của 1 ngày. Dòng ƯỚC TÍNH không bao giờ đè lên giá thật.
  Future<void> put(String commodityId, DaySummary d) async {
    final db = await _db;
    await _put(db, commodityId, d);
  }

  static Future<void> _put(
      DatabaseExecutor db, String commodityId, DaySummary d) async {
    final values = {
      'commodity_id': commodityId,
      'day': d.date,
      'avg_buy': d.avgBuy,
      'avg_sell': d.avgSell,
      'estimated': d.estimated ? 1 : 0,
    };
    if (d.estimated) {
      await db.insert(_table, values,
          conflictAlgorithm: ConflictAlgorithm.ignore);
    } else {
      await db.insert(_table, values,
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  /// Gộp lịch sử tải từ máy chủ: chỉ điền ngày còn THIẾU hoặc đang là số
  /// ƯỚC TÍNH; giá thật app đã tự ghi thì giữ nguyên.
  Future<void> mergeFromServer(
      String commodityId, Iterable<DaySummary> days) async {
    final db = await _db;
    await db.transaction((txn) async {
      for (final d in days) {
        if (d.avgBuy == null && d.avgSell == null) continue;
        final existing = await txn.query(_table,
            columns: ['estimated'],
            where: 'commodity_id = ? AND day = ?',
            whereArgs: [commodityId, d.date]);
        if (existing.isNotEmpty && existing.first['estimated'] == 0) continue;
        await txn.insert(
          _table,
          {
            'commodity_id': commodityId,
            'day': d.date,
            'avg_buy': d.avgBuy,
            'avg_sell': d.avgSell,
            'estimated': d.estimated ? 1 : 0,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  Future<bool> has(String commodityId, String day) async {
    final db = await _db;
    final r = await db.query(_table,
        columns: ['day'],
        where: 'commodity_id = ? AND day = ?',
        whereArgs: [commodityId, day],
        limit: 1);
    return r.isNotEmpty;
  }

  /// [limit] ngày gần nhất, xếp CŨ -> MỚI
  Future<List<DaySummary>> recent(String commodityId, int limit) async {
    final db = await _db;
    final rows = await db.query(_table,
        where: 'commodity_id = ?',
        whereArgs: [commodityId],
        orderBy: 'day DESC',
        limit: limit);
    return rows.reversed
        .map((r) => DaySummary(
              date: r['day'] as String,
              avgBuy: r['avg_buy'] as int?,
              avgSell: r['avg_sell'] as int?,
              estimated: (r['estimated'] as int? ?? 0) == 1,
            ))
        .toList();
  }

  /// Bỏ các ngày quá cũ (giữ [keepDays] ngày gần nhất mỗi mặt hàng)
  Future<void> prune({int keepDays = historyKeepDays}) async {
    // Không dùng hàm cửa sổ (ROW_NUMBER) vì SQLite trên Android cũ chưa có.
    final db = await _db;
    final ids = await db.rawQuery('SELECT DISTINCT commodity_id FROM $_table');
    for (final r in ids) {
      final id = r['commodity_id'] as String;
      await db.rawDelete('''
        DELETE FROM $_table WHERE commodity_id = ? AND day < (
          SELECT day FROM $_table WHERE commodity_id = ?
          ORDER BY day DESC LIMIT 1 OFFSET ?)''', [id, id, keepDays - 1]);
    }
  }
}
