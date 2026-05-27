# 一键shadowsocks脚本

一个轻量的一次性 Shadowsocks 安装器：安装时负责下载、校验、配置和启动官方 `shadowsocks-rust`；安装完成后脚本自动删除，运行期只留下官方 `ssserver`、配置文件和 systemd 服务。

目标是解决两个痛点：

- 官方项目可信，但手动部署麻烦。
- 第三方一键脚本方便，但常常残留面板、管理进程或不透明下载源。

本项目的原则：

- 只使用 `github.com/shadowsocks/shadowsocks-rust` 官方 release。
- 下载官方 `.sha256` 并校验二进制包。
- 不安装 Docker，不安装面板，不常驻管理进程。
- NAT 友好，服务端只配置监听端口，外部端口只用于生成可直接复制的 `ss://` 链接。
- 支持 systemd 和 OpenRC，覆盖 Debian/Ubuntu/RHEL 系和 Alpine NAT 小鸡。
- 默认开启 TCP + UDP，保证节点可用性。
- 安装脚本默认自删除，减少磁盘占用和残留。

## 一键安装

通用安装命令，适合干净系统直接复制：

```sh
URL=https://raw.githubusercontent.com/siri666666/one-click-shadowsocks/main/install.sh; OUT=/tmp/ss-install.sh; dl(){ command -v wget >/dev/null 2>&1 && wget -O "$OUT" "$URL" && return 0; command -v curl >/dev/null 2>&1 && curl -fsSL -o "$OUT" "$URL" && return 0; command -v busybox >/dev/null 2>&1 && busybox wget --help >/dev/null 2>&1 && busybox wget -O "$OUT" "$URL" && return 0; return 1; }; deps(){ command -v apt-get >/dev/null 2>&1 && apt-get update && apt-get install -y ca-certificates wget && return 0; command -v dnf >/dev/null 2>&1 && dnf install -y ca-certificates wget && return 0; command -v microdnf >/dev/null 2>&1 && microdnf install -y ca-certificates wget && return 0; command -v yum >/dev/null 2>&1 && yum install -y ca-certificates wget && return 0; command -v apk >/dev/null 2>&1 && apk add --no-cache ca-certificates wget && return 0; command -v pacman >/dev/null 2>&1 && pacman -Sy --noconfirm ca-certificates wget && return 0; command -v zypper >/dev/null 2>&1 && zypper --non-interactive install ca-certificates wget && return 0; command -v tdnf >/dev/null 2>&1 && tdnf install -y ca-certificates wget && return 0; return 1; }; dl || { deps && dl; } || { echo "no downloader or supported package manager found" >&2; exit 1; }; sh "$OUT" install
```

NAT 小鸡：

```sh
URL=https://raw.githubusercontent.com/siri666666/one-click-shadowsocks/main/install.sh; OUT=/tmp/ss-install.sh; dl(){ command -v wget >/dev/null 2>&1 && wget -O "$OUT" "$URL" && return 0; command -v curl >/dev/null 2>&1 && curl -fsSL -o "$OUT" "$URL" && return 0; command -v busybox >/dev/null 2>&1 && busybox wget --help >/dev/null 2>&1 && busybox wget -O "$OUT" "$URL" && return 0; return 1; }; deps(){ command -v apt-get >/dev/null 2>&1 && apt-get update && apt-get install -y ca-certificates wget && return 0; command -v dnf >/dev/null 2>&1 && dnf install -y ca-certificates wget && return 0; command -v microdnf >/dev/null 2>&1 && microdnf install -y ca-certificates wget && return 0; command -v yum >/dev/null 2>&1 && yum install -y ca-certificates wget && return 0; command -v apk >/dev/null 2>&1 && apk add --no-cache ca-certificates wget && return 0; command -v pacman >/dev/null 2>&1 && pacman -Sy --noconfirm ca-certificates wget && return 0; command -v zypper >/dev/null 2>&1 && zypper --non-interactive install ca-certificates wget && return 0; command -v tdnf >/dev/null 2>&1 && tdnf install -y ca-certificates wget && return 0; return 1; }; dl || { deps && dl; } || { echo "no downloader or supported package manager found" >&2; exit 1; }; sh "$OUT" install --port 12345
```

如果机器已经有 `curl` 或 `wget`，也可以用短命令：

```sh
curl -fsSL https://raw.githubusercontent.com/siri666666/one-click-shadowsocks/main/install.sh | sh -s -- install
```

