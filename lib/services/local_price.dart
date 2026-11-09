import 'dart:math' as math;

import 'price_parser.dart';
import 'vn_places.dart';

/// GIÁ GẦN NHÀ — chọn ra vùng giá gần "Vị trí của tôi" nhất.
///
/// Giá cà phê Đắk Lắk và Lâm Đồng có thể chênh nhau vài nghìn đồng, nên con
/// số TRUNG BÌNH cả nước không đúng với chỗ nào cả. Bà con cần biết giá ở
/// vùng mình trước.

/// Tọa độ các vùng giá mà bộ bóc tách trả về (tỉnh CŨ trước sáp nhập, vì
/// các trang giá vẫn ghi theo tên cũ; công ty cao su lấy tại nơi đóng trụ sở),
/// kèm BÁN KÍNH coi là "gần": cả một tỉnh Tây Nguyên thì rộng, còn giá
/// "Hà Nội" chỉ là giá quanh thành phố. Khoá đã bỏ dấu (normalizeVn).
const _regionCoords = <String, (double, double, double)>{
  // Tây Nguyên & Đông Nam Bộ (cà phê, hồ tiêu)
  'dak lak': (12.667, 108.038, 150),
  'lam dong': (11.940, 108.458, 150),
  'gia lai': (13.983, 108.000, 150), // Pleiku — vùng cà phê, không phải Quy Nhơn
  'dak nong': (12.004, 107.691, 120),
  'kon tum': (14.350, 108.000, 120),
  'dong nai': (10.957, 106.842, 100),
  'ba ria - vung tau': (10.496, 107.168, 80),
  'ba ria': (10.496, 107.168, 80),
  'binh phuoc': (11.535, 106.883, 100),
  'ha noi': (21.028, 105.854, 70),
  // Công ty cao su
  'phu rieng': (11.700, 106.930, 100),
  'binh long': (11.650, 106.600, 100),
  'mang yang': (13.960, 108.300, 120),
  'dong phu': (11.480, 106.950, 100),
  'phuoc hoa': (11.230, 106.700, 100),
  'dau tieng': (11.270, 106.360, 100),
};

/// Phần tên vùng gốc: "Phú Riềng — mủ nước" -> "Phú Riềng",
/// "Cả nước (thấp nhất)" -> "Cả nước"
String baseRegion(String region) {
  var r = region.split(' — ').first;
  final paren = r.indexOf(' (');
  if (paren > 0) r = r.substring(0, paren);
  return r.trim();
}

double distanceKm(double lat1, double lon1, double lat2, double lon2) {
  const r = 6371.0;
  double rad(double d) => d * math.pi / 180;
  final dLat = rad(lat2 - lat1);
  final dLon = rad(lon2 - lon1);
  final a = math.pow(math.sin(dLat / 2), 2) +
      math.cos(rad(lat1)) * math.cos(rad(lat2)) * math.pow(math.sin(dLon / 2), 2);
  return 2 * r * math.asin(math.sqrt(a));
}

/// Vùng giá heo theo MIỀN (theo cách các bản tin giá heo chia vùng):
/// Thanh Hóa trở vào thuộc miền Trung; Tây Nguyên và Bình Thuận cũng thế.
String _mienOf(double lat, double lon) {
  if (lat >= 19.95) return 'mien bac';
  if (lat < 11.7 && lon < 107.6) return 'mien nam';
  return 'mien trung';
}

class LocalMatch {
  final String region; // tên vùng gốc như trong bảng giá
  final double? km; // null = khớp theo miền
  const LocalMatch(this.region, this.km);
}

/// Chọn vùng giá gần vị trí (lat, lon) nhất trong các dòng giá.
/// Trả về null nếu không có vùng nào đủ gần (ví dụ giá vàng, giá phân bón
/// không chia theo vùng).
LocalMatch? nearestRegion(Iterable<PriceRow> rows, double lat, double lon) {
  final bases = <String>{for (final r in rows) baseRegion(r.region)};

  // 1) Tỉnh / công ty có tọa độ: lấy nơi gần nhất trong bán kính cho phép
  LocalMatch? best;
  for (final b in bases) {
    final c = _regionCoords[normalizeVn(b)];
    if (c == null) continue;
    final km = distanceKm(lat, lon, c.$1, c.$2);
    if (km <= c.$3 && (best == null || km < best.km!)) {
      best = LocalMatch(b, km);
    }
  }
  if (best != null) return best;

  // 2) Giá chia theo miền (heo hơi)
  final mien = _mienOf(lat, lon);
  for (final b in bases) {
    if (normalizeVn(b).startsWith(mien)) return LocalMatch(b, null);
  }
  return null;
}

/// Các dòng giá thuộc vùng [region] (một vùng cao su có thể có 2–3 dòng)
List<PriceRow> rowsOfRegion(Iterable<PriceRow> rows, String region) =>
    rows.where((r) => baseRegion(r.region) == region).toList();
