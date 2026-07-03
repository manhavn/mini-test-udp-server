#!/bin/bash
# Script hỗ trợ biên dịch nhanh dự án UDP Server ở chế độ Release

echo -e "\e[1;32m[+] Đang biên dịch dự án ở chế độ Release...\e[0m"
cargo build --release

if [ $? -eq 0 ]; then
    echo -e "\e[1;36m[+] Biên dịch thành công!\e[0m"
    echo -e "    File thực thi tại: \e[1;33m./target/release/mini-test-udp-server\e[0m"
    echo -e "    Bạn có thể khởi chạy server bằng lệnh:"
    echo -e "    \e[1;32m./target/release/mini-test-udp-server -p 9999\e[0m"
else
    echo -e "\e[1;31m[!] Lỗi biên dịch!\e[0m"
    exit 1
fi
