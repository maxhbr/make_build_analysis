#!/usr/bin/env bash

set -euo pipefail

cd "$(dirname "$0")"

build_img() {
  podman build -t kernel-builder .
}

get_sources() {
  local workdir="$1"
  local SRC="$2"
  local TXZ="$3"
  local URL="$4"

  if [[ ! -d "$SRC" ]]; then
    if [[ ! -f "$TXZ" ]]; then
      wget "$URL"
    fi
    tar -xvf ${TXZ}
  fi
}

run() {
  local workdir="$1"
  local SRC="$2"

  set -x
  podman run -it --rm -v "$(readlink -f "${SRC}")":/src -v "${workdir}":/out kernel-builder
}

run_interactive() {
  local workdir="$1"
  local SRC="$2"

  set -x
  podman run -it --rm -v "$(readlink -f "${SRC}")":/src -v "${workdir}":/out kernel-builder bash
}

case "$1" in
  kernel)
    shift
    KERNEL_VERSION=${2:-6.8.2}
    SRC=linux-${KERNEL_VERSION}
    TXZ=${SRC}.tar.xz
    URL=https://cdn.kernel.org/pub/linux/kernel/v6.x/${TXZ}
    ;;
  hello)
    shift
    SRC=hello-2.12
    TXZ=${SRC}.tar.gz
    URL=https://ftp.gnu.org/gnu/hello/${TXZ}
    ;;
  *)
    echo "Usage: $0 {kernel|hello}"
    exit 1
    ;;
esac

build_img


workdir="$(pwd)/wd-${SRC}/"
mkdir -p "$workdir"
cd "$workdir"

get_sources "$workdir" "$SRC" "$TXZ" "$URL"

if [[ "$#" -ge 1 && "$1" == bash ]]; then
  run_interactive "$workdir" "$SRC"
else
  run "$workdir" "$SRC"
fi
