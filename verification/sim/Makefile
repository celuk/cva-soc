.PHONY: all
all: 
	@echo "What are you expecting? (￣ー￣)";
	@echo "Read the makefile.";

.PHONY: air
air:
	python3 ./main.py --sim questa --test tb_air --top  air_soc --waves true --cfile=$(CFILE)

.PHONY: air_icarus
air_icarus:
	python3 ./main.py --sim icarus --test tb_air --top  air_soc --waves true --cfile=$(CFILE)

.PHONY: air_program
air_program:
	python3 ./main.py --sim questa --test tb_air_program --top  air_soc --waves true --cfile=$(CFILE)

.PHONY: clean
clean:
	@echo "Cleaning sim outputs";
	-rm -rf ./sim_build ./__pycache__/
