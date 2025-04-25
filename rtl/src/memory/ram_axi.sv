// Simple single-port RAM wrapped as an AXI4-Lite Slave
// Compatible with AXI4 Masters like CVA6
// Assumes single-cycle read latency

`timescale 1ns / 1ps

import axi_pkg::*; // Import standard AXI definitions (RESP_OKAY etc.)

module ram_axi #(
    parameter int unsigned AXI_ADDR_WIDTH = 32,
    parameter int unsigned AXI_DATA_WIDTH = 32,
    parameter int unsigned AXI_ID_WIDTH   = 4,  // Match CVA6 ID width
    // Internal RAM Parameters
    parameter SIZE = 16384, // Size in number of words (e.g., 16384 words * 4 bytes = 64KB)
    parameter INIT_FILE = ""
    // USE_BOOTROM parameter is removed as initialization is handled by INIT_FILE
) (
    // AXI Clock and Reset
    input  logic ACLK,
    input  logic ARESETn,

    // AXI Write Address Channel
    input  logic [AXI_ID_WIDTH-1:0]   AWID,
    input  logic [AXI_ADDR_WIDTH-1:0] AWADDR,
    input  logic                      AWVALID,
    output logic                      AWREADY,
    // AXI4-Lite ignores AWLEN, AWSIZE, AWBURST, AWLOCK, AWCACHE, AWPROT, AWQOS, AWREGION

    // AXI Write Data Channel
    input  logic [AXI_DATA_WIDTH-1:0] WDATA,
    input  logic [AXI_DATA_WIDTH/8-1:0] WSTRB,
    input  logic                      WVALID,
    output logic                      WREADY,
    // AXI4-Lite ignores WLAST

    // AXI Write Response Channel
    output logic [AXI_ID_WIDTH-1:0]   BID,
    output logic [1:0]                BRESP,
    output logic                      BVALID,
    input  logic                      BREADY,

    // AXI Read Address Channel
    input  logic [AXI_ID_WIDTH-1:0]   ARID,
    input  logic [AXI_ADDR_WIDTH-1:0] ARADDR,
    input  logic                      ARVALID,
    output logic                      ARREADY,
    // AXI4-Lite ignores ARLEN, ARSIZE, ARBURST, ARLOCK, ARCACHE, ARPROT, ARQOS, ARREGION

    // AXI Read Data Channel
    output logic [AXI_ID_WIDTH-1:0]   RID,
    output logic [AXI_DATA_WIDTH-1:0] RDATA,
    output logic [1:0]                RRESP,
    output logic                      RVALID,
    input  logic                      RREADY
    // AXI4-Lite ignores RLAST
);

    // Calculate internal address width based on SIZE (number of words)
    localparam int RAM_ADDR_W = $clog2(SIZE);
    // Check if AXI address range is sufficient
    initial begin
        if (RAM_ADDR_W + 2 > AXI_ADDR_WIDTH) begin
            $fatal(1,"AXI_ADDR_WIDTH (%0d) is too small for RAM SIZE (%0d words -> requires %0d bits)",
                     AXI_ADDR_WIDTH, SIZE, RAM_ADDR_W + 2);
        end
    end

    // Internal Memory Array (Core logic from ram32)
    logic [AXI_DATA_WIDTH-1:0] ram [SIZE*4];
    logic [RAM_ADDR_W-1:0]     mem_addr_idx; // Internal index into the ram array

    // Internal state registers and signals
    logic [AXI_ADDR_WIDTH-1:0] awaddr_reg;
    logic [AXI_ID_WIDTH-1:0]   awid_reg;
    logic                      aw_received; // Flag: AW phase done

    logic [AXI_ADDR_WIDTH-1:0] araddr_reg;
    logic [AXI_ID_WIDTH-1:0]   arid_reg;
    logic                      ar_received; // Flag: AR phase done

    logic [AXI_DATA_WIDTH-1:0] ram_read_data_reg; // Register to hold read data for output
    logic                      read_data_valid;   // Flag: Internal read data is ready

    // Internal write control
    logic                      write_en; // Internal signal to trigger RAM write

    // Assign internal memory index based on latched address
    // Assuming word addressing (bottom 2 bits ignored for word index)
    assign mem_addr_idx = (aw_received ? awaddr_reg[RAM_ADDR_W-1+2:2] : araddr_reg[RAM_ADDR_W-1+2:2]);

    //-----------------------------------------------------
    // AXI Write Logic
    //-----------------------------------------------------

    // AWREADY logic: Ready to accept address if not already processing a write
    // and B channel handshake is complete (BVALID is low or BREADY is high)
    assign AWREADY = !aw_received && (!BVALID || BREADY);

    // WREADY logic: Ready to accept data only after address is received
    assign WREADY = aw_received && (!BVALID || BREADY);

    // Latch AW channel info when handshake happens (AWVALID & AWREADY)
    always @(posedge ACLK or negedge ARESETn) begin
        if (!ARESETn) begin
            awaddr_reg  <= '0;
            awid_reg    <= '0;
            aw_received <= 1'b0;
        end else begin
            if (AWVALID && AWREADY) begin
                awaddr_reg  <= AWADDR;
                awid_reg    <= AWID;
                aw_received <= 1'b1;
            end else if (BVALID && BREADY) begin
                // Clear flag when B channel handshake completes
                aw_received <= 1'b0;
            end
        end
    end

    // Internal write enable generation: Trigger write one cycle after W channel handshake
    always @(posedge ACLK or negedge ARESETn) begin
        if (!ARESETn) begin
            write_en <= 1'b0;
        end else begin
            // Assert write_en if W channel handshake happens AND AW was received
            write_en <= WVALID && WREADY && aw_received;
        end
    end

    // Perform the synchronous RAM write (adapted from ram32)
    always @(posedge ACLK) begin
        if (write_en) begin // Use internal write enable signal
            // Use latched address (awaddr_reg) and current WDATA/WSTRB
            for (int i = 0; i < (AXI_DATA_WIDTH / 8); i++) begin
                if (WSTRB[i] == 1'b1) begin
                    ram[awaddr_reg[RAM_ADDR_W-1+2:2]][i*8 +: 8] <= WDATA[i*8 +: 8];
                end
            end
        end
    end

    // B channel logic
    logic bvalid_reg;
    logic [AXI_ID_WIDTH-1:0] bid_reg;

    assign BVALID = bvalid_reg;
    assign BID    = bid_reg;
    assign BRESP  = axi_pkg::RESP_OKAY; // Always OKAY for this simple RAM

    always @(posedge ACLK or negedge ARESETn) begin
        if (!ARESETn) begin
            bvalid_reg <= 1'b0;
            bid_reg    <= '0;
        end else begin
            if (write_en) begin // BVALID goes high one cycle after internal write starts
                bvalid_reg <= 1'b1;
                bid_reg    <= awid_reg; // Use latched AWID
            end else if (BVALID && BREADY) begin // Handshake complete
                bvalid_reg <= 1'b0;
            end
        end
    end

    //-----------------------------------------------------
    // AXI Read Logic
    //-----------------------------------------------------

    // ARREADY logic: Ready to accept address if not already processing a read
    // and R channel handshake is complete (RVALID is low or RREADY is high)
    assign ARREADY = !ar_received && (!RVALID || RREADY);

    // Latch AR channel info when handshake happens (ARVALID & ARREADY)
    always @(posedge ACLK or negedge ARESETn) begin
        if (!ARESETn) begin
            araddr_reg  <= '0;
            arid_reg    <= '0;
            ar_received <= 1'b0;
        end else begin
            if (ARVALID && ARREADY) begin
                araddr_reg  <= ARADDR;
                arid_reg    <= ARID;
                ar_received <= 1'b1;
            end else if (RVALID && RREADY) begin
                 // Clear flag when R channel handshake completes
                 ar_received <= 1'b0;
            end
        end
    end

    // Internal synchronous read data capture (1 cycle latency)
    // Replicates behavior of original `rvalid_o <= req_i`
    always @(posedge ACLK or negedge ARESETn) begin
        if (!ARESETn) begin
            ram_read_data_reg <= '0;
            read_data_valid   <= 1'b0;
        end else begin
            if (ARVALID && ARREADY) begin
                // Start read access on the cycle address is accepted
                ram_read_data_reg <= ram[ARADDR[RAM_ADDR_W-1+2:2]]; // Read from ram
                read_data_valid   <= 1'b1; // Data will be valid NEXT cycle
            end else if (RVALID && RREADY) begin
                // Deassert valid once handshake completes
                read_data_valid <= 1'b0;
            end else if (!ar_received) begin
                 // Deassert if no read is active
                 read_data_valid <= 1'b0;
            end
            // Note: ram_read_data_reg holds the value during RVALID assertion
        end
    end

    // R channel logic
    assign RVALID = read_data_valid; // RVALID is high when internal read data is ready
    assign RDATA  = ram_read_data_reg; // Output the registered read data
    assign RID    = arid_reg; // Use latched ARID
    assign RRESP  = axi_pkg::RESP_OKAY; // Always OKAY

    //-----------------------------------------------------
    // Memory Initialization (Core logic from ram32)
    //-----------------------------------------------------
    initial begin
        for (int i = 0; i < SIZE; i++) begin
            ram[i] = {AXI_DATA_WIDTH{1'b0}}; // Use parameter for width
        end
        if (INIT_FILE != "") begin
            $display("AXI RAM: Initializing memory from %s", INIT_FILE);
            $readmemh(INIT_FILE, ram);
        end else begin
            $display("AXI RAM: No INIT_FILE specified, memory initialized to zeros.");
        end
    end

endmodule
