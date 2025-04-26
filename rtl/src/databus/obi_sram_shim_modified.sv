// OBI to Simple RAM Shim (Adapts Grant/Rvalid)

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
    if (ObiCfg.OptionalCfg.UseAtop) $error("Please use an ATOP resolver before sram shim.");
    if (ObiCfg.UseRReady) $error("Please use an RReady Fifo before sram shim.");
    if (ObiCfg.Integrity) $error("Integrity not yet supported, WIP");
    if (ObiCfg.OptionalCfg.UseProt) $warning("Prot not checked!");
    if (ObiCfg.OptionalCfg.UseMemtype) $warning("Memtype not checked!");

    // Internal state for grant generation and ID tracking
    logic gnt_d, gnt_q;
    logic [ObiCfg.IdWidth-1:0] id_d, id_q;

    // Pass through request signals directly to RAM
    assign req_o   = obi_req_i.req;
    assign we_o    = obi_req_i.a.we;
    assign addr_o  = obi_req_i.a.addr;
    assign wdata_o = obi_req_i.a.wdata;
    assign be_o    = obi_req_i.a.be;

    // Generate OBI Grant Response
    // If CombGnt=1, grant immediately. If CombGnt=0, grant one cycle after req.
    assign gnt_d = obi_req_i.req;
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            gnt_q <= 1'b0;
        end
        else begin
            gnt_q <= gnt_d;
        end
    end
    assign obi_rsp_o.gnt = ObiCfg.CombGnt ? gnt_d : gnt_q;

    // Latch the request ID when the request is active
    assign id_d = obi_req_i.a.aid;
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            id_q <= '0;
        end
        else if (obi_req_i.req) begin // Latch ID when request is active
            id_q <= id_d;
        end
    end

    // Pass through response signals from RAM
    assign obi_rsp_o.rvalid = rvalid_i;      // <<< Use input from RAM
    assign obi_rsp_o.r.rdata = rdata_i;
    assign obi_rsp_o.r.rid   = id_q;         // Use the latched request ID
    assign obi_rsp_o.r.err   = 1'b0;         // Assume no errors from simple RAM

    // Tie off unused optional response fields if they exist in obi_rsp_t definition
    // Example: assign obi_rsp_o.r.r_optional = '0; // Adjust if r_optional has fields like exokay

    // If adapter_obi_r_optional_t was defined with fields, assign them:
    assign obi_rsp_o.r.r_optional.ruser = '0; // Tie off the 1-bit ruser
    assign obi_rsp_o.r.r_optional.exokay = 1'b0; // Tie off exokay

endmodule
