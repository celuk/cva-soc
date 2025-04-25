`timescale 1ns / 1ps

// Import necessary packages
import ariane_axi::*;
// Ensure axi_pkg is available if RESP_OKAY is used directly from it
// import axi_pkg::*;

module axi_to_obi_adapter #(
    // Parameters should match CVA6 configuration (CVA6Cfg)
    // Ensure these match your specific CVA6 configuration and SoC bus widths
    parameter int unsigned AXI_ADDR_WIDTH = 32,
    parameter int unsigned AXI_DATA_WIDTH = 32,
    parameter int unsigned AXI_ID_WIDTH   = 4,
    parameter int unsigned AXI_USER_WIDTH = 1, // Adjust if CVA6 uses user signals

    // RAM Latency Assumption (in cycles, after req is asserted)
    // Since there's no grant, we assume the RAM starts access immediately.
    // If rvalid takes N cycles after req, set LATENCY = N.
    // For your previous example (rvalid 1 cycle after req), LATENCY = 1.
    // A purely combinatorial RAM would have LATENCY = 0.
    parameter int unsigned RAM_READ_LATENCY = 1 // Adjust based on ram32 behavior
) (
    input  logic                          clk_i,
    input  logic                          rst_ni,

    // AXI Interface towards CVA6 Core
    input  ariane_axi::req_t              axi_req_i,
    output ariane_axi::resp_t             axi_resp_o,

    // Unified OBI-like Interface towards RAM
    output logic                          mem_req_o,  // To ram32.req_i
    output logic                          mem_we_o,   // To ram32.we_i (combined with req)
    output logic [(AXI_DATA_WIDTH/8)-1:0] mem_be_o,   // To ram32.be_i
    output logic [AXI_ADDR_WIDTH-1:0]     mem_addr_o, // To ram32.addr_i
    output logic [AXI_DATA_WIDTH-1:0]     mem_wdata_o,// To ram32.wdata_i
    input  logic                          mem_rvalid_i,// From ram32.rvalid_o
    input  logic [AXI_DATA_WIDTH-1:0]     mem_rdata_i // From ram32.rdata_o
);

    // Internal signals and state machine variables
    typedef enum logic [1:0] {
        IDLE,
        REQ_READ,     // Issuing read request to RAM (replaces WAIT_GNT)
        WAIT_RVALID,  // Waiting for read data from RAM
        REQ_WRITE     // Issuing write request to RAM & handling B resp (replaces WAIT_GNT)
    } state_e;

    // State registers
    state_e read_state_q, read_state_n;
    state_e write_state_q, write_state_n;

    // Latched AXI request info (using types from imported package)
    ariane_axi::id_t             latched_ar_id;
    ariane_axi::addr_t           latched_ar_addr;
    // Add latched ar.len etc. if handling bursts

    ariane_axi::id_t             latched_aw_id;
    ariane_axi::addr_t           latched_aw_addr;
    logic                        latched_aw_valid; // Flag: AW info latched
    // Add latched aw.len etc. if handling bursts

    ariane_axi::data_t           latched_w_data;
    ariane_axi::strb_t           latched_w_strb;
    logic                        latched_w_last; // Flag from W channel
    logic                        latched_w_valid; // Flag: W info latched

    // Counter for read latency simulation (if needed, assumes fixed latency)
    logic [$clog2(RAM_READ_LATENCY+1)-1:0] read_latency_cnt_q, read_latency_cnt_n;
    logic read_latency_done;

    // --- Internal Wires for Combinational Logic ---
    logic can_accept_ar;   // Adapter ready for AR
    logic can_accept_aw;   // Adapter ready for AW
    logic can_accept_w;    // Adapter ready for W

    //--------------------------------------------------------------------------
    // Combinational Logic Block
    //--------------------------------------------------------------------------
    always_comb begin
        // --- Default assignments ---
        // Default all outputs to prevent latches and define non-active state
        axi_resp_o.ar_ready = 1'b0;
        axi_resp_o.aw_ready = 1'b0;
        axi_resp_o.w_ready  = 1'b0;
        axi_resp_o.r_valid  = 1'b0;
        axi_resp_o.r.id     = '0;
        axi_resp_o.r.data   = '0;
        axi_resp_o.r.resp   = axi_pkg::RESP_OKAY;
        axi_resp_o.r.last   = 1'b0;
        axi_resp_o.r.user   = '0;
        axi_resp_o.b_valid  = 1'b0;
        axi_resp_o.b.id     = '0;
        axi_resp_o.b.resp   = axi_pkg::RESP_OKAY;
        axi_resp_o.b.user   = '0;

        // OBI Interface Defaults
        mem_req_o   = 1'b0; // Default request inactive
        mem_we_o    = 1'b0; // Default write disabled
        mem_be_o    = '0;   // Default byte enable
        mem_addr_o  = '0;   // Default address
        mem_wdata_o = '0;   // Default write data

        // State machine next state defaults
        read_state_n  = read_state_q;
        write_state_n = write_state_q;
        read_latency_cnt_n = read_latency_cnt_q; // Counter default
        read_latency_done = (read_latency_cnt_q == RAM_READ_LATENCY); // Latency check

        // --- AXI Input Handshake Logic ---
        // Calculate readiness based on state machine status
        // Can accept AR only if read state machine is idle AND write SM isn't active
        can_accept_ar = (read_state_q == IDLE) && (write_state_q == IDLE);
        // Can accept AW only if write state machine is idle AND no previous AW is pending W data
        // AND read SM isn't active
        can_accept_aw = (write_state_q == IDLE) && !latched_aw_valid && (read_state_q == IDLE);
        // Can accept W only if AW info has been latched and W data hasn't yet
        can_accept_w = latched_aw_valid && !latched_w_valid;

        // Assign AXI READY signals
        axi_resp_o.ar_ready = axi_req_i.ar_valid && can_accept_ar;
        axi_resp_o.aw_ready = axi_req_i.aw_valid && can_accept_aw;
        axi_resp_o.w_ready  = axi_req_i.w_valid && can_accept_w;

        // --- Read State Machine (Combinational Part) ---
        case (read_state_q)
            IDLE: begin
                // If core sends valid read request and adapter is ready, accept it
                if (axi_req_i.ar_valid && axi_resp_o.ar_ready) begin
                    read_state_n = REQ_READ; // Move to issue OBI request
                end
            end
            REQ_READ: begin
                // Assert OBI request for one cycle
                mem_req_o = 1'b1;
                mem_we_o  = 1'b0; // It's a read
                mem_addr_o = latched_ar_addr;

                // Since no grant, assume RAM accepts. Move to wait for data.
                // Start latency counter
                read_latency_cnt_n = (RAM_READ_LATENCY == 0) ? 0 : 1;
                read_state_n = WAIT_RVALID;
            end
            WAIT_RVALID: begin
                // Wait for RAM latency OR direct rvalid signal
                // Option 1: Using direct mem_rvalid_i
                // if (mem_rvalid_i) begin

                // Option 2: Using fixed latency counter (use if mem_rvalid_i timing is less reliable)
                if (read_latency_done || mem_rvalid_i) begin // Check counter OR direct signal
                    // Make the response available on the AXI R channel
                    axi_resp_o.r_valid = 1'b1;
                    axi_resp_o.r.data  = mem_rdata_i; // Use data from RAM
                    axi_resp_o.r.id    = latched_ar_id;
                    axi_resp_o.r.last  = 1'b1; // Assuming single beat
                    axi_resp_o.r.resp  = axi_pkg::RESP_OKAY;

                    // Check if CVA6 core is ready to accept the AXI response
                    if (axi_req_i.r_ready) begin
                       // CVA6 accepted the data, transaction complete
                       read_state_n = IDLE;
                       read_latency_cnt_n = 0; // Reset counter
                    end else begin
                       // CVA6 is NOT ready. Stay in WAIT_RVALID, keep r_valid asserted.
                       read_state_n = WAIT_RVALID;
                       // Keep counter maxed out or don't change it
                       read_latency_cnt_n = RAM_READ_LATENCY;
                    end
                end else if (RAM_READ_LATENCY > 0) begin
                    // Increment latency counter if not done
                    read_latency_cnt_n = read_latency_cnt_q + 1;
                end
                // Stay in WAIT_RVALID if data not yet valid / latency not met
            end
            default: read_state_n = IDLE;
        endcase

        // --- Write State Machine (Combinational Part) ---
        case (write_state_q)
            IDLE: begin
                // If both AW and W info for a transaction have been latched, move to request OBI
                if (latched_aw_valid && latched_w_valid) begin
                    write_state_n = REQ_WRITE;
                end
            end
            REQ_WRITE: begin
                // Assert OBI write request and drive data for one cycle
                mem_req_o   = 1'b1;
                mem_we_o    = 1'b1; // It's a write
                mem_addr_o  = latched_aw_addr;
                mem_be_o    = latched_w_strb;
                mem_wdata_o = latched_w_data;

                // Since no grant, assume RAM accepted the write.
                // Generate AXI Write Response (B channel) immediately.
                axi_resp_o.b_valid = 1'b1;
                axi_resp_o.b.id    = latched_aw_id;
                axi_resp_o.b.resp  = axi_pkg::RESP_OKAY;

                // Check if CVA6 core is ready to accept the AXI B response
                if (axi_req_i.b_ready) begin
                    // CVA6 accepted the response, transaction complete
                    write_state_n = IDLE;
                    // TODO: Burst handling - if not WLAST, need to wait for next W data
                end else begin
                    // CVA6 is NOT ready. Stay in REQ_WRITE, keep b_valid asserted.
                    write_state_n = REQ_WRITE;
                end
            end
            default: write_state_n = IDLE;
        endcase

        // --- OBI Output Assignment ---
        // Prioritize write signals if both state machines somehow become active (shouldn't happen with ready logic)
        if (write_state_q == REQ_WRITE) begin
            // Write already assigned above
        end else if (read_state_q == REQ_READ) begin
            // Read already assigned above
        end else begin
            // Keep defaults (req=0)
        end

    end // always_comb


    //--------------------------------------------------------------------------
    // Sequential Logic (State Registers and Data Latching)
    //--------------------------------------------------------------------------

    // Read State Machine FF
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            read_state_q <= IDLE;
            latched_ar_id <= '0;
            latched_ar_addr <= '0;
            read_latency_cnt_q <= 0;
        end else begin
            read_state_q <= read_state_n; // Update state
            read_latency_cnt_q <= read_latency_cnt_n; // Update counter

            // Latch AR info when accepted
            if (axi_req_i.ar_valid && axi_resp_o.ar_ready) begin
                latched_ar_id   <= axi_req_i.ar.id;
                latched_ar_addr <= axi_req_i.ar.addr;
                // Latch ar.len etc. here if handling bursts
            end
        end
    end

    // Write State Machine FF and AW/W Latching
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            write_state_q   <= IDLE;
            // Clear latched flags and data on reset
            latched_aw_valid <= 1'b0;
            latched_w_valid  <= 1'b0;
            latched_aw_id    <= '0;
            latched_aw_addr  <= '0;
            latched_w_data   <= '0;
            latched_w_strb   <= '0;
            latched_w_last   <= '0;
        end else begin
            write_state_q <= write_state_n; // Update state

            // Latch AW channel info when accepted
            if (axi_req_i.aw_valid && axi_resp_o.aw_ready) begin
                latched_aw_valid <= 1'b1; // Set flag indicating AW info is valid
                latched_aw_id    <= axi_req_i.aw.id;
                latched_aw_addr  <= axi_req_i.aw.addr;
                // Latch aw.len etc. here if handling bursts
            end else if (write_state_n == IDLE && write_state_q == REQ_WRITE && axi_req_i.b_ready) begin
                 // Clear AW valid flag only when the transaction completes
                 latched_aw_valid <= 1'b0;
            end

            // Latch W channel info when accepted
            if (axi_req_i.w_valid && axi_resp_o.w_ready) begin
                latched_w_valid <= 1'b1; // Set flag indicating W info is valid
                latched_w_data  <= axi_req_i.w.data;
                latched_w_strb  <= axi_req_i.w.strb;
                latched_w_last  <= axi_req_i.w.last; // Important for bursts
            end else if (write_state_n == IDLE && write_state_q == REQ_WRITE && axi_req_i.b_ready) begin
                 // Clear W valid flag only when the transaction completes
                 latched_w_valid <= 1'b0;
            end
        end
    end

endmodule
