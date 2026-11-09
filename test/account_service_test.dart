import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hefarmer/services/account_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('Hồ sơ không mật khẩu', () {
    test('máy mới: hồ sơ trống, đặt tên và avatar được', () async {
      SharedPreferences.setMockInitialValues({});
      final p = await currentProfile();
      expect(p.hasName, isFalse);

      expect(await updateName('  Ông Ba  '), isNull);
      await updateAvatar('👴');
      final p2 = await currentProfile();
      expect(p2.name, 'Ông Ba');
      expect(p2.avatar, '👴');
    });

    test('chuyển tài khoản cũ sang hồ sơ và XOÁ mật khẩu băm', () async {
      SharedPreferences.setMockInitialValues({
        'accounts_v1': jsonEncode({
          'khac': {'name': 'Người khác', 'hash': 'x', 'avatar': '🐓'},
          'ongba': {
            'name': 'Ông Ba',
            'hash': 'abc123',
            'avatar': '☕',
            'home': {
              'latitude': 12.667,
              'longitude': 108.038,
              'label': 'Đắk Lắk',
            },
          },
        }),
        'session_user_v1': 'ongba',
      });

      final p = await currentProfile();
      expect(p.name, 'Ông Ba');
      expect(p.avatar, '☕');

      final home = await getHomeLocation();
      expect(home?.label, 'Đắk Lắk');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('accounts_v1'), isNull);
      expect(prefs.getString('session_user_v1'), isNull);
    });

    test('đã đăng xuất ở bản cũ thì lấy tài khoản đầu tiên', () async {
      SharedPreferences.setMockInitialValues({
        'accounts_v1': jsonEncode({
          'cotu': {'name': 'Cô Tư', 'hash': 'x', 'avatar': '👵'},
        }),
      });
      final p = await currentProfile();
      expect(p.name, 'Cô Tư');
    });

    test('tên quá dài bị từ chối', () async {
      SharedPreferences.setMockInitialValues({});
      expect(await updateName('a' * 41), isNotNull);
    });
  });
}
