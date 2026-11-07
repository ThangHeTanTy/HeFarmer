import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'price_parser.dart';

/// DỊCH VỤ GIÁ NÔNG SẢN
/// Mỗi mặt hàng có NHIỀU nguồn dự phòng: nguồn 1 lỗi thì tự chuyển sang
/// nguồn 2, 3... Lịch sử giá được lưu vào máy (SharedPreferences) mỗi lần
/// tải thành công để dựng bảng "3 ngày gần nhất". Nếu nguồn có ghi mức
/// "tăng/giảm so với hôm trước", app suy ra giá hôm trước ngay lần mở đầu.
///
/// Nếu sau này bạn mua API trả phí (ví dụ giacaphe.vn), chỉ cần thêm một
/// nguồn mới vào ĐẦU danh sách `sources` của mặt hàng tương ứng.

const _historyKey = 'price_history_v2';
const _fetchTimeout = Duration(seconds: 15);

class PriceSource {
  final String name;
  final String url;
  final List<PriceRow> Function(String text) parse;

  /// Một số trang đăng bảng giá theo BÀI VIẾT CÓ NGÀY trong URL
  /// (ví dụ ...ngay-18-07-2026/). urlCandidates sinh danh sách URL để thử
  /// lần lượt: hôm nay -> lùi dần về trước, gặp bài nào có là dùng.
  final List<String> Function()? urlCandidates;

  /// true = đưa nội dung THÔ cho hàm parse (bắt buộc với nguồn JSON/XML,
  /// vì bộ lọc thẻ HTML sẽ xoá mất thuộc tính buy="..." sell="...")
  final bool raw;

  const PriceSource({
    required this.name,
    required this.url,
    required this.parse,
    this.urlCandidates,
    this.raw = false,
  });
}

/// URL bảng "Giá sản phẩm chăn nuôi (giá tại trại) cả nước" — đăng gần như
/// hằng ngày trên 2 tên miền của Tạp chí Chăn nuôi Việt Nam. Thử 10 ngày
/// gần nhất trên cả 2 trang.
List<String> datedChanNuoiUrls() {
  final urls = <String>[];
  final now = DateTime.now();
  for (var i = 0; i <= 6; i++) {
    final d = now.subtract(Duration(days: i));
    final slug = 'gia-san-pham-chan-nuoi-gia-tai-trai-ca-nuoc-ngay-'
        '${d.day.toString().padLeft(2, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-${d.year}';
    urls.add('https://nguoichannuoi.vn/$slug/');
    urls.add('https://nhachannuoi.vn/$slug/');
  }
  return urls;
}

class Commodity {
  final String id;
  final String name;
  final String icon;
  final String unit;
  final List<PriceSource> sources;
  const Commodity({
    required this.id,
    required this.name,
    required this.icon,
    required this.unit,
    required this.sources,
  });
}

class DaySummary {
  final String date; // yyyy-MM-dd
  final int? avgBuy;
  final int? avgSell;
  final bool estimated;
  const DaySummary({
    required this.date,
    this.avgBuy,
    this.avgSell,
    this.estimated = false,
  });
}

class CommodityResult {
  final Commodity commodity;
  final List<PriceRow> rows;
  final List<DaySummary> days; // tối đa 3 ngày, cũ -> mới
  final String? sourceName;
  final DateTime fetchedAt;
  final String? error;
  const CommodityResult({
    required this.commodity,
    required this.rows,
    required this.days,
    required this.fetchedAt,
    this.sourceName,
    this.error,
  });
}

