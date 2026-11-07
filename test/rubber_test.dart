import 'package:flutter_test/flutter_test.dart';
import 'package:hefarmer/services/price_parser.dart';

void main() {
  // Văn bản lấy từ bài báo giá cao su thực tế
  const baibao = 'Trong nước, tại Công ty Bình Long, giá cao su thu mua tại '
      'Nhà máy ở mức 540 đồng/độ TSC/kg và giá thu mua tại đội sản xuất '
      '530 đồng/TSC/kg; giá mủ tạp (DRC 60%) bình ổn 18.000 đồng/kg. '
      'Tại Công ty MangYang, giá thu mua mủ nước ghi nhận khoảng '
      '458 - 463 đồng/TSC (loại 2-loại 1), mủ đông tạp khoảng '
      '404 - 459 đồng/DRC (loại 2-loại 1). '
      'Công ty Cao su Bà Rịa cũng báo giá thu mua mủ nước ở mức '
      '420 đồng/độ TSC/kg (áp dụng cho độ TSC từ 25 đến dưới 30); '
      'mủ đông DRC (35 - 44%) ở mức 14.600 đồng/kg. '
      'Tại Công ty Phú Riềng, chào giá thu mua mủ tạp bình ổn ở mức '
      '390 đồng/DRC, giá thu mua mủ nước 420 đồng/TSC.';

  group('Giá mủ cao su', () {
    test('đọc đúng giá mủ nước của từng công ty', () {
      final rows = parseRubber(baibao);
      int? buyOf(String c) => rows
          .where((r) => r.region.contains(c) && r.region.contains('mủ nước'))
          .map((r) => r.buy)
          .firstOrNull;

      expect(buyOf('Bình Long'), 540);
      expect(buyOf('Mang Yang'), 463); // dải 458-463 -> lấy loại 1
      expect(buyOf('Bà Rịa'), 420);
      expect(buyOf('Phú Riềng'), 420);
    });

    test('không lấy nhầm giá của công ty đứng sau', () {
      final rows = parseRubber(baibao);
      // Bình Long không niêm yết theo DRC -> không được gán 459 của Mang Yang
      final binhLongDrc = rows
          .where((r) => r.region.contains('Bình Long') && r.unit == 'đ/độ DRC');
      expect(binhLongDrc.isEmpty, true);
    });

    test('đọc được mủ tạp theo đồng/kg và theo độ DRC', () {
      final rows = parseRubber(baibao);
      expect(
          rows
              .where((r) => r.region.contains('Bình Long') && r.unit == 'đ/kg')
              .first
              .buy,
          18000);
      expect(
          rows
              .where(
                  (r) => r.region.contains('Phú Riềng') && r.unit == 'đ/độ DRC')
              .first
              .buy,
          390);
    });

    test('đọc được bảng giá dạng ô trên web công ty', () {
      const bangWeb = 'Bảng giá thu mua | Mủ Nước | 420 | Đồng/TSC | '
          'Mủ Tạp | 390 | Đồng/DRC |';
      final rows = parseRubber(bangWeb);
      expect(rows.isNotEmpty, true);
      expect(rows.any((r) => r.buy == 420 && r.unit == 'đ/độ TSC'), true);
    });

    test('trang không nhắc tên công ty vẫn lấy được giá (lớp dự phòng)', () {
      const chung = 'Giá thu mua mủ nước bình quân đạt 445 đồng/độ TSC/kg, '
          'mủ tạp 16.500 đồng/kg.';
      final rows = parseRubber(chung);
      expect(rows.any((r) => r.buy == 445 && r.unit == 'đ/độ TSC'), true);
      expect(rows.any((r) => r.buy == 16500 && r.unit == 'đ/kg'), true);
    });

    test('đọc được cách viết VND/độ TSC (banggianongsan.com)', () {
      const t = 'Giá cao su hôm nay dao động 235 - 285 VND/độ TSC mủ nước, '
          'tùy khu vực như Bình Phước, Tây Ninh, Đồng Nai. '
          'Mủ tạp chênh lệch so với hôm qua.';
      final rows = parseRubber(t);
      expect(rows.any((r) => r.buy == 285 && r.unit == 'đ/độ TSC'), true);
    });

    test('đọc được cách viết "đồng/độ mủ" (giongcaosu.com)', () {
      const t = 'Giá mủ cao su hiện nay được các thương lái thu mua giao '
          'động quanh mức 425 - 450 đồng/độ mủ ở Đông Nam bộ.';
      final rows = parseRubber(t);
      expect(rows.any((r) => r.buy == 450 && r.unit == 'đ/độ TSC'), true);
    });

    test('LUÔN tách riêng mủ nước và mủ đông', () {
      const t = 'Giá mủ nước ở mức 420 đồng/TSC/kg. '
          'Mủ đông có độ DRC từ 35-45% ở mức 13.500 đồng/kg.';
      final rows = parseRubber(t);
      bool hasRow(String key, int buy) => rows.any(
          (r) => r.region.toLowerCase().contains(key) && r.buy == buy);
      expect(hasRow('mủ nước', 420), true);
      expect(hasRow('mủ đông', 13500), true);
    });

    test('bỏ qua số vô lý (ngoài khoảng giá mủ)', () {
      const rac = 'Sản lượng 999 tấn, diện tích 1.200 ha, năm 2026.';
      expect(parseRubber(rac), isEmpty);
    });
  });
}
