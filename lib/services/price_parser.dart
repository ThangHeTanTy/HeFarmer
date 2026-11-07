/// BỘ BÓC TÁCH GIÁ NÔNG SẢN — thuần Dart, không phụ thuộc Flutter
/// để có thể chạy unit test nhanh bằng `flutter test`.
///
/// Việt Nam hiện KHÔNG có API JSON công khai miễn phí cho giá cà phê /
/// hồ tiêu / mủ cao su, nên ứng dụng đọc các trang giá uy tín cập nhật
/// hằng ngày và bóc tách con số từ nội dung trang.
import 'dart:convert';

class PriceRow {
  final String region;
  final int buy; // giá mua (thu mua)
  final int? sell; // giá bán ra (nếu nguồn có niêm yết)
  final int? change; // thay đổi so với hôm trước (+/-)
  final String? unit; // đơn vị riêng (mủ cao su)

  const PriceRow({
    required this.region,
    required this.buy,
    this.sell,
    this.change,
    this.unit,
  });

  Map<String, dynamic> toJson() => {
        'region': region,
        'buy': buy,
        'sell': sell,
        'change': change,
        'unit': unit,
      };

  factory PriceRow.fromJson(Map<String, dynamic> j) => PriceRow(
        region: j['region'] as String,
        buy: j['buy'] as int,
        sell: j['sell'] as int?,
        change: j['change'] as int?,
        unit: j['unit'] as String?,
      );
}

class Province {
  final String name;
  final String pattern;
  const Province(this.name, this.pattern);
}

/// Bỏ script/style/thẻ HTML, gộp khoảng trắng -> văn bản thuần để bóc số
String htmlToText(String html) {
  return html
      .replaceAll(RegExp(r'<script[\s\S]*?</script>', caseSensitive: false), ' ')
      .replaceAll(RegExp(r'<style[\s\S]*?</style>', caseSensitive: false), ' ')
      .replaceAll(RegExp(r'</(tr|td|th|p|div|li|h\d)>', caseSensitive: false), ' | ')
      .replaceAll(RegExp(r'<[^>]+>'), ' ')
      .replaceAll(RegExp(r'&nbsp;|&#160;'), ' ')
      .replaceAll('&amp;', '&')
      .replaceAll(RegExp(r'\s+'), ' ');
}

/// "94.800" / "94,800" -> 94800
int toNumber(String s) => int.parse(s.replaceAll(RegExp(r'[.,\s]'), ''));

final _priceNum = RegExp(r'\d{1,3}(?:[.,]\d{3})+');

/// Tìm giá theo từng vùng: với mỗi tên vùng, lấy con số dạng 12.345 / 123.456
/// xuất hiện gần nhất sau tên vùng (trong cửa sổ ~120 ký tự), lọc theo
/// khoảng giá hợp lý để loại số rác (năm, số điện thoại...).
List<PriceRow> parseProvincePrices(
  String text,
  List<Province> provinces,
  int min,
  int max, {
  int windowSize = 120,
}) {
  final rows = <PriceRow>[];
  for (final p in provinces) {
    final match = RegExp(p.pattern, caseSensitive: false).firstMatch(text);
    if (match == null) continue;
    final start = match.start;
    final end =
        (start + windowSize < text.length) ? start + windowSize : text.length;
    final win = text.substring(start, end);

    int? price;
    for (final m in _priceNum.allMatches(win)) {
      final n = toNumber(m.group(0)!);
      if (n >= min && n <= max) {
        price = n;
        break;
      }
    }
    if (price == null) continue;

    // Thử tìm mức thay đổi so với hôm trước trong cùng cửa sổ
    int? change;
    final up = RegExp(r'tăng\s+(\d{1,3}(?:[.,]\d{3})*)', caseSensitive: false)
        .firstMatch(win);
    final down = RegExp(r'giảm\s+(\d{1,3}(?:[.,]\d{3})*)', caseSensitive: false)
        .firstMatch(win);
    final signed =
        RegExp(r'([+\-])\s?(\d{1,3}(?:[.,]\d{3})+|\d{3,4})\b').firstMatch(win);
    if (up != null) {
      change = toNumber(up.group(1)!);
    } else if (down != null) {
      change = -toNumber(down.group(1)!);
    } else if (signed != null) {
      change =
          (signed.group(1) == '-' ? -1 : 1) * toNumber(signed.group(2)!);
    }
    if (change != null && change.abs() > max * 0.2) change = null; // số rác

    // Giá bán ra (nếu nguồn có niêm yết)
    int? sell;
    final sellM = RegExp(r'bán(?:\s*ra)?[^0-9]{0,20}(\d{1,3}(?:[.,]\d{3})+)',
            caseSensitive: false)
        .firstMatch(win);
    if (sellM != null) {
      final v = toNumber(sellM.group(1)!);
      if (v >= min && v <= max * 1.3 && v != price) sell = v;
    }

    rows.add(PriceRow(region: p.name, buy: price, sell: sell, change: change));
  }
  return rows;
}

