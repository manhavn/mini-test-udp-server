#!/bin/bash
# Script build multi-arch bằng Podman và push lên Docker Hub hoặc GHCR (GitHub Container Registry)
# Sử dụng cargo-zigbuild để biên dịch chéo (cross-compile) tránh lỗi QEMU emulation (exec format error)

set -e

# Mã màu ANSI để làm đẹp console
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${BLUE}===================================================${NC}"
echo -e "${BLUE}       PODMAN MULTI-ARCH BUILD & PUSH SCRIPT       ${NC}"
echo -e "${BLUE}        (Sử dụng cargo-zigbuild để tối ưu)        ${NC}"
echo -e "${BLUE}===================================================${NC}"

# 1. Kiểm tra sự tồn tại của các công cụ cần thiết
DEPENDENCIES_OK=true

if ! command -v podman &> /dev/null; then
    echo -e "${RED}[!] Không tìm thấy podman trên hệ thống.${NC}"
    echo -e "${YELLOW}[*] Vui lòng cài đặt Podman trước khi chạy script này.${NC}"
    echo -e "    - Ubuntu/Debian: sudo apt update && sudo apt install -y podman"
    echo -e "    - macOS (Homebrew): brew install podman"
    echo -e "    - CentOS/RHEL/Fedora: sudo dnf install -y podman"
    DEPENDENCIES_OK=false
fi

if ! command -v cargo &> /dev/null; then
    echo -e "${RED}[!] Không tìm thấy Cargo (Rust toolchain) trên hệ thống.${NC}"
    echo -e "${YELLOW}[*] Vui lòng cài đặt Rust và Cargo từ https://rustup.rs${NC}"
    DEPENDENCIES_OK=false
fi

if ! command -v zig &> /dev/null; then
    echo -e "${RED}[!] Không tìm thấy trình biên dịch 'zig' (cần thiết cho cargo-zigbuild).${NC}"
    echo -e "${YELLOW}[*] Vui lòng cài đặt Zig bằng một trong các lệnh sau:${NC}"
    echo -e "    - Sử dụng pip (nhanh nhất): ${GREEN}pip install ziglang${NC}"
    echo -e "    - macOS (Homebrew): ${GREEN}brew install zig${NC}"
    echo -e "    - Ubuntu/Debian: ${GREEN}sudo apt update && sudo apt install -y zig${NC}"
    echo -e "    - Fedora/RHEL: ${GREEN}sudo dnf install -y zig${NC}"
    DEPENDENCIES_OK=false
fi

if ! cargo zigbuild --version &> /dev/null; then
    echo -e "${YELLOW}[!] Không tìm thấy cargo-zigbuild. Đang cố gắng cài đặt tự động...${NC}"
    if cargo install cargo-zigbuild; then
        echo -e "${GREEN}[✓] Đã cài đặt cargo-zigbuild thành công!${NC}"
    else
        echo -e "${RED}[!] Tự động cài đặt cargo-zigbuild thất bại. Vui lòng cài đặt thủ công bằng lệnh: cargo install cargo-zigbuild${NC}"
        DEPENDENCIES_OK=false
    fi
fi

if [ "$DEPENDENCIES_OK" = false ]; then
    echo -e "${RED}[!] Vui lòng cài đặt đầy đủ các công cụ thiếu ở trên rồi chạy lại script.${NC}"
    exit 1
fi

# 2. Đọc thông tin từ Cargo.toml (nếu có)
DEFAULT_APP_NAME="mini-test-udp-server"
DEFAULT_VERSION="latest"

if [ -f "Cargo.toml" ]; then
    CARGO_NAME=$(grep -m 1 '^name' Cargo.toml | awk -F '"' '{print $2}')
    CARGO_VERSION=$(grep -m 1 '^version' Cargo.toml | awk -F '"' '{print $2}')
    if [ -n "$CARGO_NAME" ]; then
        DEFAULT_APP_NAME="$CARGO_NAME"
    fi
    if [ -n "$CARGO_VERSION" ]; then
        DEFAULT_VERSION="$CARGO_VERSION"
    fi
fi

# 3. Chọn Registry
echo -e "\n${CYAN}[1/4] Chọn registry để đẩy ảnh lên:${NC}"
echo -e "  1) Docker Hub (docker.io)"
echo -e "  2) GitHub Container Registry (ghcr.io)"
read -p "Lựa chọn của bạn (1-2, mặc định là 1): " REGISTRY_CHOICE

case "$REGISTRY_CHOICE" in
    2)
        REGISTRY="ghcr.io"
        ;;
    *)
        REGISTRY="docker.io"
        ;;
esac

echo -e "-> Đã chọn registry: ${GREEN}$REGISTRY${NC}"

# 4. Nhập thông tin xác thực
echo -e "\n${CYAN}[2/4] Nhập thông tin tài khoản đăng nhập:${NC}"

