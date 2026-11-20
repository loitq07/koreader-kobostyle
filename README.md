# KOReader E-Ink UI Plugin (`kobostyle.koplugin`)

Bản thiết kế lại toàn diện giao diện **KOReader** theo chuẩn hệ thống thiết kế **[E-Ink UI](https://eink-ui.com/components)** (kết hợp triết lý monochrome tối giản của shadcn và tính năng đọc truyện tranh chuyên sâu của **Mihon**).

---

## 🎨 Ngôn ngữ Thiết kế E-Ink UI (`eink-ui.com`)

1. **Phân cấp Đường nét (Line-Weight Hierarchy)**:
   - Thay thế toàn bộ đổ bóng mờ (`box-shadow`) và gradient lem nhem bằng các đường viền nét căng chuẩn mực:
     - `1px Hairline`: Viền thẻ sách, viền capsule badges, đường chia phân mục nhỏ.
     - `2px Normal`: Ranh giới trên/dưới của thanh điều hướng (Top/Bottom Bar boundaries), trạng thái chọn.
     - `3px Heavy`: Điểm nhấn tab đang hoạt động (Active Indicator Bar), đường phân tách drawer.
2. **Đảo màu tương phản cao (Inverted Fill)**:
   - Các nút kích hoạt, tab hoặc tag quan trọng sử dụng nền đen thuần (`#000000`) chữ trắng (`#FFFFFF`) để tạo độ tương phản cực đại trên tấm nền E-ink.
3. **Vùng chạm lớn (Touch Ergonomics)**:
   - Tất cả các nút bấm và tab điều hướng đều đạt chiều cao tối thiểu **≥ 48px** để loại bỏ hiện tượng bấm nhầm khi cầm máy 1 tay.

---

## 📚 1. Màn Thư viện (Library Screen - Mihon 3-Column Grid)

- **Lưới bìa sách 3 cột (Cover Grid / Mosaic)**:
  - Tự động hiển thị toàn bộ truyện và sách dưới dạng lưới bìa 3 cột lớn, sắc nét, có tỷ lệ chuẩn truyện tranh.
- **Thanh điều hướng đáy E-Ink UI (58px)**:
  1. 🏠 **Trang chủ (`house`)**: Lịch sử các cuốn sách đang đọc gần đây.
  2. 📚 **Sách của tôi (`books`)**: Lưới bìa sách 3 cột kiểu Mihon.
  3. 🔖 **Bộ sưu tập (`bookmark`)**: Phân loại theo bộ truyện (Series) và tác giả.
  4. 📊 **Thống kê (`chart-bar`)**: Thời gian đọc sách và số trang đã đọc.
  5. ⋯ **Thêm (`dots-three`)**: Mở nhanh các cài đặt chuyên sâu của KOReader.

---

## 📖 2. Trình Đọc Sách & Truyện Tranh (Reader Overlay)

Chạm vào giữa màn hình để hiển thị giao diện điều khiển với 2 thanh trên/dưới:

### Thanh trên (Top Bar)
- ⬅️ **Nút Quay lại**: Thoát ngay về thư viện.
- 📖 **Tiêu đề sách + Badge số trang**: `[Trang 45/180]` hiển thị rõ ràng.
- 🔄 **Nút chuyển nhanh Manga (`[MANGA (RTL)]` / `[LTR]`)**: Bấm 1 chạm để đảo ngay chiều lật trang từ Phải-sang-Trái (chuẩn Manga Nhật Bản) sang Trái-sang-Phải mà không cần lục tìm trong menu con.
- 🔍 **Tìm kiếm toàn văn** & 🔖 **Đánh dấu trang**.

### Thanh dưới (Bottom Bar)
- **Hàng Badges thông tin**:
  - `[Tiến độ: XX%]` (Nền đen đảo màu nổi bật).
  - `[Tên chương hiện tại]`.
  - `[Còn XX trang]`.
- **Thanh trượt tiến độ 4px (E-Ink Slider)**:
  - Có vạch chia chương (`ticks`) và 2 nút tua nhanh `[-10]` và `[+10]` trang ở hai bên.
- **5 Nút chức năng chính**:
  1. 📑 **Mục lục (`list-bullets`)**
  2. 📖 **Manga & PDF (`book-open`)**: Mở bảng điều khiển nhanh dạng Bottom Drawer.
  3. 💡 **Độ sáng đèn nền (`sun`)**
  4. 🧭 **Nhảy trang (`navigation-arrow`)**
  5. ⚙️ **Cài đặt đầy đủ (`dots-three-vertical`)**

---

## 🗂️ 3. Bảng điều khiển Manga & PDF (Bottom Drawer)
Khi bấm vào nút **Manga & PDF**, một bảng trượt từ đáy màn hình xuất hiện với các công tắc phân đoạn (Segmented Controls) chuẩn `eink-ui`:
1. **Chiều lật trang**: `[ LTR: Trái sang Phải ]` | `[ RTL: Manga (Phải sang Trái) ]`
2. **Cắt viền trắng (Auto-Crop Margin)**: `[ Tắt ]` | `[ Cắt tự động (Toàn màn) ]` | `[ Bán tự động ]`
3. **Khung hiển thị hình ảnh**: `[ Vừa trang ]` | `[ Vừa chiều ngang ]` | `[ Vừa nội dung ]`

---

## 🚀 Cách cài đặt lên máy đọc sách Kobo
1. Cắm máy Kobo vào máy tính qua cáp USB và chọn **Connect** trên màn hình Kobo.
2. Mở PowerShell trong thư mục này và chạy:
   ```powershell
   powershell -ExecutionPolicy Bypass -File ".\install_to_kobo.ps1"
   ```
3. Script sẽ tự động:
   - Cài đặt plugin `kobostyle.koplugin` phiên bản E-Ink UI 2.0.
   - Đồng bộ toàn bộ Phosphor Icons vào `.adds/koreader/icons/`.
   - Cấu hình hiển thị lưới bìa 3 cột Mihon vào `settings.reader.lua`.
