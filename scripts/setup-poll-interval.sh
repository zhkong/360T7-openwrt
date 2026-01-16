#!/bin/bash

# 脚本：设置 LuCI 状态页面轮询间隔
# 默认设置为 1 秒刷新一次

POLL_INTERVAL="${1:-1}"  # 可通过参数指定，默认 1 秒

echo "正在设置 LuCI 轮询间隔为 ${POLL_INTERVAL} 秒..."

UCI_DEFAULTS_DIR="openwrt/files/etc/uci-defaults"
mkdir -p "$UCI_DEFAULTS_DIR"

cat > "$UCI_DEFAULTS_DIR/99-luci-poll-interval" << EOF
#!/bin/sh
# 设置 LuCI 状态页面轮询间隔为 ${POLL_INTERVAL} 秒
uci set luci.main.pollinterval=${POLL_INTERVAL}
uci commit luci
exit 0
EOF

chmod +x "$UCI_DEFAULTS_DIR/99-luci-poll-interval"
echo "✓ 轮询间隔设置已创建：$UCI_DEFAULTS_DIR/99-luci-poll-interval"
echo "完成！固件首次启动时将自动应用此设置。"
