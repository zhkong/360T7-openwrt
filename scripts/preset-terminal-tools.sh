#!/bin/bash
# ============================================================
# OpenWrt 终端工具预配置脚本
# 配置 zsh 为默认 shell，安装 oh-my-zsh 及插件
# ============================================================

set -e

OPENWRT_DIR="${1:-openwrt}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA_DIR="$(dirname "$SCRIPT_DIR")/data"

if [ ! -d "$OPENWRT_DIR" ]; then
    echo "错误: OpenWrt 目录不存在: $OPENWRT_DIR"
    exit 1
fi

cd "$OPENWRT_DIR"

echo "=========================================="
echo "开始配置终端工具..."
echo "=========================================="

# ==================== 创建文件系统目录 ====================
echo "创建文件系统目录结构..."
mkdir -p files/root
mkdir -p files/etc/profile.d

# ==================== 安装 Oh-My-Zsh ====================
echo "克隆 oh-my-zsh 仓库..."
if [ -d "files/root/.oh-my-zsh" ]; then
    echo "oh-my-zsh 已存在，跳过克隆"
else
    git clone --depth=1 https://github.com/ohmyzsh/ohmyzsh.git files/root/.oh-my-zsh
fi

# ==================== 安装 Zsh 插件 ====================
echo "安装 zsh 插件..."

# zsh-autosuggestions - 命令自动建议
if [ ! -d "files/root/.oh-my-zsh/custom/plugins/zsh-autosuggestions" ]; then
    echo "  - 安装 zsh-autosuggestions..."
    git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions \
        files/root/.oh-my-zsh/custom/plugins/zsh-autosuggestions
fi

# zsh-syntax-highlighting - 语法高亮
if [ ! -d "files/root/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting" ]; then
    echo "  - 安装 zsh-syntax-highlighting..."
    git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting.git \
        files/root/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting
fi

# zsh-completions - 额外的命令补全
if [ ! -d "files/root/.oh-my-zsh/custom/plugins/zsh-completions" ]; then
    echo "  - 安装 zsh-completions..."
    git clone --depth=1 https://github.com/zsh-users/zsh-completions \
        files/root/.oh-my-zsh/custom/plugins/zsh-completions
fi

# ==================== 复制 .zshrc 配置文件 ====================
echo "复制 .zshrc 配置文件..."
if [ -f "$DATA_DIR/zsh/.zshrc" ]; then
    cp "$DATA_DIR/zsh/.zshrc" files/root/.zshrc
    echo "  - 已从 data/zsh/.zshrc 复制配置"
else
    echo "警告: $DATA_DIR/zsh/.zshrc 不存在，将创建默认配置"
    # 创建一个简单的默认配置
    cat > files/root/.zshrc << 'ZSHRC'
export ZSH="$HOME/.oh-my-zsh"
export LANG=zh_CN.UTF-8
export LC_ALL=zh_CN.UTF-8
export TERM=xterm-256color
ZSH_THEME="agnoster"
DEFAULT_USER="root"
DISABLE_AUTO_UPDATE="true"
plugins=(git zsh-autosuggestions zsh-syntax-highlighting zsh-completions)
source $ZSH/oh-my-zsh.sh
# 显示 OpenWrt Banner
if [[ -o login ]] && [[ -o interactive ]]; then
    [[ -f /etc/banner ]] && cat /etc/banner
fi
ZSHRC
fi

# ==================== 修改默认 Shell 为 Zsh ====================
echo "设置 zsh 为默认 shell..."

# 方法1: 修改 passwd 模板文件
if [ -f "package/base-files/files/etc/passwd" ]; then
    sed -i 's|root:x:0:0:root:/root:/bin/ash|root:x:0:0:root:/root:/usr/bin/zsh|g' \
        package/base-files/files/etc/passwd
    echo "  - 已修改 package/base-files/files/etc/passwd"
fi

# 方法2: 创建首次启动脚本来确保默认 shell 被修改
mkdir -p files/usr/libexec/uci-defaults
cat > files/usr/libexec/uci-defaults/99-set-default-shell-zsh << 'UCIEOF'
#!/bin/sh
# 设置 root 用户默认 shell 为 zsh

# 检查 zsh 是否存在
if [ -x /usr/bin/zsh ]; then
    # 修改 /etc/passwd 中 root 用户的 shell
    if grep -q "root:.*:/bin/ash" /etc/passwd; then
        sed -i 's|root:\([^:]*\):\([^:]*\):\([^:]*\):\([^:]*\):\([^:]*\):/bin/ash|root:\1:\2:\3:\4:\5:/usr/bin/zsh|' /etc/passwd
        echo "Default shell changed to zsh"
    fi
fi
UCIEOF
chmod +x files/usr/libexec/uci-defaults/99-set-default-shell-zsh

# ==================== 创建 .profile 确保环境变量 ====================
echo "创建 profile 配置..."
cat > files/root/.profile << 'PROFILE'
# ~/.profile: executed by the command interpreter for login shells

# UTF-8 支持
export LANG=zh_CN.UTF-8
export LC_ALL=zh_CN.UTF-8
export LANGUAGE=zh_CN:zh:en_US:en
export TERM=xterm-256color

# 如果运行的是 zsh，则 .zshrc 已经处理了 banner
# 这里为 ash 等其他 shell 保留 banner 显示
if [ -z "$ZSH_VERSION" ]; then
    [ -f /etc/banner ] && cat /etc/banner
fi
PROFILE

# ==================== 创建终端配置确保 UTF-8 ====================
echo "配置终端 UTF-8 支持..."
cat > files/etc/profile.d/99-utf8-terminal.sh << 'EOF'
#!/bin/sh
# 终端 UTF-8 配置

export LANG=zh_CN.UTF-8
export LC_ALL=zh_CN.UTF-8
export LANGUAGE=zh_CN:zh:en_US:en

# 设置终端类型支持 256 色
if [ "$TERM" = "xterm" ] || [ "$TERM" = "screen" ]; then
    export TERM="${TERM}-256color"
fi
EOF
chmod +x files/etc/profile.d/99-utf8-terminal.sh

# ==================== 清理 Git 目录减小体积 ====================
echo "清理 Git 目录以减小固件体积..."
find files/root/.oh-my-zsh -name ".git" -type d -exec rm -rf {} + 2>/dev/null || true

echo ""
echo "=========================================="
echo "终端工具配置完成！"
echo "=========================================="
echo "已配置的功能："
echo "  ✓ Zsh 设为默认 shell"
echo "  ✓ Oh-My-Zsh 框架"
echo "  ✓ Agnoster 主题（简洁美观）"
echo "  ✓ zsh-autosuggestions 命令自动建议"
echo "  ✓ zsh-syntax-highlighting 语法高亮"
echo "  ✓ zsh-completions 增强补全"
echo "  ✓ UTF-8 编码支持"
echo "  ✓ 保留 OpenWrt Banner 显示"
echo "=========================================="