final commodities = <Commodity>[
  Commodity(
    id: 'caosu',
    name: 'Mủ cao su',
    icon: '🌳',
    unit: 'đ/độ TSC',
    sources: [
      // Các trang bảng giá chuyên về cao su, cập nhật hằng ngày
      PriceSource(
        name: 'banggianongsan.com',
        url: 'https://banggianongsan.com/bang-gia-cao-su-hom-nay/',
        parse: (t) => parseRubber(t),
      ),
      PriceSource(
        name: 'chogia.vn',
        url: 'https://chogia.vn/gia-cao-su-hom-nay-47965/',
        parse: (t) => parseRubber(t),
      ),
      // Trang CHÍNH CHỦ của công ty cao su (bảng giá mủ nước / mủ tạp)
      PriceSource(
        name: 'phuriengrubber.vn (chính chủ)',
        url: 'https://www.phuriengrubber.vn/',
        parse: (t) => parseRubber(t),
      ),
      PriceSource(
        name: 'giongcaosu.com',
        url: 'https://giongcaosu.com/bang-gia-cao-su-truc-tuyen/',
        parse: (t) => parseRubber(t),
      ),
      PriceSource(
        name: 'giacaphe.com',
        url: 'https://giacaphe.com/hang-hoa-nong-san/cao-su/',
        parse: (t) => parseRubber(t),
      ),
      // Trang tổng hợp tin giá cao su hằng ngày (bản tin có số liệu doanh nghiệp)
      PriceSource(
        name: 'nongnghiepmoitruong.vn',
        url: 'https://nongnghiepmoitruong.vn/gia-cao-su-hom-nay-tag110937/',
        parse: (t) => parseRubber(t),
      ),
      PriceSource(
        name: 'thuonghieucongluan.com.vn',
        url: 'https://thuonghieucongluan.com.vn/news-tag266774/gia-mu-cao-su',
        parse: (t) => parseRubber(t),
      ),
      PriceSource(
        name: 'giacaphe.com (trực tuyến)',
        url: 'https://giacaphe.com/gia-cao-su-truc-tuyen/',
        parse: (t) => parseRubber(t),
      ),
    ],
  ),
  Commodity(
    id: 'caphe',
    name: 'Cà phê nhân xô',
    icon: '☕',
    unit: 'đ/kg',
    sources: [
      PriceSource(
        name: 'giacaphe.com',
        url: 'https://giacaphe.com/gia-ca-phe-noi-dia/',
        parse: (t) => parseProvincePrices(t, coffeeProvinces, 40000, 200000),
      ),
      PriceSource(
        name: 'webgia.com',
        url: 'https://webgia.com/gia-hang-hoa/ca-phe/',
        parse: (t) => parseProvincePrices(t, coffeeProvinces, 40000, 200000),
      ),
      PriceSource(
        name: 'vietnambiz.vn',
        url: 'https://vietnambiz.vn/gia-ca-phe.html',
        parse: (t) => [
          ...parseProvincePrices(t, coffeeProvinces, 40000, 200000),
          ...parseRange(t, 40000, 200000, 'Tây Nguyên'),
        ],
      ),
    ],
  ),
  Commodity(
    id: 'hotieu',
    name: 'Hồ tiêu',
    icon: '⚫',
    unit: 'đ/kg',
    sources: [
      PriceSource(
        name: 'giatieu.com',
        url: 'https://giatieu.com/',
        parse: (t) => parseProvincePrices(t, pepperProvinces, 60000, 350000),
      ),
      PriceSource(
        name: 'webgia.com',
        url: 'https://webgia.com/gia-hang-hoa/hat-tieu/',
        parse: (t) => parseProvincePrices(t, pepperProvinces, 60000, 350000),
      ),
      PriceSource(
        name: 'vietnambiz.vn',
        url: 'https://vietnambiz.vn/gia-ho-tieu.html',
        parse: (t) => [
          ...parseProvincePrices(t, pepperProvinces, 60000, 350000),
          ...parseRange(t, 60000, 350000, 'Cả nước'),
        ],
      ),
    ],
  ),

  // ---------- Hoa màu ----------
  Commodity(
    id: 'ngo',
    name: 'Ngô (bắp)',
    icon: '🌽',
    unit: 'đ/kg',
    sources: [
      PriceSource(
        name: 'nhabeagri.com',
        url: 'https://nhabeagri.com/gia-nong-san/gia-ngo-moi-nhat/',
        parse: (t) => parseKeywordPrices(t, cornKeywords),
      ),
      PriceSource(
        name: 'hanghoa.anfin.vn',
        url: 'https://hanghoa.anfin.vn/gia-thi-truong/ngo/',
        parse: (t) => parseKeywordPrices(t, cornKeywords),
      ),
      PriceSource(
        name: 'thuonggiaonline.vn',
        url: 'https://thuonggiaonline.vn/gia-nong-san',
        parse: (t) => parseKeywordPrices(t, cornKeywords),
      ),
      PriceSource(
        name: 'vietnambiz.vn',
        url: 'https://vietnambiz.vn/gia-nong-san.html',
        parse: (t) => parseKeywordPrices(t, cornKeywords),
      ),
      PriceSource(
        name: 'webgia.com',
        url: 'https://webgia.com/gia-hang-hoa/',
        parse: (t) => parseKeywordPrices(t, cornKeywords),
      ),
    ],
  ),
  Commodity(
    id: 'khoailang',
    name: 'Khoai lang',
    icon: '🍠',
    unit: 'đ/kg',
    sources: [
      PriceSource(
        name: 'nhabeagri.com',
        url: 'https://nhabeagri.com/gia-nong-san/gia-khoai-lang-moi-nhat/',
        parse: (t) => parseKeywordPrices(t, sweetPotatoKeywords),
      ),
      PriceSource(
        name: 'thuonggiaonline.vn',
        url: 'https://thuonggiaonline.vn/gia-nong-san',
        parse: (t) => parseKeywordPrices(t, sweetPotatoKeywords),
      ),
      PriceSource(
        name: 'vietnambiz.vn',
        url: 'https://vietnambiz.vn/gia-nong-san.html',
        parse: (t) => parseKeywordPrices(t, sweetPotatoKeywords),
      ),
      PriceSource(
        name: 'webgia.com',
        url: 'https://webgia.com/gia-hang-hoa/',
        parse: (t) => parseKeywordPrices(t, sweetPotatoKeywords),
      ),
    ],
  ),
  Commodity(
    id: 'khoaimi',
    name: 'Khoai mì (sắn)',
    icon: '🥔',
    unit: 'đ/kg',
    sources: [
      PriceSource(
        name: 'nhabeagri.com',
        url: 'https://nhabeagri.com/gia-nong-san/gia-khoai-mi-moi-nhat/',
        parse: (t) => parseKeywordPrices(t, cassavaKeywords),
      ),
      PriceSource(
        name: 'nhabeagri.com',
        url: 'https://nhabeagri.com/gia-nong-san/gia-san-moi-nhat/',
        parse: (t) => parseKeywordPrices(t, cassavaKeywords),
      ),
      PriceSource(
        name: 'thuonggiaonline.vn',
        url: 'https://thuonggiaonline.vn/gia-nong-san',
        parse: (t) => parseKeywordPrices(t, cassavaKeywords),
      ),
      PriceSource(
        name: 'vietnambiz.vn',
        url: 'https://vietnambiz.vn/gia-san.html',
        parse: (t) => parseKeywordPrices(t, cassavaKeywords),
      ),
      PriceSource(
        name: 'webgia.com',
        url: 'https://webgia.com/gia-hang-hoa/',
        parse: (t) => parseKeywordPrices(t, cassavaKeywords),
      ),
    ],
  ),
  Commodity(
    id: 'dauphong',
    name: 'Đậu phộng (lạc)',
    icon: '🥜',
    unit: 'đ/kg',
    sources: [
      PriceSource(
        name: 'nhabeagri.com',
        url: 'https://nhabeagri.com/gia-nong-san/gia-dau-phong-moi-nhat/',
        parse: (t) => parseKeywordPrices(t, peanutKeywords),
      ),
      PriceSource(
        name: 'thuonggiaonline.vn',
        url: 'https://thuonggiaonline.vn/gia-nong-san',
        parse: (t) => parseKeywordPrices(t, peanutKeywords),
      ),
      PriceSource(
        name: 'vietnambiz.vn',
        url: 'https://vietnambiz.vn/gia-nong-san.html',
        parse: (t) => parseKeywordPrices(t, peanutKeywords),
      ),
      PriceSource(
        name: 'webgia.com',
        url: 'https://webgia.com/gia-hang-hoa/',
        parse: (t) => parseKeywordPrices(t, peanutKeywords),
      ),
    ],
  ),
  Commodity(
    id: 'daunanh',
    name: 'Đậu nành (đậu tương)',
    icon: '🫘',
    unit: 'đ/kg',
    sources: [
      PriceSource(
        name: 'nhabeagri.com',
        url: 'https://nhabeagri.com/gia-nong-san/gia-dau-tuong-moi-nhat/',
        parse: (t) => parseKeywordPrices(t, soybeanKeywords),
      ),
      PriceSource(
        name: 'hanghoa.anfin.vn',
        url: 'https://hanghoa.anfin.vn/gia-thi-truong/dau-tuong/',
        parse: (t) => parseKeywordPrices(t, soybeanKeywords),
      ),
      PriceSource(
        name: 'thuonggiaonline.vn',
        url: 'https://thuonggiaonline.vn/gia-nong-san',
        parse: (t) => parseKeywordPrices(t, soybeanKeywords),
      ),
      PriceSource(
        name: 'vietnambiz.vn',
        url: 'https://vietnambiz.vn/gia-nong-san.html',
        parse: (t) => parseKeywordPrices(t, soybeanKeywords),
      ),
      PriceSource(
        name: 'webgia.com',
        url: 'https://webgia.com/gia-hang-hoa/',
        parse: (t) => parseKeywordPrices(t, soybeanKeywords),
      ),
    ],
  ),
];

