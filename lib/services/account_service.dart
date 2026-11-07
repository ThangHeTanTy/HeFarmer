import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// DỊCH VỤ TÀI KHOẢN — lưu ngay trong máy (SharedPreferences), không cần
/// máy chủ: phù hợp app cá nhân cho người cao tuổi, mở app là dùng được,
/// không lo quên mật khẩu làm mất dữ liệu trên mạng.
/// Mật khẩu được băm SHA-256 kèm muối, không lưu dạng chữ thường.
///
/// Vị trí cư trú (homeLocation) do người dùng đặt trong tab Tài khoản sẽ
/// được tab Thời tiết ƯU TIÊN dùng thay cho GPS — rất hợp với người cao
/// tuổi không quen bật/chia sẻ vị trí.

const _accountsKey = 'accounts_v1';
const _sessionKey = 'session_user_v1';
const _homeLocationKey = 'home_location_v1';

/// Danh sách avatar có sẵn để người dùng chọn (chạm là đổi, không cần ảnh)
const avatarChoices = [
  '👨‍🌾', '👩‍🌾', '🧑‍🌾', '👴', '👵', '🧔',
  '🌱', '☕', '🌳', '⚫', '🐓', '🐖',
  '🐄', '🦆', '🥚', '🌾', '🚜', '⛅',
];

class Profile {
  final String username;
  final String name;
  final String avatar;
  const Profile({
    required this.username,
    required this.name,
    required this.avatar,
  });
}

class HomeLocation {
  final double latitude;
  final double longitude;
  final String label;
  const HomeLocation({
    required this.latitude,
    required this.longitude,
    required this.label,
  });
}

String _hash(String username, String password) {
  return sha256.convert(utf8.encode('nongdan|$username|$password')).toString();
}

Future<Map<String, dynamic>> _loadAccounts(SharedPreferences prefs) async {
  return jsonDecode(prefs.getString(_accountsKey) ?? '{}')
      as Map<String, dynamic>;
}

/// Đăng ký tài khoản mới. Trả về thông báo lỗi (tiếng Việt) hoặc null nếu OK.
Future<String?> register({
  required String name,
  required String username,
  required String password,
}) async {
  final u = username.trim().toLowerCase();
  final n = name.trim();
  if (n.isEmpty) return 'Bạn chưa nhập tên hiển thị.';
  if (u.length < 3) return 'Tên đăng nhập cần ít nhất 3 ký tự.';
  if (!RegExp(r'^[a-z0-9_.]+$').hasMatch(u)) {
    return 'Tên đăng nhập chỉ gồm chữ thường, số, dấu chấm hoặc gạch dưới.';
  }
  if (password.length < 4) return 'Mật khẩu cần ít nhất 4 ký tự.';

  final prefs = await SharedPreferences.getInstance();
  final accounts = await _loadAccounts(prefs);
  if (accounts.containsKey(u)) {
    return 'Tên đăng nhập này đã có người dùng, hãy chọn tên khác.';
  }
  accounts[u] = {
    'name': n,
    'hash': _hash(u, password),
    'avatar': avatarChoices.first,
    'home': null,
  };
  await prefs.setString(_accountsKey, jsonEncode(accounts));
  await prefs.setString(_sessionKey, u);
  return null;
}

/// Đăng nhập. Trả về thông báo lỗi hoặc null nếu OK.
Future<String?> login({
  required String username,
  required String password,
}) async {
  final u = username.trim().toLowerCase();
  final prefs = await SharedPreferences.getInstance();
  final accounts = await _loadAccounts(prefs);
  final acc = accounts[u] as Map<String, dynamic>?;
  if (acc == null || acc['hash'] != _hash(u, password)) {
    return 'Tên đăng nhập hoặc mật khẩu chưa đúng.';
  }
  await prefs.setString(_sessionKey, u);
  // Khôi phục vị trí cư trú đã lưu của tài khoản này
  final home = acc['home'];
  if (home != null) {
    await prefs.setString(_homeLocationKey, jsonEncode(home));
  }
  return null;
}

Future<void> logout() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(_sessionKey);
  // Giữ nguyên _homeLocationKey để tab thời tiết vẫn hoạt động sau đăng xuất
}

/// Hồ sơ của người đang đăng nhập, hoặc null nếu chưa đăng nhập.
Future<Profile?> currentProfile() async {
  final prefs = await SharedPreferences.getInstance();
  final u = prefs.getString(_sessionKey);
  if (u == null) return null;
  final accounts = await _loadAccounts(prefs);
  final acc = accounts[u] as Map<String, dynamic>?;
  if (acc == null) return null;
  return Profile(
    username: u,
    name: acc['name'] as String? ?? u,
    avatar: acc['avatar'] as String? ?? avatarChoices.first,
  );
}

Future<void> updateAvatar(String avatar) async {
  final prefs = await SharedPreferences.getInstance();
  final u = prefs.getString(_sessionKey);
  if (u == null) return;
  final accounts = await _loadAccounts(prefs);
  final acc = accounts[u] as Map<String, dynamic>?;
  if (acc == null) return;
  acc['avatar'] = avatar;
  await prefs.setString(_accountsKey, jsonEncode(accounts));
}

/// Đặt vị trí cư trú — tab Thời tiết sẽ ưu tiên vị trí này thay cho GPS.
Future<void> setHomeLocation(HomeLocation loc) async {
  final prefs = await SharedPreferences.getInstance();
  final data = {
    'latitude': loc.latitude,
    'longitude': loc.longitude,
    'label': loc.label,
  };
  await prefs.setString(_homeLocationKey, jsonEncode(data));
  // Lưu kèm vào tài khoản đang đăng nhập (để đăng nhập lại vẫn còn)
  final u = prefs.getString(_sessionKey);
  if (u != null) {
    final accounts = await _loadAccounts(prefs);
    final acc = accounts[u] as Map<String, dynamic>?;
    if (acc != null) {
      acc['home'] = data;
      await prefs.setString(_accountsKey, jsonEncode(accounts));
    }
  }
}

Future<void> clearHomeLocation() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(_homeLocationKey);
  final u = prefs.getString(_sessionKey);
  if (u != null) {
    final accounts = await _loadAccounts(prefs);
    final acc = accounts[u] as Map<String, dynamic>?;
    if (acc != null) {
      acc['home'] = null;
      await prefs.setString(_accountsKey, jsonEncode(accounts));
    }
  }
}

Future<HomeLocation?> getHomeLocation() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_homeLocationKey);
    if (raw == null) return null;
    final m = jsonDecode(raw) as Map<String, dynamic>;
    return HomeLocation(
      latitude: (m['latitude'] as num).toDouble(),
      longitude: (m['longitude'] as num).toDouble(),
      label: m['label'] as String? ?? 'Vị trí đã đặt',
    );
  } catch (_) {
    return null;
  }
}
