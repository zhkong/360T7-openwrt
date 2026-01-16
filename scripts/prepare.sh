#!/bin/bash

# 获取 OpenWrt 版本标签（从 workflow 传递或使用默认值）
if [ -f /tmp/openwrt_tag.txt ]; then
    OPENWRT_TAG=$(cat /tmp/openwrt_tag.txt)
else
    # 如果文件不存在，获取最新的 release 标签
    OPENWRT_TAG=$(curl -s https://api.github.com/repos/openwrt/openwrt/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/' | head -n 1)
    if [ -z "$OPENWRT_TAG" ]; then
        # 如果没有 release，尝试获取最新的标签
        OPENWRT_TAG=$(curl -s https://api.github.com/repos/openwrt/openwrt/git/refs/tags | grep -o '"refs/tags/[^"]*"' | tail -n 1 | sed 's/"refs\/tags\///;s/"//')
    fi
    # 如果还是获取不到，使用 master 分支
    if [ -z "$OPENWRT_TAG" ]; then
        OPENWRT_TAG="master"
    fi
fi

echo "正在克隆 OpenWrt 仓库，版本/标签: $OPENWRT_TAG"

# 克隆 OpenWrt 官方仓库
if [ "$OPENWRT_TAG" = "master" ] || [ -z "$OPENWRT_TAG" ]; then
    git clone https://github.com/openwrt/openwrt.git --depth 1 openwrt
else
    git clone https://github.com/openwrt/openwrt.git --depth 1 --branch "$OPENWRT_TAG" openwrt || \
    git clone https://github.com/openwrt/openwrt.git --depth 1 openwrt && \
    cd openwrt && git checkout "$OPENWRT_TAG" && cd ..
fi

cd openwrt

# 更新 Feeds
./scripts/feeds update -a
./scripts/feeds install -a

# 添加 CPU 状态显示到 LuCI 首页
cd ..
bash scripts/setup-cpu-status.sh
bash scripts/setup-poll-interval.sh

# 配置终端工具（zsh + oh-my-zsh）
bash scripts/preset-terminal-tools.sh openwrt
cd openwrt

# config file
# 使用 360t7.config 作为配置文件
cp ../config/360t7.config .config
make defconfig

rm -rf temp

# # 编译固件
# make download -j$(nproc)
# make -j$(nproc) || make -j1 V=s