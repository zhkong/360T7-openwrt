#!/bin/bash
# ============================================================
# OpenWrt ImageBuilder 自定义文件创建脚本
# 创建所有需要嵌入固件的自定义文件
# ============================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
DATA_DIR="$PROJECT_DIR/data"

# 自定义文件输出目录（可通过参数指定）
FILES_DIR="${1:-$PROJECT_DIR/imagebuilder/custom-files}"

echo "=========================================="
echo "创建 ImageBuilder 自定义文件"
echo "输出目录: $FILES_DIR"
echo "=========================================="

# 清理并创建目录
rm -rf "$FILES_DIR"
mkdir -p "$FILES_DIR"

# ==================== CPU 状态显示模块 ====================
setup_cpu_status() {
    echo ""
    echo "[1/4] 添加 CPU 状态显示模块..."
    
    # LuCI JavaScript 模块目录
    local luci_js_dir="$FILES_DIR/www/luci-static/resources/view/status/include"
    mkdir -p "$luci_js_dir"
    
    # 创建 CPU 状态显示 JavaScript
    cat > "$luci_js_dir/15_cpuinfo.js" << 'EOF'
'use strict';
'require baseclass';
'require fs';
'require rpc';

var callSystemInfo = rpc.declare({
	object: 'system',
	method: 'info'
});

function progressbar(value, max) {
	var vn = parseInt(value) || 0,
	    mn = parseInt(max) || 100,
	    pc = Math.floor((100 / mn) * vn);

	return E('div', {
		'class': 'cbi-progressbar',
		'title': '%d%% (%d / %d)'.format(pc, vn, mn)
	}, E('div', { 'style': 'width:%.2f%%'.format(pc) }));
}

return baseclass.extend({
	title: _('CPU'),

	prevIdle: 0,
	prevTotal: 0,

	load: function() {
		return Promise.all([
			L.resolveDefault(fs.exec('/bin/cat', ['/sys/class/thermal/thermal_zone0/temp']), null),
			L.resolveDefault(fs.exec('/usr/bin/head', ['-1', '/proc/stat']), null),
			L.resolveDefault(callSystemInfo(), {})
		]);
	},

	render: function(data) {
		var tempResult = data[0],
		    statResult = data[1],
		    systemInfo = data[2];

		var fields = [];

		// 解析 CPU 温度
		var cpuTemp = null;
		if (tempResult && tempResult.code === 0 && tempResult.stdout) {
			var temp = parseInt(tempResult.stdout.trim());
			if (!isNaN(temp) && temp > 0) {
				cpuTemp = (temp / 1000).toFixed(1);
			}
		}

		// 解析 CPU 使用率
		var cpuUsage = null;
		if (statResult && statResult.code === 0 && statResult.stdout) {
			var line = statResult.stdout.trim();
			if (line.indexOf('cpu ') === 0) {
				var parts = line.split(/\s+/);
				var user = parseInt(parts[1]) || 0;
				var nice = parseInt(parts[2]) || 0;
				var system = parseInt(parts[3]) || 0;
				var idle = parseInt(parts[4]) || 0;
				var iowait = parseInt(parts[5]) || 0;
				var irq = parseInt(parts[6]) || 0;
				var softirq = parseInt(parts[7]) || 0;
				var steal = parseInt(parts[8]) || 0;

				var idleTime = idle + iowait;
				var totalTime = user + nice + system + idle + iowait + irq + softirq + steal;

				var diffIdle = idleTime - this.prevIdle;
				var diffTotal = totalTime - this.prevTotal;

				if (diffTotal > 0 && this.prevTotal > 0) {
					cpuUsage = Math.round((1 - diffIdle / diffTotal) * 100);
				} else if (this.prevTotal === 0) {
					cpuUsage = 0;
				}

				this.prevIdle = idleTime;
				this.prevTotal = totalTime;
			}
		}

		// 备用：使用负载平均值
		if (cpuUsage === null && systemInfo && systemInfo.load) {
			var load1 = systemInfo.load[0] / 65535.0;
			cpuUsage = Math.min(Math.round(load1 * 100), 100);
		}

		// CPU 使用率
		if (cpuUsage !== null) {
			fields.push(_('CPU usage (%)'));
			fields.push(progressbar(cpuUsage, 100));
		}

		// CPU 温度
		if (cpuTemp !== null) {
			fields.push(_('Temperature'));
			fields.push(cpuTemp + ' °C');
		}

		if (fields.length === 0) {
			return null;
		}

		var table = E('table', { 'class': 'table' });

		for (var i = 0; i < fields.length; i += 2) {
			table.appendChild(E('tr', { 'class': 'tr' }, [
				E('td', { 'class': 'td left', 'width': '33%' }, [ fields[i] ]),
				E('td', { 'class': 'td left' }, [
					(fields[i + 1] != null) ? fields[i + 1] : '?'
				])
			]));
		}

		return table;
	}
});
EOF

    # ACL 配置目录
    local acl_dir="$FILES_DIR/usr/share/rpcd/acl.d"
    mkdir -p "$acl_dir"
    
    cat > "$acl_dir/luci-mod-status-cpuinfo.json" << 'EOF'
{
	"luci-mod-status-cpuinfo": {
		"description": "Grant access to CPU status display",
		"read": {
			"file": {
				"/bin/cat /sys/class/thermal/thermal_zone*/temp": [ "exec" ],
				"/bin/cat /proc/stat": [ "exec" ],
				"/usr/bin/head -1 /proc/stat": [ "exec" ]
			},
			"ubus": {
				"file": [ "list", "read", "exec" ]
			}
		}
	}
}
EOF

    echo "  ✓ CPU 状态显示 JavaScript 模块"
    echo "  ✓ ACL 权限配置"
}