/// Bắt khoảng giá chung kiểu "94.300 - 94.800 đồng/kg"
/// khi không bóc được theo vùng.
List<PriceRow> parseRange(String text, int min, int max, String label) {
  final m = RegExp(
    r'(\d{1,3}(?:[.,]\d{3})+)\s*[-–—]\s*(\d{1,3}(?:[.,]\d{3})+)\s*(?:đồng|đ|vnđ)\s*/\s*kg',
    caseSensitive: false,
  ).firstMatch(text);
  if (m == null) return [];
  final lo = toNumber(m.group(1)!);
  final hi = toNumber(m.group(2)!);
  if (lo < min || hi > max || lo > hi) return [];
  return [
    PriceRow(region: '$label (thấp nhất)', buy: lo),
    PriceRow(region: '$label (cao nhất)', buy: hi),
  ];
}

const rubberCompanies = [
  Province('Phú Riềng', r'Phú\s*Riềng'),
  Province('Bình Long', r'Bình\s*Long'),
  Province('Mang Yang', r'Mang\s*Yang'),
  Province('Bà Rịa', r'(?:Cao\s*su\s*)?Bà\s*Rịa'),
  Province('Đồng Phú', r'Đồng\s*Phú'),
  Province('Phước Hòa', r'Phước\s*Hòa'),
  Province('Dầu Tiếng', r'Dầu\s*Tiếng'),
  Province('Đồng Nai', r'Cao\s*su\s*Đồng\s*Nai'),
];

/// ===== MỦ CAO SU =====
/// Các trang báo giá cao su viết RẤT nhiều kiểu khác nhau:
///   "540 đồng/độ TSC/kg", "530 đồng/TSC/kg", "420 đồng/TSC",
///   "390 đồng/DRC", "458 - 463 đồng/TSC (loại 2 - loại 1)",
///   "mủ tạp (DRC 60%) 18.000 đồng/kg", "mủ đông DRC (35-44%) 14.600 đồng/kg"
/// Bộ đọc dưới đây bắt được tất cả các kiểu trên, theo 2 lớp:
///   Lớp 1: đọc quanh TÊN CÔNG TY (chính xác, ghi rõ của công ty nào)
///   Lớp 2: nếu không thấy công ty nào, quét CẢ TRANG để vẫn có giá
///
/// Đơn vị:
///   - Mủ nước: đồng trên mỗi ĐỘ TSC (mủ 30 độ, giá 420 -> 12.600đ/kg)
///   - Mủ tạp/mủ đông: đồng trên mỗi ĐỘ DRC, hoặc đồng/kg tuỳ nơi niêm yết

