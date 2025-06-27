def modify_hex(hex_code, new_base_address, new_offset, new_value):
    instructions = hex_code.split()
    
    final_address = new_base_address + new_offset
    
    value_upper = (new_value >> 12) & 0xFFFFF
    if new_value & 0x800:
        value_upper += 1
    value_lower = new_value & 0xFFF
    if value_lower & 0x800:
        value_lower |= 0xFFFFF000
    
    addr_upper = (final_address >> 12) & 0xFFFFF
    if final_address & 0x800:
        addr_upper += 1
    addr_lower = final_address & 0xFFF
    
    instructions[0] = f"{(0x37 | (15 << 7) | (value_upper << 12)):08X}"
    instructions[1] = f"{(0x37 | (14 << 7) | (addr_upper << 12)):08X}"
    instructions[2] = f"{(0x13 | (15 << 7) | (15 << 15) | ((value_lower & 0xFFF) << 20)):08X}"
    instructions[3] = f"{(0x23 | (2 << 12) | (14 << 15) | (15 << 20) | ((addr_lower & 0x1F) << 7) | (((addr_lower >> 5) & 0x7F) << 25)):08X}"
    
    return '\n'.join(instructions)

original_hex = """
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
new_offset = 0x2F456234
new_value = 0xABCD1234

modified_hex = modify_hex(original_hex, new_base_address, new_offset, new_value)
print(modified_hex)
