import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/updater.dart';
import '../theme.dart';

/// Hộp thoại CẬP NHẬT: hỏi GitHub, hiện ghi chú thay đổi, tải APK rồi mở
/// trình cài đặt của Android.
///
/// [known]: bản mới đã biết (khi app tự hỏi lúc mở) -> vào thẳng bước
/// "Có bản mới", không hỏi lại GitHub.
Future<void> showUpdateDialog(BuildContext context, {Release? known}) =>
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _UpdateDialog(known: known),
    );

enum _Step { checking, latest, available, downloading, ready, failed }

class _UpdateDialog extends StatefulWidget {
  final Release? known;
  const _UpdateDialog({this.known});

  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<_UpdateDialog> {
  _Step _step = _Step.checking;
  Release? _rel;
  File? _apk;
  double _progress = 0;
  String _error = '';

  @override
  void initState() {
    super.initState();
    final k = widget.known;
    if (k != null) {
      _rel = k;
      _step = _Step.available;
    } else {
      _check();
    }
  }

  Future<void> _check() async {
    setState(() => _step = _Step.checking);
    try {
      final rel = await Updater.check();
      if (!mounted) return;
      setState(() {
        _rel = rel;
        _step = rel == null ? _Step.latest : _Step.available;
      });
    } catch (_) {
      _fail('Không kết nối được. Bác kiểm tra mạng (3G/Wi-Fi) rồi thử lại.');
    }
  }

  Future<void> _download() async {
    setState(() {
      _step = _Step.downloading;
      _progress = 0;
    });
    try {
      final apk = await Updater.download(_rel!, onProgress: (p) {
        if (mounted) setState(() => _progress = p);
      });
      if (!mounted) return;
      setState(() {
        _apk = apk;
        _step = _Step.ready;
      });
      await _install();
    } on FormatException {
      _fail('File tải về bị hỏng. Bác bấm "Thử lại" nhé.');
    } on MissingPluginException {
      _fail('Bản này chưa có bộ cập nhật. Bác tải bản mới ở trang '
          '${Updater.releasesPage}');
    } catch (_) {
      _fail('Tải bản mới chưa được. Bác kiểm tra mạng rồi thử lại.');
    }
  }

  Future<void> _install() async {
    try {
      await Updater.install(_apk!);
    } on PlatformException catch (e) {
      _fail('Không mở được trình cài đặt: ${e.message ?? e.code}');
    }
  }

  void _fail(String msg) {
    if (!mounted) return;
    setState(() {
      _error = msg;
      _step = _Step.failed;
    });
  }

  Future<void> _later() async {
    final rel = _rel;
    if (rel != null && _step == _Step.available) {
      await Updater.snooze(rel.version);
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    const muted =
        TextStyle(fontSize: AppFont.small, color: AppColors.textMuted, height: 1.4);
    const body = TextStyle(fontSize: AppFont.body, color: AppColors.text, height: 1.4);
    final current = Updater.selfBuilt
        ? 'Bản tự build trên máy'
        : 'Bác đang dùng bản ${Updater.version}';

    Widget content;
    final actions = <Widget>[];
    void close([String label = 'Đóng']) => actions.add(TextButton(
        onPressed: _later,
        child: Text(label, style: const TextStyle(fontSize: AppFont.body))));
    Widget primary(String label, VoidCallback onPressed) => ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          ),
          child: Text(label,
              style: const TextStyle(
                  fontSize: AppFont.body,
                  fontWeight: FontWeight.w800,
                  color: Colors.white)),
        );

    switch (_step) {
      case _Step.checking:
        content = const Row(children: [
          SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                  strokeWidth: 3, color: AppColors.primary)),
          SizedBox(width: 14),
          Expanded(child: Text('Đang kiểm tra bản mới...', style: body)),
        ]);
        close('Huỷ');
      case _Step.latest:
        content = const Row(children: [
          Text('✅', style: TextStyle(fontSize: 28)),
          SizedBox(width: 12),
          Expanded(child: Text('Bác đang dùng bản mới nhất rồi.', style: body)),
        ]);
        close();
      case _Step.available:
        final rel = _rel!;
        content = Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('🎉 Có bản mới ${rel.version}',
                style: const TextStyle(
                    fontSize: AppFont.big,
                    fontWeight: FontWeight.w900,
                    color: AppColors.primary)),
            const SizedBox(height: 8),
            if (rel.notes.isNotEmpty)
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 220),
                child: SingleChildScrollView(child: Text(rel.notes, style: body)),
              ),
            const SizedBox(height: 10),
            const Text(
                'Cập nhật không mất hồ sơ, vị trí, cảnh báo giá hay lịch sử '
                'giá. Điện thoại sẽ hỏi "Cài đặt?" — bác bấm Cài đặt. Lần '
                'đầu điện thoại hỏi có cho HeFarmer cài ứng dụng không — bác '
                'bật cho phép rồi bấm quay lại.',
                style: muted),
          ],
        );
        close('Để sau');
        actions.add(primary('Cập nhật ngay', _download));
      case _Step.downloading:
        final known = _progress >= 0;
        content = Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                known
                    ? 'Đang tải bản ${_rel!.version}... ${(_progress * 100).round()}%'
                    : 'Đang tải bản ${_rel!.version}...',
                style: body),
            const SizedBox(height: 12),
            LinearProgressIndicator(
                value: known ? _progress : null,
                minHeight: 10,
                color: AppColors.primary),
          ],
        );
      case _Step.ready:
        content = const Text(
            'Tải xong. Bác bấm "Cài đặt" trên màn hình điện thoại để hoàn tất. '
            'Lỡ đóng mất thì bấm "Mở lại trình cài đặt".',
            style: body);
        close();
        actions.add(primary('Mở lại trình cài đặt', _install));
      case _Step.failed:
        content = Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('⚠️', style: TextStyle(fontSize: 24)),
          const SizedBox(width: 8),
          Expanded(child: Text(_error, style: body)),
        ]);
        close();
        actions.add(primary('Thử lại', _rel == null ? _check : _download));
    }

    return AlertDialog(
      title: const Row(children: [
        Text('🔄', style: TextStyle(fontSize: 26)),
        SizedBox(width: 10),
        Expanded(
          child: Text('Cập nhật HeFarmer',
              style: TextStyle(
                  fontSize: AppFont.big, fontWeight: FontWeight.w900)),
        ),
      ]),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(current, style: muted),
            const SizedBox(height: 12),
            content,
          ],
        ),
      ),
      actions: actions,
    );
  }
}