// Cho phép các dấu ngăn cách |, ·, : giữa con số và đơn vị, vì bảng giá
// trên web các công ty cao su thường nằm ở ô riêng ("420 | Đồng/TSC").
const _sep = r'\s*[|·:]?\s*';
// Đơn vị tiền có thể viết: đồng · đ · VND · vnđ (hoặc lược bỏ)
const _cur = r'(?:đồng|đ|VND|vnđ)?\s*';
final _rubberTsc = RegExp(
    r'(\d{3})' + _sep + _cur + r'/?\s*(?:độ\s*)?(?:TSC|mủ)',
    caseSensitive: false);
final _rubberDrc = RegExp(
    r'(\d{3})' + _sep + _cur + r'/?\s*(?:độ\s*)?DRC',
    caseSensitive: false);
final _rubberKg = RegExp(
    r'(\d{1,2}[.,]\d{3})' + _sep + r'(?:đồng|đ|VND|vnđ)\s*/\s*kg',
    caseSensitive: false);

/// Tìm giá NGAY SAU một nhãn loại mủ (ví dụ "mủ nước", "mủ đông").
/// Dùng cho các trang không nhắc tên công ty, chỉ ghi theo loại mủ.
String? _windowAfterLabel(String text, String labelPattern, {int len = 160}) {
  final m = RegExp(labelPattern, caseSensitive: false).firstMatch(text);
  if (m == null) return null;
  final start = m.end;
  final end = (start + len < text.length) ? start + len : text.length;
  return text.substring(start, end);
}

/// Một số trang ghi nhãn TRƯỚC số ("mủ nước 420 đồng/TSC"), số khác ghi
/// nhãn SAU số ("235 – 285 VND/độ TSC mủ nước") -> thử cả hai chiều.
String? _windowAroundLabel(String text, String labelPattern) {
  final m = RegExp(labelPattern, caseSensitive: false).firstMatch(text);
  if (m == null) return null;
  final from = (m.start - 90 < 0) ? 0 : m.start - 90;
  final to = (m.end + 160 < text.length) ? m.end + 160 : text.length;
  return text.substring(from, to);
}

/// Lấy giá TSC lớn nhất trong đoạn (dải "458 - 463" thì lấy 463 = loại 1)
int? _bestTsc(String win) {
  int? best;
  for (final m in _rubberTsc.allMatches(win)) {
    final v = int.parse(m.group(1)!);
    if (v < 150 || v > 900) continue;
    if (best == null || v > best) best = v;
  }
  return best;
}

int? _bestDrc(String win) {
  int? best;
  for (final m in _rubberDrc.allMatches(win)) {
    final v = int.parse(m.group(1)!);
    if (v < 150 || v > 900) continue;
    if (best == null || v > best) best = v;
  }
  return best;
}

int? _bestKg(String win) {
  for (final m in _rubberKg.allMatches(win)) {
    final v = toNumber(m.group(1)!);
    if (v >= 8000 && v <= 40000) return v;
  }
  return null;
}

