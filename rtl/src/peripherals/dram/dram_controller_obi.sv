
module dram_controller_obi (
   input  wire        clk_i,
   input  wire        rst_ni,
   input  wire        req_i,
   input  wire        we_i,
   input  wire [ 3:0] be_i,
   output wire        gnt_o,
   input  wire [31:0] addr_i,
   input  wire [31:0] wdata_i,
   output reg         rvalid_o,
   output reg  [31:0] rdata_o

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

   reg         wb_cyc_r;
   reg         wb_stb_r;
   wire        wb_ack_w;
   wire [31:0] wb_dat_o_w;

   dram_controller dram_iface_dut (
      .clk_i   (clk_i),
      .rst_i   (~rst_ni),
      .wb_adr_i(addr_i),
      .wb_dat_i(wdata_i),
      .wb_we_i (we_i),
      .wb_stb_i(wb_stb_r),
      .wb_sel_i(be_i),
      .wb_cyc_i(wb_cyc_r),
      .wb_ack_o(wb_ack_w),
      .wb_dat_o(wb_dat_o_w)

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

   always @(posedge clk_i or negedge rst_ni) begin
      if (~rst_ni) begin
         wb_cyc_r <= 1'b0;
         wb_stb_r <= 1'b0;
         rvalid_o <= 1'b0;
         rdata_o  <= 32'b0;
      end else begin
         if (req_i && gnt_o) begin
            wb_cyc_r <= 1'b1;
            wb_stb_r <= 1'b1;
         end else if (wb_ack_w) begin
            wb_cyc_r <= 1'b0;
            wb_stb_r <= 1'b0;
         end

         rvalid_o <= wb_ack_w;
         if (wb_ack_w) begin
            rdata_o <= wb_dat_o_w;
         end
      end
   end

   assign gnt_o = ~wb_cyc_r;

endmodule
