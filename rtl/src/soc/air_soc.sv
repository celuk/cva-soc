// air_soc.sv
`timescale 1ns / 1ps

`include "header.vh"

`default_nettype none

`include "obi/typedef.svh"
`include "axi/typedef.svh"

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

   logic system_reset_o = 1;
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

   localparam config_pkg::cva6_cfg_t CVA6Cfg = build_config_pkg::build_config(cva6_config_pkg::cva6_cfg);

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
      .rvfi_probes_o        (                              ),
      .cvxif_req_o          (                              ),
      .cvxif_resp_i         ( '0                           ),
      .noc_req_o            ( cva6_axi_req                 ),
      .noc_resp_i           ( cva6_axi_resp                )
   );

   // --- AXI Crossbar (XBAR) ---
   localparam int unsigned NUM_SLAVES_XBAR = 1; // CVA6
   localparam int unsigned NUM_MASTERS_XBAR = 3; // RAM, UART, TIMER
   localparam int unsigned MASTER_RAM_IDX  = 0;
   localparam int unsigned MASTER_UART_IDX = 1;
   localparam int unsigned MASTER_TIMR_IDX = 2;

   // Define AXI XBAR configuration
   localparam axi_pkg::xbar_cfg_t XbarCfg = '{
       NoSlvPorts:         NUM_SLAVES_XBAR,
       NoMstPorts:         NUM_MASTERS_XBAR,
       MaxSlvTrans:        1,
       MaxMstTrans:        1,
       FallThrough:        1'b0,
       LatencyMode:        axi_pkg::NO_LATENCY,
       AxiIdWidthSlvPorts: cva6_config_pkg::CVA6ConfigAxiIdWidth,
       AxiIdUsedSlvPorts:  cva6_config_pkg::CVA6ConfigAxiIdWidth,
       UniqueIds:          1'b0,
       AxiAddrWidth:       cva6_config_pkg::CVA6ConfigAxiAddrWidth,
       AxiDataWidth:       cva6_config_pkg::CVA6ConfigAxiDataWidth,
       NoAddrRules:        NUM_MASTERS_XBAR
       ,default: '0
   };

   // Define AXI type for the master ports of the XBAR
   // Note: If NoSlvPorts > 1, AxiIdWidthMstPorts needs to be wider.
   // Since NoSlvPorts = 1 here, master ID width = slave ID width.
   localparam int unsigned AXI_ID_WIDTH_XBAR_MST = XbarCfg.AxiIdWidthSlvPorts; // + $clog2(XbarCfg.NoSlvPorts); -> simplifies to this when NoSlvPorts = 1

   // Signals connecting CVA6 <-> XBAR Slave Port 0
   // (Using ariane_axi types directly as they match the XBAR slave port config)
   ariane_axi::req_t  xbar_slv_port0_req;
   ariane_axi::resp_t xbar_slv_port0_resp;

   // Signals connecting XBAR Master Ports <-> AXI-to-OBI Bridges
   ariane_axi::req_t     [NUM_MASTERS_XBAR-1:0] xbar_mst_ports_req;
   ariane_axi::resp_t    [NUM_MASTERS_XBAR-1:0] xbar_mst_ports_resp;

   // Define the address map for the AXI XBAR
   localparam axi_pkg::xbar_rule_32_t [XbarCfg.NoAddrRules-1:0] ADDR_MAP_XBAR = '{
      // Rule 0 -> Master Port 0 (RAM)
      '{ start_addr: `MEM_BASE_ADDR,   end_addr: `MEM_BASE_ADDR  + `MEM_RANGE,   idx: MASTER_RAM_IDX  },
      // Rule 1 -> Master Port 1 (UART)
      '{ start_addr: `UART_BASE_ADDR,  end_addr: `UART_BASE_ADDR + `UART_RANGE,  idx: MASTER_UART_IDX },
      '{ start_addr: `TIMER_BASE_ADDR, end_addr: `TIMER_BASE_ADDR+ `TIMER_RANGE, idx: MASTER_TIMR_IDX }
   };

   // Instantiate AXI XBAR
   axi_xbar #(
      .Cfg          ( XbarCfg ),
      .ATOPs        ( 1'b0 ), // Disable ATOPs if CVA6/peripherals don't use them
      .Connectivity ( '1 ), // Fully connected for simplicity
      // Pass AXI type definitions for slave port (matches CVA6)
      .slv_aw_chan_t( ariane_axi::aw_chan_t ),
      .slv_ar_chan_t( ariane_axi::ar_chan_t ),
      .w_chan_t     ( ariane_axi::w_chan_t  ), // W channel type is common
      .slv_b_chan_t ( ariane_axi::b_chan_t  ),
      .slv_r_chan_t ( ariane_axi::r_chan_t  ),
      .slv_req_t    ( ariane_axi::req_t     ),
      .slv_resp_t   ( ariane_axi::resp_t    ),
      // Pass AXI type definitions for master ports
      .mst_aw_chan_t( ariane_axi::aw_chan_t ),
      .mst_ar_chan_t( ariane_axi::ar_chan_t ),
      .mst_b_chan_t ( ariane_axi::b_chan_t  ),
      .mst_r_chan_t ( ariane_axi::r_chan_t  ),
      .mst_req_t    ( ariane_axi::req_t     ),
      .mst_resp_t   ( ariane_axi::resp_t    ),
      // Address rule type
      .rule_t       ( axi_pkg::xbar_rule_32_t   )
   ) i_axi_xbar (
      .clk_i        ( clkwiz_o                      ),
      .rst_ni       ( rst_n                         ),
      .test_i       ( 1'b0                          ),

      // Slave Port 0 Interface (Connected to CVA6)
      .slv_ports_req_i  ( {xbar_slv_port0_req}      ), // Input Req Array (size 1)
      .slv_ports_resp_o ( {xbar_slv_port0_resp}     ), // Output Resp Array (size 1)

      // Master Ports Interface (Connected to AXI-to-OBI Bridges)
      .mst_ports_req_o  ( xbar_mst_ports_req        ), // Output Req Array [NUM_MASTERS_XBAR-1:0]
      .mst_ports_resp_i ( xbar_mst_ports_resp       ), // Input Resp Array [NUM_MASTERS_XBAR-1:0]

      // Address Mapping
      .addr_map_i       ( ADDR_MAP_XBAR             ),
      .en_default_mst_port_i( {NUM_SLAVES_XBAR{1'b0}} ), // Disable default routing
      .default_mst_port_i ( '0                      )
   );

   // Connect CVA6 <-> XBAR Slave Port 0
   assign xbar_slv_port0_req = cva6_axi_req;
   assign cva6_axi_resp      = xbar_slv_port0_resp;

   axi_synth_mem #(
      .AddrWidth          ( cva6_config_pkg::CVA6ConfigAxiAddrWidth    ),
      .DataWidth          ( cva6_config_pkg::CVA6ConfigAxiDataWidth ),
      .IdWidth            ( cva6_config_pkg::CVA6ConfigAxiIdWidth ),
      .UserWidth          ( cva6_config_pkg::CVA6ConfigDataUserWidth ),
      .MemDepthWords      ( `RAM_SIZE / 4 ),
      .req_t              ( ariane_axi::req_t ),
      .rsp_t              ( ariane_axi::resp_t )
   ) main_memory (
      .clk_i              ( clkwiz_o   ),
      .rst_ni             ( rst_ni `ifdef BASYS3 & clkwiz_locked `endif ),
      .axi_req_i          ( xbar_mst_ports_req[MASTER_RAM_IDX] ),
      .axi_rsp_o          ( xbar_mst_ports_resp[MASTER_RAM_IDX] )
   );

   initial begin
      $readmemh("../../../tests/coremark/coremark_baremetal.hex", main_memory2.ram);
   end

   ram32_obi #(
      .SIZE     (`RAM_SIZE / 4),
      .INIT_FILE(`RAM_FPATH)
   ) main_memory2 (
      .clk_i   (),
      .rst_ni  (),
      .req_i   (       ),
      .we_i    (        ),
      .be_i    (        ),
      .addr_i  (      ),
      .wdata_i (     ),
      .rvalid_o(    ),
      .rdata_o (     )
      
      ,.gnt_o   (       )

      ,.program_rx_i   (    )
      ,.system_reset_o ( )
      ,.prog_mode_led_o( )
   );

   logic                            uart_axi_awvalid;
   logic                            uart_axi_awready;
   logic [XbarCfg.AxiAddrWidth-1:0] uart_axi_awaddr;
   logic [AXI_ID_WIDTH_XBAR_MST-1:0]uart_axi_awid; // <-- Added
   logic [2:0]                      uart_axi_awprot;
   logic                            uart_axi_wvalid;
   logic                            uart_axi_wready;
   logic [XbarCfg.AxiDataWidth-1:0] uart_axi_wdata;
   logic [XbarCfg.AxiDataWidth/8-1:0] uart_axi_wstrb;
   logic                            uart_axi_bvalid;
   logic                            uart_axi_bready;
   logic [AXI_ID_WIDTH_XBAR_MST-1:0]uart_axi_bid; // <-- Added
   logic [1:0]                      uart_axi_bresp;
   logic                            uart_axi_arvalid;
   logic                            uart_axi_arready;
   logic [XbarCfg.AxiAddrWidth-1:0] uart_axi_araddr;
   logic [AXI_ID_WIDTH_XBAR_MST-1:0]uart_axi_arid; // <-- Added
   logic [2:0]                      uart_axi_arprot;
   logic                            uart_axi_rvalid;
   logic                            uart_axi_rready;
   logic [AXI_ID_WIDTH_XBAR_MST-1:0]uart_axi_rid; // <-- Added
   logic [XbarCfg.AxiDataWidth-1:0] uart_axi_rdata;
   logic [1:0]                      uart_axi_rresp;

   // Assign signals from XBAR output request struct to UART AXI inputs
   assign uart_axi_awvalid = xbar_mst_ports_req[MASTER_UART_IDX].aw_valid;
   assign uart_axi_awaddr  = xbar_mst_ports_req[MASTER_UART_IDX].aw.addr;
   assign uart_axi_awid    = xbar_mst_ports_req[MASTER_UART_IDX].aw.id; // <-- Connect ID
   assign uart_axi_awprot  = xbar_mst_ports_req[MASTER_UART_IDX].aw.prot;
   // ... W channel ...
   assign uart_axi_wvalid  = xbar_mst_ports_req[MASTER_UART_IDX].w_valid;
   assign uart_axi_wdata   = xbar_mst_ports_req[MASTER_UART_IDX].w.data;
   assign uart_axi_wstrb   = xbar_mst_ports_req[MASTER_UART_IDX].w.strb;
   // ... AR channel ...
   assign uart_axi_arvalid = xbar_mst_ports_req[MASTER_UART_IDX].ar_valid;
   assign uart_axi_araddr  = xbar_mst_ports_req[MASTER_UART_IDX].ar.addr;
   assign uart_axi_arid    = xbar_mst_ports_req[MASTER_UART_IDX].ar.id; // <-- Connect ID
   assign uart_axi_arprot  = xbar_mst_ports_req[MASTER_UART_IDX].ar.prot;
   // ... Ready ...
   assign uart_axi_bready  = xbar_mst_ports_req[MASTER_UART_IDX].b_ready;
   assign uart_axi_rready  = xbar_mst_ports_req[MASTER_UART_IDX].r_ready;

   // Assign signals from UART AXI outputs to XBAR input response struct
   assign xbar_mst_ports_resp[MASTER_UART_IDX].aw_ready = uart_axi_awready;
   assign xbar_mst_ports_resp[MASTER_UART_IDX].w_ready  = uart_axi_wready;
   assign xbar_mst_ports_resp[MASTER_UART_IDX].ar_ready = uart_axi_arready;
   assign xbar_mst_ports_resp[MASTER_UART_IDX].b_valid  = uart_axi_bvalid;
   assign xbar_mst_ports_resp[MASTER_UART_IDX].b.id     = uart_axi_bid; // <-- Connect ID
   assign xbar_mst_ports_resp[MASTER_UART_IDX].b.resp   = uart_axi_bresp;
   assign xbar_mst_ports_resp[MASTER_UART_IDX].r_valid  = uart_axi_rvalid;
   assign xbar_mst_ports_resp[MASTER_UART_IDX].r.id     = uart_axi_rid; // <-- Connect ID
   assign xbar_mst_ports_resp[MASTER_UART_IDX].r.data   = uart_axi_rdata;
   assign xbar_mst_ports_resp[MASTER_UART_IDX].r.resp   = uart_axi_rresp;
   assign xbar_mst_ports_resp[MASTER_UART_IDX].r.last   = 1'b1; // AXI-Lite

   // Instantiate the UART controller with AXI interface
   uart_controller_axi #(
       .AXI_ID_WIDTH  (AXI_ID_WIDTH_XBAR_MST), // <-- Pass correct ID width
       .AXI_ADDR_WIDTH(XbarCfg.AxiAddrWidth),
       .AXI_DATA_WIDTH(XbarCfg.AxiDataWidth)
   ) uart_dut (
       .clk_i   ( clkwiz_o      ), .rst_ni  ( rst_n         ),
       .s_axi_awvalid(uart_axi_awvalid), .s_axi_awready(uart_axi_awready),
       .s_axi_awaddr (uart_axi_awaddr),  .s_axi_awid   (uart_axi_awid), // <-- Connect ID
       .s_axi_awprot (uart_axi_awprot),
       .s_axi_wvalid (uart_axi_wvalid),  .s_axi_wready (uart_axi_wready),
       .s_axi_wdata  (uart_axi_wdata),   .s_axi_wstrb  (uart_axi_wstrb),
       .s_axi_bvalid (uart_axi_bvalid),  .s_axi_bready (uart_axi_bready),
       .s_axi_bid    (uart_axi_bid),     .s_axi_bresp  (uart_axi_bresp), // <-- Connect ID
       .s_axi_arvalid(uart_axi_arvalid), .s_axi_arready(uart_axi_arready),
       .s_axi_araddr (uart_axi_araddr),  .s_axi_arid   (uart_axi_arid), // <-- Connect ID
       .s_axi_arprot (uart_axi_arprot),
       .s_axi_rvalid (uart_axi_rvalid),  .s_axi_rready (uart_axi_rready),
       .s_axi_rid    (uart_axi_rid),     .s_axi_rdata  (uart_axi_rdata), // <-- Connect ID
       .s_axi_rresp  (uart_axi_rresp),
       .rx_i    ( uart_rx_i     ), .tx_o    ( uart_tx_o     )
   );

   logic                            timer_axi_awvalid;
   logic                            timer_axi_awready;
   logic [XbarCfg.AxiAddrWidth-1:0] timer_axi_awaddr;
   logic [AXI_ID_WIDTH_XBAR_MST-1:0]timer_axi_awid;
   logic [2:0]                      timer_axi_awprot;
   logic                            timer_axi_wvalid;
   logic                            timer_axi_wready;
   logic [XbarCfg.AxiDataWidth-1:0] timer_axi_wdata;
   logic [XbarCfg.AxiDataWidth/8-1:0] timer_axi_wstrb;
   logic                            timer_axi_bvalid;
   logic                            timer_axi_bready;
   logic [AXI_ID_WIDTH_XBAR_MST-1:0]timer_axi_bid;
   logic [1:0]                      timer_axi_bresp;
   logic                            timer_axi_arvalid;
   logic                            timer_axi_arready;
   logic [XbarCfg.AxiAddrWidth-1:0] timer_axi_araddr;
   logic [AXI_ID_WIDTH_XBAR_MST-1:0]timer_axi_arid;
   logic [2:0]                      timer_axi_arprot;
   logic                            timer_axi_rvalid;
   logic                            timer_axi_rready;
   logic [AXI_ID_WIDTH_XBAR_MST-1:0]timer_axi_rid;
   logic [XbarCfg.AxiDataWidth-1:0] timer_axi_rdata;
   logic [1:0]                      timer_axi_rresp;

   assign timer_axi_awvalid = xbar_mst_ports_req[MASTER_TIMR_IDX].aw_valid;
   assign timer_axi_awaddr  = xbar_mst_ports_req[MASTER_TIMR_IDX].aw.addr;
   assign timer_axi_awid    = xbar_mst_ports_req[MASTER_TIMR_IDX].aw.id;
   assign timer_axi_awprot  = xbar_mst_ports_req[MASTER_TIMR_IDX].aw.prot;
   assign timer_axi_wvalid  = xbar_mst_ports_req[MASTER_TIMR_IDX].w_valid;
   assign timer_axi_wdata   = xbar_mst_ports_req[MASTER_TIMR_IDX].w.data;
   assign timer_axi_wstrb   = xbar_mst_ports_req[MASTER_TIMR_IDX].w.strb;
   assign timer_axi_arvalid = xbar_mst_ports_req[MASTER_TIMR_IDX].ar_valid;
   assign timer_axi_araddr  = xbar_mst_ports_req[MASTER_TIMR_IDX].ar.addr;
   assign timer_axi_arid    = xbar_mst_ports_req[MASTER_TIMR_IDX].ar.id;
   assign timer_axi_arprot  = xbar_mst_ports_req[MASTER_TIMR_IDX].ar.prot;
   assign timer_axi_bready  = xbar_mst_ports_req[MASTER_TIMR_IDX].b_ready;
   assign timer_axi_rready  = xbar_mst_ports_req[MASTER_TIMR_IDX].r_ready;

   assign xbar_mst_ports_resp[MASTER_TIMR_IDX].aw_ready = timer_axi_awready;
   assign xbar_mst_ports_resp[MASTER_TIMR_IDX].w_ready  = timer_axi_wready;
   assign xbar_mst_ports_resp[MASTER_TIMR_IDX].ar_ready = timer_axi_arready;
   assign xbar_mst_ports_resp[MASTER_TIMR_IDX].b_valid  = timer_axi_bvalid;
   assign xbar_mst_ports_resp[MASTER_TIMR_IDX].b.id     = timer_axi_bid;
   assign xbar_mst_ports_resp[MASTER_TIMR_IDX].b.resp   = timer_axi_bresp;
   assign xbar_mst_ports_resp[MASTER_TIMR_IDX].r_valid  = timer_axi_rvalid;
   assign xbar_mst_ports_resp[MASTER_TIMR_IDX].r.id     = timer_axi_rid;
   assign xbar_mst_ports_resp[MASTER_TIMR_IDX].r.data   = timer_axi_rdata;
   assign xbar_mst_ports_resp[MASTER_TIMR_IDX].r.resp   = timer_axi_rresp;
   assign xbar_mst_ports_resp[MASTER_TIMR_IDX].r.last   = 1'b1;

   timer_controller_axi #(
       .AXI_ID_WIDTH  (AXI_ID_WIDTH_XBAR_MST),
       .AXI_ADDR_WIDTH(XbarCfg.AxiAddrWidth),
       .AXI_DATA_WIDTH(XbarCfg.AxiDataWidth)
   ) timer_dut (
       .clk_i   ( clkwiz_o      ),
       .rst_ni  ( rst_n         ),
       .s_axi_awvalid(timer_axi_awvalid),
       .s_axi_awready(timer_axi_awready),
       .s_axi_awaddr (timer_axi_awaddr),
       .s_axi_awid   (timer_axi_awid),
       .s_axi_awprot (timer_axi_awprot),
       .s_axi_wvalid (timer_axi_wvalid),
       .s_axi_wready (timer_axi_wready),
       .s_axi_wdata  (timer_axi_wdata),
       .s_axi_wstrb  (timer_axi_wstrb),
       .s_axi_bvalid (timer_axi_bvalid),
       .s_axi_bready (timer_axi_bready),
       .s_axi_bid    (timer_axi_bid),
       .s_axi_bresp  (timer_axi_bresp),
       .s_axi_arvalid(timer_axi_arvalid),
       .s_axi_arready(timer_axi_arready),
       .s_axi_araddr (timer_axi_araddr),
       .s_axi_arid   (timer_axi_arid),
       .s_axi_arprot (timer_axi_arprot),
       .s_axi_rvalid (timer_axi_rvalid),
       .s_axi_rready (timer_axi_rready),
       .s_axi_rid    (timer_axi_rid),
       .s_axi_rdata  (timer_axi_rdata),
       .s_axi_rresp  (timer_axi_rresp)
   );

endmodule
