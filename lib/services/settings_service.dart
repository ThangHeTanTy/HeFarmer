import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// CÀI ĐẶT HIỂN THỊ cho người cao tuổi — lưu trong máy, đổi là app cập nhật
/// ngay (không cần khởi động lại).
///
///  - Cỡ chữ: Vừa / To / Rất to (nhân thêm vào cỡ chữ của điện thoại).
///  - Chế độ đơn giản: chỉ còn 3 tab "Giá của tôi", "Thời tiết", "Tôi";
///    tab "Giá của tôi" chỉ hiện những mặt hàng bác tự chọn.

const _textScaleKey = 'text_scale_v1';
const _simpleModeKey = 'simple_mode_v1';
const _myCommoditiesKey = 'my_commodities_v1';

/// Các mức cỡ chữ cho bác chọn
const textScaleChoices = <(String, double)>[
  ('Vừa', 1.0),
  ('To', 1.15),
  ('Rất to', 1.3),
];

/// Cỡ chữ tối đa khi app phóng thêm (để bố cục không vỡ)
const maxTextScale = 1.6;

@immutable
class AppSettings {
  final double textScale;
  final bool simpleMode;
  final List<String> myCommodities; // id mặt hàng, theo thứ tự bác chọn

  const AppSettings({
    this.textScale = 1.0,
    this.simpleMode = false,
    this.myCommodities = const [],
  });

  AppSettings copyWith({
    double? textScale,
    bool? simpleMode,
    List<String>? myCommodities,
  }) =>
      AppSettings(
        textScale: textScale ?? this.textScale,
        simpleMode: simpleMode ?? this.simpleMode,
        myCommodities: myCommodities ?? this.myCommodities,
      );
}

/// Cài đặt hiện tại — giao diện lắng nghe biến này để tự vẽ lại
final appSettings = ValueNotifier<AppSettings>(const AppSettings());

/// Cỡ chữ thực tế = cỡ của điện thoại × cỡ trong app. Phần app phóng thêm
/// không vượt [maxTextScale], nhưng KHÔNG BAO GIỜ nhỏ hơn cỡ bác đã đặt
/// trong Cài đặt của điện thoại.
double effectiveTextScale(double system, double app) {
  final v = system * app;
  if (v <= maxTextScale) return v;
  return system > maxTextScale ? system : maxTextScale;
}

/// Đọc cài đặt đã lưu (gọi 1 lần lúc mở app)
Future<void> loadSettings() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final scale = prefs.getDouble(_textScaleKey) ?? 1.0;
    appSettings.value = AppSettings(
      // chỉ nhận các mức có trong danh sách (phòng dữ liệu hỏng)
      textScale: textScaleChoices.any((c) => c.$2 == scale) ? scale : 1.0,
      simpleMode: prefs.getBool(_simpleModeKey) ?? false,
      myCommodities: prefs.getStringList(_myCommoditiesKey) ?? const [],
    );
  } catch (_) {
    // giữ mặc định
  }
}

Future<void> setTextScale(double scale) async {
  appSettings.value = appSettings.value.copyWith(textScale: scale);
  final prefs = await SharedPreferences.getInstance();
  await prefs.setDouble(_textScaleKey, scale);
}

Future<void> setSimpleMode(bool on) async {
  appSettings.value = appSettings.value.copyWith(simpleMode: on);
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_simpleModeKey, on);
}

Future<void> setMyCommodities(List<String> ids) async {
  appSettings.value = appSettings.value.copyWith(myCommodities: List.of(ids));
  final prefs = await SharedPreferences.getInstance();
  await prefs.setStringList(_myCommoditiesKey, ids);
}