如果你已经把 `install.sh` 放到了机器上，直接执行即可，脚本会自动补齐最小依赖：

```sh
sh install.sh install
```

说明：上面的通用命令会自动尝试 `wget`、`curl`、BusyBox `wget`，如果都没有，会用系统包管理器安装 `ca-certificates` 和 `wget` 后继续。完全没有下载工具、没有可用包管理器或软件源不可访问的系统，任何远程一键脚本都无法凭空联网下载。

说明：

- `--port` 是服务器上 `ssserver` 实际监听的端口。
- 如果服务商做了端口映射，脚本不需要知道外部端口，服务端仍然只监听 `--port`。
- 客户端里把端口改成服务商给你的外部端口即可。
- 如果想让脚本输出的 `ss://` 链接直接使用外部端口，可以额外加 `--external-host` 和 `--external-port`。

例如服务商映射 `45678 -> 12345`，服务端部署：

```sh
sh ss-one.sh install --port 12345
```

客户端使用：

```text
服务器地址：服务商给你的公网地址
端口：45678
```

如果要让安装结果直接打印外部端口链接：

```sh
sh ss-one.sh install --port 12345 --external-host 1.2.3.4 --external-port 45678
```

## 默认保留文件

安装成功后只保留：

```text
/usr/local/bin/ssserver
/etc/shadowsocks-rust/config.json
/etc/shadowsocks-rust/install.env
/etc/systemd/system/ss-rust.service
```

Alpine/OpenRC 上服务文件是：

```text
/etc/init.d/ss-rust
```

不会保留安装器、压缩包、临时下载文件、面板或管理守护进程。

## 常用命令

查看服务状态：

```sh
systemctl status ss-rust
```

Alpine/OpenRC：

```sh
rc-service ss-rust status
```

查看分享链接：

```sh
sh ss-one.sh link
```

因为安装器默认会自删除，所以后续查看链接可以重新下载脚本后执行：

```sh
wget -O install.sh https://raw.githubusercontent.com/siri666666/one-click-shadowsocks/main/install.sh
sh install.sh link
rm -f install.sh
```

更新到官方最新版：

```sh
wget -O install.sh https://raw.githubusercontent.com/siri666666/one-click-shadowsocks/main/install.sh
sh install.sh update
```

卸载：

```sh
wget -O install.sh https://raw.githubusercontent.com/siri666666/one-click-shadowsocks/main/install.sh
sh install.sh uninstall
```

## 可选参数

```text
--port PORT              ssserver 实际监听端口
--external-host HOST     ss:// 链接里显示的公网 IP 或域名
--external-port PORT     ss:// 链接里显示的端口，不影响服务端监听
--listen ADDR            监听地址，默认 0.0.0.0
--password PASS          自定义密码/key
--method METHOD          加密方式，默认 2022-blake3-aes-128-gcm
--version VERSION        指定 shadowsocks-rust 版本
--tag NAME               ss:// 链接名称
--tcp-only               只开 TCP
--udp-only               只开 UDP
--no-install-deps        不自动安装缺失依赖
--no-start               安装后不启动服务
--force                  覆盖已有配置
--keep-installer         安装后保留脚本
```

如果客户端不支持 2022 加密方式，可以使用更兼容的：

```sh
sh ss-one.sh install --method chacha20-ietf-poly1305
```

## 适合的机器

这个脚本按低配 NAT VPS 设计。256 MB 内存、小硬盘机器也能用，因为运行期没有面板、Docker、Python、Node.js 或管理守护进程。

已支持：

```text
Debian / Ubuntu
CentOS / Rocky / Alma / Fedora
Alpine Linux
KVM VPS
NAT VPS
常规 LXC VPS，前提是允许 systemd 或 OpenRC 服务
```

服务质量相关配置没有为了省资源乱砍：

- 使用官方 `ssserver`。
- 默认 TCP + UDP。
- systemd 或 OpenRC 自动拉起。
- systemd 下设置 `LimitNOFILE=1048576`。
- 默认不碰复杂防火墙和系统网络参数，避免破坏 NAT 环境。

## 安全说明

这个脚本会以 root 权限写入 systemd 服务、配置文件和 `/usr/local/bin/ssserver`。建议先下载查看再运行：

```sh
wget -O ss-one.sh https://raw.githubusercontent.com/siri666666/one-click-shadowsocks/main/ss-one.sh
less ss-one.sh
sh ss-one.sh install
```

不要把不明来源的一键脚本直接 `curl | sh`。
