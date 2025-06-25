#******************************************************************************
# file:    tb_cocotb.py
#
# author:  JAY CONVERTINO
#
# date:    2025/03/04
#
# about:   Brief
# Cocotb test bench
#
# license: License MIT
# Copyright 2025 Jay Convertino
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to
# deal in the Software without restriction, including without limitation the
# rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
# sell copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
# FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
# IN THE SOFTWARE.
#
#******************************************************************************

import random
import itertools

import cocotb
from cocotb.clock import Clock
from cocotb.utils import get_sim_time
from cocotb.triggers import FallingEdge, RisingEdge, Timer, Event
from cocotb.binary import BinaryValue
from cocotbext.axi import (AxiStreamBus, AxiStreamSource, AxiStreamSink, AxiStreamMonitor, AxiStreamFrame)
from cocotbext.mil_std_1553 import MILSTD1553Source, MILSTD1553Sink

# Function: random_bool
# Return a infinte cycle of random bools
#
# Returns: List
def random_bool():
  temp = []

  for x in range(0, 256):
    temp.append(bool(random.getrandbits(1)))

  return itertools.cycle(temp)

# Function: start_clock
# Start the simulation clock generator.
#
# Parameters:
#   dut - Device under test passed from cocotb test function
def start_clock(dut):
  dut._log.info(f'CLOCK NS : {int(1000000000/dut.CLOCK_SPEED.value)}')
  cocotb.start_soon(Clock(dut.aclk, int(1000000000/dut.CLOCK_SPEED.value), units="ns").start())

# Function: reset_dut
# Cocotb coroutine for resets, used with await to make sure system is reset.
async def reset_dut(dut):
  dut.arstn.value = 0
  await Timer(200, units="ns")
  dut.arstn.value = 1

# Function: increment test tx
# Coroutine that is identified as a test routine. This routine tests by sending a incrementing value
# as a command and then as data, no delay between the two is inserted by the core.
#
# Parameters:
#   dut - Device under test passed from cocotb.
@cocotb.test()
async def increment_test_tx(dut):

    start_clock(dut)

    axis_source = AxiStreamSource(AxiStreamBus.from_prefix(dut, "s_axis"), dut.aclk, dut.arstn, False)

    milstd1553_sink = MILSTD1553Sink(dut.tx_diff, dut.arstn)
    
    dut.rx_diff.value = 0
    
    await reset_dut(dut)

    for x in range(0, 2**8):
        data = x.to_bytes(length = 2, byteorder='little')

        tx_frame = AxiStreamFrame(data, tuser=0x4, tx_complete=Event())

        await axis_source.send(tx_frame)

        await RisingEdge(dut.tx_active)

        assert dut.tx_active.value.integer == 1, "Output is not enabled"

        rx_data = await milstd1553_sink.read_cmd()

        assert tx_frame.tdata == rx_data, "Input data does not match output"
        
        tx_frame = AxiStreamFrame(data, tuser=0x2, tx_complete=Event())
        
        await axis_source.send(tx_frame)
        
        await RisingEdge(dut.tx_active)
        
        assert dut.tx_active.value.integer == 1, "Output is not enabled"
        
        rx_data = await milstd1553_sink.read_data()
        
        assert tx_frame.tdata == rx_data, "Input data does not match output"


    await RisingEdge(dut.aclk)

    assert dut.s_axis_tready.value.integer == 1, "Input is not ready"

# Function: increment test rx
# Coroutine that is identified as a test routine. This routine tests by sending a incrementing value
# as a command and then as data.
#
# Parameters:
#   dut - Device under test passed from cocotb.
@cocotb.test()
async def increment_test_rx(dut):

    start_clock(dut)

    axis_sink = AxiStreamSink(AxiStreamBus.from_prefix(dut, "m_axis"), dut.aclk, dut.arstn, False)

    milstd1553_source = MILSTD1553Source(dut.rx_diff, dut.arstn)

    await reset_dut(dut)

    for x in range(0, 2**8):
        data = x.to_bytes(length = 2, byteorder='little')

        await milstd1553_source.write_cmd(data)

        rx_frame = await axis_sink.recv()

        assert rx_frame.tdata == data, "Input data does not match output"

        user_data = "{:05b}".format(rx_frame.tuser)

        assert user_data[2:] == "100", "Wrong Sync"
        
        assert user_data[1] == "0", "4us Delay"

        await milstd1553_source.write_data(data)

        rx_frame = await axis_sink.recv()

        assert rx_frame.tdata == data, "Input data does not match output"

        user_data = "{:05b}".format(rx_frame.tuser)

        assert user_data[2:] == "010", "Wrong Sync"
        
        assert user_data[1] == "0", "4us Delay"


    await RisingEdge(dut.aclk)

    assert milstd1553_source.empty(), "Buffer NOT empty"

