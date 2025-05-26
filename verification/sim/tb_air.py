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
    
    if cfile != "bootloader" or cfile != "secure_bootloader":
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
    
    await RisingEdge(clk)
    dut.rst_ni.value = 1

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

    clk_ns = 40
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
