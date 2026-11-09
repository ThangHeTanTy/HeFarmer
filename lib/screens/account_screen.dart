import 'dart:async';

import 'package:flutter/material.dart';

import '../services/account_service.dart';
import '../services/price_service.dart';
import '../services/settings_service.dart';
import '../services/vn_places.dart';
import '../theme.dart';
import 'my_commodities_screen.dart';

/// Màn hình HỒ SƠ: tên để app chào, ảnh đại diện, và "Vị trí của tôi" —
/// tab Thời tiết ưu tiên vị trí này thay GPS, tab Giá dùng nó để chọn ra
/// giá ở vùng gần nhà nhất. Không cần mật khẩu, không cần đăng nhập.
class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  Profile? _profile;
  HomeLocation? _home;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final p = await currentProfile();
    final h = await getHomeLocation();
    if (mounted) {
      setState(() {
        _profile = p;
        _home = h;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _profile;
    if (p == null) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.primary));
    }
    return _ProfileView(profile: p, home: _home, onChanged: _refresh);
  }
}

// ================== HỒ SƠ ==================

class _ProfileView extends StatelessWidget {
  final Profile profile;
  final HomeLocation? home;
  final VoidCallback onChanged;
  const _ProfileView(
      {required this.profile, required this.home, required this.onChanged});

