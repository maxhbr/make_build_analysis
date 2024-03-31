#!/usr/bin/env bash

set -euo pipefail

in="${1:-/src}"
out="${2:-/out}"

cd "$in"

make defconfig || ./configure 

if [ ! -f $out/make.log ]; then
  make clean
  find $src > $out/find.clean
  make V=1 -j$(nproc) | tee $out/make.log
  find $src > $out/find.build
fi

if [ ! -f $out/make.Bnd.log ]; then
  make clean
  make -Bnd | tee $out/make.Bnd.log
  cat $out/make.Bnd.log | make2graph > $out/make.Bnd.dot
  cat $out/make.Bnd.log | make2graph --format x > $out/make.Bnd.xml
fi

if [ ! -f $out/bear.json ]; then
  make clean
  bear --output $out/bear.json -- \
    make -j$(nproc)
  cat $out/bear.json | jq -r '.[] | [ .file, .output] | @csv' > $out/bear.json.csv
fi

if [ ! -f $out/t.log.csv ]; then
  make clean
  strace -f -tt -T -y -yy -s 2048 -o $out/t.log \
        make -j$(nproc)
  wc -l $out/t.log
  strace2csv --verbose 1 $out/t.log --out $out/t.log.csv
fi

if [ ! -d $out/ts-parsed/ ]; then
      make clean
  mkdir -p $out/ts/
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
