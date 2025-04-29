// air_soc.sv
`timescale 1ns / 1ps

`include "header.vh"

`default_nettype none

`include "obi/typedef.svh"

module air_soc (
   input wire clk_i,

   input wire rst_ni,

   //input  wire uart_rx_i,
   
   input  wire program_rx_i,
   output wire prog_mode_led_o,
   
   output wire uart_tx_o

   `ifndef QSPI_SIM
   ,output wire qspi_cs_n_o
   `ifdef EXT_FLASH
   ,output wire qspi_sck_o
   `endif
   ,inout wire [3:0] qspi_data_io
   `endif
);

   wire uart_rx_i;

   logic system_reset_o;
   `ifdef BASYS3
   wire clkwiz_o;
   wire clkwiz_locked;
   clk_wiz_0 dutclk (
      .clk_out1(clkwiz_o),
      .clk_in1(clk_i),
      .reset(~rst_ni),
      .locked(clkwiz_locked)
   );
   wire rst_n = rst_ni & system_reset_o & clkwiz_locked;
   `else
   wire clkwiz_o = clk_i;
   wire rst_n = rst_ni & system_reset_o;
   `endif

   logic               mem_req;
   logic [       63:0] mem_addr;
   logic               mem_we;
   logic [        7:0] mem_be;
   logic [       63:0] mem_wdata;
   logic               mem_rvalid;
   logic [       63:0] mem_rdata;

   logic                uart_gnt;
   logic                uart_rvalid;
   logic [`MEM_W  -1:0] uart_rdata;

   logic                timer_gnt;
   logic                timer_rvalid;
   logic [`MEM_W  -1:0] timer_rdata;

   logic                qspi_gnt;
   logic                qspi_rvalid;
   logic [`MEM_W  -1:0] qspi_rdata;

   import config_pkg::*;
   import build_config_pkg::*;
   import cva6_config_pkg::*;
   import ariane_axi::*;

   localparam cva6_cfg_t CVA6Cfg = build_config_pkg::build_config(cva6_config_pkg::cva6_cfg);

   ariane_axi::req_t  cva6_axi_req;
   ariane_axi::resp_t cva6_axi_resp;

   cva6 #(
      .CVA6Cfg ( CVA6Cfg )
      ,.axi_ar_chan_t ( ariane_axi::ar_chan_t )
      ,.axi_aw_chan_t ( ariane_axi::aw_chan_t )
      ,.axi_w_chan_t  ( ariane_axi::w_chan_t  )
      ,.b_chan_t      ( ariane_axi::b_chan_t  )
      ,.r_chan_t      ( ariane_axi::r_chan_t  )
      ,.noc_req_t     ( ariane_axi::req_t )
      ,.noc_resp_t    ( ariane_axi::resp_t )
   ) i_cva6 (
      .clk_i                ( clkwiz_o                     ),
      .rst_ni               ( rst_n                        ),
      .boot_addr_i          ( `BOOT_ADDR                   ),
      .hart_id_i            ( `HART_ID                     ),
      .irq_i                ( '0                           ),
      .ipi_i                ( 1'b0                         ),
      .time_irq_i           ( 1'b0                         ),
      .debug_req_i          ( 1'b0                         ),
      .noc_req_o            ( cva6_axi_req                 ),
      .noc_resp_i           ( cva6_axi_resp                )
   );

   logic [63:0] main_mem_rdata;
   logic main_mem_rvalid;

   AXI_BUS #(
      .AXI_ADDR_WIDTH ( cva6_config_pkg::CVA6ConfigAxiAddrWidth ),
      .AXI_DATA_WIDTH ( cva6_config_pkg::CVA6ConfigAxiDataWidth ),
      .AXI_ID_WIDTH   ( cva6_config_pkg::CVA6ConfigAxiIdWidth   ), // Use CVA6 ID width
      .AXI_USER_WIDTH ( cva6_config_pkg::CVA6ConfigDataUserWidth )
   ) mem_axi_bus();

   axi_master_connect #(
   ) i_axi_master_connect_cva6_to_mem (
      .axi_req_i  ( cva6_axi_req ),   // Input: CVA6 request struct
      .dis_mem    ( 1'b0         ),   // Input: Disable signal (tie low to always enable)
      .master     ( mem_axi_bus  )    // Output: Connects to the AXI bus interface (drives AW, W, AR valid/payload)
   );

   axi2mem #(
      .AXI_ADDR_WIDTH ( cva6_config_pkg::CVA6ConfigAxiAddrWidth ),
      .AXI_DATA_WIDTH ( cva6_config_pkg::CVA6ConfigAxiDataWidth ),
      .AXI_ID_WIDTH   ( cva6_config_pkg::CVA6ConfigAxiIdWidth   ), // Use CVA6 ID width
      .AXI_USER_WIDTH ( cva6_config_pkg::CVA6ConfigDataUserWidth )
   ) i_axi2mem (
      .clk_i  ( clkwiz_o ),
      .rst_ni ( rst_n    ),

      // AXI Slave Interface (Connect to the bus driven by axi_master_connect)
      .slave  ( mem_axi_bus ), // Reads AW, W, AR; Drives AWREADY, WREADY, B, ARREADY, R

      // Memory Master Interface (Outputs towards SRAM)
      .req_o  ( mem_req       ), // Request to memory
      .we_o   ( mem_we        ), // Write enable to memory
      .addr_o ( mem_addr  ), // Outputs full AXI Address Width
      .be_o   ( mem_be    ), // Outputs AXI Data Width Byte Enables
      .data_o ( mem_wdata ), // Outputs AXI Data Width Write Data
      .user_o ( /* mem_user_axi */ ), // Output user signal (if used)

      .data_i ( main_mem_rdata ),
      .user_i ( '0 )
   );

   assign cva6_axi_resp.aw_ready = mem_axi_bus.aw_ready;
   assign cva6_axi_resp.ar_ready = mem_axi_bus.ar_ready;
   assign cva6_axi_resp.w_ready  = mem_axi_bus.w_ready;
   assign cva6_axi_resp.b_valid  = mem_axi_bus.b_valid;
   assign cva6_axi_resp.r_valid  = mem_axi_bus.r_valid;
   // B Channel
   assign cva6_axi_resp.b.id   = mem_axi_bus.b_id;
   assign cva6_axi_resp.b.resp = mem_axi_bus.b_resp;
   assign cva6_axi_resp.b.user = mem_axi_bus.b_user;
   // R Channel
   assign cva6_axi_resp.r.id   = mem_axi_bus.r_id;
   assign cva6_axi_resp.r.data = mem_axi_bus.r_data;
   assign cva6_axi_resp.r.resp = mem_axi_bus.r_resp;
   assign cva6_axi_resp.r.last = mem_axi_bus.r_last;
   assign cva6_axi_resp.r.user = mem_axi_bus.r_user;

   assign mem_rvalid = main_mem_rvalid | uart_rvalid | timer_rvalid | qspi_rvalid;
   assign mem_rdata  = uart_rvalid     ? uart_rdata     :
                       timer_rvalid    ? timer_rdata    :
                       qspi_rvalid     ? qspi_rdata     : main_mem_rdata;

   ram64 #(
      .SIZE     (`RAM_SIZE / 4),
      .INIT_FILE(`RAM_FPATH)
   ) main_memory (
      .clk_i   (clkwiz_o),
      .rst_ni  (rst_ni `ifdef BASYS3 & clkwiz_locked `endif),
      .req_i   (mem_req & (((`MEM_BASE_ADDR  + `MEM_RANGE)  > mem_addr )   && (mem_addr >= `MEM_BASE_ADDR))),
      .we_i    (mem_req & mem_we),
      .be_i    (mem_be),
      .addr_i  (mem_addr),
      .wdata_i (mem_wdata),
      .rvalid_o(main_mem_rvalid),
      .rdata_o (main_mem_rdata)

      ,.program_rx_i(program_rx_i)
      ,.system_reset_o(system_reset_o)
      ,.prog_mode_led_o(prog_mode_led_o)
   );

   uart_controller_obi uart_dut (
      .clk_i   (clkwiz_o),
      .rst_ni  (rst_n),
      .req_i   (mem_req & (((`UART_BASE_ADDR  + `UART_RANGE)  > mem_addr )   && (mem_addr >= `UART_BASE_ADDR))),
      .we_i    (mem_req & mem_we),
      .be_i    (mem_be),
      .addr_i  (mem_addr),
      .wdata_i (mem_wdata),
      .gnt_o   (uart_gnt),
      .rvalid_o(uart_rvalid),
      .rdata_o (uart_rdata),
      .rx_i    (uart_rx_i),
      .tx_o    (uart_tx_o)
   );

   timer_controller_obi timer_dut (
      .clk_i   (clkwiz_o),
      .rst_ni  (rst_n),
      .req_i   (mem_req & (((`TIMER_BASE_ADDR  + `TIMER_RANGE)  > mem_addr )   && (mem_addr >= `TIMER_BASE_ADDR))),
      .we_i    (mem_req & mem_we),
      .be_i    (mem_be),
      .addr_i  (mem_addr),
      .wdata_i (mem_wdata),
      .gnt_o   (timer_gnt),
      .rvalid_o(timer_rvalid),
      .rdata_o (timer_rdata)
   );

   `ifdef QSPI_SIM
   wire qspi_cs_n_o;
   wire qspi_sck_o;
   wire [3:0] qspi_data_io;

   s25fl128s #(
      .mem_file_name("../../../tests/demo/demo.vmem"),
      //.mem_file_name("../../../rtl/sim/s25fl128s.mem"),
      //.mem_file_name("none"),
      .otp_file_name("none"),
      .AddrRANGE(24'h00FFFF)
      
      //,.TimingModel   ( "S25FS128SAGMFI000_F_30pF" )
      ,.TimingModel   ( "S25FL128SAGMFI000_F_30pF" )
      ,.UserPreload   (1)
   ) flash (
      // Data Inputs/Outputs
      .SI(qspi_data_io[0]),
      .SO(qspi_data_io[1]),
      // Controls
      .SCK(qspi_sck_o),
      .CSNeg(qspi_cs_n_o),
      //.RSTNeg(1),
      .WPNeg(qspi_data_io[2]),
      .HOLDNeg(qspi_data_io[3])
   );
   `endif

   wire [3:0] qspi_data_i;
   wire [3:0] qspi_data_o;
   wire [1:0] qspi_out_mod_o;
   `ifdef BASYS3
   IOBUF
   io_buf0
   (
        .I(qspi_data_o[0])
       ,.O(qspi_data_i[0])
       ,.T(~(|qspi_out_mod_o))
       ,.IO(qspi_data_io[0])
   );
      
   IOBUF
   io_buf1
   (
        .I(qspi_data_o[1])
       ,.O(qspi_data_i[1])
       ,.T(~qspi_out_mod_o[1])
       ,.IO(qspi_data_io[1])
      );
      
   IOBUF
   io_buf2
   (
        .I(qspi_data_o[2])
       ,.O(qspi_data_i[2])
       ,.T(~(&qspi_out_mod_o))
       ,.IO(qspi_data_io[2])
      );
      
   IOBUF
   io_buf3
   (
        .I(qspi_data_o[3])
       ,.O(qspi_data_i[3])
       ,.T(~(&qspi_out_mod_o))
       ,.IO(qspi_data_io[3])
   );

   `ifndef EXT_FLASH
   logic qspi_sck_o;
   STARTUPE2 #(
		.PROG_USR("FALSE"),
		.SIM_CCLK_FREQ(0.0)
	) STARTUPE2_inst (
	   .CFGCLK(),
	   .CFGMCLK(),
	   .EOS(),
	   .PREQ(),
	   .CLK(1'b0),
	   .GSR(1'b0),
	   .GTS(1'b0),
	   .KEYCLEARB(1'b0),
	   .PACK(1'b0),
	   .USRCCLKO(qspi_sck_o),
	   .USRCCLKTS(1'b0),
	   .USRDONEO(1'b1),
	   .USRDONETS(1'b1)
	);
   `endif
   `else
   assign qspi_data_io[0] = |qspi_out_mod_o   ? qspi_data_o[0] : 1'bZ;
   assign qspi_data_io[1] = qspi_out_mod_o[1] ? qspi_data_o[1] : 1'bZ;
   assign qspi_data_io[2] = &qspi_out_mod_o   ? qspi_data_o[2] : 1'bZ;
   assign qspi_data_io[3] = &qspi_out_mod_o   ? qspi_data_o[3] : 1'bZ;
   assign qspi_data_i = qspi_data_io;
   `endif

   qspi_controller_obi qspi (
      .clk_i         (clkwiz_o),
      .rst_ni        (rst_n),
      .req_i         (mem_req & (((`QSPI_BASE_ADDR  + `QSPI_RANGE)  > mem_addr )   && (mem_addr >= `QSPI_BASE_ADDR))),
      .we_i          (mem_req & mem_we),
      .be_i          (mem_be),
      .addr_i        (mem_addr),
      .wdata_i       (mem_wdata),
      .gnt_o         (qspi_gnt),
      .rvalid_o      (qspi_rvalid),
      .rdata_o       (qspi_rdata),
      .qspi_data_i   (qspi_data_i),
      .qspi_data_o   (qspi_data_o),
      .qspi_out_mod_o(qspi_out_mod_o),
      .qspi_cs_n_o   (qspi_cs_n_o),
      .qspi_sck_o    (qspi_sck_o)
   );

endmodule
