#!/bin/bash
# ============================================================
# OpenWrt ImageBuilder 自动构建脚本
# 用于 360T7 (MediaTek Filogic MT7981) 设备
# 功能：使用预编译的 ImageBuilder 快速构建自定义固件
# ============================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
CONFIG_DIR="$PROJECT_DIR/config"
BUILD_DIR="$PROJECT_DIR/imagebuilder"
FILES_DIR="$BUILD_DIR/custom-files"

# 加载软件包配置
source "$CONFIG_DIR/packages.conf"

# ==================== 获取 OpenWrt 版本 ====================
get_openwrt_version() {
    local version=""
    
    # 从环境变量或文件获取版本
    if [ -n "$OPENWRT_TAG" ]; then
        version="$OPENWRT_TAG"
    elif [ -f /tmp/openwrt_tag.txt ]; then
        version=$(cat /tmp/openwrt_tag.txt)
    else
        # 获取最新的稳定版本
        echo "正在获取最新 OpenWrt 版本..."
        version=$(curl -s https://api.github.com/repos/openwrt/openwrt/releases/latest | grep '"tag_name":' | sed -E 's/.*"v?([^"]+)".*/\1/' | head -n 1)
        
        if [ -z "$version" ]; then
            # 备用方案：从下载页面获取
            version=$(curl -s https://downloads.openwrt.org/releases/ | grep -oP 'href="\K[0-9]+\.[0-9]+\.[0-9]+(?=/")' | sort -V | tail -n 1)
        fi
        
        # 最终备用
        if [ -z "$version" ]; then
            version="24.10.0"
            echo "警告: 无法获取最新版本，使用默认版本 $version"
        fi
    fi
    
    # 清理版本号（移除 'v' 前缀如果存在）
    version="${version#v}"
    echo "$version"
}

# ==================== 下载 ImageBuilder ====================
download_imagebuilder() {
    local version="$1"
    local url="https://downloads.openwrt.org/releases/${version}/targets/${TARGET}/${SUBTARGET}/openwrt-imagebuilder-${version}-${TARGET}-${SUBTARGET}.Linux-x86_64.tar.zst"
    local filename="openwrt-imagebuilder-${version}-${TARGET}-${SUBTARGET}.Linux-x86_64.tar.zst"
    
    mkdir -p "$BUILD_DIR"
    cd "$BUILD_DIR"
    
    echo "=========================================="
    echo "下载 OpenWrt ImageBuilder ${version}..."
    echo "URL: $url"
    echo "=========================================="
    
    if [ ! -f "$filename" ]; then
        # 尝试下载
        if ! curl -L -o "$filename" "$url"; then
            # 如果 .zst 不存在，尝试 .tar.xz
            url="https://downloads.openwrt.org/releases/${version}/targets/${TARGET}/${SUBTARGET}/openwrt-imagebuilder-${version}-${TARGET}-${SUBTARGET}.Linux-x86_64.tar.xz"
            filename="openwrt-imagebuilder-${version}-${TARGET}-${SUBTARGET}.Linux-x86_64.tar.xz"
            echo "尝试备用格式: $url"
            curl -L -o "$filename" "$url"
        fi
    else
        echo "ImageBuilder 已存在，跳过下载"
    fi
    
    # 解压
    local extract_dir="openwrt-imagebuilder-${version}-${TARGET}-${SUBTARGET}.Linux-x86_64"
    if [ ! -d "$extract_dir" ]; then
        echo "解压 ImageBuilder..."
        if [[ "$filename" == *.zst ]]; then
            tar --use-compress-program=unzstd -xf "$filename"
        else
            tar -xf "$filename"
        fi
    fi
    
    echo "$BUILD_DIR/$extract_dir"
}

# ==================== 构建固件 ====================
build_firmware() {
    local imagebuilder_dir="$1"
    local version="$2"
    
    echo "=========================================="
    echo "开始构建固件..."
    echo "设备: $PROFILE"
    echo "版本: $version"
    echo "=========================================="
    
    cd "$imagebuilder_dir"
    
    # 获取软件包列表
    local packages=$(get_all_packages)
    
    echo "软件包: $packages"
    echo ""
    
    # 构建命令
    make image \
        PROFILE="$PROFILE" \
        PACKAGES="$packages" \
        FILES="$FILES_DIR" \
        EXTRA_IMAGE_NAME="custom"
    
    echo ""
    echo "=========================================="
    echo "构建完成！"
    echo "=========================================="
    
    # 显示输出文件
    echo "固件文件位置:"
    ls -lh "$imagebuilder_dir/bin/targets/$TARGET/$SUBTARGET/"*.bin 2>/dev/null || echo "未找到 .bin 文件"
    ls -lh "$imagebuilder_dir/bin/targets/$TARGET/$SUBTARGET/"*.img* 2>/dev/null || echo "未找到 .img 文件"
    
    # 复制到项目输出目录
    mkdir -p "$PROJECT_DIR/output"
    cp -v "$imagebuilder_dir/bin/targets/$TARGET/$SUBTARGET/"*"$PROFILE"* "$PROJECT_DIR/output/" 2>/dev/null || true
    
    echo ""
    echo "固件已复制到: $PROJECT_DIR/output/"
    ls -lh "$PROJECT_DIR/output/"
}

# ==================== 主程序 ====================
main() {
    echo "=============================================="
    echo "  OpenWrt ImageBuilder 自动构建脚本"
    echo "  目标设备: 360T7 (MediaTek Filogic MT7981)"
    echo "=============================================="
    echo ""
    
    # 检查依赖
    for cmd in curl tar git make; do
        if ! command -v "$cmd" &> /dev/null; then
            echo "错误: 缺少依赖 '$cmd'"
            exit 1
        fi
    done
    
    # 检查 zstd (可选)
    if ! command -v unzstd &> /dev/null; then
        echo "警告: 未安装 zstd，将尝试使用 .tar.xz 格式"
    fi
    
    # 检查配置文件
    if [ ! -f "$CONFIG_DIR/packages.conf" ]; then
        echo "错误: 找不到配置文件 $CONFIG_DIR/packages.conf"
        exit 1
    fi
    
    # 获取版本
    VERSION=$(get_openwrt_version)
    echo "OpenWrt 版本: $VERSION"
    echo ""
    
    # 下载 ImageBuilder
    IMAGEBUILDER_DIR=$(download_imagebuilder "$VERSION")
    echo "ImageBuilder 目录: $IMAGEBUILDER_DIR"
    echo ""
    
    # 创建自定义文件
    echo "创建自定义文件..."
    bash "$SCRIPT_DIR/setup-imagebuilder-files.sh" "$FILES_DIR"
    echo ""
    
    # 构建固件
    build_firmware "$IMAGEBUILDER_DIR" "$VERSION"
}

# 运行主程序
main "$@"
