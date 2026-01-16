#!/bin/bash
# 设置 OpenWrt 默认启用 Hardware Flow Offloading（仅修改 flow offloading 设置）

set -e

OPENWRT_DIR="${1:-openwrt}"

if [ ! -d "$OPENWRT_DIR" ]; then
    echo "错误: OpenWrt 目录不存在: $OPENWRT_DIR"
    exit 1
fi

cd "$OPENWRT_DIR"

echo "正在配置 Hardware Flow Offloading..."

# 创建文件系统目录结构
mkdir -p files/usr/libexec/uci-defaults

# 创建 UCI 默认配置脚本来只启用 Hardware Flow Offloading
# 这个脚本会在首次启动时运行，只修改 flow offloading 相关设置
cat > files/usr/libexec/uci-defaults/99-enable-flow-offloading <<'UCIEOF'
#!/bin/sh
# 只启用 Hardware Flow Offloading，不修改其他 firewall 配置

# 检查 firewall 配置是否存在
if [ ! -f /etc/config/firewall ]; then
    exit 0
fi

# 检查 defaults 配置段是否存在
if ! uci get firewall.@defaults[0] >/dev/null 2>&1; then
    # 如果 defaults 段不存在，创建一个
    uci add firewall defaults
fi

# 只设置 flow offloading 相关选项，保留其他现有配置
uci set firewall.@defaults[0].flow_offloading='1' 2>/dev/null || true
uci set firewall.@defaults[0].flow_offloading_hw='1' 2>/dev/null || true
uci commit firewall 2>/dev/null || true

# 如果 firewall 服务已启动，重新加载配置以应用更改
if [ -f /etc/init.d/firewall ] && /etc/init.d/firewall enabled; then
    /etc/init.d/firewall reload 2>/dev/null || true
fi
UCIEOF

chmod +x files/usr/libexec/uci-defaults/99-enable-flow-offloading

echo "Hardware Flow Offloading 配置完成！"
echo "- 已创建 UCI defaults 脚本"
echo "- 只启用 flow_offloading_hw (Hardware Flow Offloading)"
echo "- 不修改防火墙的其他配置"
echo "- 系统将在首次启动时自动应用此配置"
