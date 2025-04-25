`timescale 1ns / 1ps

module axi_to_dual_obi_adapter import axi_pkg::*; #(
    // Parameters should match CVA6 configuration (CVA6Cfg)
    parameter int unsigned AXI_ADDR_WIDTH = 32, // Example
    parameter int unsigned AXI_DATA_WIDTH = 32, // Example
    parameter int unsigned AXI_ID_WIDTH   = 4,  // Example
    parameter int unsigned AXI_USER_WIDTH = 1,  // Example
    // Add other relevant AXI parameters if needed (e.g., from CVA6Cfg)

    // Parameter to identify instruction fetches (NEEDS VERIFICATION FROM CVA6 DOCS)
    // Assuming ARPROT[1] indicates instruction fetch. Adjust if different.
    parameter bit [2:0] INSTR_FETCH_PROT = 3'b010 // Example: AxPROT[1]=1
) (
    input  logic                          clk_i,
    input  logic                          rst_ni,

    // AXI Interface towards CVA6 Core
    input  ariane_axi::req_t              axi_req_i,
    output ariane_axi::resp_t             axi_resp_o,

    // OBI-like Instruction Interface towards SoC Memory/Interconnect
    output logic                          instr_req_o,
    input  logic                          instr_gnt_i,
    input  logic                          instr_rvalid_i,
    output logic [AXI_ADDR_WIDTH-1:0]     instr_addr_o,
    input  logic [AXI_DATA_WIDTH-1:0]     instr_rdata_i,

    // OBI-like Data Interface towards SoC Memory/Interconnect
    output logic                          data_req_o,
    input  logic                          data_gnt_i,
    input  logic                          data_rvalid_i, // For reads
    output logic                          data_we_o,
    output logic [(AXI_DATA_WIDTH/8)-1:0] data_be_o,
    output logic [AXI_ADDR_WIDTH-1:0]     data_addr_o,
    output logic [AXI_DATA_WIDTH-1:0]     data_wdata_o,
    input  logic [AXI_DATA_WIDTH-1:0]     data_rdata_i
);

    // Internal signals and state machine variables
    typedef enum logic [1:0] {
        IDLE,
        WAIT_GNT,
        WAIT_RVALID,
        WAIT_WRITE
    } state_e;

    state_e instr_state_q, instr_state_n;
    state_e data_read_state_q, data_read_state_n;
    state_e data_write_state_q, data_write_state_n;

    // Latched AXI request info
    ariane_axi::id_t             latched_instr_arid;
    ariane_axi::addr_t           latched_instr_araddr;
    ariane_axi::id_t             latched_data_arid;
    ariane_axi::addr_t           latched_data_araddr;
    ariane_axi::id_t             latched_data_awid;
    ariane_axi::addr_t           latched_data_awaddr;
    logic                        latched_data_awvalid;
    ariane_axi::data_t           latched_data_wdata;
    ariane_axi::strb_t           latched_data_wstrb;
    logic                        latched_data_wlast;
    logic                        latched_data_wvalid;

    // Intermediate signals for driving outputs from a single block
    logic                          obi_data_req_read;
    logic                          obi_data_req_write;
    logic [AXI_ADDR_WIDTH-1:0]     obi_data_addr_read;
    logic [AXI_ADDR_WIDTH-1:0]     obi_data_addr_write;
    logic                          obi_data_we_write;

    // --- Internal Wires/Logic for Combinational Calculations ---
    // Moved these declarations outside the always_comb block
    logic is_instr_fetch;
    logic can_accept_instr_ar;
    logic can_accept_data_ar;
    logic can_accept_data_aw;
    logic can_accept_data_w;


    //--------------------------------------------------------------------------
    // Combinational Logic Block for AXI Handshakes and OBI Control
    //--------------------------------------------------------------------------
    always_comb begin
        // --- Default assignments ---
        // Initialize resp_o struct fields individually
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

        // OBI Instruction Interface Defaults
        instr_req_o = 1'b0;
        instr_addr_o = latched_instr_araddr;

        // OBI Data Interface Defaults
        obi_data_req_read = 1'b0;
        obi_data_addr_read = latched_data_araddr;
        obi_data_req_write = 1'b0;
        obi_data_addr_write = latched_data_awaddr;
        obi_data_we_write = 1'b0;
        data_be_o = latched_data_wstrb;
        data_wdata_o = latched_data_wdata;


        // --- AXI Input Handshake Logic ---

        // Assign values to the wires declared outside
        is_instr_fetch = (axi_req_i.ar.prot == INSTR_FETCH_PROT);
        can_accept_instr_ar = (instr_state_q == IDLE);
        can_accept_data_ar = (data_read_state_q == IDLE);
        can_accept_data_aw = (data_write_state_q == IDLE) && !latched_data_awvalid;
        can_accept_data_w = (data_write_state_q == IDLE || data_write_state_q == WAIT_GNT) && latched_data_awvalid && !latched_data_wvalid;

        // Assign AXI READY signals based on ability to accept
        axi_resp_o.ar_ready = (is_instr_fetch && axi_req_i.ar_valid && can_accept_instr_ar) ||
                              (!is_instr_fetch && axi_req_i.ar_valid && can_accept_data_ar);
        axi_resp_o.aw_ready = axi_req_i.aw_valid && can_accept_data_aw;
        axi_resp_o.w_ready  = axi_req_i.w_valid && can_accept_data_w;


        // --- Instruction Fetch State Machine (Combinational Part) ---
        instr_state_n = instr_state_q;
        instr_req_o = (instr_state_q == WAIT_GNT);

        case (instr_state_q)
            IDLE: begin
                if (axi_req_i.ar_valid && axi_resp_o.ar_ready && is_instr_fetch) begin
                    instr_state_n = WAIT_GNT;
                end
            end
            WAIT_GNT: begin
                if (instr_gnt_i) begin
                    instr_state_n = WAIT_RVALID;
                end
            end
            WAIT_RVALID: begin
                if (instr_rvalid_i) begin
                    axi_resp_o.r_valid = 1'b1;
                    axi_resp_o.r.data  = instr_rdata_i;
                    axi_resp_o.r.id    = latched_instr_arid;
                    axi_resp_o.r.last  = 1'b1; // TODO: Handle bursts
                    axi_resp_o.r.resp  = axi_pkg::RESP_OKAY;

                    if (axi_req_i.r_ready) begin
                       instr_state_n = IDLE;
                    end else begin
                       instr_state_n = WAIT_RVALID;
                    end
                end
            end
            default: instr_state_n = IDLE;
        endcase


        // --- Data Read State Machine (Combinational Part) ---
        data_read_state_n = data_read_state_q;
        obi_data_req_read = (data_read_state_q == WAIT_GNT);

        case (data_read_state_q)
            IDLE: begin
                if (axi_req_i.ar_valid && axi_resp_o.ar_ready && !is_instr_fetch) begin
                    data_read_state_n = WAIT_GNT;
                end
            end
            WAIT_GNT: begin
                if (data_gnt_i) begin
                    data_read_state_n = WAIT_RVALID;
                end
            end
            WAIT_RVALID: begin
                if (data_rvalid_i) begin
                    if (!axi_resp_o.r_valid) begin // Avoid conflict
                        axi_resp_o.r_valid = 1'b1;
                        axi_resp_o.r.data  = data_rdata_i;
                        axi_resp_o.r.id    = latched_data_arid;
                        axi_resp_o.r.last  = 1'b1; // TODO: Handle bursts
                        axi_resp_o.r.resp  = axi_pkg::RESP_OKAY;
                    end

                    if (axi_req_i.r_ready) begin
                       data_read_state_n = IDLE;
                    end else begin
                       data_read_state_n = WAIT_RVALID;
                    end
                end
            end
            default: data_read_state_n = IDLE;
        endcase


        // --- Data Write State Machine (Combinational Part) ---
        data_write_state_n = data_write_state_q;
        obi_data_req_write = (data_write_state_q == WAIT_GNT);
        obi_data_we_write  = (data_write_state_q == WAIT_GNT);

        case (data_write_state_q)
            IDLE: begin
                if (latched_data_awvalid && latched_data_wvalid) begin
                    data_write_state_n = WAIT_GNT;
                end
            end
            WAIT_GNT: begin
                if (data_gnt_i) begin
                    axi_resp_o.b_valid = 1'b1;
                    axi_resp_o.b.id    = latched_data_awid;
                    axi_resp_o.b.resp  = axi_pkg::RESP_OKAY;

                    if (axi_req_i.b_ready) begin
                        data_write_state_n = IDLE;
                    end else begin
                        data_write_state_n = WAIT_GNT; // Hold state
                    end
                end
            end
            default: data_write_state_n = IDLE;
        endcase


        // --- Combine OBI Data Signals ---
        data_req_o  = obi_data_req_read | obi_data_req_write;
        data_we_o   = obi_data_we_write;
        data_addr_o = data_we_o ? obi_data_addr_write : obi_data_addr_read;

    end // always_comb


    //--------------------------------------------------------------------------
    // Sequential Logic (State Registers and Data Latching)
    //--------------------------------------------------------------------------

    // Instruction Fetch State Machine FF
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            instr_state_q <= IDLE;
            latched_instr_arid <= '0;
            latched_instr_araddr <= '0;
        end else begin
            instr_state_q <= instr_state_n;
            // is_instr_fetch is now visible here
            if (axi_req_i.ar_valid && axi_resp_o.ar_ready && is_instr_fetch) begin
                latched_instr_arid   <= axi_req_i.ar.id;
                latched_instr_araddr <= axi_req_i.ar.addr;
            end
        end
    end

    // Data Read State Machine FF
    always_ff @(posedge clk_i or negedge rst_ni) begin
      if (!rst_ni) begin
          data_read_state_q <= IDLE;
          latched_data_arid <= '0;
          latched_data_araddr <= '0;
      end else begin
          data_read_state_q <= data_read_state_n;
           // is_instr_fetch is now visible here
          if (axi_req_i.ar_valid && axi_resp_o.ar_ready && !is_instr_fetch) begin
              latched_data_arid   <= axi_req_i.ar.id;
              latched_data_araddr <= axi_req_i.ar.addr;
          end
      end
    end

    // Data Write State Machine FF and AW/W Latching
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            data_write_state_q   <= IDLE;
            latched_data_awvalid <= 1'b0;
            latched_data_wvalid  <= 1'b0;
            latched_data_awid    <= '0;
            latched_data_awaddr  <= '0;
            latched_data_wdata   <= '0;
            latched_data_wstrb   <= '0;
            latched_data_wlast   <= '0;
        end else begin
            data_write_state_q <= data_write_state_n;

            if (axi_req_i.aw_valid && axi_resp_o.aw_ready) begin
                latched_data_awvalid <= 1'b1;
                latched_data_awid    <= axi_req_i.aw.id;
                latched_data_awaddr  <= axi_req_i.aw.addr;
            end else if (data_write_state_n == IDLE && data_write_state_q == WAIT_GNT) begin
                 latched_data_awvalid <= 1'b0;
            end

            if (axi_req_i.w_valid && axi_resp_o.w_ready) begin
                latched_data_wvalid <= 1'b1;
                latched_data_wdata  <= axi_req_i.w.data;
                latched_data_wstrb  <= axi_req_i.w.strb;
                latched_data_wlast  <= axi_req_i.w.last;
            end else if (data_write_state_n == IDLE && data_write_state_q == WAIT_GNT) begin
                 latched_data_wvalid <= 1'b0;
            end
        end
    end

endmodule
