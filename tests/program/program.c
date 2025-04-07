#include "qspi.h"
#include "timer.h"
#include "uart.h"
#include "defines.h"

const unsigned int len_00000000 = 132; // Byte length
unsigned int mem_00000000[] = {
    0x00000013, 0x00000013, 0x00000013, 0x00000013,
    0x00000013, 0x00000013, 0x00000013, 0x00000013,
    0x00000013, 0x00000013, 0x00000013, 0x00000013,
    0x00000013, 0x00000013, 0x00000013, 0x00000013,
    0x00000013, 0x00000013, 0x00000013, 0x00000013,
    0x00000013, 0x00000013, 0x00000013, 0x00000013,
    0x00000013, 0x00000013, 0x00000013, 0x00000013,
    0x00000013, 0x00000013, 0x00000013, 0x0C80006F,
    0x0800006F,
};

const unsigned int len_00000100 = 2580; // Byte length
unsigned int mem_00000100[] = {
    0x00001117, 0x00010113, 0x00001317, 0xA8030313,
    0x00001397, 0xA9838393, 0x1040006F, 0x0000006F,
    0x00032023, 0x00430313, 0xFE63DCE3, 0x00000513,
    0x00000593, 0x00000097, 0xFCC08093, 0x0E00006F,
    0x0000006F, 0xFB010113, 0x04112623, 0x04812423,
    0x05010413, 0x04512223, 0x04612023, 0x02712E23,
    0x03C12C23, 0x03D12A23, 0x03E12823, 0x03F12623,
    0x02A12423, 0x02B12223, 0x02C12023, 0x00D12E23,
    0x00E12C23, 0x00F12A23, 0x01012823, 0x01112623,
    0x304022F3, 0x30002373, 0x341025F3, 0x00512023,
    0x00612223, 0x00B12423, 0x34202573, 0x34302673,
    0x04812683, 0xF8DFF0EF, 0x00012283, 0x00412303,
    0x00812383, 0x30429073, 0x30031073, 0x34139073,
    0x00C12883, 0x01012803, 0x01412783, 0x01812703,
    0x01C12683, 0x02012603, 0x02412583, 0x02812503,
    0x02C12F83, 0x03012F03, 0x03412E83, 0x03812E03,
    0x03C12383, 0x04012303, 0x04412283, 0x04812403,
    0x04C12083, 0x05010113, 0x30200073, 0xFF010113,
    0x00112623, 0x4A8000EF, 0x00001517, 0x94450513,
    0x06C000EF, 0x00C12083, 0x00000513, 0x01010113,
    0x00008067, 0xFF000737, 0x01072783, 0x0047F793,
    0xFE078CE3, 0x00008067, 0xFF010113, 0x00812423,
    0x00112623, 0x00050413, 0xFDDFF0EF, 0xFF0007B7,
    0x0107A703, 0x00C12083, 0xFFB77713, 0x00E7A823,
    0x0087A623, 0x0107A703, 0x00812403, 0x00176713,
    0x00E7A823, 0x01010113, 0xFADFF06F, 0xFF010113,
    0x00812423, 0x00112623, 0x00050413, 0x00044503,
    0x00051A63, 0x00C12083, 0x00812403, 0x01010113,
    0x00008067, 0x00140413, 0xF91FF0EF, 0xFE1FF06F,
    0xF9010113, 0x06F12223, 0x05410793, 0x04912223,
    0x05212023, 0x03312E23, 0x03412C23, 0x03512A23,
    0x03612823, 0x03712623, 0x03812423, 0x03912223,
    0x04112623, 0x04812423, 0x00050993, 0x04B12A23,
    0x04C12C23, 0x04D12E23, 0x06E12023, 0x07012423,
    0x07112623, 0x00F12423, 0x00000C93, 0x00000C13,
    0x00000493, 0x02500A93, 0x00A00913, 0x03900B13,
    0x00001B97, 0x83CB8B93, 0x00000A17, 0x7CCA0A13,
    0x0009C403, 0x00198993, 0x02041C63, 0x04C12083,
    0x04812403, 0x04412483, 0x04012903, 0x03C12983,
    0x03812A03, 0x03412A83, 0x03012B03, 0x02C12B83,
    0x02812C03, 0x02412C83, 0x07010113, 0x00008067,
    0x18048C63, 0x028B6063, 0x02F00793, 0xFA87EAE3,
    0x000B8513, 0x1640006F, 0x00048C13, 0x00000C93,
    0xFA1FF06F, 0xF9D40413, 0x0FF47413, 0x01500793,
    0xFE87E0E3, 0x00241413, 0x01440433, 0x00042783,
    0x014787B3, 0x00078067, 0x00812783, 0x00478713,
    0x00E12423, 0x0007A483, 0x000C0663, 0x01C00413,
    0x00C0006F, 0x00400413, 0xFE0C8AE3, 0x00900C13,
    0x0084D7B3, 0x00F7F713, 0x05770513, 0x00EC4463,
    0x03070513, 0xFFC40413, 0xE41FF0EF, 0xFE0452E3,
    0x00000C93, 0x00000C13, 0x00000493, 0xF25FF06F,
    0x00812783, 0x0007A483, 0x00478793, 0x00F12423,
    0x0004D863, 0x02D00513, 0x409004B3, 0xE0DFF0EF,
    0x00048413, 0x00100C13, 0x03244433, 0x04041463,
    0xFFFC0793, 0xFFF00693, 0x00C10713, 0x00F70633,
    0x0324E733, 0xFFF78793, 0x03070713, 0x00E60023,
    0x0324C4B3, 0xFED792E3, 0x00C10793, 0x008787B3,
    0x0007C503, 0x00140413, 0xDC1FF0EF, 0xFE8C16E3,
    0xF81FF06F, 0x001C0C13, 0xFB1FF06F, 0x00812703,
    0x00100413, 0x00072783, 0x00470713, 0x00E12423,
    0x00078493, 0x0327C7B3, 0x02079463, 0xFFF40413,
    0xFFF00C13, 0x0324F533, 0xFFF40413, 0x03050513,
    0xD79FF0EF, 0x0324D4B3, 0xFF8416E3, 0xF35FF06F,
    0x00140413, 0xFD1FF06F, 0x00812783, 0x0007A503,
    0x00478713, 0x00E12423, 0xD95FF0EF, 0xF15FF06F,
    0x00812783, 0x0007C503, 0x00478713, 0x00E12423,
    0xD39FF0EF, 0xEFDFF06F, 0x03540263, 0x00040513,
    0xD29FF0EF, 0xE1241EE3, 0x00D00513, 0xD1DFF0EF,
    0xE11FF06F, 0x00048C93, 0xEDDFF06F, 0x00100493,
    0xE01FF06F, 0xFF0007B7, 0x0107A503, 0x00155513,
    0x00154513, 0x00157513, 0x00008067, 0xFF010113,
    0x00112623, 0xFE1FF0EF, 0xFE051EE3, 0xFF0007B7,
    0x0087A503, 0x0107A703, 0x00C12083, 0x0FF57513,
    0xFFD77713, 0x00E7A823, 0x01010113, 0x00008067,
    0xFD010113, 0x02812423, 0x02912223, 0x01312E23,
    0x01412C23, 0x01512A23, 0x01612823, 0x01712623,
    0x01812423, 0x02112623, 0x03212023, 0x00050413,
    0x00060993, 0x00000493, 0x00800A93, 0x00D00B13,
    0x05E00B93, 0xFFF58A13, 0x00000C17, 0x598C0C13,
    0xF7DFF0EF, 0x00050913, 0x03551063, 0xFE048AE3,
    0x00098663, 0x000C0513, 0xC95FF0EF, 0xFFF40413,
    0xFFF48493, 0xFDDFF06F, 0x03650663, 0xFE050793,
    0x0FF7F793, 0xFCFBE6E3, 0xFD44D4E3, 0x00098463,
    0xC29FF0EF, 0x01240023, 0x00148493, 0x00140413,
    0xFB1FF06F, 0x00040023, 0x00000517, 0x53C50513,
    0xC4DFF0EF, 0x02C12083, 0x02812403, 0x02012903,
    0x01C12983, 0x01812A03, 0x01412A83, 0x01012B03,
    0x00C12B83, 0x00812C03, 0x00048513, 0x02412483,
    0x03010113, 0x00008067, 0x00054703, 0x00150513,
    0x00158593, 0xFFF5C783, 0x00071663, 0x40F00533,
    0x00008067, 0xFEF702E3, 0x40F70533, 0x00008067,
    0x00050793, 0x0007C703, 0x00071663, 0x40A78533,
    0x00008067, 0x00178793, 0xFEDFF06F, 0xFF0007B7,
    0x0107A703, 0x00776713, 0x00E7A823, 0x0D900713,
    0x00E7A023, 0x0047A703, 0x00176713, 0x00E7A223,
    0x00008067, 0x00A00513, 0x4000006F, 0x00A61613,
    0x00859593, 0x3005F593, 0x40067613, 0x00B66633,
    0x000105B7, 0x00B69693, 0xFFF58593, 0x00B6F6B3,
    0x00D66633, 0x01071713, 0x01FF06B7, 0x00D77733,
    0x00E66633, 0x01979793, 0x7E000737, 0x00E7F7B3,
    0x00F66633, 0x01F81813, 0x01066633, 0x0FF57513,
    0x00A66633, 0xFF0107B7, 0x00C7A023, 0x00008067,
    0xFF010737, 0x02872783, 0x0027F793, 0xFE079CE3,
    0x00008067, 0x020007B7, 0xFF010113, 0x10078793,
    0x0FF57513, 0x00812423, 0x00112623, 0x00F56533,
    0xFF010437, 0x00A42023, 0xFC9FF0EF, 0x00842503,
    0x00C12083, 0x00812403, 0x01010113, 0x00008067,
    0xFF010113, 0x00112623, 0x00500513, 0xFB9FF0EF,
    0x00257513, 0xFE050AE3, 0x00C12083, 0x01010113,
    0x00008067, 0xFF010113, 0x00112623, 0x00500513,
    0xF95FF0EF, 0x00257513, 0xFE051AE3, 0x00C12083,
    0x01010113, 0x00008067, 0xFF010113, 0x00112623,
    0x00500513, 0xF71FF0EF, 0x00157513, 0xFE051AE3,
    0x00C12083, 0x01010113, 0x00008067, 0xFF010113,
    0x00100813, 0x00100793, 0x00000713, 0x00000693,
    0x00000613, 0x00100593, 0x00600513, 0x00112623,
    0xEBDFF0EF, 0xF1DFF0EF, 0xF69FF0EF, 0xFF0107B7,
    0x20000713, 0x00100813, 0x00000693, 0x00100613,
    0x00100593, 0x00100513, 0x00E7A423, 0x00100793,
    0x00100713, 0xE89FF0EF, 0xEE9FF0EF, 0xF7DFF0EF,
    0x00100813, 0x00100793, 0x00000713, 0x00000693,
    0x00000613, 0x00100593, 0x00400513, 0xE61FF0EF,
    0xEC1FF0EF, 0x00C12083, 0x01010113, 0xF29FF06F,
    0xFF010113, 0x00100813, 0x00100793, 0x00000713,
    0x00000693, 0x00000613, 0x00100593, 0x00600513,
    0x00112623, 0xE29FF0EF, 0xE89FF0EF, 0xED5FF0EF,
    0xFF0107B7, 0x00100813, 0x00100713, 0x00000693,
    0x00100613, 0x00100593, 0x00100513, 0x0007A423,
    0x00100793, 0xDF9FF0EF, 0xE59FF0EF, 0xEEDFF0EF,
    0x00100813, 0x00100793, 0x00000713, 0x00000693,
    0x00000613, 0x00100593, 0x00400513, 0xDD1FF0EF,
    0xE31FF0EF, 0x00C12083, 0x01010113, 0xE99FF06F,
    0xFF010113, 0x00112623, 0x00812423, 0xFF010437,
    0x00A42223, 0x00100793, 0x06B00513, 0x00100813,
    0x01F00713, 0x00800693, 0x00000613, 0x00300593,
    0xD8DFF0EF, 0xDEDFF0EF, 0x00842783, 0x00000517,
    0x20C50513, 0x00C12083, 0x00F52023, 0x00C42783,
    0x00F52223, 0x01042783, 0x00F52423, 0x01442783,
    0x00F52623, 0x01842783, 0x00F52823, 0x01C42783,
    0x00F52A23, 0x02042783, 0x00F52C23, 0x02442783,
    0x00812403, 0x00F52E23, 0x01010113, 0x00008067,
    0xFF0507B7, 0x00100713, 0x00E7A423, 0x00E7AE23,
    0x0007A023, 0xFFF00693, 0x00D7A223, 0x00E7A623,
    0x00E7A823, 0x0007AE23, 0x0007A423, 0x00008067,
    0xFF0507B7, 0x00A7A023, 0x00008067, 0xFF0507B7,
    0x0007A503, 0x00008067, 0xFF0507B7, 0x00A7A223,
    0x00008067, 0xFF0507B7, 0x0047A503, 0x00008067,
    0xFF0507B7, 0x00A7A423, 0x00008067, 0xFF0507B7,
    0x0087A503, 0x00008067, 0xFF0507B7, 0x00A7A623,
    0x00008067, 0xFF0507B7, 0x00C7A503, 0x00008067,
    0xFF0507B7, 0x00A7A823, 0x00008067, 0xFF0507B7,
    0x0107A503, 0x00008067, 0xFF0507B7, 0x0147A503,
    0x00008067, 0xFF0507B7, 0x0187A503, 0x00008067,
    0xFF0507B7, 0x00A7AE23, 0x00008067, 0xFF0507B7,
    0x01C7A503, 0x00008067, 0xFF010113, 0x00812423,
    0x00112623, 0x00050413, 0xF19FF0EF, 0xFF0507B7,
    0x0147A703, 0x0147A783, 0xFF050637, 0x40E787B3,
    0x0087EA63, 0x00C12083, 0x00812403, 0x01010113,
    0x00008067, 0x01462683, 0x40D707B3, 0xFED772E3,
    0x40E687B3, 0xFDDFF06F, 0x01900793, 0x02F50533,
    0xFA9FF06F, 0x00000000, 0x00000000, 0x00000000,
    0x00000000,
};

