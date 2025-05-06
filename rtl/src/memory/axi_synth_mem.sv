`include "axi/typedef.svh"

/// Synthesizable Memory with AXI Slave Port
///
/// This module implements a synthesizable memory with an AXI slave interface.
/// It supports configurable address and data widths and multiple ports.
/// Memory is implemented as a real array with defined size.
///
/// This module does not support atomic operations (ATOPs).
module axi_synth_mem #(
  /// AXI Address Width
  parameter int unsigned AddrWidth = 32'd0,
  /// AXI Data Width
  parameter int unsigned DataWidth = 32'd0,
  /// AXI ID Width
  parameter int unsigned IdWidth = 32'd0,
  /// AXI User Width
  parameter int unsigned UserWidth = 32'd0,
  /// Number of request ports
  parameter int unsigned NumPorts = 32'd1,
  /// Memory size in bytes (must be a power of 2)
  parameter int unsigned MemSizeBytes = 32'd4096,
  /// AXI4 request struct definition
  parameter type axi_req_t = logic,
  /// AXI4 response struct definition
  parameter type axi_rsp_t = logic
) (
  /// Rising-edge clock
  input  logic clk_i,
  /// Active-low reset
  input  logic rst_ni,
  /// AXI4 request struct
  input  axi_req_t [NumPorts-1:0] axi_req_i,
  /// AXI4 response struct
  output axi_rsp_t [NumPorts-1:0] axi_rsp_o
);


endmodule
