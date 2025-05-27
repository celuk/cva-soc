import argparse
import os

def parse_demo_file(filename):
    with open(filename, "r") as f:
        lines = f.readlines()

    memory_blocks = {}
    current_address = None

    for line in lines:
        line = line.strip()
        if not line:
            continue
        if line.startswith('@'):
            current_address = line[1:]
            memory_blocks[current_address] = []
        else:
            bytes_list = line.split()
            memory_blocks[current_address].extend(bytes_list)

    return memory_blocks

def group_into_uint32(bytes_list):
    """Convert list of hex bytes into uint32 values (assuming little-endian)"""
    uint32_values = []
    
    for i in range(0, len(bytes_list), 4):
        # Make sure we have 4 bytes to process
        if i+3 < len(bytes_list):
            # RISC-V is little-endian, so the bytes are ordered from least significant to most significant
            byte0 = bytes_list[i]
            byte1 = bytes_list[i+1]
            byte2 = bytes_list[i+2]
            byte3 = bytes_list[i+3]
            
            # Combine the bytes into a single uint32 hex value
            uint32_value = f"{byte3}{byte2}{byte1}{byte0}"
            uint32_values.append(uint32_value)
    
    return uint32_values

def generate_c_arrays_print(memory_blocks):
    for addr, bytes_list in memory_blocks.items():
        uint32_values = group_into_uint32(bytes_list)
        array_name = f"mem_{addr}"
        len_name = f"len_{addr}"
        byte_length = len(bytes_list)
        
        print(f"const unsigned int {len_name} = {byte_length}; // Byte length")
        print(f"unsigned int {array_name}[] = {{")
        for i in range(0, len(uint32_values), 4):
            chunk = uint32_values[i:i+4]
            formatted = ", ".join(f"0x{v}" for v in chunk)
            print(f"    {formatted},")
        print("};\n")

def generate_c_arrays(memory_blocks, output_file):
    with open(output_file, "w") as f:
        for addr, bytes_list in memory_blocks.items():
            uint32_values = group_into_uint32(bytes_list)
            array_name = f"mem_{addr}"
            len_name = f"len_{addr}"
            byte_length = len(bytes_list)
            
            f.write(f"const unsigned int {len_name} = {byte_length}; // Byte length\n")
            f.write(f"unsigned int {array_name}[] = {{\n")
            for i in range(0, len(uint32_values), 4):
                chunk = uint32_values[i:i+4]
                formatted = ", ".join(f"0x{v}" for v in chunk)
                f.write(f"    {formatted},\n")
            f.write("};\n\n")

def generate_c_struct_arrays(memory_blocks, output_file):
    with open(output_file, "w") as f:
        # Write header with struct definition
        f.write("#ifndef MEMORY_BLOCKS_H\n")
        f.write("#define MEMORY_BLOCKS_H\n\n")
        
        f.write("// Memory block structure definition\n")
        f.write("typedef struct {\n")
        f.write("    unsigned int address;  // Start address of the memory block\n")
        f.write("    unsigned int length;   // Length in bytes\n")
        f.write("    const unsigned int* data; // Pointer to the data array\n")
        f.write("} memory_block_t;\n\n")
        
        # Write each data array
        block_names = []
        
        for addr, bytes_list in memory_blocks.items():
            # Convert address to proper format for C identifier
            addr_hex = addr  # Keep original for display/reference
            
            # Create array name based on address
            array_name = f"memory_data_0x{addr_hex}"
            block_names.append((addr_hex, array_name, len(bytes_list)))
            
            uint32_values = group_into_uint32(bytes_list)
            
            f.write(f"// Memory block for address 0x{addr_hex} (length: {len(bytes_list)} bytes)\n")
            f.write("static const unsigned int " + array_name + "[] = {\n")
            
            for i in range(0, len(uint32_values), 4):
                chunk = uint32_values[i:i+4]
                formatted = ", ".join(f"0x{v}" for v in chunk)
                f.write("    " + formatted + ",\n")
            
            f.write("};\n\n")
        
        # Find the base address (lowest address in the memory blocks)
        addresses = [int(addr, 16) for addr in memory_blocks.keys()]
        base_address = min(addresses) if addresses else 0

        # Write the block registry
        f.write("// Memory block registry\n")
        f.write("static const memory_block_t memory_blocks[] = {\n")
        
        for addr, array_name, length in block_names:
            # Subtract the base address from each address to start from 0
            relative_addr = hex(int(addr, 16) - base_address).rstrip('L')
            # Ensure proper formatting with leading zeros
            relative_addr = relative_addr[2:].zfill(8)  # Remove '0x' prefix and pad to 8 chars
            f.write(f"    {{ 0x{relative_addr}, {length}, {array_name} }},\n")
        
        f.write("};\n\n")
        
        # Write number of blocks macro
        f.write(f"#define NUM_MEMORY_BLOCKS {len(block_names)}\n\n")
        
        f.write("#endif // MEMORY_BLOCKS_H\n")

parser = argparse.ArgumentParser(description="Convert hex memory dump to c arrays")
parser.add_argument("--file", '-f', help="Path to the input file")
args = parser.parse_args()
memory_blocks = parse_demo_file(args.file)
base_dir = os.path.dirname(args.file)
output_file = os.path.join(os.path.dirname(base_dir), "common", "gen_mem_blocks.h")
generate_c_struct_arrays(memory_blocks, output_file)
