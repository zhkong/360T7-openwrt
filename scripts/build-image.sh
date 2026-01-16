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
        echo "正在获取最新 OpenWrt 版本..." >&2
        version=$(curl -s https://api.github.com/repos/openwrt/openwrt/releases/latest | grep '"tag_name":' | sed -E 's/.*"v?([^"]+)".*/\1/' | head -n 1)
        
        if [ -z "$version" ]; then
            # 备用方案：从下载页面获取
            version=$(curl -s https://downloads.openwrt.org/releases/ | grep -oP 'href="\K[0-9]+\.[0-9]+\.[0-9]+(?=/")' | sort -V | tail -n 1)
        fi
        
        # 最终备用
        if [ -z "$version" ]; then
            version="24.10.0"
            echo "警告: 无法获取最新版本，使用默认版本 $version" >&2
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
    
    echo "==========================================" >&2
    echo "下载 OpenWrt ImageBuilder ${version}..." >&2
    echo "URL: $url" >&2
    echo "==========================================" >&2
    
    if [ ! -f "$filename" ]; then
        # 尝试下载
        if ! curl -L -o "$filename" "$url"; then
            # 如果 .zst 不存在，尝试 .tar.xz
            url="https://downloads.openwrt.org/releases/${version}/targets/${TARGET}/${SUBTARGET}/openwrt-imagebuilder-${version}-${TARGET}-${SUBTARGET}.Linux-x86_64.tar.xz"
            filename="openwrt-imagebuilder-${version}-${TARGET}-${SUBTARGET}.Linux-x86_64.tar.xz"
            echo "尝试备用格式: $url" >&2
            curl -L -o "$filename" "$url"
        fi
    else
        echo "ImageBuilder 已存在，跳过下载" >&2
    fi
    
    # 解压
    local extract_dir="openwrt-imagebuilder-${version}-${TARGET}-${SUBTARGET}.Linux-x86_64"
    
    # 检查目录是否存在且完整（验证 Makefile 是否存在）
    local need_extract=true
    if [ -d "$extract_dir" ] && [ -f "$extract_dir/Makefile" ]; then
        echo "ImageBuilder 目录已存在且完整，跳过解压" >&2
        need_extract=false
    elif [ -d "$extract_dir" ]; then
        echo "警告: ImageBuilder 目录存在但不完整（缺少 Makefile），将重新解压..." >&2
        rm -rf "$extract_dir"
    fi
    
    if [ "$need_extract" = true ]; then
        echo "解压 ImageBuilder..." >&2
        if [[ "$filename" == *.zst ]]; then
            if ! tar --use-compress-program=unzstd -xf "$filename"; then
                echo "错误: 解压失败" >&2
                exit 1
            fi
        else
            if ! tar -xf "$filename"; then
                echo "错误: 解压失败" >&2
                exit 1
            fi
        fi
    fi
    
    # 检查解压后的目录
    if [ ! -d "$extract_dir" ]; then
        echo "错误: 解压后未找到目录: $extract_dir" >&2
        echo "当前目录: $(pwd)" >&2
        echo "目录内容:" >&2
        ls -la >&2
        exit 1
    fi
    
    # 验证关键文件是否存在
    if [ ! -f "$extract_dir/Makefile" ]; then
        echo "错误: 解压后的目录中未找到 Makefile，解压可能不完整" >&2
        echo "目录内容:" >&2
        ls -la "$extract_dir" | head -20 >&2
        exit 1
    fi
    
    echo "ImageBuilder 解压完成，Makefile 验证通过" >&2
    
    # 返回绝对路径
    local abs_path="$BUILD_DIR/$extract_dir"
    if [ -d "$abs_path" ]; then
        # 使用 realpath 或 cd+pwd 获取绝对路径
        if command -v realpath &> /dev/null; then
            abs_path=$(realpath "$abs_path")
        else
            abs_path=$(cd "$abs_path" && pwd)
        fi
    else
        echo "错误: ImageBuilder 目录不存在: $abs_path" >&2
        exit 1
    fi
    
    echo "$abs_path"
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
    
    # 检查 ImageBuilder 目录是否存在
    if [ ! -d "$imagebuilder_dir" ]; then
        echo "错误: ImageBuilder 目录不存在: $imagebuilder_dir" >&2
        exit 1
    fi
    
    echo "ImageBuilder 目录: $imagebuilder_dir"
    echo "当前工作目录: $(pwd)"
    echo ""
    
    # 切换到 ImageBuilder 目录
    cd "$imagebuilder_dir" || {
        echo "错误: 无法切换到 ImageBuilder 目录: $imagebuilder_dir" >&2
        exit 1
    }
    
    echo "切换后的工作目录: $(pwd)"
    echo "目录内容:"
    ls -la | head -20
    echo ""
    
    # 检查 Makefile 是否存在
    if [ ! -f "Makefile" ]; then
        echo "错误: 在 ImageBuilder 目录中找不到 Makefile" >&2
        echo "当前目录内容:" >&2
        ls -la >&2
        exit 1
    fi
    
    echo "Makefile 存在，继续构建..."
    echo ""
    
    # 获取软件包列表
    local packages=$(get_all_packages)
    
    echo "软件包: $packages"
    echo ""
    
    # 构建命令
    echo "执行构建命令..."
    echo "PROFILE=$PROFILE"
    echo "PACKAGES=$packages"
    echo "FILES=$FILES_DIR"
    echo ""
    
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
    # 复制 sha256sums 文件（如果存在）
    if [ -f "$imagebuilder_dir/bin/targets/$TARGET/$SUBTARGET/sha256sums" ]; then
        cp -v "$imagebuilder_dir/bin/targets/$TARGET/$SUBTARGET/sha256sums" "$PROJECT_DIR/output/" 2>/dev/null || true
    fi
    
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
