# db_demo

## 🛠️ Bắt đầu

### Yêu cầu hệ thống

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (phiên bản ^3.10.7)
- Android Studio / VS Code với tiện ích mở rộng Flutter
- Trình giả lập hoặc thiết bị vật lý 

### Cài đặt

1. **Clone repository:**
   ```bash
   git clone https://github.com/TQanh23/db_demo.git
   cd db_demo
   ```

2. **Cài đặt các dependency:**
   ```bash
   flutter pub get
   ```

3. **Tạo Code tự động (Code Generation):**
   Dự án này sử dụng code generation cho schema của Isar và Hive. Bạn **phải** chạy lệnh này trước khi build:
   ```bash
   dart run build_runner build --delete-conflicting-outputs
   ```

4. **Chạy ứng dụng:**
   ```bash
   flutter run
   ```

## 📂 Cấu trúc dự án

- `lib/services/`: Chứa các bản thực thi của từng dịch vụ cơ sở dữ liệu.
- `lib/models/`: Các model dữ liệu được sử dụng để benchmark.
- `lib/screens/`: Các màn hình UI, bao gồm dashboard đo hiệu năng.
- `lib/collections/`: Các định nghĩa collection dành riêng cho Isar.
