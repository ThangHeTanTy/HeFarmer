import 'package:flutter_tts/flutter_tts.dart';

/// ĐỌC THÀNH TIẾNG (tiếng Việt)
/// Nhiều bác mắt kém, đọc dãy số dài rất mệt. Bấm nút loa 🔊 là app đọc
/// to giá hôm nay bằng tiếng Việt, đọc chậm hơn bình thường cho dễ nghe.

final FlutterTts _tts = FlutterTts();
bool _ready = false;

Future<void> _ensureReady() async {
  if (_ready) return;
  await _tts.setLanguage('vi-VN');
  await _tts.setSpeechRate(0.42); // chậm hơn mặc định cho người cao tuổi
  await _tts.setPitch(1.0);
  await _tts.setVolume(1.0);
  _ready = true;
}

Future<void> speak(String text) async {
  try {
    await _ensureReady();
    await _tts.stop();
    await _tts.speak(text);
  } catch (_) {
    // máy không có bộ đọc tiếng Việt -> bỏ qua, không làm app lỗi
  }
}

Future<void> stopSpeaking() async {
  try {
    await _tts.stop();
  } catch (_) {/* bỏ qua */}
}

/// Đổi số tiền sang cách ĐỌC tiếng Việt tự nhiên:
/// 94800 -> "chín mươi tư nghìn tám trăm đồng"
/// 151300000 -> "một trăm năm mươi mốt triệu ba trăm nghìn đồng"
String moneyToWords(int amount) {
  if (amount <= 0) return 'không đồng';
  final ty = amount ~/ 1000000000;
  final trieu = (amount % 1000000000) ~/ 1000000;
  final nghin = (amount % 1000000) ~/ 1000;
  final le = amount % 1000;

  final parts = <String>[];
  if (ty > 0) parts.add('${_threeDigits(ty)} tỷ');
  if (trieu > 0) parts.add('${_threeDigits(trieu)} triệu');
  if (nghin > 0) parts.add('${_threeDigits(nghin)} nghìn');
  if (le > 0) parts.add(_threeDigits(le));
  return '${parts.join(' ')} đồng';
}

const _digits = [
  'không', 'một', 'hai', 'ba', 'bốn',
  'năm', 'sáu', 'bảy', 'tám', 'chín',
];

/// Đọc số dưới 1000 theo đúng cách nói tiếng Việt (mốt, tư, lăm, lẻ...)
String _threeDigits(int n) {
  final tram = n ~/ 100;
  final chuc = (n % 100) ~/ 10;
  final donvi = n % 10;
  final out = <String>[];

  if (tram > 0) {
    out.add('${_digits[tram]} trăm');
    if (chuc == 0 && donvi > 0) out.add('lẻ');
  }
  if (chuc > 1) {
    out.add('${_digits[chuc]} mươi');
    if (donvi == 1) {
      out.add('mốt');
    } else if (donvi == 4) {
      out.add('tư');
    } else if (donvi == 5) {
      out.add('lăm');
    } else if (donvi > 0) {
      out.add(_digits[donvi]);
    }
  } else if (chuc == 1) {
    out.add('mười');
    if (donvi == 5) {
      out.add('lăm');
    } else if (donvi > 0) {
      out.add(_digits[donvi]);
    }
  } else if (donvi > 0 && tram == 0) {
    out.add(_digits[donvi]);
  } else if (donvi > 0) {
    out.add(_digits[donvi]);
  }
  return out.join(' ');
}

/// Đơn vị đọc sao cho tự nhiên: "một ký", "một lượng", "một quả"
String unitToWords(String unit) {
  if (unit.contains('quả')) return 'một quả';
  if (unit.contains('lượng')) return 'một lượng';
  if (unit.contains('TSC')) return 'một độ tê ét xê';
  return 'một ký';
}

/// Ghép câu đọc hoàn chỉnh cho một mặt hàng
String buildPriceSentence({
  required String name,
  required int? buy,
  int? sell,
  required String unit,
  int? change,
}) {
  if (buy == null) return 'Chưa có giá $name hôm nay.';
  final sb = StringBuffer();
  sb.write('$name hôm nay, giá mua ${moneyToWords(buy)} ${unitToWords(unit)}');
  if (sell != null) {
    sb.write(', giá bán ${moneyToWords(sell)} ${unitToWords(unit)}');
  }
  if (change != null && change != 0) {
    sb.write(change > 0
        ? ', tăng ${moneyToWords(change)} so với hôm trước'
        : ', giảm ${moneyToWords(-change)} so với hôm trước');
  }
  sb.write('.');
  return sb.toString();
}
