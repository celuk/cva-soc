`timescale 1ns / 1ps

`include "header.vh"

module dram_controller_wb (
   input wire clk_i,
   input wire rst_i,

   input  wire [31:0] wb_adr_i,
   input  wire [31:0] wb_dat_i,
   input  wire        wb_we_i ,
   input  wire        wb_stb_i,
   input  wire [3:0]  wb_sel_i,
   input  wire        wb_cyc_i,
   output        wb_ack_o,
   output [31:0] wb_dat_o

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

    localparam S_IDLE             = 4'b0000;
    localparam S_START_READ       = 4'b0001;
    localparam S_WAIT_READ_ACK    = 4'b0010;
    localparam S_MODIFY_AND_WRITE = 4'b0100;
    localparam S_WAIT_WRITE_ACK   = 4'b0101;
    localparam S_DONE             = 4'b1000;

    reg [3:0] state_r, state_next_r;
    
    reg        wb_we_r; 
    reg [31:0] wb_adr_r;
    reg [31:0] wb_dat_r;
    reg [3:0]  wb_sel_r;
    reg [31:0] aligned_adr_r;

    reg [31:0] wb_read_data_r;
    assign wb_dat_o = wb_read_data_r;

    reg wb_ack_r;
    assign wb_ack_o = wb_ack_r;

    reg [127:0] DRAM_DATA_WRITE;
    reg [127:0] DRAM_DATA_READ;
    reg DRAM_RE;
    reg DRAM_WE;
    reg [31:0]  DRAM_WDG;
    reg [15:0]  ram_wr_sel;

    wire [127:0] ram_rd_data;
    wire         ram_accept;
    wire         ram_ack;
 
    wire [31:0] write_mask;
    assign write_mask = {{8{wb_sel_r[3]}}, {8{wb_sel_r[2]}}, {8{wb_sel_r[1]}}, {8{wb_sel_r[0]}}};

    `ifdef ZC706
    wire [31:0]  ram_addr = aligned_adr_r;
    wire         ram_wr = DRAM_WE;
    wire [127:0] ram_wr_data = DRAM_DATA_WRITE;
    wire         ram_rd = DRAM_RE;
 
    wire ddr3_reset_i = (DRAM_WDG != 0);
 
    ddr3_controller 
    #(
       .DDR_MHZ(`DDR_MHZ)
    )
    ddr3_controller_inst(
       .rst_i(ddr3_reset_i),
       `ifdef DDR_100MHZ
       .clk(clk100),
       `else
       .clk(clk_i),
       `endif
       .clk_ddr(clk_ddr),
       .clk_ref(clk_ref),
       .clk_ddr_dqs(clk_ddr_dqs),
       .ram_addr(ram_addr),
       .wr_en(ram_wr),
       .wr_sel(ram_wr_sel),
       .wr_data(ram_wr_data),
       .rd_en(ram_rd),
       .rd_data(ram_rd_data),
       .accepted(ram_accept),
       .acked(ram_ack),
       .ram_req_id(0),
       .ddr3_reset_n(ddr3_reset_n),
       .ddr3_cke(ddr3_cke),
       .ddr3_ck_p(ddr3_ck_p),
       .ddr3_ck_n(ddr3_ck_n),
       .ddr3_ras_n(ddr3_ras_n),
       .ddr3_cas_n(ddr3_cas_n),
       .ddr3_we_n(ddr3_we_n),
       .ddr3_ba(ddr3_ba),
       .ddr3_addr(ddr3_addr),
       .ddr3_odt(ddr3_odt),
       .ddr3_dm(ddr3_dm),
       .ddr3_dqs_p(ddr3_dqs_p),
       .ddr3_dqs_n(ddr3_dqs_n),
       .ddr3_dq(ddr3_dq),
       .ddr3_cs_n(ddr3_cs_n)
    );
    `else
    assign ram_rd_data = 0;
    assign ram_accept = 1;
    assign ram_ack = 1;
    `endif
 
    always @* begin
        state_next_r = state_r;
        DRAM_RE = 1'b0;
        DRAM_WE = 1'b0;
        ram_wr_sel = 16'h0;
        DRAM_DATA_WRITE = DRAM_DATA_READ; 

        case(state_r)
            S_IDLE: begin
                if(wb_cyc_i && wb_stb_i) begin
                    state_next_r = S_START_READ;
                end
            end
            
            S_START_READ: begin
                DRAM_RE = 1'b1;
                if (ram_accept) begin
                    state_next_r = S_WAIT_READ_ACK;
                end
            end

            S_WAIT_READ_ACK: begin
                if (ram_ack) begin
                    if (wb_we_r) begin
                        state_next_r = S_MODIFY_AND_WRITE;
                    end else begin
                        state_next_r = S_DONE;
                    end
                end
            end

            S_MODIFY_AND_WRITE: begin
                case (wb_adr_r[3:2])
                    2'b00: DRAM_DATA_WRITE[31:0]   = (wb_dat_r & write_mask) | (DRAM_DATA_READ[31:0]   & ~write_mask);
                    2'b01: DRAM_DATA_WRITE[63:32]  = (wb_dat_r & write_mask) | (DRAM_DATA_READ[63:32]  & ~write_mask);
                    2'b10: DRAM_DATA_WRITE[95:64]  = (wb_dat_r & write_mask) | (DRAM_DATA_READ[95:64]  & ~write_mask);
                    2'b11: DRAM_DATA_WRITE[127:96] = (wb_dat_r & write_mask) | (DRAM_DATA_READ[127:96] & ~write_mask);
                endcase

                case(wb_adr_r[3:2])
                    2'b00:  ram_wr_sel = {12'h000, wb_sel_r};
                    2'b01:  ram_wr_sel = {8'h00, wb_sel_r, 4'h0};
                    2'b10:  ram_wr_sel = {4'h0, wb_sel_r, 8'h0};
                    2'b11:  ram_wr_sel = {wb_sel_r, 12'h000};
                endcase

                DRAM_WE = 1'b1;
                if (ram_accept) begin
                    state_next_r = S_WAIT_WRITE_ACK;
                end
            end
            
            S_WAIT_WRITE_ACK: begin
                if (ram_ack) begin
                    state_next_r = S_DONE;
                end
            end

            S_DONE: begin
                state_next_r = S_IDLE;
            end
        endcase
    end
    
    always_ff @(posedge clk_i) begin
        if (rst_i) begin
            state_r <= S_IDLE;
            wb_ack_r <= 1'b0;
            wb_read_data_r <= 32'b0;
            wb_we_r <= 1'b0;
            wb_adr_r <= 32'b0;
            wb_dat_r <= 32'b0;
            wb_sel_r <= 4'b0;
            aligned_adr_r <= 32'b0;
            DRAM_DATA_READ <= 128'b0;
            DRAM_WDG <= `CPU_CLK / 5000;
        end
        else begin
            state_r <= state_next_r;
            wb_ack_r <= (state_r == S_DONE);

            if (DRAM_WDG > 0) begin
                DRAM_WDG <= DRAM_WDG - 1;
            end

            if(state_r == S_IDLE && state_next_r == S_START_READ) begin
                wb_we_r <= wb_we_i;
                wb_adr_r <= wb_adr_i;
                wb_dat_r <= wb_dat_i;
                wb_sel_r <= wb_sel_i;
                aligned_adr_r <= wb_adr_i & 32'hFFFFFFF0;
            end

            if(state_r == S_WAIT_READ_ACK && ram_ack) begin
                DRAM_DATA_READ <= ram_rd_data;
            end
            
            if(state_r == S_DONE && !wb_we_r) begin
                case(wb_adr_r[3:2])
                    2'b00: wb_read_data_r <= DRAM_DATA_READ[31:0];
                    2'b01: wb_read_data_r <= DRAM_DATA_READ[63:32];
                    2'b10: wb_read_data_r <= DRAM_DATA_READ[95:64];
                    2'b11: wb_read_data_r <= DRAM_DATA_READ[127:96];
                endcase
            end
        end
    end

endmodule
