import 'package:flutter_test/flutter_test.dart';
import 'package:hefarmer/services/price_parser.dart';

void main() {
  group('htmlToText', () {
    test('bỏ thẻ HTML, script, gộp khoảng trắng', () {
      const html =
          '<html><script>var x=1;</script><body><p>Giá  cà phê</p><td>94.800</td></body></html>';
      final text = htmlToText(html);
      expect(text.contains('script'), false);
      expect(text.contains('Giá cà phê'), true);
      expect(text.contains('94.800'), true);
    });
  });

  group('toNumber', () {
    test('đổi chuỗi giá Việt Nam sang số', () {
      expect(toNumber('94.800'), 94800);
      expect(toNumber('94,800'), 94800);
      expect(toNumber('136.000'), 136000);
    });
  });

  group('parseProvincePrices — cà phê', () {
    const sample = 'Theo khảo sát sáng 9/7, Tại Gia Lai, giá cà phê giảm 2.000 '
        'đồng/kg, xuống còn 94.800 đồng/kg | Cùng mức giảm 2.000 đồng/kg, giá '
        'cà phê tại Đắk Lắk lùi về 94.700 đồng/kg | Lâm Đồng tăng 1.900 đồng/kg '
        'lên 94.300 đồng/kg';

    test('bóc đúng giá và mức thay đổi từng tỉnh', () {
      final rows =
          parseProvincePrices(sample, coffeeProvinces, 40000, 200000);
      final giaLai = rows.firstWhere((r) => r.region == 'Gia Lai');
      expect(giaLai.buy, 94800);
      expect(giaLai.change, -2000);

      final dakLak = rows.firstWhere((r) => r.region == 'Đắk Lắk');
      expect(dakLak.buy, 94700);

      final lamDong = rows.firstWhere((r) => r.region == 'Lâm Đồng');
      expect(lamDong.buy, 94300);
      expect(lamDong.change, 1900);
    });

    test('loại số rác ngoài khoảng giá hợp lý (năm, số nhỏ)', () {
      const junk = 'Gia Lai năm 2.026 có 1.500 hộ trồng, giá 94.800 đồng/kg';
      final rows = parseProvincePrices(junk, coffeeProvinces, 40000, 200000);
      expect(rows.single.buy, 94800);
    });
  });

  group('parseProvincePrices — hồ tiêu', () {
    test('bóc giá tiêu các vùng', () {
      const sample = 'Đắk Lắk và Đắk Nông cùng tăng lên 136.000 đồng/kg | '
          'Tại Gia Lai giá hồ tiêu tăng 1.000 đồng/kg, đạt 135.000 đồng/kg | '
          'Đồng Nai tăng lên 134.000 đồng/kg';
      final rows =
          parseProvincePrices(sample, pepperProvinces, 60000, 350000);
      expect(rows.firstWhere((r) => r.region == 'Đắk Lắk').buy, 136000);
      expect(rows.firstWhere((r) => r.region == 'Gia Lai').buy, 135000);
      expect(rows.firstWhere((r) => r.region == 'Đồng Nai').buy, 134000);
    });
  });

  group('parseRubber — mủ cao su', () {
    test('bóc giá mủ nước (đ/độ TSC) và mủ tạp (đ/kg)', () {
      const sample = 'Công ty Bình Long, giá cao su thu mua tại Nhà máy ở mức '
          '505 đồng/độ TSC/kg; thu mua tại đội sản xuất 495 đồng/TSC/kg; '
          'giá mủ tạp (DRC 60%) 18.000 đồng/kg. Công ty Phú Riềng giữ mức '
          '440 đồng/TSC.';
      final rows = parseRubber(sample);
      final binhLong =
          rows.firstWhere((r) => r.region.contains('Bình Long'));
      expect(binhLong.buy, 505);
      expect(binhLong.unit, 'đ/độ TSC');

      final phuRieng =
          rows.firstWhere((r) => r.region.contains('Phú Riềng'));
      expect(phuRieng.buy, 440);

      // mủ tạp nay được ghi theo từng công ty hoặc dòng tổng hợp
      final muTap = rows.firstWhere((r) => r.unit == 'đ/kg');
      expect(muTap.buy, 18000);
    });

    test('không nhận giá TSC ngoài khoảng hợp lý', () {
      const sample = 'Bình Long báo giá 999 đồng/TSC'; // > 900 -> loại
      expect(parseRubber(sample), isEmpty);
    });
  });

  group('parseRange', () {
    test('bắt khoảng giá chung "x - y đồng/kg"', () {
      const sample = 'mặt bằng thu mua xuống còn 94.300 - 94.800 đồng/kg';
      final rows = parseRange(sample, 40000, 200000, 'Tây Nguyên');
      expect(rows.length, 2);
      expect(rows[0].buy, 94300);
      expect(rows[1].buy, 94800);
    });

    test('không khớp thì trả về rỗng', () {
      expect(parseRange('không có giá nào ở đây', 40000, 200000, 'X'), isEmpty);
    });
  });

  group('parseKeywordPrices — vật nuôi', () {
    test('bóc giá gà, vịt theo từ khóa với khoảng giá riêng', () {
      const sample = 'Giá gà công nghiệp miền Nam tăng 1.000 đồng lên '
          '33.000 đồng/kg | Gà ta thả vườn giữ mức 115.000 đồng/kg | '
          'Vịt thịt bán tại trại 46.000 đồng/kg';
      final chickens = parseKeywordPrices(sample, chickenKeywords);
      final congNghiep =
          chickens.firstWhere((r) => r.region.contains('công nghiệp'));
      expect(congNghiep.buy, 33000);
      expect(congNghiep.change, 1000);
      expect(
          chickens.firstWhere((r) => r.region.contains('Gà ta')).buy, 115000);

      final ducks = parseKeywordPrices(sample, duckKeywords);
      expect(ducks.firstWhere((r) => r.region.contains('Vịt thịt')).buy, 46000);
    });

    test('bóc giá trứng theo đ/quả, không lẫn với giá đ/kg', () {
      const sample = 'Trứng gà bán ra 2.200 đồng/quả, trứng vịt 2.800 '
          'đồng/quả trong khi heo hơi 68.000 đồng/kg';
      final rows = parseKeywordPrices(sample, eggKeywords);
      expect(rows.firstWhere((r) => r.region == 'Trứng gà').buy, 2200);
      expect(rows.firstWhere((r) => r.region == 'Trứng vịt').buy, 2800);
      expect(rows.every((r) => r.buy < 10000), true);
    });

    test('bóc giá heo hơi theo vùng miền', () {
      const sample = 'Giá heo hơi miền Bắc dao động 67.000 đồng/kg, '
          'miền Trung 65.000 đồng/kg, còn miền Nam giảm 1.000 đồng '
          'xuống 64.000 đồng/kg';
      final rows = parseProvincePrices(sample, pigRegions, 40000, 110000);
      expect(rows.firstWhere((r) => r.region == 'Miền Bắc').buy, 67000);
      final mienNam = rows.firstWhere((r) => r.region == 'Miền Nam');
      expect(mienNam.buy, 64000);
      expect(mienNam.change, -1000);
    });

    test('bóc giá bò, dê hơi', () {
      const sample = 'Bò hơi tại Tây Nguyên 78.000 đồng/kg; dê hơi '
          'thương lái mua 128.000 đồng/kg';
      final rows = parseKeywordPrices(sample, otherLivestockKeywords);
      expect(rows.firstWhere((r) => r.region == 'Bò hơi').buy, 78000);
      expect(rows.firstWhere((r) => r.region == 'Dê hơi').buy, 128000);
    });
  });


  group('kim loại quý — vàng, bạc, đồng', () {
    test('toFlexibleNumber đọc đủ các kiểu số quốc tế', () {
      expect(toFlexibleNumber('3.345,6'), 3346);
      expect(toFlexibleNumber('3,345.6'), 3346);
      expect(toFlexibleNumber('38,5'), 39);
      expect(toFlexibleNumber('3.345'), 3345);
      expect(toFlexibleNumber('10,250'), 10250);
    });

    test('parseSjcGold đọc XML chính thức của SJC', () {
      const xml = '<ratelist><city name="Ho Chi Minh">'
          '<item buy="151,300,000" sell="153,300,000" type="Vàng SJC 1L"/>'
          '</city></ratelist>';
      final rows = parseSjcGold(xml);
      expect(rows.single.buy, 151300000);
      expect(rows.single.sell, 153300000);
      expect(rows.single.unit, 'đ/lượng');
    });

    test('parseBuySellKeyword tách cặp mua-bán quanh từ khóa', () {
      const t = 'Giá vàng SJC hôm nay: mua vào 151.300.000 đồng/lượng, '
          'bán ra 153.300.000 đồng/lượng';
      final rows = parseBuySellKeyword(
          t, 'SJC', r'SJC', 60000000, 400000000, 'đ/lượng');
      expect(rows.single.buy, 151300000);
      expect(rows.single.sell, 153300000);
    });

    test('parseWorldMetal đọc giá thế giới có thập phân', () {
      const t = 'Giá vàng thế giới đứng ở 3.352,4 USD/ounce sáng nay';
      final rows = parseWorldMetal(
          t, 'Vàng thế giới', r'thế\s*giới', 1500, 10000, 'USD/oz');
      expect(rows.single.buy, 3352);
    });
  });

  group('average', () {
    test('tính trung bình, bỏ qua null', () {
      expect(average([100, 200, null]), 150);
      expect(average([null, null]), null);
      expect(average([]), null);
    });
  });
}
