// air_soc.sv
`timescale 1ns / 1ps

`include "header.vh"

`default_nettype none

`include "obi/typedef.svh"
`include "axi/typedef.svh"
`include "register_interface/typedef.svh"

module air_soc (
   `ifdef ZC706
   input  wire clk_p,
   input  wire clk_n,
   `elsif DDR3_AXI
   input  wire clk_p,
   input  wire clk_n,
   `else
   input wire clk_i,
   `endif

   input wire rst_ni,

   //input  wire uart_rx_i,
   
   input  wire program_rx_i,
   output wire prog_mode_led_o,
   
   output wire uart_tx_o

   `ifndef ZC706
   `ifndef USE_SRAM
   `ifndef DDR3_AXI
   `ifndef QSPI_SIM
   ,output wire qspi_cs_n_o
   `ifdef EXT_FLASH
   ,output wire qspi_sck_o
   `endif
   ,inout wire [3:0] qspi_data_io
   `endif
   `endif
   `endif
   `endif

   `ifndef DRAM_SIM
   `ifdef ZC706
   ,output wire ddr3_reset_n
   ,output wire ddr3_cke
   ,output wire ddr3_ck_p
   ,output wire ddr3_ck_n
   ,output wire ddr3_cs_n
   ,output wire ddr3_ras_n
   ,output wire ddr3_cas_n
   ,output wire ddr3_we_n
   ,output wire [2:0] ddr3_ba
   ,output wire [13:0] ddr3_addr
   ,output wire ddr3_odt
   ,output wire [1:0] ddr3_dm
   ,inout wire [1:0] ddr3_dqs_p
   ,inout wire [1:0] ddr3_dqs_n
   ,inout wire [15:0] ddr3_dq
   `elsif DDR3_AXI
   `ifndef USE_SRAM
   ,output wire ddr3_reset_n
   ,output wire ddr3_cke
   ,output wire ddr3_ck_p
   ,output wire ddr3_ck_n
   ,output wire ddr3_cs_n
   ,output wire ddr3_ras_n
   ,output wire ddr3_cas_n
   ,output wire ddr3_we_n
   ,output wire [2:0] ddr3_ba
   ,output wire [13:0] ddr3_addr
   ,output wire ddr3_odt
   ,output wire [1:0] ddr3_dm
   ,inout wire [1:0] ddr3_dqs_p
   ,inout wire [1:0] ddr3_dqs_n
   ,inout wire [15:0] ddr3_dq
   `endif
   `endif
   `endif
);

   wire uart_rx_i;

   logic system_reset_o;
   logic uart_dram_write_rst;
   logic uart_dram_mode;
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
   `elsif ZC706
      wire pll_locked;
      wire clk100;
      wire clk_ddr;
      wire clk_ref;
      wire clk_ddr_dqs;
      wire clk_i;
      clk_wiz_0 u_pll
      //clk_wiz_1 u_pll
      (
         .clk_in1_p(clk_p),
         .clk_in1_n(clk_n)

         ,.reset(~rst_ni)

         ,.clk_out1(clk100)      // 100
         ,.clk_out2(clk_ddr)     // 400
         ,.clk_out3(clk_ref)     // 200
         ,.clk_out4(clk_ddr_dqs) // 400 (phase 90)
         ,.clk_out5(clk_i)       // 100, 50, 25
         ,.locked(pll_locked)
      );

      wire clkwiz_o = clk_i;
      wire rst_n = rst_ni & system_reset_o & !uart_dram_mode & pll_locked;
   `elsif DDR3_AXI
      wire pll_locked;
      wire clk100;
      wire clk_ddr;
      wire clk_ref;
      wire clk_ddr_dqs;
      wire clk_i;
      clk_wiz_0 u_pll
      //clk_wiz_1 u_pll
      (
         .clk_in1_p(clk_p),
         .clk_in1_n(clk_n)

         ,.reset(~rst_ni)

         // first values for 100mhz, second values for 50mhz
         ,.clk_out1(clk100)      // 100, 50
         ,.clk_out2(clk_ddr)     // 400, 200
         ,.clk_out3(clk_ref)     // 200, 200
         ,.clk_out4(clk_ddr_dqs) // 400, 200 (phase 90)
         ,.clk_out5(clk_i)       // 100, 50
         ,.locked(pll_locked)
      );

      wire clkwiz_o = clk_i;
      wire rst_n = rst_ni & system_reset_o & pll_locked;
   `else
      wire clkwiz_o = clk_i;
      wire rst_n = rst_ni & system_reset_o;
   `endif

   localparam config_pkg::cva6_cfg_t CVA6Cfg = build_config_pkg::build_config(cva6_config_pkg::cva6_cfg);

   ariane_axi::req_t  cva6_axi_req;
   ariane_axi::resp_t cva6_axi_resp;

   logic [1:0] timer_irq;
   logic [1:0] ipi;

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
      .ipi_i                ( ipi[0]                         ),
      .time_irq_i           ( timer_irq[0]                         ),
      .debug_req_i          ( 1'b0                         ),
      .rvfi_probes_o        (                              ),
      .cvxif_req_o          (                              ),
      .cvxif_resp_i         ( '0                           ),
      .noc_req_o            ( cva6_axi_req                 ),
      .noc_resp_i           ( cva6_axi_resp                )
   );

   localparam int unsigned NUM_SLAVES_XBAR = 1; // CVA6
   `ifdef ZC706
   localparam int unsigned NUM_MASTERS_XBAR = 5; // RAM, UART, TIMER, DRAM, CLINT
   `elsif USE_SRAM
   localparam int unsigned NUM_MASTERS_XBAR = 5;
   `elsif DDR3_AXI
   localparam int unsigned NUM_MASTERS_XBAR = 5;
   `else
   localparam int unsigned NUM_MASTERS_XBAR = 4;
   `endif
   localparam int unsigned MASTER_RAM_IDX  = 0;
   localparam int unsigned MASTER_UART_IDX = 1;
   localparam int unsigned MASTER_TIMER_IDX = 2;
   localparam int unsigned MASTER_CLINT_IDX = 3;
   `ifdef ZC706 
   localparam int unsigned MASTER_DRAM_IDX = 4;
   `elsif USE_SRAM
   localparam int unsigned MASTER_DRAM_IDX = 4;
   `elsif DDR3_AXI
   localparam int unsigned MASTER_DRAM_IDX = 4;
   `endif

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

   localparam int unsigned AXI_ID_WIDTH_XBAR_MST = XbarCfg.AxiIdWidthSlvPorts;

   ariane_axi::req_t  xbar_slv_port0_req;
   ariane_axi::resp_t xbar_slv_port0_resp;

   ariane_axi::req_t     [NUM_MASTERS_XBAR-1:0] xbar_mst_ports_req;
   ariane_axi::resp_t    [NUM_MASTERS_XBAR-1:0] xbar_mst_ports_resp;

   localparam axi_pkg::xbar_rule_32_t [XbarCfg.NoAddrRules-1:0] ADDR_MAP_XBAR = '{
      '{ start_addr: `MEM_BASE_ADDR,   end_addr: `MEM_BASE_ADDR  + `MEM_RANGE,   idx: MASTER_RAM_IDX  },
      '{ start_addr: `UART_BASE_ADDR,  end_addr: `UART_BASE_ADDR + `UART_RANGE,  idx: MASTER_UART_IDX },
      '{ start_addr: `TIMER_BASE_ADDR, end_addr: `TIMER_BASE_ADDR+ `TIMER_RANGE, idx: MASTER_TIMER_IDX },
      '{ start_addr: `CLINT_BASE_ADDR, end_addr: `CLINT_BASE_ADDR + `CLINT_RANGE, idx: MASTER_CLINT_IDX }
      `ifdef ZC706 
      ,'{ start_addr: `DRAM_BASE_ADDR, end_addr: `DRAM_BASE_ADDR+ `DRAM_RANGE, idx: MASTER_DRAM_IDX }
      `elsif USE_SRAM
      ,'{ start_addr: `DDR3_AXI_BASE_ADDR, end_addr: `DDR3_AXI_BASE_ADDR+ `DDR3_AXI_RANGE, idx: MASTER_DRAM_IDX }
      `elsif DDR3_AXI
      ,'{ start_addr: `DDR3_AXI_BASE_ADDR, end_addr: `DDR3_AXI_BASE_ADDR+ `DDR3_AXI_RANGE, idx: MASTER_DRAM_IDX }
      `endif
   };

   axi_xbar #(
      .Cfg          ( XbarCfg ),
      .ATOPs        ( 1'b1 ),

      .slv_aw_chan_t( ariane_axi::aw_chan_t ),
      .slv_ar_chan_t( ariane_axi::ar_chan_t ),
      .w_chan_t     ( ariane_axi::w_chan_t  ),
      .slv_b_chan_t ( ariane_axi::b_chan_t  ),
      .slv_r_chan_t ( ariane_axi::r_chan_t  ),
      .slv_req_t    ( ariane_axi::req_t     ),
      .slv_resp_t   ( ariane_axi::resp_t    ),

      .mst_aw_chan_t( ariane_axi::aw_chan_t ),
      .mst_ar_chan_t( ariane_axi::ar_chan_t ),
      .mst_b_chan_t ( ariane_axi::b_chan_t  ),
      .mst_r_chan_t ( ariane_axi::r_chan_t  ),
      .mst_req_t    ( ariane_axi::req_t     ),
      .mst_resp_t   ( ariane_axi::resp_t    ),

      .rule_t       ( axi_pkg::xbar_rule_32_t   )
   ) i_axi_xbar (
      .clk_i        ( clkwiz_o                      ),
      .rst_ni       ( rst_n                         ),
      .test_i       ( 1'b0                          ),

      .slv_ports_req_i  ( {xbar_slv_port0_req}      ),
      .slv_ports_resp_o ( {xbar_slv_port0_resp}     ),

      .mst_ports_req_o  ( xbar_mst_ports_req        ),
      .mst_ports_resp_i ( xbar_mst_ports_resp       ),

      .addr_map_i       ( ADDR_MAP_XBAR             ),
      .en_default_mst_port_i( {NUM_SLAVES_XBAR{1'b0}} ),
      .default_mst_port_i ( '0                      )
   );

   assign xbar_slv_port0_req = cva6_axi_req;
   assign cva6_axi_resp      = xbar_slv_port0_resp;
 
   `REG_BUS_TYPEDEF_ALL(reg, logic[XbarCfg.AxiAddrWidth-1:0], logic[XbarCfg.AxiDataWidth-1:0], logic[XbarCfg.AxiDataWidth/8-1:0])
 
   reg_req_t clint_reg_req;
   reg_rsp_t clint_reg_rsp;
 
   axi_to_reg_v2 #(
     .AxiAddrWidth(XbarCfg.AxiAddrWidth),
     .AxiDataWidth(XbarCfg.AxiDataWidth),
     .AxiIdWidth(AXI_ID_WIDTH_XBAR_MST),
     .RegDataWidth(XbarCfg.AxiDataWidth),
     .axi_req_t(ariane_axi::req_t),
     .axi_rsp_t(ariane_axi::resp_t),
     .reg_req_t(reg_req_t),
     .reg_rsp_t(reg_rsp_t)
   ) i_axi_to_reg_v2 (
     .clk_i(clkwiz_o),
     .rst_ni(rst_n),
     .axi_req_i(xbar_mst_ports_req[MASTER_CLINT_IDX]),
     .axi_rsp_o(xbar_mst_ports_resp[MASTER_CLINT_IDX]),
     .reg_req_o(clint_reg_req),
     .reg_rsp_i(clint_reg_rsp)
   );
 
   clint #(
     .reg_req_t(reg_req_t),
     .reg_rsp_t(reg_rsp_t)
   ) i_clint (
     .clk_i(clkwiz_o),
     .rst_ni(rst_n),
     .testmode_i(1'b0),
     .reg_req_i(clint_reg_req),
     .reg_rsp_o(clint_reg_rsp),
     .rtc_i(1'b0),
     .timer_irq_o(timer_irq),
     .ipi_o(ipi)
   );
 
   import obi_pkg::*;
   localparam obi_pkg::obi_cfg_t AdapterObiCfg = '{
       AddrWidth: XbarCfg.AxiAddrWidth,
       DataWidth: `MEM_W,
       IdWidth:   AXI_ID_WIDTH_XBAR_MST,
       UseRReady: 1'b0,
       CombGnt:   1'b0,
       Integrity: 1'b0,
       BeFull:    1'b1,
       OptionalCfg: '{ UseAtop: 1'b1, UseProt: 1'b0, UseMemtype: 1'b0, UseDbg: 1'b0,
                      AUserWidth: 0, WUserWidth: 0, RUserWidth: 1,
                      MidWidth: 0, AChkWidth: 0, RChkWidth: 0 }
   };

   `OBI_TYPEDEF_ATOP_A_OPTIONAL(adapter_obi_a_optional_t)
   `OBI_TYPEDEF_ALL_R_OPTIONAL(adapter_obi_r_optional_t, AdapterObiCfg.OptionalCfg.RUserWidth, AdapterObiCfg.OptionalCfg.RChkWidth)

   `OBI_TYPEDEF_A_CHAN_T(adapter_obi_a_chan_t, AdapterObiCfg.AddrWidth, AdapterObiCfg.DataWidth, AdapterObiCfg.IdWidth, adapter_obi_a_optional_t)
   `OBI_TYPEDEF_R_CHAN_T(adapter_obi_r_chan_t, AdapterObiCfg.DataWidth, AdapterObiCfg.IdWidth, adapter_obi_r_optional_t)

   `OBI_TYPEDEF_DEFAULT_REQ_T(adapter_obi_req_t, adapter_obi_a_chan_t)
   `OBI_TYPEDEF_RSP_T(adapter_obi_rsp_t, adapter_obi_r_chan_t)

   localparam int unsigned AXI_MAX_TRANS = XbarCfg.MaxMstTrans;

   adapter_obi_req_t mem_obi_req;
   adapter_obi_rsp_t mem_obi_rsp;

   axi_to_obi #(
      .ObiCfg         ( AdapterObiCfg          ),
      .obi_req_t      ( adapter_obi_req_t      ), .obi_rsp_t      ( adapter_obi_rsp_t      ),
      .obi_a_chan_t   ( adapter_obi_a_chan_t   ), .obi_r_chan_t   ( adapter_obi_r_chan_t   ),
      .AxiAddrWidth   ( XbarCfg.AxiAddrWidth   ),
      .AxiDataWidth   ( XbarCfg.AxiDataWidth   ),
      .AxiIdWidth     ( AXI_ID_WIDTH_XBAR_MST  ),
      .AxiUserWidth   ( cva6_config_pkg::CVA6ConfigDataUserWidth),
      .MaxTrans       ( AXI_MAX_TRANS          ),
      .axi_req_t      ( ariane_axi::req_t         ),
      .axi_rsp_t      ( ariane_axi::resp_t        )
   ) i_axi_to_obi_mem (
      .clk_i        ( clkwiz_o                              ),
      .rst_ni       ( rst_n                                 ),
      .testmode_i   ( 1'b0                                  ),

      .axi_req_i    ( xbar_mst_ports_req[MASTER_RAM_IDX]    ),
      .axi_rsp_o    ( xbar_mst_ports_resp[MASTER_RAM_IDX]   ),

      .obi_req_o    ( mem_obi_req                           ),
      .obi_rsp_i    ( mem_obi_rsp                           ),

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

   logic        ram_req_i;
   logic        ram_we_i;
   logic [AdapterObiCfg.DataWidth/8-1:0] ram_be_i;
   logic [AdapterObiCfg.AddrWidth-1:0] ram_addr_i;
   logic [AdapterObiCfg.DataWidth-1:0] ram_wdata_i;
   logic        ram_rvalid_o;
   logic [AdapterObiCfg.DataWidth-1:0] ram_rdata_o;

   assign ram_req_i   = mem_obi_req.req;
   assign ram_we_i    = mem_obi_req.a.we;
   assign ram_addr_i  = mem_obi_req.a.addr[31:0];
   assign ram_wdata_i = mem_obi_req.a.wdata;
   assign ram_be_i    = mem_obi_req.a.be;

   assign mem_obi_rsp.gnt    = 1;
   assign mem_obi_rsp.rvalid = ram_rvalid_o;
   assign mem_obi_rsp.r.rdata = ram_rdata_o;
   assign mem_obi_rsp.r.rid   = mem_obi_req.a.aid;
   assign mem_obi_rsp.r.err  = 1'b0;

   // TODO: Handle atomics with wrapper

   logic uart_dram_write_we;
   logic [31:0] uart_dram_write_addr;
   logic [31:0] uart_dram_write_data;

   ram32_dwr #(
      .SIZE     (`RAM_SIZE / 4),
      .INIT_FILE(`RAM_FPATH)
   ) main_memory (
      .clk_i   (clkwiz_o),
      .rst_ni  (rst_ni `ifdef BASYS3 & clkwiz_locked `endif), // pll_locked
      .req_i   ( ram_req_i      ),
      .we_i    ( ram_we_i       ),
      .be_i    ( ram_be_i       ),
      .addr_i  ( ram_addr_i     ),
      .wdata_i ( ram_wdata_i    ),
      .rvalid_o( ram_rvalid_o   ),
      .rdata_o ( ram_rdata_o    )

      ,.program_rx_i   ( program_rx_i   )
      ,.system_reset_o ( system_reset_o )
      ,.prog_mode_led_o( prog_mode_led_o)

      ,.dram_write_we_o(uart_dram_write_we)
      ,.dram_write_addr_o(uart_dram_write_addr)
      ,.dram_write_data_o(uart_dram_write_data)
      ,.dram_write_rst_o(uart_dram_write_rst)
      ,.dram_mode_o    ( uart_dram_mode )
   );

   logic                            uart_axi_awvalid;
   logic                            uart_axi_awready;
   logic [XbarCfg.AxiAddrWidth-1:0] uart_axi_awaddr;
   logic [AXI_ID_WIDTH_XBAR_MST-1:0]uart_axi_awid;
   logic [2:0]                      uart_axi_awprot;
   logic                            uart_axi_wvalid;
   logic                            uart_axi_wready;
   logic [XbarCfg.AxiDataWidth-1:0] uart_axi_wdata;
   logic [XbarCfg.AxiDataWidth/8-1:0] uart_axi_wstrb;
   logic                            uart_axi_bvalid;
   logic                            uart_axi_bready;
   logic [AXI_ID_WIDTH_XBAR_MST-1:0]uart_axi_bid;
   logic [1:0]                      uart_axi_bresp;
   logic                            uart_axi_arvalid;
   logic                            uart_axi_arready;
   logic [XbarCfg.AxiAddrWidth-1:0] uart_axi_araddr;
   logic [AXI_ID_WIDTH_XBAR_MST-1:0]uart_axi_arid;
   logic [2:0]                      uart_axi_arprot;
   logic                            uart_axi_rvalid;
   logic                            uart_axi_rready;
   logic [AXI_ID_WIDTH_XBAR_MST-1:0]uart_axi_rid;
   logic [XbarCfg.AxiDataWidth-1:0] uart_axi_rdata;
   logic [1:0]                      uart_axi_rresp;

   assign uart_axi_awvalid = xbar_mst_ports_req[MASTER_UART_IDX].aw_valid;
   assign uart_axi_awaddr  = xbar_mst_ports_req[MASTER_UART_IDX].aw.addr;
   assign uart_axi_awid    = xbar_mst_ports_req[MASTER_UART_IDX].aw.id;
   assign uart_axi_awprot  = xbar_mst_ports_req[MASTER_UART_IDX].aw.prot;

   assign uart_axi_wvalid  = xbar_mst_ports_req[MASTER_UART_IDX].w_valid;
   assign uart_axi_wdata   = xbar_mst_ports_req[MASTER_UART_IDX].w.data;
   assign uart_axi_wstrb   = xbar_mst_ports_req[MASTER_UART_IDX].w.strb;

   assign uart_axi_arvalid = xbar_mst_ports_req[MASTER_UART_IDX].ar_valid;
   assign uart_axi_araddr  = xbar_mst_ports_req[MASTER_UART_IDX].ar.addr;
   assign uart_axi_arid    = xbar_mst_ports_req[MASTER_UART_IDX].ar.id;
   assign uart_axi_arprot  = xbar_mst_ports_req[MASTER_UART_IDX].ar.prot;

   assign uart_axi_bready  = xbar_mst_ports_req[MASTER_UART_IDX].b_ready;
   assign uart_axi_rready  = xbar_mst_ports_req[MASTER_UART_IDX].r_ready;


   assign xbar_mst_ports_resp[MASTER_UART_IDX].aw_ready = uart_axi_awready;
   assign xbar_mst_ports_resp[MASTER_UART_IDX].w_ready  = uart_axi_wready;
   assign xbar_mst_ports_resp[MASTER_UART_IDX].ar_ready = uart_axi_arready;
   assign xbar_mst_ports_resp[MASTER_UART_IDX].b_valid  = uart_axi_bvalid;
   assign xbar_mst_ports_resp[MASTER_UART_IDX].b.id     = uart_axi_bid;
   assign xbar_mst_ports_resp[MASTER_UART_IDX].b.resp   = uart_axi_bresp;
   assign xbar_mst_ports_resp[MASTER_UART_IDX].r_valid  = uart_axi_rvalid;
   assign xbar_mst_ports_resp[MASTER_UART_IDX].r.id     = uart_axi_rid;
   assign xbar_mst_ports_resp[MASTER_UART_IDX].r.data   = uart_axi_rdata;
   assign xbar_mst_ports_resp[MASTER_UART_IDX].r.resp   = uart_axi_rresp;
   assign xbar_mst_ports_resp[MASTER_UART_IDX].r.last   = 1'b1; // AXI-Lite

   uart_controller_axi #(
       .AXI_ID_WIDTH  (AXI_ID_WIDTH_XBAR_MST),
       .AXI_ADDR_WIDTH(XbarCfg.AxiAddrWidth),
       .AXI_DATA_WIDTH(XbarCfg.AxiDataWidth)
   ) uart_dut (
       .clk_i   ( clkwiz_o      ), .rst_ni  ( rst_n         ),
       .s_axi_awvalid(uart_axi_awvalid), .s_axi_awready(uart_axi_awready),
       .s_axi_awaddr (uart_axi_awaddr),  .s_axi_awid   (uart_axi_awid),
       .s_axi_awprot (uart_axi_awprot),
       .s_axi_wvalid (uart_axi_wvalid),  .s_axi_wready (uart_axi_wready),
       .s_axi_wdata  (uart_axi_wdata),   .s_axi_wstrb  (uart_axi_wstrb),
       .s_axi_bvalid (uart_axi_bvalid),  .s_axi_bready (uart_axi_bready),
       .s_axi_bid    (uart_axi_bid),     .s_axi_bresp  (uart_axi_bresp),
       .s_axi_arvalid(uart_axi_arvalid), .s_axi_arready(uart_axi_arready),
       .s_axi_araddr (uart_axi_araddr),  .s_axi_arid   (uart_axi_arid),
       .s_axi_arprot (uart_axi_arprot),
       .s_axi_rvalid (uart_axi_rvalid),  .s_axi_rready (uart_axi_rready),
       .s_axi_rid    (uart_axi_rid),     .s_axi_rdata  (uart_axi_rdata),
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

   assign timer_axi_awvalid = xbar_mst_ports_req[MASTER_TIMER_IDX].aw_valid;
   assign timer_axi_awaddr  = xbar_mst_ports_req[MASTER_TIMER_IDX].aw.addr;
   assign timer_axi_awid    = xbar_mst_ports_req[MASTER_TIMER_IDX].aw.id;
   assign timer_axi_awprot  = xbar_mst_ports_req[MASTER_TIMER_IDX].aw.prot;
   assign timer_axi_wvalid  = xbar_mst_ports_req[MASTER_TIMER_IDX].w_valid;
   assign timer_axi_wdata   = xbar_mst_ports_req[MASTER_TIMER_IDX].w.data;
   assign timer_axi_wstrb   = xbar_mst_ports_req[MASTER_TIMER_IDX].w.strb;
   assign timer_axi_arvalid = xbar_mst_ports_req[MASTER_TIMER_IDX].ar_valid;
   assign timer_axi_araddr  = xbar_mst_ports_req[MASTER_TIMER_IDX].ar.addr;
   assign timer_axi_arid    = xbar_mst_ports_req[MASTER_TIMER_IDX].ar.id;
   assign timer_axi_arprot  = xbar_mst_ports_req[MASTER_TIMER_IDX].ar.prot;
   assign timer_axi_bready  = xbar_mst_ports_req[MASTER_TIMER_IDX].b_ready;
   assign timer_axi_rready  = xbar_mst_ports_req[MASTER_TIMER_IDX].r_ready;

   assign xbar_mst_ports_resp[MASTER_TIMER_IDX].aw_ready = timer_axi_awready;
   assign xbar_mst_ports_resp[MASTER_TIMER_IDX].w_ready  = timer_axi_wready;
   assign xbar_mst_ports_resp[MASTER_TIMER_IDX].ar_ready = timer_axi_arready;
   assign xbar_mst_ports_resp[MASTER_TIMER_IDX].b_valid  = timer_axi_bvalid;
   assign xbar_mst_ports_resp[MASTER_TIMER_IDX].b.id     = timer_axi_bid;
   assign xbar_mst_ports_resp[MASTER_TIMER_IDX].b.resp   = timer_axi_bresp;
   assign xbar_mst_ports_resp[MASTER_TIMER_IDX].r_valid  = timer_axi_rvalid;
   assign xbar_mst_ports_resp[MASTER_TIMER_IDX].r.id     = timer_axi_rid;
   assign xbar_mst_ports_resp[MASTER_TIMER_IDX].r.data   = timer_axi_rdata;
   assign xbar_mst_ports_resp[MASTER_TIMER_IDX].r.resp   = timer_axi_rresp;
   assign xbar_mst_ports_resp[MASTER_TIMER_IDX].r.last   = 1'b1;

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

   `ifdef DRAM_SIM
   wire ddr3_reset_n;
   wire ddr3_cke;
   wire ddr3_ck_p;
   wire ddr3_ck_n;
   wire ddr3_cs_n;
   wire ddr3_ras_n;
   wire ddr3_cas_n;
   wire ddr3_we_n;
   wire [2:0] ddr3_ba;
   wire [13:0] ddr3_addr;
   wire ddr3_odt;
   wire [1:0] ddr3_dm;
   wire [1:0] ddr3_dqs_p;
   wire [1:0] ddr3_dqs_n;
   wire [15:0] ddr3_dq;

   //`define den1024Mb
   //`include "1024Mb_ddr3_parameters.vh"

   ddr3 ddr3_dut (
      .rst_n  (ddr3_reset_n),
      .ck     (ddr3_ck_p),
      .ck_n   (ddr3_ck_n),
      .cke    (ddr3_cke),
      .cs_n   (ddr3_cs_n),
      .ras_n  (ddr3_ras_n),
      .cas_n  (ddr3_cas_n),
      .we_n   (ddr3_we_n),
      .dm_tdqs(ddr3_dm),
      .ba     (ddr3_ba),
      .addr   (ddr3_addr),
      .dq     (ddr3_dq),
      .dqs    (ddr3_dqs_p),
      .dqs_n  (ddr3_dqs_n),
      .tdqs_n (),
      .odt    (ddr3_odt)
   );
   `endif

   `ifdef ZC706
   logic                            dram_axi_awvalid;
   logic                            dram_axi_awready;
   logic [XbarCfg.AxiAddrWidth-1:0] dram_axi_awaddr;
   logic [AXI_ID_WIDTH_XBAR_MST-1:0]dram_axi_awid;
   logic [7:0]                      dram_axi_awlen;
   logic [2:0]                      dram_axi_awsize;
   logic [1:0]                      dram_axi_awburst;
   logic [2:0]                      dram_axi_awprot;
   logic                            dram_axi_wvalid;
   logic                            dram_axi_wready;
   logic [XbarCfg.AxiDataWidth-1:0] dram_axi_wdata;
   logic [XbarCfg.AxiDataWidth/8-1:0] dram_axi_wstrb;
   logic                            dram_axi_wlast;
   logic                            dram_axi_bvalid;
   logic                            dram_axi_bready;
   logic [AXI_ID_WIDTH_XBAR_MST-1:0]dram_axi_bid;
   logic [1:0]                      dram_axi_bresp;
   logic                            dram_axi_arvalid;
   logic                            dram_axi_arready;
   logic [XbarCfg.AxiAddrWidth-1:0] dram_axi_araddr;
   logic [AXI_ID_WIDTH_XBAR_MST-1:0]dram_axi_arid;
   logic [7:0]                      dram_axi_arlen;
   logic [2:0]                      dram_axi_arsize;
   logic [1:0]                      dram_axi_arburst;
   logic [2:0]                      dram_axi_arprot;
   logic                            dram_axi_rvalid;
   logic                            dram_axi_rready;
   logic [AXI_ID_WIDTH_XBAR_MST-1:0]dram_axi_rid;
   logic [XbarCfg.AxiDataWidth-1:0] dram_axi_rdata;
   logic [1:0]                      dram_axi_rresp;
   logic                            dram_axi_rlast;

   assign dram_axi_awvalid = xbar_mst_ports_req[MASTER_DRAM_IDX].aw_valid;
   assign dram_axi_awaddr  = xbar_mst_ports_req[MASTER_DRAM_IDX].aw.addr;
   assign dram_axi_awid    = xbar_mst_ports_req[MASTER_DRAM_IDX].aw.id;
   assign dram_axi_awlen   = xbar_mst_ports_req[MASTER_DRAM_IDX].aw.len;
   assign dram_axi_awsize  = xbar_mst_ports_req[MASTER_DRAM_IDX].aw.size;
   assign dram_axi_awburst = xbar_mst_ports_req[MASTER_DRAM_IDX].aw.burst;
   assign dram_axi_awprot  = xbar_mst_ports_req[MASTER_DRAM_IDX].aw.prot;
   assign dram_axi_wvalid  = xbar_mst_ports_req[MASTER_DRAM_IDX].w_valid;
   assign dram_axi_wdata   = xbar_mst_ports_req[MASTER_DRAM_IDX].w.data;
   assign dram_axi_wstrb   = xbar_mst_ports_req[MASTER_DRAM_IDX].w.strb;
   assign dram_axi_wlast   = xbar_mst_ports_req[MASTER_DRAM_IDX].w.last;
   assign dram_axi_arvalid = xbar_mst_ports_req[MASTER_DRAM_IDX].ar_valid;
   assign dram_axi_araddr  = xbar_mst_ports_req[MASTER_DRAM_IDX].ar.addr;
   assign dram_axi_arid    = xbar_mst_ports_req[MASTER_DRAM_IDX].ar.id;
   assign dram_axi_arlen   = xbar_mst_ports_req[MASTER_DRAM_IDX].ar.len;
   assign dram_axi_arsize  = xbar_mst_ports_req[MASTER_DRAM_IDX].ar.size;
   assign dram_axi_arburst = xbar_mst_ports_req[MASTER_DRAM_IDX].ar.burst;
   assign dram_axi_arprot  = xbar_mst_ports_req[MASTER_DRAM_IDX].ar.prot;
   assign dram_axi_bready  = xbar_mst_ports_req[MASTER_DRAM_IDX].b_ready;
   assign dram_axi_rready  = xbar_mst_ports_req[MASTER_DRAM_IDX].r_ready;

   assign xbar_mst_ports_resp[MASTER_DRAM_IDX].aw_ready = dram_axi_awready;
   assign xbar_mst_ports_resp[MASTER_DRAM_IDX].w_ready  = dram_axi_wready;
   assign xbar_mst_ports_resp[MASTER_DRAM_IDX].ar_ready = dram_axi_arready;
   assign xbar_mst_ports_resp[MASTER_DRAM_IDX].b_valid  = dram_axi_bvalid;
   assign xbar_mst_ports_resp[MASTER_DRAM_IDX].b.id     = dram_axi_bid;
   assign xbar_mst_ports_resp[MASTER_DRAM_IDX].b.resp   = dram_axi_bresp;
   assign xbar_mst_ports_resp[MASTER_DRAM_IDX].r_valid  = dram_axi_rvalid;
   assign xbar_mst_ports_resp[MASTER_DRAM_IDX].r.id     = dram_axi_rid;
   assign xbar_mst_ports_resp[MASTER_DRAM_IDX].r.data   = dram_axi_rdata;
   assign xbar_mst_ports_resp[MASTER_DRAM_IDX].r.resp   = dram_axi_rresp;
   assign xbar_mst_ports_resp[MASTER_DRAM_IDX].r.last   = dram_axi_rlast;

   dram_controller_axi #(
       .AXI_ID_WIDTH  (AXI_ID_WIDTH_XBAR_MST),
       .AXI_ADDR_WIDTH(XbarCfg.AxiAddrWidth),
       .AXI_DATA_WIDTH(XbarCfg.AxiDataWidth)
   ) dram_dut (
       .clk_i        ( clkwiz_o         ),
       .rst_ni       ( (rst_ni & system_reset_o & pll_locked) || uart_dram_mode ),

       .s_axi_awvalid( dram_axi_awvalid ),
       .s_axi_awready( dram_axi_awready ),
       .s_axi_awaddr ( dram_axi_awaddr  ),
       .s_axi_awid   ( dram_axi_awid    ),
       .s_axi_awlen  ( dram_axi_awlen   ),
       .s_axi_awsize ( dram_axi_awsize  ),
       .s_axi_awburst( dram_axi_awburst ),
       .s_axi_awprot ( dram_axi_awprot  ),

       .s_axi_wvalid ( dram_axi_wvalid  ),
       .s_axi_wready ( dram_axi_wready  ),
       .s_axi_wdata  ( dram_axi_wdata   ),
       .s_axi_wstrb  ( dram_axi_wstrb   ),
       .s_axi_wlast  ( dram_axi_wlast   ),

       .s_axi_bvalid ( dram_axi_bvalid  ),
       .s_axi_bready ( dram_axi_bready  ),
       .s_axi_bid    ( dram_axi_bid     ),
       .s_axi_bresp  ( dram_axi_bresp   ),

       .s_axi_arvalid( dram_axi_arvalid ),
       .s_axi_arready( dram_axi_arready ),
       .s_axi_araddr ( dram_axi_araddr  ),
       .s_axi_arid   ( dram_axi_arid    ),
       .s_axi_arlen  ( dram_axi_arlen   ),
       .s_axi_arsize ( dram_axi_arsize  ),
       .s_axi_arburst( dram_axi_arburst ),
       .s_axi_arprot ( dram_axi_arprot  ),

       .s_axi_rvalid ( dram_axi_rvalid  ),
       .s_axi_rready ( dram_axi_rready  ),
       .s_axi_rid    ( dram_axi_rid     ),
       .s_axi_rdata  ( dram_axi_rdata   ),
       .s_axi_rresp  ( dram_axi_rresp   ),
       .s_axi_rlast  ( dram_axi_rlast   ),

       .ddr3_reset_n( ddr3_reset_n ),
       .ddr3_cke    ( ddr3_cke     ),
       .ddr3_ck_p   ( ddr3_ck_p    ),
       .ddr3_ck_n   ( ddr3_ck_n    ),
       .ddr3_cs_n   ( ddr3_cs_n    ),
       .ddr3_ras_n  ( ddr3_ras_n   ),
       .ddr3_cas_n  ( ddr3_cas_n   ),
       .ddr3_we_n   ( ddr3_we_n    ),
       .ddr3_ba     ( ddr3_ba      ),
       .ddr3_addr   ( ddr3_addr    ),
       .ddr3_odt    ( ddr3_odt     ),
       .ddr3_dm     ( ddr3_dm      ),
       .ddr3_dqs_p  ( ddr3_dqs_p   ),
       .ddr3_dqs_n  ( ddr3_dqs_n   ),
       .ddr3_dq     ( ddr3_dq      ),

       .clk100      ( clk100       ),
       .clk_ddr     ( clk_ddr      ),
       .clk_ref     ( clk_ref      ),
       .clk_ddr_dqs ( clk_ddr_dqs  )

       ,.uart_dram_write_we_i (uart_dram_write_we),
       .uart_dram_write_addr_i (uart_dram_write_addr),
       .uart_dram_write_data_i (uart_dram_write_data),
       .uart_dram_write_rst_i (0)
   );
   `elsif USE_SRAM
   adapter_obi_req_t mem8_obi_req;
   adapter_obi_rsp_t mem8_obi_rsp;

   axi_to_obi #(
      .ObiCfg         ( AdapterObiCfg          ),
      .obi_req_t      ( adapter_obi_req_t      ),
      .obi_rsp_t      ( adapter_obi_rsp_t      ),
      .obi_a_chan_t   ( adapter_obi_a_chan_t   ),
      .obi_r_chan_t   ( adapter_obi_r_chan_t   ),
      .AxiAddrWidth   ( XbarCfg.AxiAddrWidth   ),
      .AxiDataWidth   ( XbarCfg.AxiDataWidth   ),
      .AxiIdWidth     ( AXI_ID_WIDTH_XBAR_MST  ),
      .AxiUserWidth   ( cva6_config_pkg::CVA6ConfigDataUserWidth ),
      .MaxTrans       ( AXI_MAX_TRANS          ),
      .axi_req_t      ( ariane_axi::req_t      ),
      .axi_rsp_t      ( ariane_axi::resp_t     )
   ) i_axi_to_obi_mem8 (
      .clk_i        ( clkwiz_o                            ),
      .rst_ni       ( rst_n                               ),
      .testmode_i   ( 1'b0                                ),
      .axi_req_i    ( xbar_mst_ports_req[MASTER_DRAM_IDX]  ),
      .axi_rsp_o    ( xbar_mst_ports_resp[MASTER_DRAM_IDX] ),
      .obi_req_o    ( mem8_obi_req                         ),
      .obi_rsp_i    ( mem8_obi_rsp                         ),
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

   logic        ram8_req_i;
   logic        ram8_we_i;
   logic [AdapterObiCfg.DataWidth/8-1:0] ram8_be_i;
   logic [AdapterObiCfg.AddrWidth-1:0] ram8_addr_i;
   logic [AdapterObiCfg.DataWidth-1:0] ram8_wdata_i;
   logic        ram8_rvalid_o;
   logic [AdapterObiCfg.DataWidth-1:0] ram8_rdata_o;

   assign ram8_req_i   = mem8_obi_req.req;
   assign ram8_we_i    = mem8_obi_req.a.we;
   assign ram8_addr_i  = mem8_obi_req.a.addr[30:0];
   assign ram8_wdata_i = mem8_obi_req.a.wdata;
   assign ram8_be_i    = mem8_obi_req.a.be;

   assign mem8_obi_rsp.gnt    = 1;
   assign mem8_obi_rsp.rvalid = ram8_rvalid_o;
   assign mem8_obi_rsp.r.rdata = ram8_rdata_o;
   assign mem8_obi_rsp.r.rid   = mem8_obi_req.a.aid;
   assign mem8_obi_rsp.r.err  = 1'b0;

   ram32 #(
      .SIZE     ('h40000/4),
      .INIT_FILE(`RAM_FPATH),
      .USE_BOOTROM(0)
   ) main_memory8 (
      .clk_i   (clkwiz_o),
      .rst_ni  (rst_n),
      .req_i   ( ram8_req_i      ),
      .we_i    ( ram8_we_i       ),
      .be_i    ( ram8_be_i       ),
      .addr_i  ( ram8_addr_i     ),
      .wdata_i ( ram8_wdata_i    ),
      .rvalid_o( ram8_rvalid_o   ),
      .rdata_o ( ram8_rdata_o    )

      ,.program_rx_i   (    )
      ,.system_reset_o (  )
      ,.prog_mode_led_o( )
   );
   `elsif DDR3_AXI
   logic                            dram_axi_awvalid;
   logic                            dram_axi_awready;
   logic [XbarCfg.AxiAddrWidth-1:0] dram_axi_awaddr;
   logic [AXI_ID_WIDTH_XBAR_MST-1:0]dram_axi_awid;
   logic [7:0]                      dram_axi_awlen;
   logic [1:0]                      dram_axi_awburst;
   logic [2:0]                      dram_axi_awprot;
   logic                            dram_axi_wvalid;
   logic                            dram_axi_wready;
   logic [XbarCfg.AxiDataWidth-1:0] dram_axi_wdata;
   logic [XbarCfg.AxiDataWidth/8-1:0] dram_axi_wstrb;
   logic                            dram_axi_wlast;
   logic                            dram_axi_bvalid;
   logic                            dram_axi_bready;
   logic [AXI_ID_WIDTH_XBAR_MST-1:0]dram_axi_bid;
   logic [1:0]                      dram_axi_bresp;
   logic                            dram_axi_arvalid;
   logic                            dram_axi_arready;
   logic [XbarCfg.AxiAddrWidth-1:0] dram_axi_araddr;
   logic [AXI_ID_WIDTH_XBAR_MST-1:0]dram_axi_arid;
   logic [7:0]                      dram_axi_arlen;
   logic [1:0]                      dram_axi_arburst;
   logic [2:0]                      dram_axi_arprot;
   logic                            dram_axi_rvalid;
   logic                            dram_axi_rready;
   logic [AXI_ID_WIDTH_XBAR_MST-1:0]dram_axi_rid;
   logic [XbarCfg.AxiDataWidth-1:0] dram_axi_rdata;
   logic [1:0]                      dram_axi_rresp;
   logic                            dram_axi_rlast;

   assign dram_axi_awvalid = xbar_mst_ports_req[MASTER_DRAM_IDX].aw_valid;
   assign dram_axi_awaddr  = xbar_mst_ports_req[MASTER_DRAM_IDX].aw.addr;
   assign dram_axi_awid    = xbar_mst_ports_req[MASTER_DRAM_IDX].aw.id;
   assign dram_axi_awlen   = xbar_mst_ports_req[MASTER_DRAM_IDX].aw.len;
   assign dram_axi_awburst = xbar_mst_ports_req[MASTER_DRAM_IDX].aw.burst;
   assign dram_axi_awprot  = xbar_mst_ports_req[MASTER_DRAM_IDX].aw.prot;

   assign dram_axi_wvalid  = xbar_mst_ports_req[MASTER_DRAM_IDX].w_valid;
   assign dram_axi_wdata   = xbar_mst_ports_req[MASTER_DRAM_IDX].w.data;
   assign dram_axi_wstrb   = xbar_mst_ports_req[MASTER_DRAM_IDX].w.strb;
   assign dram_axi_wlast   = xbar_mst_ports_req[MASTER_DRAM_IDX].w.last;

   assign dram_axi_arvalid = xbar_mst_ports_req[MASTER_DRAM_IDX].ar_valid;
   assign dram_axi_araddr  = xbar_mst_ports_req[MASTER_DRAM_IDX].ar.addr;
   assign dram_axi_arid    = xbar_mst_ports_req[MASTER_DRAM_IDX].ar.id;
   assign dram_axi_arlen   = xbar_mst_ports_req[MASTER_DRAM_IDX].ar.len;
   assign dram_axi_arburst = xbar_mst_ports_req[MASTER_DRAM_IDX].ar.burst;
   assign dram_axi_arprot  = xbar_mst_ports_req[MASTER_DRAM_IDX].ar.prot;

   assign dram_axi_bready  = xbar_mst_ports_req[MASTER_DRAM_IDX].b_ready;
   assign dram_axi_rready  = xbar_mst_ports_req[MASTER_DRAM_IDX].r_ready;

   assign xbar_mst_ports_resp[MASTER_DRAM_IDX].aw_ready = dram_axi_awready;
   assign xbar_mst_ports_resp[MASTER_DRAM_IDX].w_ready  = dram_axi_wready;
   assign xbar_mst_ports_resp[MASTER_DRAM_IDX].ar_ready = dram_axi_arready;

   assign xbar_mst_ports_resp[MASTER_DRAM_IDX].b_valid  = dram_axi_bvalid;
   assign xbar_mst_ports_resp[MASTER_DRAM_IDX].b.id     = dram_axi_bid;
   assign xbar_mst_ports_resp[MASTER_DRAM_IDX].b.resp   = dram_axi_bresp;

   assign xbar_mst_ports_resp[MASTER_DRAM_IDX].r_valid  = dram_axi_rvalid;
   assign xbar_mst_ports_resp[MASTER_DRAM_IDX].r.id     = dram_axi_rid;
   assign xbar_mst_ports_resp[MASTER_DRAM_IDX].r.data   = dram_axi_rdata;
   assign xbar_mst_ports_resp[MASTER_DRAM_IDX].r.resp   = dram_axi_rresp;
   assign xbar_mst_ports_resp[MASTER_DRAM_IDX].r.last   = dram_axi_rlast;

   logic [14:0] dfi_address_to_phy_w;
   logic [2:0]  dfi_bank_to_phy_w;
   logic        dfi_cas_n_to_phy_w;
   logic        dfi_cke_to_phy_w;
   logic        dfi_cs_n_to_phy_w;
   logic        dfi_odt_to_phy_w;
   logic        dfi_ras_n_to_phy_w;
   logic        dfi_reset_n_to_phy_w;
   logic        dfi_we_n_to_phy_w;
   logic [XbarCfg.AxiDataWidth-1:0] dfi_wrdata_to_phy_w;
   logic        dfi_wrdata_en_to_phy_w;
   logic [XbarCfg.AxiDataWidth/8/2-1:0]  dfi_wrdata_mask_to_phy_w;
   logic        dfi_rddata_en_to_phy_w;

   logic [XbarCfg.AxiDataWidth-1:0] dfi_rddata_from_phy_w;
   logic        dfi_rddata_valid_from_phy_w;
   logic [XbarCfg.AxiDataWidth/32-1:0]  dfi_rddata_dnv_from_phy_w;

   ddr3_axi #(
      .DDR_MHZ          ( `DDR_MHZ ),
      .DDR_WRITE_LATENCY( 4 ),
      .DDR_READ_LATENCY ( 4 )
   ) i_ddr3_axi (
      .clk_i   ( clkwiz_o ),
      .rst_i   ( ~rst_n   ),

      .inport_awvalid_i ( dram_axi_awvalid ),
      .inport_awaddr_i  ( dram_axi_awaddr ),
      .inport_awid_i    ( dram_axi_awid    ),
      .inport_awlen_i   ( dram_axi_awlen        ),
      .inport_awburst_i ( dram_axi_awburst      ),
      .inport_awready_o ( dram_axi_awready      ),

      .inport_wvalid_i  ( dram_axi_wvalid  ),
      .inport_wdata_i   ( dram_axi_wdata   ),
      .inport_wstrb_i   ( dram_axi_wstrb   ),
      .inport_wlast_i   ( dram_axi_wlast   ),
      .inport_wready_o  ( dram_axi_wready  ),

      .inport_bready_i  ( dram_axi_bready  ),
      .inport_bvalid_o  ( dram_axi_bvalid  ),
      .inport_bresp_o   ( dram_axi_bresp   ),
      .inport_bid_o     ( dram_axi_bid     ),

      .inport_arvalid_i ( dram_axi_arvalid ),
      .inport_araddr_i  ( dram_axi_araddr ),
      .inport_arid_i    ( dram_axi_arid    ),
      .inport_arlen_i   ( dram_axi_arlen        ),
      .inport_arburst_i ( dram_axi_arburst      ),
      .inport_arready_o ( dram_axi_arready      ),

      .inport_rready_i  ( dram_axi_rready  ),
      .inport_rvalid_o  ( dram_axi_rvalid  ),
      .inport_rdata_o   ( dram_axi_rdata   ),
      .inport_rresp_o   ( dram_axi_rresp   ),
      .inport_rid_o     ( dram_axi_rid     ),
      .inport_rlast_o   ( dram_axi_rlast   ),

      .dfi_rddata_i       ( dfi_rddata_from_phy_w       ),
      .dfi_rddata_valid_i ( dfi_rddata_valid_from_phy_w ),
      .dfi_rddata_dnv_i   ( dfi_rddata_dnv_from_phy_w   ),

      .dfi_address_o     ( dfi_address_to_phy_w         ),
      .dfi_bank_o        ( dfi_bank_to_phy_w            ),
      .dfi_cas_n_o       ( dfi_cas_n_to_phy_w           ),
      .dfi_cke_o         ( dfi_cke_to_phy_w             ),
      .dfi_cs_n_o        ( dfi_cs_n_to_phy_w            ),
      .dfi_odt_o         ( dfi_odt_to_phy_w             ),
      .dfi_ras_n_o       ( dfi_ras_n_to_phy_w           ),
      .dfi_reset_n_o     ( dfi_reset_n_to_phy_w         ),
      .dfi_we_n_o        ( dfi_we_n_to_phy_w            ),
      .dfi_wrdata_o      ( dfi_wrdata_to_phy_w          ),
      .dfi_wrdata_en_o   ( dfi_wrdata_en_to_phy_w       ),
      .dfi_wrdata_mask_o ( dfi_wrdata_mask_to_phy_w     ),
      .dfi_rddata_en_o   ( dfi_rddata_en_to_phy_w       )
   );

   ddr3_dfi_phy 
   #(
     .DQS_TAP_DELAY_INIT(27)
    ,.DQ_TAP_DELAY_INIT(0)
    ,.TPHY_RDLAT(5)
   )
   i_ddr3_dfi_phy (
       .clk_i         ( clk100      ),
       .clk_ddr_i     ( clk_ddr     ),
       .clk_ddr90_i   ( clk_ddr_dqs ),
       .clk_ref_i     ( clk_ref     ),
       .rst_i         ( ~rst_n      ),

       .cfg_valid_i   ( 1'b0 ),
       .cfg_i         ( '0   ),

       .dfi_address_i     ( dfi_address_to_phy_w         ),
       .dfi_bank_i        ( dfi_bank_to_phy_w            ),
       .dfi_cas_n_i       ( dfi_cas_n_to_phy_w           ),
       .dfi_cke_i         ( dfi_cke_to_phy_w             ),
       .dfi_cs_n_i        ( dfi_cs_n_to_phy_w            ),
       .dfi_odt_i         ( dfi_odt_to_phy_w             ),
       .dfi_ras_n_i       ( dfi_ras_n_to_phy_w           ),
       .dfi_reset_n_i     ( dfi_reset_n_to_phy_w         ),
       .dfi_we_n_i        ( dfi_we_n_to_phy_w            ),
       .dfi_wrdata_i      ( dfi_wrdata_to_phy_w          ),
       .dfi_wrdata_en_i   ( dfi_wrdata_en_to_phy_w       ),
       .dfi_wrdata_mask_i ( dfi_wrdata_mask_to_phy_w     ),
       .dfi_rddata_en_i   ( dfi_rddata_en_to_phy_w       ),

       .dfi_rddata_o       ( dfi_rddata_from_phy_w        ),
       .dfi_rddata_valid_o ( dfi_rddata_valid_from_phy_w  ),
       .dfi_rddata_dnv_o   ( dfi_rddata_dnv_from_phy_w    ),

       .ddr3_ck_p_o   ( ddr3_ck_p   ),
       .ddr3_ck_n_o   ( ddr3_ck_n   ),
       .ddr3_cke_o    ( ddr3_cke    ),
       .ddr3_reset_n_o( ddr3_reset_n),
       .ddr3_ras_n_o  ( ddr3_ras_n  ),
       .ddr3_cas_n_o  ( ddr3_cas_n  ),
       .ddr3_we_n_o   ( ddr3_we_n   ),
       .ddr3_cs_n_o   ( ddr3_cs_n   ),
       .ddr3_ba_o     ( ddr3_ba     ),
       .ddr3_addr_o   ( ddr3_addr   ),
       .ddr3_odt_o    ( ddr3_odt    ),
       .ddr3_dm_o     ( ddr3_dm     ),
       .ddr3_dqs_p_io ( ddr3_dqs_p  ),
       .ddr3_dqs_n_io ( ddr3_dqs_n  ),
       .ddr3_dq_io    ( ddr3_dq     )
   );
   `endif

endmodule
