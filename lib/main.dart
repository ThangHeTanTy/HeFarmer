import 'package:flutter/material.dart';

import 'dart:async';

import 'screens/account_screen.dart';
import 'screens/my_commodities_screen.dart';
import 'screens/price_screen.dart';
import 'screens/weather_screen.dart';
import 'services/account_service.dart';
import 'services/alert_service.dart';
import 'services/price_service.dart';
import 'services/settings_service.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await loadSettings(); // cỡ chữ, chế độ đơn giản — đọc trước để khỏi nháy
  ErrorWidget.builder = (details) => const Material(
        color: Colors.white,
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Có lỗi hiển thị ở phần này.\nBác thử đóng và mở lại ứng dụng nhé.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, color: AppColors.text),
            ),
          ),
        ),
      );
  runApp(const NongDanApp());
}

class NongDanApp extends StatelessWidget {
  const NongDanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HeFarmer',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
        scaffoldBackgroundColor: AppColors.background,
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          titleTextStyle: TextStyle(
              fontSize: AppFont.big,
              fontWeight: FontWeight.w900,
              color: Colors.white),
        ),
      ),
      // Cỡ chữ bác chọn trong tab Tôi, nhân thêm vào cỡ chữ của điện thoại
      builder: (context, child) => ValueListenableBuilder<AppSettings>(
        valueListenable: appSettings,
        builder: (context, st, _) {
          final mq = MediaQuery.of(context);
          final scale =
              effectiveTextScale(mq.textScaler.scale(1), st.textScale);
          return MediaQuery(
            data: mq.copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          );
        },
      ),
      home: const HomePage(),
    );
  }
}

/// Một tab của thanh dưới
class _TabSpec {
  final String id;
  final String icon;
  final String label; // chữ ngắn dưới biểu tượng
  final String title; // tiêu đề trên cùng
  const _TabSpec(this.id, this.icon, this.label, this.title);
}

const _fullTabs = [
  _TabSpec('crop', '🌱', 'Nông sản', 'Giá nông sản cây công nghiệp'),
  _TabSpec('livestock', '🐓', 'Vật nuôi', 'Giá vật nuôi'),
  _TabSpec('inputs', '🧪', 'Vật tư', 'Giá vật tư đầu vào'),
  _TabSpec('metals', '🪙', 'Vàng bạc', 'Giá vàng - bạc'),
  _TabSpec('weather', '⛅', 'Thời tiết', 'Dự báo thời tiết'),
  _TabSpec('account', '👤', 'Tôi', 'Hồ sơ của tôi'),
];