# ==================== LuCI 轮询间隔设置 ====================
setup_poll_interval() {
    echo ""
    echo "[2/4] 设置 LuCI 轮询间隔..."
    
    local poll_interval="${POLL_INTERVAL:-1}"
    local uci_dir="$FILES_DIR/etc/uci-defaults"
    mkdir -p "$uci_dir"
    
    cat > "$uci_dir/99-luci-poll-interval" << EOF
#!/bin/sh
# 设置 LuCI 状态页面轮询间隔为 ${poll_interval} 秒
uci set luci.main.pollinterval=${poll_interval}
uci commit luci
exit 0
EOF
    chmod +x "$uci_dir/99-luci-poll-interval"
    
    echo "  ✓ 轮询间隔设置 (${poll_interval}秒)"
}

# ==================== 终端工具配置 ====================
setup_terminal_tools() {
    echo ""
    echo "[3/4] 配置终端工具 (Zsh + Oh-My-Zsh)..."
    
    mkdir -p "$FILES_DIR/root"
    mkdir -p "$FILES_DIR/etc/profile.d"
    mkdir -p "$FILES_DIR/usr/libexec/uci-defaults"
    
    # 安装 Oh-My-Zsh
    echo "  克隆 oh-my-zsh 仓库..."
    if [ ! -d "$FILES_DIR/root/.oh-my-zsh" ]; then
        git clone --depth=1 https://github.com/ohmyzsh/ohmyzsh.git "$FILES_DIR/root/.oh-my-zsh"
    else
        echo "  oh-my-zsh 已存在，跳过"
    fi
    
    # 安装 Zsh 插件
    echo "  安装 zsh 插件..."
    local plugins_dir="$FILES_DIR/root/.oh-my-zsh/custom/plugins"
    
    # zsh-autosuggestions
    if [ ! -d "$plugins_dir/zsh-autosuggestions" ]; then
        git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions "$plugins_dir/zsh-autosuggestions"
        echo "    ✓ zsh-autosuggestions"
    fi
    
    # zsh-syntax-highlighting
    if [ ! -d "$plugins_dir/zsh-syntax-highlighting" ]; then
        git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting.git "$plugins_dir/zsh-syntax-highlighting"
        echo "    ✓ zsh-syntax-highlighting"
    fi
    
    # zsh-completions
    if [ ! -d "$plugins_dir/zsh-completions" ]; then
        git clone --depth=1 https://github.com/zsh-users/zsh-completions "$plugins_dir/zsh-completions"
        echo "    ✓ zsh-completions"
    fi
    
    # 复制 .zshrc 配置文件
    echo "  配置 .zshrc..."
    if [ -f "$DATA_DIR/zsh/.zshrc" ]; then
        cp "$DATA_DIR/zsh/.zshrc" "$FILES_DIR/root/.zshrc"
        echo "    ✓ 使用 data/zsh/.zshrc"
    else
        create_default_zshrc
        echo "    ✓ 使用默认配置"
    fi
    
    # 设置 zsh 为默认 shell 的脚本
    cat > "$FILES_DIR/usr/libexec/uci-defaults/99-set-default-shell-zsh" << 'UCIEOF'
#!/bin/sh
# 设置 root 用户默认 shell 为 zsh
if [ -x /usr/bin/zsh ]; then
    if grep -q "root:.*:/bin/ash" /etc/passwd; then
        sed -i 's|root:\([^:]*\):\([^:]*\):\([^:]*\):\([^:]*\):\([^:]*\):/bin/ash|root:\1:\2:\3:\4:\5:/usr/bin/zsh|' /etc/passwd
        echo "Default shell changed to zsh"
    fi
fi
UCIEOF
    chmod +x "$FILES_DIR/usr/libexec/uci-defaults/99-set-default-shell-zsh"
    
    # 创建 .profile
    cat > "$FILES_DIR/root/.profile" << 'PROFILE'
# ~/.profile: executed by the command interpreter for login shells
export LANG=zh_CN.UTF-8
export LC_ALL=zh_CN.UTF-8
export LANGUAGE=zh_CN:zh:en_US:en
export TERM=xterm-256color
if [ -z "$ZSH_VERSION" ]; then
    [ -f /etc/banner ] && cat /etc/banner
fi
PROFILE

    # 终端 UTF-8 配置
    cat > "$FILES_DIR/etc/profile.d/99-utf8-terminal.sh" << 'EOF'
#!/bin/sh
export LANG=zh_CN.UTF-8
export LC_ALL=zh_CN.UTF-8
export LANGUAGE=zh_CN:zh:en_US:en
if [ "$TERM" = "xterm" ] || [ "$TERM" = "screen" ]; then
    export TERM="${TERM}-256color"
fi
EOF
    chmod +x "$FILES_DIR/etc/profile.d/99-utf8-terminal.sh"
    
    # 清理 Git 目录
    echo "  清理 Git 目录以减小体积..."
    find "$FILES_DIR/root/.oh-my-zsh" -name ".git" -type d -exec rm -rf {} + 2>/dev/null || true
    
    echo "  ✓ 终端工具配置完成"
}

