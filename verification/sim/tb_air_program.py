from random import getrandbits
from typing import Any, Dict, List

import cocotb
from cocotb.binary import BinaryValue
from cocotb.clock import Clock
from cocotb.handle import SimHandleBase
from cocotb.queue import Queue
from cocotb.triggers import RisingEdge, FallingEdge, Edge, ClockCycles

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
        with open(tests[test]["TEST_FILE"], "r") as file:
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

import math

@cocotb.coroutine
async def _send_uart_byte(dut, byte_data, cycles_per_bit):
    dut.program_rx_i.value = 0
    await ClockCycles(dut.clk_i, cycles_per_bit)
    for i in range(8):
        dut.program_rx_i.value = (byte_data >> i) & 1
        await ClockCycles(dut.clk_i, cycles_per_bit)
    dut.program_rx_i.value = 1
    await ClockCycles(dut.clk_i, cycles_per_bit)

@cocotb.coroutine
async def _send_uart_word32(dut, word_data, cycles_per_bit):
    await _send_uart_byte(dut, (word_data >> 24) & 0xFF, cycles_per_bit)
    await _send_uart_byte(dut, (word_data >> 16) & 0xFF, cycles_per_bit)
    await _send_uart_byte(dut, (word_data >> 8)  & 0xFF, cycles_per_bit)
    await _send_uart_byte(dut, word_data & 0xFF        , cycles_per_bit)

@cocotb.coroutine
async def _send_uart_string(dut, string_data, cycles_per_bit):
    for char in string_data:
        await _send_uart_byte(dut, ord(char), cycles_per_bit)

@cocotb.coroutine
async def anabellek(dut):
    await RisingEdge(dut.clk_i)
    dut.rst_ni.value = 0
    await RisingEdge(dut.clk_i)
    
    CLOCK_PERIOD_NS = 10
    UART_BAUD_RATE = 3686400
    clock_freq_hz = int(1 / (CLOCK_PERIOD_NS * 1e-9))
    cycles_per_bit = math.ceil(clock_freq_hz / UART_BAUD_RATE)

    dut.program_rx_i.value = 1

    for test in tests:
        dut.rst_ni.value = 0
        dut.program_rx_i.value = 1
        await RisingEdge(dut.clk_i)

        for index, instruction_hex in enumerate(tests[test]["instructions"]):
            instruction_val = int(instruction_hex, 16)
            await _send_uart_word32(dut, instruction_val, cycles_per_bit)

        await RisingEdge(dut.clk_i)
        dut.rst_ni.value = 1

        timeout = 0
        while True:
            await RisingEdge(dut.clk_i)
            if timeout > TIMEOUT:
                break
            timeout += 1

@cocotb.test()
async def tair(dut):
    await read_instructions()

    await cocotb.start(Clock(dut.clk_i, 10, "ns").start(start_high=False))
    dut.rst_ni.value = 0
    await RisingEdge(dut.clk_i)
    await RisingEdge(dut.clk_i)
    dut.rst_ni.value = 1
    blk = cocotb.start_soon(anabellek(dut))
    await blk
