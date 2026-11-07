import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../services/farm_advice.dart';
import '../services/weather_service.dart';
import '../theme.dart';

const _dayNames = ['Thứ 2', 'Thứ 3', 'Thứ 4', 'Thứ 5', 'Thứ 6', 'Thứ 7', 'CN'];

/// Màn hình THỜI TIẾT — tự tải lại mỗi lần được mở (initState),
/// kéo xuống để tải lại thủ công. Bản đồ Windy nhúng bên dưới.
class WeatherScreen extends StatefulWidget {
  /// Tăng lên mỗi lần bấm vào tab Thời tiết; chỉ tải lại khi dữ liệu đã cũ
  /// (quá 10 phút), nhờ vậy bản đồ Windy không phải vẽ lại mỗi lần chuyển tab.
  final int refreshTick;
  const WeatherScreen({super.key, this.refreshTick = 0});

  @override
  State<WeatherScreen> createState() => _WeatherScreenState();
}

class _WeatherScreenState extends State<WeatherScreen> {
  DeviceLocation? _location;
  WeatherData? _weather;
  String? _error;
  bool _loading = false;
  WebViewController? _mapController;
  bool _fromProfile = false;
  DateTime? _loadedAt;
  static const _conMoi = Duration(minutes: 10);

  @override
  void didUpdateWidget(covariant WeatherScreen old) {
    super.didUpdateWidget(old);
    if (widget.refreshTick == old.refreshTick) return;
    final t = _loadedAt;
    if (t != null && DateTime.now().difference(t) < _conMoi) return;
    _load();
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final pref = await getPreferredLocation();
      final loc = pref.location;
      _fromProfile = pref.fromProfile;
      final w = await fetchWeather(loc.latitude, loc.longitude);
      if (!mounted) return;
      final controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..loadRequest(Uri.parse(windyEmbedUrl(loc.latitude, loc.longitude)));
      setState(() {
        _location = loc;
        _weather = w;
        _mapController = controller;
        _loadedAt = DateTime.now();
      });
    } catch (e) {
      if (mounted) {
        setState(() => _error =
            '${e.toString().replaceFirst('Exception: ', '')}\n\n'
            'Mẹo: vào tab TÀI KHOẢN và đặt "Vị trí của tôi" — '
            'app sẽ luôn lấy thời tiết tại đó, không cần bật GPS.');
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
          const Text('Thời tiết khu vực của bạn',
              style: TextStyle(
                  fontSize: AppFont.title,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primary)),
          if (_location != null)
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('📍 ${_location!.placeName}',
                      style: const TextStyle(
                          fontSize: AppFont.big,
                          fontWeight: FontWeight.w700,
                          color: AppColors.text)),
                  Text(
                    _fromProfile
                        ? 'Theo vị trí bạn đã đặt trong tab Tài khoản'
                        : 'Theo định vị GPS của máy',
                    style: const TextStyle(
                        fontSize: AppFont.small, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
          if (_loading && _weather == null)
            const Padding(
              padding: EdgeInsets.all(30),
              child: Column(children: [
                CircularProgressIndicator(color: AppColors.primary),
                SizedBox(height: 12),
                Text('Đang xác định vị trí và lấy dự báo...',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: AppFont.body, color: AppColors.textMuted)),
              ]),
            ),
          if (_error != null)
            Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: AppColors.downBg,
                  borderRadius: BorderRadius.circular(12)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(_error!,
                      style: const TextStyle(
                          fontSize: AppFont.body,
                          color: AppColors.down,
                          height: 1.4)),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _load,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 14)),
                    child: const Text('Thử lại',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: AppFont.big,
                            fontWeight: FontWeight.w800)),
                  ),
                ],
              ),
            ),
          if (_weather != null) ..._buildWeather(context),
        ],
      ),
    );
  }

  List<Widget> _buildWeather(BuildContext context) {
    final w = _weather!;
    return [
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(14)),
        child: Column(children: [
          Text('${w.temperature}°C',
              style: const TextStyle(
                  fontSize: 56,
                  fontWeight: FontWeight.w900,
                  color: Colors.white)),
          Text(w.description,
              style:
                  const TextStyle(fontSize: AppFont.big, color: Colors.white)),
        ]),
      ),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(
            child: _StatBox(
                icon: '💧', label: 'Độ ẩm', value: '${w.humidity}', unit: '%')),
        const SizedBox(width: 10),
        Expanded(
            child: _StatBox(
                icon: '🌬️',
                label: 'Tốc độ gió',
                value: '${w.windSpeed}',
                unit: 'km/h')),
        const SizedBox(width: 10),
        Expanded(
            child: _StatBox(
                icon: '🌧️',
                label: 'Khả năng mưa',
                value: w.rainProbability?.toString() ?? '—',
                unit: '%',
                highlight: true)),
      ]),
      const SizedBox(height: 14),
      // ===== LỜI KHUYÊN VIỆC NHÀ NÔNG THEO THỜI TIẾT =====
      const Text('Hôm nay nên làm gì?',
          style: TextStyle(
              fontSize: AppFont.big,
              fontWeight: FontWeight.w900,
              color: AppColors.text)),
      const SizedBox(height: 8),
      ...buildFarmAdvice(w).map((a) {
        final (bg, fg) = switch (a.level) {
          AdviceLevel.good => (AppColors.upBg, AppColors.up),
          AdviceLevel.warn => (AppColors.sellBg, AppColors.sell),
          AdviceLevel.danger => (AppColors.downBg, AppColors.down),
          AdviceLevel.info => (AppColors.card, AppColors.textMuted),
        };
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(a.icon, style: const TextStyle(fontSize: 28)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(a.title,
                        style: TextStyle(
                            fontSize: AppFont.body,
                            fontWeight: FontWeight.w900,
                            color: fg)),
                    const SizedBox(height: 2),
                    Text(a.detail,
                        style: const TextStyle(
                            fontSize: AppFont.small,
                            color: AppColors.text,
                            height: 1.35)),
                  ]),
            ),
          ]),
        );
      }),
      const SizedBox(height: 4),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Mấy ngày tới',
              style: TextStyle(
                  fontSize: AppFont.big,
                  fontWeight: FontWeight.w900,
                  color: AppColors.text)),
          const SizedBox(height: 6),
          ...List.generate(w.daily.length, (i) {
            final d = w.daily[i];
            final name = i == 0 ? 'Hôm nay' : _dayNames[d.date.weekday - 1];
            return Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: const BoxDecoration(
                  border:
                      Border(bottom: BorderSide(color: AppColors.border))),
              child: Row(children: [
                Expanded(
                    flex: 14,
                    child: Text('$name ${d.date.day}/${d.date.month}',
                        style: TextStyle(
                            fontSize: AppFont.body,
                            fontWeight: FontWeight.w800,
                            color: i == 0
                                ? AppColors.primary
                                : AppColors.text))),
                Expanded(
                    flex: 16,
                    child: Text(d.desc,
                        style: const TextStyle(
                            fontSize: AppFont.small,
                            color: AppColors.textMuted))),
                Expanded(
                    flex: 10,
                    child: Text('🌧 ${d.rain}%',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                            fontSize: AppFont.body,
                            fontWeight: FontWeight.w800,
                            color: d.rain >= 50
                                ? AppColors.buy
                                : AppColors.textMuted))),
                Expanded(
                    flex: 10,
                    child: Text('${d.tMin}–${d.tMax}°',
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                            fontSize: AppFont.body,
                            fontWeight: FontWeight.w700,
                            color: AppColors.text))),
              ]),
            );
          }),
        ]),
      ),
      const SizedBox(height: 14),
      const Text('Bản đồ mây & mưa (Windy)',
          style: TextStyle(
              fontSize: AppFont.big,
              fontWeight: FontWeight.w900,
              color: AppColors.text)),
      const SizedBox(height: 4),
      const Text(
          'Chạm vào bản đồ để xem chi tiết. Bản đồ tự tải lại mỗi lần bạn mở tab này.',
          style:
              TextStyle(fontSize: AppFont.small, color: AppColors.textMuted)),
      const SizedBox(height: 8),
      if (_mapController != null)
        Container(
          height: 420,
          clipBehavior: Clip.hardEdge,
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border)),
          child: WebViewWidget(controller: _mapController!),
        ),
      const SizedBox(height: 10),
      Text(
        'Dự báo: Open-Meteo (miễn phí) · Bản đồ: Windy.com · Cập nhật '
        '${w.updatedAt.hour.toString().padLeft(2, '0')}:${w.updatedAt.minute.toString().padLeft(2, '0')}',
        style:
            const TextStyle(fontSize: AppFont.small, color: AppColors.textMuted),
      ),
    ];
  }
}

class _StatBox extends StatelessWidget {
  final String icon, label, value, unit;
  final bool highlight;
  const _StatBox(
      {required this.icon,
      required this.label,
      required this.value,
      required this.unit,
      this.highlight = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
          color: highlight ? AppColors.buyBg : AppColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border)),
      child: Column(children: [
        Text(icon, style: const TextStyle(fontSize: 26)),
        const SizedBox(height: 2),
        Text.rich(TextSpan(children: [
          TextSpan(
              text: value,
              style: const TextStyle(
                  fontSize: AppFont.title,
                  fontWeight: FontWeight.w900,
                  color: AppColors.text)),
          TextSpan(
              text: ' $unit',
              style: const TextStyle(
                  fontSize: AppFont.small,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMuted)),
        ])),
        const SizedBox(height: 2),
        Text(label,
            style: const TextStyle(
                fontSize: AppFont.small, color: AppColors.textMuted)),
      ]),
    );
  }
}
