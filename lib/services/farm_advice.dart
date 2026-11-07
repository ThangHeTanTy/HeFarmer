import 'weather_service.dart';

/// GỢI Ý VIỆC NHÀ NÔNG THEO THỜI TIẾT
/// Dịch các con số dự báo (mưa, gió, nắng, độ ẩm) sang lời khuyên công việc
/// cụ thể mà bà con dùng được ngay: có nên phơi nông sản, phun thuốc, bón
/// phân, thu hoạch hay không.
///
/// Thuần Dart, không phụ thuộc giao diện -> chạy unit test được.

enum AdviceLevel { good, warn, danger, info }

class FarmAdvice {
  final String icon;
  final String title;
  final String detail;
  final AdviceLevel level;
  const FarmAdvice({
    required this.icon,
    required this.title,
    required this.detail,
    required this.level,
  });
}

/// Ngưỡng dùng chung (theo kinh nghiệm khuyến nông phổ thông)
const _rainHigh = 60; // % khả năng mưa coi là cao
const _rainLow = 20; // % coi là trời ráo
const _windStrong = 25; // km/h — phun thuốc bị bay, không hiệu quả
const _windVeryStrong = 40; // km/h — nguy hiểm, gãy đổ
const _hotTemp = 35; // °C — nắng gắt
const _humidHigh = 85; // % — ẩm cao, dễ nấm bệnh

