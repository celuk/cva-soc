import argparse
import sys
from collections import OrderedDict

BASE_ADDRESS = 0x80000000
KERNEL_OFFSET = 0x00400000
DTB_OFFSET = 0x01400000

def convert_vmem_to_mem_init(input_files, output_file):
    memory = OrderedDict()

    for input_file, offset_type in input_files:
        current_address = None
        try:
            with open(input_file, 'r') as f_in:
                for line in f_in:
                    line = line.strip()
                    if not line:
                        continue

                    if line.startswith('@'):
                        try:
                            base_addr = int(line[1:], 16)
                            if offset_type == 'i':
                                current_address = base_addr - BASE_ADDRESS
                            elif offset_type == 'i2':
                                current_address = base_addr + KERNEL_OFFSET
                            elif offset_type == 'i3':
                                current_address = base_addr + DTB_OFFSET
                        except ValueError:
                            current_address = None
                    elif current_address is not None:
                        byte_values = line.split()
                        for byte_str in byte_values:
                            try:
                                memory[current_address] = int(byte_str, 16)
                                current_address += 1
                            except ValueError:
                                pass
        except FileNotFoundError:
            print(f"Error: Input file not found at {input_file}")
            sys.exit(1)

    if not memory:
        open(output_file, 'w').close()
        return

    with open(output_file, 'w') as f_out:
        start_addr = min(memory.keys())
        end_addr = max(memory.keys())

        aligned_start = start_addr & ~15

        for addr in range(aligned_start, end_addr + 16, 16):
            bytes_16 = []
            has_data = False
            for i in range(16):
                byte_addr = addr + i
                byte_val = memory.get(byte_addr, 0x00)
                bytes_16.append(byte_val)
                if byte_addr in memory:
                    has_data = True
            
            if has_data:
                bytes_16.reverse()
                hex_parts = [f"{byte:02X}" for byte in bytes_16]
                data_word = "".join(hex_parts)
                f_out.write(f"{addr:08X} {data_word}\n")

def main():
    parser = argparse.ArgumentParser(
        description="Convert Verilog .vmem files to a mem_init.txt file for the DDR3 model.",
        formatter_class=argparse.RawTextHelpFormatter
    )
    parser.add_argument(
        "-i", "--input",
        help="Path to the input .vmem file."
    )
    parser.add_argument(
        "-i2",
        help="Path to the vmlinux .vmem file."
    )
    parser.add_argument(
        "-i3",
        help="Path to the dtb .vmem file."
    )
    parser.add_argument(
        "-o", "--output",
        default="mem_init.txt",
        help="Path for the output file."
    )
    args = parser.parse_args()

    input_files = []
    if args.input:
        input_files.append((args.input, 'i'))
    if args.i2:
        input_files.append((args.i2, 'i2'))
    if args.i3:
        input_files.append((args.i3, 'i3'))

    if not input_files:
        print("Error: No input files provided. Use -i, -i2, or -i3.")
        sys.exit(1)

    convert_vmem_to_mem_init(input_files, args.output)

if __name__ == "__main__":
    main()
