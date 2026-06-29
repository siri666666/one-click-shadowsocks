#!/usr/bin/env sh
set -eu

PROJECT_NAME="one-click-shadowsocks"
OFFICIAL_REPO="shadowsocks/shadowsocks-rust"
OFFICIAL_API="https://api.github.com/repos/${OFFICIAL_REPO}"
OFFICIAL_RELEASE="https://github.com/${OFFICIAL_REPO}/releases/download"

SERVICE_NAME="ss-rust"
CONFIG_DIR="${CONFIG_DIR:-/etc/shadowsocks-rust}"
CONFIG_PATH="${CONFIG_PATH:-${CONFIG_DIR}/config.json}"
META_PATH="${META_PATH:-${CONFIG_DIR}/install.env}"
BINARY_PATH="${BINARY_PATH:-/usr/local/bin/ssserver}"
SYSTEMD_SERVICE_PATH="${SYSTEMD_SERVICE_PATH:-/etc/systemd/system/${SERVICE_NAME}.service}"
OPENRC_SERVICE_PATH="${OPENRC_SERVICE_PATH:-/etc/init.d/${SERVICE_NAME}}"
PID_PATH="${PID_PATH:-/run/${SERVICE_NAME}.pid}"
LOG_PATH="${LOG_PATH:-/var/log/${SERVICE_NAME}.log}"
MANAGER_PATH="${MANAGER_PATH:-/usr/local/bin/ss-one}"
MANAGER_SCRIPT_URL="${MANAGER_SCRIPT_URL:-https://raw.githubusercontent.com/siri666666/one-click-shadowsocks/main/ss-one.sh}"
INIT_SYSTEM=""

SCRIPT_NAME="${0##*/}"
if [ "$#" -eq 0 ] && [ "$SCRIPT_NAME" = "ss-one" ]; then
  COMMAND="menu"
else
  COMMAND="${1:-install}"
fi
case "$COMMAND" in
  install|interactive|update|repair|uninstall|status|link|restart|menu|update-manager|help|-h|--help) shift || true ;;
  *) COMMAND="install" ;;
esac

LISTEN_ADDR="0.0.0.0"
LISTEN_ADDR_SET=0
PORT=""
EXTERNAL_HOST=""
EXTERNAL_PORT=""
PASSWORD=""
METHOD="2022-blake3-aes-128-gcm"
MODE="tcp_and_udp"
IPV6_FIRST=0
DOWNLOAD_IP_VERSION="${DOWNLOAD_IP_VERSION:-auto}"
DOWNLOAD_CONNECT_TIMEOUT="${DOWNLOAD_CONNECT_TIMEOUT:-15}"
DOWNLOAD_MAX_TIME="${DOWNLOAD_MAX_TIME:-60}"
VERSION=""
TAG="SS-Rust"
INSTALL_DEPS=1
START_SERVICE=1
FORCE=0
SELF_DELETE=1
INSTALL_MANAGER=1

log() { printf '%s\n' "[*] $*"; }
ok() { printf '%s\n' "[+] $*"; }
warn() { printf '%s\n' "[!] $*" >&2; }
die() { printf '%s\n' "[x] $*" >&2; exit 1; }

reject_newline() {
  case "$1" in
    *'
'*) die "$2 must not contain newlines" ;;
  esac
}

