import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import 'price_service.dart';

/// CẢNH BÁO GIÁ
/// Bác đặt mức mong muốn (ví dụ "cà phê vượt 100.000đ thì báo tôi"), app tự
/// kiểm tra và BÁO RA MÀN HÌNH KHOÁ, không cần bác mở app.
///
/// Cơ chế 2 lớp:
///  1. Mỗi lần MỞ APP, app đối chiếu giá mới với các mức bác đã đặt và
///     bắn thông báo ngay nếu đạt.
///  2. CHẠY NỀN (Android WorkManager): khoảng 3 giờ một lần, khi có mạng,
///     app tự kiểm tra giá dù bác không mở app.
///
/// CHỈ báo theo giá THẬT của HÔM NAY: nếu hôm nay chưa tải được giá mới thì
/// không báo (tránh báo nhầm theo số của mấy hôm trước).

const _alertsKey = 'price_alerts_v1';
const _lastNotifyKey = 'alert_last_notify_v1';
const _legacyDailyReminderId = 9001; // lời nhắc hằng ngày của bản cũ
const _bgTaskName = 'hefarmer_kiem_tra_gia';

/// Một mức cảnh báo cho 1 mặt hàng
class PriceAlert {
  final String commodityId;
  final String commodityName;
  final int threshold; // mức giá đặt ra
  final bool above; // true = báo khi VƯỢT, false = báo khi XUỐNG DƯỚI
  final bool enabled;

  const PriceAlert({
    required this.commodityId,
    required this.commodityName,
    required this.threshold,
    required this.above,
    this.enabled = true,
  });

  Map<String, dynamic> toJson() => {
        'id': commodityId,
        'name': commodityName,
        'threshold': threshold,
        'above': above,
        'enabled': enabled,
      };

  factory PriceAlert.fromJson(Map<String, dynamic> j) => PriceAlert(
        commodityId: j['id'] as String,
        commodityName: j['name'] as String? ?? '',
        threshold: (j['threshold'] as num).toInt(),
        above: j['above'] as bool? ?? true,
        enabled: j['enabled'] as bool? ?? true,
      );

  PriceAlert copyWith({int? threshold, bool? above, bool? enabled}) =>
      PriceAlert(
        commodityId: commodityId,
        commodityName: commodityName,
        threshold: threshold ?? this.threshold,
        above: above ?? this.above,
        enabled: enabled ?? this.enabled,
      );
}

// ---------- Lưu / đọc danh sách cảnh báo ----------

Future<List<PriceAlert>> loadAlerts() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_alertsKey);
    if (raw == null) return [];
    return (jsonDecode(raw) as List)
        .map((e) => PriceAlert.fromJson(e as Map<String, dynamic>))
        .toList();
  } catch (_) {
    return [];
  }
}

Future<void> saveAlerts(List<PriceAlert> alerts) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(
      _alertsKey, jsonEncode(alerts.map((e) => e.toJson()).toList()));
}

Future<void> upsertAlert(PriceAlert alert) async {
  final list = await loadAlerts();
  final i = list.indexWhere((e) => e.commodityId == alert.commodityId);
  if (i >= 0) {
    list[i] = alert;
  } else {
    list.add(alert);
  }
  await saveAlerts(list);
}

Future<void> removeAlert(String commodityId) async {
  final list = await loadAlerts();
  list.removeWhere((e) => e.commodityId == commodityId);
  await saveAlerts(list);
}

// ---------- Thông báo ----------

final FlutterLocalNotificationsPlugin _notifier =
    FlutterLocalNotificationsPlugin();

/// [requestPermission] = false khi chạy nền (không có màn hình để hỏi quyền)
Future<void> initNotifications({bool requestPermission = true}) async {
  const android = AndroidInitializationSettings('@mipmap/ic_launcher');
  await _notifier.initialize(
    const InitializationSettings(android: android),
  );
  if (!requestPermission) return;
  // Android 13 trở lên phải xin phép hiện thông báo
  await _notifier
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.requestNotificationsPermission();
}

Future<void> _showNotification(String title, String body, int id) async {
  const details = NotificationDetails(
    android: AndroidNotificationDetails(
      'gia_nong_san',
      'Cảnh báo giá',
      channelDescription: 'Báo khi giá đạt mức bác đã đặt',
      importance: Importance.high,
      priority: Priority.high,
      styleInformation: BigTextStyleInformation(''),
    ),
  );
  await _notifier.show(id, title, body, details);
}

