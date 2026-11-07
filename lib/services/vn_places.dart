import 'dart:convert';

import 'package:http/http.dart' as http;

import 'account_service.dart';

/// DỮ LIỆU ĐỊA PHƯƠNG VIỆT NAM cho ô nhập vị trí có gợi ý.
///
/// 1) Danh sách 34 tỉnh/thành CẬP NHẬT MỚI NHẤT sau sáp nhập 1/7/2025
///    (kèm tọa độ trung tâm) — hoạt động cả khi KHÔNG có mạng.
/// 2) Gõ chi tiết hơn (tên xã/phường/thị trấn) sẽ tìm thêm trực tuyến qua
///    API địa danh Open-Meteo (miễn phí, không cần key), lọc riêng Việt Nam.

class PlaceSuggestion {
  final String name; // "Biên Hòa"
  final String detail; // "Đồng Nai"
  final double latitude;
  final double longitude;
  const PlaceSuggestion({
    required this.name,
    required this.detail,
    required this.latitude,
    required this.longitude,
  });

  String get label => detail.isEmpty ? name : '$name, $detail';

  HomeLocation toHomeLocation() =>
      HomeLocation(latitude: latitude, longitude: longitude, label: label);
}

/// 34 tỉnh/thành sau sáp nhập (tọa độ lấy tại trung tâm hành chính)
const vnProvinces = <PlaceSuggestion>[
  PlaceSuggestion(name: 'Hà Nội', detail: 'Thủ đô', latitude: 21.028, longitude: 105.854),
  PlaceSuggestion(name: 'TP. Hồ Chí Minh', detail: '', latitude: 10.776, longitude: 106.700),
  PlaceSuggestion(name: 'Hải Phòng', detail: '', latitude: 20.865, longitude: 106.684),
  PlaceSuggestion(name: 'Đà Nẵng', detail: '', latitude: 16.047, longitude: 108.206),
  PlaceSuggestion(name: 'Cần Thơ', detail: '', latitude: 10.045, longitude: 105.746),
  PlaceSuggestion(name: 'Huế', detail: '', latitude: 16.463, longitude: 107.585),
  PlaceSuggestion(name: 'Lai Châu', detail: '', latitude: 22.396, longitude: 103.470),
  PlaceSuggestion(name: 'Điện Biên', detail: '', latitude: 21.386, longitude: 103.023),
  PlaceSuggestion(name: 'Sơn La', detail: '', latitude: 21.328, longitude: 103.914),
  PlaceSuggestion(name: 'Lạng Sơn', detail: '', latitude: 21.853, longitude: 106.761),
  PlaceSuggestion(name: 'Cao Bằng', detail: '', latitude: 22.665, longitude: 106.258),
  PlaceSuggestion(name: 'Tuyên Quang', detail: '', latitude: 21.823, longitude: 105.218),
  PlaceSuggestion(name: 'Lào Cai', detail: '', latitude: 22.485, longitude: 103.970),
  PlaceSuggestion(name: 'Thái Nguyên', detail: '', latitude: 21.594, longitude: 105.848),
  PlaceSuggestion(name: 'Phú Thọ', detail: 'TP. Việt Trì', latitude: 21.323, longitude: 105.402),
  PlaceSuggestion(name: 'Bắc Ninh', detail: '', latitude: 21.186, longitude: 106.076),
  PlaceSuggestion(name: 'Hưng Yên', detail: '', latitude: 20.646, longitude: 106.051),
  PlaceSuggestion(name: 'Ninh Bình', detail: '', latitude: 20.254, longitude: 105.975),
  PlaceSuggestion(name: 'Quảng Ninh', detail: 'TP. Hạ Long', latitude: 20.951, longitude: 107.073),
  PlaceSuggestion(name: 'Thanh Hóa', detail: '', latitude: 19.807, longitude: 105.777),
  PlaceSuggestion(name: 'Nghệ An', detail: 'TP. Vinh', latitude: 18.679, longitude: 105.681),
  PlaceSuggestion(name: 'Hà Tĩnh', detail: '', latitude: 18.343, longitude: 105.906),
  PlaceSuggestion(name: 'Quảng Trị', detail: 'TP. Đông Hà', latitude: 16.816, longitude: 107.100),
  PlaceSuggestion(name: 'Quảng Ngãi', detail: '', latitude: 15.121, longitude: 108.804),
  PlaceSuggestion(name: 'Gia Lai', detail: 'TP. Quy Nhơn', latitude: 13.782, longitude: 109.219),
  PlaceSuggestion(name: 'Khánh Hòa', detail: 'TP. Nha Trang', latitude: 12.238, longitude: 109.196),
  PlaceSuggestion(name: 'Lâm Đồng', detail: 'TP. Đà Lạt', latitude: 11.940, longitude: 108.458),
  PlaceSuggestion(name: 'Đắk Lắk', detail: 'TP. Buôn Ma Thuột', latitude: 12.667, longitude: 108.038),
  PlaceSuggestion(name: 'Đồng Nai', detail: 'TP. Biên Hòa', latitude: 10.957, longitude: 106.842),
  PlaceSuggestion(name: 'Tây Ninh', detail: '', latitude: 11.310, longitude: 106.098),
  PlaceSuggestion(name: 'Vĩnh Long', detail: '', latitude: 10.253, longitude: 105.972),
  PlaceSuggestion(name: 'Đồng Tháp', detail: 'TP. Mỹ Tho', latitude: 10.360, longitude: 106.360),
  PlaceSuggestion(name: 'An Giang', detail: 'TP. Rạch Giá', latitude: 10.012, longitude: 105.081),
  PlaceSuggestion(name: 'Cà Mau', detail: '', latitude: 9.177, longitude: 105.150),
];

