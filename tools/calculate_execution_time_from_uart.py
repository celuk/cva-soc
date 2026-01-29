import sys
import time
import argparse
import serial

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--port", '-p', type=str, default="/dev/ttyUSB3", required=False, help="Serial port to use")
    parser.add_argument("--baud_rate", '-b', type=int, default=921600, help="Baud rate to use")
    args = parser.parse_args()

    try:
        ser = serial.Serial(args.port, args.baud_rate, timeout=0.1)
    except Exception as e:
        print(e)
        sys.exit(1)

    start_marker = "Starting shell..."
    end_marker = "~ #"
    start_time = None
    buffer = ""

    try:
        while True:
            if ser.in_waiting:
                data = ser.read(ser.in_waiting).decode("utf-8", errors="ignore")
                sys.stdout.write(data)
                sys.stdout.flush()
                buffer += data

                if start_time is None:
                    if start_marker in buffer:
                        start_time = time.time_ns()
                        buffer = ""
                else:
                    if end_marker in buffer:
                        end_time = time.time_ns()
                        print(f"\n{end_time - start_time}")
                        break
            else:
                time.sleep(0.001)

    except KeyboardInterrupt:
        pass
    finally:
        ser.close()

if __name__ == "__main__":
    main()
