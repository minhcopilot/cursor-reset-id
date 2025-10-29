#!/bin/bash

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Check and request sudo permissions at the start (macOS/Linux)
check_sudo() {
    if [[ "$(uname)" != "MINGW"* && "$(uname)" != "MSYS"* ]]; then
        if [ "$EUID" -ne 0 ]; then
            echo -e "${YELLOW}⚠️  Script này cần quyền sudo để sửa đổi các file của Cursor${NC}"
            echo -e "${CYAN}ℹ️  Đang yêu cầu quyền quản trị...${NC}"
            
            # Re-run script with sudo
            if command -v sudo >/dev/null 2>&1; then
                sudo "$0" "$@"
                exit $?
            else
                echo -e "${RED}❌ Không tìm thấy sudo, vui lòng chạy script với quyền root${NC}"
                exit 1
            fi
        fi
    fi
}

# Check and close Cursor app (macOS only)
close_cursor_app() {
    if [[ "$(uname)" == "Darwin" ]]; then
        if pgrep -x "Cursor" > /dev/null; then
            echo -e "${YELLOW}⚠️  Phát hiện Cursor đang chạy${NC}"
            echo -e "${CYAN}ℹ️  Đang đóng Cursor...${NC}"
            
            osascript -e 'quit app "Cursor"' 2>/dev/null || killall Cursor 2>/dev/null
            
            # Wait for app to close
            sleep 2
            
            if pgrep -x "Cursor" > /dev/null; then
                echo -e "${RED}❌ Không thể đóng Cursor. Vui lòng đóng thủ công và chạy lại script${NC}"
                exit 1
            fi
            
            echo -e "${GREEN}✅ Đã đóng Cursor thành công${NC}"
        fi
    fi
}

# Logo
print_logo() {
    echo -e "${CYAN}"
    cat << "EOF"
   ██████╗██╗   ██╗██████╗ ███████╗ ██████╗ ██████╗      ██████╗ ██████╗  ██████╗   
  ██╔════╝██║   ██║██╔══██╗██╔════╝██╔═══██╗██╔══██╗     ██╔══██╗██╔══██╗██╔═══██╗  
  ██║     ██║   ██║██████╔╝███████╗██║   ██║██████╔╝     ██████╔╝██████╔╝██║   ██║  
  ██║     ██║   ██║██╔══██╗╚════██║██║   ██║██╔══██╗     ██╔═══╝ ██╔══██╗██║   ██║  
  ╚██████╗╚██████╔╝██║  ██║███████║╚██████╔╝██║  ██║     ██║     ██║  ██║╚██████╔╝  
   ╚═════╝ ╚═════╝ ╚═╝  ╚═╝╚══════╝ ╚═════╝ ╚═╝  ╚═╝     ╚═╝     ╚═╝  ╚═╝ ╚═════╝  
EOF
    echo -e "${NC}"
}

# Get download folder path
get_downloads_dir() {
    if [[ "$(uname)" == "Darwin" ]]; then
        echo "$HOME/Downloads"
    else
        if [ -f "$HOME/.config/user-dirs.dirs" ]; then
            . "$HOME/.config/user-dirs.dirs"
            echo "${XDG_DOWNLOAD_DIR:-$HOME/Downloads}"
        else
            echo "$HOME/Downloads"
        fi
    fi
}

# Get latest version
get_latest_version() {
    echo -e "${CYAN}ℹ️ Đang kiểm tra phiên bản mới nhất...${NC}"
    latest_release=$(curl -s https://api.github.com/repos/yeongpin/cursor-free-vip/releases/latest) || {
        echo -e "${RED}❌ Không thể lấy thông tin phiên bản mới nhất${NC}"
        exit 1
    }
    
    VERSION=$(echo "$latest_release" | grep -o '"tag_name": ".*"' | cut -d'"' -f4 | tr -d 'v')
    if [ -z "$VERSION" ]; then
        echo -e "${RED}❌ Không thể phân tích phiên bản từ GitHub API:\n${latest_release}"
        exit 1
    fi

    echo -e "${GREEN}✅ Tìm thấy phiên bản mới nhất: ${VERSION}${NC}"
}

# Detect system type and architecture
detect_os() {
    if [[ "$(uname)" == "Darwin" ]]; then
        # Detect macOS architecture
        ARCH=$(uname -m)
        if [[ "$ARCH" == "arm64" ]]; then
            OS="mac_arm64"
            echo -e "${CYAN}ℹ️ Phát hiện macOS ARM64 (Apple Silicon)${NC}"
        else
            OS="mac_intel"
            echo -e "${CYAN}ℹ️ Phát hiện macOS Intel${NC}"
        fi
    elif [[ "$(uname)" == "Linux" ]]; then
        # Detect Linux architecture
        ARCH=$(uname -m)
        if [[ "$ARCH" == "aarch64" || "$ARCH" == "arm64" ]]; then
            OS="linux_arm64"
            echo -e "${CYAN}ℹ️ Phát hiện Linux ARM64${NC}"
        else
            OS="linux_x64"
            echo -e "${CYAN}ℹ️ Phát hiện Linux x64${NC}"
        fi
    else
        # Assume Windows
        OS="windows"
        echo -e "${CYAN}ℹ️ Phát hiện hệ điều hành Windows${NC}"
    fi
}