  Future<void> _pickAvatar(BuildContext context) async {
    final chosen = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Chọn ảnh đại diện',
            style:
                TextStyle(fontSize: AppFont.big, fontWeight: FontWeight.w800)),
        content: SizedBox(
          width: 300,
          child: GridView.count(
            shrinkWrap: true,
            crossAxisCount: 4,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            children: avatarChoices
                .map((a) => InkWell(
                      onTap: () => Navigator.pop(ctx, a),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.center,
                        child: Text(a, style: const TextStyle(fontSize: 30)),
                      ),
                    ))
                .toList(),
          ),
        ),
      ),
    );
    if (chosen != null) {
      await updateAvatar(chosen);
      onChanged();
    }
  }

  Future<void> _editName(BuildContext context) async {
    final controller = TextEditingController(text: profile.name);
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Bác tên gì ạ?',
            style:
                TextStyle(fontSize: AppFont.big, fontWeight: FontWeight.w800)),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          style: const TextStyle(fontSize: AppFont.body),
          decoration: InputDecoration(
            hintText: 'Ví dụ: Ông Ba, Cô Tư',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Thôi', style: TextStyle(fontSize: AppFont.body)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Lưu',
                style: TextStyle(
                    fontSize: AppFont.body,
                    fontWeight: FontWeight.w800,
                    color: Colors.white)),
          ),
        ],
      ),
    );
    final text = controller.text;
    controller.dispose();
    if (saved != true) return;
    final err = await updateName(text);
    if (!context.mounted) return;
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(err, style: const TextStyle(fontSize: AppFont.body)),
        backgroundColor: AppColors.down,
      ));
      return;
    }
    onChanged();
  }

  Future<void> _pickLocation(BuildContext context) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const LocationPickerScreen()),
    );
    if (changed == true) onChanged();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
      children: [
        Center(
          child: InkWell(
            onTap: () => _pickAvatar(context),
            borderRadius: BorderRadius.circular(60),
            child: Stack(
              children: [
                Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.primary, width: 3),
                  ),
                  alignment: Alignment.center,
                  child: Text(profile.avatar,
                      style: const TextStyle(fontSize: 56)),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                        color: AppColors.primary, shape: BoxShape.circle),
                    child:
                        const Icon(Icons.edit, color: Colors.white, size: 22),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        const Center(
          child: Text('Chạm vào ảnh để đổi',
              style: TextStyle(
                  fontSize: AppFont.small, color: AppColors.textMuted)),
        ),
        const SizedBox(height: 10),
        Center(
          child: TextButton.icon(
            onPressed: () => _editName(context),
            icon: const Icon(Icons.edit, size: 24, color: AppColors.primary),
            label: Text(
              profile.hasName ? profile.name : 'Chạm để đặt tên của bác',
              style: TextStyle(
                  fontSize: profile.hasName ? AppFont.title : AppFont.big,
                  fontWeight: FontWeight.w900,
                  color: profile.hasName ? AppColors.text : AppColors.buy),
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Ô đặt vị trí
        InkWell(
          onTap: () => _pickLocation(context),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.buyBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                const Text('📍', style: TextStyle(fontSize: 32)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Vị trí của tôi',
                          style: TextStyle(
                              fontSize: AppFont.body,
                              fontWeight: FontWeight.w800,
                              color: AppColors.buy)),
                      const SizedBox(height: 2),
                      Text(
                        home?.label ?? 'Chưa đặt — chạm để chọn nơi bạn ở',
                        style: TextStyle(
                            fontSize: AppFont.body,
                            fontWeight: home != null
                                ? FontWeight.w700
                                : FontWeight.w400,
                            color: AppColors.text),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Tab Thời tiết lấy dự báo tại đây (không cần bật GPS),\n'
                        'tab Giá hiện trước giá ở vùng gần nhà nhất.',
                        style: TextStyle(
                            fontSize: AppFont.small,
                            color: AppColors.textMuted,
                            height: 1.3),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right,
                    size: 32, color: AppColors.textMuted),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        const _DisplaySettings(),
        const SizedBox(height: 20),
        const Text(
          'Hồ sơ chỉ lưu trong máy này, không gửi đi đâu và không cần mật khẩu.',
          textAlign: TextAlign.center,
          style: TextStyle(
              fontSize: AppFont.small, color: AppColors.textMuted, height: 1.4),
        ),
      ],
    );
  }
}

// ================== CÀI ĐẶT HIỂN THỊ ==================

/// Cỡ chữ + chế độ đơn giản. Đổi là cả app cập nhật ngay.
class _DisplaySettings extends StatelessWidget {
  const _DisplaySettings();

  Future<void> _toggleSimple(BuildContext context, bool on) async {
    // Bật lần đầu mà chưa chọn mặt hàng nào -> mời chọn luôn
    if (on && appSettings.value.myCommodities.isEmpty) {
      await openMyCommoditiesPicker(context);
    }
    await setSimpleMode(on);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppSettings>(
      valueListenable: appSettings,
      builder: (context, st, _) {
        final chosen =
            st.myCommodities.map(findCommodity).whereType<Commodity>().toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ----- Cỡ chữ -----
            const Text('🔠 Cỡ chữ',
                style: TextStyle(
                    fontSize: AppFont.big,
                    fontWeight: FontWeight.w900,
                    color: AppColors.primary)),
            const SizedBox(height: 8),
            Row(children: [
              for (final (label, scale) in textScaleChoices) ...[
                Expanded(
                  child: _ScaleButton(
                    label: label,
                    scale: scale,
                    selected: st.textScale == scale,
                    onTap: () => setTextScale(scale),
                  ),
                ),
                if (scale != textScaleChoices.last.$2) const SizedBox(width: 8),
              ],
            ]),
            const SizedBox(height: 6),
            const Text(
              'Chữ trong cả ứng dụng sẽ to lên ngay. Chọn mức nào bác đọc '
              'thoải mái nhất.',
              style: TextStyle(
                  fontSize: AppFont.small,
                  color: AppColors.textMuted,
                  height: 1.3),
            ),
            const SizedBox(height: 22),

            // ----- Chế độ đơn giản -----
            Container(
              padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
              decoration: BoxDecoration(
                color: st.simpleMode ? AppColors.primaryLight : AppColors.card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: st.simpleMode ? AppColors.primary : AppColors.border,
                    width: st.simpleMode ? 2 : 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(children: [
                    const Text('🧓', style: TextStyle(fontSize: 30)),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text('Chế độ đơn giản',
                          style: TextStyle(
                              fontSize: AppFont.big,
                              fontWeight: FontWeight.w900,
                              color: AppColors.text)),
                    ),
                    Transform.scale(
                      scale: 1.25,
                      child: Switch(
                        value: st.simpleMode,
                        activeTrackColor: AppColors.primary,
                        onChanged: (v) => _toggleSimple(context, v),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 4),
                  const Text(
                    'Chỉ còn 3 mục: Giá của tôi, Thời tiết và Tôi. '
                    'Tab "Giá của tôi" chỉ hiện những thứ bác chọn.',
                    style: TextStyle(
                        fontSize: AppFont.small,
                        color: AppColors.textMuted,
                        height: 1.35),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () => openMyCommoditiesPicker(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          vertical: 12, horizontal: 12),
                      side:
                          const BorderSide(color: AppColors.primary, width: 2),
                      alignment: Alignment.centerLeft,
                    ),
                    child: Text(
                      chosen.isEmpty
                          ? '➕ Chọn mặt hàng của tôi'
                          : '✏️ Mặt hàng của tôi: '
                              '${chosen.map((c) => '${c.icon} ${c.name}').join(', ')}',
                      style: const TextStyle(
                          fontSize: AppFont.body,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Nút chọn cỡ chữ — chữ "Aa" trên nút có đúng cỡ sẽ hiển thị
class _ScaleButton extends StatelessWidget {
  final String label;
  final double scale;
  final bool selected;
  final VoidCallback onTap;
  const _ScaleButton({
    required this.label,
    required this.scale,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primary : AppColors.card,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: selected ? AppColors.primary : AppColors.border,
                width: 2),
          ),
          child: Column(children: [
            // Cố định cỡ để 3 nút so sánh được với nhau
            Text('Aa',
                textScaler: TextScaler.noScaling,
                style: TextStyle(
                    fontSize: 22 * scale,
                    fontWeight: FontWeight.w900,
                    color: selected ? Colors.white : AppColors.text)),
            FittedBox(
              child: Text(label,
                  style: TextStyle(
                      fontSize: AppFont.small,
                      fontWeight: FontWeight.w800,
                      color: selected ? Colors.white : AppColors.textMuted)),
            ),
          ]),
        ),
      ),
    );
  }
}

// ================== CHỌN VỊ TRÍ (có gợi ý khi gõ) ==================

class LocationPickerScreen extends StatefulWidget {
  const LocationPickerScreen({super.key});

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;
  List<PlaceSuggestion> _local = vnProvinces;
  List<PlaceSuggestion> _online = [];
  bool _searchingOnline = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String q) {
    // Lọc 34 tỉnh/thành ngay lập tức (không cần mạng)
    setState(() => _local = searchProvinces(q));
    // Tìm trực tuyến địa danh chi tiết hơn, chờ 0,4 giây sau khi ngừng gõ
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      if (!mounted || q.trim().length < 2) {
        if (mounted) setState(() => _online = []);
        return;
      }
      setState(() => _searchingOnline = true);
      List<PlaceSuggestion> found = [];
      try {
        found = await searchPlacesOnline(q);
      } catch (_) {
        // không có mạng -> vẫn còn danh sách tỉnh/thành
      }
      if (mounted) {
        setState(() {
          _online = found;
          _searchingOnline = false;
        });
      }
    });
  }

  Future<void> _choose(PlaceSuggestion p) async {
    await setHomeLocation(p.toHomeLocation());
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Đã đặt vị trí: ${p.label}',
          style: const TextStyle(fontSize: AppFont.body)),
      backgroundColor: AppColors.primary,
    ));
    Navigator.pop(context, true);
  }

  Widget _tile(PlaceSuggestion p, {required bool online}) {
    return ListTile(
      leading:
          Text(online ? '🔎' : '🏙️', style: const TextStyle(fontSize: 26)),
      title: Text(p.name,
          style: const TextStyle(
              fontSize: AppFont.body,
              fontWeight: FontWeight.w700,
              color: AppColors.text)),
      subtitle: p.detail.isEmpty
          ? null
          : Text(p.detail,
              style: const TextStyle(
                  fontSize: AppFont.small, color: AppColors.textMuted)),
      onTap: () => _choose(p),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chọn nơi bạn đang ở')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _controller,
              autofocus: true,
              style: const TextStyle(fontSize: AppFont.big),
              onChanged: _onChanged,
              decoration: InputDecoration(
                hintText: 'Gõ tên tỉnh, thành phố, xã...',
                hintStyle: const TextStyle(
                    fontSize: AppFont.body, color: AppColors.textMuted),
                prefixIcon: const Icon(Icons.search, size: 30),
                suffixIcon: _controller.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear, size: 28),
                        onPressed: () {
                          _controller.clear();
                          _onChanged('');
                        },
                      ),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
              ),
            ),
          ),
          if (_searchingOnline)
            const LinearProgressIndicator(color: AppColors.primary),
          Expanded(
            child: ListView(
              children: [
                if (_online.isNotEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: Text('Kết quả tìm kiếm',
                        style: TextStyle(
                            fontSize: AppFont.small,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textMuted)),
                  ),
                  ..._online.map((p) => _tile(p, online: true)),
                  const Divider(),
                ],
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: Text(
                    _controller.text.trim().isEmpty
                        ? '34 tỉnh, thành phố (sau sáp nhập 7/2025)'
                        : 'Tỉnh, thành phố phù hợp',
                    style: const TextStyle(
                        fontSize: AppFont.small,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textMuted),
                  ),
                ),
                ..._local.map((p) => _tile(p, online: false)),
                if (_local.isEmpty && _online.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Không tìm thấy địa danh phù hợp.\nThử gõ ngắn hơn, ví dụ: "Bien Hoa" hoặc "Đồng Nai".',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: AppFont.body, color: AppColors.textMuted),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
