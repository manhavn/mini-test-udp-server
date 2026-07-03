# Mini Test UDP Server CLI

Một công cụ CLI nhỏ gọn bằng Rust giúp khởi động một UDP Server để kiểm thử. Server hỗ trợ cấu hình cổng (port), địa chỉ IP (bind address), phản hồi tự động (Echo hoặc phản hồi tĩnh) và cung cấp các ví dụ lệnh kiểm tra đa dạng khi chạy với tham số `--help`.

## Tính năng

- **Tùy chọn cổng & IP**: Cấu hình linh hoạt thông qua `-p` / `--port` và `-b` / `--bind`.
- **Chế độ phản hồi linh hoạt**:
  - **Echo Mode** (mặc định): Tự động trả về chính xác dữ liệu client gửi lên.
  - **Static Response Mode**: Gửi lại nội dung tĩnh được cấu hình sẵn qua `-r` / `--response`.
- **Độc lập không phụ thuộc thư viện ngoài (Zero-dependency)**: Sử dụng thư viện chuẩn của Rust giúp biên dịch siêu nhanh và dung lượng file cực kỳ nhỏ gọn.
- **Tích hợp sẵn hướng dẫn chi tiết**: Hướng dẫn kiểm thử đa dạng sử dụng `nc` (netcat), `/dev/udp/` của bash, `python`, `socat`, và `nmap` trực tiếp từ đầu ra của `--help`.

---

## Cài đặt & Biên dịch

Yêu cầu máy tính của bạn đã cài đặt Rust (Cargo).

Bạn có thể biên dịch bằng lệnh cargo trực tiếp:
```bash
cargo build --release
```

Hoặc sử dụng script hỗ trợ build được cung cấp sẵn trong dự án:
```bash
./build.sh
```

File thực thi sau khi build sẽ nằm tại: `target/release/mini-test-udp-server`.

---

## Hướng dẫn sử dụng

### 1. Khởi chạy Server

Lắng nghe trên cổng mặc định `9999` ở tất cả giao diện mạng (`0.0.0.0`) ở chế độ Echo:
```bash
./target/release/mini-test-udp-server
```

Lắng nghe trên cổng tùy chọn (ví dụ: `8888`) và chỉ cho phép kết nối nội bộ (`127.0.0.1`):
```bash
./target/release/mini-test-udp-server --port 8888 --bind 127.0.0.1
```

Khởi chạy với một nội dung phản hồi cố định (ví dụ: `"ACK FROM SERVER"`):
```bash
./target/release/mini-test-udp-server -p 9999 -r "ACK FROM SERVER"
```

---

### 2. Các lệnh kiểm thử (Testing)

Bạn có thể chạy server trong một Terminal và mở Terminal thứ hai để chạy các lệnh kiểm thử sau:

#### A. Sử dụng Netcat (`nc`)
Gửi tin nhắn và nhận phản hồi trực tiếp:
```bash
echo "Hello UDP Server" | nc -u -w 1 127.0.0.1 9999
```

Chạy chế độ tương tác (nhập tin nhắn và xem phản hồi trực tiếp, nhấn `Ctrl+C` để thoát):
```bash
nc -u 127.0.0.1 9999
```

#### B. Sử dụng Bash `/dev/udp`
Gửi tin nhắn một chiều nhanh chóng tới server:
```bash
echo "Tin nhan tu dev udp" > /dev/udp/127.0.0.1/9999
```

Gửi nội dung một file văn bản:
```bash
cat file.txt > /dev/udp/127.0.0.1/9999
```
*(Lưu ý: `/dev/udp/` chỉ hỗ trợ gửi đi một chiều từ phía Bash shell, không nhận dữ liệu phản hồi ngược lại trên terminal này).*

#### C. Sử dụng Python (Để kiểm tra luồng nhận phản hồi đầy đủ)
```bash
python3 -c 'import socket; s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM); s.sendto(b"Hello from Python", ("127.0.0.1", 9999)); print("Phản hồi:", s.recvfrom(1024)[0].decode())'
```

#### D. Sử dụng `socat`
Gửi và nhận dữ liệu phản hồi:
```bash
echo "Hello via socat" | socat - UDP:127.0.0.1:9999
```

#### E. Sử dụng Nmap (`nmap`)
Quét kiểm tra trạng thái cổng UDP 9999 (Cần quyền root/sudo):
```bash
sudo nmap -sU -p 9999 127.0.0.1
```