// ---------- Kiểm tra & bắn cảnh báo ----------

/// Một cảnh báo cần bắn
class AlertHit {
  final PriceAlert alert;
  final int price;
  final String unit;
  const AlertHit(this.alert, this.price, this.unit);
}

/// Thuần (test được): chọn ra các cảnh báo cần bắn.
///  - Chỉ xét giá THẬT của hôm nay [today] (bỏ giá cũ, giá ước tính).
///  - Mỗi mặt hàng chỉ báo 1 lần/ngày ([lastNotified]: id -> ngày đã báo).
List<AlertHit> alertsToFire(
  List<PriceAlert> alerts,
  List<CommodityResult> results,
  String today,
  Map<String, dynamic> lastNotified,
) {
  final hits = <AlertHit>[];
  for (final alert in alerts.where((a) => a.enabled)) {
    final r = results.where((e) => e.commodity.id == alert.commodityId);
    if (r.isEmpty) continue;
    final result = r.first;
    if (!result.isFreshFor(today)) continue;
    final price = result.latestDay!.avgBuy!;

    final hit =
        alert.above ? price >= alert.threshold : price <= alert.threshold;
    if (!hit) continue;
    if (lastNotified[alert.commodityId] == today) continue;
    hits.add(AlertHit(alert, price, result.commodity.unit));
  }
  return hits;
}

/// So giá hiện tại với các mức đã đặt. Trả về số cảnh báo đã bắn.
Future<int> checkAlertsAndNotify() async {
  final alerts = (await loadAlerts()).where((a) => a.enabled).toList();
  if (alerts.isEmpty) return 0;

  final ids = alerts.map((a) => a.commodityId).toSet();
  final needed = allCommodities.where((c) => ids.contains(c.id)).toList();
  if (needed.isEmpty) return 0;

  List<CommodityResult> results;
  try {
    results = await fetchAllPrices(needed);
  } catch (_) {
    return 0;
  }

  final prefs = await SharedPreferences.getInstance();
  final lastMap = jsonDecode(prefs.getString(_lastNotifyKey) ?? '{}')
      as Map<String, dynamic>;
  final today = todayKey();

  final hits = alertsToFire(alerts, results, today, lastMap);
  for (final h in hits) {
    final huong = h.alert.above ? 'đã VƯỢT' : 'đã XUỐNG DƯỚI';
    await _showNotification(
      '${h.alert.commodityName}: ${formatVnd(h.price)} ${h.unit}',
      'Giá $huong mức bác đặt (${formatVnd(h.alert.threshold)}). '
          'Mở ứng dụng để xem chi tiết.',
      h.alert.commodityId.hashCode & 0x7fffffff,
    );
    lastMap[h.alert.commodityId] = today;
  }

  await prefs.setString(_lastNotifyKey, jsonEncode(lastMap));
  return hits.length;
}

// ---------- Chạy nền ----------

/// Điểm vào khi Android đánh thức app chạy nền (không có giao diện).
@pragma('vm:entry-point')
void alertCallbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      await initNotifications(requestPermission: false);
      await checkAlertsAndNotify();
    } catch (e) {
      debugPrint('Kiểm tra giá chạy nền lỗi: $e');
    }
    // Luôn báo "xong": lỗi mạng thì lần sau (3 giờ nữa) thử lại
    return true;
  });
}

bool _workmanagerReady = false;

/// Bật/tắt việc kiểm tra giá chạy nền theo danh sách cảnh báo hiện có.
/// Gọi lại mỗi khi bác thêm/xoá cảnh báo.
Future<void> setupBackgroundCheck() async {
  try {
    // Bản cũ dùng lời nhắc hằng ngày thay cho chạy nền -> gỡ đi
    await _notifier.cancel(_legacyDailyReminderId);

    if (!_workmanagerReady) {
      await Workmanager().initialize(alertCallbackDispatcher);
      _workmanagerReady = true;
    }
    final alerts = await loadAlerts();
    if (alerts.where((a) => a.enabled).isEmpty) {
      await Workmanager().cancelByUniqueName(_bgTaskName);
      return;
    }
    await Workmanager().registerPeriodicTask(
      _bgTaskName,
      _bgTaskName,
      frequency: const Duration(hours: 3),
      constraints: Constraints(networkType: NetworkType.connected),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
    );
  } catch (e) {
    // máy không cho chạy nền -> vẫn còn kiểm tra mỗi lần mở app
    debugPrint('Không đặt được lịch chạy nền: $e');
  }
}
