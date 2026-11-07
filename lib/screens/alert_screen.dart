import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/alert_service.dart';
import '../services/price_service.dart';
import '../theme.dart';

/// ===== ĐẶT CẢNH BÁO GIÁ CHO 1 MẶT HÀNG =====
/// Bác nhập mức giá mong muốn, chọn "báo khi vượt" hay "báo khi xuống dưới".
Future<bool?> showAlertDialog(
  BuildContext context, {
  required String commodityId,
  required String commodityName,
  required String unit,
  int? currentPrice,
}) async {
  final existing =
      (await loadAlerts()).where((a) => a.commodityId == commodityId).toList();
  final old = existing.isEmpty ? null : existing.first;
  if (!context.mounted) return null;

  final controller = TextEditingController(
      text: old != null ? old.threshold.toString() : (currentPrice?.toString() ?? ''));
  var above = old?.above ?? true;

  return showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setLocal) => AlertDialog(
        title: Row(children: [
          const Text('🔔', style: TextStyle(fontSize: 26)),
          const SizedBox(width: 8),
          Expanded(
            child: Text('Báo giá $commodityName',
                style: const TextStyle(
                    fontSize: AppFont.big, fontWeight: FontWeight.w900)),
          ),
        ]),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (currentPrice != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text('Giá hôm nay: ${formatVnd(currentPrice)} $unit',
                      style: const TextStyle(
                          fontSize: AppFont.body,
                          fontWeight: FontWeight.w700,
                          color: AppColors.buy)),
                ),
              const Text('Báo cho tôi khi giá:',
                  style: TextStyle(fontSize: AppFont.body)),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: _ChoiceButton(
                    label: '▲ Vượt lên',
                    selected: above,
                    color: AppColors.up,
                    onTap: () => setLocal(() => above = true),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ChoiceButton(
                    label: '▼ Xuống dưới',
                    selected: !above,
                    color: AppColors.down,
                    onTap: () => setLocal(() => above = false),
                  ),
                ),
              ]),
              const SizedBox(height: 14),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: const TextStyle(
                    fontSize: AppFont.title, fontWeight: FontWeight.w900),
                decoration: InputDecoration(
                  labelText: 'Mức giá ($unit)',
                  labelStyle: const TextStyle(fontSize: AppFont.body),
                  border:
                      OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'App sẽ tự kiểm tra vài lần mỗi ngày và báo ra màn hình '
                'điện thoại, bác không cần mở ứng dụng.',
                style:
                    TextStyle(fontSize: AppFont.small, color: AppColors.textMuted),
              ),
            ],
          ),
        ),
        actions: [
          if (old != null)
            TextButton(
              onPressed: () async {
                await removeAlert(commodityId);
                if (ctx.mounted) Navigator.pop(ctx, true);
              },
              child: const Text('Xoá cảnh báo',
                  style: TextStyle(fontSize: AppFont.body, color: AppColors.down)),
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Đóng', style: TextStyle(fontSize: AppFont.body)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () async {
              final v = int.tryParse(controller.text.trim());
              if (v == null || v <= 0) return;
              await upsertAlert(PriceAlert(
                commodityId: commodityId,
                commodityName: commodityName,
                threshold: v,
                above: above,
              ));
              await setupBackgroundCheck();
              if (ctx.mounted) Navigator.pop(ctx, true);
            },
            child: const Text('Lưu',
                style: TextStyle(
                    fontSize: AppFont.body,
                    fontWeight: FontWeight.w800,
                    color: Colors.white)),
          ),
        ],
      ),
    ),
  );
}

class _ChoiceButton extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  const _ChoiceButton(
      {required this.label,
      required this.selected,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.12) : Colors.transparent,
          border: Border.all(
              color: selected ? color : AppColors.border,
              width: selected ? 2.5 : 1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: AppFont.body,
                fontWeight: FontWeight.w800,
                color: selected ? color : AppColors.textMuted)),
      ),
    );
  }
}

/// ===== MÁY TÍNH TIỀN BÁN =====
/// "Tôi có 1,2 tấn cà phê — bán được bao nhiêu tiền?"
Future<void> showSellCalculator(
  BuildContext context, {
  required String commodityName,
  required int price,
  required String unit,
}) async {
  final controller = TextEditingController();
  // Đơn vị nào thì nhập theo cái đó: kg / lượng / quả
  final perLabel = unit.contains('quả')
      ? 'quả'
      : unit.contains('lượng')
          ? 'lượng'
          : 'kg';

  await showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setLocal) {
        final qty = double.tryParse(controller.text.replaceAll(',', '.')) ?? 0;
        final total = (qty * price).round();
        return AlertDialog(
          title: Row(children: [
            const Text('🧮', style: TextStyle(fontSize: 26)),
            const SizedBox(width: 8),
            Expanded(
              child: Text('Tính tiền $commodityName',
                  style: const TextStyle(
                      fontSize: AppFont.big, fontWeight: FontWeight.w900)),
            ),
          ]),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Giá hôm nay: ${formatVnd(price)} $unit',
                    style: const TextStyle(
                        fontSize: AppFont.body,
                        fontWeight: FontWeight.w700,
                        color: AppColors.buy)),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  autofocus: true,
                  onChanged: (_) => setLocal(() {}),
                  style: const TextStyle(
                      fontSize: AppFont.title, fontWeight: FontWeight.w900),
                  decoration: InputDecoration(
                    labelText: 'Số $perLabel bác có',
                    labelStyle: const TextStyle(fontSize: AppFont.body),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                if (perLabel == 'kg') ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ('100 kg', '100'),
                      ('500 kg', '500'),
                      ('1 tấn', '1000'),
                      ('2 tấn', '2000'),
                    ]
                        .map((e) => OutlinedButton(
                              onPressed: () => setLocal(() {
                                controller.text = e.$2;
                              }),
                              child: Text(e.$1,
                                  style:
                                      const TextStyle(fontSize: AppFont.small)),
                            ))
                        .toList(),
                  ),
                ],
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(12)),
                  child: Column(children: [
                    const Text('THÀNH TIỀN',
                        style: TextStyle(
                            fontSize: AppFont.small,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary)),
                    const SizedBox(height: 4),
                    FittedBox(
                      child: Text('${formatVnd(total)} đ',
                          style: const TextStyle(
                              fontSize: 34,
                              fontWeight: FontWeight.w900,
                              color: AppColors.primary)),
                    ),
                    if (total > 0)
                      Text(readMoneyVn(total),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: AppFont.body,
                              color: AppColors.textMuted)),
                  ]),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Số tiền chỉ để tham khảo, chưa trừ tạp chất, độ ẩm hay '
                  'chi phí vận chuyển.',
                  style: TextStyle(
                      fontSize: AppFont.small, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child:
                  const Text('Đóng', style: TextStyle(fontSize: AppFont.body)),
            ),
          ],
        );
      },
    ),
  );
}

/// Đọc số tiền thành chữ rút gọn: "khoảng 113 triệu 760 nghìn đồng"
String readMoneyVn(int amount) {
  if (amount <= 0) return '';
  final ty = amount ~/ 1000000000;
  final trieu = (amount % 1000000000) ~/ 1000000;
  final nghin = (amount % 1000000) ~/ 1000;
  final parts = <String>[];
  if (ty > 0) parts.add('$ty tỷ');
  if (trieu > 0) parts.add('$trieu triệu');
  if (nghin > 0 && ty == 0) parts.add('$nghin nghìn');
  if (parts.isEmpty) return 'khoảng $amount đồng';
  return 'khoảng ${parts.join(' ')} đồng';
}
