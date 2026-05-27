# 一键shadowsocks脚本

一个轻量的一次性 Shadowsocks 安装器：安装时负责下载、校验、配置和启动官方 `shadowsocks-rust`；安装完成后脚本自动删除，运行期只留下官方 `ssserver`、配置文件和 systemd 服务。

目标是解决两个痛点：

- 官方项目可信，但手动部署麻烦。
- 第三方一键脚本方便，但常常残留面板、管理进程或不透明下载源。

本项目的原则：

- 只使用 `github.com/shadowsocks/shadowsocks-rust` 官方 release。
- 下载官方 `.sha256` 并校验二进制包。
- 不安装 Docker，不安装面板，不常驻管理进程。
- NAT 友好，区分内部监听端口和外部连接端口。
- 默认开启 TCP + UDP，保证节点可用性。
- 安装脚本默认自删除，减少磁盘占用和残留。

## 一键安装

普通 VPS：

```sh
curl -fsSLO https://raw.githubusercontent.com/siri666666/one-click-shadowsocks/main/ss-one.sh
sh ss-one.sh install
```

NAT 小鸡：

```sh
curl -fsSLO https://raw.githubusercontent.com/siri666666/one-click-shadowsocks/main/ss-one.sh
sh ss-one.sh install --port 12345 --external-host 1.2.3.4 --external-port 45678
```

说明：

- `--port` 是 VPS 内部监听端口。
- `--external-host` 是客户端连接的公网 IP 或域名。
- `--external-port` 是服务商映射给你的外部端口。

## 默认保留文件

安装成功后只保留：

```text
/usr/local/bin/ssserver
/etc/shadowsocks-rust/config.json
/etc/shadowsocks-rust/install.env
/etc/systemd/system/ss-rust.service
```

不会保留安装器、压缩包、临时下载文件、面板或管理守护进程。

## 常用命令

查看服务状态：

```sh
systemctl status ss-rust
```

查看分享链接：

```sh
sh ss-one.sh link
```

因为安装器默认会自删除，所以后续查看链接可以重新下载脚本后执行：

```sh
curl -fsSLO https://raw.githubusercontent.com/siri666666/one-click-shadowsocks/main/ss-one.sh
sh ss-one.sh link
rm -f ss-one.sh
```

更新到官方最新版：

```sh
curl -fsSLO https://raw.githubusercontent.com/siri666666/one-click-shadowsocks/main/ss-one.sh
sh ss-one.sh update
```

卸载：

```sh
curl -fsSLO https://raw.githubusercontent.com/siri666666/one-click-shadowsocks/main/ss-one.sh
sh ss-one.sh uninstall
```

## 可选参数

```text
--port PORT              内部监听端口
--external-host HOST     客户端连接的公网 IP 或域名
--external-port PORT     NAT 外部端口
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

服务质量相关配置没有为了省资源乱砍：

- 使用官方 `ssserver`。
- 默认 TCP + UDP。
- systemd 自动拉起。
- `LimitNOFILE=1048576`。
- 默认不碰复杂防火墙和系统网络参数，避免破坏 NAT 环境。

## 安全说明

这个脚本会以 root 权限写入 systemd 服务、配置文件和 `/usr/local/bin/ssserver`。建议先下载查看再运行：

```sh
curl -fsSLO https://raw.githubusercontent.com/siri666666/one-click-shadowsocks/main/ss-one.sh
less ss-one.sh
sh ss-one.sh install
```

不要把不明来源的一键脚本直接 `curl | sh`。
