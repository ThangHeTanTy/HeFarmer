import 'dart:convert';

import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

/// DỊCH VỤ THỜI TIẾT — dùng API Open-Meteo (https://open-meteo.com)
/// Miễn phí, không cần đăng ký API key, dữ liệu từ các mô hình khí tượng
/// quốc tế (ECMWF, GFS...), rất phù hợp cho ứng dụng nông nghiệp.

class DeviceLocation {
  final double latitude;
  final double longitude;
  final String placeName;
  const DeviceLocation(this.latitude, this.longitude, this.placeName);
}

class DailyForecast {
  final DateTime date;
  final int tMax;
  final int tMin;
  final int rain; // %
  final String desc;
  const DailyForecast(this.date, this.tMax, this.tMin, this.rain, this.desc);
}

class WeatherData {
  final int temperature; // °C
  final int humidity; // %
  final int windSpeed; // km/h
  final int? rainProbability; // %
  final String description;
  final List<DailyForecast> daily;
  final DateTime updatedAt;
  const WeatherData({
    required this.temperature,
    required this.humidity,
    required this.windSpeed,
    required this.rainProbability,
    required this.description,
    required this.daily,
    required this.updatedAt,
  });
}

const _weatherCodes = <int, String>{
  0: 'Trời quang', 1: 'Ít mây', 2: 'Có mây', 3: 'Nhiều mây',
  45: 'Sương mù', 48: 'Sương mù đọng băng',
  51: 'Mưa phùn nhẹ', 53: 'Mưa phùn', 55: 'Mưa phùn dày',
  61: 'Mưa nhỏ', 63: 'Mưa vừa', 65: 'Mưa to',
  66: 'Mưa lạnh nhẹ', 67: 'Mưa lạnh to',
  80: 'Mưa rào nhẹ', 81: 'Mưa rào', 82: 'Mưa rào rất to',
  95: 'Dông', 96: 'Dông kèm mưa đá nhẹ', 99: 'Dông kèm mưa đá to',
};

Future<DeviceLocation> getDeviceLocation() async {
  final serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) {
    throw Exception('Định vị (GPS) đang tắt. Hãy bật Vị trí trong Cài đặt rồi thử lại.');
  }
  var permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }
  if (permission == LocationPermission.denied ||
      permission == LocationPermission.deniedForever) {
    throw Exception(
        'Bạn chưa cho phép ứng dụng dùng vị trí. Vào Cài đặt > Ứng dụng > cấp quyền Vị trí rồi thử lại.');
  }
  final pos = await Geolocator.getCurrentPosition(
    locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
  );

  var placeName = 'Vị trí của bạn';
  try {
    final url = Uri.parse(
        'https://api.bigdatacloud.net/data/reverse-geocode-client'
        '?latitude=${pos.latitude}&longitude=${pos.longitude}'
        '&localityLanguage=vi');
    final res = await http.get(url).timeout(const Duration(seconds: 10));
    if (res.statusCode == 200) {
      final g = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      final parts = [g['city'], g['principalSubdivision']]
          .whereType<String>()
          .where((e) => e.isNotEmpty)
          .toList();
      if (parts.isNotEmpty) placeName = parts.join(', ');
    }
  } catch (_) {
    // không sao, dùng tên mặc định
  }
  return DeviceLocation(pos.latitude, pos.longitude, placeName);
}

Future<WeatherData> fetchWeather(double latitude, double longitude) async {
  final url = Uri.parse(
    'https://api.open-meteo.com/v1/forecast'
    '?latitude=$latitude&longitude=$longitude'
    '&current=temperature_2m,relative_humidity_2m,wind_speed_10m,weather_code,precipitation'
    '&hourly=precipitation_probability,temperature_2m'
    '&daily=precipitation_probability_max,temperature_2m_max,temperature_2m_min,weather_code'
    '&forecast_days=4&timezone=auto&wind_speed_unit=kmh',
  );
  final res = await http.get(url).timeout(const Duration(seconds: 15));
  if (res.statusCode != 200) {
    throw Exception('Máy chủ thời tiết trả lỗi HTTP ${res.statusCode}');
  }
  final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
  final current = data['current'] as Map<String, dynamic>;

  // Khả năng mưa của giờ hiện tại
  int? rainNow;
  final hourly = data['hourly'] as Map<String, dynamic>?;
  if (hourly != null) {
    final times = (hourly['time'] as List).cast<String>();
    final nowIso = (current['time'] as String).substring(0, 13); // yyyy-MM-ddTHH
    final idx = times.indexWhere((t) => t.startsWith(nowIso));
    if (idx >= 0) {
      rainNow = (hourly['precipitation_probability'][idx] as num?)?.round();
    }
  }

  final dailyRaw = data['daily'] as Map<String, dynamic>;
  final dailyTimes = (dailyRaw['time'] as List).cast<String>();
  final daily = <DailyForecast>[];
  for (var i = 0; i < dailyTimes.length; i++) {
    daily.add(DailyForecast(
      DateTime.parse(dailyTimes[i]),
      (dailyRaw['temperature_2m_max'][i] as num).round(),
      (dailyRaw['temperature_2m_min'][i] as num).round(),
      ((dailyRaw['precipitation_probability_max'][i] as num?) ?? 0).round(),
      _weatherCodes[(dailyRaw['weather_code'][i] as num).toInt()] ?? '—',
    ));
  }

  return WeatherData(
    temperature: (current['temperature_2m'] as num).round(),
    humidity: (current['relative_humidity_2m'] as num).round(),
    windSpeed: (current['wind_speed_10m'] as num).round(),
    rainProbability: rainNow ?? (daily.isNotEmpty ? daily.first.rain : null),
    description:
        _weatherCodes[(current['weather_code'] as num).toInt()] ?? 'Không rõ',
    daily: daily,
    updatedAt: DateTime.now(),
  );
}

String windyEmbedUrl(double latitude, double longitude) {
  final lat = latitude.toStringAsFixed(3);
  final lon = longitude.toStringAsFixed(3);
  return 'https://embed.windy.com/embed2.html'
      '?lat=$lat&lon=$lon&detailLat=$lat&detailLon=$lon'
      '&zoom=8&level=surface&overlay=rain&product=ecmwf'
      '&menu=&message=true&marker=true&calendar=now&type=map'
      '&location=coordinates&metricWind=km%2Fh&metricTemp=%C2%B0C';
}
