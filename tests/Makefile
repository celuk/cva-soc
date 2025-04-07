RISCVTYPE ?= riscv32-unknown-elf
CC = $(RISCVTYPE)-gcc

# use BOOT=1 while making if you will load the program from bootloader
# e.g.
# make compile bootloader
# make compile demo BOOT=1
BOOT ?= 0

WITHBOOTLOADER ?=

ifeq ($(BOOT), 1)
    WITHBOOTLOADER := withbootloader
endif

COMMON_PATH ?= common

LINKER_SCRIPT ?= coremark/riscv32-baremetal/link.ld
#$(COMMON_PATH)/link$(WITHBOOTLOADER).ld
START_ASM ?= coremark/riscv32-baremetal/crt0.S
#$(COMMON_PATH)/crt0$(WITHBOOTLOADER).S

DRIVERS_PATH ?= $(COMMON_PATH)/drivers
DRIVERS ?= coremark/riscv32-baremetal/syscalls.c coremark/riscv32-baremetal/ee_printf.c $(DRIVERS_PATH)/uart.c $(DRIVERS_PATH)/timer.c $(DRIVERS_PATH)/qspi.c

CFLAGS ?= -O2 -mcmodel=medany -static -std=gnu99 -fno-common -fno-unroll-loops -nostdlib -nostartfiles -fno-builtin -ffunction-sections -lm -lgcc -T $(LINKER_SCRIPT) -march=rv32im -mabi=ilp32 -I$(COMMON_PATH) -I$(DRIVERS_PATH) -Icoremark -Icoremark/riscv32-baremetal -DITERATIONS=2000 -DUSE_COREMARK_UTILS

CFILE ?= demo
CPATH ?= $(CFILE)/$(CFILE)

SRCS ?= $(CPATH).c $(DRIVERS) $(START_ASM)

OUTNAME ?= $(CPATH).riscv

.PHONY: all
all:
	$(CC) $(CFLAGS) $(SRCS) -o $(OUTNAME)
#	$(CC) -S $(CFLAGS) $(SRCS)
#	$(CC) -c $(CFLAGS) $(SRCS)

	$(RISCVTYPE)-objdump -d -M numeric,no-aliases $(CPATH).riscv > $(CPATH).dump

	$(RISCVTYPE)-objcopy -O binary $(CPATH).riscv $(CPATH).bin
	python3 ../tools/bin2hex.py $(CPATH).bin > $(CPATH).hex

	$(RISCVTYPE)-objcopy -O verilog $(CPATH).riscv $(CPATH).vmem

ifeq ($(BOOT), 1)
	python3 ../tools/clear_adresses_for_qspi_boot.py -f $(CPATH).vmem --place_zero > $(CPATH).tmp
	mv $(CPATH).tmp $(CPATH).vmem
endif

ifeq ($(CFILE), bootloader)
	python3 ../tools/generate_bootrom.py -f $(CPATH).hex --addr_width 14 > ../rtl/src/memory/bootrom.sv
endif

#.PHONY: $(CFILE)
#$(CFILE): all

.PHONY: clean
clean:
	rm -f $(CFILE)/*.log $(CFILE)/*.info $(CFILE)/index.html $(CFILE)/*.o $(CFILE)/*.s $(CFILE)/*.riscv $(CFILE)/*.bin $(CFILE)/*.hex $(CFILE)/*.vh $(CFILE)/*.vmem $(CFILE)/*.coe $(CFILE)/*.txt $(CFILE)/*.v $(CFILE)/*.dump $(CFILE)/*.tmp
