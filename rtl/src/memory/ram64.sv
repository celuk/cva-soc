`timescale 1ns / 1ps

`include "header.vh"

module ram64 #(
   parameter SIZE = 16384,  // 64 K
   parameter INIT_FILE = ""
) (
   input clk_i,
   input rst_ni,

   input               req_i,
   input               we_i,
   input        [ 7:0] be_i,
   input        [63:0] addr_i,
   input        [63:0] wdata_i,
   output logic        rvalid_o,
   output logic [63:0] rdata_o

   ,input logic program_rx_i
   ,output logic system_reset_o
   ,output logic prog_mode_led_o
);

   localparam int ADDR_W = $clog2(SIZE*4); // SIZE??

   logic [ADDR_W-1:0] mem_addr;
   assign mem_addr = addr_i[ADDR_W-1+2:2];

   function integer clogb2;
   input integer depth;
     for (clogb2=0; depth>0; clogb2=clogb2+1)
       depth = depth >> 1;
   endfunction
   
   localparam NB_COL = 4;
   localparam COL_WIDTH = 8;
   localparam RAM_DEPTH = SIZE*4;
   localparam ADDR_MSB = clogb2(RAM_DEPTH) + 1;
   localparam CPU_CLK   = `CPU_CLK;
   localparam BAUD_RATE = `BAUD_RATE;
   
   reg [(NB_COL*COL_WIDTH)-1:0] ram [RAM_DEPTH-1:0];
   
   wire [31:0] ram_prog_data;
   wire        ram_prog_data_valid;
   
   reg  [clogb2(RAM_DEPTH-1)-1:0] prog_addr;

   generate
   if (INIT_FILE != "") begin: use_init_file
     initial
       $readmemh(INIT_FILE, ram, 0, RAM_DEPTH-1);
   end else begin: init_bram_to_zero
     integer ram_index;
     initial
       for (ram_index = 0; ram_index < RAM_DEPTH; ram_index = ram_index + 1)
         ram[ram_index] = {(NB_COL*COL_WIDTH){1'b0}};
   end
   endgenerate

   wire [ADDR_W-1:0] wr_addr_ram;
   wire [63:0]  wr_data_ram;
   
   assign wr_addr_ram = mem_addr;
   assign wr_data_ram = wdata_i;

   assign system_reset_o = 1;
   wire rst_n = rst_ni && system_reset_o;

   always @(posedge clk_i) begin
      if (!rst_n) begin
         rdata_o <= 0;
      end else begin
         if ((req_i && we_i) || (prog_mode_led_o && ram_prog_data_valid)) begin
            for (int i = 0; i < 4; i++) if (be_i[i] == 1'b1) ram[wr_addr_ram][i*8+:8] <= wr_data_ram[i*8+:8];
            for (int i = 4; i < 8; i++) if (be_i[i] == 1'b1) ram[wr_addr_ram+1][(i-4)*8+:8] <= wr_data_ram[i*8+:8];
         end
         rdata_o[31:0] <= ram[mem_addr];
         rdata_o[63:32] <= ram[mem_addr+1];
      end
   end

   always_ff @(posedge clk_i or negedge rst_n) begin
      if (!rst_n) begin
         rvalid_o <= 0;
      end else begin
         rvalid_o <= req_i;
      end
   end

endmodule
