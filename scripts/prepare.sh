git clone https://github.com/padavanonly/immortalwrt-mt798x-6.6 --depth 1 --single-branch -b openwrt-24.10-6.6 openwrt
cd openwrt

# 更新 Feeds
./scripts/feeds update -a
./scripts/feeds install -a


# config file
# cp ../config/360t7.config .config
cp ../config/immortalwrt.config .config
make defconfig

rm -rf temp

# # 编译固件
# make download -j$(nproc)
# make -j$(nproc) || make -j1 V=s