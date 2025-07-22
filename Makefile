SUBMAKE := $(MAKE) --no-print-directory -C

# All args except for the first one (which is the target name)
ARGS := $(wordlist 2,$(words $(MAKECMDGOALS)),$(MAKECMDGOALS))

.PHONY: all
all: 
	@echo "What are you expecting? (￣ー￣)";
	@echo "Read the makefile.";

XILINX_VIVADO ?= /tools/Xilinx/Vivado/2022.2
VIVADO_DIR    := ./vivado
COMPILED_LIBS := compiled-libs

.PHONY: compx
compx:
	@pushd $(VIVADO_DIR); \
	mkdir -p $(COMPILED_LIBS); \
	vlib $(COMPILED_LIBS); \
	vmap $(COMPILED_LIBS) $(shell pwd)/$(VIVADO_DIR)/$(COMPILED_LIBS); \
	vcom -2008 -work $(COMPILED_LIBS) $(XILINX_VIVADO)/data/vhdl/src/unisims/unisim_VCOMP.vhd $(XILINX_VIVADO)/data/vhdl/src/unisims/unisim_VPKG.vhd; \
	vlog -work $(COMPILED_LIBS) $(XILINX_VIVADO)/data/verilog/src/unisims/*.v; \
	export XILINX_VIVADO=$(XILINX_VIVADO); \
	vlog -work $(COMPILED_LIBS) -f $(XILINX_VIVADO)/data/secureip/secureip_cell.list.f; \
	vlog -work $(COMPILED_LIBS) $(XILINX_VIVADO)/data/verilog/src/glbl.v; \
	popd;
	
.PHONY: rmcompx
rmcompx:
	@pushd $(VIVADO_DIR); \
	rm -rf $(COMPILED_LIBS) \
	rm -f modelsim.ini; \
	popd;

#.PHONY: sim
#sim:
#	+@$(SUBMAKE) verification/sim/ $(ARGS)

.PHONY: coremark
coremark:
	+@$(SUBMAKE) tests/coremark clean
	+@$(SUBMAKE) tests/coremark

.PHONY: compile
compile:
	+@$(SUBMAKE) tests clean CFILE=$(ARGS)
	+@$(SUBMAKE) tests CFILE=$(ARGS)

.PHONY: compiletemp
compiletemp:
	@mkdir -p temp;
	@cp -f tests/Makefile temp/Makefile;
	@cp -rf tests/common temp/common;
	+@$(SUBMAKE) temp clean CFILE=$(ARGS)
	+@$(SUBMAKE) temp CFILE=$(ARGS)

.PHONY: rmtemp
rmtemp:
	@rm -rf temp;

.PHONY: clean_test
clean_test:
	+@$(SUBMAKE) tests clean CFILE=$(ARGS)

.PHONY: clean_all_tests
clean_all_tests:
	+@$(SUBMAKE) tests/coremark clean
	+@$(SUBMAKE) tests clean CFILE=demo
	+@$(SUBMAKE) tests clean CFILE=pikachu

.PHONY: sim
sim:
	+@$(SUBMAKE) verification/sim clean
	+@$(SUBMAKE) verification/sim air CFILE=$(ARGS)

.PHONY: simp
simp:
	+@$(SUBMAKE) verification/sim clean
	+@$(SUBMAKE) verification/sim air_program CFILE=$(ARGS)

.PHONY: simcoremark
simcoremark:
	+@$(SUBMAKE) verification/sim clean
	+@$(SUBMAKE) verification/sim air CFILE=coremark

.PHONY: send
send:
	@if [ "$(MAKECMDGOALS)" = "send" ]; then \
		python3 ./tools/uart_send_data.py; \
	else \
		python3 ./tools/uart_send_data.py --port /dev/ttyUSB$(word 2, $(MAKECMDGOALS)) --file $(word 3, $(MAKECMDGOALS)); \
	fi

.PHONY: sendc
sendc:
	python3 ./tools/uart_send_by_chunks.py

.PHONY: reset
reset:
	python3 ./tools/uart_send_reset.py --port /dev/ttyUSB$(word 2, $(MAKECMDGOALS));

.PHONY: pico
pico:
	picocom -b 921600 /dev/ttyUSB$(ARGS) --imap lfcrlf

%:
	@:

.PHONY: show
show:
	simvision verification/sim/sim_build/cocotb_waves.shm/cocotb_waves.trn
#	simvision -input verification/sim/waveform/xcelium_wave_setup.tcl verification/sim/sim_build/cocotb_waves.shm/cocotb_waves.trn
#	vsim verification/sim/sim_build/vsim.wlf -do verification/sim/waveform/wave.do
#-do verification/sim/waveform/wave.do

.PHONY: gen_dramw
gen_dramw: rmtemp
	python3 ./tools/generate_simple_dram_writes.py -f $(ARGS)

.PHONY: clean
clean:
	-rm -rf ./build
	-rm -rf ./sim_build
	-+@$(SUBMAKE) synth/quartus/ clean
	-+@$(SUBMAKE) synth/vivado/ clean
	-+@$(SUBMAKE) verification/sim/ clean
	-+@$(SUBMAKE) verification/prove/ clean
	-+@$(SUBMAKE) software/tests/riscv-tests/ clean
