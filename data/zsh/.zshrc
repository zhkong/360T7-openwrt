# ============================================================
# OpenWrt ZSH 配置文件
# 美化的 zsh 界面，支持 UTF-8，保留 OpenWrt banner
# ============================================================

# ==================== UTF-8 支持 ====================
export LANG=zh_CN.UTF-8
export LC_ALL=zh_CN.UTF-8
export LANGUAGE=zh_CN:zh:en_US:en
export TERM=xterm-256color

# ==================== 显示 OpenWrt Banner ====================
# 只在交互式登录 shell 时显示 banner
if [[ -o login ]] && [[ -o interactive ]]; then
    if [[ -f /etc/banner ]]; then
        cat /etc/banner
    fi
fi

# ==================== Oh-My-Zsh 配置 ====================
export ZSH="$HOME/.oh-my-zsh"

# 主题设置 - 使用简洁美观的 agnoster 主题
# 如果终端不支持 powerline 字体，可以切换为 robbyrussell
ZSH_THEME="agnoster"

# 不显示用户名和主机名（在路由器上通常都是 root@OpenWrt）
DEFAULT_USER="root"

# 禁用自动更新检查（路由器环境不需要）
DISABLE_AUTO_UPDATE="true"

# 启用命令自动更正
ENABLE_CORRECTION="false"

# 命令执行时间戳格式
HIST_STAMPS="yyyy-mm-dd"

# ==================== 插件配置 ====================
# 启用的插件列表：
#   - git: Git 快捷命令
#   - zsh-autosuggestions: 命令自动建议（灰色提示历史命令）
#   - zsh-syntax-highlighting: 语法高亮（命令正确显示绿色，错误显示红色）
#   - zsh-completions: 更多的命令补全
plugins=(
    git
    zsh-autosuggestions
    zsh-syntax-highlighting
    zsh-completions
)

# 加载 Oh-My-Zsh
source $ZSH/oh-my-zsh.sh

# ==================== 自动建议插件配置 ====================
# 设置建议文字颜色（灰色）
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=8'
# 使用历史记录作为建议来源
ZSH_AUTOSUGGEST_STRATEGY=(history completion)

# ==================== 语法高亮配置 ====================
# 高亮显示配置
typeset -A ZSH_HIGHLIGHT_STYLES
ZSH_HIGHLIGHT_STYLES[command]='fg=green,bold'
ZSH_HIGHLIGHT_STYLES[builtin]='fg=green,bold'
ZSH_HIGHLIGHT_STYLES[alias]='fg=cyan,bold'
ZSH_HIGHLIGHT_STYLES[function]='fg=cyan,bold'
ZSH_HIGHLIGHT_STYLES[path]='fg=yellow'
ZSH_HIGHLIGHT_STYLES[single-quoted-argument]='fg=magenta'
ZSH_HIGHLIGHT_STYLES[double-quoted-argument]='fg=magenta'
ZSH_HIGHLIGHT_STYLES[dollar-quoted-argument]='fg=magenta'

# ==================== 历史记录配置 ====================
HISTFILE=~/.zsh_history
HISTSIZE=1000
SAVEHIST=1000
# 共享历史记录
setopt SHARE_HISTORY
# 忽略重复命令
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_ALL_DUPS
# 忽略以空格开头的命令
setopt HIST_IGNORE_SPACE
# 历史记录中删除多余空格
setopt HIST_REDUCE_BLANKS

# ==================== 补全配置 ====================
# 启用补全缓存
zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path ~/.zsh/cache

# 补全菜单选择
zstyle ':completion:*' menu select
# 补全时显示描述
zstyle ':completion:*' verbose yes
# 补全分组显示
zstyle ':completion:*' group-name ''
# 补全列表颜色
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}

# 大小写不敏感补全
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'

# ==================== 快捷键配置 ====================
# 使用 Emacs 风格快捷键
bindkey -e

# 使用上下方向键搜索历史（基于当前输入）
bindkey '^[[A' history-beginning-search-backward
bindkey '^[[B' history-beginning-search-forward
bindkey '^P' history-beginning-search-backward
bindkey '^N' history-beginning-search-forward

# Home/End 键
bindkey '^[[H' beginning-of-line
bindkey '^[[F' end-of-line
bindkey '^[[1~' beginning-of-line
bindkey '^[[4~' end-of-line

# Delete 键
bindkey '^[[3~' delete-char

# Ctrl+左/右 跳过单词
bindkey '^[[1;5C' forward-word
bindkey '^[[1;5D' backward-word

# ==================== 别名配置 ====================
# 列表显示
alias ll='ls -alFh --color=auto'
alias la='ls -A --color=auto'
alias l='ls -CF --color=auto'
alias ls='ls --color=auto'

# 安全操作
alias rm='rm -i'
alias cp='cp -i'
alias mv='mv -i'

# 网络相关
alias ports='netstat -tuln'
alias connections='netstat -an'

# OpenWrt 特定
alias logs='logread -f'
alias syslog='logread'
alias dmesg='dmesg -w'

# 系统信息
alias mem='free -m'
alias disk='df -h'

# 服务管理
alias services='ls /etc/init.d/'

# ==================== 环境变量 ====================
export PATH="$HOME/bin:/usr/local/bin:$PATH"
export EDITOR='vi'

# ==================== 简化的提示符（备选方案） ====================
# 如果 agnoster 主题不适用，取消注释下面的配置使用简洁提示符
# PROMPT='%F{cyan}%n%f@%F{green}%m%f:%F{yellow}%~%f %# '

# ==================== 欢迎信息 ====================
# 如果 banner 之后还想显示额外信息，可以取消注释
# echo "Welcome to OpenWrt! Type 'btop' for system monitor."
