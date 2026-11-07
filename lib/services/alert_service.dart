import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'price_service.dart';

/// CẢNH BÁO GIÁ
/// Bác đặt mức mong muốn (ví dụ "cà phê vượt 100.000đ thì báo tôi"), app tự
/// kiểm tra và BÁO RA MÀN HÌNH KHOÁ, không cần bác mở app.
///
/// Cơ chế 2 lớp:
///  1. Mỗi lần MỞ APP, app đối chiếu giá mới với các mức bác đã đặt và
///     bắn thông báo ngay nếu đạt.
///  2. NHẮC HẰNG NGÀY: app tự gửi lời nhắc buổi sáng để bác mở xem giá —
///     chạm vào lời nhắc là app kiểm tra và báo luôn nếu giá đã đạt mức.

const _alertsKey = 'price_alerts_v1';
const _lastNotifyKey = 'alert_last_notify_v1';
const _dailyReminderId = 9001;

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

Future<void> initNotifications() async {
  const android = AndroidInitializationSettings('@mipmap/ic_launcher');
  await _notifier.initialize(
    const InitializationSettings(android: android),
  );
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

/// So giá hiện tại với các mức đã đặt. Trả về số cảnh báo đã bắn.
/// Mỗi mặt hàng chỉ báo 1 lần/ngày để không làm phiền bà con.
Future<int> checkAlertsAndNotify({bool fromBackground = false}) async {
  final alerts = (await loadAlerts()).where((a) => a.enabled).toList();
  if (alerts.isEmpty) return 0;

  final prefs = await SharedPreferences.getInstance();
  final lastMap =
      jsonDecode(prefs.getString(_lastNotifyKey) ?? '{}') as Map<String, dynamic>;
  final today = todayKey();

  // Gom mặt hàng cần lấy giá theo từng nhóm
  final ids = alerts.map((a) => a.commodityId).toSet();
  final needed = [
    ...commodities,
    ...livestockCommodities,
    ...metalsCommodities,
  ].where((c) => ids.contains(c.id)).toList();
  if (needed.isEmpty) return 0;

  List<CommodityResult> results;
  try {
    results = await fetchAllPrices(needed);
  } catch (_) {
    return 0;
  }

  var fired = 0;
  for (final alert in alerts) {
    final r = results.where((e) => e.commodity.id == alert.commodityId);
    if (r.isEmpty) continue;
    final today0 = r.first.days.isNotEmpty ? r.first.days.last : null;
    final price = today0?.avgBuy;
    if (price == null) continue;

    final hit = alert.above ? price >= alert.threshold : price <= alert.threshold;
    if (!hit) continue;

    // đã báo hôm nay rồi thì thôi
    if (lastMap[alert.commodityId] == today) continue;

    final huong = alert.above ? 'đã VƯỢT' : 'đã XUỐNG DƯỚI';
    await _showNotification(
      '${alert.commodityName}: ${formatVnd(price)} ${r.first.commodity.unit}',
      'Giá $huong mức bác đặt (${formatVnd(alert.threshold)}). '
          'Mở ứng dụng để xem chi tiết.',
      alert.commodityId.hashCode & 0x7fffffff,
    );
    lastMap[alert.commodityId] = today;
    fired++;
  }

  await prefs.setString(_lastNotifyKey, jsonEncode(lastMap));
  return fired;
}

// ---------- Nhắc hằng ngày ----------

/// Đặt lời nhắc hằng ngày để bác nhớ mở app xem giá.
/// (Chạy nền thật sự cần thư viện workmanager, nhưng bản hiện tại của nó
/// KHÔNG build được với Flutter mới — dùng lời nhắc là cách chắc chắn nhất
/// mà vẫn không bỏ lỡ giá.)
Future<void> setupBackgroundCheck() async {
  try {
    final alerts = await loadAlerts();
    if (alerts.where((a) => a.enabled).isEmpty) {
      await _notifier.cancel(_dailyReminderId);
      return;
    }
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'nhac_xem_gia',
        'Nhắc xem giá hằng ngày',
        channelDescription: 'Nhắc mở ứng dụng để xem giá mới nhất',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      ),
    );
    await _notifier.periodicallyShow(
      _dailyReminderId,
      'Giá hôm nay đã cập nhật',
      'Bác mở ứng dụng xem giá nông sản và các mức cảnh báo đã đặt nhé.',
      RepeatInterval.daily,
      details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  } catch (_) {
    // máy không cho đặt lịch thông báo -> bỏ qua, app vẫn chạy bình thường
  }
}
