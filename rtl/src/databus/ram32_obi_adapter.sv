// Adapter to connect obi_sram_shim (expecting gnt_i)
// to ram32 (providing rvalid_o)
`timescale 1ns / 1ps

module ram32_obi_adapter #(
    // Match widths used in the SoC
    parameter int unsigned ADDR_WIDTH = 32,
    parameter int unsigned DATA_WIDTH = 32,
    parameter int unsigned BE_WIDTH   = 4
) (
    input  logic clk_i,
    input  logic rst_ni,

    // Interface towards obi_sram_shim (Master side of shim)
    input  logic                          shim_req_i,   // From shim.req_o
    input  logic                          shim_we_i,    // From shim.we_o
    input  logic [ADDR_WIDTH-1:0]         shim_addr_i,  // From shim.addr_o
    input  logic [DATA_WIDTH-1:0]         shim_wdata_i, // From shim.wdata_o
    input  logic [BE_WIDTH-1:0]           shim_be_i,    // From shim.be_o
    output logic                          shim_gnt_o,   // To shim.gnt_i
    output logic [DATA_WIDTH-1:0]         shim_rdata_o, // To shim.rdata_i

    // Interface towards ram32 (Slave side of RAM)
    output logic                          ram_req_o,    // To ram.req_i
    output logic                          ram_we_o,     // To ram.we_i
    output logic [ADDR_WIDTH-1:0]         ram_addr_o,   // To ram.addr_i
    output logic [DATA_WIDTH-1:0]         ram_wdata_o,  // To ram.wdata_i
    output logic [BE_WIDTH-1:0]           ram_be_o,     // To ram.be_i
    input  logic                          ram_rvalid_i, // From ram.rvalid_o
    input  logic [DATA_WIDTH-1:0]         ram_rdata_i   // From ram.rdata_o
);

    // Pass through request signals from Shim to RAM
    assign ram_req_o   = shim_req_i;
    assign ram_we_o    = shim_we_i;
    assign ram_addr_o  = shim_addr_i;
    assign ram_wdata_o = shim_wdata_i;
    assign ram_be_o    = shim_be_i;

    // Pass through read data from RAM to Shim
    assign shim_rdata_o = ram_rdata_i;

    // Generate the Grant signal required by the Shim.
    // Since ram32 has a 1-cycle latency (rvalid_o <= req_i),
    // we can generate the grant one cycle after the request is sent to the RAM.
    // This matches the timing the shim expects if CombGnt=0.
    logic gnt_d, gnt_q;
    assign gnt_d = ram_req_o; // Grant follows request

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            gnt_q <= 1'b0;
        end else begin
            gnt_q <= gnt_d;
        end
    end
    assign shim_gnt_o = gnt_q; // Provide registered grant to shim

    // Note: ram_rvalid_i is ignored by this adapter, as the shim
    // generates its own rvalid based on the grant we provide.

endmodule
