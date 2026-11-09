import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// HỒ SƠ NGƯỜI DÙNG — lưu ngay trong máy, KHÔNG cần mật khẩu.
///
/// Trước đây app có đăng ký/đăng nhập với mật khẩu, nhưng mọi dữ liệu đều
/// nằm trong máy nên mật khẩu không bảo vệ thêm được gì, lại làm khó người
/// cao tuổi (quên mật khẩu là coi như mất hồ sơ). Nay chỉ còn hồ sơ gồm
/// tên để chào, ảnh đại diện và "Vị trí của tôi".
///
/// Vị trí cư trú (homeLocation) được tab Thời tiết ƯU TIÊN dùng thay cho GPS
/// và tab Giá dùng để chọn ra giá ở vùng gần nhà nhất.

const _profileKey = 'profile_v2';
const _homeLocationKey = 'home_location_v1';

// Khoá của phiên bản cũ (có mật khẩu) — chỉ dùng để chuyển dữ liệu một lần
const _legacyAccountsKey = 'accounts_v1';
const _legacySessionKey = 'session_user_v1';

/// Danh sách avatar có sẵn để người dùng chọn (chạm là đổi, không cần ảnh)
const avatarChoices = [
  '👨‍🌾', '👩‍🌾', '🧑‍🌾', '👴', '👵', '🧔',
  '🌱', '☕', '🌳', '⚫', '🐓', '🐖',
  '🐄', '🦆', '🥚', '🌾', '🚜', '⛅',
];

class Profile {
  final String name; // rỗng = chưa đặt tên
  final String avatar;
  const Profile({required this.name, required this.avatar});

  bool get hasName => name.trim().isNotEmpty;

  Map<String, dynamic> toJson() => {'name': name, 'avatar': avatar};

  factory Profile.fromJson(Map<String, dynamic> j) => Profile(
        name: j['name'] as String? ?? '',
        avatar: j['avatar'] as String? ?? avatarChoices.first,
      );
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

  Map<String, dynamic> toJson() =>
      {'latitude': latitude, 'longitude': longitude, 'label': label};
}

/// Chuyển hồ sơ từ bản cũ (có tài khoản + mật khẩu) sang hồ sơ mới, rồi XOÁ
/// hẳn dữ liệu mật khẩu băm cũ khỏi máy. Chạy nhiều lần cũng không sao.
Future<void> _migrateLegacyAccounts(SharedPreferences prefs) async {
  final raw = prefs.getString(_legacyAccountsKey);
  if (raw == null) return;
  try {
    if (prefs.getString(_profileKey) == null) {
      final accounts = jsonDecode(raw) as Map<String, dynamic>;
      // Ưu tiên tài khoản đang đăng nhập, không có thì lấy tài khoản đầu tiên
      final session = prefs.getString(_legacySessionKey);
      final key = (session != null && accounts.containsKey(session))
          ? session
          : (accounts.keys.isNotEmpty ? accounts.keys.first : null);
      final acc = key == null ? null : accounts[key] as Map<String, dynamic>?;
      if (acc != null) {
        final profile = Profile(
          name: acc['name'] as String? ?? '',
          avatar: acc['avatar'] as String? ?? avatarChoices.first,
        );
        await prefs.setString(_profileKey, jsonEncode(profile.toJson()));
        final home = acc['home'];
        if (home != null && prefs.getString(_homeLocationKey) == null) {
          await prefs.setString(_homeLocationKey, jsonEncode(home));
        }
      }
    }
  } catch (_) {
    // dữ liệu cũ hỏng -> bỏ qua, bắt đầu hồ sơ mới
  }
  await prefs.remove(_legacyAccountsKey);
  await prefs.remove(_legacySessionKey);
}

/// Hồ sơ hiện tại. Luôn trả về một hồ sơ (chưa đặt tên thì tên rỗng).
Future<Profile> currentProfile() async {
  final prefs = await SharedPreferences.getInstance();
  await _migrateLegacyAccounts(prefs);
  final raw = prefs.getString(_profileKey);
  if (raw == null) return const Profile(name: '', avatar: '👨‍🌾');
  try {
    return Profile.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  } catch (_) {
    return const Profile(name: '', avatar: '👨‍🌾');
  }
}

Future<void> _saveProfile(Profile p) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_profileKey, jsonEncode(p.toJson()));
}

/// Đổi tên để app chào. Trả về thông báo lỗi hoặc null nếu OK.
Future<String?> updateName(String name) async {
  final n = name.trim();
  if (n.length > 40) return 'Tên dài quá, bác nhập ngắn lại nhé.';
  final p = await currentProfile();
  await _saveProfile(Profile(name: n, avatar: p.avatar));
  return null;
}

Future<void> updateAvatar(String avatar) async {
  final p = await currentProfile();
  await _saveProfile(Profile(name: p.name, avatar: avatar));
}

/// Đặt vị trí cư trú — tab Thời tiết sẽ ưu tiên vị trí này thay cho GPS.
Future<void> setHomeLocation(HomeLocation loc) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_homeLocationKey, jsonEncode(loc.toJson()));
}

Future<void> clearHomeLocation() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(_homeLocationKey);
}

Future<HomeLocation?> getHomeLocation() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await _migrateLegacyAccounts(prefs);
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