# Function: increment test tx delay
# Coroutine that is identified as a test routine. This routine tests by sending a incrementing value
# as a command and then as data, delay between the two is inserted by the core.
#
# Parameters:
#   dut - Device under test passed from cocotb.
@cocotb.test()
async def increment_test_tx_delay(dut):

    start_clock(dut)

    axis_source = AxiStreamSource(AxiStreamBus.from_prefix(dut, "s_axis"), dut.aclk, dut.arstn, False)

    milstd1553_sink = MILSTD1553Sink(dut.tx_diff, dut.arstn)

    dut.rx_diff.value = 0

    await reset_dut(dut)

    for x in range(0, 2**8):
        data = x.to_bytes(length = 2, byteorder='little')

        tx_frame = AxiStreamFrame(data, tuser=0x4, tx_complete=Event())

        await Timer(10, units="us")

        await axis_source.send(tx_frame)

        await RisingEdge(dut.tx_active)

        assert dut.tx_active.value.integer == 1, "Output is not enabled"

        await FallingEdge(dut.tx_active)

        start_time = get_sim_time("us")

        rx_data = await milstd1553_sink.read_cmd()

        assert tx_frame.tdata == rx_data, "Input data does not match output"

        tx_frame = AxiStreamFrame(data, tuser=0xA, tx_complete=Event())

        await axis_source.send(tx_frame)

        await RisingEdge(dut.tx_active)

        end_time = get_sim_time("us")

        delay_time = end_time - start_time

        assert delay_time >= 4, "Delay less then 4 us"

        assert dut.tx_active.value.integer == 1, "Output is not enabled"

        rx_data = await milstd1553_sink.read_data()

        assert tx_frame.tdata == rx_data, "Input data does not match output"


    await RisingEdge(dut.aclk)

    assert dut.s_axis_tready.value.integer == 1, "Input is not ready"

# Function: increment test tx delay
# Coroutine that is identified as a test routine. This routine tests by sending a incrementing value
# as a command and then as data.
#
# Parameters:
#   dut - Device under test passed from cocotb.
@cocotb.test()
async def increment_test_rx_delay(dut):

    start_clock(dut)

    axis_sink = AxiStreamSink(AxiStreamBus.from_prefix(dut, "m_axis"), dut.aclk, dut.arstn, False)

    milstd1553_source = MILSTD1553Source(dut.rx_diff, dut.arstn)

    await reset_dut(dut)

    for x in range(0, 2**8):
        data = x.to_bytes(length = 2, byteorder='little')

        await milstd1553_source.write_cmd(data)

        rx_frame = await axis_sink.recv()

        assert rx_frame.tdata == data, "Input data does not match output"

        user_data = "{:05b}".format(rx_frame.tuser)

        assert user_data[2:] == "100", "Wrong Sync"
        
        assert user_data[1] == "0", "4us Delay"
        
        await Timer(4, units="us")

        await milstd1553_source.write_data(data)

        rx_frame = await axis_sink.recv()

        assert rx_frame.tdata == data, "Input data does not match output"

        user_data = "{:05b}".format(rx_frame.tuser)

        assert user_data[2:] == "010", "Wrong Sync"
        
        assert user_data[1] == "1", "No 4us Delay"


    await RisingEdge(dut.aclk)

    assert milstd1553_source.empty(), "Buffer NOT empty"


# Function: in_reset
# Coroutine that is identified as a test routine. This routine tests if device stays
# in unready state when in reset.
#
# Parameters:
#   dut - Device under test passed from cocotb.
@cocotb.test()
async def in_reset(dut):

    start_clock(dut)

    dut.s_axis_tvalid.value = 0

    dut.arstn.value = 0

    await Timer(10, units="ns")

    assert dut.s_axis_tready.value.integer == 0, "tready is 1!"

# Function: no_clock
# Coroutine that is identified as a test routine. This routine tests if no ready when clock is lost
# and device is left in reset.
#
# Parameters:
#   dut - Device under test passed from cocotb.
@cocotb.test()
async def no_clock(dut):

    dut.s_axis_tvalid.value = 0

    dut.arstn.value = 0

    await Timer(5, units="ns")

    assert dut.s_axis_tready.value.integer == 0, "tready is 1!"
