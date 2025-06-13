from random import getrandbits
from typing import Any, Dict, List

import cocotb
from cocotb.binary import BinaryValue
from cocotb.clock import Clock
from cocotb.handle import SimHandleBase
from cocotb.queue import Queue
from cocotb.triggers import RisingEdge, FallingEdge, Edge, ClockCycles, Timer

TIMEOUT = 2500000
tests = {}

import os
cfile = os.environ['CFILE']

from pathlib import Path
SCRIPT_DIR = Path(os.path.realpath(__file__)).parent.absolute()
test_hex = {
    cfile: {
        "TEST_FILE": f"{SCRIPT_DIR}/../../tests/{cfile}/{cfile}.hex",
        "fail_adr": 0x40F00060,
        "pass_adr": 0x40F00078,
        "instructions": [],
    }
}
if cfile == "coremark":
    from tests import coremark
    tests.update(coremark)
else:
    tests.update(test_hex)

@cocotb.coroutine
async def uart_monitor(dut, clk, cpu_clk, baud_rate):
    # Calculate number of clock cycles per UART bit
    cycles_per_bit = int(cpu_clk / baud_rate)
    half_bit = cycles_per_bit // 2

    bit_time_ns = 1e9 / baud_rate
    half_bit_time_ns = bit_time_ns / 2

    bit_time_ns = int(bit_time_ns)
    half_bit_time_ns = int(half_bit_time_ns)

    print("UART Monitor started")
    while True:
        # Wait for start bit (falling edge)
        await FallingEdge(dut.uart_tx_o)
        # Wait half bit to sample in middle of first data bit
        #await ClockCycles(clk, half_bit)
        await Timer(half_bit_time_ns, 'ns')

        # Read 8 data bits
        data = 0
        for i in range(8):
            #await ClockCycles(clk, cycles_per_bit)
            await Timer(bit_time_ns, 'ns')
            bit = int(dut.uart_tx_o.value)
            data |= (bit << i)

        # Wait for stop bit
        #await ClockCycles(clk, cycles_per_bit)
        await Timer(bit_time_ns, 'ns')

        # Convert to character
        try:
            char = chr(data)
        except ValueError:
            char = '?'

        # Print to console like a terminal
        print(char, end='', flush=True)
        ### reset if Done dram write
        #if(char == 'e'):
        #    print()
        #    dut.rst_ni.value = 0
        #    await RisingEdge(clk)
        #    dut.rst_ni.value = 1
        #    #break

@cocotb.coroutine
async def read_instructions():
    for test in tests:
        with open(tests[test]["TEST_FILE"], "r") as f:
            instructions = [line.rstrip("\n") for line in f]
        tests[test]["instructions"] = instructions

def load_verilog_hex_file():
    for test in tests:
        with open(tests[test]["TEST_FILE"].replace(".hex", ".vmem"), "r") as file:
            lines = file.readlines()

        memory = {}
        current_address = None

        for line in lines:
            if line.startswith("@"):
                current_address = int(line[1:], 16)
            else:
                values = line.strip().split()
                for value in values:
                    if current_address is not None:
                        memory[current_address] = int(value, 16)
                        current_address += 1

    return memory

def load_dram_verilog_hex_file():
    for test in tests:
        #with open(tests[test]["TEST_FILE"].rsplit("/", 2)[0] + "/coremark/coremark_baremetal.vmem", "r") as file:
        with open(tests[test]["TEST_FILE"].rsplit("/", 2)[0] + "/demo/demo.vmem", "r") as file:
            lines = file.readlines()

        memory = {}
        current_address = None

        for line in lines:
            if line.startswith("@"):
                current_address = int(line[1:], 16) - 0x80000000  # Adjust for DRAM base address
            else:
                values = line.strip().split()
                for value in values:
                    if current_address is not None:
                        memory[current_address] = int(value, 16)
                        current_address += 1

    return memory

