#!/usr/bin/env bash
# usage: scripts/run_prog.sh tests/foo.S [timeout_cycles]
set -e
SRC=$1; TMO=${2:-100000}
NAME=$(basename "${SRC%.*}")
OUT=build/$NAME
CC=${CC:-riscv64-unknown-elf-gcc}
OBJCOPY=${OBJCOPY:-riscv64-unknown-elf-objcopy}
ARCH=${ARCH:-rv32im_zicsr}
mkdir -p build

cat > $OUT.ld << 'LD'
OUTPUT_ARCH(riscv)
ENTRY(_start)
SECTIONS {
  . = 0;
  .text : { *(.text*) }
  .rodata : { *(.rodata*) }
  .data : { *(.data*) }
}
LD

$CC -march=$ARCH -mabi=ilp32 -nostdlib -nostartfiles -T $OUT.ld -o $OUT.elf "$SRC"
$OBJCOPY -O binary $OUT.elf $OUT.bin

python3 - $OUT.bin $OUT.hex << 'PY'
import sys, struct
b = open(sys.argv[1], 'rb').read()
b += b'\0' * (-len(b) % 4)
with open(sys.argv[2], 'w') as f:
    for i in range(0, len(b), 4):
        f.write('%08x\n' % struct.unpack('<I', b[i:i+4])[0])
PY
n=$(wc -l < $OUT.hex); for i in $(seq $((n+1)) 256); do echo 00000013 >> $OUT.hex; done

iverilog -g2012 -P"tb_program.IMEM_FILE=\"$OUT.hex\"" -Ptb_program.TIMEOUT=$TMO \
    -o $OUT.vvp tb/tb_program.v $(find rtl -name '*.v')
vvp $OUT.vvp | tee $OUT.log
grep -q '^PASS' $OUT.log
