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

使用 `root` 登录 VPS，然后复制下面这一整条命令执行：

```bash
apt-get update -y && apt-get install -y curl && bash <(curl -fsSL https://raw.githubusercontent.com/nus111/socks5-onekey/main/install.sh)
```

无需提前下载脚本，也无需手动填写本机 IP。运行后会依次提示：

```text
请输入 SOCKS5 端口 [默认：1080]：
请输入 SOCKS5 账号 [默认：socks5]：
请输入 SOCKS5 密码 [留空自动生成]：
```

依次输入端口、账号和密码即可。全部依赖会自动安装，脚本也会自动识别公网 IPv4/IPv6。

安装完成后，终端会直接显示：

```text
公网 IPv4：VPS 公网 IPv4
公网 IPv6：VPS 公网 IPv6
端口：1080
用户名：socks5
密码：自动生成的密码
```

最后还会输出可以直接复制到客户端的节点链接：

```text
socks5://socks5:密码@公网IPv4:1080
socks5://socks5:密码@[公网IPv6]:1080
```

如果 VPS 同时拥有公网 IPv4 和 IPv6，会分别生成两条链接。

连接信息同时保存在 VPS 的：

```text
/root/socks5-info.txt
```

## 无交互自动安装

```bash
NONINTERACTIVE=1 SOCKS_PORT=23456 SOCKS_USER=myuser SOCKS_PASS='YourStrongPassword' \
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

## 认证失败排查

如果客户端提示 `username/password authentication failed`，说明 VPS 端口已经连通，但账号密码没有通过 Dante 认证。请在 VPS 上执行：

```bash
cat /root/socks5-info.txt
```

优先复制文件中“可复制的节点链接”整行，不要手动修改其中的 `%40`、`%23` 等编码字符。如果客户端使用分开的账号密码输入框，账号填写“用户名”，密码填写“密码”这一行的原始内容。

检查服务状态：

```bash
systemctl is-active danted
ss -lntp | grep 23412
passwd -S socks5
```

需要重设账号密码时，重新运行一键命令并输入新的端口、账号和密码即可。

## 开源协议

[MIT](LICENSE)
