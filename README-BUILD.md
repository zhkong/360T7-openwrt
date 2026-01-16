# 360T7 OpenWrt 固件自动编译

[![360T7 OpenWRT Build](https://github.com/zhkong/360T7-openwrt/actions/workflows/build-firmware.yml/badge.svg)](https://github.com/zhkong/360T7-openwrt/actions/workflows/build-firmware.yml)

本项目为 **奇虎360 T7 路由器** 提供自动化的 OpenWrt 固件编译方案。基于官方 OpenWrt 源码，**禁用 WiFi 功能**，适合作为有线路由器或旁路由使用。

## ✨ 特性

- 🔄 **自动跟踪最新版本** - 每6小时检查 OpenWrt 官方 Release，自动编译最新固件
- 🔧 **无 WiFi 配置** - 移除所有无线相关驱动和模块，减小固件体积，降低功耗
- 🌐 **中文本地化** - 默认中文界面，包含完整中文语言包
- 🚀 **硬件流量卸载** - 默认启用 Hardware Flow Offloading，提升转发性能
- 📊 **CPU 状态显示** - LuCI 首页实时显示 CPU 温度和使用率（1秒刷新）
- 🔐 **HTTPS 支持** - 内置 LuCI SSL 支持

## 📋 设备信息

| 项目 | 信息 |
|------|------|
| 设备型号 | 奇虎 360 T7 (qihoo_360t7) |
| 平台架构 | MediaTek MT7981B (Filogic 820) |
| CPU 架构 | ARM Cortex-A53 (aarch64) |
| 内存 | 256MB DDR3 |
| 闪存 | 128MB NAND |

## 🔧 预装软件

### 系统工具
- `btop` - 现代化资源监控工具
- `iperf3` - 网络性能测试
- `zsh` - 增强型 Shell

### LuCI 应用
- `luci-app-firewall` - 防火墙管理
- `luci-app-package-manager` - 软件包管理

## 📦 固件下载

前往 [Releases](https://github.com/zhkong/360T7-openwrt/releases) 页面下载最新固件。

固件命名格式：`OpenWrt-<版本号>-<commit>`

## 🚀 使用方法

### 自动编译

本项目配置了 GitHub Actions 自动编译：

- **定时编译**：每 6 小时检查 OpenWrt 是否有新 Release
- **手动触发**：可在 Actions 页面手动运行，支持指定 OpenWrt 版本

### 手动编译

1. 克隆本仓库：
```bash
git clone https://github.com/zhkong/360T7-openwrt.git
cd 360T7-openwrt
```

2. 执行准备脚本：
```bash
bash scripts/prepare.sh
```

3. 进入 OpenWrt 目录并编译：
```bash
cd openwrt
make download -j$(nproc)
make -j$(nproc)
```

编译产物位于 `openwrt/bin/targets/mediatek/filogic/`

## 📁 项目结构

```
360T7-openwrt/
├── .github/
│   └── workflows/
│       └── build-firmware.yml    # GitHub Actions 工作流
├── config/
│   └── 360t7.config              # OpenWrt 编译配置（无WiFi）
├── scripts/
│   ├── prepare.sh                # 环境准备脚本
│   ├── setup-cpu-status.sh       # CPU 状态显示配置
│   ├── setup-poll-interval.sh    # LuCI 轮询间隔配置
│   ├── setup-chinese-locale.sh   # 中文本地化配置
│   ├── setup-flow-offloading.sh  # 硬件流量卸载配置
│   └── preset-terminal-tools.sh  # 终端工具预配置（oh-my-zsh）
└── data/
    └── zsh/                      # ZSH 配置文件
```

## ⚙️ 配置说明

### 默认配置 (360t7.config)

- ✅ LuCI Web 界面
- ✅ HTTPS/SSL 支持
- ✅ IPv6 协议支持
- ✅ PPPoE 拨号支持
- ✅ IPT 流量卸载内核模块
- ❌ WiFi 驱动 (mt7915e)
- ❌ 无线配置工具

## 🛠️ 自定义编译

1. 修改 `config/360t7.config` 配置文件
2. 推送到 GitHub 触发自动编译，或本地手动编译

### 启用 WiFi

如需启用 WiFi，在 `config/360t7.config` 中添加或修改以下配置：

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

## 📝 更新日志

查看 [Releases](https://github.com/zhkong/360T7-openwrt/releases) 获取版本更新信息。

## 🙏 致谢

- [OpenWrt](https://github.com/openwrt/openwrt) - 官方 OpenWrt 项目
- [LuCI](https://github.com/openwrt/luci) - OpenWrt Web 界面

## 📄 许可证

本项目遵循 [GPL-2.0](LICENSE) 许可证。

---

**⚠️ 免责声明**：刷机有风险，请确保了解相关知识后再进行操作。因刷机导致的设备损坏，本项目不承担任何责任。
