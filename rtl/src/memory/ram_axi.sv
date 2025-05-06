// ram32_axi.sv
`timescale 1ns / 1ps

import axi_pkg::*; // Assuming axi_pkg is available

module ram32_axi #(
    parameter int unsigned AXI_ID_WIDTH   = 4, // Example ID width - **MUST MATCH XBAR MASTER PORT ID WIDTH**
    parameter int unsigned AXI_ADDR_WIDTH = 32,
    parameter int unsigned AXI_DATA_WIDTH = 32,
    parameter int unsigned RAM_DEPTH      = 16384,
    parameter string       INIT_FILE      = ""
) (
    // Clock and Reset
    input  logic clk_i,
    input  logic rst_ni,

    // AXI4-Lite Slave Interface (with IDs)
    input  logic                            s_axi_awvalid,
    output logic                            s_axi_awready,
    input  logic [AXI_ADDR_WIDTH-1:0]       s_axi_awaddr,
    input  logic [AXI_ID_WIDTH-1:0]         s_axi_awid,   // <-- Added
    input  logic [2:0]                      s_axi_awprot, // Ignored
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
    input  logic [2:0]                      s_axi_arprot, // Ignored
    output logic                            s_axi_rvalid,
    input  logic                            s_axi_rready,
    output logic [AXI_ID_WIDTH-1:0]         s_axi_rid,    // <-- Added
    output logic [AXI_DATA_WIDTH-1:0]       s_axi_rdata,
    output logic [1:0]                      s_axi_rresp
);

    localparam int ADDR_W = $clog2(RAM_DEPTH);
    localparam int DATA_BYTES = AXI_DATA_WIDTH / 8;

    initial begin // Sanity checks
        if (AXI_ID_WIDTH == 0) $warning("ram32_axi: AXI_ID_WIDTH is 0. Ensure this matches the interconnect.");
        if (ADDR_W > AXI_ADDR_WIDTH - $clog2(DATA_BYTES)) $fatal(1,"RAM_DEPTH is too large for AXI_ADDR_WIDTH");
    end

    logic [AXI_DATA_WIDTH-1:0] ram [RAM_DEPTH-1:0];
    logic [ADDR_W-1:0] ram_addr_idx;
    logic [ADDR_W-1:0] read_addr_idx;
    assign ram_addr_idx = s_axi_awaddr[ADDR_W + $clog2(DATA_BYTES) - 1 : $clog2(DATA_BYTES)];
    assign read_addr_idx = s_axi_araddr[ADDR_W + $clog2(DATA_BYTES) - 1 : $clog2(DATA_BYTES)];

    // Registers for AXI state and IDs
    logic aw_transfer_pending;
    logic ar_transfer_pending;
    logic [AXI_ID_WIDTH-1:0] reg_awid;
    logic [AXI_ID_WIDTH-1:0] reg_arid;
    logic [AXI_DATA_WIDTH-1:0] read_data_reg;
    logic bvalid_reg;
    logic rvalid_reg;

    // --- Write Channel Logic ---
    assign s_axi_awready = !aw_transfer_pending;
    assign s_axi_wready  = aw_transfer_pending;

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            aw_transfer_pending <= 1'b0;
            reg_awid <= '0;
        end else begin
            if (s_axi_awvalid && s_axi_awready) begin
                aw_transfer_pending <= 1'b1;
                reg_awid <= s_axi_awid; // Capture AWID
            end else if (s_axi_wvalid && s_axi_wready) begin
                aw_transfer_pending <= 1'b0;
            end
        end
    end

    always @(posedge clk_i) begin // Memory write
        if (s_axi_wvalid && s_axi_wready) begin
             for (int i = 0; i < DATA_BYTES; i++) begin
                 if (s_axi_wstrb[i]) ram[ram_addr_idx][i*8 +: 8] <= s_axi_wdata[i*8 +: 8];
             end
        end
    end

    // --- Write Response Channel Logic (B) ---
    assign s_axi_bvalid = bvalid_reg;
    assign s_axi_bresp  = RESP_OKAY;
    assign s_axi_bid    = reg_awid; // Return captured AWID

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            bvalid_reg <= 1'b0;
        end else begin
            if (s_axi_wvalid && s_axi_wready) begin
                bvalid_reg <= 1'b1;
            end else if (s_axi_bready && s_axi_bvalid) begin
                bvalid_reg <= 1'b0;
            end
        end
    end

    // --- Read Channel Logic ---
    assign s_axi_arready = !ar_transfer_pending;
    assign s_axi_rresp   = RESP_OKAY;
    assign s_axi_rvalid  = rvalid_reg;
    assign s_axi_rdata   = read_data_reg;
    assign s_axi_rid     = reg_arid; // Return captured ARID

    always @(posedge clk_i or negedge rst_ni) begin // Read Address and Data Path
         if (!rst_ni) begin
             ar_transfer_pending <= 1'b0;
             read_data_reg <= '0;
             reg_arid <= '0;
         end else begin
             if (s_axi_arvalid && s_axi_arready) begin
                 ar_transfer_pending <= 1'b1;
                 read_data_reg <= ram[read_addr_idx]; // Read data combinationally
                 reg_arid <= s_axi_arid; // Capture ARID
             end else if (s_axi_rready && s_axi_rvalid) begin // If response accepted this cycle
                 ar_transfer_pending <= 1'b0;
                 read_data_reg <= '0;
                 // Keep reg_arid until next AR transfer
             end else if (ar_transfer_pending) begin
                 // Hold read data if RVALID is asserted but RREADY is not yet high
                 read_data_reg <= read_data_reg;
                 reg_arid <= reg_arid; // Hold ID too
             end else begin
                 read_data_reg <= '0;
             end
         end
     end

     always_ff @(posedge clk_i or negedge rst_ni) begin // Read Valid Path
         if (!rst_ni) begin
             rvalid_reg <= 1'b0;
         end else begin
             if (s_axi_arvalid && s_axi_arready) begin
                 rvalid_reg <= 1'b1; // Assert RVALID next cycle
             end else if (s_axi_rready && s_axi_rvalid) begin
                 rvalid_reg <= 1'b0; // Deassert RVALID next cycle
             end else if (rvalid_reg) begin
                 // Keep RVALID asserted if master is not ready
                 rvalid_reg <= 1'b1;
             end else begin
                 rvalid_reg <= 1'b0;
             end
         end
     end

    generate
    if (INIT_FILE != "") begin: use_init_file
      initial
        $readmemh(INIT_FILE, ram, 0, RAM_DEPTH-1);
    end else begin: init_bram_to_zero
      integer ram_index;
      initial
        for (ram_index = 0; ram_index < RAM_DEPTH; ram_index = ram_index + 1)
          ram[ram_index] = {(32){1'b0}};
    end
    endgenerate

endmodule