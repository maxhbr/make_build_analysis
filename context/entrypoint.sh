#!/usr/bin/env bash

set -euo pipefail

in="${1:-/src}"
out="${2:-/out}"

cd "$in"

make defconfig || ./configure 

_expected_out() {
  local expected_out="$1"
  if [[ ! -f $expected_out || -d $expected_out ]]; then
    make clean
    echo "start working on $expected_out ..."
  else
    echo "file $expected_out already exists"
    return 1
  fi
}

run_verbose_build() {
  if _expected_out $out/make.log; then
    find $src > $out/find.clean
    make V=1 -j$(nproc) | tee $out/make.log
    find $src > $out/find.build
  fi
}

run_make2graph() {
  if _expected_out $out/make.Bnd.log; then
    make -Bnd | tee $out/make.Bnd.log
    cat $out/make.Bnd.log | make2graph > $out/make.Bnd.dot
    cat $out/make.Bnd.log | make2graph --format x > $out/make.Bnd.xml
  fi
}

run_bear() {
  if _expected_out $out/bear.json; then
    bear --output $out/bear.json -- \
      make -j$(nproc)
    cat $out/bear.json | jq -r '.[] | [ .file, .output] | @csv' > $out/bear.json.csv
  fi
}

run_strace2csv() {
  if _expected_out $out/t.log.csv; then
    strace -f -tt -T -y -yy -s 2048 -o $out/t.log \
          make -j$(nproc)
    wc -l $out/t.log
    strace2csv --verbose 1 $out/t.log --out $out/t.log.csv
  fi
}

run_tracecode() {
  if _expected_out $out/ts-parsed/; then
    strace \
          -ff `# trace each process and children in a separate trace file` \
          -y `# decode file descs` \
          -ttt `# full resolution time stamps` \
          -s 256 `# get so many chars per args` \
          -a1 `# no alignment for results codes` \
          -qq `# suppress process exit messages` \
          -o "$out/ts/t" \
          make -j$(nproc)
    mkdir -p $out/ts-parsed/
    tracecode parse $out/ts/ $out/ts-parsed/
    #tracecode analyze $out/ts-parsed/ $out/ts-parsed.analyze
    tracecode inventory $out/ts-parsed/ $out/ts-parsed.inventory
    tracecode graphic $out/ts-parsed/ $out/ts-parsed.graphic
  fi
}

run_all() {
  run_verbose_build
  run_make2graph
  run_bear
  run_strace2csv
  run_tracecode
}

case "${1:-all}" in
  "build")
    run_verbose_build
    ;;
  "make2graph")
    run_make2graph
    ;;
  "bear")
    run_bear
    ;;
  "strace2csv")
    run_strace2csv
    ;;
  "tracecode")
    run_tracecode
    ;;
  *)
    run_all
    ;;
esac
