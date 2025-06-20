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
    reg DRAM_ACCEPT;
    reg DRAM_ACCEPT_NEXT;
    reg DRAM_ACK;
    reg DRAM_ACK_NEXT;
    reg [31:0] DRAM_WDG;
    reg [31:0] DRAM_WDG_NEXT;

    wire [31:0] data_read_w0;
    wire [31:0] data_read_w1;
    wire [31:0] data_read_w2;
    wire [31:0] data_read_w3;
 
    `ifdef ZC706
    wire [31:0]  ram_addr = DRAM_ADDRESS;
    wire         ram_wr = DRAM_WE;
    reg [15:0]   ram_wr_sel;
    reg [15:0]   ram_wr_sel_next;
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
       .wr_sel(ram_wr_sel),
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

    assign data_read_w0 = ram_rd_data[31:0];
    assign data_read_w1 = ram_rd_data[63:32];
    assign data_read_w2 = ram_rd_data[95:64];
    assign data_read_w3 = ram_rd_data[127:96];
 
    always @* begin
        wb_ack_next_r = 0;
        wb_read_data_next_r = 0;
    
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
        DRAM_ACCEPT_NEXT = DRAM_ACCEPT;
        DRAM_ACK_NEXT = DRAM_ACK;

        ram_wr_sel_next = ram_wr_sel;
    
        if(wb_cyc_i) begin
            wb_ack_next_r = DRAM_ACK; //wb_stb_i & !wb_ack_r;
            if(wb_stb_i & wb_we_i & !wb_ack_o) begin // write
                DRAM_WE_NEXT = 1;
                case(wb_adr_i % 16)
                    0: begin
                        DRAM_DATA_WRITE0_NEXT[7:0  ] = wb_sel_i[0] ? wb_dat_i[7:0  ] : DRAM_DATA_WRITE0[7:0  ];
                        DRAM_DATA_WRITE0_NEXT[15:8 ] = wb_sel_i[1] ? wb_dat_i[15:8 ] : DRAM_DATA_WRITE0[15:8 ];
                        DRAM_DATA_WRITE0_NEXT[23:16] = wb_sel_i[2] ? wb_dat_i[23:16] : DRAM_DATA_WRITE0[23:16];
                        DRAM_DATA_WRITE0_NEXT[31:24] = wb_sel_i[3] ? wb_dat_i[31:24] : DRAM_DATA_WRITE0[31:24];
                        DRAM_ADDRESS_NEXT = wb_adr_i;
                        ram_wr_sel_next = 16'h0001;
                    end
                    4: begin
                        DRAM_DATA_WRITE1_NEXT[7:0  ] = wb_sel_i[0] ? wb_dat_i[7:0  ] : DRAM_DATA_WRITE1[7:0  ];
                        DRAM_DATA_WRITE1_NEXT[15:8 ] = wb_sel_i[1] ? wb_dat_i[15:8 ] : DRAM_DATA_WRITE1[15:8 ];
                        DRAM_DATA_WRITE1_NEXT[23:16] = wb_sel_i[2] ? wb_dat_i[23:16] : DRAM_DATA_WRITE1[23:16];
                        DRAM_DATA_WRITE1_NEXT[31:24] = wb_sel_i[3] ? wb_dat_i[31:24] : DRAM_DATA_WRITE1[31:24];
                        DRAM_ADDRESS_NEXT = wb_adr_i;
                        ram_wr_sel_next = 16'h0010;
                    end
                    8: begin
                        DRAM_DATA_WRITE2_NEXT[7:0  ] = wb_sel_i[0] ? wb_dat_i[7:0  ] : DRAM_DATA_WRITE2[7:0  ];
                        DRAM_DATA_WRITE2_NEXT[15:8 ] = wb_sel_i[1] ? wb_dat_i[15:8 ] : DRAM_DATA_WRITE2[15:8 ];
                        DRAM_DATA_WRITE2_NEXT[23:16] = wb_sel_i[2] ? wb_dat_i[23:16] : DRAM_DATA_WRITE2[23:16];
                        DRAM_DATA_WRITE2_NEXT[31:24] = wb_sel_i[3] ? wb_dat_i[31:24] : DRAM_DATA_WRITE2[31:24];
                        DRAM_ADDRESS_NEXT = wb_adr_i;
                        ram_wr_sel_next = 16'h0100;
                    end
                    12: begin
                        DRAM_DATA_WRITE3_NEXT[7:0  ] = wb_sel_i[0] ? wb_dat_i[7:0  ] : DRAM_DATA_WRITE3[7:0  ];
                        DRAM_DATA_WRITE3_NEXT[15:8 ] = wb_sel_i[1] ? wb_dat_i[15:8 ] : DRAM_DATA_WRITE3[15:8 ];
                        DRAM_DATA_WRITE3_NEXT[23:16] = wb_sel_i[2] ? wb_dat_i[23:16] : DRAM_DATA_WRITE3[23:16];
                        DRAM_DATA_WRITE3_NEXT[31:24] = wb_sel_i[3] ? wb_dat_i[31:24] : DRAM_DATA_WRITE3[31:24];
                        DRAM_ADDRESS_NEXT = wb_adr_i;
                        ram_wr_sel_next = 16'h1000;
                    end
                endcase
            end 
            else if(!wb_we_i) begin // read
                DRAM_RE_NEXT = 1;
                case(wb_adr_i % 16)
                    0: begin
                        wb_read_data_next_r = DRAM_DATA_READ0;
                        DRAM_ADDRESS_NEXT = wb_adr_i;
                    end
                    4: begin
                        wb_read_data_next_r = DRAM_DATA_READ1;
                        DRAM_ADDRESS_NEXT = wb_adr_i;
                    end
                    8: begin
                        wb_read_data_next_r = DRAM_DATA_READ2;
                        DRAM_ADDRESS_NEXT = wb_adr_i;
                    end
                    12: begin
                        wb_read_data_next_r = DRAM_DATA_READ3;
                        DRAM_ADDRESS_NEXT = wb_adr_i;
                    end
                endcase
            end
        end

        if (DRAM_WDG > 0) begin
            DRAM_WDG_NEXT = DRAM_WDG - 1;
        end

        DRAM_DATA_READ0_NEXT = data_read_w0;
        DRAM_DATA_READ1_NEXT = data_read_w1;
        DRAM_DATA_READ2_NEXT = data_read_w2;
        DRAM_DATA_READ3_NEXT = data_read_w3;

        // TODO: prevent 2 times read and write to dram
        if(ram_accept) DRAM_ACCEPT_NEXT = 1;
        if(ram_ack) DRAM_ACK_NEXT = 1;

        // if previous RE or WE acked, then reset the RE and WE
        if(DRAM_ACK) DRAM_RE_NEXT = 0;
        if(DRAM_ACK) DRAM_WE_NEXT = 0;

        // if RE and WE is resetted, then reset the ACCEPT and ACK
        if(!DRAM_RE & !DRAM_WE) begin
            DRAM_ACCEPT_NEXT = 0;
            DRAM_ACK_NEXT = 0;
            wb_ack_next_r = 0;
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
            DRAM_ACCEPT <= 0;
            DRAM_ACK <= 0;
            DRAM_WDG <= `CPU_CLK / 5000;

            ram_wr_sel <= 16'h1111;
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
            DRAM_ACCEPT <= DRAM_ACCEPT_NEXT;
            DRAM_ACK <= DRAM_ACK_NEXT;
            DRAM_WDG <= DRAM_WDG_NEXT;

            ram_wr_sel <= ram_wr_sel_next;
        end
    end

endmodule