List<PriceRow> parseRubber(String text) {
  final rows = <PriceRow>[];
  final seen = <String>{};

  void add(String name, int? value, String unit) {
    if (value == null) return;
    if (!seen.add(name)) return;
    rows.add(PriceRow(region: name, buy: value, unit: unit));
  }

  // ----- Lớp 1: theo từng công ty -----
  for (final c in rubberCompanies) {
    final m = RegExp(c.pattern, caseSensitive: false).firstMatch(text);
    if (m == null) continue;
    // Cắt đoạn tại chỗ nhắc tới CÔNG TY KẾ TIẾP, tránh lấy nhầm giá của
    // doanh nghiệp khác (các bài báo liệt kê liền mạch nhiều công ty).
    final start = m.end;
    var end = (start + 300 < text.length) ? start + 300 : text.length;
    final next = RegExp(r'(?:Công\s*ty|Cty|Tại\s+Công)', caseSensitive: false)
        .firstMatch(text.substring(start, end));
    if (next != null && next.start > 20) end = start + next.start;
    final win = text.substring(start, end);

    add('${c.name} — mủ nước', _bestTsc(win), 'đ/độ TSC');
    add('${c.name} — mủ tạp', _bestDrc(win), 'đ/độ DRC');
    add('${c.name} — mủ tạp/đông', _bestKg(win), 'đ/kg');
  }

  // ----- Lớp 2: hai dòng THEO LOẠI MỦ (mủ nước & mủ đông) -----
  // Nhiều trang chỉ ghi theo loại mủ, không nhắc tên công ty. Bà con cũng
  // quan tâm trực tiếp 2 loại này nhất.
  bool has(String key) =>
      rows.any((r) => r.region.toLowerCase().contains(key));

  if (!has('mủ nước')) {
    final win = _windowAroundLabel(text, r'mủ\s*nước');
    if (win != null) add('Thị trường — mủ nước', _bestTsc(win), 'đ/độ TSC');
  }
  if (!has('mủ đông') && !has('mủ tạp')) {
    // gộp cả "mủ tạp" vì nhiều trang chỉ ghi tên này
    final win = _windowAfterLabel(text, r'mủ\s*(?:đông|chén|tạp)');
    if (win != null) {
      final kg = _bestKg(win);
      if (kg != null) {
        add('Thị trường — mủ đông / mủ tạp', kg, 'đ/kg');
      } else {
        add('Thị trường — mủ đông theo độ DRC', _bestDrc(win), 'đ/độ DRC');
      }
    }
  }

  // ----- Lớp 3: quét cả trang nếu vẫn chưa ra gì -----
  if (rows.isEmpty) {
    add('Mủ nước (bình quân doanh nghiệp)', _bestTsc(text), 'đ/độ TSC');
    add('Mủ tạp theo độ DRC', _bestDrc(text), 'đ/độ DRC');

    // mủ tạp / mủ đông tính theo đồng/kg
    final mt = RegExp(r'mủ\s*(?:tạp|đông|chén|nguyên\s*liệu)[\s\S]{0,80}?(\d{1,2}[.,]\d{3})',
            caseSensitive: false)
        .firstMatch(text);
    if (mt != null) {
      final v = toNumber(mt.group(1)!);
      if (v >= 8000 && v <= 40000) add('Mủ tạp / mủ đông', v, 'đ/kg');
    }
  }

  return rows;
}

const coffeeProvinces = [
  Province('Đắk Lắk', r'Đ[ăắ]k\s*L[ăắ]k|Dak\s*Lak'),
  Province('Lâm Đồng', r'Lâm\s*Đồng|Lam\s*Dong'),
  Province('Gia Lai', r'Gia\s*Lai'),
  Province('Đắk Nông', r'Đ[ăắ]k\s*Nông|Dak\s*Nong'),
  Province('Kon Tum', r'Kon\s*Tum'),
];

const pepperProvinces = [
  Province('Đắk Lắk', r'Đ[ăắ]k\s*L[ăắ]k'),
  Province('Đắk Nông', r'Đ[ăắ]k\s*Nông'),
  Province('Gia Lai', r'Gia\s*Lai'),
  Province('Đồng Nai', r'Đồng\s*Nai'),
  Province('Bà Rịa - Vũng Tàu', r'Bà\s*Rịa'),
  Province('Bình Phước', r'Bình\s*Phước'),
];

/// Trung bình các số (bỏ null); trả về null nếu rỗng
int? average(Iterable<int?> nums) {
  final arr = nums.whereType<int>().toList();
  if (arr.isEmpty) return null;
  return (arr.reduce((a, b) => a + b) / arr.length).round();
}

// ---------- Vật nuôi (heo, gà, vịt, trứng...) ----------

/// Một loại vật nuôi/sản phẩm cần bóc giá theo TỪ KHÓA
/// (mỗi loại có khoảng giá hợp lý riêng, ví dụ trứng ~2.000đ/quả
/// còn heo hơi ~60.000đ/kg).
class PriceKeyword {
  final String name;
  final String pattern;
  final int min;
  final int max;
  final String unit;
  const PriceKeyword(this.name, this.pattern, this.min, this.max, this.unit);
}

