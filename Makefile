# EC22711 SoC build switch:  make BUILD=A sim   |   make BUILD=C sim
BUILD ?= A

CORE  := rtl/core/regfile.v rtl/core/decoder.v rtl/core/alu.v \
	     rtl/core/alu_control.v rtl/core/control_unit.v rtl/core/imem.v \
	     rtl/core/dmem.v rtl/core/pipeline_regs.v rtl/core/forwarding_unit.v \
	     rtl/core/muldiv.v rtl/core/csr_unit.v rtl/core/rv32_pipeline.v
ACCEL := rtl/accel/nmc_psum.v rtl/accel/nmc_threshold.v \
	     rtl/accel/nmc_pool_reduce.v rtl/accel/nmc_unit.v rtl/accel/cim_sequencer.v rtl/accel/xif_bridge.v
SOC   := rtl/soc/soc_top.v
SRC   := $(CORE) $(ACCEL) $(SOC)

ifeq ($(BUILD),C)
DEF := -DNMC
else
DEF :=
endif

.PHONY: sim sim_trap lint clean

sim:
	mkdir -p build
	iverilog $(DEF) -o build/soc_$(BUILD).vvp $(SRC) tb/tb_soc.v
	vvp build/soc_$(BUILD).vvp

sim_trap:
	iverilog -o build/trap.vvp $(CORE) rtl/accel/nmc_psum.v rtl/accel/nmc_threshold.v rtl/accel/nmc_pool_reduce.v rtl/accel/nmc_unit.v rtl/accel/cim_sequencer.v rtl/accel/xif_bridge.v tb/tb_trap.v
	vvp build/trap.vvp

lint:
	verilator --lint-only --top-module soc_top $(DEF) $(SRC)

clean:
	rm -f build/*.vvp build/*.vcd

sim_nmc:
	mkdir -p build
	iverilog -DNMC -o build/nmc_instr.vvp $(SRC) tb/tb_nmc_instr.v
	vvp build/nmc_instr.vvp

sim_e2e:
	mkdir -p build
	riscv32-unknown-elf-gcc -march=rv32im_zicsr -mabi=ilp32 -nostdlib -Ttext=0x0 \
	    -o build/program_e2e.elf tests/program_e2e.S
	riscv64-unknown-elf-objcopy -O binary build/program_e2e.elf build/program_e2e.bin
	python3 -c "import sys; d=open('build/program_e2e.bin','rb').read(); open('tb/program_e2e.hex','w').write(''.join('%08x\n'%int.from_bytes(d[i:i+4],'little') for i in range(0,len(d),4)))"
	iverilog -DNMC -o build/e2e.vvp rtl/core/regfile.v rtl/core/decoder.v rtl/core/alu.v rtl/core/alu_control.v rtl/core/control_unit.v rtl/core/imem.v rtl/core/dmem.v rtl/core/pipeline_regs.v rtl/core/forwarding_unit.v rtl/core/muldiv.v rtl/core/csr_unit.v rtl/core/rv32_pipeline.v rtl/accel/nmc_psum.v rtl/accel/nmc_threshold.v rtl/accel/nmc_pool_reduce.v rtl/accel/nmc_unit.v rtl/accel/cim_sequencer.v rtl/accel/xif_bridge.v rtl/soc/soc_top.v tb/tb_e2e.v
	timeout 300 vvp build/e2e.vvp