json_escape() {
  reject_newline "$1" "JSON value"
  printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

usage() {
  cat <<'EOF'
One-click Shadowsocks installer for official shadowsocks-rust.

Usage:
  sh ss-one.sh install [options]
  sh ss-one.sh interactive
  sh ss-one.sh update [options]
  sh ss-one.sh repair
  sh ss-one.sh uninstall
  sh ss-one.sh status
  sh ss-one.sh link
  sh ss-one.sh restart
  sh ss-one.sh menu
  sh ss-one.sh update-manager

After install, the same commands are available through:
  ss-one
  ss-one link
  ss-one status
  ss-one update

Install options:
  --port PORT              Server listen port. Default: random high port.
  --external-host HOST     Host/IP used in the generated ss:// link. Default: public IP lookup.
  --external-port PORT     Port used in the generated ss:// link. Default: --port.
  --listen ADDR            Listen address. Default: 0.0.0.0, or :: for IPv6 endpoints.
  --password PASS          Password/key. Default: secure random value.
  --method METHOD          Cipher. Default: 2022-blake3-aes-128-gcm.
  --version VERSION        shadowsocks-rust version, for example 1.24.0.
  --tag NAME               Display tag in ss:// link. Default: SS-Rust.
  --tcp-only               TCP only.
  --udp-only               UDP only.
  --ipv6-first             Resolve domain names to IPv6 first.
  --ipv4-first             Resolve domain names to IPv4 first. Default.
  --download-ipv4          Force installer downloads over IPv4.
  --download-ipv6          Force installer downloads over IPv6.
  --download-auto          Auto-detect installer download IP version. Default.
  --no-install-deps        Do not install missing minimal dependencies.
  --no-start               Install but do not start service.
  --force                  Overwrite existing config on install.
  --no-manager             Do not install the persistent ss-one manager command.
  --install-manager        Install/update the persistent ss-one manager command. Default.
  --manager-path PATH      Manager command path. Default: /usr/local/bin/ss-one.
  --keep-installer         Keep this installer file after install/update.
  --self-delete            Delete this installer after install/update.

Examples:
  sh ss-one.sh install
  sh ss-one.sh interactive
  sh ss-one.sh install --port 12345 --external-host 1.2.3.4 --external-port 45678
  sh ss-one.sh install --method chacha20-ietf-poly1305

NAT note:
  ssserver only listens on --port. If your provider maps 45678 -> 12345,
  install with --port 12345 and use --external-port 45678 only to print
  a ready-to-copy client link.
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --port|--internal-port|--listen-port)
      [ "$#" -ge 2 ] || die "$1 requires a value"; PORT="$2"; shift 2 ;;
    --external-host|--host)
      [ "$#" -ge 2 ] || die "$1 requires a value"; EXTERNAL_HOST="$2"; shift 2 ;;
    --external-port)
      [ "$#" -ge 2 ] || die "$1 requires a value"; EXTERNAL_PORT="$2"; shift 2 ;;
    --listen|--listen-addr)
      [ "$#" -ge 2 ] || die "$1 requires a value"; LISTEN_ADDR="$2"; LISTEN_ADDR_SET=1; shift 2 ;;
    --password)
      [ "$#" -ge 2 ] || die "$1 requires a value"; PASSWORD="$2"; shift 2 ;;
    --method)
      [ "$#" -ge 2 ] || die "$1 requires a value"; METHOD="$2"; shift 2 ;;
    --version)
      [ "$#" -ge 2 ] || die "$1 requires a value"; VERSION="${2#v}"; shift 2 ;;
    --tag)
      [ "$#" -ge 2 ] || die "$1 requires a value"; TAG="$2"; shift 2 ;;
    --tcp-only)
      MODE="tcp_only"; shift ;;
    --udp-only)
      MODE="udp_only"; shift ;;
    --ipv6-first)
      IPV6_FIRST=1; shift ;;
    --ipv4-first)
      IPV6_FIRST=0; shift ;;
    --download-ipv4)
      DOWNLOAD_IP_VERSION=4; shift ;;
    --download-ipv6)
      DOWNLOAD_IP_VERSION=6; shift ;;
    --download-auto)
      DOWNLOAD_IP_VERSION=auto; shift ;;
    --no-install-deps)
      INSTALL_DEPS=0; shift ;;
    --install-deps)
      INSTALL_DEPS=1; shift ;;
    --no-start)
      START_SERVICE=0; shift ;;
    --force)
      FORCE=1; shift ;;
    --no-manager)
      INSTALL_MANAGER=0; shift ;;
    --install-manager)
      INSTALL_MANAGER=1; shift ;;
    --manager-path)
      [ "$#" -ge 2 ] || die "$1 requires a value"; MANAGER_PATH="$2"; shift 2 ;;
    --keep-installer)
      SELF_DELETE=0; shift ;;
    --self-delete)
      SELF_DELETE=1; shift ;;
    -h|--help|help)
      usage; exit 0 ;;
    *)
      die "unknown option: $1" ;;
  esac
done

need_root() {
  [ "$(id -u)" = "0" ] || die "please run as root"
}

have() {
  command -v "$1" >/dev/null 2>&1
}

have_busybox_wget() {
  have busybox && busybox wget --help >/dev/null 2>&1
}

have_downloader() {
  have curl || have wget || have_busybox_wget
}

have_supervise_daemon() {
  have supervise-daemon || [ -x /sbin/supervise-daemon ] || [ -x /usr/sbin/supervise-daemon ]
}

have_ca_certificates() {
  [ -s /etc/ssl/certs/ca-certificates.crt ] ||
    [ -s /etc/ssl/cert.pem ] ||
    [ -s /etc/pki/tls/certs/ca-bundle.crt ]
}

have_ipv6_default_route() {
  if have ip && ip -6 route show default 2>/dev/null | grep -q .; then
    return 0
  fi
  if have route && route -A inet6 -n 2>/dev/null | awk '($1 == "::/0" || $1 == "default") && $NF != "lo" && $3 !~ /!/ { found = 1 } END { exit found ? 0 : 1 }'; then
    return 0
  fi
  return 1
}

download_ip_args() {
  case "$DOWNLOAD_IP_VERSION" in
    4|ipv4|IPv4) printf '%s\n' "-4" ;;
    6|ipv6|IPv6) printf '%s\n' "-6" ;;
    auto|"")
      if have_ipv6_default_route; then
        printf '%s\n' "default"
        printf '%s\n' "-4"
      else
        printf '%s\n' "-4"
      fi ;;
    *) die "invalid DOWNLOAD_IP_VERSION: $DOWNLOAD_IP_VERSION" ;;
  esac
}

host_is_ipv6() {
  host="$1"
  case "$host" in
    \[*\]) host="${host#\[}"; host="${host%\]}" ;;
  esac
  case "$host" in
    *:*) return 0 ;;
    *) return 1 ;;
  esac
}

fetch_stdout_curl() {
  url="$1"
  ip_arg="$2"
  if [ -n "$ip_arg" ]; then
    curl "$ip_arg" -fsSL --retry 3 --connect-timeout "$DOWNLOAD_CONNECT_TIMEOUT" --max-time "$DOWNLOAD_MAX_TIME" "$url"
  else
    curl -fsSL --retry 3 --connect-timeout "$DOWNLOAD_CONNECT_TIMEOUT" --max-time "$DOWNLOAD_MAX_TIME" "$url"
  fi
}