final livestockCommodities = <Commodity>[
  Commodity(
    id: 'heohoi',
    name: 'Heo hơi',
    icon: '🐖',
    unit: 'đ/kg',
    sources: [
      PriceSource(
        name: 'vietnambiz.vn',
        url: 'https://vietnambiz.vn/gia-heo-hoi.html',
        parse: (t) => [
          ...parseProvincePrices(t, pigRegions, 40000, 110000),
          ...parseRange(t, 40000, 110000, 'Cả nước'),
        ],
      ),
      PriceSource(
        name: 'channuoivietnam.com',
        url: 'https://channuoivietnam.com/gia-heo-hoi/',
        parse: (t) => [
          ...parseProvincePrices(t, pigRegions, 40000, 110000),
          ...parseRange(t, 40000, 110000, 'Cả nước'),
        ],
      ),
      PriceSource(
        name: 'webgia.com',
        url: 'https://webgia.com/gia-heo-hoi/',
        parse: (t) => parseProvincePrices(t, pigRegions, 40000, 110000),
      ),
      PriceSource(
        name: 'Tạp chí Chăn nuôi VN (giá tại trại)',
        url: 'https://nguoichannuoi.vn/',
        urlCandidates: datedChanNuoiUrls,
        parse: (t) => parseKeywordPrices(t, const [
          PriceKeyword('Heo thịt (tại trại)', r'heo\s*(?:thịt|hơi)', 40000, 110000, 'đ/kg'),
        ]),
      ),
      PriceSource(
        name: 'vietdvm.com',
        url: 'https://vietdvm.com/gia-heo-hoi.html',
        parse: (t) => [
          ...parseProvincePrices(t, pigRegions, 40000, 110000),
          ...parseRange(t, 40000, 110000, 'Cả nước'),
        ],
      ),
      PriceSource(
        name: 'thanhnien.vn',
        url: 'https://thanhnien.vn/gia-heo-hoi-hom-nay-tags487816.html',
        parse: (t) => parseRange(t, 40000, 110000, 'Cả nước'),
      ),
    ],
  ),
  Commodity(
    id: 'ga',
    name: 'Gà thịt',
    icon: '🐓',
    unit: 'đ/kg',
    sources: [
      PriceSource(
        name: 'Tạp chí Chăn nuôi VN (giá tại trại)',
        url: 'https://nguoichannuoi.vn/',
        urlCandidates: datedChanNuoiUrls,
        parse: (t) => parseKeywordPrices(t, chickenKeywords),
      ),
      PriceSource(
        name: 'channuoivietnam.com',
        url: 'https://channuoivietnam.com/',
        parse: (t) => parseKeywordPrices(t, chickenKeywords),
      ),
      PriceSource(
        name: 'vietnambiz.vn',
        url: 'https://vietnambiz.vn/gia-gia-cam.html',
        parse: (t) => parseKeywordPrices(t, chickenKeywords),
      ),
      PriceSource(
        name: 'thuonggiaonline.vn',
        url: 'https://thuonggiaonline.vn/gia-nong-san',
        parse: (t) => parseKeywordPrices(t, chickenKeywords),
      ),
    ],
  ),
  Commodity(
    id: 'vit',
    name: 'Vịt, ngan',
    icon: '🦆',
    unit: 'đ/kg',
    sources: [
      PriceSource(
        name: 'Tạp chí Chăn nuôi VN (giá tại trại)',
        url: 'https://nguoichannuoi.vn/',
        urlCandidates: datedChanNuoiUrls,
        parse: (t) => parseKeywordPrices(t, duckKeywords),
      ),
      PriceSource(
        name: 'channuoivietnam.com',
        url: 'https://channuoivietnam.com/',
        parse: (t) => parseKeywordPrices(t, duckKeywords),
      ),
      PriceSource(
        name: 'vietnambiz.vn',
        url: 'https://vietnambiz.vn/gia-gia-cam.html',
        parse: (t) => parseKeywordPrices(t, duckKeywords),
      ),
      PriceSource(
        name: 'thuonggiaonline.vn',
        url: 'https://thuonggiaonline.vn/gia-nong-san',
        parse: (t) => parseKeywordPrices(t, duckKeywords),
      ),
    ],
  ),
  Commodity(
    id: 'trung',
    name: 'Trứng',
    icon: '🥚',
    unit: 'đ/quả',
    sources: [
      PriceSource(
        name: 'Tạp chí Chăn nuôi VN (giá tại trại)',
        url: 'https://nguoichannuoi.vn/',
        urlCandidates: datedChanNuoiUrls,
        parse: (t) => parseKeywordPrices(t, eggKeywords),
      ),
      PriceSource(
        name: 'channuoivietnam.com',
        url: 'https://channuoivietnam.com/',
        parse: (t) => parseKeywordPrices(t, eggKeywords),
      ),
      PriceSource(
        name: 'vietnambiz.vn',
        url: 'https://vietnambiz.vn/gia-gia-cam.html',
        parse: (t) => parseKeywordPrices(t, eggKeywords),
      ),
      PriceSource(
        name: 'thuonggiaonline.vn',
        url: 'https://thuonggiaonline.vn/gia-nong-san',
        parse: (t) => parseKeywordPrices(t, eggKeywords),
      ),
    ],
  ),
  Commodity(
    id: 'bode',
    name: 'Bò, dê hơi',
    icon: '🐄',
    unit: 'đ/kg',
    sources: [
      PriceSource(
        name: 'Tạp chí Chăn nuôi VN (giá tại trại)',
        url: 'https://nguoichannuoi.vn/',
        urlCandidates: datedChanNuoiUrls,
        parse: (t) => parseKeywordPrices(t, otherLivestockKeywords),
      ),
      PriceSource(
        name: 'channuoivietnam.com',
        url: 'https://channuoivietnam.com/',
        parse: (t) => parseKeywordPrices(t, otherLivestockKeywords),
      ),
      PriceSource(
        name: 'thuonggiaonline.vn',
        url: 'https://thuonggiaonline.vn/gia-nong-san',
        parse: (t) => parseKeywordPrices(t, otherLivestockKeywords),
      ),
    ],
  ),
];