def get_controller_address_map(axi_address, dut):
    COL_W = dut.i_ddr3_axi.u_core.DDR_COL_W.value
    ROW_W = dut.i_ddr3_axi.u_core.DDR_ROW_W.value
    
    bank = (axi_address >> 11) & 0x7
    row = (axi_address >> 14) & 0x7FFF
    col = axi_address & ((1 << COL_W) - 1)

    return {'bank': bank, 'row': row, 'col': col}

@cocotb.coroutine
async def backdoor_memory_loader(sorted_addresses, clk, dut, dram_memory):
    for address in sorted_addresses:
        if address % 16 == 0:
            word128 = 0
            for i in range(16):
                byte_val = dram_memory.get(address + i, 0)
                word128 |= byte_val << (i * 8)
            addr_map = get_controller_address_map(address, dut)
            
            dut.ddr3_dut.cocotb_bank_in.value = addr_map['bank']
            dut.ddr3_dut.cocotb_row_in.value  = addr_map['row']
            dut.ddr3_dut.cocotb_col_in.value  = addr_map['col']
            dut.ddr3_dut.cocotb_data_in.value = word128

            dut.ddr3_dut.cocotb_memory_write_trigger.value = 1
            await ClockCycles(clk, 1)
            #dut.ddr3_dut.cocotb_memory_write_trigger.value = 0

    dut.ddr3_dut.cocotb_memory_write_trigger.value = 0
    cocotb.log.info(f"Backdoor memory load complete. Loaded {len(sorted_addresses)//16} entries.")
    await ClockCycles(clk, 5)

timeout = 0

import signal
def signal_handler(sig, frame):
    global timeout
    timeout = TIMEOUT
    pass

signal.signal(signal.SIGINT, signal_handler)

@cocotb.coroutine
async def main_memory(dut, clk, start_address):
    await RisingEdge(clk)
    dut.rst_ni.value = 0
    await RisingEdge(clk)
    
    if cfile != "bootloader" or cfile != "bootloader_dram" or cfile != "secure_bootloader":
        memory = load_verilog_hex_file()
        for address, value in memory.items():
            if address % 4 == 0: # TODO: are all addresses 4 byte aligned?
                word = (
                    memory.get(address + 3, 0) << 24 |
                    memory.get(address + 2, 0) << 16 |
                    memory.get(address + 1, 0) << 8  |
                    memory.get(address, 0)
                )
                dut.main_memory.ram[address >> 2].value = word
        
    dram_mem_size = 0
    address = 0
    memory_array_index = 0
    ## for dram bootloader test
    #if cfile == "bootloader_dram":
    #    dram_mem_size = len(dut.ddr3_dut.memory)
    #    #dut.ddr3_dut.memory_index.value = 0
    #    dut.ddr3_dut.memory_used.value = 0
#
    #    #for i in range(dram_mem_size):
    #    #    dut.ddr3_dut.memory[i].value = 0
    #    #    dut.ddr3_dut.address[i].value = i
