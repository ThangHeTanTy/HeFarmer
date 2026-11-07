import 'dart:async';

import 'package:flutter/material.dart';

import '../services/account_service.dart';
import '../services/vn_places.dart';
import '../theme.dart';

/// Màn hình TÀI KHOẢN: đăng nhập / đăng ký (lưu trong máy), đổi avatar,
/// và đặt "Vị trí của tôi" — tab Thời tiết sẽ ưu tiên vị trí này thay GPS,
/// giúp người cao tuổi không cần biết cách bật/chia sẻ vị trí.
class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  Profile? _profile;
  HomeLocation? _home;
  bool _loading = true;

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
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.primary));
    }
    return _profile == null
        ? _AuthView(onDone: _refresh)
        : _ProfileView(profile: _profile!, home: _home, onChanged: _refresh);
  }
}

// ================== ĐĂNG NHẬP / ĐĂNG KÝ ==================

class _AuthView extends StatefulWidget {
  final VoidCallback onDone;
  const _AuthView({required this.onDone});

  @override
  State<_AuthView> createState() => _AuthViewState();
}

class _AuthViewState extends State<_AuthView> {
  bool _isRegister = false;
  bool _busy = false;
  bool _hidePassword = true;
  String? _error;
  final _name = TextEditingController();
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _password2 = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _username.dispose();
    _password.dispose();
    _password2.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    String? err;
    if (_isRegister) {
      if (_password.text != _password2.text) {
        err = 'Hai lần nhập mật khẩu chưa giống nhau.';
      } else {
        err = await register(
          name: _name.text,
          username: _username.text,
          password: _password.text,
        );
      }
    } else {
      err = await login(username: _username.text, password: _password.text);
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = err;
    });
    if (err == null) widget.onDone();
  }

  InputDecoration _dec(String label, {Widget? suffix}) => InputDecoration(
        labelText: label,
        labelStyle:
            const TextStyle(fontSize: AppFont.body, color: AppColors.textMuted),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        suffixIcon: suffix,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      );

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
      children: [
        const Center(child: Text('👨‍🌾', style: TextStyle(fontSize: 64))),
        const SizedBox(height: 8),
        Center(
          child: Text(
            _isRegister ? 'Tạo tài khoản mới' : 'Đăng nhập',
            style: const TextStyle(
                fontSize: AppFont.title,
                fontWeight: FontWeight.w900,
                color: AppColors.primary),
          ),
        ),
        const SizedBox(height: 6),
        const Center(
          child: Text(
            'Tài khoản được lưu ngay trong máy của bạn',
            style:
                TextStyle(fontSize: AppFont.small, color: AppColors.textMuted),
          ),
        ),
        const SizedBox(height: 20),
        if (_isRegister) ...[
          TextField(
            controller: _name,
            style: const TextStyle(fontSize: AppFont.body),
            decoration: _dec('Tên của bạn (ví dụ: Ông Ba)'),
          ),
          const SizedBox(height: 14),
        ],
        TextField(
          controller: _username,
          style: const TextStyle(fontSize: AppFont.body),
          autocorrect: false,
          decoration: _dec('Tên đăng nhập'),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _password,
          obscureText: _hidePassword,
          style: const TextStyle(fontSize: AppFont.body),
          decoration: _dec(
            'Mật khẩu',
            suffix: IconButton(
              icon: Icon(
                  _hidePassword ? Icons.visibility : Icons.visibility_off,
                  size: 26),
              onPressed: () => setState(() => _hidePassword = !_hidePassword),
            ),
          ),
        ),
        if (_isRegister) ...[
          const SizedBox(height: 14),
          TextField(
            controller: _password2,
            obscureText: _hidePassword,
            style: const TextStyle(fontSize: AppFont.body),
            decoration: _dec('Nhập lại mật khẩu'),
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: AppColors.downBg,
                borderRadius: BorderRadius.circular(10)),
            child: Text(_error!,
                style: const TextStyle(
                    fontSize: AppFont.body, color: AppColors.down)),
          ),
        ],
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: _busy ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: _busy
              ? const SizedBox(
                  width: 26,
                  height: 26,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 3))
              : Text(_isRegister ? 'Đăng ký' : 'Đăng nhập',
                  style: const TextStyle(
                      fontSize: AppFont.big,
                      fontWeight: FontWeight.w800,
                      color: Colors.white)),
        ),
        const SizedBox(height: 14),
        TextButton(
          onPressed: _busy
              ? null
              : () => setState(() {
                    _isRegister = !_isRegister;
                    _error = null;
                  }),
          child: Text(
            _isRegister
                ? 'Đã có tài khoản? Bấm vào đây để đăng nhập'
                : 'Chưa có tài khoản? Bấm vào đây để đăng ký',
            style: const TextStyle(
                fontSize: AppFont.body,
                color: AppColors.buy,
                fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

// ================== HỒ SƠ SAU KHI ĐĂNG NHẬP ==================

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
                  child:
                      Text(profile.avatar, style: const TextStyle(fontSize: 56)),
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
          child: Text(profile.name,
              style: const TextStyle(
                  fontSize: AppFont.title,
                  fontWeight: FontWeight.w900,
                  color: AppColors.text)),
        ),
        Center(
          child: Text('@${profile.username}',
              style: const TextStyle(
                  fontSize: AppFont.small, color: AppColors.textMuted)),
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
                            fontWeight:
                                home != null ? FontWeight.w700 : FontWeight.w400,
                            color: AppColors.text),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Tab Thời tiết sẽ ưu tiên lấy dự báo tại đây,\nkhông cần bật GPS.',
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
        OutlinedButton(
          onPressed: () async {
            await logout();
            onChanged();
          },
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            side: const BorderSide(color: AppColors.down, width: 2),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text('Đăng xuất',
              style: TextStyle(
                  fontSize: AppFont.big,
                  fontWeight: FontWeight.w800,
                  color: AppColors.down)),
        ),
      ],
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
      leading: Text(online ? '🔎' : '🏙️', style: const TextStyle(fontSize: 26)),
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
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 16),
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