const unsigned int len_00000B14 = 116; // Byte length
unsigned int mem_00000B14[] = {
    0xFFFFF9FC, 0xFFFFF91C, 0xFFFFF88C, 0xFFFFF8C4,
    0xFFFFF88C, 0xFFFFFA30, 0xFFFFF88C, 0xFFFFF88C,
    0xFFFFF88C, 0xFFFFF894, 0xFFFFF88C, 0xFFFFF88C,
    0xFFFFF88C, 0xFFFFF88C, 0xFFFFF88C, 0xFFFFF88C,
    0xFFFFF9E4, 0xFFFFF88C, 0xFFFFF998, 0xFFFFF88C,
    0xFFFFF88C, 0xFFFFF8C4, 0x6C6C6548, 0x77202C6F,
    0x646C726F, 0x00000A21, 0x00000025, 0x00082008,
    0x0000000A,
};

void qspi_32byte_write(unsigned int* data, unsigned int addr){

    qspi_set_ccr(
        /*inst_value*/       CMD_WREN,
        /*data_mod*/         1,
        /*wr_flash*/         0,
        /*dummy_cycle*/      0,
        /*data_size*/        0,
        /*prescaler*/        1,
        /*clear_status_reg*/ 1
    );
    wait_for_not_busy();
    wait_for_wel_set();

    QSPI_DR0 = data[0];
    QSPI_DR1 = data[1];
    QSPI_DR2 = data[2];
    QSPI_DR3 = data[3];
    QSPI_DR4 = data[4];
    QSPI_DR5 = data[5];
    QSPI_DR6 = data[6];
    QSPI_DR7 = data[7];

    QSPI_ADR = addr;
    qspi_set_ccr(
        /*inst_value*/       CMD_QPP,
        /*data_mod*/         3,
        /*wr_flash*/         1,
        /*dummy_cycle*/      0,
        /*data_size*/        31,
        /*prescaler*/        1,
        /*clear_status_reg*/ 1
    );
    wait_for_not_busy();
    wait_for_wip_done();

    tekno_printf("Wrote 32 bytes to address: %x\n", addr);
}

