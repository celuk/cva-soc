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

   logic               mem_gnt;
   logic               mem_req;
   logic [       31:0] mem_addr;
   logic               mem_we;
   logic [        3:0] mem_be;
   logic [       31:0] mem_wdata;
   logic               mem_rvalid;
   logic [       31:0] mem_rdata;

   logic               main_mem_gnt;
   logic               main_mem_req;
   logic [       31:0] main_mem_addr;
   logic               main_mem_we;
   logic [        3:0] main_mem_be;
   logic [       31:0] main_mem_wdata;
   logic               main_mem_rvalid;
   logic [       31:0] main_mem_rdata;

   logic                uart_req;
   logic [       31:0]  uart_addr;
   logic                uart_we;
   logic [`MEM_W/8-1:0] uart_be;
   logic [`MEM_W  -1:0] uart_wdata;
   logic                uart_gnt;
   logic                uart_rvalid;
   logic [`MEM_W  -1:0] uart_rdata;

   logic                timer_req;
   logic [       31:0]  timer_addr;
   logic                timer_we;
   logic [`MEM_W/8-1:0] timer_be;
   logic [`MEM_W  -1:0] timer_wdata;
   logic                timer_gnt;
   logic                timer_rvalid;
   logic [`MEM_W  -1:0] timer_rdata;

   //logic                qspi_req;
   //logic [       31:0]  qspi_addr;
   //logic                qspi_we;
   //logic [`MEM_W/8-1:0] qspi_be;
   //logic [`MEM_W  -1:0] qspi_wdata;
   //logic                qspi_gnt;
   //logic                qspi_rvalid;
   //logic [`MEM_W  -1:0] qspi_rdata;

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
   localparam int unsigned NUM_MASTERS_XBAR = 4; // RAM, UART, Timer, QSPI
   localparam int unsigned MASTER_RAM_IDX  = 0;
   localparam int unsigned MASTER_UART_IDX = 1;
   localparam int unsigned MASTER_TIMR_IDX = 2;
   localparam int unsigned MASTER_QSPI_IDX = 3;

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

   // Define AXI Types based on CVA6/XBAR parameters
   `AXI_TYPEDEF_AW_CHAN_T(xbar_mst_aw_chan_t, logic [XbarCfg.AxiAddrWidth-1:0], logic [AXI_ID_WIDTH_XBAR_MST-1:0], logic [cva6_config_pkg::CVA6ConfigDataUserWidth-1:0])
   `AXI_TYPEDEF_W_CHAN_T(xbar_w_chan_t,      logic [XbarCfg.AxiDataWidth-1:0], logic [XbarCfg.AxiDataWidth/8-1:0], logic [cva6_config_pkg::CVA6ConfigDataUserWidth-1:0])
   `AXI_TYPEDEF_B_CHAN_T(xbar_mst_b_chan_t,  logic [AXI_ID_WIDTH_XBAR_MST-1:0], logic [cva6_config_pkg::CVA6ConfigDataUserWidth-1:0])
   `AXI_TYPEDEF_AR_CHAN_T(xbar_mst_ar_chan_t,logic [XbarCfg.AxiAddrWidth-1:0], logic [AXI_ID_WIDTH_XBAR_MST-1:0], logic [cva6_config_pkg::CVA6ConfigDataUserWidth-1:0])
   `AXI_TYPEDEF_R_CHAN_T(xbar_mst_r_chan_t,  logic [XbarCfg.AxiDataWidth-1:0], logic [AXI_ID_WIDTH_XBAR_MST-1:0], logic [cva6_config_pkg::CVA6ConfigDataUserWidth-1:0])
   `AXI_TYPEDEF_REQ_T(xbar_mst_req_t, xbar_mst_aw_chan_t, xbar_w_chan_t, xbar_mst_ar_chan_t)
   `AXI_TYPEDEF_RESP_T(xbar_mst_resp_t, xbar_mst_b_chan_t, xbar_mst_r_chan_t)

   // Signals connecting CVA6 <-> XBAR Slave Port 0
   // (Using ariane_axi types directly as they match the XBAR slave port config)
   ariane_axi::req_t  xbar_slv_port0_req;
   ariane_axi::resp_t xbar_slv_port0_resp;

   // Signals connecting XBAR Master Ports <-> AXI-to-OBI Bridges
   xbar_mst_req_t     [NUM_MASTERS_XBAR-1:0] xbar_mst_ports_req;
   xbar_mst_resp_t    [NUM_MASTERS_XBAR-1:0] xbar_mst_ports_resp;

   // Define the address rule structure expected by axi_xbar
   // (Check axi_pkg.svh for the actual definition, e.g., axi_pkg::xbar_rule_t)
   typedef struct packed {
     logic [XbarCfg.AxiAddrWidth-1:0] start_addr; // Inclusive start address
     logic [XbarCfg.AxiAddrWidth-1:0] end_addr;   // Exclusive end address
     logic [$clog2(NUM_MASTERS_XBAR)-1:0] idx; // Output master port index
   } xbar_addr_rule_t; // Use the type from axi_pkg if available!

   // Define the address map for the AXI XBAR
   localparam xbar_addr_rule_t [XbarCfg.NoAddrRules-1:0] ADDR_MAP_XBAR = '{
      // Rule 0 -> Master Port 0 (RAM)
      '{ start_addr: `MEM_BASE_ADDR,   end_addr: `MEM_BASE_ADDR  + `MEM_RANGE,   idx: MASTER_RAM_IDX  },
      // Rule 1 -> Master Port 1 (UART)
      '{ start_addr: `UART_BASE_ADDR,  end_addr: `UART_BASE_ADDR + `UART_RANGE,  idx: MASTER_UART_IDX },
      // Rule 2 -> Master Port 2 (Timer)
      '{ start_addr: `TIMER_BASE_ADDR, end_addr: `TIMER_BASE_ADDR+ `TIMER_RANGE, idx: MASTER_TIMR_IDX },
      // Rule 3 -> Master Port 3 (QSPI)
      '{ start_addr: `QSPI_BASE_ADDR,  end_addr: `QSPI_BASE_ADDR + `QSPI_RANGE,  idx: MASTER_QSPI_IDX }
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
      .mst_aw_chan_t( xbar_mst_aw_chan_t ),
      .mst_ar_chan_t( xbar_mst_ar_chan_t ),
      .mst_b_chan_t ( xbar_mst_b_chan_t  ),
      .mst_r_chan_t ( xbar_mst_r_chan_t  ),
      .mst_req_t    ( xbar_mst_req_t     ),
      .mst_resp_t   ( xbar_mst_resp_t    ),
      // Address rule type
      .rule_t       ( xbar_addr_rule_t   ) // Use the type from axi_pkg if available!
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


   // --- OBI Interface Definition (Common for all bridges) ---
   import obi_pkg::*;
   localparam obi_pkg::obi_cfg_t AdapterObiCfg = '{
       AddrWidth: XbarCfg.AxiAddrWidth, // Match AXI Addr Width
       DataWidth: `MEM_W, // OBI Data width (can differ from AXI) - Use peripheral width `MEM_W`
       IdWidth:   AXI_ID_WIDTH_XBAR_MST, // Pass AXI ID from XBAR Master Port through OBI
       UseRReady: 1'b0,
       CombGnt:   1'b0,
       Integrity: 1'b0,
       BeFull:    1'b1,
       OptionalCfg: '{ UseAtop: 1'b0, UseProt: 1'b0, UseMemtype: 1'b0, UseDbg: 1'b0,
                      AUserWidth: 0, WUserWidth: 0, RUserWidth: 1, // Adjust if needed
                      MidWidth: 0, AChkWidth: 0, RChkWidth: 0 }
   };

   // Define OBI types based on the configuration (Only need req/rsp now)
   `OBI_TYPEDEF_MINIMAL_A_OPTIONAL(adapter_obi_a_optional_t)
   `OBI_TYPEDEF_ALL_R_OPTIONAL(adapter_obi_r_optional_t, AdapterObiCfg.OptionalCfg.RUserWidth, AdapterObiCfg.OptionalCfg.RChkWidth)

   `OBI_TYPEDEF_A_CHAN_T(adapter_obi_a_chan_t, AdapterObiCfg.AddrWidth, AdapterObiCfg.DataWidth, AdapterObiCfg.IdWidth, adapter_obi_a_optional_t)
   `OBI_TYPEDEF_R_CHAN_T(adapter_obi_r_chan_t, AdapterObiCfg.DataWidth, AdapterObiCfg.IdWidth, adapter_obi_r_optional_t) // Use type defined by _ALL_ macro

   `OBI_TYPEDEF_DEFAULT_REQ_T(adapter_obi_req_t, adapter_obi_a_chan_t)
   `OBI_TYPEDEF_RSP_T(adapter_obi_rsp_t, adapter_obi_r_chan_t)

   // --- AXI-to-OBI Bridges (One per Peripheral) ---
   localparam int unsigned AXI_MAX_TRANS = XbarCfg.MaxMstTrans; // Max outstanding transactions per bridge

   // OBI signals between bridges and peripherals
   adapter_obi_req_t mem_obi_req;   adapter_obi_rsp_t mem_obi_rsp;
   adapter_obi_req_t uart_obi_req;  adapter_obi_rsp_t uart_obi_rsp;
   adapter_obi_req_t timer_obi_req; adapter_obi_rsp_t timer_obi_rsp;
   adapter_obi_req_t qspi_obi_req;  adapter_obi_rsp_t qspi_obi_rsp;

   // Instantiate Bridge for RAM (Master Port 0)
   axi_to_obi #(
      .ObiCfg         ( AdapterObiCfg          ),
      .obi_req_t      ( adapter_obi_req_t      ), .obi_rsp_t      ( adapter_obi_rsp_t      ),
      .obi_a_chan_t   ( adapter_obi_a_chan_t   ), .obi_r_chan_t   ( adapter_obi_r_chan_t   ),
      .AxiAddrWidth   ( XbarCfg.AxiAddrWidth   ),
      .AxiDataWidth   ( XbarCfg.AxiDataWidth   ),
      .AxiIdWidth     ( AXI_ID_WIDTH_XBAR_MST  ), // Use XBAR Master ID Width
      .AxiUserWidth   ( cva6_config_pkg::CVA6ConfigDataUserWidth), // Match XBAR User Width
      .MaxTrans       ( AXI_MAX_TRANS          ),
      .axi_req_t      ( xbar_mst_req_t         ), // Use XBAR Master Req Type
      .axi_rsp_t      ( xbar_mst_resp_t        )  // Use XBAR Master Resp Type
   ) i_axi_to_obi_mem (
      .clk_i        ( clkwiz_o                              ),
      .rst_ni       ( rst_n                                 ),
      .testmode_i   ( 1'b0                                  ),
      // AXI Slave Interface (Connected to XBAR Master Port 0)
      .axi_req_i    ( xbar_mst_ports_req[MASTER_RAM_IDX]    ),
      .axi_rsp_o    ( xbar_mst_ports_resp[MASTER_RAM_IDX]   ),
      // OBI Master Interface (Connected to RAM)
      .obi_req_o    ( mem_obi_req                           ),
      .obi_rsp_i    ( mem_obi_rsp                           ),
      // Tie-offs (adjust if user signals are actually used)
      .req_aw_id_o (), .req_aw_user_o (), .req_w_user_o (),
      .req_write_aid_i ('0),.req_write_auser_i ('0),.req_write_wuser_i ('0),
      .req_ar_id_o (), .req_ar_user_o (),
      .req_read_aid_i ('0),.req_read_auser_i ('0),
      .rsp_write_aw_user_o (), .rsp_write_w_user_o (), .rsp_write_bank_strb_o (),
      .rsp_write_rid_o (), .rsp_write_ruser_o (), .rsp_write_last_o (),
      .rsp_write_hs_o (), .rsp_b_user_i ('0),
      .rsp_read_ar_user_o (), .rsp_read_size_enable_o (), .rsp_read_rid_o (),
      .rsp_read_ruser_o (), .rsp_r_user_i ('0)
   );

   // Instantiate Bridge for UART (Master Port 1)
   axi_to_obi #(
      .ObiCfg(AdapterObiCfg), .obi_req_t(adapter_obi_req_t), .obi_rsp_t(adapter_obi_rsp_t),
      .obi_a_chan_t(adapter_obi_a_chan_t), .obi_r_chan_t(adapter_obi_r_chan_t),
      .AxiAddrWidth(XbarCfg.AxiAddrWidth), .AxiDataWidth(XbarCfg.AxiDataWidth),
      .AxiIdWidth(AXI_ID_WIDTH_XBAR_MST), .AxiUserWidth(cva6_config_pkg::CVA6ConfigDataUserWidth),
      .MaxTrans(AXI_MAX_TRANS), .axi_req_t(xbar_mst_req_t), .axi_rsp_t(xbar_mst_resp_t)
   ) i_axi_to_obi_uart (
      .clk_i(clkwiz_o), .rst_ni(rst_n), .testmode_i(1'b0),
      .axi_req_i(xbar_mst_ports_req[MASTER_UART_IDX]), .axi_rsp_o(xbar_mst_ports_resp[MASTER_UART_IDX]),
      .obi_req_o(uart_obi_req), .obi_rsp_i(uart_obi_rsp),
      /* Tie-offs */ .req_aw_id_o(), .req_aw_user_o(), .req_w_user_o(), .req_write_aid_i('0), .req_write_auser_i('0), .req_write_wuser_i('0), .req_ar_id_o(), .req_ar_user_o(), .req_read_aid_i('0), .req_read_auser_i('0), .rsp_write_aw_user_o(), .rsp_write_w_user_o(), .rsp_write_bank_strb_o(), .rsp_write_rid_o(), .rsp_write_ruser_o(), .rsp_write_last_o(), .rsp_write_hs_o(), .rsp_b_user_i('0), .rsp_read_ar_user_o(), .rsp_read_size_enable_o(), .rsp_read_rid_o(), .rsp_read_ruser_o(), .rsp_r_user_i('0)
   );

    // Instantiate Bridge for Timer (Master Port 2)
   axi_to_obi #(
      .ObiCfg(AdapterObiCfg), .obi_req_t(adapter_obi_req_t), .obi_rsp_t(adapter_obi_rsp_t),
      .obi_a_chan_t(adapter_obi_a_chan_t), .obi_r_chan_t(adapter_obi_r_chan_t),
      .AxiAddrWidth(XbarCfg.AxiAddrWidth), .AxiDataWidth(XbarCfg.AxiDataWidth),
      .AxiIdWidth(AXI_ID_WIDTH_XBAR_MST), .AxiUserWidth(cva6_config_pkg::CVA6ConfigDataUserWidth),
      .MaxTrans(AXI_MAX_TRANS), .axi_req_t(xbar_mst_req_t), .axi_rsp_t(xbar_mst_resp_t)
   ) i_axi_to_obi_timer (
      .clk_i(clkwiz_o), .rst_ni(rst_n), .testmode_i(1'b0),
      .axi_req_i(xbar_mst_ports_req[MASTER_TIMR_IDX]), .axi_rsp_o(xbar_mst_ports_resp[MASTER_TIMR_IDX]),
      .obi_req_o(timer_obi_req), .obi_rsp_i(timer_obi_rsp),
      /* Tie-offs */ .req_aw_id_o(), .req_aw_user_o(), .req_w_user_o(), .req_write_aid_i('0), .req_write_auser_i('0), .req_write_wuser_i('0), .req_ar_id_o(), .req_ar_user_o(), .req_read_aid_i('0), .req_read_auser_i('0), .rsp_write_aw_user_o(), .rsp_write_w_user_o(), .rsp_write_bank_strb_o(), .rsp_write_rid_o(), .rsp_write_ruser_o(), .rsp_write_last_o(), .rsp_write_hs_o(), .rsp_b_user_i('0), .rsp_read_ar_user_o(), .rsp_read_size_enable_o(), .rsp_read_rid_o(), .rsp_read_ruser_o(), .rsp_r_user_i('0)
   );

    // Instantiate Bridge for QSPI (Master Port 3)
   axi_to_obi #(
      .ObiCfg(AdapterObiCfg), .obi_req_t(adapter_obi_req_t), .obi_rsp_t(adapter_obi_rsp_t),
      .obi_a_chan_t(adapter_obi_a_chan_t), .obi_r_chan_t(adapter_obi_r_chan_t),
      .AxiAddrWidth(XbarCfg.AxiAddrWidth), .AxiDataWidth(XbarCfg.AxiDataWidth),
      .AxiIdWidth(AXI_ID_WIDTH_XBAR_MST), .AxiUserWidth(cva6_config_pkg::CVA6ConfigDataUserWidth),
      .MaxTrans(AXI_MAX_TRANS), .axi_req_t(xbar_mst_req_t), .axi_rsp_t(xbar_mst_resp_t)
   ) i_axi_to_obi_qspi (
      .clk_i(clkwiz_o), .rst_ni(rst_n), .testmode_i(1'b0),
      .axi_req_i(xbar_mst_ports_req[MASTER_QSPI_IDX]), .axi_rsp_o(xbar_mst_ports_resp[MASTER_QSPI_IDX]),
      .obi_req_o(qspi_obi_req), .obi_rsp_i(qspi_obi_rsp),
      /* Tie-offs */ .req_aw_id_o(), .req_aw_user_o(), .req_w_user_o(), .req_write_aid_i('0), .req_write_auser_i('0), .req_write_wuser_i('0), .req_ar_id_o(), .req_ar_user_o(), .req_read_aid_i('0), .req_read_auser_i('0), .rsp_write_aw_user_o(), .rsp_write_w_user_o(), .rsp_write_bank_strb_o(), .rsp_write_rid_o(), .rsp_write_ruser_o(), .rsp_write_last_o(), .rsp_write_hs_o(), .rsp_b_user_i('0), .rsp_read_ar_user_o(), .rsp_read_size_enable_o(), .rsp_read_rid_o(), .rsp_read_ruser_o(), .rsp_r_user_i('0)
   );

   // --- Peripheral Instantiation and Connections ---

   // Unpack OBI requests from bridges to peripherals, Pack OBI responses from peripherals to bridges
   // Note: `MEM_W` should match `AdapterObiCfg.DataWidth` used above

   // RAM (Connects to mem_obi_req/mem_obi_rsp)
   logic        ram_req_i;
   logic        ram_we_i;
   logic [AdapterObiCfg.DataWidth/8-1:0] ram_be_i;
   logic [AdapterObiCfg.AddrWidth-1:0] ram_addr_i;
   logic [AdapterObiCfg.DataWidth-1:0] ram_wdata_i;
   logic        ram_rvalid_o;
   logic [AdapterObiCfg.DataWidth-1:0] ram_rdata_o;
   logic        ram_gnt_o; // Note: ram32_obi might not need gnt_i, confirm its interface

   assign ram_req_i   = mem_obi_req.req;
   assign ram_we_i    = mem_obi_req.a.we;
   assign ram_addr_i  = mem_obi_req.a.addr[31:0]; // Slice to RAM's address width
   assign ram_wdata_i = mem_obi_req.a.wdata;
   assign ram_be_i    = mem_obi_req.a.be;

   // RAM grants immediately (assuming simple RAM model)
   // The actual peripheral must assert gnt correctly if it has latency.
   // ram32_obi needs a gnt_o, assuming it's combinatorial based on req_i.
   // If ram32_obi uses registered grant, the bridge needs CombGnt=0.
   // ** Assuming ram32_obi provides gnt_o combinatorially or 1 cycle after req_i **
   assign mem_obi_rsp.gnt    = 1; // Use grant from RAM module
   assign mem_obi_rsp.rvalid = ram_rvalid_o;
   assign mem_obi_rsp.r.rdata = ram_rdata_o;
   assign mem_obi_rsp.r.rid   = mem_obi_req.a.aid; // Echo back the ID
   assign mem_obi_rsp.r.err  = 1'b0; // Assuming no errors from simple RAM
   // Assign optional fields if used in AdapterObiCfg/types
   // assign mem_obi_rsp.r.r_optional.ruser = '0;

   ram32_obi #(
      .SIZE     (`RAM_SIZE / 4),
      .INIT_FILE(`RAM_FPATH)
   ) main_memory (
      .clk_i   (clkwiz_o),
      .rst_ni  (rst_ni `ifdef BASYS3 & clkwiz_locked `endif),
      .req_i   ( ram_req_i      ),
      .we_i    ( ram_we_i       ),
      .be_i    ( ram_be_i       ),
      .addr_i  ( ram_addr_i     ),
      .wdata_i ( ram_wdata_i    ),
      .rvalid_o( ram_rvalid_o   ),
      .rdata_o ( ram_rdata_o    )
      
      ,.gnt_o   ( ram_gnt_o      )

      ,.program_rx_i   ( program_rx_i   )
      ,.system_reset_o ( system_reset_o )
      ,.prog_mode_led_o( prog_mode_led_o)
   );

   // UART (Connects to uart_obi_req/uart_obi_rsp)
   logic        uart_req_i;
   logic        uart_we_i;
   logic [AdapterObiCfg.DataWidth/8-1:0] uart_be_i;
   logic [AdapterObiCfg.AddrWidth-1:0] uart_addr_i;
   logic [AdapterObiCfg.DataWidth-1:0] uart_wdata_i;
   logic        uart_rvalid_o;
   logic [AdapterObiCfg.DataWidth-1:0] uart_rdata_o;
   logic        uart_gnt_o;

   assign uart_req_i   = uart_obi_req.req;
   assign uart_we_i    = uart_obi_req.a.we;
   assign uart_addr_i  = uart_obi_req.a.addr; // Use full address, controller slices internally
   assign uart_wdata_i = uart_obi_req.a.wdata;
   assign uart_be_i    = uart_obi_req.a.be;

   assign uart_obi_rsp.gnt    = uart_gnt_o;
   assign uart_obi_rsp.rvalid = uart_rvalid_o;
   assign uart_obi_rsp.r.rdata = uart_rdata_o;
   assign uart_obi_rsp.r.rid   = uart_obi_req.a.aid;
   assign uart_obi_rsp.r.err  = 1'b0; // Assuming no errors from UART controller
   // assign uart_obi_rsp.r.r_optional.ruser = '0;

   uart_controller_obi uart_dut (
      .clk_i   ( clkwiz_o      ),
      .rst_ni  ( rst_n         ),
      .req_i   ( uart_req_i    ),
      .we_i    ( uart_we_i     ),
      .be_i    ( uart_be_i[3:0]),
      .addr_i  ( uart_addr_i   ),
      .wdata_i ( uart_wdata_i  ),
      .gnt_o   ( uart_gnt_o    ),
      .rvalid_o( uart_rvalid_o ),
      .rdata_o ( uart_rdata_o  ),
      .rx_i    ( uart_rx_i     ),
      .tx_o    ( uart_tx_o     )
   );

   // Timer (Connects to timer_obi_req/timer_obi_rsp)
   logic        timer_req_i;
   logic        timer_we_i;
   logic [AdapterObiCfg.DataWidth/8-1:0] timer_be_i;
   logic [AdapterObiCfg.AddrWidth-1:0] timer_addr_i;
   logic [AdapterObiCfg.DataWidth-1:0] timer_wdata_i;
   logic        timer_rvalid_o;
   logic [AdapterObiCfg.DataWidth-1:0] timer_rdata_o;
   logic        timer_gnt_o;

   assign timer_req_i   = timer_obi_req.req;
   assign timer_we_i    = timer_obi_req.a.we;
   assign timer_addr_i  = timer_obi_req.a.addr;
   assign timer_wdata_i = timer_obi_req.a.wdata;
   assign timer_be_i    = timer_obi_req.a.be;

   assign timer_obi_rsp.gnt    = timer_gnt_o;
   assign timer_obi_rsp.rvalid = timer_rvalid_o;
   assign timer_obi_rsp.r.rdata = timer_rdata_o;
   assign timer_obi_rsp.r.rid   = timer_obi_req.a.aid;
   assign timer_obi_rsp.r.err  = 1'b0;
   // assign timer_obi_rsp.r.r_optional.ruser = '0;

   timer_controller_obi timer_dut (
      .clk_i   (clkwiz_o),
      .rst_ni  (rst_n),
      .req_i   ( timer_req_i   ),
      .we_i    ( timer_we_i    ),
      .be_i    ( timer_be_i[3:0]),
      .addr_i  ( timer_addr_i  ),
      .wdata_i ( timer_wdata_i ),
      .gnt_o   ( timer_gnt_o   ),
      .rvalid_o( timer_rvalid_o),
      .rdata_o ( timer_rdata_o )
   );

   logic        qspi_req_i;
   logic        qspi_we_i;
   logic [AdapterObiCfg.DataWidth/8-1:0] qspi_be_i;
   logic [AdapterObiCfg.AddrWidth-1:0] qspi_addr_i;
   logic [AdapterObiCfg.DataWidth-1:0] qspi_wdata_i;
   logic        qspi_rvalid_o;
   logic [AdapterObiCfg.DataWidth-1:0] qspi_rdata_o;
   logic        qspi_gnt_o;

   assign qspi_req_i   = qspi_obi_req.req;
   assign qspi_we_i    = qspi_obi_req.a.we;
   assign qspi_addr_i  = qspi_obi_req.a.addr;
   assign qspi_wdata_i = qspi_obi_req.a.wdata;
   assign qspi_be_i    = qspi_obi_req.a.be;

   assign qspi_obi_rsp.gnt    = qspi_gnt_o;
   assign qspi_obi_rsp.rvalid = qspi_rvalid_o;
   assign qspi_obi_rsp.r.rdata = qspi_rdata_o;
   assign qspi_obi_rsp.r.rid   = qspi_obi_req.a.aid;
   assign qspi_obi_rsp.r.err  = 1'b0; // Assuming no errors from QSPI controller
   // assign qspi_obi_rsp.r.r_optional.ruser = '0;

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
      .req_i         (qspi_req_i),
      .we_i          (qspi_we_i),
      .be_i          (qspi_be_i),
      .addr_i        (qspi_addr_i),
      .wdata_i       (qspi_wdata_i),
      .gnt_o         (qspi_gnt_o),
      .rvalid_o      (qspi_rvalid_o),
      .rdata_o       (qspi_rdata_o),
      .qspi_data_i   (qspi_data_i),
      .qspi_data_o   (qspi_data_o),
      .qspi_out_mod_o(qspi_out_mod_o),
      .qspi_cs_n_o   (qspi_cs_n_o),
      .qspi_sck_o    (qspi_sck_o)
   );

endmodule