/// Tìm giá theo từ khóa sản phẩm: với mỗi từ khóa, lấy con số dạng
/// 1.500 / 68.000 xuất hiện gần nhất sau từ khóa (cửa sổ ~140 ký tự),
/// lọc theo khoảng giá hợp lý của riêng sản phẩm đó.
List<PriceRow> parseKeywordPrices(
  String text,
  List<PriceKeyword> items, {
  int windowSize = 140,
}) {
  final rows = <PriceRow>[];
  for (final item in items) {
    final match = RegExp(item.pattern, caseSensitive: false).firstMatch(text);
    if (match == null) continue;
    final start = match.start;
    final end =
        (start + windowSize < text.length) ? start + windowSize : text.length;
    final win = text.substring(start, end);

    int? price;
    for (final m in _priceNum.allMatches(win)) {
      final n = toNumber(m.group(0)!);
      if (n >= item.min && n <= item.max) {
        price = n;
        break;
      }
    }
    if (price == null) continue;

    int? change;
    final up = RegExp(r'tăng\s+(\d{1,3}(?:[.,]\d{3})*)', caseSensitive: false)
        .firstMatch(win);
    final down = RegExp(r'giảm\s+(\d{1,3}(?:[.,]\d{3})*)', caseSensitive: false)
        .firstMatch(win);
    if (up != null) {
      change = toNumber(up.group(1)!);
    } else if (down != null) {
      change = -toNumber(down.group(1)!);
    }
    if (change != null && (change.abs() > item.max * 0.2 || change == 0)) {
      change = null;
    }

    rows.add(PriceRow(
      region: item.name,
      buy: price,
      change: change,
      unit: item.unit,
    ));
  }
  return rows;
}

const pigRegions = [
  Province('Miền Bắc', r'miền\s*Bắc'),
  Province('Miền Trung - Tây Nguyên', r'miền\s*Trung'),
  Province('Miền Nam', r'miền\s*Nam'),
  Province('Đồng Nai', r'Đồng\s*Nai'),
  Province('Hà Nội', r'Hà\s*Nội'),
];

const chickenKeywords = [
  PriceKeyword('Gà công nghiệp (lông trắng)',
      r'gà\s*(?:thịt\s*)?(?:công\s*nghiệp|trắng|lông\s*trắng)', 20000, 60000, 'đ/kg'),
  PriceKeyword('Gà lông màu / tam hoàng',
      r'gà\s*(?:thịt\s*)?(?:lông\s*màu|tam\s*hoàng|màu)', 30000, 90000, 'đ/kg'),
  PriceKeyword(
      'Gà ta / thả vườn', r'gà\s*(?:ta|thả\s*vườn|vườn)', 55000, 180000, 'đ/kg'),
];

const duckKeywords = [
  PriceKeyword('Vịt thịt (siêu thịt)',
      r'(?<!trứng\s)vịt\s*(?:thịt|siêu\s*thịt|hơi)?', 25000, 80000, 'đ/kg'),
  PriceKeyword(
      'Vịt xiêm / ngan', r'(?:vịt\s*xiêm|\bngan\b)', 40000, 120000, 'đ/kg'),
];

const eggKeywords = [
  PriceKeyword('Trứng gà', r'trứng\s*gà', 1000, 5000, 'đ/quả'),
  PriceKeyword('Trứng vịt', r'trứng\s*vịt', 1200, 6000, 'đ/quả'),
  PriceKeyword('Trứng cút', r'trứng\s*cút', 300, 1500, 'đ/quả'),
];

const otherLivestockKeywords = [
  PriceKeyword('Bò hơi', r'bò\s*hơi', 50000, 150000, 'đ/kg'),
  PriceKeyword('Dê hơi', r'dê\s*(?:hơi|thịt)', 80000, 250000, 'đ/kg'),
];