fetch_stdout_wget() {
  url="$1"
  ip_arg="$2"
  if [ -n "$ip_arg" ]; then
    wget "$ip_arg" -q -T "$DOWNLOAD_CONNECT_TIMEOUT" -t 3 -O - "$url"
  else
    wget -q -T "$DOWNLOAD_CONNECT_TIMEOUT" -t 3 -O - "$url"
  fi
}

download_curl() {
  url="$1"
  output="$2"
  ip_arg="$3"
  if [ -n "$ip_arg" ]; then
    curl "$ip_arg" -fL --retry 3 --connect-timeout "$DOWNLOAD_CONNECT_TIMEOUT" --max-time "$DOWNLOAD_MAX_TIME" -o "$output" "$url"
  else
    curl -fL --retry 3 --connect-timeout "$DOWNLOAD_CONNECT_TIMEOUT" --max-time "$DOWNLOAD_MAX_TIME" -o "$output" "$url"
  fi
}

download_wget() {
  url="$1"
  output="$2"
  ip_arg="$3"
  if [ -n "$ip_arg" ]; then
    wget "$ip_arg" -T "$DOWNLOAD_CONNECT_TIMEOUT" -t 3 -O "$output" "$url"
  else
    wget -T "$DOWNLOAD_CONNECT_TIMEOUT" -t 3 -O "$output" "$url"
  fi
}

fetch_stdout() {
  url="$1"
  if have curl; then
    last_rc=1
    for ip_arg in $(download_ip_args); do
      [ "$ip_arg" = "default" ] && ip_arg=""
      fetch_stdout_curl "$url" "$ip_arg" && return 0
      last_rc=$?
      [ "$DOWNLOAD_IP_VERSION" = "auto" ] && [ "$ip_arg" != "-4" ] && warn "download failed, retrying with IPv4"
    done
    return "$last_rc"
  elif have wget; then
    last_rc=1
    for ip_arg in $(download_ip_args); do
      [ "$ip_arg" = "default" ] && ip_arg=""
      fetch_stdout_wget "$url" "$ip_arg" && return 0
      last_rc=$?
      [ "$DOWNLOAD_IP_VERSION" = "auto" ] && [ "$ip_arg" != "-4" ] && warn "download failed, retrying with IPv4"
    done
    return "$last_rc"
  elif have_busybox_wget; then
    busybox wget -q -O - "$url"
  else
    return 127
  fi
}

download() {
  url="$1"
  output="$2"
  if have curl; then
    last_rc=1
    for ip_arg in $(download_ip_args); do
      [ "$ip_arg" = "default" ] && ip_arg=""
      download_curl "$url" "$output" "$ip_arg" && return 0
      last_rc=$?
      rm -f "$output"
      [ "$DOWNLOAD_IP_VERSION" = "auto" ] && [ "$ip_arg" != "-4" ] && warn "download failed, retrying with IPv4"
    done
    return "$last_rc"
  elif have wget; then
    last_rc=1
    for ip_arg in $(download_ip_args); do
      [ "$ip_arg" = "default" ] && ip_arg=""
      download_wget "$url" "$output" "$ip_arg" && return 0
      last_rc=$?
      rm -f "$output"
      [ "$DOWNLOAD_IP_VERSION" = "auto" ] && [ "$ip_arg" != "-4" ] && warn "download failed, retrying with IPv4"
    done
    return "$last_rc"
  elif have_busybox_wget; then
    busybox wget -O "$output" "$url"
  else
    die "curl or wget is required"
  fi
}

install_missing_deps() {
  missing=""
  have_downloader || missing="${missing} download-tool"
  have_ca_certificates || missing="${missing} ca-certificates"
  have tar || missing="${missing} tar"
  have xz || missing="${missing} xz"
  have sha256sum || have shasum || missing="${missing} coreutils"

  [ -n "$missing" ] || return 0
  [ "$INSTALL_DEPS" = "1" ] || die "missing dependencies:${missing}; rerun without --no-install-deps"

  log "installing minimal dependencies:${missing}"
  if have apt-get; then
    export DEBIAN_FRONTEND=noninteractive
    apt-get update
    apt-get install -y ca-certificates wget tar xz-utils coreutils
  elif have dnf; then
    dnf install -y ca-certificates wget tar xz coreutils
  elif have microdnf; then
    microdnf install -y ca-certificates wget tar xz coreutils
  elif have yum; then
    yum install -y ca-certificates wget tar xz coreutils
  elif have apk; then
    apk add --no-cache ca-certificates wget tar xz coreutils openrc
  elif have pacman; then
    pacman -Sy --noconfirm ca-certificates wget tar xz coreutils
  elif have zypper; then
    zypper --non-interactive install ca-certificates wget tar xz coreutils
  elif have tdnf; then
    tdnf install -y ca-certificates wget tar xz coreutils
  else
    die "no supported package manager found; install curl/wget, ca-certificates, tar, xz, sha256sum manually"
  fi
}

