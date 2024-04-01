#!/usr/bin/env bash

set -euo pipefail

if [[ "$#" -ge 1 && "$1" == --help ]]; then
  cat <<EOF
Usage:
  $0 {kernel|hello} [bash]"
  $0 only-build-img
  $0 --help
EOF
  exit 0
fi

docker="docker"

cd "$(dirname "$0")"

build_img() (
  cd context
  $docker build -t kernel-builder .
)

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
  shift
  shift

  set -x
  $docker run \
    -it \
    --privileged \
    --rm \
    -v "$(readlink -f "${SRC}")":/src \
    -v "${workdir}":/out \
    kernel-builder \
    "$@" | tee -a "$workdir/run.log"
}

run_interactive() {
  local workdir="$1"
  local SRC="$2"

  set -x
  $docker run \
    -it \
    --rm \
    -v "$(readlink -f "${SRC}")":/src \
    -v "${workdir}":/out \
    -entrypoint='' \
    kernel-builder \
    bash
}

build_img
if [[ "$#" -ge 1 && "$1" == only-build-img ]]; then
  exit 0
fi

case "$1" in
  kernel)
    shift
    KERNEL_VERSION=${2:-6.8.2}
    SRC=linux-${KERNEL_VERSION}
    TXZ=${SRC}.tar.xz
    URL=https://cdn.kernel.org/pub/linux/kernel/v6.x/${TXZ}
    TARGET=
    ;;
  hello)
    shift
    SRC=hello-2.12
    TXZ=${SRC}.tar.gz
    URL=https://ftp.gnu.org/gnu/hello/${TXZ}
    TARGET=
    ;;
  *)
    echo "Usage: $0 {kernel|hello}"
    exit 1
    ;;
esac


workdir="$(pwd)/wd-${SRC}/"
mkdir -p "$workdir"
cd "$workdir"

get_sources "$workdir" "$SRC" "$TXZ" "$URL"

if [[ "$#" -ge 1 && "$1" == bash ]]; then
  run_interactive "$workdir" "$SRC"
else
  run "$workdir" "$SRC" "$TARGET" "$@"
fi
