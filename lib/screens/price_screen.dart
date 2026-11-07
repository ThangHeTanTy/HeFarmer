import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'alert_screen.dart';
import '../services/speech_service.dart';
import '../widgets/price_chart.dart';
import '../services/price_parser.dart';
import '../services/price_service.dart';
import '../theme.dart';

/// Màn hình GIÁ (dùng chung cho nông sản & vật nuôi) — tự tải lại mỗi lần
/// được mở (initState), kéo xuống để tải lại thủ công.
class PriceScreen extends StatefulWidget {
  final String title;
  final List<Commodity> commodityList;
  final String cacheKey;
  /// Được gọi 1 lần khi màn hình có dữ liệu hiển thị đầu tiên
  /// (dùng để tắt màn hình chào ở main.dart)
  final VoidCallback? onDataLoaded;

  /// Tăng lên mỗi lần người dùng BẤM VÀO TAB này. Màn hình chỉ tải lại nếu
  /// dữ liệu đang hiển thị đã cũ (quá 10 phút) — nhờ vậy chuyển qua lại
  /// giữa các tab là hiện ngay, không bắt chờ.
  final int refreshTick;
  const PriceScreen({
    super.key,
    this.title = 'Giá nông sản hôm nay',
    this.commodityList = const [],
    this.cacheKey = 'crop',
    this.onDataLoaded,
    this.refreshTick = 0,
  });

  @override
  State<PriceScreen> createState() => _PriceScreenState();
}

class _PriceScreenState extends State<PriceScreen> {
  List<CommodityResult>? _data;
  bool _loading = false;
  DateTime? _loadedAt;
  static const _conMoi = Duration(minutes: 10);

  @override
  void didUpdateWidget(covariant PriceScreen old) {
    super.didUpdateWidget(old);
    if (widget.refreshTick == old.refreshTick) return;
    final t = _loadedAt;
    if (t != null && DateTime.now().difference(t) < _conMoi) return;
    _load();
  }
  // Các thẻ đang THU GỌN (chạm tiêu đề để đóng/mở) — được nhớ giữa các lần mở
  Set<String> _collapsed = {};

  @override
  void initState() {
    super.initState();
    _loadCollapsed();
    _load();
  }

  Future<void> _loadCollapsed() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('collapsed_cards') ?? [];
    if (mounted) setState(() => _collapsed = saved.toSet());
  }

  Future<void> _toggleCollapsed(String id) async {
    setState(() {
      if (!_collapsed.remove(id)) _collapsed.add(id);
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('collapsed_cards', _collapsed.toList());
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    // 1) Hiện NGAY dữ liệu của lần tải trước (nếu có) cho mượt,
    //    trong lúc chờ dữ liệu mới về phía sau.
    if (_data == null) {
      final cached = await loadCachedResults(widget.cacheKey);
      if (cached != null && mounted && _data == null) {
        setState(() => _data = cached);
        widget.onDataLoaded?.call();
      }
    }
    // 2) Tải dữ liệu mới (các mặt hàng chạy song song)
    try {
      final results = await fetchAllPrices(
        widget.commodityList.isEmpty ? commodities : widget.commodityList,
        cacheKey: widget.cacheKey,
      );
      if (mounted) {
        setState(() {
          _data = results;
          _loadedAt = DateTime.now();
        });
        widget.onDataLoaded?.call();
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.primary,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        children: [
          Text(widget.title,
              style: const TextStyle(
                  fontSize: AppFont.title,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primary)),
          const SizedBox(height: 4),
          const Text(
            'Kéo xuống để tải lại. Màu xanh dương là giá mua, màu cam là giá bán; '
            '▲ xanh lá là tăng, ▼ đỏ là giảm so với hôm trước.',
            style: TextStyle(
                fontSize: AppFont.small, color: AppColors.textMuted, height: 1.4),
          ),
          const SizedBox(height: 12),
          if (_loading && _data != null)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(10)),
              child: const Row(children: [
                SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.5, color: AppColors.primary)),
                SizedBox(width: 10),
                Text('Đang cập nhật giá mới nhất...',
                    style: TextStyle(
                        fontSize: AppFont.small, color: AppColors.primary)),
              ]),
            ),
          if (_loading && _data == null)
            const Padding(
              padding: EdgeInsets.all(30),
              child: Column(children: [
                CircularProgressIndicator(color: AppColors.primary),
                SizedBox(height: 12),
                Text('Đang lấy giá mới nhất...',
                    style: TextStyle(
                        fontSize: AppFont.body, color: AppColors.textMuted)),
              ]),
            ),
          if (_data != null)
            ..._data!.map((r) => _CommodityCard(
                  result: r,
                  collapsed: _collapsed.contains(r.commodity.id),
                  onToggle: () => _toggleCollapsed(r.commodity.id),
                )),
          if (_data != null)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text(
                '* Giá ước tính từ mức tăng/giảm do nguồn công bố.\n'
                'Lưu ý: phần lớn nguồn công khai chỉ niêm yết giá THU MUA tại đại lý; '
                'nơi nào có giá bán ra, ứng dụng sẽ hiển thị, còn lại ghi "—". '
                'Giá chỉ mang tính tham khảo, có thể chênh lệch với đại lý tại địa phương.',
                style: TextStyle(
                    fontSize: AppFont.small,
                    color: AppColors.textMuted,
                    height: 1.4),
              ),
            ),
        ],
      ),
    );
  }
}