# 创建默认 .zshrc
create_default_zshrc() {
    cat > "$FILES_DIR/root/.zshrc" << 'ZSHRC'
# OpenWrt Zsh 配置
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

# 别名
alias ll='ls -alFh --color=auto'
alias la='ls -A --color=auto'
alias logs='logread -f'
alias syslog='logread'
ZSHRC
}

# ==================== 显示摘要 ====================
show_summary() {
    echo ""
    echo "[4/4] 清理和统计..."
    
    local total_size=$(du -sh "$FILES_DIR" 2>/dev/null | cut -f1)
    local file_count=$(find "$FILES_DIR" -type f | wc -l)
    
    echo ""
    echo "=========================================="
    echo "自定义文件创建完成！"
    echo "=========================================="
    echo "输出目录: $FILES_DIR"
    echo "文件数量: $file_count"
    echo "总大小:   $total_size"
    echo ""
    echo "包含功能:"
    echo "  ✓ CPU 状态显示 (温度 + 使用率)"
    echo "  ✓ LuCI 轮询间隔 (${POLL_INTERVAL:-1}秒)"
    echo "  ✓ Zsh 默认 Shell"
    echo "  ✓ Oh-My-Zsh + Agnoster 主题"
    echo "  ✓ Zsh 插件 (autosuggestions, syntax-highlighting, completions)"
    echo "  ✓ UTF-8 终端支持"
    echo "=========================================="
}

# ==================== 主程序 ====================
main() {
    setup_cpu_status
    setup_poll_interval
    setup_terminal_tools
    show_summary
}

main "$@"
