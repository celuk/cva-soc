#include <stdint.h>
#include "timer.h"

static const unsigned int start_address = 0x00000000;
static const unsigned int data[] = {
    0x81000737,
    0x20234285,
    0x42A10057,
    0x810015B7,
    0x0055A023,
    0x24234291,
    0x02930057,
    0x2623FF00,
    0x02930057,
    0x28230FF0,
    0x02930057,
    0x2A23F000,
    0x05130057,
    0x06130007,
    0x06930087,
    0x43090107,
    0x086523AF,
    0x99634285,
    0x2E030E53,
    0x42890005,
    0x0E5E1463,
    0x23AF430D,
    0x42890065,
    0x0C539E63,
    0x00052E03,
    0x19634295,
    0x43310C5E,
    0x206523AF,
    0x93634295,
    0x2E030C53,
    0x42A50005,
    0x0A5E1E63,
    0x23AF430D,
    0x42A56065,
    0x0A539863,
    0x00052E03,
    0x13634285,
    0x43290A5E,
    0x406523AF,
    0x9D634285,
    0x2E030853,
    0x42AD0005,
    0x085E1863,
    0x1005A32F,
    0xA3AF0305,
    0x91631865,
    0xAE030803,
    0x42A50005,
    0x065E1C63,
    0x23AF537D,
    0x42918066,
    0x06539663,
    0x00062E03,
    0x116352FD,
    0x4329065E,
    0x00460E93,
    0xA06EA3AF,
    0x996352C1,
    0xAE030453,
    0x42A9000E,
    0x045E1463,
    0x0C800313,
    0xC066A3AF,
    0x0FF00293,
    0x02539C63,
    0x0006AE03,
    0x0C800293,
    0x025E1663,
    0x00010337,
    0xFFF30313,
    0x00468E93,
    0xE06EA3AF,
    0xF0000293,
    0x00539A63,
    0x000EAE03,
    0xF0000293,
    0x005E1463,
    0xA001A009,
    0x0000A001,
    0xFFFFFFFF
};

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
    
    for (int i = 0; i < sizeof(data)/sizeof(data[0]); i++) {
        (*((volatile unsigned int*)(DDR3_AXI_BASE_ADDR + start_address + i*4))) = data[i];
    }

    //update_trap_vector_base_address();
    opensbi_init();
    //jump_to_dram();
    return 0;
}
