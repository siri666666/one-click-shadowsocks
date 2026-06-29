# 一键shadowsocks脚本

一个轻量的 Shadowsocks 安装器：安装时负责下载、校验、配置和启动官方 `shadowsocks-rust`；安装完成后安装器自动删除，运行期只留下官方 `ssserver`、配置文件、系统服务和一个 `ss-one` 管理命令。

目标是解决几个痛点：

- 官方项目可信，但手动部署麻烦。
- 第三方一键脚本方便，但常常残留面板、管理进程或不透明下载源。
- 服务器装好系统后 可能需要先安装bash/curl/wget等依赖才能用其他所谓的“一键”脚本
- 服务器是外网映射内网的形式 用普通的脚本建好节点后还得手动改成外部ip/ddns和外部端口才能开始使用
  
本项目的原则：

- 只使用 `github.com/shadowsocks/shadowsocks-rust` 官方 release。
- 下载官方 `.sha256` 并校验二进制包。
- 不安装 Docker，不安装面板，不常驻管理进程。
- NAT 友好，服务端只配置监听端口，外部端口只用于生成可直接复制的 `ss://` 链接。
- 支持 systemd 和 OpenRC，覆盖 Debian/Ubuntu/RHEL 系和 Alpine NAT 小鸡。
- 默认开启 TCP + UDP，保证节点可用性。
- 安装脚本默认自删除，减少磁盘占用和残留。
- 默认保留 `ss-one` 管理命令，方便后续查看链接、状态、更新、修复和卸载。

## 安装

（推荐）交互安装，按提示设置端口、密码、外部端口等参数：

```sh
set -- interactive; URL=https://raw.githubusercontent.com/siri666666/one-click-shadowsocks/main/install.sh; OUT=/tmp/ss-install.sh; dl(){ command -v wget >/dev/null 2>&1 && wget -O "$OUT" "$URL" && return 0; command -v curl >/dev/null 2>&1 && curl -fsSL -o "$OUT" "$URL" && return 0; command -v busybox >/dev/null 2>&1 && busybox wget --help >/dev/null 2>&1 && busybox wget -O "$OUT" "$URL" && return 0; return 1; }; deps(){ command -v apt-get >/dev/null 2>&1 && apt-get update && apt-get install -y ca-certificates wget && return 0; command -v dnf >/dev/null 2>&1 && dnf install -y ca-certificates wget && return 0; command -v microdnf >/dev/null 2>&1 && microdnf install -y ca-certificates wget && return 0; command -v yum >/dev/null 2>&1 && yum install -y ca-certificates wget && return 0; command -v apk >/dev/null 2>&1 && apk add --no-cache ca-certificates wget && return 0; command -v pacman >/dev/null 2>&1 && pacman -Sy --noconfirm ca-certificates wget && return 0; command -v zypper >/dev/null 2>&1 && zypper --non-interactive install ca-certificates wget && return 0; command -v tdnf >/dev/null 2>&1 && tdnf install -y ca-certificates wget && return 0; return 1; }; dl || { deps && dl; } || { echo "no downloader or supported package manager found" >&2; exit 1; }; sh "$OUT" "$@"
```

一键随机，自动生成端口和密码：

```sh
set -- install; URL=https://raw.githubusercontent.com/siri666666/one-click-shadowsocks/main/install.sh; OUT=/tmp/ss-install.sh; dl(){ command -v wget >/dev/null 2>&1 && wget -O "$OUT" "$URL" && return 0; command -v curl >/dev/null 2>&1 && curl -fsSL -o "$OUT" "$URL" && return 0; command -v busybox >/dev/null 2>&1 && busybox wget --help >/dev/null 2>&1 && busybox wget -O "$OUT" "$URL" && return 0; return 1; }; deps(){ command -v apt-get >/dev/null 2>&1 && apt-get update && apt-get install -y ca-certificates wget && return 0; command -v dnf >/dev/null 2>&1 && dnf install -y ca-certificates wget && return 0; command -v microdnf >/dev/null 2>&1 && microdnf install -y ca-certificates wget && return 0; command -v yum >/dev/null 2>&1 && yum install -y ca-certificates wget && return 0; command -v apk >/dev/null 2>&1 && apk add --no-cache ca-certificates wget && return 0; command -v pacman >/dev/null 2>&1 && pacman -Sy --noconfirm ca-certificates wget && return 0; command -v zypper >/dev/null 2>&1 && zypper --non-interactive install ca-certificates wget && return 0; command -v tdnf >/dev/null 2>&1 && tdnf install -y ca-certificates wget && return 0; return 1; }; dl || { deps && dl; } || { echo "no downloader or supported package manager found" >&2; exit 1; }; sh "$OUT" "$@"
```

