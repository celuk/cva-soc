import serial
import argparse

parser = argparse.ArgumentParser(description="Send sram reset over UART")
parser.add_argument("--port", '-p', type=str, default="/dev/ttyUSB1", required=False, help="Serial port to use")
parser.add_argument("--baud_rate", '-b', type=int, default=115200, help="Baud rate to use")
parser.add_argument("--program_sequence", '-ps', type=str, default="RESETTTTT", help="Program sequence to send")
args = parser.parse_args()
port = args.port
baud_rate = args.baud_rate
program_sequence = args.program_sequence

ser = serial.Serial(port, baud_rate)
ser.timeout = 1

ser.write(program_sequence.encode('utf-8'))
print(program_sequence)