// ---------- Tỷ giá USD/VND để quy đổi giá thế giới sang VNĐ ----------
// Người cao tuổi khó hình dung USD, nên MỌI GIÁ THẾ GIỚI trong app đều được
// quy đổi sẵn sang đồng/lượng (1 lượng vàng ta = 1,20565 ounce).
double? _usdVndRate;
const _ozPerLuong = 1.20565;

Future<void> _ensureUsdVndRate(SharedPreferences prefs) async {
  try {
    final res = await http
        .get(Uri.parse('https://open.er-api.com/v6/latest/USD'))
        .timeout(const Duration(seconds: 10));
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final v = ((data['rates'] as Map<String, dynamic>?)?['VND'] as num?)
          ?.toDouble();
      if (v != null && v > 15000 && v < 60000) {
        _usdVndRate = v;
        await prefs.setDouble('usd_vnd_rate', v);
        return;
      }
    }
  } catch (_) {/* rơi xuống dùng tỷ giá đã lưu */}
  _usdVndRate ??= prefs.getDouble('usd_vnd_rate');
}

/// USD/ounce -> đồng/lượng. Chưa có tỷ giá thì ẩn dòng thế giới
/// (nhất quyết không hiển thị USD gây rối cho người cao tuổi).
List<PriceRow> _ozUsdToVndLuong(List<PriceRow> usdRows) {
  final rate = _usdVndRate;
  if (rate == null) return [];
  return usdRows
      .map((r) => PriceRow(
            region: '${r.region} (quy đổi)',
            buy: (r.buy * rate * _ozPerLuong).round(),
            unit: 'đ/lượng',
          ))
      .toList();
}

