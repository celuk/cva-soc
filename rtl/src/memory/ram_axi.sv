// ram32_axi_lite.sv
`timescale 1ns / 1ps

import axi_pkg::*; // Assuming axi_pkg is available

module ram32_axi #(
    parameter int unsigned AXI_ID_WIDTH   = 4,  // ID width - for tracking transactions
    parameter int unsigned AXI_ADDR_WIDTH = 32,
    parameter int unsigned AXI_DATA_WIDTH = 32,
    parameter int unsigned RAM_DEPTH      = 16384,
    parameter string       INIT_FILE      = ""
) (
    // Clock and Reset
    input  logic clk_i,
    input  logic rst_ni,

    // AXI4-Lite Slave Interface with IDs
    input  logic                            s_axi_awvalid,
    output logic                            s_axi_awready,
    input  logic [AXI_ADDR_WIDTH-1:0]       s_axi_awaddr,
    input  logic [AXI_ID_WIDTH-1:0]         s_axi_awid,   // Added for transaction tracking
    input  logic [2:0]                      s_axi_awprot, // Required by AXI4-Lite but ignored
    
    input  logic                            s_axi_wvalid,
    output logic                            s_axi_wready,
    input  logic [AXI_DATA_WIDTH-1:0]       s_axi_wdata,
    input  logic [AXI_DATA_WIDTH/8-1:0]     s_axi_wstrb,
    
    output logic                            s_axi_bvalid,
    input  logic                            s_axi_bready,
    output logic [AXI_ID_WIDTH-1:0]         s_axi_bid,    // Return ID with response
    output logic [1:0]                      s_axi_bresp,
    
    input  logic                            s_axi_arvalid,
    output logic                            s_axi_arready,
    input  logic [AXI_ADDR_WIDTH-1:0]       s_axi_araddr,
    input  logic [AXI_ID_WIDTH-1:0]         s_axi_arid,   // Added for transaction tracking
    input  logic [2:0]                      s_axi_arprot, // Required by AXI4-Lite but ignored
    
    output logic                            s_axi_rvalid,
    input  logic                            s_axi_rready,
    output logic [AXI_ID_WIDTH-1:0]         s_axi_rid,    // Return ID with response
    output logic [AXI_DATA_WIDTH-1:0]       s_axi_rdata,
    output logic [1:0]                      s_axi_rresp
);

    // Local parameters
    localparam int ADDR_W = $clog2(RAM_DEPTH);
    localparam int DATA_BYTES = AXI_DATA_WIDTH / 8;

    // Sanity checks
    initial begin
        if (AXI_ID_WIDTH == 0) $warning("ram32_axi_lite: AXI_ID_WIDTH is 0. Ensure this matches the interconnect.");
        if (ADDR_W > AXI_ADDR_WIDTH - $clog2(DATA_BYTES)) $fatal(1,"RAM_DEPTH is too large for AXI_ADDR_WIDTH");
    end

    // Memory
    logic [AXI_DATA_WIDTH-1:0] ram [RAM_DEPTH-1:0];
    
    // Address calculation for write operations
    logic [ADDR_W-1:0] ram_addr_idx;
    assign ram_addr_idx = s_axi_awaddr[ADDR_W + $clog2(DATA_BYTES) - 1 : $clog2(DATA_BYTES)];
    
    // Registered versions of important signals
    logic [ADDR_W-1:0] write_addr_q;
    logic [ADDR_W-1:0] read_addr_q;
    logic [AXI_ID_WIDTH-1:0] reg_awid_q;
    logic [AXI_ID_WIDTH-1:0] reg_arid_q;
    logic [AXI_DATA_WIDTH-1:0] read_data_q;
    
    // ----------------------
    // Write Channel Logic
    // ----------------------
    
    // Write state machine states
    typedef enum logic [1:0] {
        W_IDLE,
        W_DATA,
        W_RESP
    } write_state_e;
    
    write_state_e write_state_q, write_state_d;
    
    // Write state machine
    always_comb begin
        // Default values
        write_state_d = write_state_q;
        s_axi_awready = 1'b0;
        s_axi_wready = 1'b0;
        s_axi_bvalid = 1'b0;
        
        case (write_state_q)
            W_IDLE: begin
                // Ready to accept a write address
                s_axi_awready = 1'b1;
                
                if (s_axi_awvalid) begin
                    // Address accepted, move to data phase
                    write_state_d = W_DATA;
                end
            end
            
            W_DATA: begin
                // Ready to accept write data
                s_axi_wready = 1'b1;
                
                if (s_axi_wvalid) begin
                    // Data accepted, move to response phase
                    write_state_d = W_RESP;
                end
            end
            
            W_RESP: begin
                // Present write response
                s_axi_bvalid = 1'b1;
                
                if (s_axi_bready) begin
                    // Response accepted, return to idle
                    write_state_d = W_IDLE;
                end
            end
            
            default: write_state_d = W_IDLE;
        endcase
    end
    
    // Write state and control signals register
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            write_state_q <= W_IDLE;
            reg_awid_q <= '0;
            write_addr_q <= '0;
        end else begin
            write_state_q <= write_state_d;
            
            // Capture write address and ID when accepting address
            if (s_axi_awvalid && s_axi_awready) begin
                reg_awid_q <= s_axi_awid;
                write_addr_q <= ram_addr_idx;
            end
        end
    end
    
    // Memory write operation
    always @(posedge clk_i) begin
        if (s_axi_wvalid && s_axi_wready) begin
            for (int i = 0; i < DATA_BYTES; i++) begin
                if (s_axi_wstrb[i]) begin
                    ram[write_addr_q][i*8 +: 8] <= s_axi_wdata[i*8 +: 8];
                end
            end
        end
    end
    
    // Write response signals
    assign s_axi_bid = reg_awid_q;
    assign s_axi_bresp = RESP_OKAY; // Always return OKAY for successful writes
    
    // ----------------------
    // Read Channel Logic
    // ----------------------
    
    // Read state machine states
    typedef enum logic [1:0] {
        R_IDLE,
        R_DATA
    } read_state_e;
    
    read_state_e read_state_q, read_state_d;
    
    // Calculate read address
    logic [ADDR_W-1:0] read_addr_idx;
    assign read_addr_idx = s_axi_araddr[ADDR_W + $clog2(DATA_BYTES) - 1 : $clog2(DATA_BYTES)];
    
    // Read state machine
    always_comb begin
        // Default values
        read_state_d = read_state_q;
        s_axi_arready = 1'b0;
        s_axi_rvalid = 1'b0;
        
        case (read_state_q)
            R_IDLE: begin
                // Ready to accept a read address
                s_axi_arready = 1'b1;
                
                if (s_axi_arvalid) begin
                    // Address accepted, move to data phase
                    read_state_d = R_DATA;
                end
            end
            
            R_DATA: begin
                // Present read data
                s_axi_rvalid = 1'b1;
                
                if (s_axi_rready) begin
                    // Data accepted by master, return to idle
                    read_state_d = R_IDLE;
                end
            end
            
            default: read_state_d = R_IDLE;
        endcase
    end
    
    // Read state and data register
    always @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            read_state_q <= R_IDLE;
            reg_arid_q <= '0;
            read_addr_q <= '0;
            read_data_q <= '0;
        end else begin
            read_state_q <= read_state_d;
            
            // Capture read address and ID when accepting address
            if (s_axi_arvalid && s_axi_arready) begin
                reg_arid_q <= s_axi_arid;
                read_addr_q <= read_addr_idx;
                // Read data from memory when address is captured
                read_data_q <= ram[read_addr_idx];
            end
        end
    end
    
    // Read data and response signals
    assign s_axi_rid = reg_arid_q;
    assign s_axi_rdata = read_data_q;
    assign s_axi_rresp = RESP_OKAY; // Always return OKAY for successful reads
    
    // Initialize memory if requested
    generate
        if (INIT_FILE != "") begin: use_init_file
            initial
                $readmemh(INIT_FILE, ram, 0, RAM_DEPTH-1);
        end else begin: init_bram_to_zero
            integer ram_index;
            initial
                for (ram_index = 0; ram_index < RAM_DEPTH; ram_index = ram_index + 1)
                    ram[ram_index] = {AXI_DATA_WIDTH{1'b0}};
        end
    endgenerate

endmodule
