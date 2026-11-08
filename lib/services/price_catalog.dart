/// DANH MỤC MẶT HÀNG & NGUỒN GIÁ — thuần Dart (không phụ thuộc Flutter)
/// để dùng chung cho cả ứng dụng lẫn công cụ tổng hợp giá chạy trên máy chủ
/// (tool/build_prices.dart).
///
/// Mỗi mặt hàng có NHIỀU nguồn dự phòng: nguồn 1 lỗi thì tự chuyển sang
/// nguồn 2, 3... Nếu sau này có API trả phí, chỉ cần thêm một nguồn mới vào
/// ĐẦU danh sách `sources` của mặt hàng tương ứng.
library;

import 'price_parser.dart';

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

  /// Ngày có giá mới nhất (null nếu chưa có gì)
  DaySummary? get latestDay => days.isEmpty ? null : days.last;

  /// Giá này có phải giá THẬT của hôm nay [today] không. Chỉ khi đúng như
  /// vậy mới được dùng để bắn cảnh báo giá — tránh báo theo số của mấy hôm
  /// trước khi mạng lỗi.
  bool isFreshFor(String today) {
    final d = latestDay;
    return error == null &&
        d != null &&
        d.date == today &&
        !d.estimated &&
        d.avgBuy != null;
  }
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
//
// Tỷ giá do price_fetcher.dart tải về rồi đặt vào biến này trước khi
// bóc tách giá vàng/bạc.
double? usdVndRate;
const _ozPerLuong = 1.20565;

/// USD/ounce -> đồng/lượng. Chưa có tỷ giá thì ẩn dòng thế giới
/// (nhất quyết không hiển thị USD gây rối cho người cao tuổi).
List<PriceRow> _ozUsdToVndLuong(List<PriceRow> usdRows) {
  final rate = usdVndRate;
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

/// Mọi mặt hàng của app (dùng khi cần tìm theo id)
List<Commodity> get allCommodities => [
      ...commodities,
      ...livestockCommodities,
      ...inputCommodities,
      ...metalsCommodities,
    ];

Commodity? findCommodity(String id) {
  for (final c in allCommodities) {
    if (c.id == id) return c;
  }
  return null;
}