一键预设，只填你想固定的参数，没填的继续自动随机或自动识别：

```sh
set -- install --port 12345; URL=https://raw.githubusercontent.com/siri666666/one-click-shadowsocks/main/install.sh; OUT=/tmp/ss-install.sh; dl(){ command -v wget >/dev/null 2>&1 && wget -O "$OUT" "$URL" && return 0; command -v curl >/dev/null 2>&1 && curl -fsSL -o "$OUT" "$URL" && return 0; command -v busybox >/dev/null 2>&1 && busybox wget --help >/dev/null 2>&1 && busybox wget -O "$OUT" "$URL" && return 0; return 1; }; deps(){ command -v apt-get >/dev/null 2>&1 && apt-get update && apt-get install -y ca-certificates wget && return 0; command -v dnf >/dev/null 2>&1 && dnf install -y ca-certificates wget && return 0; command -v microdnf >/dev/null 2>&1 && microdnf install -y ca-certificates wget && return 0; command -v yum >/dev/null 2>&1 && yum install -y ca-certificates wget && return 0; command -v apk >/dev/null 2>&1 && apk add --no-cache ca-certificates wget && return 0; command -v pacman >/dev/null 2>&1 && pacman -Sy --noconfirm ca-certificates wget && return 0; command -v zypper >/dev/null 2>&1 && zypper --non-interactive install ca-certificates wget && return 0; command -v tdnf >/dev/null 2>&1 && tdnf install -y ca-certificates wget && return 0; return 1; }; dl || { deps && dl; } || { echo "no downloader or supported package manager found" >&2; exit 1; }; sh "$OUT" "$@"
```

预设参数可以按需追加，例如 `--password 'your-password'`、`--method chacha20-ietf-poly1305`、`--tag my-ss`、`--external-host 1.2.3.4`、`--external-port 45678`。



修复已有安装，不改变端口、密码和加密方式：

```sh
wget -O install.sh https://raw.githubusercontent.com/siri666666/one-click-shadowsocks/main/install.sh && sh install.sh repair
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
- 如果 `--external-host` 是 IPv6 地址且没有手动指定 `--listen`，脚本会自动监听 `::`，生成的 `ss://` 链接也会使用 `[IPv6]:端口` 格式。
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
/usr/local/bin/ss-one
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

安装完成后会保留一个管理命令：

```sh
ss-one
```

直接运行 `ss-one` 会打开交互菜单。也可以使用下面的子命令。

查看分享链接：

```sh
ss-one link
```

查看服务状态：

```sh
ss-one status
```

重启服务：

```sh
ss-one restart
```

更新到官方最新版：

```sh
ss-one update
```

修复服务文件和配置：

```sh
ss-one repair
```

卸载：

```sh
ss-one uninstall
```

## 可选参数

```text
--port PORT              ssserver 实际监听端口
--external-host HOST     ss:// 链接里显示的公网 IP 或域名
--external-port PORT     ss:// 链接里显示的端口，不影响服务端监听
--listen ADDR            监听地址，默认 0.0.0.0；外部地址为 IPv6 时自动使用 ::
--password PASS          自定义密码/key
--method METHOD          加密方式，默认 2022-blake3-aes-128-gcm
--version VERSION        指定 shadowsocks-rust 版本
--tag NAME               ss:// 链接名称
--tcp-only               只开 TCP
--udp-only               只开 UDP
--ipv4-first             域名解析优先 IPv4，默认值，适合大多数 NAT 小鸡
--ipv6-first             域名解析优先 IPv6
--download-ipv4          安装器下载强制走 IPv4
--download-ipv6          安装器下载强制走 IPv6
--download-auto          安装器自动检测下载 IP 版本，默认值；无 IPv6 默认路由时自动走 IPv4
--no-install-deps        不自动安装缺失依赖
--no-start               安装后不启动服务
--force                  覆盖已有配置
--no-manager             不安装 /usr/local/bin/ss-one 管理命令
--manager-path PATH      自定义管理命令路径
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
- OpenRC 下优先使用 `supervise-daemon` 监控进程，异常退出会自动拉起。
- 默认 `ipv6_first=false`，避免无 IPv6 出口的 NAT 小鸡优先访问 IPv6 目标。
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
