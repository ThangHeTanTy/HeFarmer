import 'package:flutter_test/flutter_test.dart';
import 'package:hefarmer/services/updater.dart';

Map<String, dynamic> _release({
  String tag = 'v1.3.0',
  String body = '- Chữ to hơn\n- Thêm giá gần nhà\n\n---\n\n## Cài lần đầu\n...',
  List<Map<String, dynamic>>? assets,
}) =>
    {
      'tag_name': tag,
      'body': body,
      'assets': assets ??
          [
            {
              'name': 'SHA256SUMS.txt',
              'browser_download_url': 'https://x/SHA256SUMS.txt',
              'size': 80,
            },
            {
              'name': 'HeFarmer.apk',
              'browser_download_url': 'https://x/HeFarmer.apk',
              'size': 25000000,
              'digest': 'sha256:abc123',
            },
          ],
    };

void main() {
  group('Số phiên bản', () {
    test('đọc thẻ v1.2.3 và 1.2.3; thẻ sai -> null', () {
      expect(Updater.parseVersion('v1.2.3'), [1, 2, 3]);
      expect(Updater.parseVersion(' 10.0.21 '), [10, 0, 21]);
      expect(Updater.parseVersion('v1.2'), isNull);
      expect(Updater.parseVersion('dev'), isNull);
      expect(Updater.parseVersion(''), isNull);
    });

    test('so sánh theo từng số, không theo chữ (1.10 > 1.9)', () {
      expect(Updater.isNewer([1, 10, 0], [1, 9, 9]), isTrue);
      expect(Updater.isNewer([2, 0, 0], [1, 99, 99]), isTrue);
      expect(Updater.isNewer([1, 2, 3], [1, 2, 3]), isFalse);
      expect(Updater.isNewer([1, 2, 2], [1, 2, 3]), isFalse);
    });
  });

  group('Đọc bản phát hành từ GitHub', () {
    test('lấy APK, dung lượng, SHA-256 và chỉ phần ghi chú trên dòng ---', () {
      final r = Release.fromJson(_release())!;
      expect(r.version, '1.3.0');
      expect(r.apkUrl, 'https://x/HeFarmer.apk');
      expect(r.apkSize, 25000000);
      expect(r.apkSha256, 'abc123');
      expect(r.notes, '- Chữ to hơn\n- Thêm giá gần nhà');
    });

    test('không có APK hoặc thẻ sai -> null', () {
      expect(Release.fromJson(_release(assets: [])), isNull);
      expect(Release.fromJson(_release(tag: 'ban-thu')), isNull);
    });

    test('GitHub chưa ghi SHA-256 -> bỏ qua bước kiểm', () {
      final r = Release.fromJson(_release(assets: [
        {'name': 'HeFarmer.apk', 'browser_download_url': 'u', 'size': 1},
      ]))!;
      expect(r.apkSha256, isEmpty);
    });
  });

  group('Nhắc cập nhật', () {
    final now = DateTime(2026, 11, 9, 8);

    test('bấm "Để sau" thì 3 ngày sau mới nhắc lại cùng bản đó', () {
      expect(Updater.isSnoozed('1.3.0|2026-11-09', '1.3.0', now), isTrue);
      expect(Updater.isSnoozed('1.3.0|2026-11-07', '1.3.0', now), isTrue);
      expect(Updater.isSnoozed('1.3.0|2026-11-06', '1.3.0', now), isFalse);
    });

    test('có bản mới hơn bản đã hoãn -> nhắc ngay', () {
      expect(Updater.isSnoozed('1.3.0|2026-11-09', '1.4.0', now), isFalse);
    });

    test('dữ liệu hoãn hỏng -> coi như chưa hoãn', () {
      expect(Updater.isSnoozed(null, '1.3.0', now), isFalse);
      expect(Updater.isSnoozed('rac', '1.3.0', now), isFalse);
    });

    test('bản tự build (không có số phiên bản) không tự nhắc', () async {
      expect(Updater.selfBuilt, isTrue);
      expect(await Updater.autoCheck(), isNull);
    });
  });
}
