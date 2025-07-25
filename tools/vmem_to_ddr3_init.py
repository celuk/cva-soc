import argparse
import sys
from collections import OrderedDict

def convert_vmem_to_mem_init(input_file, output_file):
    memory = OrderedDict()
    current_address = None

    try:
        with open(input_file, 'r') as f_in:
            for line in f_in:
                line = line.strip()
                if not line:
                    continue

                if line.startswith('@'):
                    try:
                        current_address = int(line[1:], 16) - 0x80000000
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
        description="Convert a Verilog .vmem file to a mem_init.txt file for the DDR3 model.",
        formatter_class=argparse.RawTextHelpFormatter
    )
    parser.add_argument(
        "-i", "--input",
        help="Path to the input .vmem file."
    )
    parser.add_argument(
        "-o", "--output",
        default="mem_init.txt",
        help="Path for the output file."
    )
    args = parser.parse_args()

    convert_vmem_to_mem_init(args.input, args.output)

if __name__ == "__main__":
    main()