/// Kim loại quý — người lớn tuổi rất quan tâm giá vàng!
/// Vàng có CẢ giá mua & giá bán (nguồn niêm yết 2 chiều).
final metalsCommodities = <Commodity>[
  Commodity(
    id: 'vang',
    name: 'Vàng',
    icon: '🪙',
    unit: 'đ/lượng',
    sources: [
      // ƯU TIÊN 1: API JSON (SJC, PNJ, DOJI, Bảo Tín) — không phụ thuộc HTML
      PriceSource(
        name: 'vang.today (SJC, PNJ, DOJI, Bảo Tín)',
        url: 'https://www.vang.today/api/prices',
        raw: true,
        parse: (t) => [
          ...parseVangTodayGold(t),
          ..._ozUsdToVndLuong(parseVangTodayWorld(t)),
        ],
      ),
      // ƯU TIÊN 2: XML CHÍNH THỨC của SJC (đọc thô)
      PriceSource(
        name: 'sjc.com.vn (chính thức)',
        url: 'https://sjc.com.vn/xml/tygiavang.xml',
        raw: true,
        parse: (t) => parseSjcGold(t),
      ),
      PriceSource(
        name: 'sjc.com.vn (dự phòng)',
        url: 'http://www.sjc.com.vn/xml/tygiavang.xml',
        raw: true,
        parse: (t) => parseSjcGold(t),
      ),
      // ƯU TIÊN 3: các trang phổ biến
      PriceSource(
        name: 'pnj.com.vn',
        url: 'https://www.pnj.com.vn/blog/gia-vang/',
        parse: (t) => parseMetalGeneric(
            t, 'Vàng PNJ (trong nước)', 60000000, 400000000, 'đ/lượng'),
      ),
      PriceSource(
        name: 'phuquygroup.vn',
        url: 'https://phuquygroup.vn/gia-vang',
        parse: (t) => parseMetalGeneric(
            t, 'Vàng Phú Quý (trong nước)', 60000000, 400000000, 'đ/lượng'),
      ),
      PriceSource(
        name: 'btmc.vn (Bảo Tín Minh Châu)',
        url: 'https://btmc.vn/bang-gia-vang',
        parse: (t) => parseMetalGeneric(
            t, 'Vàng Bảo Tín (trong nước)', 60000000, 400000000, 'đ/lượng'),
      ),
      PriceSource(
        name: 'webgia.com',
        url: 'https://webgia.com/gia-vang/',
        parse: (t) => [
          ...parseBuySellKeyword(t, 'Vàng miếng SJC (trong nước)',
              r'SJC\s*(?:1\s*L|1L|miếng)', 60000000, 400000000, 'đ/lượng'),
          ...parseBuySellKeyword(t, 'Vàng nhẫn 9999 (trong nước)',
              r'nhẫn', 50000000, 400000000, 'đ/lượng'),
        ],
      ),
      PriceSource(
        name: 'vietnambiz.vn',
        url: 'https://vietnambiz.vn/gia-vang.html',
        parse: (t) => parseMetalGeneric(
            t, 'Vàng miếng SJC (trong nước)', 60000000, 400000000, 'đ/lượng'),
      ),
    ],
  ),
  Commodity(
    id: 'bac',
    name: 'Bạc',
    icon: '🥈',
    unit: 'đ/lượng',
    sources: [
      PriceSource(
        name: 'phuquygroup.vn (Phú Quý)',
        url: 'https://phuquygroup.vn/gia-bac',
        parse: (t) => parseMetalGeneric(
            t, 'Bạc miếng Phú Quý', 500000, 15000000, 'đ/lượng'),
      ),
      PriceSource(
        name: 'giabac.net',
        url: 'https://giabac.net/',
        parse: (t) => parseMetalGeneric(
            t, 'Bạc miếng (trong nước)', 500000, 15000000, 'đ/lượng'),
      ),
      PriceSource(
        name: 'webgia.com',
        url: 'https://webgia.com/gia-bac/',
        parse: (t) => [
          ...parseBuySellKeyword(t, 'Bạc miếng (trong nước)',
              r'bạc\s*(?:miếng|999|9999|Phú\s*Quý)', 500000, 15000000,
              'đ/lượng'),
          ..._ozUsdToVndLuong(parseWorldMetal(t, 'Bạc thế giới',
              r'(?:bạc\s*)?thế\s*giới|XAG', 10, 300, 'USD/oz')),
        ],
      ),
      PriceSource(
        name: 'vietnambiz.vn',
        url: 'https://vietnambiz.vn/gia-bac.html',
        parse: (t) => parseMetalGeneric(
            t, 'Bạc miếng (trong nước)', 500000, 15000000, 'đ/lượng'),
      ),
    ],
  ),
];