# Xác định biến môi trường tương ứng với registry đã chọn
if [ "$REGISTRY" = "ghcr.io" ]; then
    ENV_USER="$GHCR_USER"
    ENV_TOKEN="$GHCR_TOKEN"
    ENV_USER_VAR="GHCR_USER"
    ENV_TOKEN_VAR="GHCR_TOKEN"
else
    ENV_USER="$DOCKERHUB_USER"
    ENV_TOKEN="$DOCKERHUB_TOKEN"
    ENV_USER_VAR="DOCKERHUB_USER"
    ENV_TOKEN_VAR="DOCKERHUB_TOKEN"
fi

if [ -n "$ENV_USER" ]; then
    USERNAME="$ENV_USER"
    echo -e "-> Đang sử dụng Username từ env \$${ENV_USER_VAR}: ${GREEN}$USERNAME${NC}"
else
    read -r -p "Username: " USERNAME
fi

if [ -n "$ENV_TOKEN" ]; then
    TOKEN="$ENV_TOKEN"
    echo -e "-> Đang sử dụng Password/Token từ env \$${ENV_TOKEN_VAR} (độ dài: ${#TOKEN} ký tự)"
else
    # Đọc token/password ẩn (không hiện trên màn hình)
    echo -n "Password/Token: "
    read -r -s TOKEN
    echo "" # Xuống dòng sau khi nhập password ẩn
fi

# Loại bỏ khoảng trắng ở đầu/cuối và ký tự xuống dòng Windows (\r) nếu copy-paste bị dính
USERNAME=$(echo "$USERNAME" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e 's/\r//g')
TOKEN=$(echo "$TOKEN" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e 's/\r//g')

if [ -z "$USERNAME" ] || [ -z "$TOKEN" ]; then
    echo -e "${RED}[!] Username và Password/Token không được để trống!${NC}"
    exit 1
fi

# Thiết lập DEFAULT_REPO dựa trên USERNAME vừa nhập
DEFAULT_REPO="$REGISTRY/$USERNAME/$DEFAULT_APP_NAME"

# 5. Xác định tên Repository và Tag
echo -e "\n${CYAN}[3/4] Nhập thông tin Image Repository:${NC}"
read -p "Tên Repository (Mặc định: $DEFAULT_REPO): " REPO_INPUT
REPO="${REPO_INPUT:-$DEFAULT_REPO}"

# Đảm bảo tiền tố registry hợp lệ
if [[ "$REPO" != "$REGISTRY"* ]]; then
    REPO=$(echo "$REPO" | sed -E "s|^(docker.io\|ghcr.io)/||")
    REPO="$REGISTRY/$REPO"
fi

read -p "Image Tag (Mặc định: $DEFAULT_VERSION): " TAG_INPUT
TAG="${TAG_INPUT:-$DEFAULT_VERSION}"

FULL_IMAGE_NAME="${REPO}:${TAG}"
echo -e "-> Target Image: ${GREEN}${FULL_IMAGE_NAME}${NC}"

# 6. Xác nhận và tiến hành Build
echo -e "\n${CYAN}[4/4] Bắt đầu quá trình build & push...${NC}"
echo -e "---------------------------------------------------"
echo -e "Target Platforms : ${YELLOW}linux/amd64, linux/arm64${NC}"
echo -e "Runtime Base     : ${YELLOW}docker.io/library/alpine:latest${NC}"
echo -e "Image Tag        : ${GREEN}${FULL_IMAGE_NAME}${NC}"
echo -e "---------------------------------------------------"

# Đăng nhập vào Registry trước để tránh lỗi khi kéo base image hoặc push
echo -e "\n${YELLOW}[+] Đăng nhập vào ${REGISTRY}...${NC}"
echo -e "    Username: ${GREEN}$USERNAME${NC}"
echo -e "    Độ dài Password/Token: ${YELLOW}${#TOKEN}${NC} ký tự"

if ! printf "%s" "$TOKEN" | podman login --username "$USERNAME" --password-stdin "$REGISTRY"; then
    if [ "$REGISTRY" = "docker.io" ]; then
        echo -e "${YELLOW}[!] Đăng nhập docker.io thất bại. Thử lại với registry-1.docker.io...${NC}"
        if printf "%s" "$TOKEN" | podman login --username "$USERNAME" --password-stdin "registry-1.docker.io"; then
            echo -e "${GREEN}[✓] Đăng nhập thành công qua registry-1.docker.io!${NC}"
            REGISTRY="registry-1.docker.io"
            FULL_IMAGE_NAME=$(echo "$FULL_IMAGE_NAME" | sed "s|docker.io/|registry-1.docker.io/|")
        else
            echo -e "${RED}[!] Đăng nhập thất bại vào cả docker.io và registry-1.docker.io.${NC}"
            echo -e "${YELLOW}[*] Gợi ý: Hãy thử chạy lệnh sau trực tiếp trên Terminal để kiểm tra thông tin tài khoản:${NC}"
            echo -e "    ${CYAN}podman login -u $USERNAME docker.io${NC}"
            exit 1
        fi
    else
        echo -e "${RED}[!] Đăng nhập thất bại vào $REGISTRY.${NC}"
        echo -e "${YELLOW}[*] Gợi ý: Hãy thử chạy lệnh sau trực tiếp trên Terminal để kiểm tra thông tin tài khoản:${NC}"
        echo -e "    ${CYAN}podman login -u $USERNAME $REGISTRY${NC}"
        exit 1
    fi
