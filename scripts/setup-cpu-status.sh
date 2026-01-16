#!/bin/bash

# 脚本：添加 CPU 温度和使用率显示到 OpenWrt LuCI 首页
# 此脚本会在 luci-mod-status 模块中添加一个新的状态组件

echo "正在添加 CPU 温度和使用率显示..."

LUCI_STATUS_DIR="openwrt/feeds/luci/modules/luci-mod-status/htdocs/luci-static/resources/view/status/include"
LUCI_ACL_DIR="openwrt/feeds/luci/modules/luci-mod-status/root/usr/share/rpcd/acl.d"

# 检查目录是否存在
if [ ! -d "$LUCI_STATUS_DIR" ]; then
    echo "错误：LuCI 状态目录不存在，请先运行 prepare.sh"
    exit 1
fi

# 创建 ACL 配置文件，授权执行命令读取 CPU 信息
cat > "$LUCI_ACL_DIR/luci-mod-status-cpuinfo.json" << 'EOF'
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

echo "✓ ACL 配置已创建：$LUCI_ACL_DIR/luci-mod-status-cpuinfo.json"

# 创建 CPU 信息显示模块 - 匹配原版 OpenWrt LuCI 风格
cat > "$LUCI_STATUS_DIR/15_cpuinfo.js" << 'EOF'
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

echo "✓ CPU 状态模块已创建：$LUCI_STATUS_DIR/15_cpuinfo.js"

# 创建 uci-defaults 脚本，设置轮询间隔为 1 秒
UCI_DEFAULTS_DIR="openwrt/files/etc/uci-defaults"
mkdir -p "$UCI_DEFAULTS_DIR"

cat > "$UCI_DEFAULTS_DIR/99-luci-poll-interval" << 'EOF'
#!/bin/sh
# 设置 LuCI 状态页面轮询间隔为 1 秒
uci set luci.main.pollinterval=1
uci commit luci
exit 0
EOF

chmod +x "$UCI_DEFAULTS_DIR/99-luci-poll-interval"
echo "✓ 轮询间隔设置已创建：$UCI_DEFAULTS_DIR/99-luci-poll-interval (1秒)"

echo "完成！CPU 温度和使用率将显示在 LuCI 首页，刷新间隔为 1 秒。"
