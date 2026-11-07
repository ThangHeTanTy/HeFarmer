import 'package:flutter_test/flutter_test.dart';
import 'package:hefarmer/services/vn_places.dart';

void main() {
  group('normalizeVn', () {
    test('bỏ dấu tiếng Việt để tìm kiếm dễ dãi', () {
      expect(normalizeVn('Đồng Nai'), 'dong nai');
      expect(normalizeVn('BIÊN HÒA'), 'bien hoa');
    });
  });

  group('searchProvinces — gợi ý khi nhập', () {
    test('danh sách đủ 34 tỉnh thành sau sáp nhập', () {
      expect(vnProvinces.length, 34);
    });
    test('gõ có dấu hoặc không dấu đều ra kết quả', () {
      expect(searchProvinces('dong nai').single.name, 'Đồng Nai');
      expect(searchProvinces('Đồng Nai').single.name, 'Đồng Nai');
    });
    test('gõ tên thành phố trực thuộc cũng gợi ý được tỉnh mới', () {
      expect(searchProvinces('bien hoa').single.name, 'Đồng Nai');
      expect(searchProvinces('quy nhon').single.name, 'Gia Lai');
    });
    test('không khớp thì trả rỗng', () {
      expect(searchProvinces('paris'), isEmpty);
    });
  });
}
