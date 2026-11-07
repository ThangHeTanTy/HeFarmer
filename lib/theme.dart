import 'package:flutter/material.dart';

/// Bảng màu & cỡ chữ dùng chung — thiết kế cho người cao tuổi:
/// chữ to, tương phản cao, màu tăng/giảm tách bạch rõ ràng.
class AppColors {
  static const primary = Color(0xFF1B5E20); // xanh lá đậm — nông nghiệp
  static const primaryLight = Color(0xFFE8F5E9);
  static const background = Colors.white;
  static const card = Color(0xFFF6F8F4);
  static const text = Color(0xFF111111);
  static const textMuted = Color(0xFF4A4A4A);
  static const up = Color(0xFF0B7A2F); // giá tăng — xanh
  static const upBg = Color(0xFFDCF3E3);
  static const down = Color(0xFFC62828); // giá giảm — đỏ
  static const downBg = Color(0xFFFBE3E3);
  static const flat = Color(0xFF616161); // đứng giá — xám
  static const flatBg = Color(0xFFEEEEEE);
  static const buy = Color(0xFF0D47A1); // giá mua — xanh dương đậm
  static const buyBg = Color(0xFFE3EDFB);
  static const sell = Color(0xFFB35C00); // giá bán — cam đất đậm
  static const sellBg = Color(0xFFFCEEDD);
  static const border = Color(0xFFD8DED4);
}

class AppFont {
  static const double huge = 34; // con số giá chính
  static const double title = 24;
  static const double big = 21;
  static const double body = 19;
  static const double small = 16;
}