fi

# Đảm bảo các target toolchain của Rust đã được cài đặt
echo -e "\n${YELLOW}[+] Đảm bảo các target toolchain của Rust đã được cài đặt...${NC}"
rustup target add x86_64-unknown-linux-musl aarch64-unknown-linux-musl

# Biên dịch ứng dụng cho amd64 (x86_64) và arm64 (aarch64) sử dụng cargo-zigbuild trên máy host (Native)
# Sử dụng RUSTFLAGS="-A linker_messages" để ẩn cảnh báo không đáng có của linker LLD/Zig
echo -e "\n${YELLOW}[+] Đang biên dịch chéo cho linux/amd64 (x86_64-unknown-linux-musl) bằng cargo-zigbuild...${NC}"
RUSTFLAGS="-A linker_messages" cargo zigbuild --target x86_64-unknown-linux-musl --release

echo -e "\n${YELLOW}[+] Đang biên dịch chéo cho linux/arm64 (aarch64-unknown-linux-musl) bằng cargo-zigbuild...${NC}"
RUSTFLAGS="-A linker_messages" cargo zigbuild --target aarch64-unknown-linux-musl --release

# Chuẩn bị cấu trúc thư mục chứa các binary đã build để Containerfile copy vào
echo -e "\n${YELLOW}[+] Chuẩn bị cấu trúc thư mục chứa các binary...${NC}"
mkdir -p target/bin/amd64 target/bin/arm64
cp target/x86_64-unknown-linux-musl/release/"$DEFAULT_APP_NAME" target/bin/amd64/
cp target/aarch64-unknown-linux-musl/release/"$DEFAULT_APP_NAME" target/bin/arm64/

# Xóa manifest cũ nếu tồn tại
echo -e "\n${YELLOW}[+] Tạo manifest list cho multi-arch build...${NC}"
if podman manifest exists "$FULL_IMAGE_NAME" &>/dev/null; then
    podman manifest rm "$FULL_IMAGE_NAME"
fi
podman manifest create "$FULL_IMAGE_NAME"

# Build cho amd64 (không biên dịch trong Container, chỉ COPY)
echo -e "\n${YELLOW}[+] Đang đóng gói container image cho linux/amd64...${NC}"
podman build \
    --platform linux/amd64 \
    --manifest "$FULL_IMAGE_NAME" \
    -f Containerfile .

# Build cho arm64 (không biên dịch trong Container, chỉ COPY)
echo -e "\n${YELLOW}[+] Đang đóng gói container image cho linux/arm64...${NC}"
podman build \
    --platform linux/arm64 \
    --manifest "$FULL_IMAGE_NAME" \
    -f Containerfile .

# Đẩy Manifest lên Registry
echo -e "\n${YELLOW}[+] Đang push manifest và các image thành phần lên ${REGISTRY}...${NC}"
podman manifest push "$FULL_IMAGE_NAME" "docker://$FULL_IMAGE_NAME"

# Nếu tag hiện tại không phải là "latest", tiến hành đẩy thêm tag "latest"
if [ "$TAG" != "latest" ]; then
    LATEST_IMAGE_NAME="${REPO}:latest"
    echo -e "${YELLOW}[+] Đang đẩy thêm tag 'latest': ${LATEST_IMAGE_NAME}...${NC}"
    podman manifest push "$FULL_IMAGE_NAME" "docker://$LATEST_IMAGE_NAME"
    echo -e "\n${GREEN}[✓] Hoàn thành! Đã đẩy cả 2 tag: ${FULL_IMAGE_NAME} và ${LATEST_IMAGE_NAME}${NC}"
else
    echo -e "\n${GREEN}[✓] Hoàn thành! Đã đẩy thành công image lên ${FULL_IMAGE_NAME}${NC}"
fi

# 7. Dọn dẹp tài nguyên tạm thời
echo -e "\n${YELLOW}[+] Đang dọn dẹp tài nguyên tạm thời trên máy local...${NC}"
# Xóa manifest local (các component image cũng được giải phóng)
if podman manifest exists "$FULL_IMAGE_NAME" &>/dev/null; then
    podman manifest rm "$FULL_IMAGE_NAME"
fi
# Xóa thư mục chứa binary trung gian
rm -rf target/bin/
# Dọn dẹp các dangling images tạm thời được tạo ra trong quá trình build
podman image prune -f
echo -e "${GREEN}[✓] Đã dọn dẹp xong local manifest, thư mục target/bin/ và dọn dẹp ảnh tạm (prune)!${NC}"

# Đăng xuất để bảo mật
podman logout "$REGISTRY"