/// VẬT TƯ ĐẦU VÀO — phân bón & thức ăn chăn nuôi.
/// Biết giá bán mà không biết giá phân thì mới thấy một nửa câu chuyện.
final inputCommodities = <Commodity>[
  Commodity(
    id: 'phanbon',
    name: 'Phân bón',
    icon: '🧪',
    unit: 'đ/kg',
    sources: [
      PriceSource(
        name: '2nong.vn',
        url: 'https://2nong.vn/gia-phan-bon',
        parse: (t) => parseKeywordPrices(t, fertilizerKeywords),
      ),
      PriceSource(
        name: 'vietnambiz.vn',
        url: 'https://vietnambiz.vn/gia-phan-bon.html',
        parse: (t) => parseKeywordPrices(t, fertilizerKeywords),
      ),
      PriceSource(
        name: 'thuonggiaonline.vn',
        url: 'https://thuonggiaonline.vn/gia-nong-san',
        parse: (t) => parseKeywordPrices(t, fertilizerKeywords),
      ),
      PriceSource(
        name: 'webgia.com',
        url: 'https://webgia.com/gia-hang-hoa/',
        parse: (t) => parseKeywordPrices(t, fertilizerKeywords),
      ),
    ],
  ),
  Commodity(
    id: 'thucanchannuoi',
    name: 'Thức ăn chăn nuôi',
    icon: '🌽',
    unit: 'đ/kg',
    sources: [
      PriceSource(
        name: 'Tạp chí Chăn nuôi VN (giá tại trại)',
        url: 'https://nguoichannuoi.vn/',
        urlCandidates: datedChanNuoiUrls,
        parse: (t) => parseKeywordPrices(t, feedKeywords),
      ),
      PriceSource(
        name: 'channuoivietnam.com',
        url: 'https://channuoivietnam.com/',
        parse: (t) => parseKeywordPrices(t, feedKeywords),
      ),
      PriceSource(
        name: 'vietnambiz.vn',
        url: 'https://vietnambiz.vn/gia-nguyen-lieu-thuc-an-chan-nuoi.html',
        parse: (t) => parseKeywordPrices(t, feedKeywords),
      ),
      PriceSource(
        name: 'thuonggiaonline.vn',
        url: 'https://thuonggiaonline.vn/gia-nong-san',
        parse: (t) => parseKeywordPrices(t, feedKeywords),
      ),
    ],
  ),
];

String todayKey([DateTime? d]) {
  final t = d ?? DateTime.now();
  return '${t.year.toString().padLeft(4, '0')}-'
      '${t.month.toString().padLeft(2, '0')}-'
      '${t.day.toString().padLeft(2, '0')}';
}

String shiftDay(String key, int delta) {
  final d = DateTime.parse(key).add(Duration(days: delta));
  return todayKey(d);
}

// Nhiều mặt hàng dùng chung một trang nguồn -> nhớ tạm theo Future để khi
// tải SONG SONG, cùng một trang chỉ được tải đúng 1 lần (đỡ tốn mạng).
final Map<String, Future<String>> _htmlCache = {};

Future<String> _fetchHtml(String url) {
  return _htmlCache.putIfAbsent(url, () => _doFetchHtml(url));
}

Future<String> _doFetchHtml(String url) async {
  final res = await http.get(
    Uri.parse(url),
    headers: {
      'User-Agent':
          'Mozilla/5.0 (Linux; Android 12) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120 Mobile Safari/537.36',
      'Accept': 'text/html,application/xhtml+xml',
    },
  ).timeout(_fetchTimeout);
  if (res.statusCode != 200) {
    throw Exception('HTTP ${res.statusCode}');
  }
  final body = utf8.decode(res.bodyBytes, allowMalformed: true);
  return body;
}

/// Thử lần lượt các nguồn (và các URL ứng viên của mỗi nguồn)
/// cho tới khi bóc được dữ liệu
Future<(List<PriceRow>, String)> _fetchCommodity(Commodity c) async {
  Object? lastError;
  for (final source in c.sources) {
    final urls = source.urlCandidates?.call() ?? [source.url];
    for (final url in urls) {
      try {
        final html = await _fetchHtml(url);
        final rows = source.parse(source.raw ? html : htmlToText(html));
        if (rows.isNotEmpty) return (rows, source.name);
        lastError = Exception('Không bóc được dữ liệu từ ${source.name}');
      } catch (e) {
        lastError = e;
      }
    }
  }
  final tried = c.sources.map((e) => e.name).join(', ');
  throw Exception(
      '${lastError.toString().replaceFirst('Exception: ', '')} — đã thử: $tried');
}