void write_flash_data(void) {
    unsigned int zero_data[8] = {0}; // Buffer of zeros for filling gaps
    unsigned int temp_buffer[8]; // Temporary buffer for partial writes
    unsigned int addr, i, j;
    unsigned int bytes_written;
    
    // Calculate the number of 32-byte chunks needed for each array
    unsigned int chunks_00000000 = (len_00000000 + 31) / 32; // Round up division
    unsigned int chunks_00000100 = (len_00000100 + 31) / 32;
    unsigned int chunks_00000B14 = (len_00000B14 + 31) / 32;
    
    // First array - 0x00000000
    addr = 0x00000000;
    bytes_written = 0;
    
    for (i = 0; i < chunks_00000000; i++) {
        // Check if we have a full chunk
        if (bytes_written + 32 <= len_00000000) {
            // Write a full chunk
            qspi_32byte_write(&mem_00000000[i * 8], addr);
            bytes_written += 32;
        } else {
            // Handle partial chunk (last chunk might not be complete)
            unsigned int remaining = len_00000000 - bytes_written;
            unsigned int words_to_copy = (remaining + 3) / 4; // Number of whole words
            
            // Clear temp buffer
            for (j = 0; j < 8; j++) {
                temp_buffer[j] = 0;
            }
            
            // Copy remaining data
            for (j = 0; j < words_to_copy; j++) {
                temp_buffer[j] = mem_00000000[i * 8 + j];
            }
            
            qspi_32byte_write(temp_buffer, addr);
            bytes_written += remaining;
        }
        
        addr += 32;
    }
    
    // Fill gap between first and second array
    // Gap between 0x00000000+(len_00000000) and 0x00000100
    unsigned int end_addr_first = (chunks_00000000 * 32); // End address after writing first array
    unsigned int start_addr_second = 0x00000100; // Start address of second array
    
    // Calculate how many 32-byte chunks we need to fill the gap
    if (end_addr_first < start_addr_second) {
        unsigned int gap_size = start_addr_second - end_addr_first;
        unsigned int gap_chunks = gap_size / 32;
        
        // Fill the gap with zeros
        for (i = 0; i < gap_chunks; i++) {
            qspi_32byte_write(zero_data, end_addr_first + (i * 32));
        }
    }
    
    // Second array - 0x00000100
    addr = 0x00000100;
    bytes_written = 0;
    
    for (i = 0; i < chunks_00000100; i++) {
        // Check if we have a full chunk
        if (bytes_written + 32 <= len_00000100) {
            // Write a full chunk
            qspi_32byte_write(&mem_00000100[i * 8], addr);
            bytes_written += 32;
        } else {
            // Handle partial chunk
            unsigned int remaining = len_00000100 - bytes_written;
            unsigned int words_to_copy = (remaining + 3) / 4;
            
            // Clear temp buffer
            for (j = 0; j < 8; j++) {
                temp_buffer[j] = 0;
            }
            
            // Copy remaining data
            for (j = 0; j < words_to_copy; j++) {
                temp_buffer[j] = mem_00000100[i * 8 + j];
            }
            
            qspi_32byte_write(temp_buffer, addr);
            bytes_written += remaining;
        }
        
        addr += 32;
    }
    
    // Fill gap between second and third array
    // Gap between 0x00000100+(len_00000100) and 0x00000B14
    unsigned int end_addr_second = 0x00000100 + ((chunks_00000100 * 32) > len_00000100 ? 
                                              (chunks_00000100 * 32) : len_00000100);
    unsigned int start_addr_third = 0x00000B14;
    
    // Calculate how many 32-byte chunks we need to fill the gap
    if (end_addr_second < start_addr_third) {
        unsigned int gap_size = start_addr_third - end_addr_second;
        unsigned int gap_chunks = gap_size / 32;
        
        // Fill the gap with zeros
        for (i = 0; i < gap_chunks; i++) {
            qspi_32byte_write(zero_data, end_addr_second + (i * 32));
        }
    }
    
    // Third array - 0x00000B14
    addr = 0x00000B14;
    bytes_written = 0;
    
    for (i = 0; i < chunks_00000B14; i++) {
        // Check if we have a full chunk
        if (bytes_written + 32 <= len_00000B14) {
            // Write a full chunk
            qspi_32byte_write(&mem_00000B14[i * 8], addr);
            bytes_written += 32;
        } else {
            // Handle partial chunk
            unsigned int remaining = len_00000B14 - bytes_written;
            unsigned int words_to_copy = (remaining + 3) / 4;
            
            // Clear temp buffer
            for (j = 0; j < 8; j++) {
                temp_buffer[j] = 0;
            }
            
            // Copy remaining data
            for (j = 0; j < words_to_copy; j++) {
                temp_buffer[j] = mem_00000B14[i * 8 + j];
            }
            
            qspi_32byte_write(temp_buffer, addr);
            bytes_written += remaining;
        }
        
        addr += 32;
    }
}

