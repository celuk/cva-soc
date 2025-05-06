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

  // Local AXI constants
  localparam logic [1:0] AXI_RESP_OKAY   = 2'b00;
  localparam logic [1:0] AXI_RESP_SLVERR = 2'b10;

  localparam logic [1:0] AXI_BURST_FIXED = 2'b00;
  localparam logic [1:0] AXI_BURST_INCR  = 2'b01;
  localparam logic [1:0] AXI_BURST_WRAP  = 2'b10;

  localparam int unsigned BytesPerWord    = DataWidth / 8;
  // Ensure MemIndexWidth is at least 1 to prevent zero-width vectors if MemDepthWords is 1
  localparam int unsigned MemIndexWidth   = (MemDepthWords > 1) ? $clog2(MemDepthWords) : 1;
  localparam int unsigned StrbWidth       = DataWidth / 8;


  logic [DataWidth-1:0] ram[0:MemDepthWords-1];

  // --- Write Channel Registers and Wires ---
  logic [IdWidth-1:0]   aw_id_reg;
  logic [AddrWidth-1:0] aw_addr_reg;
  logic [7:0]           aw_len_reg;
  logic [2:0]           aw_size_reg;
  logic [1:0]           aw_burst_reg;
  logic [UserWidth-1:0] aw_user_reg; // Only used if UserWidth > 0
  logic aw_processing_w_reg; // True if AW latched, and W phase is ongoing

  logic [7:0] w_beats_count_reg;

  logic [IdWidth-1:0]   b_id_reg;
  logic [1:0]           b_resp_reg;
  logic [UserWidth-1:0] b_user_reg; // Only used if UserWidth > 0
  logic b_valid_reg;

  logic aw_ready_next;
  logic w_ready_next;

  // --- Read Channel Registers and Wires ---
  logic [IdWidth-1:0]   ar_id_reg;
  logic [AddrWidth-1:0] ar_addr_reg;
  logic [7:0]           ar_len_reg;
  logic [2:0]           ar_size_reg;
  logic [1:0]           ar_burst_reg;
  logic [UserWidth-1:0] ar_user_reg; // Only used if UserWidth > 0
  logic ar_processing_r_reg; // True if AR latched, and R phase is ongoing

  logic [7:0] r_beats_count_reg;
  logic r_valid_reg;

  logic [IdWidth-1:0]   r_id_payload;
  logic [DataWidth-1:0] r_data_payload;
  logic [1:0]           r_resp_payload;
  logic                 r_last_payload;
  logic [UserWidth-1:0] r_user_payload; // Only used if UserWidth > 0

  logic ar_ready_next;

  // --- Helper functions ---
  // Calculates the byte address for the current beat of a burst
  function automatic [AddrWidth-1:0] calculate_beat_byte_addr (
    input logic [AddrWidth-1:0] base_addr,    // AxADDR (Start_Address for the burst)
    input logic [1:0]           burst_type,   // AxBURST
    input logic [2:0]           axsize,       // AxSIZE (log2 of Number_Bytes in transfer)
    input logic [7:0]           axlen,        // AxLEN (Burst_Length - 1)
    input logic [7:0]           beat_count    // Current beat number (0 to AxLEN)
  );
    // Local variable declarations MUST come first in a SystemVerilog function
    int unsigned          num_bytes_in_beat;     // Number_Bytes for AxSIZE
    logic [AddrWidth-1:0] current_addr;

    // Variables for WRAP burst calculation (AXI Spec: AMBA AXI and ACE Protocol Specification IHI0022H.a - A3.4.3)
    int unsigned          burst_length_transfers; // AxLEN + 1 (Burst_Length in spec terms)
    int unsigned          wrap_boundary_len_bytes; // Total bytes in the wrap region (Number_Bytes * Burst_Length)
    logic [AddrWidth-1:0] lower_wrap_boundary;     // Wrap_Boundary = (FLOOR(Start_Address / Wrap_Boundary_Length)) * Wrap_Boundary_Length
    logic [AddrWidth-1:0] unaligned_incremented_addr_from_start; // Start_Address + (Number_Bytes * Beat_Number)
    logic [AddrWidth-1:0] offset_of_start_addr_in_wrap; // Start_Address - Lower_Wrap_Boundary
    logic [AddrWidth-1:0] current_beat_offset_in_wrap;  // (Offset_of_Start_Addr_in_Wrap + Number_Bytes * Beat_Number)

    // Procedural part of the function starts here
    num_bytes_in_beat = 1 << axsize; // Calculate bytes per beat from AxSIZE

    case (burst_type)
      AXI_BURST_INCR: begin
        current_addr = base_addr + (beat_count * num_bytes_in_beat);
      end

      AXI_BURST_WRAP: begin
        burst_length_transfers = axlen + 1;
        wrap_boundary_len_bytes = num_bytes_in_beat * burst_length_transfers;

        if (wrap_boundary_len_bytes == 0) begin // Avoid division by zero if params are invalid
            current_addr = base_addr; // Fallback behavior
        end else begin
            // Lower_Wrap_Boundary = (FLOOR(Start_Address / Wrap_Boundary_Length)) * Wrap_Boundary_Length
            // Integer division in Verilog/SV performs FLOOR for positive numbers.
            lower_wrap_boundary = (base_addr / wrap_boundary_len_bytes) * wrap_boundary_len_bytes;

            // Calculate offset of the original start address (base_addr) within its wrap region
            offset_of_start_addr_in_wrap = base_addr - lower_wrap_boundary;

            // Calculate the increment for the current beat relative to the start address's offset
            current_beat_offset_in_wrap = offset_of_start_addr_in_wrap + (beat_count * num_bytes_in_beat);

            // Beat_Address = Lower_Wrap_Boundary + ( (Start_Address - Lower_Wrap_Boundary) + (Number_Bytes * Beat_Number) ) MOD Wrap_Boundary_Length
            current_addr = lower_wrap_boundary + (current_beat_offset_in_wrap % wrap_boundary_len_bytes);
        end
      end

      AXI_BURST_FIXED: begin
        // For FIXED burst, the address for all transfers is AxADDR.
        // The slave determines which bytes within that AxADDR range are accessed based on AxSIZE.
        // It's common for slaves to use AxADDR aligned to AxSIZE for FIXED bursts.
        current_addr = (base_addr / num_bytes_in_beat) * num_bytes_in_beat;
      end

      default: begin // Covers AXI_BURST_RESERVED (2'b11) or any other invalid value
        // As per AXI spec, reserved burst types should default to INCR behavior or error.
        // For simplicity in a basic memory, treating as INCR or returning base_addr is an option.
        // SLVERR would be more compliant but adds complexity.
        current_addr = base_addr + (beat_count * num_bytes_in_beat); // Defaulting to INCR-like
      end
    endcase
    return current_addr;
  endfunction

  function automatic [AddrWidth-1:0] get_target_word_idx (
    input [AddrWidth-1:0] byte_addr
  );
    if (BytesPerWord == 0) return '0; // Should not happen with DataWidth > 0
    return byte_addr / BytesPerWord;
  endfunction

  // --- Write Channel Logic ---
  assign aw_ready_next = !aw_processing_w_reg && (!b_valid_reg || axi_req_i.b_ready);
  assign w_ready_next  = aw_processing_w_reg && !b_valid_reg; // Can only accept W if AW processed and no B pending for *this* slave.


  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      aw_processing_w_reg <= 1'b0;
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
        aw_processing_w_reg <= 1'b1; // Start processing W phase
        aw_id_reg         <= axi_req_i.aw.id;
        aw_addr_reg       <= axi_req_i.aw.addr;
        aw_len_reg        <= axi_req_i.aw.len;
        aw_size_reg       <= axi_req_i.aw.size;
        aw_burst_reg      <= axi_req_i.aw.burst;
        if (UserWidth > 0) aw_user_reg <= axi_req_i.aw.user;
        w_beats_count_reg <= '0;
      end

      // W Channel data and memory write
      if (aw_processing_w_reg && axi_req_i.w_valid && w_ready_next) begin
        logic [AddrWidth-1:0] current_w_byte_addr;
        logic [AddrWidth-1:0] target_mem_word_idx_full; // Full width before truncation
        logic [MemIndexWidth-1:0] actual_mem_idx;
        logic is_write_error;

        current_w_byte_addr = calculate_beat_byte_addr(aw_addr_reg, aw_burst_reg, aw_size_reg, aw_len_reg, w_beats_count_reg);
        target_mem_word_idx_full = get_target_word_idx(current_w_byte_addr);

        is_write_error = (MemDepthWords == 0) || (target_mem_word_idx_full >= MemDepthWords);

        if (!is_write_error) begin
            actual_mem_idx = target_mem_word_idx_full[MemIndexWidth-1:0];
            for (int i = 0; i < StrbWidth; i++) begin
                if (axi_req_i.w.strb[i]) begin
                   ram[actual_mem_idx][i*8 +: 8] <= axi_req_i.w.data[i*8 +: 8];
                end
            end
        end

        if (w_beats_count_reg == aw_len_reg) begin // Last beat of the burst
          aw_processing_w_reg <= 1'b0; // Finished with W phase, AW info can be overwritten
          b_valid_reg       <= 1'b1;   // Prepare B response
          b_id_reg          <= aw_id_reg;
          if (UserWidth > 0) b_user_reg <= '0; // Match sim_mem (aw_user_reg if propagating)
          b_resp_reg        <= is_write_error ? AXI_RESP_SLVERR : AXI_RESP_OKAY;
        end else begin
          w_beats_count_reg <= w_beats_count_reg + 1;
        end
      end

      // B Channel handshake
      if (b_valid_reg && axi_req_i.b_ready) begin
        b_valid_reg <= 1'b0;
      end
    end
  end

  assign axi_rsp_o.aw_ready = aw_ready_next;
  assign axi_rsp_o.w_ready  = w_ready_next;
  assign axi_rsp_o.b.id     = b_id_reg;
  assign axi_rsp_o.b.resp   = b_resp_reg;
  assign axi_rsp_o.b.user   = (UserWidth > 0) ? b_user_reg : '0;
  assign axi_rsp_o.b_valid  = b_valid_reg;


  // --- Read Path Logic ---
  assign ar_ready_next = !ar_processing_r_reg && (!r_valid_reg || axi_req_i.r_ready);

  always_comb begin
    logic [AddrWidth-1:0] current_r_byte_addr;
    logic [AddrWidth-1:0] target_mem_word_idx_full;
    logic [MemIndexWidth-1:0] actual_mem_idx;
    logic is_read_error;

    // Default R channel payload values
    r_id_payload   = ar_id_reg; // From latched AR request
    if (UserWidth > 0) r_user_payload = '0; /*ar_user_reg;*/ else r_user_payload = '0; // Match sim_mem

    current_r_byte_addr = calculate_beat_byte_addr(ar_addr_reg, ar_burst_reg, ar_size_reg, ar_len_reg, r_beats_count_reg);
    target_mem_word_idx_full = get_target_word_idx(current_r_byte_addr);

    is_read_error = (MemDepthWords == 0) || (target_mem_word_idx_full >= MemDepthWords);

    if (is_read_error) begin
      r_data_payload = {DataWidth{1'bx}}; // SLVERR for read data is undefined by spec, 'x is common
      r_resp_payload = AXI_RESP_SLVERR;
    end else begin
      actual_mem_idx = target_mem_word_idx_full[MemIndexWidth-1:0];
      r_data_payload = ram[actual_mem_idx]; // Combinational read from memory
      r_resp_payload = AXI_RESP_OKAY;
    end
    r_last_payload = (r_beats_count_reg == ar_len_reg);
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      ar_processing_r_reg <= 1'b0;
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
        ar_processing_r_reg <= 1'b1; // Start R phase
        ar_id_reg         <= axi_req_i.ar.id;
        ar_addr_reg       <= axi_req_i.ar.addr;
        ar_len_reg        <= axi_req_i.ar.len;
        ar_size_reg       <= axi_req_i.ar.size;
        ar_burst_reg      <= axi_req_i.ar.burst;
        if (UserWidth > 0) ar_user_reg <= axi_req_i.ar.user;
        r_beats_count_reg <= '0;
        r_valid_reg       <= 1'b1; // R data available combinatorially from ram, so RVALID can go high in same cycle AR is accepted.
                                   // If BRAM has registered output, this r_valid_reg would need to be delayed.
      end else if (r_valid_reg && axi_req_i.r_ready) begin // R beat transferred
        if (r_beats_count_reg == ar_len_reg) begin // Last beat was sent and accepted
          ar_processing_r_reg <= 1'b0; // Finished with R phase
          r_valid_reg       <= 1'b0;
        end else begin
          r_beats_count_reg <= r_beats_count_reg + 1;
          // r_valid_reg remains high for the next beat (data will update via comb logic)
        end
      end else if (r_valid_reg && !axi_req_i.r_ready) begin
        // RVALID is high, but RREADY is low (stall condition).
        // Hold RVALID, data, and beat counter. No state change in this part.
      end else if (!ar_processing_r_reg) begin
        // If no AR is active (e.g. after last beat sent and RVALID went low, or at init), ensure RVALID is low.
        r_valid_reg <= 1'b0;
      end
      // If ar_processing_r_reg is true, but r_valid_reg is false (e.g. initial cycle after AR accepted if RVALID was delayed by a reg stage)
      // then r_valid_reg should go high. This is handled by the AR acceptance logic setting r_valid_reg.
    end
  end

  assign axi_rsp_o.ar_ready = ar_ready_next;
  assign axi_rsp_o.r.id     = r_id_payload;
  assign axi_rsp_o.r.data   = r_data_payload;
  assign axi_rsp_o.r.resp   = r_resp_payload;
  assign axi_rsp_o.r.last   = r_last_payload;
  assign axi_rsp_o.r.user   = (UserWidth > 0) ? r_user_payload : '0;
  assign axi_rsp_o.r_valid  = r_valid_reg;

  `ifdef SIMULATION_MEMORY_INIT
  initial begin
    if (MemDepthWords > 0) begin
      for (int i = 0; i < MemDepthWords; i++) begin
        ram[i] = $random(); // Or '0 or specific pattern
      end
    end
  end
  `endif

endmodule
