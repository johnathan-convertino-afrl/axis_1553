//******************************************************************************
// file:    axis_1553.v
//
// author:  JAY CONVERTINO
//
// date:    2025/06/24
//
// about:   Brief
// AXIS 1553 core
//
// license: License MIT
// Copyright 2025 Jay Convertino
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

`resetall
`timescale 1 ns/10 ps
`default_nettype none

/*
 * Module: axis_1553
 *
 * AXIS 1553, simple core for encoding and decoding 1553 bus messages.
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
 *   parity_err     - Indicates error with parity check for receive (active high)
 *   sync_only      - Indicates only the sync was received and the data is invalid.
 *   frame_err      - Indicates the diff line went to no diff before data catpure finished.
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
module axis_1553 #(
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
  
  `include "util_helper_math.vh"
  
  // var: BASE_1553_CLOCK_RATE
  // 1553 base clock rate
  localparam integer BASE_1553_CLOCK_RATE = 1000000;
  // var: BASE_1553_SAMPLE_RATE
  // Sample rate to use for the 1553 bus, set to 2 MHz
  localparam integer BASE_1553_SAMPLE_RATE = 2000000;
  // var: SAMPLES_PER_MHZ
  // sample rate of 2 MHz to caputre transmission bits at
  localparam integer SAMPLES_PER_MHZ = BASE_1553_SAMPLE_RATE / BASE_1553_CLOCK_RATE;
  // var: cycles_per_mhz
  // calculate the number of cycles the clock changes per period
  localparam integer CYCLES_PER_MHZ = CLOCK_SPEED / BASE_1553_CLOCK_RATE;
  // var: BIT_RATE_PER_MHZ
  // bit rate per mhz
  localparam integer BIT_RATE_PER_MHZ = SAMPLES_PER_MHZ;
  // var: DELAY_TIME
  // delay time, 4 is for 4 us (min 1553 time)
  localparam integer DELAY_TIME = CYCLES_PER_MHZ * 4;
  // var: SYNC_BITS_PER_TRANS
  // sync bits per transmission
  localparam integer SYNC_BITS_PER_TRANS = 3;
  // var: SYNTH_SYNC_BITS_PER_TRANS
  // sync pulse length
  localparam integer SYNTH_SYNC_BITS_PER_TRANS = SYNC_BITS_PER_TRANS * BIT_RATE_PER_MHZ;
  // var: PARITY_BITS_PER_TRANS
  // parity bits per transmission
  localparam integer PARITY_BITS_PER_TRANS = 1;
  // var: SYNTH_PARITY_BITS_PER_TRANS
  // synth parity bits per transmission
  localparam integer SYNTH_PARITY_BITS_PER_TRANS = PARITY_BITS_PER_TRANS * BIT_RATE_PER_MHZ;
  // var: DATA_BITS_PER_TRANS
  // data bits per transmission
  localparam integer DATA_BITS_PER_TRANS = 16;
  // var: SYNTH_DATA_BITS_PER_TRANS
  // synth data bits per transmission
  localparam integer SYNTH_DATA_BITS_PER_TRANS = DATA_BITS_PER_TRANS * BIT_RATE_PER_MHZ;
  // var: BITS_PER_TRANS
  // non sync bits per transmission
  localparam integer BITS_PER_TRANS = DATA_BITS_PER_TRANS + PARITY_BITS_PER_TRANS;
  // var: TOTAL_BITS_PER_TRANS
  // bits per transmission with sync
  localparam integer TOTAL_BITS_PER_TRANS = DATA_BITS_PER_TRANS + PARITY_BITS_PER_TRANS + SYNC_BITS_PER_TRANS;
  // var: SYNTH_BITS_PER_TRANS
  // synth bits per trans without sync
  localparam integer SYNTH_BITS_PER_TRANS = SYNTH_DATA_BITS_PER_TRANS + SYNTH_PARITY_BITS_PER_TRANS;
  // var: TOTAL_SYNTH_BITS_PER_TRANS
  // synth bits per trans with sync
  localparam integer TOTAL_SYNTH_BITS_PER_TRANS = SYNTH_DATA_BITS_PER_TRANS + SYNTH_SYNC_BITS_PER_TRANS + SYNTH_PARITY_BITS_PER_TRANS;
  // var: TOTAL_SYNTH_BYTES_PER_TRANS
  // sync bits per trans with sync
  localparam integer TOTAL_SYNTH_BYTES_PER_TRANS = TOTAL_SYNTH_BITS_PER_TRANS/8;
  // var: BIT_PATTERN
  // create the bit pattern. This is based on outputing data on the negative and positive. This allows the encoder to run down to 1 mhz.
  localparam [(BIT_RATE_PER_MHZ)-1:0]BIT_PATTERN = {{BIT_RATE_PER_MHZ/2{1'b1}}, {BIT_RATE_PER_MHZ/2{1'b0}}};
  // var: SYNTH_CLK
  // synth clock is the clock constructed by the repeating the bit pattern. this is intended to be a representation of the clock. Captured at a bit_rate_per_mhz of a 1mhz clock.
  localparam [SYNTH_DATA_BITS_PER_TRANS-1:0]SYNTH_CLK = {DATA_BITS_PER_TRANS{BIT_PATTERN}};
  // var: SYNC_CMD_STAT
  // sync pulse command
  localparam [SYNTH_SYNC_BITS_PER_TRANS-1:0]SYNC_CMD_STAT = {{SYNTH_SYNC_BITS_PER_TRANS/2{1'b1}}, {SYNTH_SYNC_BITS_PER_TRANS/2{1'b0}}};
  // var: SYNC_DATA
  // sync pulse data
  localparam [SYNTH_SYNC_BITS_PER_TRANS-1:0]SYNC_DATA     = {{SYNTH_SYNC_BITS_PER_TRANS/2{1'b0}}, {SYNTH_SYNC_BITS_PER_TRANS/2{1'b1}}};
  // var: CMD_DATA
  // tuser decode for data
  localparam CMD_DATA = 3'b010;
  // var: CMD_DATA
  // tuser decode for command
  localparam CMD_CMND = 3'b100;
  
  //for loop indexs
  genvar xnor_index;
  genvar cycle_index;
  
  wire ena_tx;
  wire ena_rx;
  wire s_clr_clk_rx;
  
  wire tx;
  wire rx;
  
  wire s_parity_bit_tx;
  wire s_parity_bit_rx;
  
  wire s_tx_ready;
  
  wire [TOTAL_SYNTH_BITS_PER_TRANS-1:0]   s_input_data;
  
  wire [SYNTH_DATA_BITS_PER_TRANS-1:0]    s_machester_ii_data_tx;
  wire [SYNTH_PARITY_BITS_PER_TRANS-1:0]  s_machester_ii_parity_tx;
  wire [SYNTH_SYNC_BITS_PER_TRANS-1:0]    s_sync_tx;
  
  wire [SYNTH_DATA_BITS_PER_TRANS-1:0]    s_machester_ii_data_rx;
  wire [SYNTH_PARITY_BITS_PER_TRANS-1:0]  s_machester_ii_parity_rx;
  wire [SYNTH_SYNC_BITS_PER_TRANS-1:0]    s_sync_rx;
  
  wire [DATA_BITS_PER_TRANS-1:0]          s_decoded_data_rx;
  wire [DATA_BITS_PER_TRANS-1:0]          s_frame_err;
  
  wire [ 7:0] s_tx_counter;
  wire [ 7:0] s_rx_counter;
  
  wire [TOTAL_SYNTH_BITS_PER_TRANS-1:0]   s_output_data;
  
  reg  [15:0] r_m_axis_tdata;
  reg  [ 3:0] r_m_axis_tuser;
  reg         r_m_axis_tvalid;
  
  reg         r_parity_err;
  reg         r_sync_only;
  reg         r_frame_err;
  
  reg  r_rx_tx;
  reg  r_tx_delay;
  reg  r_tx_hold;
  
  reg [clogb2(DELAY_TIME)-1:0]  r_delay_cnt_tx;
  reg [clogb2(DELAY_TIME)-1:0]  r_delay_cnt_rx;
  
  reg  r_rx_load;
  reg  r_rx_delay;
  
  //INPUT DATA GENERATION
  assign s_machester_ii_data_rx = s_output_data[SYNTH_BITS_PER_TRANS-1:SYNTH_PARITY_BITS_PER_TRANS];
  
  //expand data for xnor
  //xnor data with synth clock for MANCHESTER II (G.E. THOMAS) XNOR
  generate
    for(xnor_index = 0; xnor_index < DATA_BITS_PER_TRANS; xnor_index = xnor_index + 1) begin : gen_DATA_MACHESTER_II_tx
      for(cycle_index = (BIT_RATE_PER_MHZ*xnor_index); cycle_index < (BIT_RATE_PER_MHZ*xnor_index)+(BIT_RATE_PER_MHZ); cycle_index = cycle_index + 1)
        assign s_machester_ii_data_tx[cycle_index] = ~(SYNTH_CLK[cycle_index] ^ s_axis_tdata[xnor_index]);
    end
    
    //future, check if previous and current bit are equal. If so, frame error
    for(xnor_index = 0; xnor_index < DATA_BITS_PER_TRANS; xnor_index = xnor_index + 1) begin : gen_DATA_MACHESTER_II_rx
      assign s_frame_err[xnor_index] = ~(s_machester_ii_data_rx[BIT_RATE_PER_MHZ*xnor_index] ^ s_machester_ii_data_rx[(BIT_RATE_PER_MHZ*xnor_index)+1]);
      
      for(cycle_index = (BIT_RATE_PER_MHZ*xnor_index); cycle_index < (BIT_RATE_PER_MHZ*xnor_index)+(BIT_RATE_PER_MHZ); cycle_index = cycle_index + 1)
        assign s_decoded_data_rx[xnor_index] = ~(SYNTH_CLK[cycle_index] ^ s_machester_ii_data_rx[cycle_index]);
    end
  endgenerate
  
  // PARITY GEN
  // create parity bit
  assign s_parity_bit_tx = ^s_axis_tdata ^ 1'b1; //odd
  
  assign s_machester_ii_parity_rx = s_output_data[SYNTH_PARITY_BITS_PER_TRANS-1:0];
  
  assign s_machester_ii_parity_tx = ~(SYNTH_CLK[BIT_RATE_PER_MHZ-1:0] ^ {SYNTH_PARITY_BITS_PER_TRANS{s_parity_bit_tx}});
  
  assign s_parity_bit_rx = ~(&(SYNTH_CLK[BIT_RATE_PER_MHZ-1:0] ^ s_machester_ii_parity_rx));
  
  //SELECT SYNC
  assign s_sync_tx = (s_axis_tuser[2:0] == CMD_DATA ? SYNC_DATA : SYNC_CMD_STAT);
  
  assign s_sync_rx = s_output_data[TOTAL_SYNTH_BITS_PER_TRANS-1:TOTAL_SYNTH_BITS_PER_TRANS-SYNTH_SYNC_BITS_PER_TRANS];
  
  //CONCATENATE PIECES FOR FULL 1553 MESSAGE
  assign s_input_data = {s_sync_tx, s_machester_ii_data_tx, s_machester_ii_parity_tx};
  
  //1553 IO
  assign tx_diff[0] = (r_rx_tx ?  tx : 1'b0);
  assign tx_diff[1] = (r_rx_tx ? ~tx : 1'b0);
  
  // when tx is NOT ready, we are transmitting.
  assign rx_tx = (r_tx_hold ? 1'b0 : r_rx_tx);
  
  // AXIS IO
  // only ready for data when the counter has hit 0 and we have not stored valid input. We wait to load data since we want to make sure all pulses are the correct length.
  assign s_axis_tready = s_tx_ready;
  assign s_tx_ready = (s_tx_counter == 0 ? 1'b1 : 1'b0) & arstn;
  
  // output that the current m_axis_tdata is valid.
  assign m_axis_tvalid = r_m_axis_tvalid;
  
  // output data, this doesr_tx_delayn't matter till valid is set.
  assign m_axis_tdata = r_m_axis_tdata;
  
  assign m_axis_tuser = r_m_axis_tuser;
  
  // output parity error when valid data is present.
  assign parity_err = r_parity_err;
  
  assign sync_only  = r_sync_only;
  
  assign frame_err  = r_frame_err;
  
  // clock stays cleared when no signal diff (xnor)
  assign s_clr_clk_rx = ~^rx_diff;

  //Group: Instantiated Modules
  /*
   * Module: uart_baud_gen_tx
   *
   * Generates TX BAUD rate for UART modules using modulo divide method.
   */
  mod_clock_ena_gen #(
    .CLOCK_SPEED(CLOCK_SPEED),
    .DELAY(TX_BAUD_DELAY)
  ) clk_gen_tx (
    .clk(aclk),
    .rstn(arstn),
    .start0(1'b1),
    .clr(s_tx_ready & ~r_rx_tx),
    .hold(r_tx_hold),
    .rate(BASE_1553_SAMPLE_RATE),
    .ena(ena_tx)
  );
  
  /*
   * Module: uart_baud_gen_rx
   *
   * Generates RX BAUD rate for UART modules using modulo divide method.
   */
  mod_clock_ena_gen #(
    .CLOCK_SPEED(CLOCK_SPEED),
    .DELAY(RX_BAUD_DELAY)
  ) uart_baud_gen_rx (
    .clk(aclk),
    .rstn(arstn),
    .start0(1'b0),
    .clr(s_clr_clk_rx),
    .hold(1'b0),
    .rate(BASE_1553_SAMPLE_RATE),
    .ena(ena_rx)
  );
  
  /*
   * Module: inst_sipo
   *
   * Captures RX data for 1553 receive
   */
  sipo #(
    .BUS_WIDTH(TOTAL_SYNTH_BYTES_PER_TRANS)
  ) inst_sipo (
    .clk(aclk),
    .rstn(arstn),
    .ena(ena_rx),
    .rev(1'b0),
    .load(r_rx_load),
    .pdata(s_output_data),
    .reg_count_amount(0),
    .sdata(rx_diff[0]),
    .dcount(s_rx_counter)
  );
  
  /*
   * Module: inst_piso
   *
   * Generates TX data for 1553 transmit
   */
  piso #(
    .BUS_WIDTH(TOTAL_SYNTH_BYTES_PER_TRANS),
    .DEFAULT_RESET_VAL(0),
    .DEFAULT_SHIFT_VAL(0)
  ) inst_piso (
    .clk(aclk),
    .rstn(arstn),
    .ena(ena_tx),
    .rev(1'b0),
    .load(s_axis_tvalid & s_tx_ready),
    .pdata(s_input_data),
    .reg_count_amount(0),
    .sdata(tx),
    .dcount(s_tx_counter)
  );
  
  // check for delay from start to end of transmit data. (must be 4us or more between transmit if delay enforced by tuser bit 3)
  always @(posedge aclk) begin
    if(arstn == 1'b0)
    begin
      r_delay_cnt_tx  <= DELAY_TIME-1;
    end else begin
      r_delay_cnt_tx <= r_delay_cnt_tx - 1;
      
      if(r_delay_cnt_tx == 0)
      begin
        r_delay_cnt_tx  <= 0;
      end
      
      // when the tx clock isn't cleared, we are receiving, hold the time.
      if(s_tx_ready == 1'b0 && r_tx_hold == 1'b0)
      begin
        r_delay_cnt_tx <= DELAY_TIME-1;
      end
    end
  end
  
  // setup for delay
  always @(posedge aclk) begin
    if(arstn == 1'b0)
    begin
      r_tx_delay <= 1'b0;
      r_tx_hold  <= 1'b0;
    end else begin
      r_tx_hold <= 1'b0;
      
      // both must be active high (1)
      if(s_axis_tvalid & s_tx_ready)
      begin
        r_tx_delay <= s_axis_tuser[3];
      end
      
      if(s_tx_ready == 1'b0 && r_tx_delay == 1'b1)
      begin
        r_tx_hold <= 1'b1;
        
        if(r_delay_cnt_tx == 0)
        begin
          r_tx_hold   <= 1'b0;
          r_tx_delay  <= 1'b0;
        end
      end
    end
  end
  
  // rx_tx needs to be a cycle behind.
  always @(posedge aclk)
  begin
    if(arstn == 1'b0)
    begin
      r_rx_tx <= 1'b0;
    end else begin
      if(ena_tx == 1'b1)
      begin
        r_rx_tx <= ~s_tx_ready;
      end
    end
  end
  
  // check for delay from start to end of received data (4us or more between receive).
  always @(posedge aclk) begin
    if(arstn == 1'b0)
    begin
      r_delay_cnt_rx  <= DELAY_TIME-1;
    end else begin
      r_delay_cnt_rx <= r_delay_cnt_rx - 1;
      
      if(r_delay_cnt_rx == 0)
      begin
        r_delay_cnt_rx  <= 0;
      end
      
      // when the rx clock isn't cleared, we are receiving, hold the time.
      if(s_clr_clk_rx == 1'b0)
      begin
        r_delay_cnt_rx <= DELAY_TIME-1;
      end
    end
  end
  
  // rx diff detection broken, will just keep going, need to wait till diff is done.
  // for detection of incoming transmissions (RX)
  always @(posedge aclk)
  begin
    if(arstn == 1'b0)
    begin
      r_rx_delay  <= 1'b0;
      r_rx_load   <= 1'b0;
      
      r_m_axis_tdata  <= 0;
      r_m_axis_tuser  <= 0;
      r_m_axis_tvalid <= 1'b0;
      
      r_parity_err  <= 1'b0;
      r_sync_only   <= 1'b0;
      r_frame_err   <= 1'b0;
    end else begin
      r_rx_load <= 1'b0;
      
      if(m_axis_tready == 1'b1)
      begin
        r_m_axis_tdata  <= 0;
        r_m_axis_tuser  <= 0;
        r_m_axis_tvalid <= 1'b0;
        r_parity_err    <= 1'b0;
        r_sync_only     <= 1'b0;
        r_frame_err     <= 1'b0;
      end
      
      if(s_rx_counter == 0 && r_delay_cnt_rx == 0)
      begin
        r_rx_delay <= 1'b1;
      end
      
      // receive only got a sync
      if(s_clr_clk_rx == 1'b1)
      begin
        if(s_rx_counter > 0)
        begin
          r_m_axis_tdata  <= 16'hDEAD;
          r_m_axis_tvalid <= 1'b1;
          
          r_parity_err    <= 1'b0;
          
          if(s_rx_counter == SYNTH_SYNC_BITS_PER_TRANS)
          begin
            r_sync_only <= 1'b1;
          end else begin
            r_frame_err <= 1'b1;
          end
          
          case(s_output_data[SYNTH_SYNC_BITS_PER_TRANS-1:0])
            SYNC_CMD_STAT:
            begin
              r_m_axis_tuser <= {r_rx_delay, CMD_CMND};
            end
            SYNC_DATA:
            begin
              r_m_axis_tuser <= {r_rx_delay, CMD_DATA};
            end
            default:
            begin
              // destroy sync only if sync is invalid and call it a frame error instead.
              r_m_axis_tuser <= {r_rx_delay, 3'b000};
              r_sync_only    <= 1'b0;
              r_frame_err    <= 1'b1;
            end
          endcase
          
          r_rx_delay <= 1'b0;
          r_rx_load  <= 1'b1;
        end
      end
      
      // receive is finished
      if(s_rx_counter == TOTAL_SYNTH_BITS_PER_TRANS && r_rx_load != 1'b1)
      begin
        r_m_axis_tdata  <= s_decoded_data_rx;
        r_m_axis_tvalid <= 1'b1;
        
        r_parity_err <= ^s_decoded_data_rx ^ 1'b1 ^ s_parity_bit_rx; //odd
        
        r_frame_err  <= |s_frame_err;
        
        r_sync_only  <= 1'b0;
        
        case(s_sync_rx)
          SYNC_CMD_STAT:
          begin
            r_m_axis_tuser <= {r_rx_delay, CMD_CMND};
          end
          SYNC_DATA:
          begin
            r_m_axis_tuser <= {r_rx_delay, CMD_DATA};
          end
          default:
          begin
            r_m_axis_tuser <= {r_rx_delay, 3'b000};
            r_frame_err    <= 1'b1;
          end
        endcase
        
        r_rx_delay <= 1'b0;
        r_rx_load  <= 1'b1;
      end
    end
  end
 
endmodule

`resetall
