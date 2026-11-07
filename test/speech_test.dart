import 'package:flutter_test/flutter_test.dart';
import 'package:hefarmer/services/speech_service.dart';

void main() {
  group('Đọc số tiền thành lời tiếng Việt', () {
    test('đọc đúng cách nói mốt / tư / lăm / lẻ', () {
      expect(moneyToWords(94800), 'chín mươi tư nghìn tám trăm đồng');
      expect(moneyToWords(21000), 'hai mươi mốt nghìn đồng');
      expect(moneyToWords(15000), 'mười lăm nghìn đồng');
      expect(moneyToWords(105000), 'một trăm lẻ năm nghìn đồng');
    });

    test('đọc số lớn hàng triệu, hàng tỷ', () {
      expect(moneyToWords(151300000),
          'một trăm năm mươi mốt triệu ba trăm nghìn đồng');
      expect(moneyToWords(2000000000), 'hai tỷ đồng');
    });

    test('đơn vị đọc tự nhiên theo mặt hàng', () {
      expect(unitToWords('đ/kg'), 'một ký');
      expect(unitToWords('đ/quả'), 'một quả');
      expect(unitToWords('đ/lượng'), 'một lượng');
    });

    test('ghép câu đọc đầy đủ cho một mặt hàng', () {
      final s = buildPriceSentence(
        name: 'Cà phê',
        buy: 94800,
        sell: null,
        unit: 'đ/kg',
        change: -2000,
      );
      expect(s.contains('Cà phê hôm nay'), true);
      expect(s.contains('chín mươi tư nghìn tám trăm đồng một ký'), true);
      expect(s.contains('giảm hai nghìn đồng'), true);
    });

    test('chưa có giá thì báo rõ, không đọc số rỗng', () {
      expect(buildPriceSentence(name: 'Hồ tiêu', buy: null, unit: 'đ/kg'),
          'Chưa có giá Hồ tiêu hôm nay.');
    });
  });
}
