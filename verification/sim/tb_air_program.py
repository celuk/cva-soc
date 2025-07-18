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
async def _send_uart_byte(dut, byte_data, cycles_per_bit, clk):
    dut.program_rx_i.value = 0
    await ClockCycles(clk, cycles_per_bit)
    for i in range(8):
        dut.program_rx_i.value = (byte_data >> i) & 1
        await ClockCycles(clk, cycles_per_bit)
    dut.program_rx_i.value = 1
    await ClockCycles(clk, cycles_per_bit)

@cocotb.coroutine
async def _send_uart_word32(dut, word_data, cycles_per_bit, clk):
    await _send_uart_byte(dut, (word_data >> 24) & 0xFF, cycles_per_bit, clk)
    await _send_uart_byte(dut, (word_data >> 16) & 0xFF, cycles_per_bit, clk)
    await _send_uart_byte(dut, (word_data >> 8)  & 0xFF, cycles_per_bit, clk)
    await _send_uart_byte(dut, word_data & 0xFF        , cycles_per_bit, clk)

@cocotb.coroutine
async def _send_uart_string(dut, string_data, cycles_per_bit, clk):
    for char in string_data:
        await _send_uart_byte(dut, ord(char), cycles_per_bit, clk)

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
async def main_memory(dut, clock_period_ns, uart_baud_rate, clk):
    await RisingEdge(clk)
    #dut.rst_ni.value = 0
    #await RisingEdge(dut.clk_i)
    
    clock_freq_hz = int(1 / (clock_period_ns * 1e-9))
    cycles_per_bit = math.ceil(clock_freq_hz / uart_baud_rate)

    dut.program_rx_i.value = 1

    for test in tests:
        #dut.rst_ni.value = 0
        dut.program_rx_i.value = 1
        await RisingEdge(clk)

        instructions = tests[test]["instructions"]
        prog_size = len(instructions)

        await _send_uart_string(dut, "SECURESOC", cycles_per_bit, clk) # DRAMWRITE
        await _send_uart_word32(dut, prog_size, cycles_per_bit, clk)

        ## TODO: send start address to UART

        for index, instruction_hex in enumerate(instructions):
            instruction_val = int(instruction_hex, 16)
            await _send_uart_word32(dut, instruction_val, cycles_per_bit, clk)

        await RisingEdge(clk)
        #dut.rst_ni.value = 1

        ## reset after programmed to get boot again, waiting some time
        for _ in range(1000):
            await RisingEdge(clk)
        dut.rst_ni.value = 0
        await RisingEdge(clk)
        dut.rst_ni.value = 1

        timeout = 0
        while True:
            await RisingEdge(clk)
            if timeout > TIMEOUT:
                break
            timeout += 1

@cocotb.test()
async def tair(dut):
    await read_instructions()

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

    blk = cocotb.start_soon(main_memory(dut, clk_ns, baud_rate, clk))
    await blk
