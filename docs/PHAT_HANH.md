# Phát hành bản mới

Dành cho người giữ kho mã. Bà con cài theo link trong [README](../README.md#tải-về).

```
PHAT_HANH.bat ──► thẻ v1.3.0 ──► GitHub Actions ──► Release v1.3.0
                                  • chạy test           ├─ HeFarmer.apk
                                  • build APK, ký       └─ SHA256SUMS.txt
                                                               │
     App: tự báo "Có bản mới" mỗi ngày 1 lần ◄─────────────────┤
     App: tab Tôi → Kiểm tra cập nhật ◄────────────────────────┘
```

Chỉ **gắn thẻ phiên bản** mới phát hành. Merge vào `main` không phát hành gì
cả — CI (`ci.yml`) vẫn build thử mỗi lần đẩy code để chắc `main` luôn build
được.

---

## Việc làm một lần: khoá ký APK

Android chỉ cho cài bản mới đè lên bản cũ khi cả hai **ký bằng cùng một
khoá**. Khoá này phải giữ mãi: **mất khoá là mọi người dùng phải gỡ app cài
lại** (mất hồ sơ, cảnh báo giá, lịch sử giá).

1. Cần Android Studio (hoặc JDK 17) trên máy — chính cái đang dùng để build.
2. Nháy đúp **`TAO_KHOA_KY.bat`**. Script chọn khoá theo thứ tự:
   1. khoá đã cất ở `%USERPROFILE%\HeFarmer-khoa-ky\` (lần chạy trước);
   2. **khoá cũ theo [BAO-MAT.md](../BAO-MAT.md)** (`android\key.properties`)
      — điện thoại đang cài APK ký bằng khoá này cài đè được bản GitHub,
      **không phải gỡ app**;
   3. khoá debug của máy này (điện thoại cài app bằng `flutter run`);
   4. tạo khoá mới kèm mật khẩu ngẫu nhiên.

   Khoá được chép vào `%USERPROFILE%\HeFarmer-khoa-ky\`, ngoài kho mã, không
   bao giờ lên Git. Chưa có `android\key.properties` thì script tự ghi, để
   `flutter build apk --release` trên máy cũng ký bằng khoá này — APK tự build
   và APK tải từ GitHub cài đè lên nhau được.

   Sau đó script mở trang tạo secret của GitHub và chép sẵn từng giá trị vào
   clipboard. Bạn chỉ cần dán (Ctrl+V) và bấm **Add secret**:

   | Name | Secret |
   |---|---|
   | `ANDROID_KEYSTORE_BASE64` | (script đã chép sẵn) |
   | `ANDROID_KEYSTORE_PASSWORD` | (script đã chép sẵn) |
   | `ANDROID_KEY_ALIAS` | (script đã chép sẵn) |
   | `ANDROID_KEY_PASSWORD` | chỉ khi khoá cũ đặt mật khẩu khoá khác mật khẩu kho |

3. **Sao lưu thư mục `HeFarmer-khoa-ky`** sang USB, Google Drive… Không gửi
   cho ai, không đưa vào kho mã.

Chạy lại `TAO_KHOA_KY.bat` không tạo khoá mới — chỉ chép lại secret (dùng khi
cần dán lại, hoặc sang máy khác sau khi chép thư mục khoá qua).

---

## Việc làm một lần: bật trang tải

Trang https://thanghetanty.github.io/HeFarmer/ dựng từ thư mục `site/` bằng
workflow `.github/workflows/pages.yml` (giống HeDeck). GitHub chỉ cho bật bằng
tay:

1. Repo trên GitHub → **Settings** → **Pages** (cột trái).
2. Mục **Build and deployment** → **Source**: chọn **GitHub Actions**.
3. Tab **Actions** → **Trang tải** → **Run workflow** → **Run workflow**.
   Khoảng một phút sau trang chạy ở địa chỉ trên.

Trang tự hỏi GitHub bản phát hành mới nhất (số phiên bản, ngày, dung lượng,
ghi chú "Có gì mới"), nên phát hành bản mới **không** cần đăng lại trang.
Workflow chỉ tự chạy lại khi sửa `site/`. Ảnh app trong `site/images/` chụp
từ app thật với dữ liệu mẫu; sửa giao diện nhiều thì nên chụp lại.

Gửi bà con link trang thay vì link file APK: trang có hướng dẫn cài từng bước,
mã QR cho người đang xem trên máy tính, và báo rõ khi mở bằng iPhone.

---

## Mỗi lần phát hành

1. Merge mọi thay đổi vào `main`, rồi trên máy: `git checkout main` và
   `git pull`.
2. Nháy đúp **`PHAT_HANH.bat`**:
   - kiểm tra đang ở `main`, không còn thay đổi chưa commit, khớp GitHub;
   - gợi ý số phiên bản kế tiếp;
   - mở Notepad để viết **ghi chú thay đổi** — bà con đọc phần này trong app
     khi có bản mới, nên viết cho bà con chứ không cho lập trình viên
     (ví dụ: `- Chữ to hơn`, `- Thêm giá sầu riêng`);
   - gắn thẻ và đẩy lên GitHub.
3. Theo dõi ở tab **Actions** (khoảng 10 phút). Xong thì bản mới nằm ở tab
   **Releases**; app của bà con tự báo trong vòng một ngày (hoặc ngay khi bấm
   **Tôi → Kiểm tra cập nhật**).

Đánh số `chính.phụ.sửa`: sửa lỗi nhỏ tăng số cuối (`1.2.0 → 1.2.1`), thêm
tính năng tăng số giữa (`1.2.1 → 1.3.0`). Số phải luôn tăng — app chỉ coi là
bản mới khi số lớn hơn bản đang chạy.

Không dùng được `PHAT_HANH.bat` (ví dụ không phải Windows) thì gắn thẻ bằng
tay, kết quả như nhau:

```
git tag -a v1.3.0 -m "- Chữ to hơn"
git push origin v1.3.0
```

### Lỡ phát hành bản lỗi

Đừng xoá rồi đăng lại cùng số — máy đã tải bản lỗi sẽ không nhận ra bản sửa.
Sửa lỗi rồi phát hành số mới (`1.3.1`).

---

## Build hỏng trên GitHub

Mở lượt chạy đỏ trong tab **Actions**, bấm vào bước đỏ để xem log.

| Báo lỗi | Cách sửa |
|---|---|
| `Chưa có secret ANDROID_KEYSTORE_BASE64…` | Chạy `TAO_KHOA_KY.bat`, dán đủ secret. |
| `apksigner … password` / `Failed to load signer` | Secret mật khẩu, mật khẩu khoá hoặc alias sai — chạy lại `TAO_KHOA_KY.bat`, dán lại. |
| `Thẻ phải có dạng v1.2.3` | Xoá thẻ sai (`git push --delete origin <thẻ>`), gắn lại cho đúng. |
| Bước `flutter test` đỏ | Có test hỏng — sửa trên `main` rồi phát hành số mới. |

Build lại cùng thẻ sau khi sửa secret: tab **Actions** → lượt chạy đỏ →
**Re-run all jobs**.

Muốn build thử mà không phát hành: **Actions → Phát hành → Run workflow**
(APK chưa ký khoá phát hành, nằm ở mục Artifacts).

---

## Bên trong

- Workflow: [`.github/workflows/release.yml`](../.github/workflows/release.yml).
  Chạy `flutter test` trước, test hỏng thì không phát hành.
- Flutter ký APK bằng khoá debug như mọi khi; workflow dùng `apksigner` ký
  lại bằng khoá phát hành. File luôn tên `HeFarmer.apk`, nên link
  `releases/latest/download/HeFarmer.apk` luôn trỏ tới bản mới nhất.
- Số phiên bản lấy từ thẻ: `--build-name`, `versionCode = chính×1 000 000 +
  phụ×1 000 + sửa`, và `--dart-define=HEFARMER_VERSION` để app biết mình là
  bản nào. Bản tự build không có số này, tự coi là *"bản tự build"* và không
  tự nhắc cập nhật.
- App ([`lib/services/updater.dart`](../lib/services/updater.dart)) hỏi
  `api.github.com/repos/ThangHeTanTy/HeFarmer/releases/latest`, tải APK, so
  SHA-256 GitHub ghi cho file, rồi mở trình cài đặt qua `FileProvider` (kênh
  `hefarmer/update` trong `MainActivity.kt`). Android luôn bắt người dùng bấm
  **Cài đặt** — app ngoài Play Store không cài im lặng được.
- Tự nhắc: mở app thì hỏi GitHub tối đa 1 lần/ngày; bấm **Để sau** thì cùng
  bản đó 3 ngày sau mới nhắc lại.
- Cập nhật không đụng tới dữ liệu: Android giữ nguyên vùng dữ liệu riêng
  của app (hồ sơ, cảnh báo, SQLite lịch sử giá) khi cài đè bản cùng khoá ký.
  Chỉ **gỡ app** mới xoá.
- Ghi chú phát hành = lời ghi chú của thẻ, nối thêm
  [`.github/release_body.md`](../.github/release_body.md) (hướng dẫn cài lần
  đầu) sau dòng `---`. App chỉ hiện phần trên dòng đó.
- Bảng đối chiếu lỗi (`debug-symbols`, do `--obfuscate`) nằm ở mục Artifacts
  của lượt chạy, giữ 90 ngày; không đính vào Release vì công khai nó thì làm
  rối mã như không.
