from random import getrandbits
from typing import Any, Dict, List

import cocotb
from cocotb.binary import BinaryValue
from cocotb.clock import Clock
from cocotb.handle import SimHandleBase
from cocotb.queue import Queue
from cocotb.triggers import RisingEdge, FallingEdge, Edge

TIMEOUT = 250000
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
async def read_instructions():
    for test in tests:
        with open(tests[test]["TEST_FILE"], "r") as f:
            instructions = [line.rstrip("\n") for line in f]
        tests[test]["instructions"] = instructions

#@cocotb.coroutine async
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

@cocotb.coroutine
async def anabellek(dut):
    await RisingEdge(dut.clk_i)
    dut.rst_ni.value = 0
    await RisingEdge(dut.clk_i)
    
    memory = load_verilog_hex_file()
    for address, value in memory.items():
        if address % 4 == 0:
            word = (
                memory.get(address + 3, 0) << 24 |
                memory.get(address + 2, 0) << 16 |
                memory.get(address + 1, 0) << 8  |
                memory.get(address, 0)
            )
            dut.main_memory.ram[address >> 2].value = word
    
    await RisingEdge(dut.clk_i)
    dut.rst_ni.value = 1

    timeout = 0
    while True:
        await RisingEdge(dut.clk_i)
        if timeout > TIMEOUT:
            break
        timeout += 1
    
    """
    for test in tests:
        dut.rst_ni.value = 0
        await RisingEdge(dut.clk_i)
        #if test != "bootloader":
        for index, instruction in enumerate(tests[test]["instructions"]):
            # fmt: off
            #dut.ram_i.dp_ram_i.mem[(index << 2) + 0].value = (int(instruction, 16) >>  0) & 0xFF
            #dut.ram_i.dp_ram_i.mem[(index << 2) + 1].value = (int(instruction, 16) >>  8) & 0xFF
            #dut.ram_i.dp_ram_i.mem[(index << 2) + 2].value = (int(instruction, 16) >> 16) & 0xFF
            #dut.ram_i.dp_ram_i.mem[(index << 2) + 3].value = (int(instruction, 16) >> 24) & 0xFF
            # fmt: on
            dut.main_memory.ram[index].value = int(instruction, 16)

        await RisingEdge(dut.clk_i)
        dut.rst_ni.value = 1

        timeout = 0
        while True:
            await RisingEdge(dut.clk_i)
            if timeout > TIMEOUT:
                break
            timeout += 1
    """

@cocotb.test()
async def tair(dut):
    await read_instructions()

    await cocotb.start(Clock(dut.clk_i, 40, "ns").start(start_high=False))
    dut.rst_ni.value = 0
    await RisingEdge(dut.clk_i)
    await RisingEdge(dut.clk_i)
    dut.rst_ni.value = 1
    blk = cocotb.start_soon(anabellek(dut))
    await blk
