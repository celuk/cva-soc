import serial
import argparse
import os

parser = argparse.ArgumentParser(description="Send data to the UART")
parser.add_argument("--port", '-p', type=str, default="/dev/ttyUSB2", required=False, help="Serial port to use")
parser.add_argument("--baud_rate", '-b', type=int, default=921600, help="Baud rate to use")
parser.add_argument("--file", '-f', type=str, default="./tests/qspi_demo/qspi_demo.hex", help="File to send")
parser.add_argument("--file_format", '-ff', type=int, default=1, help="File format to send")
parser.add_argument("--program_sequence", '-ps', type=str, default="DRAMWRITE", help="Program sequence to send")
parser.add_argument("--start_address", '-sa', type=str, default="0x00000000", help="Start address for DRAM write")
args = parser.parse_args()
port = args.port
baud_rate = args.baud_rate
file = args.file
file_format = args.file_format
program_sequence = args.program_sequence
start_address = int(args.start_address, 16)

if file_format == 1:
    line_count = 0
    with open(file, 'r') as f:
        for line in f:
            if len(line.strip()) >= 8:
                line_count += 1
    
    ser = serial.Serial(port, baud_rate)
    ser.timeout = 1
    
    ser.write(program_sequence.encode('utf-8'))
    print(program_sequence)
    
    hex_str = hex(line_count)
    print ("Number of Instruction is " + str(line_count) + " = " + hex_str)
    
    hex_str = int(hex_str, 16).to_bytes(4, 'big')
    ser.write(hex_str)

    print(f"Start address is {hex(start_address)}")
    start_address_bytes = int(hex(start_address), 16).to_bytes(4, 'big')
    ser.write(start_address_bytes)

    with open(file, 'r') as f:
        for line in f:
            line = line.strip()
            if len(line) >= 8:
                read_data = int(line, 16).to_bytes(4,'big')
                ser.write(read_data)
    
    ser.write('done'.encode('utf-8'))

elif file_format == 2:
    file_size = os.path.getsize(file)
    ser = serial.Serial(port, baud_rate)
    ser.timeout = 1
    
    ser.write(program_sequence.encode('utf-8'))
    print(program_sequence)
    
    hex_str = hex(file_size)
    print ("Number of Instruction is " + str(file_size) + " = " + hex_str)
    
    hex_str = int(hex_str, 16).to_bytes(4, 'big')
    ser.write(hex_str)

    print(f"Start address is {hex(start_address)}")
    start_address_bytes = int(hex(start_address), 16).to_bytes(4, 'big')
    ser.write(start_address_bytes)
    
    with open(file, 'rb') as f:
        while True:
            chunk = f.read(4)
            if not chunk:
                break
            if len(chunk) == 4:
                ser.write(chunk[3:4])
                ser.write(chunk[2:3])
                ser.write(chunk[1:2])
                ser.write(chunk[0:1])
            else:
                padded = chunk + b'\x00' * (4 - len(chunk))
                ser.write(padded[3:4])
                ser.write(padded[2:3])
                ser.write(padded[1:2])
                ser.write(padded[0:1])
        
    ser.write('done'.encode('utf-8'))

print("Done Programming")
