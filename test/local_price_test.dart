import 'package:flutter_test/flutter_test.dart';
import 'package:hefarmer/services/local_price.dart';
import 'package:hefarmer/services/price_parser.dart';

const _coffee = [
  PriceRow(region: 'Đắk Lắk', buy: 98500),
  PriceRow(region: 'Lâm Đồng', buy: 97800),
  PriceRow(region: 'Gia Lai', buy: 98300),
  PriceRow(region: 'Đắk Nông', buy: 98600),
];

const _pig = [
  PriceRow(region: 'Miền Bắc', buy: 61000),
  PriceRow(region: 'Miền Trung - Tây Nguyên', buy: 59000),
  PriceRow(region: 'Miền Nam', buy: 62000),
  PriceRow(region: 'Hà Nội', buy: 61500),
];

void main() {
  group('Giá vùng gần nhà', () {
    test('ở Buôn Ma Thuột -> giá cà phê Đắk Lắk', () {
      final m = nearestRegion(_coffee, 12.667, 108.038)!;
      expect(m.region, 'Đắk Lắk');
      expect(m.km, lessThan(1));
    });

    test('ở Đà Lạt -> giá Lâm Đồng', () {
      expect(nearestRegion(_coffee, 11.94, 108.458)!.region, 'Lâm Đồng');
    });

    test('ở Cần Thơ: không có vùng cà phê nào đủ gần -> null', () {
      expect(nearestRegion(_coffee, 10.045, 105.746), isNull);
    });

    test('heo hơi: ở Hà Nội lấy đúng dòng Hà Nội', () {
      expect(nearestRegion(_pig, 21.028, 105.854)!.region, 'Hà Nội');
    });

    test('heo hơi: Thanh Hóa thuộc miền Trung, Cần Thơ thuộc miền Nam', () {
      expect(nearestRegion(_pig, 19.807, 105.777)!.region,
          'Miền Trung - Tây Nguyên');
      expect(nearestRegion(_pig, 10.045, 105.746)!.region, 'Miền Nam');
      expect(nearestRegion(_pig, 21.594, 105.848)!.region, 'Hà Nội');
      expect(nearestRegion(_pig, 22.665, 106.258)!.region, 'Miền Bắc');
    });

    test('cao su: tên vùng có hậu tố loại mủ vẫn khớp, lấy đủ các dòng', () {
      const rubber = [
        PriceRow(region: 'Phú Riềng — mủ nước', buy: 420, unit: 'đ/độ TSC'),
        PriceRow(region: 'Phú Riềng — mủ tạp/đông', buy: 15000, unit: 'đ/kg'),
        PriceRow(region: 'Mang Yang — mủ nước', buy: 400, unit: 'đ/độ TSC'),
      ];
      final m = nearestRegion(rubber, 11.535, 106.883)!; // Đồng Xoài
      expect(m.region, 'Phú Riềng');
      expect(rowsOfRegion(rubber, m.region), hasLength(2));
    });

    test('giá không chia vùng (vàng) -> null', () {
      const gold = [PriceRow(region: 'Vàng miếng SJC', buy: 150000000)];
      expect(nearestRegion(gold, 10.776, 106.7), isNull);
    });

    test('baseRegion bỏ hậu tố', () {
      expect(baseRegion('Phú Riềng — mủ nước'), 'Phú Riềng');
      expect(baseRegion('Cả nước (thấp nhất)'), 'Cả nước');
      expect(baseRegion('Đắk Lắk'), 'Đắk Lắk');
    });
  });
}