#
    #    dram_memory = load_dram_verilog_hex_file()
    #    
    #    sorted_addresses = sorted(dram_memory.keys())
    #
    #    for address in sorted_addresses:
    #        if address % 16 == 0:
    #            word128 = 0
    #            for i in range(16):
    #                byte_val = dram_memory.get(address + i, 0)
    #                word128 |= byte_val << (i * 8)
    #            
    #            lookup_key = axi_to_ddr_model_key(address, dut)
    #            
    #            dut.ddr3_dut.memory[memory_array_index].value = word128
    #            dut.ddr3_dut.address[memory_array_index].value = lookup_key
    #            memory_array_index += 1
        #print("ADDRESS: " + list(dram_memory.keys())[-1].__str__())
        #print("ADDRESS: " + (hex(address >> 4)).__str__())
    #print("ADDRESS: " + (hex(address >> 4)).__str__())

        #while not dut.ddr3_dut.init_done.value:
        #    await RisingEdge(clk)
        #await Edge(dut.ddr3_dut.init_done)
        #dut.ddr3_dut.memory_used.value = dram_mem_size

    #    for i in range(1024):
    #        dut.ddr3_dut.memory[i].value = 0xDEADBEEF
    #    dut.ddr3_dut.memory[256 + 0].value = 0x00A00293
    #    dut.ddr3_dut.memory[256 + 1].value = 0xFFF28293
    #    dut.ddr3_dut.memory[256 + 2].value = 0xFE029EE3
    #    dut.ddr3_dut.memory[256 + 3].value = 0x0000006F

    await RisingEdge(clk)
    dut.rst_ni.value = 1

    if cfile == "bootloader_dram":
        #dut.ddr3_dut.memory_used.value = 0

        dram_memory = load_dram_verilog_hex_file()
        
        sorted_addresses = sorted(dram_memory.keys())
        
        
        await Edge(dut.ddr3_dut.init_done)
        #dut.ddr3_dut.memory_used.value = dram_mem_size
        ## it is used as latest program address of word128
        #dut.ddr3_dut.memory_used.value = memory_array_index #address

        await ClockCycles(clk, 10000)

        bml = cocotb.start_soon(backdoor_memory_loader(sorted_addresses, clk, dut, dram_memory))
        await bml

    await RisingEdge(clk)

    global timeout
    while True:
        try:
            await RisingEdge(clk)
            if timeout > TIMEOUT:
                break
            timeout += 1
        except:
            pass
            #timeout = TIMEOUT
            ##await cocotb.triggers.Timer(1, units='ns')
            ##cocotb.simulator.end_simulation()
            #break
        
    """
    for test in tests:
        dut.rst_ni.value = 0
        await RisingEdge(clk)
        #if test != "bootloader":
        for index, instruction in enumerate(tests[test]["instructions"]):
            # fmt: off
            #dut.ram_i.dp_ram_i.mem[(index << 2) + 0].value = (int(instruction, 16) >>  0) & 0xFF
            #dut.ram_i.dp_ram_i.mem[(index << 2) + 1].value = (int(instruction, 16) >>  8) & 0xFF
            #dut.ram_i.dp_ram_i.mem[(index << 2) + 2].value = (int(instruction, 16) >> 16) & 0xFF
            #dut.ram_i.dp_ram_i.mem[(index << 2) + 3].value = (int(instruction, 16) >> 24) & 0xFF
            # fmt: on
            dut.main_memory.ram[index + (start_address >> 2)].value = int(instruction, 16)

        await RisingEdge(clk)
        dut.rst_ni.value = 1

        timeout = 0
        while True:
            await RisingEdge(clk)
            if timeout > TIMEOUT:
                break
            timeout += 1
    """

@cocotb.test()
async def tair(dut):
    #await read_instructions()

    ## start address of hex file not boot address
    ## boot address is 0x80 always but the hex file start address can be different
    start_address = 0x00000000
    ## is not used now

    clk_ns = 10
    baud_rate = 115200

    if hasattr(dut, "clk_p") and hasattr(dut, "clk_n"):
        clk_ns = 5
        # drive the positive pin
        clk = dut.clk_p
        cocotb.start_soon(Clock(clk, clk_ns, "ns").start(start_high=False))

        # in parallel, tie clk_n to the inverse of clk_p
        async def drive_inverted():
            # initialise
            dut.clk_n.value = 1
            while True:
                await RisingEdge(clk)
                dut.clk_n.value = 0
                await FallingEdge(clk)
                dut.clk_n.value = 1

        cocotb.start_soon(drive_inverted())

    else:
        # fallback to single-ended
        clk = dut.clk_i
        cocotb.start_soon(Clock(clk, clk_ns, "ns").start(start_high=False))

    dut.rst_ni.value = 0
    await RisingEdge(clk)
    await RisingEdge(clk)
    dut.rst_ni.value = 1
    cocotb.start_soon(uart_monitor(dut, clk, clk_ns, baud_rate))
    blk = cocotb.start_soon(main_memory(dut, clk, start_address))
    await blk
    print()
