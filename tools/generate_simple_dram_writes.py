import os
import subprocess
import argparse

WORDS_PER_FILE = 4096
START_ADDRESS_STEP = WORDS_PER_FILE * 4 #0x2000  # 2048 * 4
BUILD_DIR = "temp"

HEADER_TEMPLATE = """#include "uart.h"

static const unsigned int start_address = 0x{start_address:08X};

static const unsigned int data[] = {{
{data_lines}
}};
"""

TIMER_INIT_TEMPLATE = HEADER_TEMPLATE + """
#define DDR3_AXI_BASE_ADDR 0x80000000

#define CPU_MHZ 100
#define CPU_CLK (CPU_MHZ * 1000000)

#define US(x) (CPU_CLK/1000000 * x)

#define TIM_BASE_ADDR  0xFF050000
#define TIM_PRE_OFFSET 0x00
#define TIM_ARE_OFFSET 0x04
#define TIM_CLR_OFFSET 0x08
#define TIM_ENA_OFFSET 0x0C
#define TIM_MOD_OFFSET 0x10
#define TIM_CNT_OFFSET 0x14
#define TIM_EVC_OFFSET 0x1C

#define TIM_PRE (*((volatile unsigned int*) (TIM_BASE_ADDR + TIM_PRE_OFFSET)))
#define TIM_ARE (*((volatile unsigned int*) (TIM_BASE_ADDR + TIM_ARE_OFFSET)))
#define TIM_CLR (*((volatile unsigned int*) (TIM_BASE_ADDR + TIM_CLR_OFFSET)))
#define TIM_ENA (*((volatile unsigned int*) (TIM_BASE_ADDR + TIM_ENA_OFFSET)))
#define TIM_MOD (*((volatile unsigned int*) (TIM_BASE_ADDR + TIM_MOD_OFFSET)))
#define TIM_CNT (*((volatile unsigned int*) (TIM_BASE_ADDR + TIM_CNT_OFFSET)))
#define TIM_EVC (*((volatile unsigned int*) (TIM_BASE_ADDR + TIM_EVC_OFFSET)))

int main()
{{
    // init timer
    TIM_CLR = 1;
    TIM_EVC = 1;
    TIM_PRE = 0;
    TIM_ARE = 0xFFFFFFFF;
    TIM_ENA = 1;
    TIM_MOD = 1;
    TIM_EVC = 0;
    TIM_CLR = 0;

    // wait for 500 us
    unsigned int start = TIM_CNT;
    unsigned int end = TIM_CNT;
    unsigned int diff = end - start;
    while(((diff)) < US(500)){{
        end = TIM_CNT;
        if(end > start)
            diff = end - start;
        else
            diff = start - end;
    }}

    for (int i = 0; i < sizeof(data)/sizeof(data[0]); i++) {{
        (*((volatile unsigned int*)(DDR3_AXI_BASE_ADDR + start_address + i*4))) = data[i];
    }}

    init_uart();
    print("Done!");
    
    return 0;
}}
"""

SIMPLE_TEMPLATE = HEADER_TEMPLATE + """
#define DDR3_AXI_BASE_ADDR 0x80000000

int main()
{{
    for (int i = 0; i < sizeof(data)/sizeof(data[0]); i++) {{
        (*((volatile unsigned int*)(DDR3_AXI_BASE_ADDR + start_address + i*4))) = data[i];
    }}

    init_uart();
    print("Done!");
    
    return 0;
}}
"""

def read_hex_words(hex_file):
    with open(hex_file, 'r') as f:
        return [line.strip() for line in f if line.strip()]

def generate_files(hex_file):
    words = read_hex_words(hex_file)
    num_chunks = (len(words) + WORDS_PER_FILE - 1) // WORDS_PER_FILE

    os.makedirs(BUILD_DIR, exist_ok=True)
    generated_dirs = []

    for i in range(num_chunks):
        chunk = words[i * WORDS_PER_FILE : (i + 1) * WORDS_PER_FILE]
        if i == num_chunks - 1:
            chunk.append('FFFFFFFF')
            #chunk.append('00000000')
            #chunk.append('00000000')
        
        folder_name = f"simple_dram_write{i}"
        folder_path = os.path.join(BUILD_DIR, folder_name)
        os.makedirs(folder_path, exist_ok=True)

        start_address = i * START_ADDRESS_STEP
        data_lines = ',\n'.join([f"    0x{word.upper()}" for word in chunk])

        if i == 0:
            content = TIMER_INIT_TEMPLATE.format(start_address=start_address, data_lines=data_lines)
        else:
            content = SIMPLE_TEMPLATE.format(start_address=start_address, data_lines=data_lines)

        c_filename = f"{folder_name}.c"
        c_filepath = os.path.join(folder_path, c_filename)

        with open(c_filepath, 'w') as f:
            f.write(content)

        generated_dirs.append((folder_path, folder_name))

    return generated_dirs

def compile_files(generated_dirs):
    for folder_path, folder_name in generated_dirs:
        print(f"Compiling {folder_name} in {folder_path}...")
        subprocess.run(["make", "compiletemp", folder_name, "SIMPLE=1"])

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Generate and compile C files from a hex file.")
    parser.add_argument('--file', '-f', type=str, required=True, help='The input hex file')
    args = parser.parse_args()

    generated = generate_files(args.file)
    compile_files(generated)
