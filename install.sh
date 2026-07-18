#!/usr/bin/env bash
set -Eeuo pipefail

VERSION="1.0.0"
ACTION="${1:-install}"
PORT="${SOCKS_PORT:-1080}"
SOCKS_USER="${SOCKS_USER:-socks5}"
CONFIG="/etc/danted.conf"
CREDENTIALS="/root/socks5-info.txt"
BACKUP_DIR="/root/socks5-backups"

red='\033[31m'
green='\033[32m'
yellow='\033[33m'
reset='\033[0m'

info() { printf "${green}[+]${reset} %s\n" "$*"; }
warn() { printf "${yellow}[!]${reset} %s\n" "$*"; }
die() { printf "${red}[x]${reset} %s\n" "$*" >&2; exit 1; }

require_root() {
  [[ "$(id -u)" -eq 0 ]] || die "请使用 root 用户运行此脚本。"
}

require_debian() {
  [[ -r /etc/os-release ]] || die "未识别到当前操作系统。"
  . /etc/os-release
  case "${ID:-}:${ID_LIKE:-}" in
    debian:*|ubuntu:*|*:debian*) ;;
    *) die "此脚本仅支持 Debian 和 Ubuntu。" ;;
  esac
}

default_interface() {
  ip -4 route get 1.1.1.1 2>/dev/null |
    awk '{for (i=1;i<=NF;i++) if ($i=="dev") {print $(i+1); exit}}'
}

public_ipv4() {
  curl -4fsS --max-time 6 https://api.ipify.org 2>/dev/null ||
    curl -4fsS --max-time 6 https://ifconfig.me/ip 2>/dev/null || true
}

public_ipv6() {
  curl -6fsS --max-time 6 https://api64.ipify.org 2>/dev/null ||
    curl -6fsS --max-time 6 https://ifconfig.me/ip 2>/dev/null || true
}

generate_password() {
  openssl rand -hex 10
}

install_packages() {
  info "正在安装 Dante SOCKS5 服务端……"
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -y
  apt-get install -y --no-install-recommends \
    dante-server openssl curl ca-certificates iproute2
}

create_user() {
  local password="$1"
  if id "$SOCKS_USER" >/dev/null 2>&1; then
    usermod -s /usr/sbin/nologin "$SOCKS_USER"
  else
    useradd --system --no-create-home --shell /usr/sbin/nologin "$SOCKS_USER"
  fi
  printf '%s:%s\n' "$SOCKS_USER" "$password" | chpasswd
}

write_config() {
  local iface="$1"
  install -d -m 0700 "$BACKUP_DIR"
  if [[ -f "$CONFIG" ]]; then
    cp -a "$CONFIG" "$BACKUP_DIR/danted.conf.$(date +%Y%m%d-%H%M%S)"
  fi

  cat > "$CONFIG" <<EOF
# Managed by socks5-onekey v$VERSION
logoutput: syslog
internal: 0.0.0.0 port = $PORT
internal: :: port = $PORT
external: $iface

socksmethod: username
clientmethod: none
user.privileged: proxy
user.notprivileged: nobody

client pass {
    from: 0.0.0.0/0 to: 0.0.0.0/0
    log: connect error
}
client pass {
    from: ::/0 to: ::/0
    log: connect error
}
socks pass {
    from: 0.0.0.0/0 to: 0.0.0.0/0
    command: connect
    socksmethod: username
    log: connect error
}
socks pass {
    from: ::/0 to: ::/0
    command: connect
    socksmethod: username
    log: connect error
}
EOF
  chmod 0640 "$CONFIG"
  chown root:root "$CONFIG"
}

start_service() {
  command -v systemctl >/dev/null 2>&1 || die "当前系统缺少 systemd。"
  systemctl enable danted >/dev/null
  systemctl restart danted
  sleep 1
  if ! systemctl is-active --quiet danted; then
    systemctl --no-pager --full status danted || true
    die "Dante 启动失败，请查看上方错误信息。"
  fi
}

configure_firewall() {
  if command -v ufw >/dev/null 2>&1 && ufw status 2>/dev/null | grep -q 'Status: active'; then
    ufw allow "$PORT/tcp" comment SOCKS5 >/dev/null
    info "已在 UFW 中放行 TCP 端口 $PORT。"
  else
    warn "如果服务商控制台启用了防火墙，请放行 TCP 端口 $PORT。"
  fi
}

save_and_show_info() {
  local password="$1" ipv4 ipv6
  ipv4="$(public_ipv4)"
  ipv6="$(public_ipv6)"

  umask 077
  {
    echo "SOCKS5 节点信息"
    echo "================================"
    [[ -n "$ipv4" ]] && echo "公网 IPv4：$ipv4"
    [[ -n "$ipv6" ]] && echo "公网 IPv6：$ipv6"
    echo "端口：$PORT"
    echo "用户名：$SOCKS_USER"
    echo "密码：$password"
  } > "$CREDENTIALS"
  chmod 0600 "$CREDENTIALS"

  echo
  printf "${green}========== SOCKS5 搭建完成 ==========${reset}\n"
  [[ -n "$ipv4" ]] && printf "公网 IPv4：%s\n" "$ipv4"
  [[ -n "$ipv6" ]] && printf "公网 IPv6：%s\n" "$ipv6"
  printf "端口：     %s\n" "$PORT"
  printf "用户名：   %s\n" "$SOCKS_USER"
  printf "密码：     %s\n" "$password"
  printf "信息保存： %s\n" "$CREDENTIALS"
  printf "${green}==================================${reset}\n"
}

install_socks5() {
  require_root
  require_debian
  [[ "$PORT" =~ ^[0-9]+$ ]] && (( PORT >= 1 && PORT <= 65535 )) ||
    die "SOCKS_PORT 必须是 1 到 65535 之间的端口。"
  [[ "$SOCKS_USER" =~ ^[a-z_][a-z0-9_-]*$ ]] ||
    die "SOCKS_USER 包含不支持的字符。"

  install_packages

  local iface password
  iface="$(default_interface)"
  [[ -n "$iface" ]] || die "未找到默认网络接口。"
  password="${SOCKS_PASS:-$(generate_password)}"
  [[ -n "$password" && "$password" != *:* && "$password" != *$'\n'* ]] ||
    die "SOCKS_PASS 需要填写，且不可包含冒号或换行符。"

  create_user "$password"
  write_config "$iface"
  start_service
  configure_firewall
  save_and_show_info "$password"
}

show_status() {
  require_root
  systemctl --no-pager --full status danted || true
  echo
  [[ -f "$CREDENTIALS" ]] && cat "$CREDENTIALS"
}

uninstall_socks5() {
  require_root
  systemctl disable --now danted 2>/dev/null || true
  apt-get purge -y dante-server
  rm -f "$CONFIG" "$CREDENTIALS"
  info "SOCKS5 已卸载，配置备份仍保存在 $BACKUP_DIR。"
}

case "$ACTION" in
  install) install_socks5 ;;
  status) show_status ;;
  uninstall) uninstall_socks5 ;;
  *) die "用法：bash install.sh [install|status|uninstall]" ;;
esac