/// Hàm chính cho màn hình Giá: truyền vào danh sách mặt hàng cần lấy
/// (cây công nghiệp hoặc vật nuôi).
///
/// TỐI ƯU MƯỢT:
/// - Các mặt hàng được tải SONG SONG (Future.wait) thay vì lần lượt,
///   thời gian chờ bằng mặt hàng chậm nhất thay vì tổng cộng.
/// - Kết quả hiển thị được lưu lại (cacheKey) để lần mở sau hiện NGAY
///   dữ liệu cũ trong lúc chờ dữ liệu mới về (stale-while-revalidate).
Future<List<CommodityResult>> fetchAllPrices(
  List<Commodity>? commodityList, {
  String? cacheKey,
}) async {
  _htmlCache.clear(); // mỗi lượt tải lấy dữ liệu mới
  final list = commodityList ?? commodities;
  final prefs = await SharedPreferences.getInstance();
  final Map<String, dynamic> history =
      jsonDecode(prefs.getString(_historyKey) ?? '{}') as Map<String, dynamic>;
  final today = todayKey();

  // Cần tỷ giá để quy đổi giá vàng/bạc thế giới sang VNĐ
  if (list.any((c) => c.id == 'vang' || c.id == 'bac')) {
    await _ensureUsdVndRate(prefs);
  }

  // Tải tất cả mặt hàng song song
  final results = await Future.wait(
    list.map((c) => _processCommodity(c, history, today)),
  );

  // Chỉ giữ 14 ngày gần nhất cho gọn rồi lưu lại
  for (final id in history.keys) {
    final store = history[id] as Map<String, dynamic>;
    final keys = store.keys.toList()..sort();
    if (keys.length > 60) {
      for (final k in keys.sublist(0, keys.length - 60)) {
        store.remove(k);
      }
    }
  }
  await prefs.setString(_historyKey, jsonEncode(history));

  // Lưu kết quả hiển thị cho lần mở sau
  if (cacheKey != null) {
    await _saveResultsCache(prefs, cacheKey, results);
  }

  return results;
}

/// Xử lý 1 mặt hàng (chạy song song với các mặt hàng khác)
Future<CommodityResult> _processCommodity(
  Commodity c,
  Map<String, dynamic> history,
  String today,
) async {
  List<PriceRow> rows = [];
  String? sourceName;
  String? error;

  try {
    final (fetchedRows, name) = await _fetchCommodity(c);
    rows = fetchedRows;
    sourceName = name;

    // CHỈ tính trung bình trên các dòng CÙNG ĐƠN VỊ với mặt hàng.
    // Ví dụ mủ cao su: chỉ lấy các dòng đ/độ TSC, không trộn với đ/kg
    // (trộn vào sẽ ra con số vô nghĩa).
    final sameUnit =
        rows.where((r) => r.unit == null || r.unit == c.unit).toList();
    final base = sameUnit.isEmpty ? rows : sameUnit;
    final avgBuy = average(base.map((r) => r.buy));
    final avgSell = average(base.map((r) => r.sell));
    final avgChange = average(base.map((r) => r.change));

    final store = (history[c.id] as Map<String, dynamic>?) ?? {};
    store[today] = {'avgBuy': avgBuy, 'avgSell': avgSell};

    // Chưa có hôm qua nhưng biết mức tăng/giảm -> ước tính hôm qua
    final yesterday = shiftDay(today, -1);
    if (!store.containsKey(yesterday) && avgChange != null && avgBuy != null) {
      store[yesterday] = {
        'avgBuy': avgBuy - avgChange,
        'avgSell': null,
        'estimated': true,
      };
    }
    history[c.id] = store;
  } catch (e) {
    error =
        'Chưa lấy được giá mới (${e.toString().replaceFirst('Exception: ', '')}). '
        'Đang hiển thị dữ liệu gần nhất đã lưu (nếu có).';
  }

  // Dựng 3 ngày gần nhất từ lịch sử
  final store = (history[c.id] as Map<String, dynamic>?) ?? {};
  final dayKeys = store.keys.toList()..sort();
  final last3 =
      dayKeys.length > 3 ? dayKeys.sublist(dayKeys.length - 3) : dayKeys;
  final days = last3.map((d) {
    final e = store[d] as Map<String, dynamic>;
    return DaySummary(
      date: d,
      avgBuy: (e['avgBuy'] as num?)?.toInt(),
      avgSell: (e['avgSell'] as num?)?.toInt(),
      estimated: (e['estimated'] as bool?) ?? false,
    );
  }).toList();

  return CommodityResult(
    commodity: c,
    rows: rows,
    days: days,
    sourceName: sourceName,
    fetchedAt: DateTime.now(),
    error: error,
  );
}

