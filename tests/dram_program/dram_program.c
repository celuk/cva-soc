#include "dram.h"
#include "timer.h"
#include "uart.h"
#include "defines.h"

#include "gen_mem_blocks.h"

void write_all_dram_data(void) {
    unsigned int dram_buffer[4]; // Buffer for 16 bytes (4 words)

    if (NUM_MEMORY_BLOCKS == 0) {
        unsigned int signature_addr = 0; // Default address if no blocks

        dram_write_16bytes(signature_addr, 0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF);
        tekno_printf("FINAL: Wrote data %08x to address: %08x\n", 0xFFFFFFFF, signature_addr);
        tekno_printf("FINAL: Wrote data %08x to address: %08x\n", 0xFFFFFFFF, signature_addr + 4);
        tekno_printf("FINAL: Wrote data %08x to address: %08x\n", 0xFFFFFFFF, signature_addr + 8);
        tekno_printf("FINAL: Wrote data %08x to address: %08x\n", 0xFFFFFFFF, signature_addr + 12);
        return;
    }

    // Determine the overall address range to be written
    unsigned int min_addr_overall = memory_blocks[0].address;
    unsigned int max_addr_excl_overall = 0; // Exclusive end address

    for (int i = 0; i < NUM_MEMORY_BLOCKS; i++) {
        if (memory_blocks[i].address < min_addr_overall) {
            min_addr_overall = memory_blocks[i].address;
        }
        if ((memory_blocks[i].address + memory_blocks[i].length) > max_addr_excl_overall) {
            max_addr_excl_overall = memory_blocks[i].address + memory_blocks[i].length;
        }
    }

    // Handle cases where there are blocks but they are all empty or result in no range
    if (max_addr_excl_overall == 0 || max_addr_excl_overall <= min_addr_overall) {
        unsigned int signature_addr = (min_addr_overall & ~0xF); // Align to 16 bytes
        dram_write_16bytes(signature_addr, 0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF);
        tekno_printf("FINAL: Wrote data %08x to address: %08x\n", 0xFFFFFFFF, signature_addr);
        tekno_printf("FINAL: Wrote data %08x to address: %08x\n", 0xFFFFFFFF, signature_addr + 4);
        tekno_printf("FINAL: Wrote data %08x to address: %08x\n", 0xFFFFFFFF, signature_addr + 8);
        tekno_printf("FINAL: Wrote data %08x to address: %08x\n", 0xFFFFFFFF, signature_addr + 12);
        return;
    }
    
    unsigned int current_phys_addr;
    // Iterate over 16-byte aligned DRAM chunks covering the entire range
    for (current_phys_addr = (min_addr_overall & ~0xF); current_phys_addr < max_addr_excl_overall; current_phys_addr += 16) {
        // Initialize buffer to zeros (for gaps or padding within the 16-byte chunk)
        dram_buffer[0] = 0; dram_buffer[1] = 0; dram_buffer[2] = 0; dram_buffer[3] = 0;

        // Populate the 16-byte buffer by "painting" data from all relevant blocks.
        // Later blocks in the memory_blocks array will overwrite earlier ones if they overlap.
        for (int block_idx = 0; block_idx < NUM_MEMORY_BLOCKS; ++block_idx) {
            const memory_block_t* block = &memory_blocks[block_idx];
            if (block->length == 0) continue;

            unsigned int block_start_addr = block->address;
            unsigned int block_end_addr_excl = block->address + block->length;

            // Calculate overlap between the current block and the current 16-byte physical chunk
            unsigned int overlap_start_abs = (block_start_addr > current_phys_addr) ? block_start_addr : current_phys_addr;
            unsigned int overlap_end_abs_excl = (block_end_addr_excl < (current_phys_addr + 16)) ? block_end_addr_excl : (current_phys_addr + 16);

            if (overlap_start_abs < overlap_end_abs_excl) { // If there is an overlap
                for (unsigned int abs_addr = overlap_start_abs; abs_addr < overlap_end_abs_excl; ++abs_addr) {
                    unsigned int byte_offset_in_block_data = abs_addr - block_start_addr;
                    unsigned int byte_offset_in_chunk = abs_addr - current_phys_addr;
                    
                    // Get byte from block data (block->data is const unsigned int*, so cast to const unsigned char*)
                    unsigned char byte_value = ((const unsigned char*)block->data)[byte_offset_in_block_data];
                    // Place it in the buffer (dram_buffer is unsigned int[], cast to unsigned char*)
                    ((unsigned char*)dram_buffer)[byte_offset_in_chunk] = byte_value;
                }
            }
        }

        dram_write_16bytes(current_phys_addr, dram_buffer[0], dram_buffer[1], dram_buffer[2], dram_buffer[3]);

        // Logging per word
        for (int w = 0; w < 4; ++w) {
            unsigned int current_word_addr_abs = current_phys_addr + w * 4;
            unsigned int word_val = dram_buffer[w];
            
            int is_from_block = 0;
            // Check if this word is covered by any block's defined data region
            for (int k = 0; k < NUM_MEMORY_BLOCKS; ++k) {
                const memory_block_t* b = &memory_blocks[k];
                if (b->length == 0) continue;

                unsigned int block_start = b->address;
                unsigned int block_end_excl = b->address + b->length;
                
                // Check if the current word [current_word_addr_abs, current_word_addr_abs+3] overlaps with block
                if (current_word_addr_abs < block_end_excl && (current_word_addr_abs + 3) >= block_start) {
                    is_from_block = 1;
                    break;
                }
            }

            if (is_from_block) {
                tekno_printf("Wrote data %08x to address: %08x\n", word_val, current_word_addr_abs);
            } else {
                // This word is not within any block's specified [address, address+length).
                // It's a gap or padding for alignment. Print as "GAP" if it falls within the overall data footprint.
                if (current_word_addr_abs < max_addr_excl_overall && (current_word_addr_abs + 3) >= min_addr_overall) {
                    tekno_printf("GAP: Wrote data %08x to address: %08x\n", word_val, current_word_addr_abs);
                }
            }
        }
    }
    
    // After the loop, current_phys_addr is the start of the next 16-byte chunk
    // that is >= max_addr_excl_overall. This is where the final signature is written.
    // This is equivalent to ceil_align_16(max_addr_excl_overall).
    unsigned int final_signature_addr;
    if (max_addr_excl_overall == 0 && NUM_MEMORY_BLOCKS > 0 && min_addr_overall == 0) {
        // Special case: blocks exist but total length is 0, starting at address 0.
        // The main loop might not run if min_addr_overall (aligned) is not < max_addr_excl_overall (0).
        // current_phys_addr would be (min_addr_overall & ~0xF) which is 0.
        final_signature_addr = 0;
    } else {
        // In all other cases where the loop runs or would have run,
        // current_phys_addr holds the smallest 16-byte aligned address >= max_addr_excl_overall.
        final_signature_addr = current_phys_addr;
    }

    dram_write_16bytes(final_signature_addr, 0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF);
    tekno_printf("FINAL: Wrote data %08x to address: %08x\n", 0xFFFFFFFF, final_signature_addr);
    tekno_printf("FINAL: Wrote data %08x to address: %08x\n", 0xFFFFFFFF, final_signature_addr + 4);
    tekno_printf("FINAL: Wrote data %08x to address: %08x\n", 0xFFFFFFFF, final_signature_addr + 8);
    tekno_printf("FINAL: Wrote data %08x to address: %08x\n", 0xFFFFFFFF, final_signature_addr + 12);
}

int main() {
    init_uart();
    init_timer();

    tekno_printf("DRAM write started\n");

    wait_for_us(500);

    write_all_dram_data();
    
    tekno_printf("DRAM write done\n");

    return 0;
}
