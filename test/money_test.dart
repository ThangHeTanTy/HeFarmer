import 'package:flutter_test/flutter_test.dart';
import 'package:hefarmer/screens/alert_screen.dart';

void main() {
  group('Đọc số tiền thành chữ (máy tính tiền bán)', () {
    test('đọc đúng hàng triệu, nghìn', () {
      expect(readMoneyVn(113760000), 'khoảng 113 triệu 760 nghìn đồng');
      expect(readMoneyVn(94800000), 'khoảng 94 triệu 800 nghìn đồng');
    });
    test('đọc đúng hàng tỷ', () {
      expect(readMoneyVn(1500000000), 'khoảng 1 tỷ 500 triệu đồng');
    });
    test('số nhỏ và số 0', () {
      expect(readMoneyVn(0), '');
      expect(readMoneyVn(500), 'khoảng 500 đồng');
    });
  });
}
