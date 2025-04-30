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
   logic [       31:0] mem_addr;
   logic               mem_we;
   logic [        3:0] mem_be;
   logic [       31:0] mem_wdata;
   logic               mem_rvalid;
   logic [       31:0] mem_rdata;

   logic                uart_gnt;
   logic                uart_rvalid;
   logic [`MEM_W  -1:0] uart_rdata;

   logic                timer_gnt;
   logic                timer_rvalid;
   logic [`MEM_W  -1:0] timer_rdata;

   logic                qspi_gnt;
   logic                qspi_rvalid;
   logic [`MEM_W  -1:0] qspi_rdata;

   localparam config_pkg::cva6_cfg_t CVA6Cfg = cva6_config_pkg::cva6_cfg;

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

   logic [31:0] main_mem_rdata;
   logic main_mem_rvalid;

   import obi_pkg::*;

   localparam obi_pkg::obi_cfg_t AdapterObiCfg = '{
       AddrWidth: cva6_config_pkg::CVA6ConfigAxiAddrWidth,
       DataWidth: cva6_config_pkg::CVA6ConfigAxiDataWidth,
       IdWidth:   cva6_config_pkg::CVA6ConfigAxiIdWidth,   // Pass AXI ID through OBI
       // --- Settings in the main obi_cfg_t struct ---
       UseRReady: 1'b0, // Keep default unless needed
       CombGnt:   1'b0, // Use standard registered grant timing (GNT cycle after REQ)
       Integrity: 1'b0, // Keep default
       BeFull:    1'b1, // Keep default
       OptionalCfg: '{
           UseAtop:    1'b0, // Disable unused features
           UseProt:    1'b0,
           UseMemtype: 1'b0,
           UseDbg:     1'b0,
           AUserWidth: 0,
           WUserWidth: 0,
           RUserWidth: 1,
           MidWidth:   0,
           AChkWidth:  0,
           RChkWidth:  0
       }
   };
   // Define OBI types based on the configuration
   `OBI_TYPEDEF_MINIMAL_A_OPTIONAL(adapter_obi_a_optional_t)
   `OBI_TYPEDEF_ALL_R_OPTIONAL(adapter_obi_r_optional_t, AdapterObiCfg.OptionalCfg.RUserWidth, AdapterObiCfg.OptionalCfg.RChkWidth)

   `OBI_TYPEDEF_A_CHAN_T(adapter_obi_a_chan_t, AdapterObiCfg.AddrWidth, AdapterObiCfg.DataWidth, AdapterObiCfg.IdWidth, adapter_obi_a_optional_t)
   `OBI_TYPEDEF_R_CHAN_T(adapter_obi_r_chan_t, AdapterObiCfg.DataWidth, AdapterObiCfg.IdWidth, adapter_obi_r_optional_t) // Use type defined by _ALL_ macro

   `OBI_TYPEDEF_DEFAULT_REQ_T(adapter_obi_req_t, adapter_obi_a_chan_t)
   `OBI_TYPEDEF_RSP_T(adapter_obi_rsp_t, adapter_obi_r_chan_t)

   // OBI signals between adapter and shim
   adapter_obi_req_t adapter_obi_req;
   adapter_obi_rsp_t adapter_obi_rsp;

   localparam AXI_MAX_TRANS = 4; // Example: Max outstanding AXI transactions

   axi_to_obi #(
      .ObiCfg         ( AdapterObiCfg          ), // Use the defined OBI config
      .obi_req_t      ( adapter_obi_req_t      ), // Pass OBI type definitions
      .obi_rsp_t      ( adapter_obi_rsp_t      ),
      .obi_a_chan_t   ( adapter_obi_a_chan_t   ), // Pass OBI type definitions
      .obi_r_chan_t   ( adapter_obi_r_chan_t   ), // Pass OBI type definitions
      .AxiAddrWidth   ( cva6_config_pkg::CVA6ConfigAxiAddrWidth ),
      .AxiDataWidth   ( cva6_config_pkg::CVA6ConfigAxiDataWidth ),
      .AxiIdWidth     ( cva6_config_pkg::CVA6ConfigAxiIdWidth   ),
      .AxiUserWidth   ( cva6_config_pkg::CVA6ConfigDataUserWidth), // Match CVA6 User Width
      .MaxTrans       ( AXI_MAX_TRANS          ),
      .axi_req_t      ( ariane_axi::req_t      ), // Pass AXI type definitions
      .axi_rsp_t      ( ariane_axi::resp_t     )
   ) i_axi_to_obi_bridge (
      .clk_i        ( clkwiz_o        ),
      .rst_ni       ( rst_n           ),
      .testmode_i   ( 1'b0            ),

      // AXI Slave Interface (Connected to CVA6)
      .axi_req_i    ( cva6_axi_req    ),
      .axi_rsp_o    ( cva6_axi_resp   ),

      // OBI Master Interface (Connected to OBI SRAM Shim)
      .obi_req_o    ( adapter_obi_req ),
      .obi_rsp_i    ( adapter_obi_rsp ),

      // Tie off unused combinatorial user signals if not needed by adapter
      .req_aw_id_o           (), .req_aw_user_o         (), .req_w_user_o          (),
      .req_write_aid_i       ('0),.req_write_auser_i     ('0),.req_write_wuser_i     ('0),
      .req_ar_id_o           (), .req_ar_user_o         (),
      .req_read_aid_i        ('0),.req_read_auser_i      ('0),
      .rsp_write_aw_user_o   (), .rsp_write_w_user_o    (), .rsp_write_bank_strb_o (),
      .rsp_write_rid_o       (), .rsp_write_ruser_o     (), .rsp_write_last_o      (),
      .rsp_write_hs_o        (), .rsp_b_user_i          ('0),
      .rsp_read_ar_user_o    (), .rsp_read_size_enable_o(), .rsp_read_rid_o        (),
      .rsp_read_ruser_o      (), .rsp_r_user_i          ('0)
   );

   logic gnt_q;

   obi_sram_shim #(
       .ObiCfg    ( AdapterObiCfg     ), // Use the same OBI config
       .obi_req_t ( adapter_obi_req_t ), // Pass OBI type definitions
       .obi_rsp_t ( adapter_obi_rsp_t )
   ) i_obi_sram_shim (
       .clk_i      ( clkwiz_o        ),
       .rst_ni     ( rst_n           ),

       // OBI Slave Interface (Connected to Adapter)
       .obi_req_i  ( adapter_obi_req ),
       .obi_rsp_o  ( adapter_obi_rsp ),

       // Simple RAM Master Interface (Connected to ram32)
       .req_o      ( mem_req         ),
       .we_o       ( mem_we          ),
       .addr_o     ( mem_addr        ),
       .wdata_o    ( mem_wdata       ),
       .be_o       ( mem_be          ),
       .gnt_i      ( gnt_q            ),
       .rdata_i    ( main_mem_rdata      )  // From ram32
   );

   always_ff @(posedge clkwiz_o or negedge rst_n) begin
      if (!rst_n) begin
          gnt_q <= 1'b0;
      end else begin
          gnt_q <= mem_req; // Register the grant signal
      end
   end

   assign mem_rvalid = main_mem_rvalid | uart_rvalid | timer_rvalid | qspi_rvalid;
   assign mem_rdata  = uart_rvalid     ? uart_rdata     :
                       timer_rvalid    ? timer_rdata    :
                       qspi_rvalid     ? qspi_rdata     : main_mem_rdata;

   ram32 #(
      .SIZE     (`RAM_SIZE / 4),
      .INIT_FILE(`RAM_FPATH)
   ) main_memory (
      .clk_i   (clkwiz_o),
      .rst_ni  (rst_ni `ifdef BASYS3 & clkwiz_locked `endif),
      .req_i   (mem_req),
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
