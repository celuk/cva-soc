// dram_controller_wb.sv
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

    reg [31:0] wb_read_data_r;
    reg [31:0] wb_read_data_next_r;
    assign wb_dat_o = wb_read_data_r;

    reg wb_ack_r;
    reg wb_ack_next_r;
    assign wb_ack_o = wb_ack_r;

    reg [31:0] DRAM_ADDRESS;
    reg [31:0] DRAM_ADDRESS_NEXT;
    reg [31:0] DRAM_DATA_WRITE0;
    reg [31:0] DRAM_DATA_WRITE0_NEXT;
    reg [31:0] DRAM_DATA_WRITE1;
    reg [31:0] DRAM_DATA_WRITE1_NEXT;
    reg [31:0] DRAM_DATA_WRITE2;
    reg [31:0] DRAM_DATA_WRITE2_NEXT;
    reg [31:0] DRAM_DATA_WRITE3;
    reg [31:0] DRAM_DATA_WRITE3_NEXT;
    reg [31:0] DRAM_DATA_READ0;
    reg [31:0] DRAM_DATA_READ0_NEXT;
    reg [31:0] DRAM_DATA_READ1;
    reg [31:0] DRAM_DATA_READ1_NEXT;
    reg [31:0] DRAM_DATA_READ2;
    reg [31:0] DRAM_DATA_READ2_NEXT;
    reg [31:0] DRAM_DATA_READ3;
    reg [31:0] DRAM_DATA_READ3_NEXT;
    reg DRAM_RE;
    reg DRAM_RE_NEXT;
    reg DRAM_WE;
    reg DRAM_WE_NEXT;
    reg [31:0] DRAM_WDG;
    reg [31:0] DRAM_WDG_NEXT;

    typedef enum logic [3:0] {
        IDLE,
        READ_START,
        READ_WAIT_ACK,
        WRITE_RMW_START,
        WRITE_RMW_WAIT_ACK,
        WRITE_START,
        WRITE_WAIT_ACK,
        WAIT,
        WAIT_RMW
    } state_t;

    state_t state_r, state_next_r;

    reg [31:0] wb_adr_r, wb_adr_next_r;
    reg [31:0] wb_dat_r, wb_dat_next_r;
    reg [3:0]  wb_sel_r, wb_sel_next_r;

    wire [31:0] data_read_w0;
    wire [31:0] data_read_w1;
    wire [31:0] data_read_w2;
    wire [31:0] data_read_w3;

    logic [127:0] modified_rmw_data;
 
    reg ram_accept_r, ram_accept_next_r;
    reg ram_ack_r, ram_ack_next_r;

    `ifdef ZC706
    wire [31:0]  ram_addr = DRAM_ADDRESS;
    wire         ram_wr = DRAM_WE;
    wire [127:0] ram_wr_data = {DRAM_DATA_WRITE3, DRAM_DATA_WRITE2, DRAM_DATA_WRITE1, DRAM_DATA_WRITE0};
    wire         ram_rd = DRAM_RE;
    wire [127:0] ram_rd_data;
    wire         ram_accept;
    wire         ram_ack;
 
    reg [15:0] ram_req_id = 0;

    wire ddr3_reset_i = (DRAM_WDG != 0);
 
    ddr3_controller 
    #(
       .DDR_MHZ(`DDR_MHZ)
    )
    ddr3_controller_inst(
       // user ports
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
       .wr_sel(16'b1111111111111111),
       .wr_data(ram_wr_data),
       .rd_en(ram_rd),
       .rd_data(ram_rd_data),
       .accepted(ram_accept),
       .acked(ram_ack),
       // io ports
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
 
       ,.ram_req_id(0)
    );
    `else
    wire [127:0] ram_rd_data = 0;
    wire         ram_accept = 1;
    wire         ram_ack = 1;
    `endif

    reg [31:0] counter;
    reg [31:0] counter_next;

    always @* begin
        state_next_r = state_r;
        wb_ack_next_r = 0;
        wb_read_data_next_r = wb_read_data_r;
        wb_adr_next_r = wb_adr_r;
        wb_dat_next_r = wb_dat_r;
        wb_sel_next_r = wb_sel_r;

        DRAM_ADDRESS_NEXT = DRAM_ADDRESS;
        DRAM_DATA_WRITE0_NEXT = DRAM_DATA_WRITE0;
        DRAM_DATA_WRITE1_NEXT = DRAM_DATA_WRITE1;
        DRAM_DATA_WRITE2_NEXT = DRAM_DATA_WRITE2;
        DRAM_DATA_WRITE3_NEXT = DRAM_DATA_WRITE3;
        DRAM_DATA_READ0_NEXT = DRAM_DATA_READ0;
        DRAM_DATA_READ1_NEXT = DRAM_DATA_READ1;
        DRAM_DATA_READ2_NEXT = DRAM_DATA_READ2;
        DRAM_DATA_READ3_NEXT = DRAM_DATA_READ3;
        DRAM_RE_NEXT = DRAM_RE;
        DRAM_WE_NEXT = DRAM_WE;
        DRAM_WDG_NEXT = DRAM_WDG;

        counter_next = counter;

        ram_accept_next_r = ram_accept_r;
        ram_ack_next_r = ram_ack_r;

        if (ram_accept) begin
            ram_accept_next_r = 1'b1;
        end
        if (ram_ack) begin
            ram_ack_next_r = 1'b1;
            if(DRAM_RE) begin
                DRAM_DATA_READ0_NEXT = ram_rd_data[31:0];
                DRAM_DATA_READ1_NEXT = ram_rd_data[63:32];
                DRAM_DATA_READ2_NEXT = ram_rd_data[95:64];
                DRAM_DATA_READ3_NEXT = ram_rd_data[127:96];
            end
        end

        case (state_r)
            IDLE: begin
                if (wb_cyc_i && wb_stb_i && !wb_ack_r) begin
                    wb_adr_next_r = wb_adr_i;
                    DRAM_ADDRESS_NEXT = wb_adr_i & 32'hFFFFFFF0;
                    if (wb_we_i) begin
                        wb_dat_next_r = wb_dat_i;
                        wb_sel_next_r = wb_sel_i;
                        DRAM_RE_NEXT = 1;
                        state_next_r = WRITE_RMW_START;
                    end
                    else begin
                        DRAM_RE_NEXT = 1;
                        state_next_r = READ_START;
                    end
                end
            end

            WAIT: begin
                counter_next = counter + 1;
                if(counter >= 10) begin
                    state_next_r = IDLE;
                    counter_next = 0;
                end
            end

            WAIT_RMW: begin
                counter_next = counter + 1;
                if(counter >= 10) begin
                    DRAM_WE_NEXT = 1;
                    state_next_r = WRITE_START;
                    counter_next = 0;
                end
            end

            READ_START: begin
                if (ram_accept_r) begin
                    state_next_r = READ_WAIT_ACK;
                    ram_accept_next_r = 1'b0;
                end
            end

            READ_WAIT_ACK: begin
                if (ram_ack_r) begin
                    case (wb_adr_r[3:2])
                        2'b00: wb_read_data_next_r = DRAM_DATA_READ0; //ram_rd_data[31:0];
                        2'b01: wb_read_data_next_r = DRAM_DATA_READ1; //ram_rd_data[63:32];
                        2'b10: wb_read_data_next_r = DRAM_DATA_READ2; //ram_rd_data[95:64];
                        2'b11: wb_read_data_next_r = DRAM_DATA_READ3; //ram_rd_data[127:96];
                    endcase
                    wb_ack_next_r = 1;
                    state_next_r = WAIT;
                    ram_ack_next_r = 1'b0;
                    DRAM_RE_NEXT = 0;
                end
            end

            WRITE_RMW_START: begin
                if (ram_accept_r) begin
                    state_next_r = WRITE_RMW_WAIT_ACK;
                    ram_accept_next_r = 1'b0;
                end
            end

            WRITE_RMW_WAIT_ACK: begin
                if (ram_ack_r) begin
                    modified_rmw_data = {DRAM_DATA_READ3, DRAM_DATA_READ2, DRAM_DATA_READ1, DRAM_DATA_READ0}; //ram_rd_data;
                    case (wb_adr_r[3:2])
                        2'b00: begin
                            if(wb_sel_r[0]) modified_rmw_data[7:0]   = wb_dat_r[7:0];
                            if(wb_sel_r[1]) modified_rmw_data[15:8]  = wb_dat_r[15:8];
                            if(wb_sel_r[2]) modified_rmw_data[23:16] = wb_dat_r[23:16];
                            if(wb_sel_r[3]) modified_rmw_data[31:24] = wb_dat_r[31:24];
                        end
                        2'b01: begin
                            if(wb_sel_r[0]) modified_rmw_data[39:32] = wb_dat_r[7:0];
                            if(wb_sel_r[1]) modified_rmw_data[47:40] = wb_dat_r[15:8];
                            if(wb_sel_r[2]) modified_rmw_data[55:48] = wb_dat_r[23:16];
                            if(wb_sel_r[3]) modified_rmw_data[63:56] = wb_dat_r[31:24];
                        end
                        2'b10: begin
                            if(wb_sel_r[0]) modified_rmw_data[71:64] = wb_dat_r[7:0];
                            if(wb_sel_r[1]) modified_rmw_data[79:72] = wb_dat_r[15:8];
                            if(wb_sel_r[2]) modified_rmw_data[87:80] = wb_dat_r[23:16];
                            if(wb_sel_r[3]) modified_rmw_data[95:88] = wb_dat_r[31:24];
                        end
                        2'b11: begin
                            if(wb_sel_r[0]) modified_rmw_data[103:96]  = wb_dat_r[7:0];
                            if(wb_sel_r[1]) modified_rmw_data[111:104] = wb_dat_r[15:8];
                            if(wb_sel_r[2]) modified_rmw_data[119:112] = wb_dat_r[23:16];
                            if(wb_sel_r[3]) modified_rmw_data[127:120] = wb_dat_r[31:24];
                        end
                    endcase
                    DRAM_DATA_WRITE0_NEXT = modified_rmw_data[31:0];
                    DRAM_DATA_WRITE1_NEXT = modified_rmw_data[63:32];
                    DRAM_DATA_WRITE2_NEXT = modified_rmw_data[95:64];
                    DRAM_DATA_WRITE3_NEXT = modified_rmw_data[127:96];
                    state_next_r = WAIT_RMW;
                    ram_ack_next_r = 1'b0;
                    DRAM_RE_NEXT = 0;
                end
            end

            WRITE_START: begin
                if (ram_accept_r) begin
                    state_next_r = WRITE_WAIT_ACK;
                    ram_accept_next_r = 1'b0;
                end
            end

            WRITE_WAIT_ACK: begin
                if (ram_ack_r) begin
                    wb_ack_next_r = 1;
                    state_next_r = WAIT;
                    ram_ack_next_r = 1'b0;
                    DRAM_WE_NEXT = 0;
                end
            end
        endcase

        if (DRAM_WDG > 0) begin
            DRAM_WDG_NEXT = DRAM_WDG - 1;
        end
    end

    always_ff @(posedge clk_i) begin
        if (rst_i) begin
            wb_ack_r <= 0;
            wb_read_data_r <= 0;
    
            DRAM_ADDRESS <= 0;
            DRAM_DATA_WRITE0 <= 0;
            DRAM_DATA_WRITE1 <= 0;
            DRAM_DATA_WRITE2 <= 0;
            DRAM_DATA_WRITE3 <= 0;
            DRAM_DATA_READ0 <= 0;
            DRAM_DATA_READ1 <= 0;
            DRAM_DATA_READ2 <= 0;
            DRAM_DATA_READ3 <= 0;
            DRAM_RE <= 0;
            DRAM_WE <= 0;
            DRAM_WDG <= `CPU_CLK / 5000;

            state_r <= IDLE;
            wb_adr_r <= 0;
            wb_dat_r <= 0;
            wb_sel_r <= 0;

            ram_accept_r <= 1'b0;
            ram_ack_r <= 1'b0;

            counter <= 0;
        end
        else begin
            wb_ack_r <= wb_ack_next_r;
            wb_read_data_r <= wb_read_data_next_r;
    
            DRAM_ADDRESS <= DRAM_ADDRESS_NEXT;
            DRAM_DATA_WRITE0 <= DRAM_DATA_WRITE0_NEXT;
            DRAM_DATA_WRITE1 <= DRAM_DATA_WRITE1_NEXT;
            DRAM_DATA_WRITE2 <= DRAM_DATA_WRITE2_NEXT;
            DRAM_DATA_WRITE3 <= DRAM_DATA_WRITE3_NEXT;
            DRAM_DATA_READ0 <= DRAM_DATA_READ0_NEXT;
            DRAM_DATA_READ1 <= DRAM_DATA_READ1_NEXT;
            DRAM_DATA_READ2 <= DRAM_DATA_READ2_NEXT;
            DRAM_DATA_READ3 <= DRAM_DATA_READ3_NEXT;
            DRAM_RE <= DRAM_RE_NEXT;
            DRAM_WE <= DRAM_WE_NEXT;
            DRAM_WDG <= DRAM_WDG_NEXT;

            state_r <= state_next_r;
            wb_adr_r <= wb_adr_next_r;
            wb_dat_r <= wb_dat_next_r;
            wb_sel_r <= wb_sel_next_r;

            ram_accept_r <= ram_accept_next_r;
            ram_ack_r <= ram_ack_next_r;

            counter <= counter_next;
        end
    end
endmodule