// ---------- Hoa màu (ngô, khoai, đậu...) ----------
// Mỗi loại một khoảng giá hợp lý riêng; từ khóa có kèm loại trừ để không
// bắt nhầm (ví dụ "bắp cải" không phải bắp/ngô, "sắn dây" không phải khoai mì)

const cornKeywords = [
  PriceKeyword('Ngô (bắp) hạt', r'ngô(?!\s*ngọt)|bắp(?!\s*cải)', 3000, 15000, 'đ/kg'),
];

const sweetPotatoKeywords = [
  PriceKeyword('Khoai lang', r'khoai\s*lang', 3000, 35000, 'đ/kg'),
];

const cassavaKeywords = [
  PriceKeyword('Khoai mì (sắn) tươi', r'khoai\s*mì|củ\s*mì|sắn(?!\s*dây)', 1000, 8000, 'đ/kg'),
];

const peanutKeywords = [
  PriceKeyword('Đậu phộng (lạc)', r'đậu\s*phộng|lạc\s*nhân', 15000, 70000, 'đ/kg'),
];

const soybeanKeywords = [
  PriceKeyword('Đậu nành (đậu tương)', r'đậu\s*nành|đậu\s*tương', 8000, 40000, 'đ/kg'),
];

// ---------- Kim loại quý: vàng, bạc, đồng ----------

/// Đọc số linh hoạt cho giá quốc tế: "3.345,6" / "3,345.6" / "38,5" / "3.345"
/// -> làm tròn về số nguyên. Nhận cả dấu chấm/phẩy là thập phân hay ngăn nghìn.
int? toFlexibleNumber(String raw) {
  var s = raw.trim();
  if (s.isEmpty) return null;
  final lastDot = s.lastIndexOf('.');
  final lastComma = s.lastIndexOf(',');
  String intPart = s;
  String decPart = '';
  int sepIdx = -1;
  if (lastDot >= 0 && lastComma >= 0) {
    sepIdx = lastDot > lastComma ? lastDot : lastComma; // dấu sau cùng = thập phân
  } else if (lastDot >= 0 || lastComma >= 0) {
    final idx = lastDot >= 0 ? lastDot : lastComma;
    final tail = s.length - idx - 1;
    if (tail > 0 && tail <= 2) sepIdx = idx; // 1-2 số cuối -> thập phân
  }
  if (sepIdx >= 0) {
    intPart = s.substring(0, sepIdx);
    decPart = s.substring(sepIdx + 1);
  }
  intPart = intPart.replaceAll(RegExp(r'[.,\s]'), '');
  if (intPart.isEmpty) return null;
  final v = double.tryParse('$intPart.${decPart.isEmpty ? '0' : decPart}');
  return v?.round();
}

/// ===== VÀNG: đọc API JSON của vang.today =====
/// API miễn phí, không cần khoá, cập nhật 5 phút/lần, có đủ SJC, PNJ, DOJI,
/// Bảo Tín và vàng thế giới. Giá trong nước đã ở đơn vị ĐỒNG/LƯỢNG.
/// Vì là JSON nên phải đọc THÔ (PriceSource.raw = true).
const vangTodayNames = <String, String>{
  'SJL1L10': 'Vàng miếng SJC',
  'SJ9999': 'Nhẫn SJC 9999',
  'PQHNVM': 'Vàng miếng PNJ',
  'PQHN24NTT': 'Nhẫn PNJ 24K',
  'DOHCML': 'Vàng miếng DOJI',
  'BTSJC': 'Vàng miếng Bảo Tín',
};

List<Map<String, dynamic>> _vangTodayItems(String body) {
  final data = jsonDecode(body);
  if (data is! Map<String, dynamic>) return [];
  final list = data['data'];
  if (list is! List) return [];
  return list.whereType<Map<String, dynamic>>().toList();
}

