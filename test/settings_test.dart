import 'package:flutter_test/flutter_test.dart';
import 'package:hefarmer/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => appSettings.value = const AppSettings());

  test('mặc định: cỡ chữ Vừa, chế độ đầy đủ, chưa chọn mặt hàng', () async {
    SharedPreferences.setMockInitialValues({});
    await loadSettings();
    expect(appSettings.value.textScale, 1.0);
    expect(appSettings.value.simpleMode, isFalse);
    expect(appSettings.value.myCommodities, isEmpty);
  });

  test('lưu rồi mở lại app vẫn giữ cài đặt, giữ đúng thứ tự mặt hàng',
      () async {
    SharedPreferences.setMockInitialValues({});
    await setTextScale(1.3);
    await setSimpleMode(true);
    await setMyCommodities(['heohoi', 'caphe']);

    appSettings.value = const AppSettings(); // như vừa mở lại app
    await loadSettings();
    expect(appSettings.value.textScale, 1.3);
    expect(appSettings.value.simpleMode, isTrue);
    expect(appSettings.value.myCommodities, ['heohoi', 'caphe']);
  });

  test('cỡ chữ lạ (dữ liệu hỏng) thì quay về Vừa', () async {
    SharedPreferences.setMockInitialValues({'text_scale_v1': 7.0});
    await loadSettings();
    expect(appSettings.value.textScale, 1.0);
  });

  test('đổi cài đặt báo ngay cho giao diện', () async {
    SharedPreferences.setMockInitialValues({});
    var notified = 0;
    void listener() => notified++;
    appSettings.addListener(listener);
    await setTextScale(1.15);
    appSettings.removeListener(listener);
    expect(notified, 1);
  });

  test('cỡ chữ điện thoại × cỡ trong app không vượt mức tối đa', () {
    expect(effectiveTextScale(1.0, 1.3), 1.3);
    expect(effectiveTextScale(1.3, 1.3), maxTextScale);
  });

  test('không bao giờ làm chữ NHỎ hơn cỡ đã đặt trong điện thoại', () {
    expect(effectiveTextScale(2.0, 1.0), 2.0);
    expect(effectiveTextScale(2.0, 1.3), 2.0);
  });
}
