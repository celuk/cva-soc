`timescale 1ns / 1ps

module ddr3_controller
#(
    parameter DDR_MHZ          = 100
)
(
    input rst_i,
    input clk,
    input clk_ddr,
    input clk_ref,
    input clk_ddr_dqs,
    
    input [31:0] ram_addr,
    input wr_en,
    input [127:0] wr_data,
    input rd_en,
    output [127:0] rd_data,
    output accepted,
    output acked,
    
    input [ 15:0] ram_req_id,
    
    output ddr3_reset_n,
    output ddr3_cke,
    output ddr3_ck_p,
    output ddr3_ck_n,
    output ddr3_ras_n,
    output ddr3_cas_n,
    output ddr3_we_n,
    output [2:0] ddr3_ba,
    output [13:0] ddr3_addr,
    output ddr3_odt,
    output [1:0] ddr3_dm,
    inout [1:0] ddr3_dqs_p,
    inout [1:0] ddr3_dqs_n,
    inout [15:0] ddr3_dq,
    output ddr3_cs_n
);

wire  [ 14:0] dfi_address;
wire  [  2:0] dfi_bank;
wire          dfi_cas_n;
wire          dfi_cke;
wire          dfi_cs_n;
wire          dfi_odt;
wire          dfi_ras_n;
wire          dfi_reset_n;
wire          dfi_we_n;
wire  [ 31:0] dfi_wrdata;
wire          dfi_wrdata_en;
wire  [  3:0] dfi_wrdata_mask;
wire          dfi_rddata_en;
wire [ 31:0]  dfi_rddata;
wire          dfi_rddata_valid;

wire [1:0] dfi_rddata_dnv;

ddr3_dfi_phy
#(
     .DQS_TAP_DELAY_INIT(27)
    ,.DQ_TAP_DELAY_INIT(0)
    ,.TPHY_RDLAT(5)
)
u_phy
(
     .clk_i(clk)
    ,.clk_ddr_i(clk_ddr)
    ,.clk_ddr90_i(clk_ddr_dqs)
    ,.clk_ref_i(clk_ref)
    ,.rst_i(rst_i)

    ,.cfg_i(0)
    ,.cfg_valid_i(0)

    ,.dfi_address_i(dfi_address)
    ,.dfi_bank_i(dfi_bank)
    ,.dfi_cas_n_i(dfi_cas_n)
    ,.dfi_cke_i(dfi_cke)
    ,.dfi_cs_n_i(dfi_cs_n)
    ,.dfi_odt_i(dfi_odt)
    ,.dfi_ras_n_i(dfi_ras_n)
    ,.dfi_reset_n_i(dfi_reset_n)
    ,.dfi_we_n_i(dfi_we_n)

    ,.dfi_wrdata_i(dfi_wrdata)
    ,.dfi_wrdata_en_i(dfi_wrdata_en)
    ,.dfi_wrdata_mask_i(dfi_wrdata_mask)
    ,.dfi_rddata_en_i(dfi_rddata_en)

    ,.dfi_rddata_o(dfi_rddata)
    ,.dfi_rddata_valid_o(dfi_rddata_valid)
    ,.dfi_rddata_dnv_o()

    ,.ddr3_ck_p_o(ddr3_ck_p)
    ,.ddr3_ck_n_o(ddr3_ck_n)
    ,.ddr3_cke_o(ddr3_cke)
    ,.ddr3_reset_n_o(ddr3_reset_n)
    ,.ddr3_ras_n_o(ddr3_ras_n)
    ,.ddr3_cas_n_o(ddr3_cas_n)
    ,.ddr3_we_n_o(ddr3_we_n)
    ,.ddr3_cs_n_o(ddr3_cs_n)
    ,.ddr3_ba_o(ddr3_ba)
    ,.ddr3_addr_o(ddr3_addr)
    ,.ddr3_odt_o(ddr3_odt)
    ,.ddr3_dm_o(ddr3_dm)
    ,.ddr3_dqs_p_io(ddr3_dqs_p)
    ,.ddr3_dqs_n_io(ddr3_dqs_n)
    ,.ddr3_dq_io(ddr3_dq)
);

wire  [ 15:0]  ram_wr = {16{wr_en}};
wire           ram_rd = rd_en;

wire  [127:0]  ram_write_data = wr_data;

wire          ram_accept;
wire          ram_ack;
assign accepted = ram_accept;
assign acked = ram_ack;

wire [127:0]  ram_read_data;
assign rd_data = ram_read_data;

//reg  [ 15:0]  ram_req_id = 0;
wire          ram_error;
wire [ 15:0]  ram_resp_id;

ddr3_core
#(
     .DDR_WRITE_LATENCY(4)
    ,.DDR_READ_LATENCY(4)
    ,.DDR_MHZ(DDR_MHZ)
)
u_ddr_core
(
     .clk_i(clk)
    ,.rst_i(rst_i)

    // Configuration (unused)
    ,.cfg_enable_i(1'b1)
    ,.cfg_stb_i(1'b0)
    ,.cfg_data_i(32'b0)
    ,.cfg_stall_o()

    ,.inport_wr_i(ram_wr)
    ,.inport_rd_i(ram_rd)
    ,.inport_addr_i(ram_addr)
    ,.inport_write_data_i(ram_write_data)
    ,.inport_req_id_i(ram_req_id)
    ,.inport_accept_o(ram_accept)
    ,.inport_ack_o(ram_ack)
    ,.inport_error_o(ram_error)
    ,.inport_resp_id_o(ram_resp_id)
    ,.inport_read_data_o(ram_read_data)

    ,.dfi_address_o(dfi_address)
    ,.dfi_bank_o(dfi_bank)
    ,.dfi_cas_n_o(dfi_cas_n)
    ,.dfi_cke_o(dfi_cke)
    ,.dfi_cs_n_o(dfi_cs_n)
    ,.dfi_odt_o(dfi_odt)
    ,.dfi_ras_n_o(dfi_ras_n)
    ,.dfi_reset_n_o(dfi_reset_n)
    ,.dfi_we_n_o(dfi_we_n)
    ,.dfi_wrdata_o(dfi_wrdata)
    ,.dfi_wrdata_en_o(dfi_wrdata_en)
    ,.dfi_wrdata_mask_o(dfi_wrdata_mask)
    ,.dfi_rddata_en_o(dfi_rddata_en)
    ,.dfi_rddata_i(dfi_rddata)
    ,.dfi_rddata_valid_i(dfi_rddata_valid)
    ,.dfi_rddata_dnv_i(dfi_rddata_dnv)
);
    
endmodule