class _CommodityCard extends StatelessWidget {
  final CommodityResult result;
  final bool collapsed;
  final VoidCallback onToggle;
  const _CommodityCard({
    required this.result,
    required this.collapsed,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final today = result.days.isNotEmpty ? result.days.last : null;
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Chạm tiêu đề để thu gọn / mở ra
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(10),
            child: Row(children: [
              Text(result.commodity.icon, style: const TextStyle(fontSize: 30)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(result.commodity.name,
                    style: const TextStyle(
                        fontSize: AppFont.big,
                        fontWeight: FontWeight.w900,
                        color: AppColors.text)),
              ),
              // Khi thu gọn vẫn hiện nhanh giá hôm nay
              if (collapsed && today != null && today.avgBuy != null)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Text(formatVnd(today.avgBuy),
                      style: const TextStyle(
                          fontSize: AppFont.body,
                          fontWeight: FontWeight.w800,
                          color: AppColors.buy)),
                ),
              // Nút loa: đọc to giá cho bác nào mắt kém
              if (today != null && today.avgBuy != null)
                IconButton(
                  tooltip: 'Đọc to giá',
                  icon: const Text('🔊', style: TextStyle(fontSize: 26)),
                  onPressed: () => speak(buildPriceSentence(
                    name: result.commodity.name,
                    buy: today.avgBuy,
                    sell: today.avgSell,
                    unit: result.commodity.unit,
                    change: result.rows.isEmpty ? null : result.rows.first.change,
                  )),
                ),
              Icon(collapsed ? Icons.expand_more : Icons.expand_less,
                  size: 32, color: AppColors.textMuted),
            ]),
          ),
          if (collapsed)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text('Chạm để xem chi tiết',
                  style: TextStyle(
                      fontSize: AppFont.small, color: AppColors.textMuted)),
            ),
          if (!collapsed) ...[
          const SizedBox(height: 10),
          if (result.error != null)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: AppColors.downBg,
                  borderRadius: BorderRadius.circular(8)),
              child: Text(result.error!,
                  style: const TextStyle(
                      fontSize: AppFont.small,
                      color: AppColors.down,
                      height: 1.4)),
            ),
          if (today != null && today.avgBuy != null)
            Row(children: [
              Expanded(
                  child: _PriceBox(
                      label: 'GIÁ MUA TB',
                      value: formatVnd(today.avgBuy),
                      unit: result.commodity.unit,
                      color: AppColors.buy,
                      bg: AppColors.buyBg)),
              const SizedBox(width: 10),
              Expanded(
                  child: _PriceBox(
                      label: 'GIÁ BÁN TB',
                      value: formatVnd(today.avgSell),
                      unit: result.commodity.unit,
                      color: AppColors.sell,
                      bg: AppColors.sellBg)),
            ]),
          if (result.rows.isNotEmpty) ...[
            const SizedBox(height: 12),
            _RegionTable(rows: result.rows),
          ],
          if (result.days.isNotEmpty) ...[
            const SizedBox(height: 12),
            _ThreeDayTable(days: result.days, unit: result.commodity.unit),
          ],
          // Hai nút hành động: tính tiền bán & đặt cảnh báo giá
          if (today != null && today.avgBuy != null) ...[
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => showSellCalculator(
                    context,
                    commodityName: result.commodity.name,
                    price: today.avgBuy!,
                    unit: result.commodity.unit,
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: const BorderSide(color: AppColors.primary, width: 2),
                  ),
                  child: const Text('🧮  Tính tiền',
                      style: TextStyle(
                          fontSize: AppFont.small,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => showPriceChart(
                    context,
                    commodityId: result.commodity.id,
                    commodityName: result.commodity.name,
                    unit: result.commodity.unit,
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: const BorderSide(color: AppColors.buy, width: 2),
                  ),
                  child: const Text('📈  Biểu đồ',
                      style: TextStyle(
                          fontSize: AppFont.small,
                          fontWeight: FontWeight.w800,
                          color: AppColors.buy)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () async {
                    await showAlertDialog(
                      context,
                      commodityId: result.commodity.id,
                      commodityName: result.commodity.name,
                      unit: result.commodity.unit,
                      currentPrice: today.avgBuy,
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: const BorderSide(color: AppColors.sell, width: 2),
                  ),
                  child: const Text('🔔  Báo giá',
                      style: TextStyle(
                          fontSize: AppFont.small,
                          fontWeight: FontWeight.w800,
                          color: AppColors.sell)),
                ),
              ),
            ]),
          ],
          if (result.sourceName != null) ...[
            const SizedBox(height: 10),
            Text(
              'Nguồn: ${result.sourceName} · cập nhật '
              '${result.fetchedAt.hour.toString().padLeft(2, '0')}:${result.fetchedAt.minute.toString().padLeft(2, '0')}',
              style: const TextStyle(
                  fontSize: AppFont.small, color: AppColors.textMuted),
            ),
          ],
          ], // hết phần chỉ hiện khi MỞ RỘNG (!collapsed)
        ],
      ),
    );
  }
}