/// Giá vàng TRONG NƯỚC (đồng/lượng) từ vang.today
List<PriceRow> parseVangTodayGold(String body) {
  final rows = <PriceRow>[];
  try {
    for (final item in _vangTodayItems(body)) {
      final code = item['type_code']?.toString() ?? '';
      final name = vangTodayNames[code];
      if (name == null) continue;
      final buy = (item['buy'] as num?)?.round();
      var sell = (item['sell'] as num?)?.round();
      if (buy == null || buy < 30000000 || buy > 500000000) continue;
      if (sell != null && (sell < buy || sell > buy * 1.3)) sell = null;
      final change = (item['change_buy'] as num?)?.round();
      rows.add(PriceRow(
        region: name,
        buy: buy,
        sell: sell,
        change: (change == null || change == 0) ? null : change,
        unit: 'đ/lượng',
      ));
    }
  } catch (_) {
    return [];
  }
  return rows;
}

/// Vàng THẾ GIỚI (USD/ounce) từ vang.today — sẽ được quy đổi sang đ/lượng
List<PriceRow> parseVangTodayWorld(String body) {
  try {
    for (final item in _vangTodayItems(body)) {
      if (item['type_code']?.toString() != 'XAUUSD') continue;
      final v = (item['buy'] as num?)?.round() ?? (item['sell'] as num?)?.round();
      if (v == null || v < 500 || v > 20000) continue;
      return [PriceRow(region: 'Vàng thế giới', buy: v, unit: 'USD/oz')];
    }
  } catch (_) {/* bỏ qua */}
  return [];
}

/// Giá vàng từ XML CHÍNH THỨC sjc.com.vn
/// LƯU Ý: phải đọc XML THÔ (raw = true) — bộ lọc thẻ HTML sẽ xoá sạch
/// các thuộc tính buy="..." sell="..." khiến không bóc được gì.
List<PriceRow> parseSjcGold(String xml) {
  final rows = <PriceRow>[];
  final seen = <String>{};
  for (final m
      in RegExp(r'<item\b([^>]*)/?>', caseSensitive: false).allMatches(xml)) {
    final attrs = m.group(1)!;
    String? attr(String name) =>
        RegExp('$name\\s*=\\s*"([^"]*)"', caseSensitive: false)
            .firstMatch(attrs)
            ?.group(1);

    final type = (attr('type') ?? '').trim();
    var buy = toNumberSafe(attr('buy') ?? '');
    var sell = toNumberSafe(attr('sell') ?? '');
    if (buy == null || buy <= 0) continue;

    // File có thể ghi theo NGÀN ĐỒNG/lượng -> quy về đồng
    if (buy < 1000000) {
      buy = buy * 1000;
      if (sell != null) sell = sell * 1000;
    }
    if (buy < 30000000 || buy > 500000000) continue;
    if (sell != null && (sell < buy || sell > buy * 1.3)) sell = null;

    final name = type.isEmpty ? 'Vàng SJC' : type;
    if (!seen.add(name)) continue;
    rows.add(PriceRow(region: name, buy: buy, sell: sell, unit: 'đ/lượng'));
    if (rows.length >= 4) break;
  }
  return rows;
}

/// Bộ đọc DỰ PHÒNG: quét cả trang tìm CẶP số trong khoảng giá hợp lý
List<PriceRow> parseMetalGeneric(
  String text,
  String name,
  int min,
  int max,
  String unit,
) {
  final nums = <int>[];
  for (final m in _priceNum.allMatches(text)) {
    final n = toNumber(m.group(0)!);
    if (n >= min && n <= max) nums.add(n);
    if (nums.length >= 2) break;
  }
  if (nums.isEmpty) return [];
  int? sell = nums.length > 1 ? nums[1] : null;
  if (sell != null && (sell < nums[0] || sell > nums[0] * 1.3)) sell = null;
  return [PriceRow(region: name, buy: nums[0], sell: sell, unit: unit)];
}

int? toNumberSafe(String s) {
  final cleaned = s.replaceAll(RegExp(r'[.,\s]'), '');
  return cleaned.isEmpty ? null : int.tryParse(cleaned);
}

