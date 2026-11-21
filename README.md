# Dữ liệu giá HeFarmer

Nhánh này do GitHub Actions (`.github/workflows/prices.yml`) tự sinh —
**đừng sửa tay**, lần chạy sau sẽ ghi đè.

- `latest.json` — giá mới nhất của mọi mặt hàng (ứng dụng tải file này)
- `history/<id>.json` — giá trung bình theo ngày
- `health.json` — tình trạng từng nguồn (nguồn nào đang hỏng)

Giá chỉ mang tính tham khảo, có thể chênh lệch với đại lý tại địa phương.
