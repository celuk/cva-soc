import argparse

#ADDR_WIDTH = 14

def generate_bootrom(hex_file):
    with open(hex_file, 'r') as f:
        lines = f.readlines()

    #print(f"`define ADDR_WIDTH {ADDR_WIDTH}\n")
    print("module bootrom (")
    print("   input logic [31:0] addr_i,")
    print("   output logic [31:0] rdata_o")
    print(");\n")
    print("always_comb begin")
    print("   case (addr_i)")

    for i, line in enumerate(lines):
        line = line.strip()
        if line:
            print(f"      {i}:    rdata_o = 32'h{line};")

    print(f"      default: rdata_o = 32'h00000000;")
    print("   endcase")
    print("end")
    print("endmodule\n")

parser = argparse.ArgumentParser(description='Generate bootrom from hex file.')
parser.add_argument('--file', '-f', type=str, help='The input hex file')
parser.add_argument('--addr_width', '-aw', type=int, help='Address width')

args = parser.parse_args()

ADDR_WIDTH = args.addr_width

generate_bootrom(args.file)