/// CHẾ ĐỘ ĐƠN GIẢN: chỉ 3 tab, chữ trên thanh tab to hơn
const _simpleTabs = [
  _TabSpec('mine', '🌾', 'Giá của tôi', 'Giá của tôi'),
  _TabSpec('weather', '⛅', 'Thời tiết', 'Dự báo thời tiết'),
  _TabSpec('account', '👤', 'Tôi', 'Hồ sơ của tôi'),
];

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _index = 0;
  // Mỗi tab có bộ đếm riêng: bấm vào tab nào thì chỉ tab đó được nhắc
  // làm mới (và nó cũng chỉ tải lại nếu dữ liệu đã cũ hơn 10 phút).
  final Map<String, int> _ticks = {};
  // Các tab đã từng mở -> giữ nguyên trong bộ nhớ để quay lại là thấy ngay
  late final Set<String> _daMo = {_tabs.first.id};
  late bool _simple = appSettings.value.simpleMode;

  List<_TabSpec> get _tabs => _simple ? _simpleTabs : _fullTabs;

  // ---- Màn hình chào (intro) ----
  bool _introDone = false; // dữ liệu giá đã tải xong -> bắt đầu mờ dần
  String _greetName = '';
  Timer? _introTimeout;
  final DateTime _introStart = DateTime.now();
  static const _introMinShow = Duration(seconds: 2); // đọc kịp lời chào

  @override
  void initState() {
    super.initState();
    // Lấy tên trong hồ sơ (nếu bác đã đặt) để chào cho thân mật
    currentProfile().then((p) {
      if (mounted) setState(() => _greetName = p.name);
    });
    // Phòng khi mạng quá chậm/mất mạng: tối đa 5 giây là vào app
    _introTimeout = Timer(const Duration(seconds: 5), _finishIntro);
    // Chuẩn bị thông báo + kiểm tra cảnh báo giá ngay khi mở app
    _setupAlerts();
    appSettings.addListener(_onSettingsChanged);
    // Chế độ đơn giản mà chưa chọn mặt hàng nào: không có gì để chờ tải
    if (_simple && appSettings.value.myCommodities.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _finishIntro());
    }
  }

  @override
  void dispose() {
    appSettings.removeListener(_onSettingsChanged);
    _introTimeout?.cancel();
    super.dispose();
  }

  /// Bật/tắt chế độ đơn giản (bác đang ở tab Tôi) -> đổi bộ tab, vẫn ở
  /// tab Tôi. Đổi mặt hàng của tôi -> tab "Giá của tôi" tự dựng lại.
  void _onSettingsChanged() {
    final simple = appSettings.value.simpleMode;
    if (simple == _simple) {
      setState(() {});
      return;
    }
    setState(() {
      _simple = simple;
      _index = _tabs.indexWhere((t) => t.id == 'account');
      _daMo.add('account');
    });
  }

  Future<void> _setupAlerts() async {
    try {
      await initNotifications();
      await setupBackgroundCheck();
      await checkAlertsAndNotify();
    } catch (_) {
      // không có quyền thông báo cũng không sao, app vẫn chạy bình thường
    }
  }

  /// Tab giá nông sản đã có dữ liệu: tắt màn hình chào và âm thầm tải sẵn
  /// dữ liệu cho các tab còn lại để chuyển tab là thấy ngay.
  void _khiTabDauTaiXong() {
    _finishIntro();
    // Chế độ đơn giản chỉ có 1 tab giá, không cần tải sẵn tab khác
    if (!_simple) prefetchOtherTabs();
  }

  /// Bấm "Vào ứng dụng ngay" -> vào thẳng, không phải chờ
  void _forceFinishIntro() {
    _introTimeout?.cancel();
    if (mounted && !_introDone) setState(() => _introDone = true);
  }

  void _finishIntro() {
    if (_introDone || !mounted) return;
    // Dữ liệu về quá nhanh (nhờ bộ nhớ đệm) thì vẫn giữ intro đủ 3 giây
    final elapsed = DateTime.now().difference(_introStart);
    if (elapsed < _introMinShow) {
      Timer(_introMinShow - elapsed, _finishIntro);
      return;
    }
    setState(() => _introDone = true);
  }

  void _onTabTap(int i) {
    final id = _tabs[i].id;
    setState(() {
      _index = i;
      _daMo.add(id);
      _ticks[id] = (_ticks[id] ?? 0) + 1;
    });
  }

  /// Dựng nội dung 1 tab. Dùng key CỐ ĐỊNH để trạng thái được giữ nguyên;
  /// việc làm mới do refreshTick quyết định.
  Widget _trangTab(String id) {
    final tick = _ticks[id] ?? 0;
    final first = id == _tabs.first.id;
    PriceScreen price(String title, List<Commodity> list) => PriceScreen(
          key: ValueKey(id),
          title: title,
          commodityList: list,
          cacheKey: id,
          onDataLoaded: first ? _khiTabDauTaiXong : null,
          refreshTick: tick,
        );
    return switch (id) {
      'crop' => price('Giá nông sản hôm nay', commodities),
      'livestock' => price('Giá vật nuôi hôm nay', livestockCommodities),
      'inputs' => price('Giá vật tư đầu vào', inputCommodities),
      'metals' => price('Giá vàng, bạc hôm nay', metalsCommodities),
      'mine' => _myPrices(tick),
      'weather' =>
        WeatherScreen(key: const ValueKey('weather'), refreshTick: tick),
      _ => const AccountScreen(key: ValueKey('account')),
    };
  }

  /// Tab "Giá của tôi" (chế độ đơn giản)
  Widget _myPrices(int tick) {
    final ids = appSettings.value.myCommodities;
    final list = ids.map(findCommodity).whereType<Commodity>().toList();
    if (list.isEmpty) {
      return _ChooseMineHint(onChoose: () => openMyCommoditiesPicker(context));
    }
    return PriceScreen(
      // đổi danh sách mặt hàng -> dựng lại và tải giá mới
      key: ValueKey('mine:${ids.join(',')}'),
      title: 'Giá của tôi hôm nay',
      commodityList: list,
      cacheKey: 'mine',
      onDataLoaded: _khiTabDauTaiXong,
      refreshTick: tick,
    );
  }

  @override
  Widget build(BuildContext context) {
    final tabs = _tabs;
    // Dựng sẵn các tab ĐÃ TỪNG MỞ và giữ chúng sống trong IndexedStack:
    // quay lại tab cũ là hiện ngay, không dựng lại, không mất vị trí cuộn,
    // bản đồ Windy cũng không phải tải lại.
    final body = IndexedStack(
      index: _index,
      children: [
        for (final t in tabs)
          KeyedSubtree(
            key: ValueKey('tab-${t.id}'),
            child: _daMo.contains(t.id)
                ? _trangTab(t.id)
                : const SizedBox.shrink(),
          ),
      ],
    );

    final app = Scaffold(
      appBar: AppBar(title: Text(tabs[_index].title)),
      body: body,
      bottomNavigationBar:
          _BumpTabBar(items: tabs, index: _index, onTap: _onTabTap),
    );

    // App LUÔN được dựng phía sau (StackFit.expand) để dữ liệu tải sẵn;
    // KHÔNG dùng hiệu ứng mờ chồng lớp vì máy ảo yếu dễ vẽ hỏng thành đen.
    return Stack(
      fit: StackFit.expand,
      children: [
        app,
        if (!_introDone)
          IntroScreen(greetName: _greetName, onSkip: _forceFinishIntro),
      ],
    );
  }
}