ensure_init_manager() {
  if have systemctl && [ -d /run/systemd/system ]; then
    return 0
  fi
  if have rc-service && have rc-update && [ -d /etc/init.d ]; then
    return 0
  fi
  if have apk && [ "$INSTALL_DEPS" = "1" ]; then
    log "installing OpenRC for Alpine service management"
    apk add --no-cache openrc
    return 0
  fi
}

detect_init_system() {
  if have systemctl && [ -d /run/systemd/system ]; then
    printf '%s\n' "systemd"
  elif have rc-service && have rc-update && [ -d /etc/init.d ]; then
    printf '%s\n' "openrc"
  else
    die "unsupported init system; this script currently supports systemd and OpenRC"
  fi
}

validate_port() {
  p="$1"
  case "$p" in
    ''|*[!0-9]*) die "invalid port: $p" ;;
  esac
  [ "$p" -ge 1 ] 2>/dev/null && [ "$p" -le 65535 ] 2>/dev/null || die "invalid port: $p"
}

random_port() {
  if have od; then
    n="$(od -An -N2 -tu2 /dev/urandom 2>/dev/null | tr -d ' ')"
    printf '%s\n' "$((20000 + n % 40000))"
  else
    printf '%s\n' "$((20000 + ($(date +%s) % 40000)))"
  fi
}

random_b64() {
  bytes="$1"
  dd if=/dev/urandom bs="$bytes" count=1 2>/dev/null | base64 | tr -d '\n'
}

generate_password() {
  case "$METHOD" in
    2022-blake3-aes-128-gcm)
      random_b64 16 ;;
    2022-blake3-aes-256-gcm)
      random_b64 32 ;;
    *)
      random_b64 24 ;;
  esac
}

prompt_value() {
  label="$1"
  default="$2"
  printf '%s' "${label}" >&2
  [ -n "$default" ] && printf ' [%s]' "$default" >&2
  printf ': ' >&2
  IFS= read -r value || value=""
  [ -n "$value" ] || value="$default"
  printf '%s\n' "$value"
}

prompt_yes_no() {
  label="$1"
  default="$2"
  while :; do
    printf '%s [%s]: ' "$label" "$default" >&2
    IFS= read -r value || value=""
    [ -n "$value" ] || value="$default"
    case "$value" in
      y|Y|yes|YES|Yes) return 0 ;;
      n|N|no|NO|No) return 1 ;;
      *) warn "please answer y or n" ;;
    esac
  done
}

cmd_interactive() {
  [ -t 0 ] || die "interactive mode requires a TTY; download install.sh first, then run: sh install.sh interactive"

  printf '%s\n' "Interactive Shadowsocks installer"
  port_value="$(prompt_value "Listen port, empty for random" "")"
  [ -n "$port_value" ] && PORT="$port_value"

  external_host_value="$(prompt_value "External host/IP for ss link, empty for auto-detect" "")"
  [ -n "$external_host_value" ] && EXTERNAL_HOST="$external_host_value"

  external_port_default="$PORT"
  external_port_value="$(prompt_value "External port for ss link, empty to use listen port" "$external_port_default")"
  [ -n "$external_port_value" ] && EXTERNAL_PORT="$external_port_value"

  method_value="$(prompt_value "Cipher method" "$METHOD")"
  [ -n "$method_value" ] && METHOD="$method_value"

  password_value="$(prompt_value "Password/key, empty for random" "")"
  [ -n "$password_value" ] && PASSWORD="$password_value"

  tag_value="$(prompt_value "Link tag" "$TAG")"
  [ -n "$tag_value" ] && TAG="$tag_value"

  if prompt_yes_no "TCP only" "n"; then
    MODE="tcp_only"
  elif prompt_yes_no "UDP only" "n"; then
    MODE="udp_only"
  else
    MODE="tcp_and_udp"
  fi

  if prompt_yes_no "Prefer IPv6 DNS results" "n"; then
    IPV6_FIRST=1
  else
    IPV6_FIRST=0
  fi

  if [ -f "$CONFIG_PATH" ] && prompt_yes_no "Existing config found, overwrite" "n"; then
    FORCE=1
  fi

  cmd_install
}

detect_public_host() {
  host=""
  host="$(fetch_stdout https://api.ipify.org 2>/dev/null || true)"
  [ -n "$host" ] || host="$(fetch_stdout https://api64.ipify.org 2>/dev/null || true)"
  [ -n "$host" ] || host="YOUR_SERVER_IP"
  printf '%s\n' "$host"
}

