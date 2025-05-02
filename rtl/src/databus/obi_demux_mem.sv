`timescale 1ns / 1ps

`include "header.vh"

module obi_demux_mem (
   input wire clk_i,
   input wire rst_ni,

   // CPU interface (from obi_sram_shim)
   input  wire        data_req_i,
   output logic       data_gnt_o,      // Changed to logic for assignment in always block
   output logic       data_rvalid_o,   // Changed to logic
   input  wire        data_we_i,
   input  wire [ 3:0] data_be_i,
   input  wire [31:0] data_addr_i,
   input  wire [31:0] data_wdata_i,
   output logic [31:0] data_rdata_o,    // Changed to logic

   // Main Memory interface
   output logic       main_mem_req_o,  // Changed to logic
   output wire [31:0] main_mem_addr_o, // Can remain wire
   output logic       main_mem_we_o,   // Changed to logic
   output wire [ 3:0] main_mem_be_o,   // Can remain wire
   output wire [31:0] main_mem_wdata_o,// Can remain wire
   input  wire        main_mem_gnt_i,  // Input still exists but unused in grant logic
   input  wire        main_mem_rvalid_i,
   input  wire [31:0] main_mem_rdata_i,

   // UART interface
   output logic        uart_req_o,     // Changed to logic
   output wire [31:0] uart_addr_o,
   output logic        uart_we_o,      // Changed to logic
   output wire [ 3:0] uart_be_o,
   output wire [31:0] uart_wdata_o,
   input  wire        uart_gnt_i,
   input  wire        uart_rvalid_i,
   input  wire [31:0] uart_rdata_i,

   // TIMER interface
   output logic        timer_req_o,    // Changed to logic
   output wire [31:0] timer_addr_o,
   output logic        timer_we_o,     // Changed to logic
   output wire [ 3:0] timer_be_o,
   output wire [31:0] timer_wdata_o,
   input  wire        timer_gnt_i,
   input  wire        timer_rvalid_i,
   input  wire [31:0] timer_rdata_i,

   // QSPI interface
   output logic        qspi_req_o,     // Changed to logic
   output wire [31:0] qspi_addr_o,
   output logic        qspi_we_o,      // Changed to logic
   output wire [ 3:0] qspi_be_o,
   output wire [31:0] qspi_wdata_o,
   input  wire        qspi_gnt_i,
   input  wire        qspi_rvalid_i,
   input  wire [31:0] qspi_rdata_i
);

   // --- State Registers ---
   logic       req_in_progress; // Indicates a transaction is active
   logic       mem_access_pending; // Registered signal for memory grant generation
   logic       data_we_latched;
   logic [3:0] data_be_latched;
   logic [31:0]data_addr_latched;
   logic [31:0]data_wdata_latched;

   // --- Peripheral Selection (based on latched address) ---
   // Use latched address for stability during the transaction
   wire main_mem_sel = (`MEM_BASE_ADDR  + `MEM_RANGE  > data_addr_latched) && (data_addr_latched >= `MEM_BASE_ADDR);
   wire uart_sel     = (`UART_BASE_ADDR + `UART_RANGE > data_addr_latched) && (data_addr_latched >= `UART_BASE_ADDR);
   wire timer_sel    = (`TIMER_BASE_ADDR+ `TIMER_RANGE> data_addr_latched) && (data_addr_latched >= `TIMER_BASE_ADDR);
   wire qspi_sel     = (`QSPI_BASE_ADDR + `QSPI_RANGE > data_addr_latched) && (data_addr_latched >= `QSPI_BASE_ADDR);

   // --- Peripheral Selection (based on incoming address for grant check) ---
   wire main_mem_sel_next = (`MEM_BASE_ADDR  + `MEM_RANGE  > data_addr_i) && (data_addr_i >= `MEM_BASE_ADDR);
   wire uart_sel_next     = (`UART_BASE_ADDR + `UART_RANGE > data_addr_i) && (data_addr_i >= `UART_BASE_ADDR);
   wire timer_sel_next    = (`TIMER_BASE_ADDR+ `TIMER_RANGE> data_addr_i) && (data_addr_i >= `TIMER_BASE_ADDR);
   wire qspi_sel_next     = (`QSPI_BASE_ADDR + `QSPI_RANGE > data_addr_i) && (data_addr_i >= `QSPI_BASE_ADDR);

   // --- Response Muxing ---
   // Mux RVALID based on the active (latched) selection
   wire periph_rvalid = (main_mem_sel ? main_mem_rvalid_i : 1'b0) |
                        (uart_sel     ? uart_rvalid_i     : 1'b0) |
                        (timer_sel    ? timer_rvalid_i    : 1'b0) |
                        (qspi_sel     ? qspi_rvalid_i     : 1'b0) ;

   // Mux RDATA based on the active (latched) selection
   wire [31:0] periph_rdata = main_mem_sel ? main_mem_rdata_i :
                              uart_sel     ? uart_rdata_i     :
                              timer_sel    ? timer_rdata_i    :
                              qspi_sel     ? qspi_rdata_i     :
                                             32'b0; // Default

   // --- Output Assignments ---
   assign main_mem_req_o = req_in_progress && main_mem_sel;
   assign main_mem_addr_o = data_addr_latched; // Route latched address
   assign main_mem_we_o   = data_we_latched && main_mem_sel; // Qualify WE
   assign main_mem_be_o   = data_be_latched;
   assign main_mem_wdata_o= data_wdata_latched;

   assign uart_req_o   = req_in_progress && uart_sel;
   assign uart_addr_o  = data_addr_latched;
   assign uart_we_o    = data_we_latched && uart_sel;
   assign uart_be_o    = data_be_latched;
   assign uart_wdata_o = data_wdata_latched;

   assign timer_req_o  = req_in_progress && timer_sel;
   assign timer_addr_o = data_addr_latched;
   assign timer_we_o   = data_we_latched && timer_sel;
   assign timer_be_o   = data_be_latched;
   assign timer_wdata_o= data_wdata_latched;

   assign qspi_req_o   = req_in_progress && qspi_sel;
   assign qspi_addr_o  = data_addr_latched;
   assign qspi_we_o    = data_we_latched && qspi_sel;
   assign qspi_be_o    = data_be_latched;
   assign qspi_wdata_o = data_wdata_latched;

   // Assign final outputs back to shim
   assign data_rvalid_o = periph_rvalid && req_in_progress; // Only valid during an active request
   assign data_rdata_o  = periph_rdata;

   // --- State Machine and Grant Logic ---
   always_ff @(posedge clk_i or negedge rst_ni) begin
      if (!rst_ni) begin
         req_in_progress    <= 1'b0;
         mem_access_pending <= 1'b0;
         data_gnt_o         <= 1'b0; // Ensure grant is low on reset
         data_we_latched    <= 1'b0;
         data_be_latched    <= 4'b0;
         data_addr_latched  <= 32'b0;
         data_wdata_latched <= 32'b0;
      end else begin
         // Default assignments
         data_gnt_o <= 1'b0; // Grant is asserted only under specific conditions below
         mem_access_pending <= 1'b0; // Clear pending memory flag unless set below

         if (!req_in_progress) begin
            // --- IDLE State: Check for new request ---
            if (data_req_i) begin
               // Check if the selected peripheral can grant
               if (main_mem_sel_next) begin
                  // Memory: Grant will be asserted NEXT cycle. Set pending flag.
                  mem_access_pending <= 1'b1;
                  // Latch details immediately, grant comes next cycle
                  req_in_progress    <= 1'b1;
                  data_we_latched    <= data_we_i;
                  data_be_latched    <= data_be_i;
                  data_addr_latched  <= data_addr_i;
                  data_wdata_latched <= data_wdata_i;
               end else if (uart_sel_next && uart_gnt_i) begin
                  // UART: Grant now if peripheral's gnt is high
                  data_gnt_o         <= 1'b1;
                  req_in_progress    <= 1'b1;
                  data_we_latched    <= data_we_i;
                  data_be_latched    <= data_be_i;
                  data_addr_latched  <= data_addr_i;
                  data_wdata_latched <= data_wdata_i;
               end else if (timer_sel_next && timer_gnt_i) begin
                  // TIMER: Grant now if peripheral's gnt is high
                  data_gnt_o         <= 1'b1;
                  req_in_progress    <= 1'b1;
                  data_we_latched    <= data_we_i;
                  data_be_latched    <= data_be_i;
                  data_addr_latched  <= data_addr_i;
                  data_wdata_latched <= data_wdata_i;
               end else if (qspi_sel_next && qspi_gnt_i) begin
                  // QSPI: Grant now if peripheral's gnt is high
                  data_gnt_o         <= 1'b1;
                  req_in_progress    <= 1'b1;
                  data_we_latched    <= data_we_i;
                  data_be_latched    <= data_be_i;
                  data_addr_latched  <= data_addr_i;
                  data_wdata_latched <= data_wdata_i;
               end
               // If no peripheral grants, remain IDLE, request is ignored this cycle
            end
         end else begin
            // --- ACTIVE State: Request is in progress ---

            // Check if this was a memory access waiting for its delayed grant
            if (mem_access_pending) begin
               data_gnt_o <= 1'b1; // Assert the registered grant for memory
               mem_access_pending <= 1'b0; // Clear the flag, grant has been sent
            end

            // Check for transaction completion (read or write)
            // IMPORTANT: Assumes peripherals assert rvalid for writes too!
            if (periph_rvalid) begin
               req_in_progress <= 1'b0; // Transaction complete, go back to idle next cycle
               // Clear latched data (optional, good practice)
               data_we_latched    <= 1'b0;
               data_be_latched    <= 4'b0;
               data_addr_latched  <= 32'b0;
               data_wdata_latched <= 32'b0;
            end
            // If no rvalid, stay in req_in_progress state, keep outputs asserted
         end
      end // else: !if(!rst_ni)
   end // always_ff

endmodule
