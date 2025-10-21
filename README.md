
## 📖 Hướng Dẫn Sử Dụng

Công cụ này giúp bạn reset cấu hình Cursor

### Yêu Cầu Hệ Thống

- Windows, macOS hoặc Linux
- Python 3.8 trở lên (nếu chạy từ source code)
- Quyền quản trị viên (Administrator/Root)

### Cài Đặt & Chạy

#### **Windows**

Mở PowerShell với quyền Administrator và chạy:

```powershell
irm https://raw.githubusercontent.com/minhcopilot/cursor-reset-id/main/scripts/install.ps1 | iex
```

#### **Linux/macOS**

Mở Terminal và chạy:

```bash
curl -fsSL https://raw.githubusercontent.com/minhcopilot/cursor-reset-id/main/scripts/install.sh -o install.sh && chmod +x install.sh && ./install.sh
```

### Sử Dụng

Sau khi chạy, bạn sẽ thấy menu với các lựa chọn:

- **0** - Thoát chương trình
- **1** - Reset ID máy (Machine ID)
- **2** - Thoát Cursor
- **3** - Chọn ngôn ngữ
- **4** - Tắt tự động cập nhật

### Lưu Ý Quan Trọng

⚠️ **Đảm bảo đóng Cursor trước khi chạy công cụ**

⚠️ **Chạy với quyền Administrator/Root**

⚠️ **Backup dữ liệu quan trọng trước khi sử dụng**

### Cấu Hình

File cấu hình nằm tại:
- **Windows**: `Documents\.cursor-free-vip\config.ini`
- **macOS/Linux**: `Documents/.cursor-free-vip/config.ini`

### Dừng Script

Nhấn **Ctrl+C** để dừng script bất kỳ lúc nào.

---

## ⚠️ Miễn Trừ Trách Nhiệm

Công cụ này chỉ dành cho mục đích học tập và nghiên cứu. Người sử dụng tự chịu trách nhiệm về mọi hậu quả phát sinh.

---

## 📝 Giấy Phép

[CC BY-NC-ND 4.0](https://creativecommons.org/licenses/by-nc-nd/4.0/)
