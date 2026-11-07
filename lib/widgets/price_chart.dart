import 'package:flutter/material.dart';

import '../services/price_service.dart';
import '../theme.dart';

/// BIỂU ĐỒ GIÁ nhiều ngày — tự vẽ bằng CustomPainter (không cần thư viện
/// ngoài). Trả lời câu hỏi thật sự của bà con: "nên bán bây giờ hay đợi?"
///
/// Dữ liệu lấy từ lịch sử lưu trong máy (app ghi lại mỗi lần tải giá),
/// nên càng dùng lâu biểu đồ càng đầy đặn.

Future<void> showPriceChart(
  BuildContext context, {
  required String commodityId,
  required String commodityName,
  required String unit,
}) async {
  final history = await loadPriceHistory(commodityId);
  if (!context.mounted) return;

  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Row(children: [
        const Text('📈', style: TextStyle(fontSize: 26)),
        const SizedBox(width: 8),
        Expanded(
          child: Text('Giá $commodityName',
              style: const TextStyle(
                  fontSize: AppFont.big, fontWeight: FontWeight.w900)),
        ),
      ]),
      contentPadding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      content: SizedBox(
        width: 360,
        child: PriceChartBody(
            history: history, unit: unit, commodityName: commodityName),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Đóng', style: TextStyle(fontSize: AppFont.body)),
        ),
      ],
    ),
  );
}

class PriceChartBody extends StatelessWidget {
  final List<DaySummary> history;
  final String unit;
  final String commodityName;
  const PriceChartBody({
    super.key,
    required this.history,
    required this.unit,
    required this.commodityName,
  });

  @override
  Widget build(BuildContext context) {
    final points = history.where((d) => d.avgBuy != null).toList();

    if (points.length < 2) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('📊', style: TextStyle(fontSize: 44)),
          const SizedBox(height: 10),
          Text(
            points.isEmpty
                ? 'Chưa có dữ liệu để vẽ biểu đồ.'
                : 'Mới có giá của 1 ngày nên chưa vẽ được đường biểu đồ.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: AppFont.body),
          ),
          const SizedBox(height: 8),
          const Text(
            'Bác cứ mở ứng dụng mỗi ngày, app sẽ tự ghi lại giá và vài hôm '
            'nữa biểu đồ sẽ hiện lên đầy đủ.',
            textAlign: TextAlign.center,
            style:
                TextStyle(fontSize: AppFont.small, color: AppColors.textMuted),
          ),
        ]),
      );
    }

    final values = points.map((e) => e.avgBuy!).toList();
    final maxV = values.reduce((a, b) => a > b ? a : b);
    final minV = values.reduce((a, b) => a < b ? a : b);
    final first = values.first;
    final last = values.last;
    final diff = last - first;
    final pct = first == 0 ? 0.0 : diff * 100 / first;
    final up = diff > 0;
    final flat = diff == 0;
    final color = flat ? AppColors.flat : (up ? AppColors.up : AppColors.down);

    return Column(mainAxisSize: MainAxisSize.min, children: [
      // Tóm tắt xu hướng — điều bà con muốn biết nhất
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: flat
              ? AppColors.flatBg
              : (up ? AppColors.upBg : AppColors.downBg),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(children: [
          Text(
            flat
                ? 'Giá đi ngang trong ${points.length} ngày qua'
                : '${up ? '▲ Tăng' : '▼ Giảm'} ${formatVnd(diff.abs())} '
                    '(${pct.abs().toStringAsFixed(1)}%) trong ${points.length} ngày qua',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: AppFont.body,
                fontWeight: FontWeight.w900,
                color: color),
          ),
          const SizedBox(height: 4),
          Text('Thấp nhất ${formatVnd(minV)} · Cao nhất ${formatVnd(maxV)}',
              style: const TextStyle(
                  fontSize: AppFont.small, color: AppColors.textMuted)),
        ]),
      ),
      const SizedBox(height: 14),
      SizedBox(
        height: 190,
        width: double.infinity,
        child: CustomPaint(
          painter: _ChartPainter(points: points, color: color),
        ),
      ),
      const SizedBox(height: 6),
      Text('Đơn vị: $unit · ${points.length} ngày có dữ liệu',
          style: const TextStyle(
              fontSize: AppFont.small, color: AppColors.textMuted)),
      const SizedBox(height: 8),
    ]);
  }
}

class _ChartPainter extends CustomPainter {
  final List<DaySummary> points;
  final Color color;
  _ChartPainter({required this.points, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final values = points.map((e) => e.avgBuy!.toDouble()).toList();
    var maxV = values.reduce((a, b) => a > b ? a : b);
    var minV = values.reduce((a, b) => a < b ? a : b);
    if (maxV == minV) {
      maxV += maxV * 0.01 + 1;
      minV -= minV * 0.01 + 1;
    }
    // chừa lề: trên 12, dưới 28 (cho nhãn ngày), trái 4, phải 4
    const padTop = 12.0, padBottom = 28.0, padLeft = 4.0, padRight = 4.0;
    final w = size.width - padLeft - padRight;
    final h = size.height - padTop - padBottom;

    Offset pos(int i) {
      final x = padLeft + (points.length == 1 ? w / 2 : w * i / (points.length - 1));
      final y = padTop + h * (1 - (values[i] - minV) / (maxV - minV));
      return Offset(x, y);
    }

    // Lưới ngang mờ
    final grid = Paint()
      ..color = AppColors.border
      ..strokeWidth = 1;
    for (var g = 0; g <= 3; g++) {
      final y = padTop + h * g / 3;
      canvas.drawLine(Offset(padLeft, y), Offset(size.width - padRight, y), grid);
    }

    // Vùng tô dưới đường
    final path = Path()..moveTo(pos(0).dx, pos(0).dy);
    for (var i = 1; i < points.length; i++) {
      path.lineTo(pos(i).dx, pos(i).dy);
    }
    final fill = Path.from(path)
      ..lineTo(pos(points.length - 1).dx, padTop + h)
      ..lineTo(pos(0).dx, padTop + h)
      ..close();
    canvas.drawPath(
        fill, Paint()..color = color.withValues(alpha: 0.13));

    // Đường giá
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = 3.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // Chấm tròn tại từng ngày
    for (var i = 0; i < points.length; i++) {
      canvas.drawCircle(pos(i), 4.5, Paint()..color = Colors.white);
      canvas.drawCircle(
          pos(i),
          4.5,
          Paint()
            ..color = color
            ..strokeWidth = 2.5
            ..style = PaintingStyle.stroke);
    }

    // Nhãn ngày: chỉ ghi ngày đầu, giữa, cuối cho đỡ rối
    final idxs = points.length <= 3
        ? List.generate(points.length, (i) => i)
        : [0, points.length ~/ 2, points.length - 1];
    for (final i in idxs) {
      final p = points[i].date.split('-');
      final label = '${p[2]}/${p[1]}';
      final tp = TextPainter(
        text: TextSpan(
            text: label,
            style: const TextStyle(
                fontSize: 13,
                color: AppColors.textMuted,
                fontWeight: FontWeight.w600)),
        textDirection: TextDirection.ltr,
      )..layout();
      var dx = pos(i).dx - tp.width / 2;
      dx = dx.clamp(0.0, size.width - tp.width);
      tp.paint(canvas, Offset(dx, padTop + h + 8));
    }
  }

  @override
  bool shouldRepaint(covariant _ChartPainter old) =>
      old.points != points || old.color != color;
}
