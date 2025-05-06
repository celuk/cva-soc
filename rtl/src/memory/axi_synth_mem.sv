`include "axi/typedef.svh" // Provides req_t, rsp_t

module axi_synth_mem #(
  parameter int unsigned AddrWidth     = 32,
  parameter int unsigned DataWidth     = 32,
  parameter int unsigned IdWidth       = 4,
  parameter int unsigned UserWidth     = 1, // Assuming UserWidth >= 1 as per original
  parameter int unsigned MemDepthWords = 1024, // Depth of the memory in DataWidth words

  // AXI4 request struct definition (from typedef.svh)
  parameter type req_t = logic,
  // AXI4 response struct definition (from typedef.svh)
  parameter type rsp_t = logic
) (
  input  logic clk_i,
  input  logic rst_ni,

  input  req_t axi_req_i,
  output rsp_t axi_rsp_o
);

  // Local AXI constants (if not provided by axi_pkg or similar)
  localparam logic [1:0] AXI_RESP_OKAY   = 2'b00;
  localparam logic [1:0] AXI_RESP_EXOKAY = 2'b01; // Not used in this basic slave
  localparam logic [1:0] AXI_RESP_SLVERR = 2'b10;
  localparam logic [1:0] AXI_RESP_DECERR = 2'b11; // Not used in this basic slave

  localparam logic [1:0] AXI_BURST_FIXED = 2'b00;
  localparam logic [1:0] AXI_BURST_INCR  = 2'b01;
  localparam logic [1:0] AXI_BURST_WRAP  = 2'b10; // WRAP not fully supported here

  localparam int unsigned StrbWidth       = DataWidth / 8;
  localparam int unsigned BytesPerWord    = DataWidth / 8;
  // Address width for the memory array index
  localparam int unsigned MemIndexWidth   = (MemDepthWords > 0) ? $clog2(MemDepthWords) : 1;


  // Synthesizable memory array
  logic [DataWidth-1:0] ram[0:MemDepthWords-1];

  // --- Write Channel Registers and Wires ---
  logic [IdWidth-1:0]   aw_id_reg;
  logic [AddrWidth-1:0] aw_addr_reg;
  logic [7:0]           aw_len_reg;
  logic [2:0]           aw_size_reg;
  logic [1:0]           aw_burst_reg;
  logic [UserWidth-1:0] aw_user_reg;
  logic aw_active_reg; // An AW transaction is being processed (address phase done, data phase ongoing)

  logic [7:0] w_beats_count_reg; // Counter for data beats written in current burst

  logic [IdWidth-1:0]   b_id_reg;
  logic [1:0]           b_resp_reg;
  logic [UserWidth-1:0] b_user_reg;
  logic b_valid_reg;    // B channel valid signal

  logic aw_ready_next;
  logic w_ready_next;

  // --- Read Channel Registers and Wires ---
  logic [IdWidth-1:0]   ar_id_reg;
  logic [AddrWidth-1:0] ar_addr_reg;
  logic [7:0]           ar_len_reg;
  logic [2:0]           ar_size_reg;
  logic [1:0]           ar_burst_reg;
  logic [UserWidth-1:0] ar_user_reg;
  logic ar_active_reg; // An AR transaction is being processed

  logic [7:0] r_beats_count_reg; // Counter for data beats read in current burst
  logic r_valid_reg;    // R channel valid signal

  // R channel payload (driven combinationally based on current state, or could be registered for timing)
  logic [IdWidth-1:0]   r_id_payload;
  logic [DataWidth-1:0] r_data_payload;
  logic [1:0]           r_resp_payload;
  logic                 r_last_payload;
  logic [UserWidth-1:0] r_user_payload;

  logic ar_ready_next;

  // --- Helper functions ---

  // Calculates the byte address for the current beat of a burst
  function automatic [AddrWidth-1:0] calculate_beat_byte_addr (
    input [AddrWidth-1:0] base_addr,
    input [1:0]           burst_type, // axi_pkg::burst_t
    input [2:0]           axsize,     // axi_pkg::size_t (AxSIZE)
    input [7:0]           beat_count  // Current beat number (0 to AxLEN)
  );
    int unsigned num_bytes_in_beat = 1 << axsize;
    if (burst_type == AXI_BURST_INCR) begin
      return base_addr + (beat_count * num_bytes_in_beat);
    end else begin // FIXED or WRAP (WRAP not fully supported, treated as FIXED)
      return base_addr;
    end
  endfunction

  // Converts a byte address to a word index for the memory array
  // Returns the full potential word index before truncation/bounds check.
  function automatic [AddrWidth-1:0] get_target_word_idx (
    input [AddrWidth-1:0] byte_addr
  );
    if (BytesPerWord == 0) return '0; // Avoid division by zero, though BytesPerWord should be >0
    return byte_addr / BytesPerWord; // Integer division
    // Alternative for power-of-2 BytesPerWord: return byte_addr >> $clog2(BytesPerWord);
  endfunction


  // --- Write Channel Logic ---

  // AWREADY: Can accept new AW if no AW is active and B channel is clear (or finishing)
  assign aw_ready_next = !aw_active_reg && (!b_valid_reg || axi_req_i.b_ready);

  // WREADY: Can accept W data if an AW transaction is active and B response is not pending acceptance
  assign w_ready_next = aw_active_reg && (!b_valid_reg || axi_req_i.b_ready) ;


  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      aw_active_reg     <= 1'b0;
      aw_id_reg         <= '0;
      aw_addr_reg       <= '0;
      aw_len_reg        <= '0;
      aw_size_reg       <= '0;
      aw_burst_reg      <= '0;
      if (UserWidth > 0) aw_user_reg <= '0;
      w_beats_count_reg <= '0;

      b_valid_reg       <= 1'b0;
      b_id_reg          <= '0;
      b_resp_reg        <= AXI_RESP_OKAY;
      if (UserWidth > 0) b_user_reg <= '0;
    end else begin
      // AW Channel handshake
      if (axi_req_i.aw_valid && aw_ready_next) begin
        aw_active_reg     <= 1'b1;
        aw_id_reg         <= axi_req_i.aw.id;
        aw_addr_reg       <= axi_req_i.aw.addr;
        aw_len_reg        <= axi_req_i.aw.len;
        aw_size_reg       <= axi_req_i.aw.size;
        aw_burst_reg      <= axi_req_i.aw.burst;
        if (UserWidth > 0) aw_user_reg <= axi_req_i.aw.user;
        w_beats_count_reg <= '0; // Reset beat counter for new burst
      end

      // W Channel data and memory write
      if (aw_active_reg && axi_req_i.w_valid && w_ready_next) begin
        logic [AddrWidth-1:0] current_w_byte_addr;
        logic [AddrWidth-1:0] target_mem_word_idx;
        logic [MemIndexWidth-1:0] actual_mem_idx;
        logic is_write_error;

        current_w_byte_addr = calculate_beat_byte_addr(aw_addr_reg, aw_burst_reg, aw_size_reg, w_beats_count_reg);
        target_mem_word_idx = get_target_word_idx(current_w_byte_addr);
        
        // Check for out-of-bounds access
        is_write_error = (MemDepthWords == 0) || (target_mem_word_idx >= MemDepthWords);
        
        if (!is_write_error) begin
            actual_mem_idx = target_mem_word_idx[MemIndexWidth-1:0];
            // Perform the write to memory using strobes
            for (int i = 0; i < StrbWidth; i++) begin
                if (axi_req_i.w.strb[i]) begin
                ram[actual_mem_idx][i*8 +: 8] <= axi_req_i.w.data[i*8 +: 8];
                end
            end
        end
        // Note: AXI slave error for out-of-bounds write is typically signaled on B.RESP
        // The actual write might be suppressed or write to a dummy location.
        // Here, we suppress the write if out of bounds.

        if (w_beats_count_reg == aw_len_reg) begin // Last beat of the burst
          aw_active_reg     <= 1'b0; // Finished with AW/W phase
          b_valid_reg       <= 1'b1; // Prepare B response
          b_id_reg          <= aw_id_reg;
          if (UserWidth > 0) b_user_reg <= aw_user_reg; // Or other source for b.user
          b_resp_reg        <= is_write_error ? AXI_RESP_SLVERR : AXI_RESP_OKAY;
        end else begin
          w_beats_count_reg <= w_beats_count_reg + 1;
        end
      end

      // B Channel handshake
      if (b_valid_reg && axi_req_i.b_ready) begin
        b_valid_reg <= 1'b0; // B transaction completed
      end
    end
  end

  assign axi_rsp_o.aw_ready = aw_ready_next;
  assign axi_rsp_o.w_ready  = w_ready_next;
  assign axi_rsp_o.b.id     = b_id_reg;
  assign axi_rsp_o.b.resp   = b_resp_reg;
  assign axi_rsp_o.b.user   = (UserWidth > 0) ? b_user_reg : '0; // Handle UserWidth=0 case for output
  assign axi_rsp_o.b_valid  = b_valid_reg;


  // --- Read Path Logic ---

  // ARREADY: Can accept new AR if no AR is active and R channel is clear (or finishing last beat)
  assign ar_ready_next = !ar_active_reg && (!r_valid_reg || axi_req_i.r_ready);

  always_comb begin
    // Default values for R channel payload
    logic [AddrWidth-1:0] current_r_byte_addr;
    logic [AddrWidth-1:0] target_mem_word_idx;
    logic [MemIndexWidth-1:0] actual_mem_idx;
    logic is_read_error;

    r_id_payload   = ar_id_reg; // From latched AR request
    if (UserWidth > 0) r_user_payload = ar_user_reg; else r_user_payload = '0;

    current_r_byte_addr = calculate_beat_byte_addr(ar_addr_reg, ar_burst_reg, ar_size_reg, r_beats_count_reg);
    target_mem_word_idx = get_target_word_idx(current_r_byte_addr);

    is_read_error = (MemDepthWords == 0) || (target_mem_word_idx >= MemDepthWords);

    if (is_read_error) begin
      r_data_payload = {DataWidth{1'bx}}; // Or '0, or specific error pattern
      r_resp_payload = AXI_RESP_SLVERR;
    end else begin
      actual_mem_idx = target_mem_word_idx[MemIndexWidth-1:0];
      r_data_payload = ram[actual_mem_idx]; // Combinational read from memory
      r_resp_payload = AXI_RESP_OKAY;
    end

    r_last_payload = (r_beats_count_reg == ar_len_reg);
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      ar_active_reg     <= 1'b0;
      ar_id_reg         <= '0;
      ar_addr_reg       <= '0;
      ar_len_reg        <= '0;
      ar_size_reg       <= '0;
      ar_burst_reg      <= '0;
      if (UserWidth > 0) ar_user_reg <= '0;
      r_beats_count_reg <= '0;
      r_valid_reg       <= 1'b0;
    end else begin
      // AR Channel handshake
      if (axi_req_i.ar_valid && ar_ready_next) begin
        ar_active_reg     <= 1'b1;
        ar_id_reg         <= axi_req_i.ar.id;
        ar_addr_reg       <= axi_req_i.ar.addr;
        ar_len_reg        <= axi_req_i.ar.len;
        ar_size_reg       <= axi_req_i.ar.size;
        ar_burst_reg      <= axi_req_i.ar.burst;
        if (UserWidth > 0) ar_user_reg <= axi_req_i.ar.user;
        r_beats_count_reg <= '0; // Reset beat counter
        r_valid_reg       <= 1'b1; // First R beat will be valid next cycle (data is combinational)
                                   // If memory has registered output, r_valid_reg might need another cycle delay.
      end else if (r_valid_reg && axi_req_i.r_ready) begin // R beat transferred
        if (r_beats_count_reg == ar_len_reg) begin // Last beat was sent and accepted
          ar_active_reg     <= 1'b0;
          r_valid_reg       <= 1'b0;
        end else begin
          r_beats_count_reg <= r_beats_count_reg + 1;
          r_valid_reg       <= 1'b1; // Keep RVALID asserted for the next beat
        end
      end else if (ar_active_reg && !r_valid_reg) begin
        // If AR is active, but RVALID is not yet high (e.g., just after AR accepted), make it high.
        // This ensures RVALID goes high if it was low, provided an AR is active.
        // This case is covered by the AR acceptance setting r_valid_reg <= 1'b1;
        // If r_valid_reg is high and r_ready is low, r_valid_reg remains high (no change in this FF).
      end
      // If !ar_active_reg (e.g. after last beat sent), r_valid_reg is (or becomes) 0.
    end
  end

  assign axi_rsp_o.ar_ready = ar_ready_next;
  assign axi_rsp_o.r.id     = r_id_payload;
  assign axi_rsp_o.r.data   = r_data_payload;
  assign axi_rsp_o.r.resp   = r_resp_payload;
  assign axi_rsp_o.r.last   = r_last_payload;
  assign axi_rsp_o.r.user   = (UserWidth > 0) ? r_user_payload : '0;
  assign axi_rsp_o.r_valid  = r_valid_reg;


  // Optional: Memory Initialization for Simulation
  // This is typically NOT synthesizable for RTL block RAM initialization.
  // FPGA BRAMs are initialized via tool-specific mechanisms (e.g., .mem files).
`ifdef SIMULATION_MEMORY_INIT
  initial begin
    if (MemDepthWords > 0) begin
      for (int i = 0; i < MemDepthWords; i++) begin
        ram[i] = '0;
      end
    end
  end
`endif

endmodule

