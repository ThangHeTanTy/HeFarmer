# HƯỚNG DẪN BUILD BẢO MẬT 🔒

## App này bảo vệ người dùng thế nào
1. CHỐNG DỊCH NGƯỢC: bật R8 minify + shrinkResources (xáo trộn tên lớp/hàm
   Java/Kotlin, bỏ mã và tài nguyên thừa) + lệnh build kèm --obfuscate để
   xáo trộn cả mã Dart. Kẻ xấu mở APK ra chỉ thấy tên hàm vô nghĩa.
2. CHỐNG SỬA APK / CHÈN QUYỀN TỪ BÊN NGOÀI: quyền của app nằm cố định trong
   AndroidManifest lúc build (chỉ 3 quyền: Internet + Vị trí). APK được KÝ SỐ
   bằng khóa riêng của bạn — ai sửa file APK (thêm quyền, chèn mã độc, gắn
   quảng cáo) chữ ký sẽ vỡ, Android từ chối cài đè và người dùng phân biệt
   được bản giả. Vì vậy PHẢI tạo khóa riêng (bước dưới), đừng dùng khóa debug.
3. KHÓA THÊM: allowBackup=false (không cho trích xuất dữ liệu app qua sao lưu),
   usesCleartextTraffic=false (chặn mọi kết nối HTTP không mã hóa — app chỉ
   dùng HTTPS), không nhúng bất kỳ SDK quảng cáo/theo dõi nào, mật khẩu tài
   khoản băm SHA-256 và mọi dữ liệu cá nhân chỉ nằm trong máy người dùng.

## Bước 1 — Tạo khóa ký riêng (làm 1 lần, GIỮ CẨN THẬN)
Mở CMD tại thư mục android/ của dự án, chạy:

  keytool -genkey -v -keystore hefarmer-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias hefarmer

(keytool có sẵn theo Android Studio; nếu không nhận lệnh, dùng đường dẫn
"C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe" ...)
Nhập mật khẩu kho khóa + thông tin tùy ý. File hefarmer-release.jks sẽ nằm
trong thư mục android/. TUYỆT ĐỐI không đưa file này và mật khẩu cho ai;
mất nó là không phát hành bản cập nhật cùng chữ ký được nữa.

## Bước 2 — Khai báo khóa cho Gradle
Tạo file android/key.properties với nội dung (thay mật khẩu thật):

  storePassword=MAT_KHAU_KHO
  keyPassword=MAT_KHAU_KHOA
  keyAlias=hefarmer
  storeFile=../hefarmer-release.jks

## Bước 3 — Build bản phát hành bảo mật

  flutter build apk --release --obfuscate --split-debug-info=build/debug-info

APK ở build\app\outputs\flutter-apk\app-release.apk (đã ký khóa riêng, đã
xáo trộn). Thư mục build/debug-info chứa bản đồ giải mã lỗi — GIỮ LẠI cho
mình để đọc log crash, KHÔNG kèm vào APK, không gửi ai.

Ghi chú: `flutter run` hằng ngày vẫn hoạt động bình thường (chưa có
key.properties thì tự dùng khóa debug, không ảnh hưởng lập trình).