latest_version() {
  err="${TMPDIR:-/tmp}/ss-one.latest.$$.err"
  json="$(fetch_stdout "${OFFICIAL_API}/releases/latest" 2>"$err" || true)"
  tag="$(printf '%s\n' "$json" | sed -n 's/.*"tag_name"[[:space:]]*:[[:space:]]*"v\{0,1\}\([^"]*\)".*/\1/p' | head -n 1)"
  if [ -z "$tag" ] && [ -s "$err" ]; then
    warn "GitHub API latest lookup failed:"
    sed 's/^/[!]   /' "$err" >&2
  fi
  rm -f "$err"
  if [ -z "$tag" ]; then
    warn "falling back to GitHub releases feed"
    feed="$(fetch_stdout "https://github.com/${OFFICIAL_REPO}/releases.atom" 2>/dev/null || true)"
    tag="$(printf '%s\n' "$feed" | sed -n 's/.*<title>[[:space:]]*v\{0,1\}\([0-9][0-9.][^<]*\)[[:space:]]*<\/title>.*/\1/p' | head -n 1)"
  fi
  if [ -z "$tag" ]; then
    warn "falling back to GitHub latest release page"
    latest_url="$(fetch_stdout "https://github.com/${OFFICIAL_REPO}/releases/latest" 2>/dev/null | sed -n 's/.*releases\/tag\/v\{0,1\}\([0-9][^"?#<]*\).*/\1/p' | head -n 1 || true)"
    tag="$latest_url"
  fi
  [ -n "$tag" ] || die "failed to detect latest shadowsocks-rust version; retry with --version VERSION or --download-ipv4"
  printf '%s\n' "$tag"
}

detect_target() {
  arch="$(uname -m)"
  case "$arch" in
    x86_64|amd64) printf '%s\n' "x86_64-unknown-linux-musl" ;;
    aarch64|arm64) printf '%s\n' "aarch64-unknown-linux-musl" ;;
    armv7l|armv7*) printf '%s\n' "armv7-unknown-linux-musleabihf" ;;
    armv6l|armv6*) printf '%s\n' "arm-unknown-linux-musleabihf" ;;
    arm*) printf '%s\n' "arm-unknown-linux-musleabihf" ;;
    i386|i686) printf '%s\n' "i686-unknown-linux-musl" ;;
    riscv64) printf '%s\n' "riscv64gc-unknown-linux-musl" ;;
    loongarch64) printf '%s\n' "loongarch64-unknown-linux-musl" ;;
    *) die "unsupported architecture: $arch" ;;
  esac
}

hash_file() {
  file="$1"
  if have sha256sum; then
    sha256sum "$file" | awk '{print $1}'
  elif have shasum; then
    shasum -a 256 "$file" | awk '{print $1}'
  else
    die "sha256sum or shasum is required"
  fi
}

verify_sha256() {
  file="$1"
  sha_file="$2"
  expected="$(awk '{print $1; exit}' "$sha_file")"
  actual="$(hash_file "$file")"
  [ "$expected" = "$actual" ] || die "sha256 mismatch for $(basename "$file")"
  ok "verified official sha256"
}

TMP_DIR=""
cleanup_tmp() {
  [ -n "${TMP_DIR:-}" ] && [ -d "$TMP_DIR" ] && rm -rf "$TMP_DIR"
}
trap cleanup_tmp EXIT INT TERM

install_binary() {
  install_missing_deps
  ensure_init_manager
  [ -n "$VERSION" ] || VERSION="$(latest_version)"
  target="$(detect_target)"
  asset="shadowsocks-v${VERSION}.${target}.tar.xz"
  base="${OFFICIAL_RELEASE}/v${VERSION}"
  TMP_DIR="$(mktemp -d /tmp/ss-one.XXXXXX)"

  log "downloading official shadowsocks-rust v${VERSION} (${target})"
  download "${base}/${asset}" "${TMP_DIR}/${asset}"
  download "${base}/${asset}.sha256" "${TMP_DIR}/${asset}.sha256"
  verify_sha256 "${TMP_DIR}/${asset}" "${TMP_DIR}/${asset}.sha256"

  tar -xJf "${TMP_DIR}/${asset}" -C "$TMP_DIR"
  src="$(find "$TMP_DIR" -type f -name ssserver | head -n 1)"
  [ -n "$src" ] || die "ssserver binary not found in official release archive"

  cp "$src" "$BINARY_PATH"
  chmod 0755 "$BINARY_PATH"
  ok "installed ${BINARY_PATH}"
}

write_config() {
  [ -n "$PORT" ] || PORT="$(random_port)"
  [ -n "$EXTERNAL_PORT" ] || EXTERNAL_PORT="$PORT"
  [ -n "$EXTERNAL_HOST" ] || EXTERNAL_HOST="$(detect_public_host)"
  [ -n "$PASSWORD" ] || PASSWORD="$(generate_password)"
  if [ "$LISTEN_ADDR_SET" = "0" ] && [ "$LISTEN_ADDR" = "0.0.0.0" ] && host_is_ipv6 "$EXTERNAL_HOST"; then
    LISTEN_ADDR="::"
  fi

  validate_port "$PORT"
  validate_port "$EXTERNAL_PORT"
  reject_newline "$LISTEN_ADDR" "listen address"
  reject_newline "$PASSWORD" "password"
  reject_newline "$METHOD" "method"
  reject_newline "$MODE" "mode"
  reject_newline "$EXTERNAL_HOST" "external host"
  reject_newline "$TAG" "tag"

  case "$IPV6_FIRST" in
    0) ipv6_first_json="false" ;;
    1) ipv6_first_json="true" ;;
    *) die "invalid ipv6_first value: $IPV6_FIRST" ;;
  esac

  listen_json="$(json_escape "$LISTEN_ADDR")"
  password_json="$(json_escape "$PASSWORD")"
  method_json="$(json_escape "$METHOD")"
  mode_json="$(json_escape "$MODE")"

  mkdir -p "$CONFIG_DIR"
  cat > "$CONFIG_PATH" <<EOF
{
  "server": "${listen_json}",
  "server_port": ${PORT},
  "password": "${password_json}",
  "method": "${method_json}",
  "timeout": 300,
  "mode": "${mode_json}",
  "no_delay": true,
  "ipv6_first": ${ipv6_first_json}
}
EOF
  chmod 0600 "$CONFIG_PATH"

  cat > "$META_PATH" <<EOF
