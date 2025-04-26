module obi_sram_shim_modified #(
    parameter obi_pkg::obi_cfg_t ObiCfg    = obi_pkg::ObiDefaultConfig,
    parameter type               obi_req_t = logic,
    parameter type               obi_rsp_t = logic
) (
    input  logic                          clk_i,
    input  logic                          rst_ni,

    // OBI Slave Interface (from axi_to_obi)
    input  obi_req_t                      obi_req_i,
    output obi_rsp_t                      obi_rsp_o,

    // Simple RAM Master Interface (to ram32)
    output logic                          req_o,
    output logic                          we_o,
    output logic [  ObiCfg.AddrWidth-1:0] addr_o,
    output logic [  ObiCfg.DataWidth-1:0] wdata_o,
    output logic [ObiCfg.DataWidth/8-1:0] be_o,

    // Inputs from RAM (ram32)
    input  logic                          rvalid_i, // <<< Input from RAM rvalid_o
    input  logic [  ObiCfg.DataWidth-1:0] rdata_i   // Data FROM RAM
);

    // Check for unsupported configurations
    // ... (keep existing checks) ...

    // Internal state for grant generation and ID tracking
    logic gnt_d, gnt_q;
    // *** MODIFICATION: Use a dedicated register for the ID of the transaction sent downstream ***
    logic [ObiCfg.IdWidth-1:0] id_inflight_q;

    // Pass through request signals directly to RAM
    assign req_o   = obi_req_i.req; // This might need refinement if req needs delaying
    assign we_o    = obi_req_i.a.we;
    assign addr_o  = obi_req_i.a.addr;
    assign wdata_o = obi_req_i.a.wdata;
    assign be_o    = obi_req_i.a.be;

    // Generate OBI Grant Response
    assign gnt_d = obi_req_i.req;
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            gnt_q <= 1'b0;
        end else begin
            gnt_q <= gnt_d;
        end
    end
    assign obi_rsp_o.gnt = ObiCfg.CombGnt ? gnt_d : gnt_q;

    // *** MODIFICATION: Latch the request ID when the request is granted ***
    // This assumes the grant signals the acceptance of the request to be processed.
    // We latch the ID associated with the granted request.
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            id_inflight_q <= '0;
        end else if (obi_req_i.req & obi_rsp_o.gnt) begin // Latch ID when request is granted
            // (Check CombGnt: if CombGnt=1, obi_rsp_o.gnt=req_i.req, latch happens immediately.
            // If CombGnt=0, obi_rsp_o.gnt=gnt_q, latch happens cycle after req.)
            id_inflight_q <= obi_req_i.a.aid;
        end
        // No else: id_inflight_q holds its value until the next granted request
    end

    // Pass through response signals from RAM
    assign obi_rsp_o.rvalid = rvalid_i;      // Use input from RAM
    assign obi_rsp_o.r.rdata = rdata_i;
    // *** MODIFICATION: Use the ID of the transaction that was in flight ***
    assign obi_rsp_o.r.rid   = id_inflight_q;
    assign obi_rsp_o.r.err   = 1'b0;         // Assume no errors from simple RAM

    // Tie off unused optional response fields
    assign obi_rsp_o.r.r_optional.ruser = '0; // Tie off the 1-bit ruser
    //assign obi_rsp_o.r.r_optional.exokay = 1'b0; // Tie off exokay - Uncomment if needed based on exact obi_rsp_t def
    // Ensure all fields in adapter_obi_r_optional_t are assigned
     `ifdef OBI_TYPEDEF_ALL_R_OPTIONAL // Check if this macro defines more fields
     assign obi_rsp_o.r.r_optional.exokay = 1'b0;
     // Assign other fields if they exist, e.g., rchk
     `endif


endmodule
