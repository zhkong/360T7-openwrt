# 360T7 OpenWrt 固件项目

[![360T7 OpenWRT ImageBuilder Build](https://github.com/zhkong/360T7-openwrt/actions/workflows/build-imagebuilder.yml/badge.svg)](https://github.com/zhkong/360T7-openwrt/actions/workflows/build-imagebuilder.yml)
<!-- [![360T7 OpenWRT Build](https://github.com/zhkong/360T7-openwrt/actions/workflows/build-firmware.yml/badge.svg)](https://github.com/zhkong/360T7-openwrt/actions/workflows/build-firmware.yml) -->

本项目为 **奇虎360 T7 路由器** 提供自动化的 OpenWrt 固件编译方案。支持两种构建方式：**ImageBuilder 快速构建**和**完整源码编译**。

## 📋 设备信息

| 项目 | 信息 |
|------|------|
| 设备型号 | 奇虎 360 T7 (qihoo_360t7) |
| 平台架构 | MediaTek MT7981B (Filogic 820) |
| CPU 架构 | ARM Cortex-A53 (aarch64) |
| 内存 | 256MB DDR3 |
| 闪存 | 128MB NAND |

## ✨ 主要特性

### 🚀 性能优化
- **硬件流量卸载** - 默认启用 Hardware Flow Offloading，提升转发性能
- **无 WiFi 配置** - 移除所有无线相关驱动和模块，减小固件体积，降低功耗
- **优化编译** - 支持 ImageBuilder 快速构建和完整源码编译两种方式

### 🌐 用户体验
- **中文本地化** - 默认中文界面，包含完整中文语言包
- **CPU 状态显示** - LuCI 首页实时显示 CPU 温度和使用率（1秒刷新）
- **HTTPS 支持** - 内置 LuCI SSL 支持

### 🛠️ 开发工具
- **Zsh + Oh-My-Zsh** - 增强型 Shell 环境，提升开发体验
- **系统监控工具** - 内置 btop、iperf3 等实用工具

## 📦 固件下载

前往 [Releases](https://github.com/zhkong/360T7-openwrt/releases) 页面下载最新固件。

### 固件类型说明

- **ImageBuilder 构建** - 使用预编译的 ImageBuilder 快速构建，文件名包含 `ImageBuilder`
- **完整编译** - 从源码完整编译，文件名包含版本号和 commit

## 🚀 快速开始

### 方式一：ImageBuilder 快速构建（推荐）

使用预编译的 ImageBuilder，构建速度快，适合快速定制固件。

```bash
# 克隆仓库
git clone https://github.com/zhkong/360T7-openwrt.git
cd 360T7-openwrt

# 运行构建脚本
bash scripts/build-image.sh
```

构建产物位于 `output/` 目录。

### 方式二：完整源码编译

从 OpenWrt 源码完整编译，可深度定制。

```bash
# 克隆仓库
git clone https://github.com/zhkong/360T7-openwrt.git
cd 360T7-openwrt

# 准备编译环境
bash scripts/prepare.sh

# 编译固件
cd openwrt
make download -j$(nproc)
make -j$(nproc)
```

编译产物位于 `openwrt/bin/targets/mediatek/filogic/`。

## 🔧 预装软件

### 系统工具
- `btop` - 现代化资源监控工具
- `iperf3` - 网络性能测试
- `zsh` - 增强型 Shell（带 Oh-My-Zsh）

### LuCI 应用
- `luci-app-firewall` - 防火墙管理
- `luci-app-package-manager` - 软件包管理

## 📁 项目结构

```
360T7-openwrt/
├── .github/
│   └── workflows/
│       ├── build-imagebuilder.yml  # ImageBuilder 构建工作流
│       └── build-firmware.yml      # 完整编译工作流
├── config/
│   ├── 360t7.config               # OpenWrt 编译配置（无WiFi）
│   └── packages.conf               # ImageBuilder 软件包配置
├── scripts/
│   ├── build-image.sh              # ImageBuilder 构建脚本
│   ├── prepare.sh                  # 环境准备脚本
│   ├── setup-imagebuilder-files.sh # ImageBuilder 自定义文件创建
│   ├── setup-cpu-status.sh         # CPU 状态显示配置
│   ├── setup-poll-interval.sh      # LuCI 轮询间隔配置
│   ├── setup-chinese-locale.sh     # 中文本地化配置
│   ├── setup-flow-offloading.sh    # 硬件流量卸载配置
│   └── preset-terminal-tools.sh    # 终端工具预配置
└── data/
    └── zsh/                        # ZSH 配置文件
```

## ⚙️ 配置说明

### 默认配置

- ✅ LuCI Web 界面（中文）
- ✅ HTTPS/SSL 支持
- ✅ IPv6 协议支持
- ✅ PPPoE 拨号支持
- ✅ 硬件流量卸载（Hardware Flow Offloading）
- ✅ CPU 状态显示（温度 + 使用率）
- ✅ Zsh + Oh-My-Zsh 终端环境
- ❌ WiFi 驱动（适合有线路由器或旁路由）

### 自定义配置

#### ImageBuilder 方式

编辑 `config/packages.conf` 文件，修改软件包列表：

```bash
# 添加软件包
PACKAGES_EXTRA="
    nano
    curl
    wget
"

# 移除软件包（在包名前加 -）
PACKAGES_DISABLED="
    -wpad-basic-mbedtls
"
```

#### 完整编译方式

编辑 `config/360t7.config` 文件，修改编译配置。

### 启用 WiFi

如需启用 WiFi，在配置文件中添加：

```
CONFIG_DRIVER_11AC_SUPPORT=y
CONFIG_DRIVER_11AX_SUPPORT=y
CONFIG_PACKAGE_kmod-mt7915e=y
CONFIG_PACKAGE_kmod-cfg80211=y
CONFIG_PACKAGE_kmod-mac80211=y
CONFIG_PACKAGE_wifi-scripts=y
CONFIG_PACKAGE_hostapd-common=y
CONFIG_PACKAGE_wpad-basic-mbedtls=y
```

## 🤖 自动化构建

本项目配置了 GitHub Actions 自动构建：

### ImageBuilder 构建
- **定时编译**：每 6 小时检查 OpenWrt 是否有新 Release
- **手动触发**：可在 Actions 页面手动运行，支持指定 OpenWrt 版本
- **构建速度快**：通常 5-10 分钟完成

### 完整编译
- **定时编译**：每 6 小时检查 OpenWrt 是否有新 Release
- **手动触发**：可在 Actions 页面手动运行
- **构建时间长**：通常 1-2 小时完成

## 📝 更新日志

查看 [Releases](https://github.com/zhkong/360T7-openwrt/releases) 获取版本更新信息。

## 🛠️ 故障排除

### 硬件流量卸载未启用

如果硬件流量卸载未自动启用，可以手动设置：

```bash
uci set firewall.@defaults[0].flow_offloading='1'
uci set firewall.@defaults[0].flow_offloading_hw='1'
uci commit firewall
/etc/init.d/firewall reload
```

### CPU 状态不显示

确保已安装相关依赖：

```bash
opkg update
opkg install rpcd-mod-file
```

## 🙏 致谢

- [OpenWrt](https://github.com/openwrt/openwrt) - 官方 OpenWrt 项目
- [LuCI](https://github.com/openwrt/luci) - OpenWrt Web 界面

## 📄 许可证

本项目遵循 [GPL-2.0](LICENSE) 许可证。

---

**⚠️ 免责声明**：刷机有风险，请确保了解相关知识后再进行操作。因刷机导致的设备损坏，本项目不承担任何责任。
