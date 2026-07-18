# SOCKS5 一键搭建

面向 Debian/Ubuntu VPS 的轻量级 SOCKS5 一键安装脚本，适合低配置服务器。

## 功能

- 自动识别默认网卡和公网 IPv4/IPv6
- 自动生成用户名与强密码
- 同时监听 IPv4 和 IPv6
- 仅允许用户名密码认证
- 自动配置开机启动
- 自动备份原有 Dante 配置
- 支持查看状态和卸载

## 一键安装

使用 `root` 登录 VPS，然后复制下面整条命令执行：

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/nus111/socks5-onekey/main/install.sh)
```

安装完成后，终端会直接显示：

```text
IPv4:     VPS 公网 IPv4
IPv6:     VPS 公网 IPv6
Port:     1080
Username: socks5
Password: 自动生成的密码
```

连接信息同时保存在 VPS 的：

```text
/root/socks5-info.txt
```

## 自定义端口、用户名和密码

```bash
SOCKS_PORT=23456 SOCKS_USER=myuser SOCKS_PASS='YourStrongPassword' \
bash <(curl -fsSL https://raw.githubusercontent.com/nus111/socks5-onekey/main/install.sh)
```

## 查看状态

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/nus111/socks5-onekey/main/install.sh) status
```

## 卸载

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/nus111/socks5-onekey/main/install.sh) uninstall
```

## 系统要求

- Debian 11/12/13 或 Ubuntu 20.04/22.04/24.04
- 使用 systemd
- root 权限
- VPS 防火墙放行对应 TCP 端口，默认 `1080`

## 安全提示

- 安装脚本默认启用用户名密码认证。
- 请妥善保存 `/root/socks5-info.txt`。
- 建议在云厂商防火墙中仅向自己的固定 IP 放行 SOCKS5 端口。

## 开源协议

[MIT](LICENSE)
