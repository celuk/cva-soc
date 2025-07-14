`define COMMON_CELLS_ASSERTS_OFF 1
`define ASSERTS_OFF 1

`define TARGET_SYNTHESIS

//`define PITON_ARIANE 1

`define COREV_PULP 1'b0
`define COREV_CLUSTER 1'b0
`define FPU 1'b0
`define FPU_ADDMUL_LAT 1'b0
`define FPU_OTHERS_LAT 1'b0
`define ZFINX 1'b0
`define NUM_MHPMCOUNTERS 1'b1

`define BOOT_ADDR 32'h0000_0080 //32'h00000180
`define MTVEC_ADDR 32'h0
`define DM_HALT_ADDR 32'h0000_0000 //32'h1A110800

`define PULP_CLOCK_EN 1'b0
`define SCAN_CG_EN 1'b0

`define HART_ID 32'h0
`define DM_EXCEPTION_ADDR 32'h0

`define CPU_CLK 50_000_000
`define BAUD_RATE 115200

// Cache sizes must be multiple of 64 --> e.g. 0, 64, 128, 256, ...
`define ICACHE_SZ 0
`define DCACHE_SZ 0
`define MEM_W 32
`define ICACHE_LINE_W 64
`define DCACHE_LINE_W 64
`define ICACHE_WAY_LEN `ICACHE_SZ / (`ICACHE_LINE_W / 8) / 2
`define DCACHE_WAY_LEN `DCACHE_SZ / (`DCACHE_LINE_W / 8) / 2

`define RAM_FPATH "" //"../../../tests/coremark/coremark_baremetal.hex" //"" //"../../../tests/demo/demo.hex" //"../../../tests/coremark/coremark_baremetal.hex" //"../../../tests/qspi_demo/qspi_demo.hex"
`define RAM_SIZE 'h2F00 //'h3200 //131072 //32'h0002_0000 //131072 //256 * 1024

`define MEM_BASE_ADDR   32'h0000_0000
`define MEM_RANGE       32'h0F00_0000

`define USE_BOOTROM 1

//`define BASYS3
//`define EXT_FLASH
//`define QSPI_SIM

//`define DDR_100MHZ

//`define ZC706
`define DDR3_AXI
`define DDR_MHZ 50
//`define DRAM_SIM
`define USE_SRAM

/*
PERIPHERALS
0xFF000000 = UART  = 11111111000000000000000000000000
0xFF010000 = QSPI  = 11111111000000010000000000000000
0xFF020000 = I2C   = 11111111000000100000000000000000
0xFF030000 = GPIO  = 11111111000000110000000000000000
0xFF040000 = USB   = 11111111000001000000000000000000
0xFF050000 = TIMER = 11111111000001010000000000000000
0xFF060000 = JTAG  = 11111111000001100000000000000000
*/

`define UART_BASE_ADDR  32'hFF00_0000
`define UART_RANGE      32'h0000_FFFF
`define QSPI_BASE_ADDR  32'hFF01_0000
`define QSPI_RANGE      32'h0000_FFFF
`define TIMER_BASE_ADDR 32'hFF05_0000
`define TIMER_RANGE     32'h0000_FFFF
//`define DRAM_BASE_ADDR  32'hFF07_0000
//`define DRAM_RANGE      32'h0000_FFFF

// https://github.com/pulp-platform/clint
// BASE + 0x0	msip	Machine mode software interrupt (IPI)
// BASE + 0x4000	mtimecmp	Machine mode timer compare register for Hart 0
// BASE + 0xBFF8	mtime	Timer register
`define CLINT_BASE_ADDR 32'hFF08_0000
`define CLINT_RANGE     32'h0000_FFFF

`define DRAM_BASE_ADDR  32'h8000_0000
`define DRAM_RANGE      32'h7F00_0000

`define DDR3_AXI_BASE_ADDR 32'h8000_0000
`define DDR3_AXI_RANGE     32'h7F00_0000 //32'h1F00_0000
