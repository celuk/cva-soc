#include <stdint.h>
#include "timer.h"

#define DDR3_AXI_BASE_ADDR 0x80000000

void init()
{
    init_timer();
    wait_for_us(500);
}

static inline void update_trap_vector_base_address()
{
    asm volatile (
        "li    t0, 0x80000000 \n"
        "csrrw t0, mtvec,  t0 \n"
    );
}

static inline void jump_to_dram()
{
    asm volatile (
        //"lui   t0, 0x80000 \n"
        //"addi  t0, t0, 0x100 \n"
        "li    t0, 0x80001000 \n"
        "jalr  x0, t0, 0 \n"
    );
}

struct fw_dynamic_info {
    unsigned int magic;
    unsigned int version;
    unsigned int next_addr;
    unsigned int next_mode;
    unsigned int options;
    unsigned int boot_hart;
};

#define OPENSBI_BASE_ADDR DDR3_AXI_BASE_ADDR //0x80000000

#define FW_DYNAMIC_INFO_MAGIC_VALUE 0x4942534f
#define FW_DYNAMIC_INFO_VERSION_2 0x2
#define FW_DYNAMIC_INFO_VERSION_MAX FW_DYNAMIC_INFO_VERSION_2
#define FW_DYNAMIC_INFO_NEXT_MODE_U 0x0
#define FW_DYNAMIC_INFO_NEXT_MODE_S 0x1
#define FW_DYNAMIC_INFO_NEXT_MODE_M 0x3
#define FW_DYNAMIC_NEXT_ADDRESS_OFFSET 0x00100000
#define FW_DYNAMIC_NEXT_ADDRESS (OPENSBI_BASE_ADDR + FW_DYNAMIC_NEXT_ADDRESS_OFFSET) //0x90000000

#define BOOT_HART_ID 0x0

#define DTB_ADDRESS (OPENSBI_BASE_ADDR + 0xd000) // fw_fdt_bin (compiled dts - dtb file) address

static inline void opensbi_init()
{
    static struct fw_dynamic_info dynamic_info;
    dynamic_info.magic = FW_DYNAMIC_INFO_MAGIC_VALUE;
    dynamic_info.version = FW_DYNAMIC_INFO_VERSION_MAX;
    dynamic_info.next_addr = FW_DYNAMIC_NEXT_ADDRESS;
    dynamic_info.next_mode = FW_DYNAMIC_INFO_NEXT_MODE_S;
    dynamic_info.options = 0x00000000;
    dynamic_info.boot_hart = BOOT_HART_ID;

    unsigned int hart_id;
	__asm__ volatile("csrr %0, mhartid" : "=r"(hart_id));

    __asm__ volatile (
        "mv a0, %[hart_id]\n"
        "mv a1, %[dtb_addr]\n"
        "mv a2, %[info_addr]\n"
        "li t0, %[entry]\n"
        "jalr x0, t0, 0\n"
        :
        : [hart_id]"r"(hart_id),
          [dtb_addr]"r"(DTB_ADDRESS),
          [info_addr]"r"(&dynamic_info),
          [entry]"i"(OPENSBI_BASE_ADDR)
        : "a0", "a1", "a2", "t0"
    );
}

int main()
{
    init();

    //update_trap_vector_base_address();
    opensbi_init();
    //jump_to_dram();
    return 0;
}