/// Tìm CẶP giá mua–bán gần một từ khóa (số hợp lệ thứ 1 = mua, thứ 2 = bán)
List<PriceRow> parseBuySellKeyword(
  String text,
  String name,
  String pattern,
  int min,
  int max,
  String unit, {
  int windowSize = 200,
}) {
  final match = RegExp(pattern, caseSensitive: false).firstMatch(text);
  if (match == null) return [];
  final start = match.start;
  final end =
      (start + windowSize < text.length) ? start + windowSize : text.length;
  final win = text.substring(start, end);
  final nums = <int>[];
  for (final m in _priceNum.allMatches(win)) {
    final n = toNumber(m.group(0)!);
    if (n >= min && n <= max) nums.add(n);
    if (nums.length == 2) break;
  }
  if (nums.isEmpty) return [];
  int? sell = nums.length > 1 ? nums[1] : null;
  if (sell != null && sell < nums[0]) sell = null; // bán phải >= mua
  return [PriceRow(region: name, buy: nums[0], sell: sell, unit: unit)];
}

/// Giá quốc tế (USD) — chấp nhận số thập phân kiểu "38,5" hay "3.345,6"
List<PriceRow> parseWorldMetal(
  String text,
  String name,
  String pattern,
  int min,
  int max,
  String unit, {
  int windowSize = 160,
}) {
  final match = RegExp(pattern, caseSensitive: false).firstMatch(text);
  if (match == null) return [];
  final start = match.start;
  final end =
      (start + windowSize < text.length) ? start + windowSize : text.length;
  final win = text.substring(start, end);
  for (final m
      in RegExp(r'\d{1,3}(?:[.,]\d{3})*(?:[.,]\d{1,2})?').allMatches(win)) {
    final n = toFlexibleNumber(m.group(0)!);
    if (n != null && n >= min && n <= max) {
      return [PriceRow(region: name, buy: n, unit: unit)];
    }
  }
  return [];
}

// ---------- Vật tư đầu vào: phân bón, thức ăn chăn nuôi ----------
// Lãi của bà con nằm ở CHÊNH LỆCH giữa giá bán và giá vật tư, nên cần
// theo dõi cả đầu vào. Khoảng giá đặt rộng vì nguồn có nơi ghi đ/kg,
// nơi ghi đ/bao — bộ lọc chỉ nhận số nằm trong khoảng hợp lý theo kg.

const fertilizerKeywords = [
  PriceKeyword('Đạm Ure', r'(?:phân\s*)?(?:đạm\s*)?ure|urê', 6000, 25000, 'đ/kg'),
  PriceKeyword('DAP', r'\bDAP\b', 12000, 40000, 'đ/kg'),
  PriceKeyword('Kali', r'\bkali\b|KCL', 6000, 25000, 'đ/kg'),
  PriceKeyword('NPK', r'\bNPK\b', 6000, 30000, 'đ/kg'),
  PriceKeyword('Lân', r'\b(?:phân\s*)?lân\b', 2500, 12000, 'đ/kg'),
];

const feedKeywords = [
  PriceKeyword('Cám heo (thức ăn hỗn hợp)',
      r'(?:cám|thức\s*ăn)\s*(?:hỗn\s*hợp\s*)?(?:cho\s*)?(?:heo|lợn)', 8000, 30000, 'đ/kg'),
  PriceKeyword('Cám gà (thức ăn hỗn hợp)',
      r'(?:cám|thức\s*ăn)\s*(?:hỗn\s*hợp\s*)?(?:cho\s*)?gà', 8000, 30000, 'đ/kg'),
  PriceKeyword('Ngô hạt (nguyên liệu)', r'ngô(?!\s*ngọt)|bắp(?!\s*cải)', 5000, 15000, 'đ/kg'),
  PriceKeyword('Khô đậu tương (nguyên liệu)',
      r'khô\s*(?:dầu\s*)?đậu\s*(?:tương|nành)', 8000, 25000, 'đ/kg'),
];
