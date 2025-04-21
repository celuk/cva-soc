SUBMAKE := $(MAKE) --no-print-directory -C

# All args except for the first one (which is the target name)
ARGS := $(wordlist 2,$(words $(MAKECMDGOALS)),$(MAKECMDGOALS))

.PHONY: all
all: 
	@echo "What are you expecting? (￣ー￣)";
	@echo "Read the makefile.";


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

.PHONY: send
send:
	@if [ "$(MAKECMDGOALS)" = "send" ]; then \
		python3 ./tools/uart_send_data.py; \
	else \
		python3 ./tools/uart_send_data.py --port /dev/ttyUSB$(word 2, $(MAKECMDGOALS)) --file $(word 3, $(MAKECMDGOALS)); \
	fi

.PHONY: pico
pico:
	picocom -b 115200 /dev/ttyUSB$(ARGS) --imap lfcrlf

%:
	@:

.PHONY: show
show:
	vsim verification/sim/sim_build/vsim.wlf -do verification/sim/waveform/wave.do
#-do verification/sim/waveform/wave.do

.PHONY: clean
clean:
	-rm -rf ./build
	-rm -rf ./sim_build
	-+@$(SUBMAKE) synth/quartus/ clean
	-+@$(SUBMAKE) synth/vivado/ clean
	-+@$(SUBMAKE) verification/sim/ clean
	-+@$(SUBMAKE) verification/prove/ clean
	-+@$(SUBMAKE) software/tests/riscv-tests/ clean
