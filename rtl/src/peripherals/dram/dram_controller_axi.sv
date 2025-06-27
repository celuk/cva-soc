// dram_controller_axi.sv
`timescale 1ns / 1ps

import axi_pkg::*;

module dram_controller_axi #(
    parameter int unsigned AXI_ID_WIDTH   = 4,
    parameter int unsigned AXI_ADDR_WIDTH = 32,
    parameter int unsigned AXI_DATA_WIDTH = 32,
    parameter int unsigned WB_ADDR_WIDTH  = 32
) (
    input  logic clk_i,
    input  logic rst_ni,

    // Full AXI4 Slave Interface
    // Write Address Channel
    input  logic                            s_axi_awvalid,
    output logic                            s_axi_awready,
    input  logic [AXI_ADDR_WIDTH-1:0]       s_axi_awaddr,
    input  logic [AXI_ID_WIDTH-1:0]         s_axi_awid,
    input  logic [7:0]                      s_axi_awlen,
    input  logic [2:0]                      s_axi_awsize,
    input  logic [1:0]                      s_axi_awburst,
    input  logic [2:0]                      s_axi_awprot,
    // Write Data Channel
    input  logic                            s_axi_wvalid,
    output logic                            s_axi_wready,
    input  logic [AXI_DATA_WIDTH-1:0]       s_axi_wdata,
    input  logic [AXI_DATA_WIDTH/8-1:0]     s_axi_wstrb,
    input  logic                            s_axi_wlast,
    // Write Response Channel
    output logic                            s_axi_bvalid,
    input  logic                            s_axi_bready,
    output logic [AXI_ID_WIDTH-1:0]         s_axi_bid,
    output logic [1:0]                      s_axi_bresp,
    // Read Address Channel
    input  logic                            s_axi_arvalid,
    output logic                            s_axi_arready,
    input  logic [AXI_ADDR_WIDTH-1:0]       s_axi_araddr,
    input  logic [AXI_ID_WIDTH-1:0]         s_axi_arid,
    input  logic [7:0]                      s_axi_arlen,
    input  logic [2:0]                      s_axi_arsize,
    input  logic [1:0]                      s_axi_arburst,
    input  logic [2:0]                      s_axi_arprot,
    // Read Data Channel
    output logic                            s_axi_rvalid,
    input  logic                            s_axi_rready,
    output logic [AXI_ID_WIDTH-1:0]         s_axi_rid,
    output logic [AXI_DATA_WIDTH-1:0]       s_axi_rdata,
    output logic [1:0]                      s_axi_rresp,
    output logic                            s_axi_rlast

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

    ,input wire uart_dram_write_we_i,
    input wire [31:0] uart_dram_write_addr_i,
    input wire [31:0] uart_dram_write_data_i,
    input wire uart_dram_write_rst_i
);

    localparam logic [1:0] AXI_BURST_FIXED = 2'b00;
    localparam logic [1:0] AXI_BURST_INCR  = 2'b01;
    localparam logic [1:0] AXI_BURST_WRAP  = 2'b10;

    localparam DATA_BYTES = AXI_DATA_WIDTH / 8;

    typedef enum logic [2:0] {
        S_IDLE,
        S_READ_REQ_WB,
        S_READ_WAIT_WB,
        S_READ_RESP_AXI,
        S_WRITE_WAIT_DATA,
        S_WRITE_REQ_WB,
        S_WRITE_WAIT_WB,
        S_WRITE_RESP_AXI
    } state_e;

    state_e current_state, next_state;

    logic                            wb_cyc;
    logic                            wb_stb;
    logic                            wb_we;
    logic [AXI_ADDR_WIDTH-1:0]       wb_adr;
    logic [AXI_DATA_WIDTH-1:0]       wb_dat_w;
    logic [DATA_BYTES-1:0]           wb_sel;
    logic                            wb_ack;
    logic [AXI_DATA_WIDTH-1:0]       wb_dat_r;

    logic [AXI_ID_WIDTH-1:0]         reg_id;
    logic [AXI_ADDR_WIDTH-1:0]       current_addr;
    logic [7:0]                      reg_len;
    logic [2:0]                      reg_size;
    logic [1:0]                      reg_burst;
    logic [7:0]                      beat_count;
    logic                            is_write;
    logic [AXI_DATA_WIDTH-1:0]       reg_rdata;

    dram_controller_wb dram_iface_dut (
       .clk_i   (clk_i),
       .rst_i   (~rst_ni),
       .wb_adr_i(wb_adr[WB_ADDR_WIDTH-1:0]),
       .wb_dat_i(wb_dat_w),
       .wb_we_i (wb_we),
       .wb_stb_i(wb_stb),
       .wb_sel_i(wb_sel),
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

      ,.uart_dram_write_we_i(uart_dram_write_we_i)
      ,.uart_dram_write_addr_i(uart_dram_write_addr_i)
      ,.uart_dram_write_data_i(uart_dram_write_data_i)
      ,.uart_dram_write_rst_i(uart_dram_write_rst_i)
   );

    assign s_axi_awready = (current_state == S_IDLE);
    assign s_axi_arready = (current_state == S_IDLE);
    assign s_axi_wready  = (current_state == S_WRITE_WAIT_DATA);

    assign s_axi_bvalid = (current_state == S_WRITE_RESP_AXI);
    assign s_axi_bresp  = RESP_OKAY;
    assign s_axi_bid    = reg_id;

    assign s_axi_rvalid = (current_state == S_READ_RESP_AXI);
    assign s_axi_rdata  = reg_rdata;
    assign s_axi_rresp  = RESP_OKAY;
    assign s_axi_rid    = reg_id;
    assign s_axi_rlast  = (beat_count == reg_len);

    assign wb_cyc = (current_state == S_READ_REQ_WB) || (current_state == S_WRITE_REQ_WB) ||
                    (current_state == S_READ_WAIT_WB) || (current_state == S_WRITE_WAIT_WB);
    assign wb_stb = wb_cyc;
    assign wb_we  = is_write;
    assign wb_adr = current_addr;

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            current_state <= S_IDLE;
        end else begin
            current_state <= next_state;
        end
    end

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            reg_id <= '0;
            current_addr <= '0;
            reg_len <= '0;
            reg_size <= '0;
            reg_burst <= '0;
            beat_count <= '0;
            is_write <= 1'b0;
            reg_rdata <= '0;
            wb_dat_w <= '0;
            wb_sel <= '0;
        end else begin
            case (current_state)
                S_IDLE: begin
                    if (s_axi_awvalid) begin
                        reg_id       <= s_axi_awid;
                        current_addr <= s_axi_awaddr;
                        reg_len      <= s_axi_awlen;
                        reg_size     <= s_axi_awsize;
                        reg_burst    <= s_axi_awburst;
                        is_write     <= 1'b1;
                        beat_count   <= '0;
                    end else if (s_axi_arvalid) begin
                        reg_id       <= s_axi_arid;
                        current_addr <= s_axi_araddr;
                        reg_len      <= s_axi_arlen;
                        reg_size     <= s_axi_arsize;
                        reg_burst    <= s_axi_arburst;
                        is_write     <= 1'b0;
                        beat_count   <= '0;
                    end
                end
                S_WRITE_WAIT_DATA: begin
                    if (s_axi_wvalid) begin
                        wb_dat_w <= s_axi_wdata;
                        wb_sel   <= s_axi_wstrb;
                    end
                end
                S_READ_WAIT_WB: begin
                    if (wb_ack) begin
                        reg_rdata <= wb_dat_r;
                    end
                end
                S_READ_RESP_AXI: begin
                    if (s_axi_rready) begin
                        beat_count <= beat_count + 1;
                        if (reg_burst == AXI_BURST_INCR) begin
                            current_addr <= current_addr + (1 << reg_size);
                        end
                    end
                end
                S_WRITE_WAIT_WB: begin
                    if (wb_ack) begin
                        beat_count <= beat_count + 1;
                        if (reg_burst == AXI_BURST_INCR) begin
                            current_addr <= current_addr + (1 << reg_size);
                        end
                    end
                end
            endcase
        end
    end

    always_comb begin
        next_state = current_state;
        case (current_state)
            S_IDLE: begin
                if (s_axi_awvalid) begin
                    next_state = S_WRITE_WAIT_DATA;
                end else if (s_axi_arvalid) begin
                    next_state = S_READ_REQ_WB;
                end
            end
            S_READ_REQ_WB: begin
                next_state = S_READ_WAIT_WB;
            end
            S_READ_WAIT_WB: begin
                if (wb_ack) begin
                    next_state = S_READ_RESP_AXI;
                end
            end
            S_READ_RESP_AXI: begin
                if (s_axi_rready) begin
                    if (beat_count == reg_len) begin
                        next_state = S_IDLE;
                    end else begin
                        next_state = S_READ_REQ_WB;
                    end
                end
            end
            S_WRITE_WAIT_DATA: begin
                if (s_axi_wvalid) begin
                    next_state = S_WRITE_REQ_WB;
                end
            end
            S_WRITE_REQ_WB: begin
                next_state = S_WRITE_WAIT_WB;
            end
            S_WRITE_WAIT_WB: begin
                if (wb_ack) begin
                    if (beat_count == reg_len) begin
                        next_state = S_WRITE_RESP_AXI;
                    end else begin
                        next_state = S_WRITE_WAIT_DATA;
                    end
                end
            end
            S_WRITE_RESP_AXI: begin
                if (s_axi_bready) begin
                    next_state = S_IDLE;
                end
            end
            default: next_state = S_IDLE;
        endcase
    end

endmodule