/// Bỏ dấu tiếng Việt + viết thường để so khớp dễ dãi khi gõ tìm
String normalizeVn(String s) {
  const from = 'àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡ'
      'ùúụủũưừứựửữỳýỵỷỹđ';
  const to = 'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooo'
      'uuuuuuuuuuuyyyyyd';
  var out = s.toLowerCase();
  for (var i = 0; i < from.length; i++) {
    out = out.replaceAll(from[i], to[i]);
  }
  return out;
}

/// Lọc danh sách 34 tỉnh/thành theo từ khóa (không cần mạng)
List<PlaceSuggestion> searchProvinces(String query) {
  final q = normalizeVn(query.trim());
  if (q.isEmpty) return vnProvinces;
  return vnProvinces
      .where((p) =>
          normalizeVn(p.name).contains(q) || normalizeVn(p.detail).contains(q))
      .toList();
}

/// Tìm địa danh chi tiết (xã/phường/thị trấn...) trực tuyến, chỉ lấy ở VN
Future<List<PlaceSuggestion>> searchPlacesOnline(String query) async {
  final q = query.trim();
  if (q.length < 2) return [];
  final url = Uri.parse('https://geocoding-api.open-meteo.com/v1/search'
      '?name=${Uri.encodeComponent(q)}&count=10&language=vi&format=json');
  final res = await http.get(url).timeout(const Duration(seconds: 10));
  if (res.statusCode != 200) return [];
  final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
  final results = (data['results'] as List?) ?? [];
  return results
      .cast<Map<String, dynamic>>()
      .where((r) => (r['country_code'] as String?)?.toUpperCase() == 'VN')
      .map((r) => PlaceSuggestion(
            name: r['name'] as String? ?? '',
            detail: [r['admin2'], r['admin1']]
                .whereType<String>()
                .where((e) => e.isNotEmpty && e != r['name'])
                .join(', '),
            latitude: (r['latitude'] as num).toDouble(),
            longitude: (r['longitude'] as num).toDouble(),
          ))
      .where((p) => p.name.isNotEmpty)
      .toList();
}