VERSION=${VERSION}
METHOD=${METHOD}
INTERNAL_PORT=${PORT}
EXTERNAL_HOST=${EXTERNAL_HOST}
EXTERNAL_PORT=${EXTERNAL_PORT}
MODE=${MODE}
IPV6_FIRST=${IPV6_FIRST}
TAG=${TAG}
EOF
  chmod 0600 "$META_PATH"
  ok "wrote ${CONFIG_PATH}"
}

write_systemd_service() {
  cat > "$SYSTEMD_SERVICE_PATH" <<EOF
[Unit]
Description=Shadowsocks Rust Server
Documentation=https://github.com/shadowsocks/shadowsocks-rust
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=${BINARY_PATH} -c ${CONFIG_PATH}
Restart=always
RestartSec=3
LimitNOFILE=1048576
NoNewPrivileges=true

[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reload
  systemctl enable "$SERVICE_NAME" >/dev/null
  ok "installed systemd service ${SERVICE_NAME}"
}

write_openrc_service() {
  if have_supervise_daemon; then
    cat > "$OPENRC_SERVICE_PATH" <<EOF
#!/sbin/openrc-run

name="Shadowsocks Rust Server"
description="Shadowsocks Rust Server"
command="${BINARY_PATH}"
command_args="-c ${CONFIG_PATH}"
supervisor="supervise-daemon"
respawn_delay=3
respawn_max=0
pidfile="${PID_PATH}"
output_log="${LOG_PATH}"
error_log="${LOG_PATH}"

depend() {
  need net
  after firewall
}

start_pre() {
  checkpath -d -m 0755 /run
  checkpath -f -m 0644 "${LOG_PATH}"
}
EOF
  else
    cat > "$OPENRC_SERVICE_PATH" <<EOF
#!/sbin/openrc-run

name="Shadowsocks Rust Server"
description="Shadowsocks Rust Server"
command="${BINARY_PATH}"
command_args="-c ${CONFIG_PATH}"
command_background="yes"
pidfile="${PID_PATH}"
output_log="${LOG_PATH}"
error_log="${LOG_PATH}"

depend() {
  need net
  after firewall
}

start_pre() {
  checkpath -d -m 0755 /run
  checkpath -f -m 0644 "${LOG_PATH}"
}
EOF
  fi

  chmod 0755 "$OPENRC_SERVICE_PATH"
  rc-update add "$SERVICE_NAME" default >/dev/null
  ok "installed OpenRC service ${SERVICE_NAME}"
}

write_service() {
  INIT_SYSTEM="$(detect_init_system)"
  case "$INIT_SYSTEM" in
    systemd) write_systemd_service ;;
    openrc) write_openrc_service ;;
  esac
}

install_manager() {
  [ "$INSTALL_MANAGER" = "1" ] || return 0

  mkdir -p "$(dirname "$MANAGER_PATH")"
  if [ -f "$0" ] && [ -s "$0" ] && [ "$0" != "$MANAGER_PATH" ]; then
    cp "$0" "$MANAGER_PATH"
  elif [ -f "$MANAGER_PATH" ] && [ -s "$MANAGER_PATH" ]; then
    chmod 0755 "$MANAGER_PATH"
    ok "manager command kept at ${MANAGER_PATH}"
    return 0
  else
    download "$MANAGER_SCRIPT_URL" "$MANAGER_PATH"
  fi
  chmod 0755 "$MANAGER_PATH"
  ok "installed manager command ${MANAGER_PATH}"
}

update_manager_from_remote() {
  need_root
  mkdir -p "$(dirname "$MANAGER_PATH")"
  tmp="${MANAGER_PATH}.tmp.$$"
  download "$MANAGER_SCRIPT_URL" "$tmp" || {
    rm -f "$tmp"
    return 1
  }
  chmod 0755 "$tmp" || {
    rm -f "$tmp"
    return 1
  }
  mv "$tmp" "$MANAGER_PATH" || {
    rm -f "$tmp"
    return 1
  }
  ok "updated manager command ${MANAGER_PATH}"
}

service_start() {
  case "${INIT_SYSTEM:-$(detect_init_system)}" in
    systemd)
      systemctl restart "$SERVICE_NAME"
      systemctl is-active "$SERVICE_NAME" >/dev/null || die "service failed to start; run: journalctl -u ${SERVICE_NAME} -e"
      ;;
    openrc)
      rc-service "$SERVICE_NAME" restart
      rc-service "$SERVICE_NAME" status >/dev/null || die "service failed to start; run: tail -n 100 ${LOG_PATH}"
      ;;
  esac
}

service_restart() {
  case "${INIT_SYSTEM:-$(detect_init_system)}" in
    systemd)
      systemctl daemon-reload
      systemctl restart "$SERVICE_NAME"
      systemctl is-active "$SERVICE_NAME" >/dev/null || die "service failed after update"
      ;;
    openrc)
      rc-service "$SERVICE_NAME" restart
      rc-service "$SERVICE_NAME" status >/dev/null || die "service failed after update"
      ;;
  esac
}

