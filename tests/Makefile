RISCVTYPE ?= riscv32-unknown-elf
CC = $(RISCVTYPE)-gcc

ASM = 0

# use BOOT=1 while making if you will load the program from bootloader
# e.g.
# make compile bootloader
# make compile demo BOOT=1
BOOT ?= 0

WITHBOOTLOADER ?=

USE_COREMARK ?= 0

ifeq ($(BOOT), 1)
    WITHBOOTLOADER := withbootloader
endif

COMMON_PATH ?= common

LINKER_SCRIPT ?= $(COMMON_PATH)/link$(WITHBOOTLOADER).ld
#coremark/riscv32-baremetal/link.ld

START_ASM ?= $(COMMON_PATH)/crt0$(WITHBOOTLOADER).S
#coremark/riscv32-baremetal/crt0.S

DRIVERS_PATH ?= $(COMMON_PATH)/drivers
DRIVERS ?= $(DRIVERS_PATH)/uart.c $(DRIVERS_PATH)/timer.c $(DRIVERS_PATH)/qspi.c $(DRIVERS_PATH)/dram.c

ifeq ($(USE_COREMARK), 1)
	LINKER_SCRIPT := coremark/riscv32-baremetal/link.ld
	START_ASM := coremark/riscv32-baremetal/crt0.S
	DRIVERS += coremark/riscv32-baremetal/syscalls.c coremark/riscv32-baremetal/ee_printf.c
endif

CFLAGS ?= -O2 -mcmodel=medany -static -std=gnu99 -fno-common -fno-unroll-loops -nostdlib -nostartfiles -fno-builtin -ffunction-sections -lm -lgcc -T $(LINKER_SCRIPT) -march=rv32im -mabi=ilp32 -I$(COMMON_PATH) -I$(DRIVERS_PATH)

ifeq ($(USE_COREMARK), 1)
	CFLAGS += -Icoremark -Icoremark/riscv32-baremetal -DITERATIONS=2000 -DUSE_COREMARK_UTILS
endif

CFILE ?= demo
CPATH ?= $(CFILE)/$(CFILE)

SRCS ?= $(CPATH).c $(DRIVERS) $(START_ASM)

OUTNAME ?= $(CPATH).riscv

ifeq ($(ASM), 1)
	SRCS := $(CPATH).S
	CFLAGS := -nostartfiles -nostdlib -march=rv32im -mabi=ilp32 -T $(COMMON_PATH)/link_asm.ld
endif

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
