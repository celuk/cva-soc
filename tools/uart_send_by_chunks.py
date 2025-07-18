import os
import time
import serial
import argparse

BUILD_DIR = "temp"

def send_hex_over_uart(port, baud_rate, hex_path, program_sequence="SECURESOC", file_format=1):
    print(f"Sending {hex_path} over UART...")

    if file_format == 1:
        with open(hex_path, 'r') as f:
            lines = f.read().splitlines()

        with serial.Serial(port, baud_rate, timeout=1) as ser:
            ser.write(program_sequence.encode('utf-8'))
            print(f"Sent sequence: {program_sequence}")

            line_count = len(lines)
            print(f"Number of instructions: {line_count} = {hex(line_count)}")
            ser.write(line_count.to_bytes(4, 'big'))

            for line in lines:
                if len(line) >= 8:
                    data = int(line, 16).to_bytes(4, 'big')
                    ser.write(data)

            ser.write(b'done')
            print(f"Done sending {hex_path}\n")

    elif file_format == 2:
        with open(hex_path, 'rb') as f:
            data = f.read()

        with serial.Serial(port, baud_rate, timeout=1) as ser:
            ser.write(program_sequence.encode('utf-8'))
            print(f"Sent sequence: {program_sequence}")

            data_len = len(data)
            print(f"Binary size: {data_len} = {hex(data_len)}")
            ser.write(data_len.to_bytes(4, 'big'))

            for i in range(0, data_len, 4):
                chunk = data[i:i+4].ljust(4, b'\x00')
                ser.write(chunk[::-1])

            ser.write(b'done')
            print(f"Done sending {hex_path}\n")


def send_all_hex_from_build_dir(build_dir, port="/dev/ttyUSB1", baud_rate=115200, program_sequence="SECURESOC"):
    i = 0
    while True:
        folder_name = f"simple_dram_write{i}"
        hex_path = os.path.join(build_dir, folder_name, f"{folder_name}.hex")
        if not os.path.isfile(hex_path):
            break
        send_hex_over_uart(port, baud_rate, hex_path, program_sequence)
        time.sleep(20)
        # wait until done received
        #done_seq = b"Done!"
        #with serial.Serial(port, baud_rate) as ser:
        #    while done_seq not in ser.read_until(done_seq):
        #        pass
        i += 1

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Send all .hex files from BUILD_DIR over UART.")
    parser.add_argument("--port", "-p", type=str, default="/dev/ttyUSB1", help="Serial port")
    parser.add_argument("--baud_rate", "-b", type=int, default=115200, help="Baud rate")
    parser.add_argument("--program_sequence", "-ps", type=str, default="SECURESOC", help="UART init sequence")

    args = parser.parse_args()

    send_all_hex_from_build_dir(
        BUILD_DIR,
        port=args.port,
        baud_rate=args.baud_rate,
        program_sequence=args.program_sequence
    )
