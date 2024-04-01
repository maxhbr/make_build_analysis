#!/usr/bin/env bash

set -euo pipefail

src="/src"
out="/out"
target="$1"
shift

cd "$src"

_configure() {
  echo "configure..."
  { 
    make defconfig || ./configure 
  } &> /out/configure.log
}

_expected_out() {
  local expected_out="$1"
  echo "####################################################################################"
  echo "####################################################################################"
  echo "####################################################################################"
  if [[ ! -f $expected_out || -d $expected_out ]]; then
    echo "make clean..."
    make clean &>/dev/null
    echo "start working on $expected_out ..."
  else
    echo "file $expected_out already exists"
    return 1
  fi
}

run_verbose_build() {
  if _expected_out $out/make.log; then
    find $src > $out/find.clean
    make V=1 -j$(nproc) $target 2>&1 | tee $out/make.log
    find $src > $out/find.build
  fi
}

run_make2graph() {
  if _expected_out $out/make.Bnd.log; then
    make -Bnd $target | tee $out/make.Bnd.log
    cat $out/make.Bnd.log | make2graph > $out/make.Bnd.dot
    cat $out/make.Bnd.log | make2graph --format x > $out/make.Bnd.xml
  fi
}

run_bear() {
  if _expected_out $out/bear.json; then
    bear --output $out/bear.json -- \
      make -j$(nproc) $target
    cat $out/bear.json | jq -r '.[] | [ .file, .output] | @csv' > $out/bear.json.csv
  fi
}

run_strace2csv() {
  if _expected_out $out/strace.log.csv; then
    strace -f -tt -T -y -yy -s 2048 -o $out/strace.log \
          make -j$(nproc) $target
    wc -l $out/strace.log
    strace2csv --verbose 1 $out/strace.log --out $out/strace.log.csv
  fi
}

run_tracecode() {
  if _expected_out $out/ts-parsed/; then
    mkdir -p "$out/ts"
    strace \
          -ff `# trace each process and children in a separate trace file` \
          -y `# decode file descs` \
          -ttt `# full resolution time stamps` \
          -s 256 `# get so many chars per args` \
          -a1 `# no alignment for results codes` \
          -qq `# suppress process exit messages` \
          -o "$out/ts/t" \
          make -j$(nproc) $target
    mkdir -p $out/ts-parsed/
    (
      set -x
      tracecode parse $out/ts/ $out/ts-parsed/
      #tracecode analyze $out/ts-parsed/ $out/ts-parsed.analyze
      tracecode inventory $out/ts-parsed/ $out/ts-parsed.inventory
      tracecode graphic $out/ts-parsed/ $out/ts-parsed.graphic
    )
  fi
}

run_gregkh_scripts() {
  if _expected_out $out/touched_files.txt; then
    /trace_kernel_build.sh \
      --make="make -j$(nproc) $target" \
      --kernel_dir=/src \
      --file_list=$out/touched_files.txt \
      --count | tee $out/touched_files.txt.log 
  fi
}

run_all() {
  run_verbose_build || ( echo "verbose_build failed" | tee -a "$out/failed_runs.log" )
  run_make2graph || ( echo "make2graph failed" | tee -a "$out/failed_runs.log" )
  run_bear || ( echo "bear failed" | tee -a "$out/failed_runs.log" )
  run_strace2csv || ( echo "strace2csv failed" | tee -a "$out/failed_runs.log" )
  run_tracecode || ( echo "tracecode failed" | tee -a "$out/failed_runs.log" )
  # run_gregkh_scripts || ( echo "gregkh_scripts failed" | tee -a "$out/failed_runs.log" )
}

_configure
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
  "gregkh_scripts")
    run_gregkh_scripts
    ;;
  *)
    run_all
    ;;
esac
