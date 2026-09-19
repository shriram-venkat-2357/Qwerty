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
	iverilog -o build/trap.vvp $(CORE) tb/tb_trap.v
	vvp build/trap.vvp

lint:
	verilator --lint-only --top-module soc_top $(DEF) $(SRC)

clean:
	rm -f build/*.vvp build/*.vcd

sim_nmc:
	mkdir -p build
	iverilog -DNMC -o build/nmc_instr.vvp $(SRC) tb/tb_nmc_instr.v
	vvp build/nmc_instr.vvp
