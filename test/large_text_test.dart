import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hefarmer/screens/account_screen.dart';
import 'package:hefarmer/screens/my_commodities_screen.dart';
import 'package:hefarmer/screens/price_screen.dart';
import 'package:hefarmer/services/account_service.dart';
import 'package:hefarmer/services/price_parser.dart';
import 'package:hefarmer/services/price_service.dart';
import 'package:hefarmer/services/settings_service.dart';
import 'package:hefarmer/services/updater.dart';
import 'package:hefarmer/widgets/update_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// CHỮ TO KHÔNG ĐƯỢC LÀM VỠ GIAO DIỆN: vẽ các màn hình chính ở cỡ chữ lớn
/// nhất (1,6 lần) trên điện thoại màn hình nhỏ (320 điểm ảnh ngang). Nếu có
/// chỗ tràn (RenderFlex overflow), Flutter báo lỗi và test thất bại.

List<CommodityResult> fakeResults() {
  final today = todayKey();
  final y = shiftDay(today, -1);
  final y2 = shiftDay(today, -2);
  List<DaySummary> days(int a, int b, int c) => [
        DaySummary(date: y2, avgBuy: a),
        DaySummary(date: y, avgBuy: b, estimated: true),
        DaySummary(date: today, avgBuy: c, avgSell: c + 1500),
      ];
  return [
    CommodityResult(
      commodity: findCommodity('caphe')!,
      rows: const [
        PriceRow(region: 'Đắk Lắk', buy: 98500, sell: 99800, change: 1200),
        PriceRow(region: 'Lâm Đồng', buy: 97800, change: -500),
        PriceRow(region: 'Gia Lai', buy: 98300, change: 0),
      ],
      days: days(96000, 97300, 98200),
      sourceName: 'giacaphe.com',
      fetchedAt: DateTime.now(),
    ),
    CommodityResult(
      commodity: findCommodity('caosu')!,
      rows: const [
        PriceRow(region: 'Mang Yang — mủ nước', buy: 420, unit: 'đ/độ TSC'),
        PriceRow(
            region: 'Thị trường — mủ đông theo độ DRC',
            buy: 380,
            unit: 'đ/độ DRC'),
      ],
      days: days(410, 415, 420),
      sourceName: 'banggianongsan.com',
      fetchedAt: DateTime.now(),
    ),
    // Giá vàng: con số rất dài
    CommodityResult(
      commodity: findCommodity('vang')!,
      rows: const [
        PriceRow(
            region: 'Vàng miếng SJC (trong nước)',
            buy: 152500000,
            sell: 155500000,
            unit: 'đ/lượng'),
      ],
      days: days(150000000, 151000000, 152500000),
      sourceName: 'vang.today',
      fetchedAt: DateTime.now(),
    ),
    // Giá cũ + lỗi
    CommodityResult(
      commodity: findCommodity('hotieu')!,
      rows: const [PriceRow(region: 'Đắk Nông', buy: 141000)],
      days: [DaySummary(date: y2, avgBuy: 141000)],
      sourceName: 'giatieu.com',
      fetchedAt: DateTime.now().subtract(const Duration(days: 2)),
      error: 'Hôm nay các nguồn chưa đăng giá mới. Đang hiển thị giá ngày '
          '${formatDateVn(y2)}.',
    ),
  ];
}

Widget scaled(double scale, Widget home) => MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: home,
    );

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    appSettings.value = const AppSettings();
  });

  for (final width in [320.0, 360.0]) {
    for (final scale in [1.0, 1.3, maxTextScale]) {
      testWidgets('màn hình Giá: rộng $width, chữ ×$scale không tràn',
          (tester) async {
        tester.view.physicalSize = Size(width, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(scaled(
          scale,
          Scaffold(
            body: PriceScreen(
              commodityList: const [],
              cacheKey: 'test',
              loadPrices: (list, {cacheKey}) async => fakeResults(),
              loadHome: () async => const HomeLocation(
                  latitude: 12.667, longitude: 108.038, label: 'Đắk Lắk'),
            ),
          ),
        ));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Cuộn dần xuống, vẽ từng thẻ (lỗi tràn sẽ làm test thất bại)
        Future<void> see(Finder f) async {
          await tester.scrollUntilVisible(f, 200,
              scrollable: find.byType(Scrollable).first);
          expect(f, findsOneWidget);
        }

        await see(find.textContaining('Gần nhà bác: Đắk Lắk'));
        await see(find.text('Vàng'));
        await see(find.textContaining('chưa đăng giá mới'));
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('tab Tôi (cỡ chữ, chế độ đơn giản): rộng $width, chữ lớn nhất',
        (tester) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await updateName('Bà Năm Đồng Tháp');
      await setMyCommodities(['caphe', 'hotieu', 'heohoi', 'vang']);

      await tester.pumpWidget(scaled(
          maxTextScale, const Scaffold(body: AccountScreen())));
      await tester.pumpAndSettle();
      final f = find.text('Chế độ đơn giản');
      await tester.scrollUntilVisible(f, 200,
          scrollable: find.byType(Scrollable).first);
      expect(f, findsOneWidget);
      await tester.scrollUntilVisible(
          find.textContaining('Mặt hàng của tôi:'), 200,
          scrollable: find.byType(Scrollable).first);
      expect(tester.takeException(), isNull);
    });

    testWidgets('hộp thoại "Có bản mới": rộng $width, chữ lớn nhất',
        (tester) async {
      tester.view.physicalSize = Size(width, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(scaled(
        maxTextScale,
        Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showUpdateDialog(context,
                    known: const Release(
                      version: '1.3.0',
                      parts: [1, 3, 0],
                      notes: '- Chữ to hơn, đọc dễ hơn\n- Thêm giá vùng gần nhà\n'
                          '- Tự báo khi có bản mới',
                      apkUrl: 'https://x/HeFarmer.apk',
                      apkSize: 1,
                      apkSha256: '',
                    )),
                child: const Text('mở'),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('mở'));
      await tester.pumpAndSettle();
      expect(find.text('🎉 Có bản mới 1.3.0'), findsOneWidget);
      expect(find.text('Cập nhật ngay'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('chọn mặt hàng của tôi: rộng $width, chữ lớn nhất',
        (tester) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
          scaled(maxTextScale, const MyCommoditiesScreen()));
      await tester.pumpAndSettle();
      final coffee = find.text(findCommodity('caphe')!.name);
      await tester.scrollUntilVisible(coffee, 200,
          scrollable: find.byType(Scrollable).first);
      await tester.tap(coffee);
      await tester.pump();
      expect(find.text('Lưu (1 mặt hàng)'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
