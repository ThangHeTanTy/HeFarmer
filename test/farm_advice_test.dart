import 'package:flutter_test/flutter_test.dart';
import 'package:hefarmer/services/farm_advice.dart';
import 'package:hefarmer/services/weather_service.dart';

WeatherData _w({
  int temp = 30,
  int humidity = 70,
  int wind = 10,
  int rain = 10,
  List<DailyForecast>? daily,
}) =>
    WeatherData(
      temperature: temp,
      humidity: humidity,
      windSpeed: wind,
      rainProbability: rain,
      description: 'Có mây',
      daily: daily ?? const [],
      updatedAt: DateTime(2026, 7, 24),
    );

void main() {
  group('Gợi ý việc nhà nông theo thời tiết', () {
    test('mưa nhiều -> khuyên KHÔNG phơi nông sản', () {
      final a = buildFarmAdvice(_w(rain: 80));
      expect(a.any((e) => e.title.contains('Không nên phơi')), true);
      expect(a.firstWhere((e) => e.title.contains('Không nên phơi')).level,
          AdviceLevel.danger);
    });

    test('trời ráo, ấm -> khuyên tranh thủ phơi và phun thuốc được', () {
      final a = buildFarmAdvice(_w(rain: 10, temp: 30, wind: 8));
      expect(a.any((e) => e.title.contains('thuận lợi để phơi')), true);
      expect(a.any((e) => e.title.contains('hợp để phun thuốc')), true);
    });

    test('gió mạnh -> hoãn phun thuốc', () {
      final a = buildFarmAdvice(_w(wind: 30));
      expect(a.any((e) => e.title.contains('Hoãn phun thuốc')), true);
    });

    test('gió rất mạnh -> cảnh báo chằng chống', () {
      final a = buildFarmAdvice(_w(wind: 45));
      expect(
          a.any((e) =>
              e.level == AdviceLevel.danger && e.title.contains('Gió rất mạnh')),
          true);
    });

    test('nắng gắt -> nhắc sức khoẻ và chống nóng chuồng trại', () {
      final a = buildFarmAdvice(_w(temp: 37));
      expect(a.any((e) => e.title.contains('Nắng gắt')), true);
      expect(a.any((e) => e.title.contains('chống nóng')), true);
    });

    test('mưa nhẹ -> thuận lợi bón phân; mưa to -> chưa nên bón', () {
      expect(
          buildFarmAdvice(_w(rain: 50))
              .any((e) => e.title.contains('Thuận lợi bón phân')),
          true);
      expect(
          buildFarmAdvice(_w(rain: 85))
              .any((e) => e.title.contains('Chưa nên bón phân')),
          true);
    });

    test('nhiều ngày ráo liên tiếp -> gợi ý sắp xếp thu hoạch', () {
      final daily = [
        DailyForecast(DateTime(2026, 7, 24), 32, 24, 10, 'Nắng'),
        DailyForecast(DateTime(2026, 7, 25), 33, 24, 15, 'Nắng'),
        DailyForecast(DateTime(2026, 7, 26), 33, 25, 20, 'Ít mây'),
      ];
      final a = buildFarmAdvice(_w(rain: 10, daily: daily));
      expect(a.any((e) => e.title.contains('ngày ráo liên tiếp')), true);
    });

    test('luôn có ít nhất 1 lời khuyên', () {
      expect(buildFarmAdvice(_w(rain: 35, temp: 25, wind: 12)).isNotEmpty, true);
    });
  });
}