class _PriceBox extends StatelessWidget {
  final String label, value, unit;
  final Color color, bg;
  const _PriceBox(
      {required this.label,
      required this.value,
      required this.unit,
      required this.color,
      required this.bg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Column(children: [
        Text(label,
            style: TextStyle(
                fontSize: AppFont.small,
                fontWeight: FontWeight.w800,
                color: color)),
        const SizedBox(height: 2),
        FittedBox(
          child: Text(value,
              style: TextStyle(
                  fontSize: AppFont.huge - 6,
                  fontWeight: FontWeight.w900,
                  color: color)),
        ),
        Text(unit,
            style: const TextStyle(
                fontSize: AppFont.small, color: AppColors.textMuted)),
      ]),
    );
  }
}

class _RegionTable extends StatelessWidget {
  final List<PriceRow> rows;
  const _RegionTable({required this.rows});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      const _TableHeader(first: 'Khu vực', second: 'Giá mua', third: 'Giá bán'),
      ...rows.map((r) => Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: const BoxDecoration(
                border:
                    Border(bottom: BorderSide(color: AppColors.border))),
            child: Row(children: [
              Expanded(
                flex: 20,
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(r.region,
                          style: const TextStyle(
                              fontSize: AppFont.body,
                              fontWeight: FontWeight.w600,
                              color: AppColors.text)),
                      if (r.unit != null)
                        Text(r.unit!,
                            style: const TextStyle(
                                fontSize: AppFont.small,
                                color: AppColors.textMuted)),
                      if (r.change != null) _ChangeBadge(change: r.change!),
                    ]),
              ),
              Expanded(
                  flex: 14,
                  child: Text(formatVnd(r.buy),
                      style: const TextStyle(
                          fontSize: AppFont.body,
                          fontWeight: FontWeight.w800,
                          color: AppColors.buy))),
              Expanded(
                  flex: 14,
                  child: Text(formatVnd(r.sell),
                      style: const TextStyle(
                          fontSize: AppFont.body,
                          fontWeight: FontWeight.w800,
                          color: AppColors.sell))),
            ]),
          )),
    ]);
  }
}

