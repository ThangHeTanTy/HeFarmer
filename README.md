# 🤡🌾 HeFarmer

Ứng dụng Android giúp bà con nông dân — đặc biệt là người cao tuổi — theo dõi
**giá nông sản, vật nuôi, vật tư, vàng bạc** và **dự báo thời tiết** để chủ động
sắp xếp công việc và chọn thời điểm bán được giá.

Thiết kế xuyên suốt cho người lớn tuổi: chữ to, màu tương phản rõ, thao tác
tối giản, có nút đọc thành tiếng, và mọi con số đều kèm lời giải thích.

---

## Tính năng

### 🌱 Giá nông sản cây công nghiệp
Mủ cao su (mủ nước theo độ TSC, mủ đông/mủ tạp), cà phê nhân xô, hồ tiêu,
ngô (bắp), khoai lang, khoai mì (sắn), đậu phộng, đậu nành.

### 🐓 Giá vật nuôi
Heo hơi (theo miền Bắc/Trung/Nam), gà (công nghiệp, lông màu, gà ta),
vịt và ngan, trứng (gà, vịt, cút — tính theo đồng/quả), bò và dê hơi.

### 🧪 Giá vật tư đầu vào
Phân bón (Ure, DAP, Kali, NPK, Lân) và thức ăn chăn nuôi (cám heo, cám gà,
ngô hạt, khô đậu tương) — để nhìn được cả hai đầu của bài toán lãi lỗ.

### 🪙 Giá vàng, bạc
Vàng miếng SJC, nhẫn SJC 9999, vàng miếng PNJ, nhẫn PNJ 24K, DOJI, Bảo Tín,
bạc miếng. Giá thế giới được **tự quy đổi sang đồng/lượng** theo tỷ giá
USD/VND cập nhật — không hiển thị USD để người cao tuổi khỏi phải nhẩm.

### ⛅ Dự báo thời tiết + gợi ý việc nhà nông
Nhiệt độ, độ ẩm, tốc độ gió, khả năng mưa, dự báo 4 ngày, bản đồ mây mưa Windy.
Quan trọng nhất là mục **"Hôm nay nên làm gì?"** — dịch số liệu thành việc cụ thể:

> 🌾 *Không nên phơi nông sản hôm nay — khả năng mưa 80%, bác nên thu gom và che bạt sớm.*
> 🌬️ *Hoãn phun thuốc — gió 30 km/h làm thuốc bay mất, vừa phí vừa hại sức khoẻ.*
> 📅 *Sắp có 3 ngày ráo liên tiếp — thuận lợi thu hoạch, nên sắp xếp nhân công trước.*

### 👤 Tài khoản
Đăng ký / đăng nhập lưu ngay trong máy (mật khẩu băm SHA-256), đổi ảnh đại diện,
và đặt **"Vị trí của tôi"** với gợi ý 34 tỉnh/thành sau sáp nhập 7/2025 — tab
Thời tiết sẽ ưu tiên vị trí này nên bà con **không cần biết cách bật GPS**.

### Tiện ích dùng chung ở mọi thẻ giá
| | |
|---|---|
| 🧮 **Tính tiền** | Nhập số kg → ra thành tiền chữ to, kèm đọc chữ *"khoảng 113 triệu 760 nghìn đồng"* |
| 📈 **Biểu đồ** | Xu hướng giá nhiều ngày, kèm tóm tắt *"▼ Giảm 2.500 (2,6%) trong 12 ngày qua"* |
| 🔔 **Báo giá** | Đặt mức mong muốn, app báo ra màn hình điện thoại khi giá chạm mức |
| 🔊 **Đọc to** | Đọc giá bằng tiếng Việt đúng cách nói dân gian (hai mươi **mốt**, chín mươi **tư**, mười **lăm**) |
| ▼ **Thu gọn** | Chạm tiêu đề để gấp thẻ không cần xem; app nhớ trạng thái cho lần sau |

---

## Nguồn dữ liệu

Việt Nam chưa có API công khai miễn phí cho phần lớn mặt hàng nông sản, nên app
đọc từ các trang giá uy tín cập nhật hằng ngày, với **cơ chế dự phòng xếp tầng**
(khoảng 80 nguồn): nguồn 1 lỗi thì tự chuyển nguồn 2, 3… Nếu mọi nguồn đều
không có dữ liệu, app hiển thị số gần nhất đã lưu kèm thông báo rõ ràng.

