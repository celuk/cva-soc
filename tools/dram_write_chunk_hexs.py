import serial
import time
import argparse

def modify_hex(hex_code, new_base_address, new_offset, new_value):
    instructions = hex_code.split()
    
    final_address = new_base_address + new_offset
    
    # Handle value splitting for LUI + ADDI (same logic as compiler)
    value_lower = new_value & 0xFFF
    value_upper = new_value >> 12
    if value_lower & 0x800:  # If bit 11 is set, ADDI will sign extend
        value_upper += 1     # Compensate by adding 1 to upper part
    
    # Handle address splitting for LUI + SW offset  
    addr_lower = final_address & 0xFFF
    addr_upper = final_address >> 12
    if addr_lower & 0x800:  # If bit 11 is set, SW offset will sign extend
        addr_upper += 1     # Compensate by adding 1 to upper part
    
    # Ensure values fit in instruction fields and handle overflow
    value_upper &= 0xFFFFF  # 20-bit limit for LUI
    addr_upper &= 0xFFFFF   # 20-bit limit for LUI
    
    # Sign extend lower parts for instruction encoding
    if value_lower & 0x800:
        value_lower |= 0xFFFFF000
    if addr_lower & 0x800:
        addr_lower |= 0xFFFFF000
    
    instructions[0] = f"{(0x37 | (15 << 7) | (value_upper << 12)):08X}"
    instructions[1] = f"{(0x37 | (14 << 7) | (addr_upper << 12)):08X}"
    instructions[2] = f"{(0x13 | (15 << 7) | (15 << 15) | ((value_lower & 0xFFF) << 20)):08X}"
    instructions[3] = f"{(0x23 | (2 << 12) | (14 << 15) | (15 << 20) | ((addr_lower & 0x1F) << 7) | (((addr_lower >> 5) & 0x7F) << 25)):08X}"
    
    return ' '.join(instructions)

def send_hex_chunk(ser, header_hex, hex_chunk, program_sequence):
    hex_chunk = header_hex + hex_chunk
    lines = hex_chunk.split()
    
    ser.write(program_sequence.encode('utf-8'))
    prog_size = hex(len(lines))
    prog_size = int(prog_size, 16).to_bytes(4, 'big')
    ser.write(prog_size)
    
    hex_bytes = bytes.fromhex(hex_chunk.replace(' ', '').replace('\n', '').replace('\r', '').replace('\t', '').upper())
    ser.write(hex_bytes)
    #try:
    #    clean_hex = hex_chunk.replace(' ', '').replace('\n', '').replace('\r', '').replace('\t', '').upper()
    #    if not all(c in '0123456789ABCDEF' for c in clean_hex):
    #        print(f"Invalid hex characters found in: {hex_chunk}")
    #        return
    #    hex_bytes = bytes.fromhex(clean_hex)
    #    ser.write(hex_bytes)
    #except ValueError as e:
    #    print(f"Hex conversion error: {e}")
    #    print(f"Problematic hex chunk: {hex_chunk}")
    #    return

def send_hex_file(ser, hex_file_path, header_hex, original_hex, new_base_address, program_sequence):
    with open(hex_file_path, 'r') as f:
        hex_data = f.read().replace('\n', '').replace(' ', '')
    
    words = [hex_data[i:i+8] for i in range(0, len(hex_data), 8)]
    
    for i, word in enumerate(words):
        if len(word) == 8:
            new_offset = i * 0x4
            new_value = int(word, 16)
            
            modified_hex = modify_hex(original_hex, new_base_address, new_offset, new_value)
            send_hex_chunk(ser, header_hex, modified_hex, program_sequence)
            time.sleep(0.1)

parser = argparse.ArgumentParser()
parser.add_argument("--file", '-f', type=str, default="./tests/qspi_demo/qspi_demo.hex", help="File to send")
parser.add_argument("--port", '-p', type=str, default="/dev/ttyUSB1", required=False, help="Serial port to use")
parser.add_argument("--baud_rate", '-b', type=int, default=115200, help="Baud rate to use")
parser.add_argument("--program_sequence", '-ps', type=str, default="SECURESOC", help="Program sequence to send")

args = parser.parse_args()

ser = serial.Serial(args.port, args.baud_rate)

header_hex = """
00000013
00000013
00000013
00000013
00000013
00000013
00000013
00000013
00000013
00000013
00000013
00000013
00000013
00000013
00000013
00000013
00000013
00000013
00000013
00000013
00000013
00000013
00000013
00000013
00000013
00000013
00000013
00000013
00000013
00000013
00000013
0C80006F
0800006F
00000000
00000000
00000000
00000000
00000000
00000000
00000000
00000000
00000000
00000000
00000000
00000000
00000000
00000000
00000000
00000000
00000000
00000000
00000000
00000000
00000000
00000000
00000000
00000000
00000000
00000000
00000000
00000000
00000000
00000000
00000000
"""

original_hex = original_hex = """
DEADC7B7
92345737
EEF78793
12F72423
00000513
00008067
"""
#old_base_address = 0x80000000
#old_offset = 0x12345128
#old_value = 0xDEADBEEF

new_base_address = 0x80000000

send_hex_file(ser, args.file, header_hex, original_hex, new_base_address, args.program_sequence)
ser.close()