class _ChangeBadge extends StatelessWidget {
  final int change;
  const _ChangeBadge({required this.change});

  @override
  Widget build(BuildContext context) {
    final up = change > 0;
    final flat = change == 0;
    final bg = flat ? AppColors.flatBg : (up ? AppColors.upBg : AppColors.downBg);
    final color = flat ? AppColors.flat : (up ? AppColors.up : AppColors.down);
    final label = flat
        ? '― đứng giá'
        : '${up ? '▲ +' : '▼ -'}${formatVnd(change.abs())}';
    return Container(
      margin: const EdgeInsets.only(top: 3),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(label,
          style: TextStyle(
              fontSize: AppFont.small,
              fontWeight: FontWeight.w800,
              color: color)),
    );
  }
}

class _ThreeDayTable extends StatelessWidget {
  final List<DaySummary> days;
  final String unit;
  const _ThreeDayTable({required this.days, required this.unit});

  Color _colorFor(int i, int? Function(DaySummary) field) {
    if (i == 0) return AppColors.text;
    final cur = field(days[i]);
    final prev = field(days[i - 1]);
    if (cur == null || prev == null || cur == prev) return AppColors.text;
    return cur > prev ? AppColors.up : AppColors.down;
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const _TableHeader(first: 'Ngày', second: 'Giá mua TB', third: 'Giá bán TB'),
      ...List.generate(days.length, (i) {
        final d = days[i];
        final isToday = i == days.length - 1;
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          decoration: BoxDecoration(
            color: isToday ? AppColors.primaryLight : null,
            border: const Border(bottom: BorderSide(color: AppColors.border)),
          ),
          child: Row(children: [
            Expanded(
                flex: 11,
                child: Text(
                    '${formatDateVn(d.date)}${d.estimated ? ' *' : ''}',
                    style: const TextStyle(
                        fontSize: AppFont.body,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text))),
            Expanded(
                flex: 16,
                child: Text(formatVnd(d.avgBuy),
                    style: TextStyle(
                        fontSize: AppFont.body,
                        fontWeight: FontWeight.w800,
                        color: _colorFor(i, (x) => x.avgBuy)))),
            Expanded(
                flex: 16,
                child: Text(formatVnd(d.avgSell),
                    style: TextStyle(
                        fontSize: AppFont.body,
                        fontWeight: FontWeight.w800,
                        color: _colorFor(i, (x) => x.avgSell)))),
          ]),
        );
      }),
      const SizedBox(height: 6),
      Text('Đơn vị: $unit. Dòng dưới cùng là hôm nay.',
          style: const TextStyle(
              fontSize: AppFont.small, color: AppColors.textMuted)),
    ]);
  }
}

class _TableHeader extends StatelessWidget {
  final String first, second, third;
  const _TableHeader(
      {required this.first, required this.second, required this.third});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: const BoxDecoration(
          border:
              Border(bottom: BorderSide(color: AppColors.primary, width: 2))),
      child: Row(children: [
        Expanded(
            flex: 20,
            child: Text(first,
                style: const TextStyle(
                    fontSize: AppFont.small,
                    fontWeight: FontWeight.w900,
                    color: AppColors.text))),
        Expanded(
            flex: 14,
            child: Text(second,
                style: const TextStyle(
                    fontSize: AppFont.small,
                    fontWeight: FontWeight.w900,
                    color: AppColors.buy))),
        Expanded(
            flex: 14,
            child: Text(third,
                style: const TextStyle(
                    fontSize: AppFont.small,
                    fontWeight: FontWeight.w900,
                    color: AppColors.sell))),
      ]),
    );
  }
}
