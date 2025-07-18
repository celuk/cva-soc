.PHONY: all
all: 
	@echo "What are you expecting? (￣ー￣)";
	@echo "Read the makefile.";

.PHONY: air
air:
	@export XILINX_VIVADO=/tools/Xilinx/Vivado/2022.2; \
	python3 ./main.py --sim xcelium --test tb_air --top  secure_soc --waves true --cfile=$(CFILE)

.PHONY: air_icarus
air_icarus:
	python3 ./main.py --sim icarus --test tb_air --top  secure_soc --waves true --cfile=$(CFILE)

.PHONY: air_program
air_program:
	@export XILINX_VIVADO=/tools/Xilinx/Vivado/2022.2; \
	python3 ./main.py --sim xcelium --test tb_air_program --top  secure_soc --waves true --cfile=$(CFILE)

.PHONY: clean
clean:
	@echo "Cleaning sim outputs";
	-rm -rf ./sim_build ./__pycache__/
