import 'package:flutter/material.dart';

import '../services/price_service.dart';
import '../services/settings_service.dart';
import '../theme.dart';

/// CHỌN "MẶT HÀNG CỦA TÔI" cho chế độ đơn giản: bác trồng cà phê, nuôi heo
/// thì chỉ chọn 2 thứ đó — tab "Giá của tôi" sẽ chỉ hiện đúng những thứ này.
///
/// Trả về true nếu bác đã bấm Lưu.
Future<bool> openMyCommoditiesPicker(BuildContext context) async {
  final saved = await Navigator.push<bool>(
    context,
    MaterialPageRoute(builder: (_) => const MyCommoditiesScreen()),
  );
  return saved == true;
}

class MyCommoditiesScreen extends StatefulWidget {
  const MyCommoditiesScreen({super.key});

  @override
  State<MyCommoditiesScreen> createState() => _MyCommoditiesScreenState();
}

class _MyCommoditiesScreenState extends State<MyCommoditiesScreen> {
  // Giữ THỨ TỰ bác chọn: chọn trước thì hiện trước
  late final List<String> _chosen = List.of(appSettings.value.myCommodities);

  static final _groups = <(String, List<Commodity>)>[
    ('Cây trồng', commodities),
    ('Vật nuôi', livestockCommodities),
    ('Vật tư đầu vào', inputCommodities),
    ('Vàng, bạc', metalsCommodities),
  ];

  void _toggle(String id) {
    setState(() {
      if (!_chosen.remove(id)) _chosen.add(id);
    });
  }

  Future<void> _save() async {
    await setMyCommodities(_chosen);
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mặt hàng của tôi')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          const Text(
            'Chạm để chọn những thứ bác trồng, nuôi hoặc hay mua. '
            'Tab "Giá của tôi" sẽ chỉ hiện đúng những mặt hàng này.',
            style: TextStyle(
                fontSize: AppFont.body,
                color: AppColors.textMuted,
                height: 1.4),
          ),
          for (final (title, list) in _groups) ...[
            Padding(
              padding: const EdgeInsets.only(top: 18, bottom: 6),
              child: Text(title,
                  style: const TextStyle(
                      fontSize: AppFont.big,
                      fontWeight: FontWeight.w900,
                      color: AppColors.primary)),
            ),
            for (final c in list) _tile(c),
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: ElevatedButton(
            onPressed: _save,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(
              _chosen.isEmpty ? 'Lưu' : 'Lưu (${_chosen.length} mặt hàng)',
              style: const TextStyle(
                  fontSize: AppFont.big,
                  fontWeight: FontWeight.w800,
                  color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }

  Widget _tile(Commodity c) {
    final on = _chosen.contains(c.id);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: on ? AppColors.primaryLight : AppColors.card,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _toggle(c.id),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: on ? AppColors.primary : AppColors.border,
                  width: on ? 2.5 : 1),
            ),
            child: Row(children: [
              Text(c.icon, style: const TextStyle(fontSize: 30)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(c.name,
                    style: TextStyle(
                        fontSize: AppFont.body,
                        fontWeight: on ? FontWeight.w900 : FontWeight.w600,
                        color: AppColors.text)),
              ),
              Icon(on ? Icons.check_circle : Icons.circle_outlined,
                  size: 34, color: on ? AppColors.primary : AppColors.border),
            ]),
          ),
        ),
      ),
    );
  }
}
