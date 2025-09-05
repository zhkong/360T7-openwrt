git clone https://github.com/openwrt/openwrt.git --depth 1 --single-branch -b v24.10.0
cd openwrt

# 更新 Feeds
./scripts/feeds update -a
./scripts/feeds install -a

## argon theme
git clone https://github.com/jerrykuku/luci-theme-argon.git --single-branch --depth 1 package/new/luci-theme-argon

mkdir temp
git clone https://github.com/immortalwrt/luci.git -b openwrt-24.10 --single-branch --depth 1 temp/luci
git clone https://github.com/immortalwrt/packages.git -b openwrt-24.10 --single-branch --depth 1 temp/packages
git clone https://github.com/immortalwrt/immortalwrt.git -b openwrt-24.10 --single-branch --depth 1 temp/immortalwrt

## KMS激活
mv temp/luci/applications/luci-app-vlmcsd package/new/luci-app-vlmcsd
mv temp/packages/net/vlmcsd package/new/vlmcsd
# edit package/new/luci-app-vlmcsd/Makefile
sed -i 's/..\/..\/luci.mk/$(TOPDIR)\/feeds\/luci\/luci.mk/g' package/new/luci-app-vlmcsd/Makefile
sed -i 's/Vlmcsd KMS 服务器/KMS服务器/g' package/new/luci-app-vlmcsd/po/zh_Hans/vlmcsd.po

## MOSDNS
# remove v2ray-geodata package from feeds (openwrt-22.03 & master)
rm -rf feeds/packages/net/v2ray-geodata
git clone https://github.com/sbwml/luci-app-mosdns -b v5 package/mosdns
git clone https://github.com/sbwml/v2ray-geodata package/v2ray-geodata

## OpenClash
git clone https://github.com/vernesong/OpenClash.git -b master --single-branch --depth 1 package/openclash

# AutoCore
mv temp/immortalwrt/package/emortal/autocore package/new/autocore
# sed -i 's/"getTempInfo" /"getTempInfo", "getCPUBench", "getCPUUsage" /g' package/new/autocore/files/luci-mod-status-autocore.json

# rm -rf feeds/luci/modules/luci-base
# rm -rf feeds/luci/modules/luci-mod-status
rm -rf feeds/packages/utils/coremark
rm -rf package/emortal/default-settings

# mv temp/luci/modules/luci-base feeds/luci/modules/luci-base
# mv temp/luci/modules/luci-mod-status feeds/luci/modules/luci-mod-status
mv temp/packages/utils/coremark package/new/coremark
mv temp/immortalwrt/package/emortal/default-settings package/new/default-settings


# config file
# cp ../config/360t7.config .config
cp ../config/openclash.config .config
make defconfig

rm -rf temp

# # 编译固件
# make download -j$(nproc)
# make -j$(nproc) || make -j1 V=s