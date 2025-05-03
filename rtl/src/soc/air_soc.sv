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
      .noc_req_o            ( cva6_axi_req                 ),
      .noc_resp_i           ( cva6_axi_resp                )
   );

   import obi_pkg::*;

   // --- OBI Interface (Adapter <-> Shim) ---
   // Define the OBI configuration between adapter and shim
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

   // --- OBI Crossbar (XBAR) ---
   localparam int unsigned NUM_SLAVES = 4;
   localparam int unsigned SLAVE_RAM_IDX  = 0;
   localparam int unsigned SLAVE_UART_IDX = 1;
   localparam int unsigned SLAVE_TIMR_IDX = 2;
   localparam int unsigned SLAVE_QSPI_IDX = 3;

   // Define the address map rule structure based on AddrWidth
   typedef struct packed {
      logic [AdapterObiCfg.AddrWidth-1:0] addr_base;
      logic [AdapterObiCfg.AddrWidth-1:0] addr_mask;
   } addr_map_rule_t;

   // Define the address map rules
   // Mask = ~(Range - 1) assuming range is power of 2
   // Be careful with mask calculation if range is not power of 2
   localparam bit [AdapterObiCfg.AddrWidth-1:0] MASK_RAM  = ~(`MEM_RANGE  - 1);
   localparam bit [AdapterObiCfg.AddrWidth-1:0] MASK_UART = ~(`UART_RANGE - 1);
   localparam bit [AdapterObiCfg.AddrWidth-1:0] MASK_TIMR = ~(`TIMER_RANGE- 1);
   localparam bit [AdapterObiCfg.AddrWidth-1:0] MASK_QSPI = ~(`QSPI_RANGE- 1);

   localparam addr_map_rule_t ADDR_MAP [NUM_SLAVES-1:0] = '{
      '{ addr_base: `MEM_BASE_ADDR,  addr_mask: MASK_RAM  }, // Rule 0 -> RAM
      '{ addr_base: `UART_BASE_ADDR, addr_mask: MASK_UART }, // Rule 1 -> UART
      '{ addr_base: `TIMER_BASE_ADDR,addr_mask: MASK_TIMR }, // Rule 2 -> Timer
      '{ addr_base: `QSPI_BASE_ADDR, addr_mask: MASK_QSPI }  // Rule 3 -> QSPI
   };

   // OBI signals between Xbar and Peripherals
   adapter_obi_req_t peripheral_req [NUM_SLAVES-1:0]; // From Xbar to Slaves
   adapter_obi_rsp_t peripheral_rsp [NUM_SLAVES-1:0]; // From Slaves to Xbar

   obi_xbar #(
      .SbrPortObiCfg      ( AdapterObiCfg         ), // Config for master port (input)
      .MgrPortObiCfg      ( AdapterObiCfg         ), // Config for slave ports (output)
      .sbr_port_obi_req_t ( adapter_obi_req_t     ), // Type for master request
      .sbr_port_a_chan_t  ( adapter_obi_a_chan_t  ), // Needed internally by mux
      .sbr_port_obi_rsp_t ( adapter_obi_rsp_t     ), // Type for master response
      .sbr_port_r_chan_t  ( adapter_obi_r_chan_t  ), // Needed internally by mux
      .mgr_port_obi_req_t ( adapter_obi_req_t     ), // Type for slave request
      .mgr_port_obi_rsp_t ( adapter_obi_rsp_t     ), // Type for slave response
      .NumSbrPorts        ( 1                     ), // One master (AXI->OBI bridge)
      .NumMgrPorts        ( NUM_SLAVES            ), // Number of peripherals
      .NumMaxTrans        ( AXI_MAX_TRANS         ), // Max outstanding transactions
      .NumAddrRules       ( NUM_SLAVES            ), // One rule per slave
      .addr_map_rule_t    ( addr_map_rule_t       ), // Pass the type definition
      .UseIdForRouting    ( 1'b0                  ), // Only 1 master, no ID routing needed
      .Connectivity       ( '1                    )  // Default: master can access all slaves
   ) i_obi_xbar (
      .clk_i,
      .rst_ni       ( rst_n                 ),
      .testmode_i   ( 1'b0                  ),

      // Subordinate Port 0 (Master Input from AXI->OBI bridge)
      .sbr_ports_req_i  ( {adapter_obi_req}   ), // Input request array (size 1)
      .sbr_ports_rsp_o  ( {adapter_obi_rsp}   ), // Output response array (size 1)

      // Manager Ports (Slave Outputs to Peripherals)
      .mgr_ports_req_o  ( peripheral_req      ), // Output request array [NUM_SLAVES-1:0]
      .mgr_ports_rsp_i  ( peripheral_rsp      ), // Input response array [NUM_SLAVES-1:0]

      // Address Decoding Inputs
      .addr_map_i       ( ADDR_MAP            ), // The address map rules
      .en_default_idx_i ( {1{1'b0}}           ), // No default routing for master 0
      .default_idx_i    ( {{$clog2(NUM_SLAVES){1'b0}}} ) // Default index (unused)
   );

   // --- Peripheral Instantiation and Connections ---

   // Unpack requests from Xbar to peripherals, Pack responses from peripherals to Xbar
   // Note: Assumes peripherals use scalar signals matching the simple OBI subset

   // RAM (Slave Index 0)
   logic        ram_req_i;
   logic        ram_we_i;
   logic [AdapterObiCfg.DataWidth/8-1:0] ram_be_i; // Use correct BE width
   logic [AdapterObiCfg.AddrWidth-1:0] ram_addr_i;
   logic [AdapterObiCfg.DataWidth-1:0] ram_wdata_i;
   logic        ram_rvalid_o;
   logic [AdapterObiCfg.DataWidth-1:0] ram_rdata_o;
   logic        ram_gnt_o;

   assign ram_req_i   = peripheral_req[SLAVE_RAM_IDX].req;
   assign ram_we_i    = peripheral_req[SLAVE_RAM_IDX].a.we;
   assign ram_addr_i  = peripheral_req[SLAVE_RAM_IDX].a.addr;
   assign ram_wdata_i = peripheral_req[SLAVE_RAM_IDX].a.wdata;
   assign ram_be_i    = peripheral_req[SLAVE_RAM_IDX].a.be;

   assign peripheral_rsp[SLAVE_RAM_IDX].gnt    = ram_gnt_o;
   assign peripheral_rsp[SLAVE_RAM_IDX].rvalid = ram_rvalid_o;
   assign peripheral_rsp[SLAVE_RAM_IDX].r.rdata = ram_rdata_o;
   assign peripheral_rsp[SLAVE_RAM_IDX].r.rid   = peripheral_req[SLAVE_RAM_IDX].a.aid;
   assign peripheral_rsp[SLAVE_RAM_IDX].r.err  = 1'b0;
   assign peripheral_rsp[SLAVE_RAM_IDX].r.r_optional.ruser = '0;

   // UART (Slave Index 1)
   logic        uart_req_i;
   logic        uart_we_i;
   logic [AdapterObiCfg.DataWidth/8-1:0] uart_be_i;
   logic [AdapterObiCfg.AddrWidth-1:0] uart_addr_i;
   logic [AdapterObiCfg.DataWidth-1:0] uart_wdata_i;
   logic        uart_rvalid_o;
   logic [AdapterObiCfg.DataWidth-1:0] uart_rdata_o;
   logic        uart_gnt_o;

   assign uart_req_i   = peripheral_req[SLAVE_UART_IDX].req;
   assign uart_we_i    = peripheral_req[SLAVE_UART_IDX].a.we;
   // UART likely only uses lower address bits and data bytes
   assign uart_addr_i  = peripheral_req[SLAVE_UART_IDX].a.addr;
   assign uart_wdata_i = peripheral_req[SLAVE_UART_IDX].a.wdata;
   assign uart_be_i    = peripheral_req[SLAVE_UART_IDX].a.be;

   assign peripheral_rsp[SLAVE_UART_IDX].gnt    = uart_gnt_o;
   assign peripheral_rsp[SLAVE_UART_IDX].rvalid = uart_rvalid_o;
   assign peripheral_rsp[SLAVE_UART_IDX].r.rdata = uart_rdata_o;
   assign peripheral_rsp[SLAVE_UART_IDX].r.rid   = peripheral_req[SLAVE_UART_IDX].a.aid;
   assign peripheral_rsp[SLAVE_UART_IDX].r.err  = 1'b0;
   assign peripheral_rsp[SLAVE_UART_IDX].r.r_optional.ruser = '0;

   // Timer (Slave Index 2)
   logic        timer_req_i;
   logic        timer_we_i;
   logic [AdapterObiCfg.DataWidth/8-1:0] timer_be_i;
   logic [AdapterObiCfg.AddrWidth-1:0] timer_addr_i;
   logic [AdapterObiCfg.DataWidth-1:0] timer_wdata_i;
   logic        timer_rvalid_o;
   logic [AdapterObiCfg.DataWidth-1:0] timer_rdata_o;
   logic        timer_gnt_o;

   assign timer_req_i   = peripheral_req[SLAVE_TIMR_IDX].req;
   assign timer_we_i    = peripheral_req[SLAVE_TIMR_IDX].a.we;
   assign timer_addr_i  = peripheral_req[SLAVE_TIMR_IDX].a.addr;
   assign timer_wdata_i = peripheral_req[SLAVE_TIMR_IDX].a.wdata;
   assign timer_be_i    = peripheral_req[SLAVE_TIMR_IDX].a.be;

   assign peripheral_rsp[SLAVE_TIMR_IDX].gnt    = timer_gnt_o;
   assign peripheral_rsp[SLAVE_TIMR_IDX].rvalid = timer_rvalid_o;
   assign peripheral_rsp[SLAVE_TIMR_IDX].r.rdata = timer_rdata_o;
   assign peripheral_rsp[SLAVE_TIMR_IDX].r.rid   = peripheral_req[SLAVE_TIMR_IDX].a.aid;
   assign peripheral_rsp[SLAVE_TIMR_IDX].r.err  = 1'b0;
   assign peripheral_rsp[SLAVE_TIMR_IDX].r.r_optional.ruser = '0;

   // QSPI Flash Controller (Slave Index 3)
   logic        qspi_req;
   logic        qspi_we;
   logic [AdapterObiCfg.DataWidth/8-1:0] qspi_be;
   logic [AdapterObiCfg.AddrWidth-1:0] qspi_addr;
   logic [AdapterObiCfg.DataWidth-1:0] qspi_wdata;
   logic        qspi_rvalid;
   logic [AdapterObiCfg.DataWidth-1:0] qspi_rdata;
   logic        qspi_gnt;

   assign qspi_req   = peripheral_req[SLAVE_QSPI_IDX].req;
   assign qspi_we    = peripheral_req[SLAVE_QSPI_IDX].a.we;
   assign qspi_addr  = peripheral_req[SLAVE_QSPI_IDX].a.addr;
   assign qspi_wdata = peripheral_req[SLAVE_QSPI_IDX].a.wdata;
   assign qspi_be    = peripheral_req[SLAVE_QSPI_IDX].a.be;

   assign peripheral_rsp[SLAVE_QSPI_IDX].gnt    = qspi_gnt;
   assign peripheral_rsp[SLAVE_QSPI_IDX].rvalid = qspi_rvalid;
   assign peripheral_rsp[SLAVE_QSPI_IDX].r.rdata = qspi_rdata;
   assign peripheral_rsp[SLAVE_QSPI_IDX].r.rid   = peripheral_req[SLAVE_QSPI_IDX].a.aid;
   assign peripheral_rsp[SLAVE_QSPI_IDX].r.err  = 1'b0;
   assign peripheral_rsp[SLAVE_QSPI_IDX].r.r_optional.ruser = '0;

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
      .req_i         (qspi_req),
      .we_i          (qspi_we),
      .be_i          (qspi_be),
      .addr_i        (qspi_addr),
      .wdata_i       (qspi_wdata),
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
