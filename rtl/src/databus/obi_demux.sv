// air_soc.sv
`timescale 1ns / 1ps

`include "header.vh"

module obi_demux (
   input wire clk_i,
   input wire rst_ni,

   // CPU interface
   input  wire        data_req_i,
   output wire        data_gnt_o,
   output wire        data_rvalid_o,
   input  wire        data_we_i,
   input  wire [ 3:0] data_be_i,
   input  wire [31:0] data_addr_i,
   input  wire [31:0] data_wdata_i,
   output wire [31:0] data_rdata_o,

   // DCache interface
   output wire        cache_req_o,
   output wire [31:0] cache_addr_o,
   output wire        cache_we_o,
   output wire [ 3:0] cache_be_o,
   output wire [31:0] cache_wdata_o,
   input  wire        cache_gnt_i,
   input  wire        cache_rvalid_i,
   input  wire [31:0] cache_rdata_i,

   // UART interface
   output wire        uart_req_o,
   output wire [31:0] uart_addr_o,
   output wire        uart_we_o,
   output wire [ 3:0] uart_be_o,
   output wire [31:0] uart_wdata_o,
   input  wire        uart_gnt_i,
   input  wire        uart_rvalid_i,
   input  wire [31:0] uart_rdata_i,

   // TIMER interface
   output wire        timer_req_o,
   output wire [31:0] timer_addr_o,
   output wire        timer_we_o,
   output wire [ 3:0] timer_be_o,
   output wire [31:0] timer_wdata_o,
   input  wire        timer_gnt_i,
   input  wire        timer_rvalid_i,
   input  wire [31:0] timer_rdata_i

   // QSPI interface
   ,output wire        qspi_req_o
   ,output wire [31:0] qspi_addr_o
   ,output wire        qspi_we_o
   ,output wire [ 3:0] qspi_be_o
   ,output wire [31:0] qspi_wdata_o
   ,input  wire        qspi_gnt_i
   ,input  wire        qspi_rvalid_i
   ,input  wire [31:0] qspi_rdata_i
);

   reg         data_req;
   reg         data_we;
   reg  [ 3:0] data_be;
   reg  [31:0] data_addr;
   reg  [31:0] data_wdata;

   wire        periph_gnt;

   typedef enum {
      IDLE,
      WAITING
   } state_t;

   state_t state;

   // verilog_format: off
   assign cache_addr_o = data_addr;
   assign uart_addr_o  = data_addr;
   assign timer_addr_o = data_addr;
   assign qspi_addr_o = data_addr;

   assign cache_wdata_o = data_wdata;
   assign uart_wdata_o  = data_wdata;
   assign timer_wdata_o = data_wdata;
   assign qspi_wdata_o = data_wdata;

   //assign cache_req_o = (`MEM_BASE_ADDR  + `MEM_RANGE  > data_addr )   && (data_addr >= `MEM_BASE_ADDR)   ? (state == WAITING) & data_req : 'h0;
   generate
      if (`DCACHE_SZ > 0) begin
         assign cache_req_o = (`MEM_BASE_ADDR + `MEM_RANGE > data_addr ) && 
                              (data_addr >= `MEM_BASE_ADDR) ? (state == WAITING) & data_req : 'h0;
      end else begin
         assign cache_req_o = (`MEM_BASE_ADDR + `MEM_RANGE > data_addr ) && 
                              (data_addr >= `MEM_BASE_ADDR) ? data_req : 'h0;
      end
   endgenerate

   assign cache_we_o  = (`MEM_BASE_ADDR  + `MEM_RANGE  > data_addr )   && (data_addr >= `MEM_BASE_ADDR)   ? data_we  : 'h0;
   assign cache_be_o  = (`MEM_BASE_ADDR  + `MEM_RANGE  > data_addr )   && (data_addr >= `MEM_BASE_ADDR)   ? data_be  : 'h0;
  
   assign uart_req_o  = (`UART_BASE_ADDR + `UART_RANGE > data_addr )   && (data_addr >= `UART_BASE_ADDR)  ? (state == WAITING) & data_req : 'h0;
   assign uart_we_o   = (`UART_BASE_ADDR + `UART_RANGE > data_addr )   && (data_addr >= `UART_BASE_ADDR)  ? data_we  : 'h0;
   assign uart_be_o   = (`UART_BASE_ADDR + `UART_RANGE > data_addr )   && (data_addr >= `UART_BASE_ADDR)  ? data_be  : 'h0;

   assign timer_req_o = (`TIMER_BASE_ADDR + `TIMER_RANGE > data_addr ) && (data_addr >= `TIMER_BASE_ADDR) ? (state == WAITING) & data_req : 'h0;
   assign timer_we_o  = (`TIMER_BASE_ADDR + `TIMER_RANGE > data_addr ) && (data_addr >= `TIMER_BASE_ADDR) ? data_we  : 'h0;
   assign timer_be_o  = (`TIMER_BASE_ADDR + `TIMER_RANGE > data_addr ) && (data_addr >= `TIMER_BASE_ADDR) ? data_be  : 'h0;

   assign qspi_req_o = (`QSPI_BASE_ADDR + `QSPI_RANGE > data_addr ) && (data_addr >= `QSPI_BASE_ADDR) ? (state == WAITING) & data_req : 'h0;
   assign qspi_we_o  = (`QSPI_BASE_ADDR + `QSPI_RANGE > data_addr ) && (data_addr >= `QSPI_BASE_ADDR) ? data_we  : 'h0;
   assign qspi_be_o  = (`QSPI_BASE_ADDR + `QSPI_RANGE > data_addr ) && (data_addr >= `QSPI_BASE_ADDR) ? data_be  : 'h0;

   assign data_rdata_o = (`MEM_BASE_ADDR+`MEM_RANGE     > data_addr) && (data_addr >= `MEM_BASE_ADDR  ) ? cache_rdata_i :
                         (`UART_BASE_ADDR+`UART_RANGE   > data_addr) && (data_addr >= `UART_BASE_ADDR ) ? uart_rdata_i  :
                         (`TIMER_BASE_ADDR+`TIMER_RANGE > data_addr) && (data_addr >= `TIMER_BASE_ADDR) ? timer_rdata_i :
                         (`QSPI_BASE_ADDR+`QSPI_RANGE   > data_addr) && (data_addr >= `QSPI_BASE_ADDR ) ? qspi_rdata_i  :
                                                                                                          32'h0         ;

   assign data_rvalid_o= (`MEM_BASE_ADDR+`MEM_RANGE     >= data_addr) && (data_addr >= `MEM_BASE_ADDR  ) ? cache_rvalid_i :
                         (`UART_BASE_ADDR+`UART_RANGE   >= data_addr) && (data_addr >= `UART_BASE_ADDR ) ? uart_rvalid_i  :
                         (`TIMER_BASE_ADDR+`TIMER_RANGE >= data_addr) && (data_addr >= `TIMER_BASE_ADDR) ? timer_rvalid_i :
                         (`QSPI_BASE_ADDR+`QSPI_RANGE   >= data_addr) && (data_addr >= `QSPI_BASE_ADDR ) ? qspi_rvalid_i  :
                                                                                                           1'h0           ;

   assign periph_gnt   = (`MEM_BASE_ADDR+`MEM_RANGE     > data_addr) && (data_addr >= `MEM_BASE_ADDR  ) ? cache_gnt_i :
                         (`UART_BASE_ADDR+`UART_RANGE   > data_addr) && (data_addr >= `UART_BASE_ADDR ) ? uart_gnt_i  :
                         (`TIMER_BASE_ADDR+`TIMER_RANGE > data_addr) && (data_addr >= `TIMER_BASE_ADDR) ? timer_gnt_i :
                         (`QSPI_BASE_ADDR+`QSPI_RANGE   > data_addr) && (data_addr >= `QSPI_BASE_ADDR ) ? qspi_gnt_i  :
                                                                                                          'h0         ;

   assign data_gnt_o = (state == IDLE) & periph_gnt | (`DCACHE_SZ == 0) & data_req_i;

   // verilog_format: on

   always @(posedge clk_i) begin
      if (!rst_ni) begin
         state <= IDLE;

         data_req <= 0;
         data_we <= 0;
         data_be <= 0;
         data_addr <= 0;
         data_wdata <= 0;

      end else begin
         case (state)
            IDLE: begin
               if (data_req_i & data_gnt_o) begin
                  state <= WAITING;
               end
            end
            WAITING: begin
               if (data_rvalid_o) state <= IDLE;
               if (data_req & periph_gnt) data_req <= 0;
            end
         endcase

         case (state)
            IDLE: begin
               data_req <= data_req_i;
               data_we <= data_we_i;
               data_be <= data_be_i;
               data_addr <= data_addr_i;
               data_wdata <= data_wdata_i;
            end
            default: begin
               data_req <= 0;
            end
         endcase
      end
   end
endmodule