- **Thời tiết:** [Open-Meteo](https://open-meteo.com) (miễn phí, không cần khoá) + bản đồ [Windy](https://windy.com)
- **Vàng:** API JSON vang.today, XML chính thức sjc.com.vn, PNJ, Phú Quý, Bảo Tín Minh Châu
- **Cao su:** banggianongsan.com, chogia.vn, phuriengrubber.vn (trang chính chủ), giacaphe.com…
- **Nông sản / vật nuôi / vật tư:** giacaphe.com, giatieu.com, vietnambiz.vn, webgia.com,
  Tạp chí Chăn nuôi Việt Nam (bảng giá tại trại theo ngày), nhabeagri.com…
- **Địa danh:** danh sách 34 tỉnh/thành ngoại tuyến + geocoding Open-Meteo
- **Tỷ giá:** open.er-api.com

> ⚠️ Giá chỉ mang tính tham khảo, có thể chênh lệch với đại lý tại địa phương.

---

## Chạy thử

```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

Yêu cầu: Flutter SDK 3.3+ và Android SDK (kèm **Android SDK Command-line Tools**).
Trên Windows, nếu PowerShell chặn script thì dùng CMD hoặc chạy một lần
`Set-ExecutionPolicy RemoteSigned -Scope CurrentUser`.

## Đổi icon ứng dụng

```bash
dart run flutter_launcher_icons
```

Icon nguồn: `assets/icon/icon.png` (1024×1024).

## Build APK

```bash
flutter build apk --release
```

File: `build/app/outputs/flutter-apk/app-release.apk`

Bản phát hành có ký số riêng và chống dịch ngược — xem [BAO-MAT.md](BAO-MAT.md):

```bash
flutter build apk --release --obfuscate --split-debug-info=build/debug-info
```

---

## Cấu trúc mã nguồn

```
lib/
├── main.dart                     # 6 tab, thanh tab bán cung nổi, màn hình chào
├── theme.dart                    # màu sắc & cỡ chữ (chỉnh chữ to hơn ở đây)
├── screens/
│   ├── price_screen.dart         # màn hình giá (dùng chung 4 tab giá)
│   ├── weather_screen.dart       # thời tiết + gợi ý việc nhà nông + bản đồ
│   ├── account_screen.dart       # đăng nhập, avatar, chọn vị trí có gợi ý
│   └── alert_screen.dart         # hộp thoại báo giá & máy tính tiền bán
├── widgets/
│   └── price_chart.dart          # biểu đồ giá tự vẽ (không dùng thư viện ngoài)
└── services/
    ├── price_parser.dart         # bóc tách giá từ HTML/JSON/XML (thuần Dart, có test)
    ├── price_service.dart        # nguồn dữ liệu, dự phòng, lịch sử, tải sẵn ngầm
    ├── weather_service.dart      # vị trí thiết bị + Open-Meteo
    ├── farm_advice.dart          # dịch thời tiết thành lời khuyên công việc
    ├── alert_service.dart        # cảnh báo giá & thông báo
    ├── speech_service.dart       # đọc tiếng Việt + đọc số đúng cách nói dân gian
    ├── account_service.dart      # tài khoản lưu trong máy
    └── vn_places.dart            # 34 tỉnh/thành + tìm địa danh có gợi ý
test/                             # ~60 test cho bộ bóc tách giá, gợi ý, đọc số
```

## Ghi chú kỹ thuật

- **Độ mượt:** tab đầu tải xong sẽ âm thầm tải sẵn các tab còn lại; các tab đã mở
  được giữ sống trong `IndexedStack` nên quay lại là hiện ngay, đúng vị trí đang
  cuộn; chỉ tải lại khi dữ liệu đã quá 10 phút (kéo xuống để làm mới ngay).
- **Riêng tư:** mọi dữ liệu cá nhân (tài khoản, vị trí, lịch sử giá, cảnh báo)
  chỉ nằm trong máy người dùng. App không có máy chủ, không SDK quảng cáo,
  không theo dõi, và chỉ xin 3 quyền: Internet, Vị trí, Thông báo.

## Ghi công

Biểu tượng cảm xúc trong icon: [Twemoji](https://github.com/jdecked/twemoji) — giấy phép CC-BY 4.0.