/// Chế độ đơn giản nhưng chưa chọn mặt hàng nào
class _ChooseMineHint extends StatelessWidget {
  final VoidCallback onChoose;
  const _ChooseMineHint({required this.onChoose});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 20),
        const Center(child: Text('🌾', style: TextStyle(fontSize: 64))),
        const SizedBox(height: 12),
        const Text(
          'Bác chưa chọn mặt hàng nào.\n'
          'Chọn những thứ bác trồng, nuôi để xem giá nhanh ở đây.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: AppFont.big, height: 1.4),
        ),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: onChoose,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text('➕ Chọn mặt hàng của tôi',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: AppFont.big,
                  fontWeight: FontWeight.w800,
                  color: Colors.white)),
        ),
      ],
    );
  }
}

/// THANH TAB DƯỚI với hiệu ứng "BÁN CUNG NỔI": tab đang chọn nhô hẳn lên
/// thành hình tròn vượt qua đường kẻ trên của thanh, có bóng đổ — nhìn là
/// biết ngay mình đang ở đâu, hợp với người cao tuổi.
class _BumpTabBar extends StatelessWidget {
  final List<_TabSpec> items;
  final int index;
  final ValueChanged<int> onTap;
  const _BumpTabBar(
      {required this.items, required this.index, required this.onTap});