# Install and download
install_cursor_free_vip() {
    local downloads_dir=$(get_downloads_dir)
    local binary_name="CursorFreeVIP_${VERSION}_${OS}"
    local binary_path="${downloads_dir}/${binary_name}"
    local download_url="https://github.com/minhcopilot/cursor-reset-id/releases/download/v${VERSION}/${binary_name}"
    
    # Check if file already exists
    if [ -f "${binary_path}" ]; then
        echo -e "${GREEN}✅ Đã tìm thấy file cài đặt${NC}"
        echo -e "${CYAN}ℹ️ Vị trí: ${binary_path}${NC}"
        echo -e "${CYAN}ℹ️ Đang khởi động chương trình...${NC}"
        
        chmod +x "${binary_path}"
        "${binary_path}"
        return
    fi
    
    echo -e "${CYAN}ℹ️ Không tìm thấy file cài đặt, bắt đầu tải xuống...${NC}"
    echo -e "${CYAN}ℹ️ Đang tải về ${downloads_dir}...${NC}"
    echo -e "${CYAN}ℹ️ Link tải: ${download_url}${NC}"
    
    # Check if file exists
    if curl --output /dev/null --silent --head --fail "$download_url"; then
        echo -e "${GREEN}✅ File tồn tại, bắt đầu tải xuống...${NC}"
    else
        echo -e "${RED}❌ Link tải không tồn tại: ${download_url}${NC}"
        echo -e "${YELLOW}⚠️ Đang thử phiên bản không phân biệt kiến trúc...${NC}"
        
        # Try without architecture
        if [[ "$OS" == "mac_arm64" || "$OS" == "mac_intel" ]]; then
            OS="mac"
            binary_name="CursorFreeVIP_${VERSION}_${OS}"
            download_url="https://github.com/minhcopilot/cursor-reset-id/releases/download/v${VERSION}/${binary_name}"
            echo -e "${CYAN}ℹ️ Link tải mới: ${download_url}${NC}"
            
            if ! curl --output /dev/null --silent --head --fail "$download_url"; then
                echo -e "${RED}❌ Link tải mới không tồn tại${NC}"
                exit 1
            fi
        elif [[ "$OS" == "linux_x64" || "$OS" == "linux_arm64" ]]; then
            OS="linux"
            binary_name="CursorFreeVIP_${VERSION}_${OS}"
            download_url="https://github.com/minhcopilot/cursor-reset-id/releases/download/v${VERSION}/${binary_name}"
            echo -e "${CYAN}ℹ️ Link tải mới: ${download_url}${NC}"
            
            if ! curl --output /dev/null --silent --head --fail "$download_url"; then
                echo -e "${RED}❌ Link tải mới không tồn tại${NC}"
                exit 1
            fi
        else
            exit 1
        fi
    fi
    
    # Download file
    if ! curl -L -o "${binary_path}" "$download_url"; then
        echo -e "${RED}❌ Tải xuống thất bại${NC}"
        exit 1
    fi
    
    # Check downloaded file size
    local file_size=$(stat -f%z "${binary_path}" 2>/dev/null || stat -c%s "${binary_path}" 2>/dev/null)
    echo -e "${CYAN}ℹ️ Kích thước file đã tải: ${file_size} bytes${NC}"
    
    # If file is too small, it might be an error message
    if [ "$file_size" -lt 1000 ]; then
        echo -e "${YELLOW}⚠️ Cảnh báo: File tải xuống quá nhỏ, có thể không phải file thực thi hợp lệ${NC}"
        echo -e "${YELLOW}⚠️ Nội dung file:${NC}"
        cat "${binary_path}"
        echo ""
        echo -e "${RED}❌ Tải xuống thất bại, vui lòng kiểm tra phiên bản và hệ điều hành${NC}"
        exit 1
    fi
    
    echo -e "${CYAN}ℹ️ Đang thiết lập quyền thực thi...${NC}"
    if chmod +x "${binary_path}"; then
        echo -e "${GREEN}✅ Cài đặt hoàn tất!${NC}"
        echo -e "${CYAN}ℹ️ Chương trình đã được tải về: ${binary_path}${NC}"
        echo -e "${CYAN}ℹ️ Đang khởi động chương trình...${NC}"
        
        # Run program directly
        "${binary_path}"
    else
        echo -e "${RED}❌ Cài đặt thất bại${NC}"
        exit 1
    fi
}

# Main program
main() {
    print_logo
    check_sudo "$@"
    close_cursor_app
    get_latest_version
    detect_os
    install_cursor_free_vip
}

# Run main program
main "$@" 
