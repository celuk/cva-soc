// dram_controller_axi.sv
`timescale 1ns / 1ps

import axi_pkg::*;

module dram_controller_axi #(
    parameter int unsigned AXI_ID_WIDTH   = 4, // Example ID width - **MUST MATCH XBAR MASTER PORT ID WIDTH**
    parameter int unsigned AXI_ADDR_WIDTH = 32,
    parameter int unsigned AXI_DATA_WIDTH = 32,
    parameter int unsigned WB_ADDR_WIDTH  = 8
) (
    // Clock and Reset
    input  logic clk_i,
    input  logic rst_ni,

    // AXI4-Lite Slave Interface (with IDs)
    input  logic                            s_axi_awvalid,
    output logic                            s_axi_awready,
    input  logic [AXI_ADDR_WIDTH-1:0]       s_axi_awaddr,
    input  logic [AXI_ID_WIDTH-1:0]         s_axi_awid,   // <-- Added
    input  logic [2:0]                      s_axi_awprot,
    input  logic                            s_axi_wvalid,
    output logic                            s_axi_wready,
    input  logic [AXI_DATA_WIDTH-1:0]       s_axi_wdata,
    input  logic [AXI_DATA_WIDTH/8-1:0]     s_axi_wstrb,
    output logic                            s_axi_bvalid,
    input  logic                            s_axi_bready,
    output logic [AXI_ID_WIDTH-1:0]         s_axi_bid,    // <-- Added
    output logic [1:0]                      s_axi_bresp,
    input  logic                            s_axi_arvalid,
    output logic                            s_axi_arready,
    input  logic [AXI_ADDR_WIDTH-1:0]       s_axi_araddr,
    input  logic [AXI_ID_WIDTH-1:0]         s_axi_arid,   // <-- Added
    input  logic [2:0]                      s_axi_arprot,
    output logic                            s_axi_rvalid,
    input  logic                            s_axi_rready,
    output logic [AXI_ID_WIDTH-1:0]         s_axi_rid,    // <-- Added
    output logic [AXI_DATA_WIDTH-1:0]       s_axi_rdata,
    output logic [1:0]                      s_axi_rresp

    ,output ddr3_reset_n
    ,output ddr3_cke
    ,output ddr3_ck_p
    ,output ddr3_ck_n
    ,output ddr3_cs_n
    ,output ddr3_ras_n
    ,output ddr3_cas_n
    ,output ddr3_we_n
    ,output [2:0] ddr3_ba
    ,output [13:0] ddr3_addr
    ,output ddr3_odt
    ,output [1:0] ddr3_dm
    ,inout [1:0] ddr3_dqs_p
    ,inout [1:0] ddr3_dqs_n
    ,inout [15:0] ddr3_dq
 
    ,input clk100
    ,input clk_ddr
    ,input clk_ref
    ,input clk_ddr_dqs
);

    localparam DATA_BYTES = AXI_DATA_WIDTH / 8;

    typedef enum logic [2:0] {
        S_IDLE, S_WRITE_ADDR, S_WRITE_DATA, S_READ_ADDR, S_WAIT_ACK, S_RESP
    } state_e;

    state_e current_state, next_state;

    // Wishbone Interface Signals
    logic                            wb_cyc;
    logic                            wb_stb;
    logic                            wb_we;
    logic [AXI_ADDR_WIDTH-1:0]       wb_adr_reg;
    logic [AXI_DATA_WIDTH-1:0]       wb_dat_w_reg;
    logic [DATA_BYTES-1:0]           wb_sel_reg;
    logic                            wb_ack;
    logic [AXI_DATA_WIDTH-1:0]       wb_dat_r;

    // Internal Registers
    logic [AXI_DATA_WIDTH-1:0]       reg_axi_rdata;
    logic                            reg_is_write;
    logic [AXI_ID_WIDTH-1:0]         reg_axi_id; // Register to hold ID for current transaction

    dram_controller_wb dram_iface_dut (
       .clk_i   (clk_i),
       .rst_i   (~rst_ni),
       .wb_adr_i(wb_adr_reg[WB_ADDR_WIDTH-1:0]),
       .wb_dat_i(wb_dat_w_reg),
       .wb_we_i (wb_we),
       .wb_stb_i(wb_stb),
       .wb_sel_i(wb_sel_reg),
       .wb_cyc_i(wb_cyc),
       .wb_ack_o(wb_ack),
       .wb_dat_o(wb_dat_r)

      ,.ddr3_reset_n(ddr3_reset_n)
      ,.ddr3_cke(ddr3_cke)
      ,.ddr3_ck_p(ddr3_ck_p)
      ,.ddr3_ck_n(ddr3_ck_n)
      ,.ddr3_cs_n(ddr3_cs_n)
      ,.ddr3_ras_n(ddr3_ras_n)
      ,.ddr3_cas_n(ddr3_cas_n)
      ,.ddr3_we_n(ddr3_we_n)
      ,.ddr3_ba(ddr3_ba)
      ,.ddr3_addr(ddr3_addr)
      ,.ddr3_odt(ddr3_odt)
      ,.ddr3_dm(ddr3_dm)
      ,.ddr3_dqs_p(ddr3_dqs_p)
      ,.ddr3_dqs_n(ddr3_dqs_n)
      ,.ddr3_dq(ddr3_dq)

      ,.clk100(clk100)
      ,.clk_ddr(clk_ddr)
      ,.clk_ref(clk_ref)
      ,.clk_ddr_dqs(clk_ddr_dqs)
   );

    // AXI Ready Signal Logic
    assign s_axi_awready = (current_state == S_IDLE);
    assign s_axi_wready  = (current_state == S_WRITE_ADDR);
    assign s_axi_arready = (current_state == S_IDLE);

    // AXI Response Signal Logic
    assign s_axi_bvalid = (current_state == S_RESP) && reg_is_write;
    assign s_axi_bresp  = RESP_OKAY;
    assign s_axi_bid    = reg_axi_id; // Return stored ID for write resp

    assign s_axi_rvalid = (current_state == S_RESP) && !reg_is_write;
    assign s_axi_rdata  = reg_axi_rdata;
    assign s_axi_rresp  = RESP_OKAY;
    assign s_axi_rid    = reg_axi_id; // Return stored ID for read resp

    // Wishbone Control Signals
    assign wb_cyc = (current_state == S_WRITE_DATA) || (current_state == S_READ_ADDR) || (current_state == S_WAIT_ACK);
    assign wb_stb = wb_cyc;
    assign wb_we  = (current_state == S_WRITE_DATA) || ((current_state == S_WAIT_ACK) && reg_is_write);

    // State Register
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) current_state <= S_IDLE; else current_state <= next_state; end

    // Data Registers and Transaction Type/ID Tracking
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            wb_adr_reg   <= '0; wb_dat_w_reg <= '0; wb_sel_reg   <= '0;
            reg_axi_rdata<= '0; reg_is_write <= 1'b0; reg_axi_id <= '0;
        end else begin
            // Register inputs when AXI handshake occurs
            if (s_axi_awvalid && s_axi_awready) begin
                wb_adr_reg <= s_axi_awaddr;
                reg_is_write <= 1'b1;
                reg_axi_id <= s_axi_awid; // Capture AWID
            end else if (s_axi_arvalid && s_axi_arready) begin
                wb_adr_reg <= s_axi_araddr;
                reg_is_write <= 1'b0;
                reg_axi_id <= s_axi_arid; // Capture ARID
            end

            if (s_axi_wvalid && s_axi_wready) begin
                wb_dat_w_reg <= s_axi_wdata;
                wb_sel_reg   <= s_axi_wstrb;
            end

            if (current_state == S_WAIT_ACK && wb_ack && !reg_is_write) begin
                reg_axi_rdata <= wb_dat_r; end // Latch WB read data

            if (s_axi_rvalid && s_axi_rready) begin reg_axi_rdata <= '0; end // Clear read data
        end
    end

    // Next State Logic
    always_comb begin
        next_state = current_state;
        case (current_state)
            S_IDLE: begin
                if (s_axi_awvalid) begin next_state = S_WRITE_ADDR;
                end else if (s_axi_arvalid) begin next_state = S_READ_ADDR; end
            end
            S_WRITE_ADDR: begin if (s_axi_wvalid) begin next_state = S_WRITE_DATA; end end
            S_WRITE_DATA: begin next_state = S_WAIT_ACK; end
            S_READ_ADDR:  begin next_state = S_WAIT_ACK; end
            S_WAIT_ACK: begin if (wb_ack) begin next_state = S_RESP; end end
            S_RESP: begin
                if (reg_is_write && s_axi_bready) begin next_state = S_IDLE;
                end else if (!reg_is_write && s_axi_rready) begin next_state = S_IDLE; end
            end
            default: next_state = S_IDLE;
        endcase
    end

endmodule