int main() {

    init_uart();

    tekno_printf("QSPI write started\n");

    wait_for_us(500);

    qspi_set_ccr(
        /*inst_value*/       CMD_RESET,
        /*data_mod*/         1,
        /*wr_flash*/         0,
        /*dummy_cycle*/      0,
        /*data_size*/        0,
        /*prescaler*/        1,
        /*clear_status_reg*/ 1
    );
    wait_for_not_busy();

    wait_for_us(500);

    qspi_enable_quad_mode();

    //QSPI_DR0 = 0xbbbbbbbb;
    //QSPI_DR1 = 0xbbbbbbbb;
    //QSPI_DR2 = 0xbbbbbbbb;
    //QSPI_DR3 = 0xbbbbbbbb;
    //QSPI_DR4 = 0xbbbbbbbb;
    //QSPI_DR5 = 0xbbbbbbbb;
    //QSPI_DR6 = 0xbbbbbbbb;
    //QSPI_DR7 = 0xbbbbbbbb;
//
    //QSPI_ADR = 0x00000000;
    //qspi_set_ccr(
    //    /*inst_value*/       CMD_QPP,
    //    /*data_mod*/         3,
    //    /*wr_flash*/         1,
    //    /*dummy_cycle*/      0,
    //    /*data_size*/        31,
    //    /*prescaler*/        1,
    //    /*clear_status_reg*/ 1
    //);
    //wait_for_not_busy();
    //wait_for_wip_done();

    //qspi_set_ccr(
    //    /*inst_value*/       CMD_WRDI,
    //    /*data_mod*/         1,
    //    /*wr_flash*/         0,
    //    /*dummy_cycle*/      0,
    //    /*data_size*/        0,
    //    /*prescaler*/        1,
    //    /*clear_status_reg*/ 1
    //);
    //wait_for_not_busy();
    //wait_for_wel_down();

    write_flash_data();
    
    tekno_printf("QSPI write done\n");

    return 0;
}
