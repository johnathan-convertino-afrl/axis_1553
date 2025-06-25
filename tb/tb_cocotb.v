//******************************************************************************
// file:    tb_cocotb.v
//
// author:  JAY CONVERTINO
//
// date:    2025/06/24
//
// about:   Brief
// Test bench wrapper for cocotb
//
// license: License MIT
// Copyright 2024 Jay Convertino
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to
// deal in the Software without restriction, including without limitation the
// rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
// sell copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
// FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
// IN THE SOFTWARE.
//
//******************************************************************************

`timescale 1ns/100ps

/*
 * Module: tb_cocotb
 *
 * Parameters:
 *
 *   CLOCK_SPEED      - This is the aclk frequency in Hz
 *   RX_BAUD_DELAY    - Delay in rx baud enable. This will delay when we sample a bit (default is midpoint when rx delay is 0).
 *   TX_BAUD_DELAY    - Delay in tx baud enable. This will delay the time the bit output starts.
 *
 * Ports:
 *
 *   aclk           - Clock for AXIS
 *   arstn          - Negative reset for AXIS
 *   parity_err     - Indicates error with parity check (active high)
 *   frame_err      - Indicates the diff line went to no diff before data catpure finished.
 *   sync_only      - Indicates only the sync was received and the data is invalid.
 *   rx_tx          - Active high indicates transmit, active low indicates receive state.
 *   s_axis_tdata   - Input data for UART TX.
 *   s_axis_tuser   - Information about the AXIS data {D,TYY} (3:0)
 *
 *                    Bits explained below:
 *                  --- Code
 *                    - D   = DELAY ENABLED (3)
 *                          - 1 = Make sure there is a delay of 4us
 *                          - 0 = Send out immediatly
 *                    - TYY = TYPE OF DATA  (2:0)
 *                          - 000 = NA
 *                          - 001 = REG (NOT IMPLIMENTED)
 *                          - 010 = DATA
 *                          - 100 = CMD/STATUS
 *                  ---
 *   s_axis_tvalid  - When set active high the input data is valid
 *   s_axis_tready  - When active high the device is ready for input data.
 *   m_axis_tdata   - Output data from UART RX
 *   m_axis_tuser   - Information about the AXIS data {D,TYY} (3:0)
 *
 *                    Bits explained below:
 *                  --- Code
 *                    - D   = DELAY BEFORE DATA (3)
 *                          - 1 = Delay of 4us or more before data
 *                          - 0 = No delay between data
 *                    - TYY = TYPE OF DATA      (2:0)
 *                          - 000 NA
 *                          - 001 REG (NOT IMPLIMENTED)
 *                          - 010 DATA
 *                          - 100 CMD/STATUS
 *                  ---
 *   m_axis_tvalid  - When active high the output data is valid
 *   m_axis_tready  - When set active high the output device is ready for data.
 *   tx_diff        - transmit for 1553 (output to RX)
 *   rx_diff        - receive for 1553 (input from TX)
 */
module tb_cocotb #(
    parameter CLOCK_SPEED   = 2000000,
    parameter RX_BAUD_DELAY = 0,
    parameter TX_BAUD_DELAY = 0
  ) 
  (
    input   wire         aclk,
    input   wire         arstn,
    output  wire         parity_err,
    output  wire         frame_err,
    output  wire         sync_only,
    output  wire         rx_tx,
    input   wire [15:0]  s_axis_tdata,
    input   wire [ 3:0]  s_axis_tuser,
    input   wire         s_axis_tvalid,
    output  wire         s_axis_tready,
    output  wire [15:0]  m_axis_tdata,
    output  wire [ 3:0]  m_axis_tuser,
    output  wire         m_axis_tvalid,
    input   wire         m_axis_tready,
    output  wire [ 1:0]  tx_diff,
    input   wire [ 1:0]  rx_diff
  );
  
  // fst dump command
  initial begin
    $dumpfile ("tb_cocotb.fst");
    $dumpvars (0, tb_cocotb);
    #1;
  end
  
  //Group: Instantiated Modules

  /*
   * Module: dut
   *
   * Device under test, axis_1553
   */
  axis_1553 #(
    .CLOCK_SPEED(CLOCK_SPEED),
    .RX_BAUD_DELAY(RX_BAUD_DELAY),
    .TX_BAUD_DELAY(TX_BAUD_DELAY)
  ) dut (
    .aclk(aclk),
    .arstn(arstn),
    .parity_err(parity_err),
    .frame_err(frame_err),
    .sync_only(sync_only),
    .rx_tx(rx_tx),
    .s_axis_tdata(s_axis_tdata),
    .s_axis_tuser(s_axis_tuser),
    .s_axis_tvalid(s_axis_tvalid),
    .s_axis_tready(s_axis_tready),
    .m_axis_tdata(m_axis_tdata),
    .m_axis_tuser(m_axis_tuser),
    .m_axis_tvalid(m_axis_tvalid),
    .m_axis_tready(m_axis_tready),
    .tx_diff(tx_diff),
    .rx_diff(rx_diff)
  );
  
endmodule