// ---------- Bộ nhớ kết quả hiển thị (để mở app là thấy ngay) ----------

Commodity? _findCommodity(String id) {
  for (final c in [
    ...commodities,
    ...livestockCommodities,
    ...metalsCommodities,
    ...inputCommodities,
  ]) {
    if (c.id == id) return c;
  }
  return null;
}

Future<void> _saveResultsCache(
  SharedPreferences prefs,
  String cacheKey,
  List<CommodityResult> results,
) async {
  final data = results
      .map((r) => {
            'id': r.commodity.id,
            'rows': r.rows.map((x) => x.toJson()).toList(),
            'days': r.days
                .map((d) => {
                      'date': d.date,
                      'avgBuy': d.avgBuy,
                      'avgSell': d.avgSell,
                      'estimated': d.estimated,
                    })
                .toList(),
            'sourceName': r.sourceName,
            'fetchedAt': r.fetchedAt.toIso8601String(),
          })
      .toList();
  await prefs.setString('results_cache_$cacheKey', jsonEncode(data));
}

/// Đọc kết quả đã lưu của lần tải trước — trả về ngay lập tức, không cần mạng.
Future<List<CommodityResult>?> loadCachedResults(String cacheKey) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('results_cache_$cacheKey');
    if (raw == null) return null;
    final data = jsonDecode(raw) as List;
    final results = <CommodityResult>[];
    for (final item in data) {
      final m = item as Map<String, dynamic>;
      final c = _findCommodity(m['id'] as String);
      if (c == null) continue;
      results.add(CommodityResult(
        commodity: c,
        rows: (m['rows'] as List)
            .map((x) => PriceRow.fromJson(x as Map<String, dynamic>))
            .toList(),
        days: (m['days'] as List).map((d) {
          final e = d as Map<String, dynamic>;
          return DaySummary(
            date: e['date'] as String,
            avgBuy: (e['avgBuy'] as num?)?.toInt(),
            avgSell: (e['avgSell'] as num?)?.toInt(),
            estimated: (e['estimated'] as bool?) ?? false,
          );
        }).toList(),
        sourceName: m['sourceName'] as String?,
        fetchedAt:
            DateTime.tryParse(m['fetchedAt'] as String? ?? '') ?? DateTime.now(),
        error: null,
      ));
    }
    return results.isEmpty ? null : results;
  } catch (_) {
    return null;
  }
}

String formatVnd(int? n) {
  if (n == null) return '—';
  final s = n.abs().toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    final left = s.length - i;
    buf.write(s[i]);
    if (left > 1 && left % 3 == 1) buf.write('.');
  }
  return (n < 0 ? '-' : '') + buf.toString();
}

String formatDateVn(String key) {
  final p = key.split('-');
  return '${p[2]}/${p[1]}';
}

/// Đọc lịch sử giá đã lưu của 1 mặt hàng (tối đa `days` ngày gần nhất)
/// dùng cho biểu đồ. Không cần mạng.
Future<List<DaySummary>> loadPriceHistory(String commodityId,
    {int days = 30}) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final history =
        jsonDecode(prefs.getString(_historyKey) ?? '{}') as Map<String, dynamic>;
    final store = history[commodityId] as Map<String, dynamic>?;
    if (store == null) return [];
    final keys = store.keys.toList()..sort();
    final take = keys.length > days ? keys.sublist(keys.length - days) : keys;
    return take.map((d) {
      final e = store[d] as Map<String, dynamic>;
      return DaySummary(
        date: d,
        avgBuy: (e['avgBuy'] as num?)?.toInt(),
        avgSell: (e['avgSell'] as num?)?.toInt(),
        estimated: (e['estimated'] as bool?) ?? false,
      );
    }).toList();
  } catch (_) {
    return [];
  }
}

// ---------- TẢI SẴN NGẦM cho các tab chưa mở ----------

bool _prefetchDone = false;

/// Sau khi tab đầu tiên có dữ liệu, gọi hàm này để LẦN LƯỢT tải sẵn dữ liệu
/// của các tab còn lại và cất vào bộ nhớ máy. Nhờ vậy khi bác bấm sang tab
/// khác là thấy giá NGAY, không phải chờ tải lại từ đầu.
///
/// Cố ý tải LẦN LƯỢT (không cùng lúc) và nghỉ giữa mỗi tab để máy còn sức
/// vẽ giao diện — tránh giật khi bà con đang cuộn xem giá.
Future<void> prefetchOtherTabs() async {
  if (_prefetchDone) return;
  _prefetchDone = true;

  final tabs = <(String, List<Commodity>)>[
    ('livestock', livestockCommodities),
    ('inputs', inputCommodities),
    ('metals', metalsCommodities),
  ];

  for (final tab in tabs) {
    try {
      await fetchAllPrices(tab.$2, cacheKey: tab.$1);
    } catch (_) {
      // tab nào lỗi thì bỏ qua, khi mở tab đó sẽ tự tải lại
    }
    // nghỉ một nhịp cho giao diện mượt
    await Future<void>.delayed(const Duration(milliseconds: 400));
  }
}
