#!/bin/bash
# 设置 OpenWrt 系统为中文环境

set -e

OPENWRT_DIR="${1:-openwrt}"

if [ ! -d "$OPENWRT_DIR" ]; then
    echo "错误: OpenWrt 目录不存在: $OPENWRT_DIR"
    exit 1
fi

cd "$OPENWRT_DIR"

echo "正在配置中文环境..."

# 1. 在配置文件中启用中文语言包支持
if [ -f .config ]; then
    echo "添加中文语言包配置到 .config..."
    
    # 启用 Luci 中文语言
    sed -i '/CONFIG_LUCI_LANG_zh_Hans/d' .config
    echo "CONFIG_LUCI_LANG_zh_Hans=y" >> .config
    
    # 启用 Luci 基础中文语言包
    sed -i '/CONFIG_PACKAGE_luci-i18n-base-zh-cn/d' .config
    echo "CONFIG_PACKAGE_luci-i18n-base-zh-cn=y" >> .config
    
    # 启用防火墙中文语言包
    sed -i '/CONFIG_PACKAGE_luci-i18n-firewall-zh-cn/d' .config
    echo "CONFIG_PACKAGE_luci-i18n-firewall-zh-cn=y" >> .config
    
    # 启用包管理器中中文语言包
    sed -i '/CONFIG_PACKAGE_luci-i18n-package-manager-zh-cn/d' .config
    echo "CONFIG_PACKAGE_luci-i18n-package-manager-zh-cn=y" >> .config
    
    # 启用系统模块中文语言包
    sed -i '/CONFIG_PACKAGE_luci-i18n-system-zh-cn/d' .config
    echo "CONFIG_PACKAGE_luci-i18n-system-zh-cn=y" >> .config
    
    # 启用网络模块中文语言包
    sed -i '/CONFIG_PACKAGE_luci-i18n-network-zh-cn/d' .config
    echo "CONFIG_PACKAGE_luci-i18n-network-zh-cn=y" >> .config
    
    # 启用状态模块中文语言包
    sed -i '/CONFIG_PACKAGE_luci-i18n-status-zh-cn/d' .config
    echo "CONFIG_PACKAGE_luci-i18n-status-zh-cn=y" >> .config
    
    echo "已添加中文语言包配置"
else
    echo "警告: .config 文件不存在"
fi

# 2. 创建文件系统目录结构
echo "创建中文语言配置文件..."
mkdir -p files/etc/config
mkdir -p files/etc/profile.d

# 3. 创建语言环境配置文件
cat > files/etc/config/luci <<'EOF'
config core 'main'
	option lang 'zh_cn'
	option resourcebase '/luci-static/resources'
	option mediaurlbase '/luci-static/bootstrap'
EOF

# 4. 创建系统语言环境配置文件
cat > files/etc/profile.d/99-locale-zh_CN.sh <<'EOF'
#!/bin/sh
export LANG=zh_CN.UTF-8
export LC_ALL=zh_CN.UTF-8
export LANGUAGE=zh_CN:zh:en_US:en
EOF

chmod +x files/etc/profile.d/99-locale-zh_CN.sh

# 5. 创建默认语言环境配置文件
cat > files/etc/locale.conf <<'EOF'
LANG=zh_CN.UTF-8
LC_ALL=zh_CN.UTF-8
LANGUAGE=zh_CN:zh:en_US:en
EOF

# 6. 创建 rc.local 脚本来在启动时设置语言（如果不存在）
if [ ! -f files/etc/rc.local ]; then
    cat > files/etc/rc.local <<'EOF'
#!/bin/sh /etc/rc.common
START=99

start() {
    # 设置系统语言为中文
    export LANG=zh_CN.UTF-8
    export LC_ALL=zh_CN.UTF-8
    export LANGUAGE=zh_CN:zh:en_US:en
    
    # 设置 Luci 语言为中文
    uci set luci.main.lang='zh_cn'
    uci commit luci
}
EOF
    chmod +x files/etc/rc.local
else
    # 如果 rc.local 已存在，添加语言设置
    if ! grep -q "设置系统语言为中文" files/etc/rc.local; then
        cat >> files/etc/rc.local <<'EOF'
    # 设置系统语言为中文
    export LANG=zh_CN.UTF-8
    export LC_ALL=zh_CN.UTF-8
    export LANGUAGE=zh_CN:zh:en_US:en
    
    # 设置 Luci 语言为中文
    uci set luci.main.lang='zh_cn' 2>/dev/null || true
    uci commit luci 2>/dev/null || true
EOF
    fi
fi

# 7. 创建 UCI 默认配置脚本来设置 Luci 语言
mkdir -p files/usr/libexec/uci-defaults
cat > files/usr/libexec/uci-defaults/99-set-chinese-locale <<'UCIEOF'
#!/bin/sh
# 设置 Luci 默认语言为中文
uci set luci.main.lang='zh_cn' 2>/dev/null || true
uci commit luci 2>/dev/null || true
UCIEOF

chmod +x files/usr/libexec/uci-defaults/99-set-chinese-locale

echo "中文环境配置完成！"
echo "- 已添加中文语言包支持"
echo "- 已创建语言环境配置文件"
echo "- 已创建 Luci 中文配置"
echo "- 系统将在首次启动时设置为中文"