  @override
  Widget build(BuildContext context) {
    // Ít tab (chế độ đơn giản) thì chữ dưới biểu tượng to hẳn lên
    final few = items.length <= 3;
    final labelSize = few ? 16.0 : 11.5;
    // Thanh tab cao cố định: 6 tab thì giữ cỡ chữ gốc (biểu tượng đã đủ
    // to), 3 tab thì cho chữ to thêm
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: few ? 1.2 : 1.0,
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          // đường thẳng trên của thanh tab — bán cung sẽ nổi vượt qua nó
          border: Border(top: BorderSide(color: AppColors.border, width: 1.5)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 76,
            child: Row(
              children: List.generate(items.length, (i) {
                final selected = i == index;
                final icon = items[i].icon;
                final label = items[i].label;
                return Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onTap(i),
                    child: Stack(
                      clipBehavior: Clip.none, // cho phép nổi ra NGOÀI thanh
                      alignment: Alignment.topCenter,
                      children: [
                        // nhãn chữ nằm sát đáy
                        Positioned(
                          bottom: 8,
                          child: Text(
                            label,
                            style: TextStyle(
                              fontSize: selected ? labelSize + 1 : labelSize,
                              fontWeight:
                                  selected ? FontWeight.w900 : FontWeight.w600,
                              color: selected
                                  ? AppColors.primary
                                  : AppColors.textMuted,
                            ),
                          ),
                        ),
                        // biểu tượng: chọn thì thành hình tròn NỔI BÁN CUNG
                        AnimatedPositioned(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOutBack,
                          top: selected ? -22 : 10,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            width: selected ? 52 : 32,
                            height: selected ? 52 : 32,
                            alignment: Alignment.center,
                            decoration: selected
                                ? BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: AppColors.primary, width: 3),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0x2E000000),
                                        blurRadius: 10,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  )
                                : null,
                            child: Text(icon,
                                style: TextStyle(fontSize: selected ? 27 : 22)),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

/// MÀN HÌNH CHÀO: dùng đúng hình icon của app + lời chào theo buổi.
/// Hiện trong lúc tab Giá nông sản đang tải; tải xong sẽ mờ dần rồi biến mất.
class IntroScreen extends StatelessWidget {
  final String greetName;
  final VoidCallback? onSkip;
  const IntroScreen({super.key, this.greetName = '', this.onSkip});

  String get _greeting {
    final h = DateTime.now().hour;
    if (h >= 5 && h <= 10) return 'Chào buổi sáng';
    if (h >= 11 && h <= 13) return 'Chào buổi trưa';
    if (h >= 14 && h <= 17) return 'Chào buổi chiều';
    return 'Chào buổi tối';
  }

  String get _wish {
    final h = DateTime.now().hour;
    if (h >= 5 && h <= 10) return 'Chúc bác một ngày làm việc thuận lợi! ☀️';
    if (h >= 11 && h <= 13) return 'Bác nhớ nghỉ trưa cho khỏe nhé! 🍚';
    if (h >= 14 && h <= 17) return 'Chúc buổi chiều mát mẻ, được giá! 🌾';
    return 'Chúc bác buổi tối ấm áp, ngủ ngon! 🌙';
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFBEE7F7), Color(0xFFE8F5E9)],
          ),
        ),
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(48),
              child: Image.asset(
                'assets/icon/icon.png',
                width: 220,
                height: 220,
                errorBuilder: (_, __, ___) =>
                    const Text('👨‍🌾', style: TextStyle(fontSize: 120)),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              greetName.isEmpty ? '$_greeting!' : '$_greeting, $greetName!',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primary),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _wish,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: AppFont.body, color: AppColors.textMuted),
              ),
            ),
            const SizedBox(height: 40),
            const SizedBox(
              width: 30,
              height: 30,
              child: CircularProgressIndicator(
                  color: AppColors.primary, strokeWidth: 3.5),
            ),
            const SizedBox(height: 12),
            const Text('Đang tải giá nông sản hôm nay...',
                style: TextStyle(
                    fontSize: AppFont.small, color: AppColors.textMuted)),
            const SizedBox(height: 12),
            if (onSkip != null)
              TextButton(
                onPressed: onSkip,
                child: const Text('Vào ứng dụng ngay',
                    style: TextStyle(
                        fontSize: AppFont.body,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary)),
              ),
          ],
        ),
      ),
    );
  }
}