service_stop_disable() {
  if have systemctl; then
    systemctl stop "$SERVICE_NAME" >/dev/null 2>&1 || true
    systemctl disable "$SERVICE_NAME" >/dev/null 2>&1 || true
  fi
  if have rc-service; then
    rc-service "$SERVICE_NAME" stop >/dev/null 2>&1 || true
  fi
  if have rc-update; then
    rc-update del "$SERVICE_NAME" default >/dev/null 2>&1 || true
  fi
}

service_status() {
  if have systemctl && [ -f "$SYSTEMD_SERVICE_PATH" ]; then
    systemctl --no-pager status "$SERVICE_NAME" || true
  elif have rc-service && [ -f "$OPENRC_SERVICE_PATH" ]; then
    rc-service "$SERVICE_NAME" status || true
  elif have systemctl; then
    systemctl --no-pager status "$SERVICE_NAME" || true
  elif have rc-service; then
    rc-service "$SERVICE_NAME" status || true
  else
    warn "no supported service manager found"
  fi
}

base64_url() {
  printf '%s' "$1" | base64 | tr -d '\n' | tr '+/' '-_' | sed 's/=*$//'
}

link_host() {
  host="$1"
  case "$host" in
    \[*\]) printf '%s\n' "$host" ;;
    *:*) printf '[%s]\n' "$host" ;;
    *) printf '%s\n' "$host" ;;
  esac
}

meta_get() {
  key="$1"
  [ -f "$META_PATH" ] || return 0
  sed -n "s/^${key}=//p" "$META_PATH" | head -n 1
}

link_from_files() {
  [ -f "$CONFIG_PATH" ] || die "config not found: ${CONFIG_PATH}"
  method="$(sed -n 's/.*"method"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$CONFIG_PATH" | head -n 1)"
  password="$(sed -n 's/.*"password"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$CONFIG_PATH" | head -n 1)"
  port="$(sed -n 's/.*"server_port"[[:space:]]*:[[:space:]]*\([0-9][0-9]*\).*/\1/p' "$CONFIG_PATH" | head -n 1)"
  host=""
  external_port=""
  tag="$TAG"

  host="$(meta_get EXTERNAL_HOST)"
  external_port="$(meta_get EXTERNAL_PORT)"
  saved_tag="$(meta_get TAG)"
  [ -n "$saved_tag" ] && tag="$saved_tag"

  [ -n "$host" ] || host="$(detect_public_host)"
  [ -n "$external_port" ] || external_port="$port"
  userinfo="$(base64_url "${method}:${password}")"
  tag64="$(printf '%s' "$tag" | sed 's/[ #?&]/-/g')"
  printf 'ss://%s@%s:%s#%s\n' "$userinfo" "$(link_host "$host")" "$external_port" "$tag64"
}

load_existing_settings() {
  [ -f "$CONFIG_PATH" ] || die "config not found: ${CONFIG_PATH}"

  existing_port="$(sed -n 's/.*"server_port"[[:space:]]*:[[:space:]]*\([0-9][0-9]*\).*/\1/p' "$CONFIG_PATH" | head -n 1)"
  existing_password="$(sed -n 's/.*"password"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$CONFIG_PATH" | head -n 1)"
  existing_method="$(sed -n 's/.*"method"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$CONFIG_PATH" | head -n 1)"
  existing_mode="$(sed -n 's/.*"mode"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$CONFIG_PATH" | head -n 1)"
  existing_server="$(sed -n 's/.*"server"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$CONFIG_PATH" | head -n 1)"
  existing_ipv6_first="$(sed -n 's/.*"ipv6_first"[[:space:]]*:[[:space:]]*\(true\|false\).*/\1/p' "$CONFIG_PATH" | head -n 1)"

  [ -n "$existing_port" ] && PORT="$existing_port"
  [ -n "$existing_password" ] && PASSWORD="$existing_password"
  [ -n "$existing_method" ] && METHOD="$existing_method"
  [ -n "$existing_mode" ] && MODE="$existing_mode"
  [ -n "$existing_server" ] && LISTEN_ADDR="$existing_server"
  case "$existing_ipv6_first" in
    true) IPV6_FIRST=1 ;;
    false) IPV6_FIRST=0 ;;
  esac

  saved_host="$(meta_get EXTERNAL_HOST)"
  saved_external_port="$(meta_get EXTERNAL_PORT)"
  saved_tag="$(meta_get TAG)"
  saved_version="$(meta_get VERSION)"
  saved_ipv6_first="$(meta_get IPV6_FIRST)"

  [ -n "$saved_host" ] && EXTERNAL_HOST="$saved_host"
  [ -n "$saved_external_port" ] && EXTERNAL_PORT="$saved_external_port"
  [ -n "$saved_tag" ] && TAG="$saved_tag"
  [ -n "$saved_version" ] && VERSION="$saved_version"
  case "$saved_ipv6_first" in
    0|1) IPV6_FIRST="$saved_ipv6_first" ;;
  esac

  [ -n "$PORT" ] || die "failed to read server_port from ${CONFIG_PATH}"
  [ -n "$PASSWORD" ] || die "failed to read password from ${CONFIG_PATH}"
  [ -n "$METHOD" ] || die "failed to read method from ${CONFIG_PATH}"
}

