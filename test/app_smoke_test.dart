import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hefarmer/main.dart';

/// Test giao diện MÀN HÌNH CHÀO — dùng chính widget thật của app
/// (IntroScreen trong main.dart), không gọi mạng, không cần GPS.
void main() {
  testWidgets('màn hình chào hiện lời chào theo buổi kèm tên người dùng',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: IntroScreen(greetName: 'Ông Ba')),
    );
    await tester.pump(); // vẽ 1 khung, không dùng pumpAndSettle vì có vòng xoay

    // Lời chào thay đổi theo giờ trong máy nên chỉ kiểm tra phần cố định
    expect(find.textContaining('Ông Ba'), findsOneWidget);
    expect(find.textContaining('Chào buổi'), findsOneWidget);
    expect(find.text('Đang tải giá nông sản hôm nay...'), findsOneWidget);
  });

  testWidgets('không đăng nhập thì vẫn chào bình thường', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: IntroScreen()));
    await tester.pump();
    expect(find.textContaining('Chào buổi'), findsOneWidget);
  });

  testWidgets('nút "Vào ứng dụng ngay" bấm được và gọi đúng hành động',
      (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(home: IntroScreen(onSkip: () => tapped = true)),
    );
    await tester.pump();

    final button = find.text('Vào ứng dụng ngay');
    expect(button, findsOneWidget);
    await tester.tap(button);
    await tester.pump();
    expect(tapped, true);
  });

  testWidgets('không truyền onSkip thì không hiện nút bỏ qua', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: IntroScreen()));
    await tester.pump();
    expect(find.text('Vào ứng dụng ngay'), findsNothing);
  });
}
