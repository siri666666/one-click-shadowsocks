#!/usr/bin/env sh
set -eu

SCRIPT_URL="${SCRIPT_URL:-https://raw.githubusercontent.com/siri666666/one-click-shadowsocks/main/ss-one.sh}"
SCRIPT_PATH="${SCRIPT_PATH:-/tmp/ss-one.sh}"

have() {
  command -v "$1" >/dev/null 2>&1
}

have_busybox_wget() {
  have busybox && busybox wget --help >/dev/null 2>&1
}

install_downloader() {
  if [ "$(id -u)" != "0" ]; then
    echo "please run as root so the script can install missing dependencies" >&2
    return 1
  fi

  if have apt-get; then
    export DEBIAN_FRONTEND=noninteractive
    apt-get update
    apt-get install -y ca-certificates wget
  elif have dnf; then
    dnf install -y ca-certificates wget
  elif have microdnf; then
    microdnf install -y ca-certificates wget
  elif have yum; then
    yum install -y ca-certificates wget
  elif have apk; then
    apk add --no-cache ca-certificates wget
  elif have pacman; then
    pacman -Sy --noconfirm ca-certificates wget
  elif have zypper; then
    zypper --non-interactive install ca-certificates wget
  elif have tdnf; then
    tdnf install -y ca-certificates wget
  else
    return 1
  fi
}

download_script() {
  if have curl; then
    curl -fsSL -o "$SCRIPT_PATH" "$SCRIPT_URL"
  elif have wget; then
    wget -O "$SCRIPT_PATH" "$SCRIPT_URL"
  elif have_busybox_wget; then
    busybox wget -O "$SCRIPT_PATH" "$SCRIPT_URL"
  else
    return 127
  fi
}

if ! download_script; then
  echo "[*] installing minimal downloader dependencies" >&2
  install_downloader || {
    echo "curl or wget is required to download ss-one.sh" >&2
    echo "No supported package manager was found for automatic dependency install." >&2
    exit 1
  }
  download_script || {
    echo "failed to download ss-one.sh from: $SCRIPT_URL" >&2
    exit 1
  }
fi

if [ ! -s "$SCRIPT_PATH" ]; then
  echo "downloaded script is empty: $SCRIPT_PATH" >&2
  exit 1
fi

chmod +x "$SCRIPT_PATH"
exec sh "$SCRIPT_PATH" "$@"