print_summary() {
  printf '\n'
  ok "Shadowsocks node is ready"
  printf '  Service:       %s\n' "$SERVICE_NAME"
  printf '  Init system:   %s\n' "${INIT_SYSTEM:-$(detect_init_system)}"
  printf '  Config:        %s\n' "$CONFIG_PATH"
  printf '  Listen port:   %s\n' "$PORT"
  printf '  Link endpoint: %s:%s\n' "$(link_host "$EXTERNAL_HOST")" "$EXTERNAL_PORT"
  printf '  Method:        %s\n' "$METHOD"
  printf '  Link:          %s\n' "$(link_from_files)"
}

self_delete_installer() {
  [ "$SELF_DELETE" = "1" ] || return 0
  case "$COMMAND" in install|interactive|update) ;; *) return 0 ;; esac

  script="$0"
  [ -f "$script" ] || return 0
  [ "$script" = "$MANAGER_PATH" ] && return 0
  case "$script" in
    */sh|sh|bash|-*) return 0 ;;
  esac

  if have git && git -C "$(dirname "$script")" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    log "installer kept because it is inside a git worktree"
    return 0
  fi

  rm -f -- "$script" && ok "installer removed: $script"

  if [ -n "${BOOTSTRAP_PATH:-}" ] && [ -f "$BOOTSTRAP_PATH" ]; then
    rm -f -- "$BOOTSTRAP_PATH" && ok "bootstrap removed: $BOOTSTRAP_PATH"
  fi
}

cmd_install() {
  need_root
  if [ -f "$CONFIG_PATH" ] && [ "$FORCE" != "1" ]; then
    die "${CONFIG_PATH} already exists; use update or install --force"
  fi
  install_binary
  write_config
  write_service
  install_manager
  if [ "$START_SERVICE" = "1" ]; then
    service_start
  fi
  print_summary
  self_delete_installer
}

cmd_update() {
  need_root
  [ -f "$CONFIG_PATH" ] || die "config not found; run install first"
  install_binary
  if [ -f "$META_PATH" ]; then
    tmp_meta="${META_PATH}.tmp"
    sed "s/^VERSION=.*/VERSION=\"${VERSION}\"/" "$META_PATH" > "$tmp_meta" && mv "$tmp_meta" "$META_PATH"
  fi
  service_restart
  if [ "$0" = "$MANAGER_PATH" ]; then
    update_manager_from_remote || warn "failed to update manager command ${MANAGER_PATH}"
  else
    install_manager
  fi
  ok "updated shadowsocks-rust to v${VERSION}"
  self_delete_installer
}

cmd_repair() {
  need_root
  [ -x "$BINARY_PATH" ] || die "binary not found: ${BINARY_PATH}; run install first"
  load_existing_settings
  [ -n "$VERSION" ] || VERSION="$("$BINARY_PATH" --version 2>/dev/null | awk '{print $2; exit}' | sed 's/^v//')"
  [ -n "$VERSION" ] || VERSION="unknown"
  write_config
  write_service
  install_manager
  service_restart
  print_summary
}

cmd_uninstall() {
  need_root
  service_stop_disable
  rm -f "$SYSTEMD_SERVICE_PATH"
  rm -f "$OPENRC_SERVICE_PATH"
  rm -f "$PID_PATH"
  rm -f "$BINARY_PATH"
  rm -f "$MANAGER_PATH"
  rm -rf "$CONFIG_DIR"
  have systemctl && systemctl daemon-reload || true
  ok "uninstalled ${PROJECT_NAME}"
}

cmd_status() {
  service_status
  [ -x "$BINARY_PATH" ] && "$BINARY_PATH" --version || true
  [ -f "$CONFIG_PATH" ] && printf 'Config: %s\n' "$CONFIG_PATH"
}

cmd_restart() {
  need_root
  service_restart
  ok "restarted ${SERVICE_NAME}"
}

cmd_menu() {
  [ -t 0 ] || die "menu mode requires a TTY"
  while :; do
    printf '\n%s\n' "Shadowsocks manager"
    printf '%s\n' "1) Show ss:// link"
    printf '%s\n' "2) Show service status"
    printf '%s\n' "3) Restart service"
    printf '%s\n' "4) Update shadowsocks-rust"
    printf '%s\n' "5) Repair service/config"
    printf '%s\n' "6) Update manager script"
    printf '%s\n' "7) Uninstall"
    printf '%s\n' "0) Exit"
    printf '%s' "Choose: "
    IFS= read -r choice || choice=""
    case "$choice" in
      1) link_from_files ;;
      2) cmd_status ;;
      3) cmd_restart ;;
      4) cmd_update ;;
      5) cmd_repair ;;
      6) update_manager_from_remote ;;
      7) cmd_uninstall; return 0 ;;
      0|"") return 0 ;;
      *) warn "unknown choice: $choice" ;;
    esac
  done
}

case "$COMMAND" in
  install) cmd_install ;;
  interactive) cmd_interactive ;;
  update) cmd_update ;;
  repair) cmd_repair ;;
  uninstall) cmd_uninstall ;;
  status) cmd_status ;;
  link) link_from_files ;;
  restart) cmd_restart ;;
  menu) cmd_menu ;;
  update-manager) update_manager_from_remote ;;
  help|-h|--help) usage ;;
esac
exit 0