/// Sinh danh sách lời khuyên từ dữ liệu thời tiết hiện tại + dự báo vài ngày
List<FarmAdvice> buildFarmAdvice(WeatherData w) {
  final list = <FarmAdvice>[];
  final rain = w.rainProbability ?? 0;
  final wind = w.windSpeed;
  final temp = w.temperature;
  final humidity = w.humidity;

  // ----- Phơi nông sản -----
  if (rain >= _rainHigh) {
    list.add(FarmAdvice(
      icon: '🌾',
      title: 'Không nên phơi nông sản hôm nay',
      detail:
          'Khả năng mưa $rain%. Nếu đang phơi cà phê, lúa, tiêu... bác nên '
          'thu gom và che bạt sớm.',
      level: AdviceLevel.danger,
    ));
  } else if (rain <= _rainLow && temp >= 27) {
    list.add(FarmAdvice(
      icon: '☀️',
      title: 'Trời thuận lợi để phơi nông sản',
      detail: 'Khả năng mưa chỉ $rain%, nhiệt độ $temp°C. Tranh thủ phơi và '
          'trở đều cho khô nhanh.',
      level: AdviceLevel.good,
    ));
  }

  // ----- Phun thuốc -----
  if (wind >= _windStrong) {
    list.add(FarmAdvice(
      icon: '🌬️',
      title: 'Hoãn phun thuốc — gió mạnh',
      detail: 'Gió $wind km/h làm thuốc bay mất, vừa phí vừa hại sức khoẻ. '
          'Chờ lúc gió lặng, sáng sớm hoặc chiều mát.',
      level: AdviceLevel.warn,
    ));
  } else if (rain >= _rainHigh) {
    list.add(const FarmAdvice(
      icon: '💊',
      title: 'Hoãn phun thuốc — sắp mưa',
      detail: 'Mưa sẽ rửa trôi thuốc, phun lúc này coi như bỏ đi.',
      level: AdviceLevel.warn,
    ));
  } else if (rain <= _rainLow && wind < _windStrong) {
    list.add(const FarmAdvice(
      icon: '💊',
      title: 'Thời tiết hợp để phun thuốc',
      detail: 'Ít mưa, gió nhẹ. Nên phun sáng sớm hoặc chiều mát, tránh giờ '
          'nắng gắt giữa trưa.',
      level: AdviceLevel.good,
    ));
  }

  // ----- Bón phân -----
  if (rain >= 40 && rain < 80) {
    list.add(FarmAdvice(
      icon: '🌱',
      title: 'Thuận lợi bón phân',
      detail: 'Có mưa nhẹ ($rain%) giúp phân tan và ngấm vào đất, đỡ công '
          'tưới.',
      level: AdviceLevel.good,
    ));
  } else if (rain >= 80) {
    list.add(const FarmAdvice(
      icon: '🌱',
      title: 'Chưa nên bón phân',
      detail: 'Mưa to dễ rửa trôi phân, vừa mất tiền vừa không hiệu quả.',
      level: AdviceLevel.warn,
    ));
  }

  // ----- Nắng gắt / tưới nước -----
  if (temp >= _hotTemp) {
    list.add(FarmAdvice(
      icon: '🥵',
      title: 'Nắng gắt $temp°C — chú ý sức khoẻ',
      detail: 'Bác tránh làm đồng từ 11h đến 14h, nhớ uống đủ nước và đội nón. '
          'Cây cần tưới thêm vào sáng sớm hoặc chiều tối.',
      level: AdviceLevel.warn,
    ));
  }

  // ----- Gió rất mạnh -----
  if (wind >= _windVeryStrong) {
    list.add(FarmAdvice(
      icon: '⚠️',
      title: 'Gió rất mạnh $wind km/h',
      detail: 'Kiểm tra chằng chống cây non, giàn tiêu, mái chuồng trại. '
          'Hạn chế trèo cao.',
      level: AdviceLevel.danger,
    ));
  }

  // ----- Ẩm cao — nấm bệnh -----
  if (humidity >= _humidHigh && rain >= 40) {
    list.add(FarmAdvice(
      icon: '🍄',
      title: 'Ẩm cao $humidity% — coi chừng nấm bệnh',
      detail: 'Trời ẩm kéo dài dễ phát sinh nấm, rỉ sắt, thán thư. Bác nên '
          'thăm vườn kiểm tra lá và thoát nước cho gốc.',
      level: AdviceLevel.warn,
    ));
  }

  // ----- Chuồng trại (gà, vịt, heo) -----
  if (temp >= _hotTemp) {
    list.add(const FarmAdvice(
      icon: '🐓',
      title: 'Chuồng trại: chống nóng cho vật nuôi',
      detail: 'Tăng thông gió, che mát mái chuồng, cho uống nước mát đầy đủ '
          'để gà vịt heo không bị sốc nhiệt.',
      level: AdviceLevel.info,
    ));
  } else if (temp <= 18) {
    list.add(FarmAdvice(
      icon: '🐓',
      title: 'Chuồng trại: giữ ấm cho vật nuôi',
      detail: 'Trời lạnh $temp°C, nhớ che chắn gió lùa và ủ ấm cho con non.',
      level: AdviceLevel.info,
    ));
  }

  // ----- Nhìn trước mấy ngày tới: chuỗi ngày nắng ráo để thu hoạch/phơi -----
  final dry = <String>[];
  for (var i = 0; i < w.daily.length && i < 4; i++) {
    if (w.daily[i].rain <= 30) {
      final d = w.daily[i].date;
      dry.add(i == 0 ? 'hôm nay' : '${d.day}/${d.month}');
    }
  }
  if (dry.length >= 2) {
    list.add(FarmAdvice(
      icon: '📅',
      title: 'Sắp có ${dry.length} ngày ráo liên tiếp',
      detail: 'Các ngày ${dry.join(', ')} ít mưa — thuận lợi để thu hoạch và '
          'phơi. Bác nên sắp xếp nhân công trước.',
      level: AdviceLevel.good,
    ));
  }

  // Có mưa to trong mấy ngày tới -> nhắc trước
  for (var i = 1; i < w.daily.length && i < 4; i++) {
    if (w.daily[i].rain >= 80) {
      final d = w.daily[i].date;
      list.add(FarmAdvice(
        icon: '🌧️',
        title: 'Ngày ${d.day}/${d.month} nhiều khả năng mưa to',
        detail: 'Khả năng mưa ${w.daily[i].rain}%. Bác tính trước việc thu '
            'hoạch, che bạt, khơi rãnh thoát nước.',
        level: AdviceLevel.warn,
      ));
      break;
    }
  }

  if (list.isEmpty) {
    list.add(const FarmAdvice(
      icon: '🙂',
      title: 'Thời tiết bình thường',
      detail: 'Không có gì bất thường, bác cứ làm việc như thường lệ.',
      level: AdviceLevel.info,
    ));
  }
  return list;
}
