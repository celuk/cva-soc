module tc_sram #(
  parameter int unsigned NumWords     = 32'd1024, // Number of Words in data array
  parameter int unsigned DataWidth    = 32'd128,  // Data signal width
  parameter int unsigned ByteWidth    = 32'd8,    // Width of a data byte
  parameter int unsigned NumPorts     = 32'd2,    // Number of read and write ports
  parameter int unsigned Latency      = 32'd1,    // Latency when the read data is available
  parameter              SimInit      = "none",   // Simulation initialization (ignored in synthesis)
  parameter bit          PrintSimCfg  = 1'b0,     // Print configuration (ignored in synthesis)
  parameter              ImplKey      = "none",   // Reference to specific implementation (ignored)
  // DEPENDENT PARAMETERS, DO NOT OVERWRITE!
  parameter int unsigned AddrWidth = (NumWords > 32'd1) ? $clog2(NumWords) : 32'd1,
  parameter int unsigned BeWidth   = (DataWidth + ByteWidth - 32'd1) / ByteWidth, // ceil_div
  parameter type         addr_t    = logic [AddrWidth-1:0],
  parameter type         data_t    = logic [DataWidth-1:0],
  parameter type         be_t      = logic [BeWidth-1:0]
) (
  input  logic                 clk_i,      // Clock
  input  logic                 rst_ni,     // Asynchronous reset active low
  // input ports
  input  logic  [NumPorts-1:0] req_i,      // request
  input  logic  [NumPorts-1:0] we_i,       // write enable
  input  addr_t [NumPorts-1:0] addr_i,     // request address
  input  data_t [NumPorts-1:0] wdata_i,    // write data
  input  be_t   [NumPorts-1:0] be_i,       // write byte enable
  // output ports
  output data_t [NumPorts-1:0] rdata_o     // read data
);

  // memory array
  data_t sram [NumWords-1:0];
  // register to hold read address
  addr_t r_addr_q [NumPorts-1:0];

  // pipeline registers for read data
  data_t rdata_q [NumPorts-1:0][Latency-1:0];

  // Write and read logic
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      // reset read address and pipeline
      for (int i = 0; i < NumPorts; i++) begin
        r_addr_q[i] <= '0;
        for (int j = 0; j < Latency; j++) begin
          rdata_q[i][j] <= '0;
        end
      end
    end else begin
      // pipeline shift and new read data
      for (int i = 0; i < NumPorts; i++) begin
        if (Latency > 0) begin
          rdata_q[i][0] <= (req_i[i] && !we_i[i]) ? sram[addr_i[i]] : sram[r_addr_q[i]];
          for (int j = 1; j < Latency; j++) begin
            rdata_q[i][j] <= rdata_q[i][j-1];
          end
        end
        // latch read address or write data
        if (req_i[i]) begin
          if (we_i[i]) begin
            /*
            // byte-write
            for (int b = 0; b < BeWidth; b++) begin
              if (be_i[i][b]) begin
                //sram[addr_i[i]][b*ByteWidth +: ByteWidth] <= wdata_i[i][b*ByteWidth +: ByteWidth];
                sram[addr_i[i]][ (b+1)*ByteWidth-1 -: ByteWidth ] <= wdata_i[i][ (b+1)*ByteWidth-1 -: ByteWidth ];
              end
            end
            */
            for (int b = 0; b < BeWidth-1; b++) begin
              if (req_i[i] && we_i[i] && be_i[i][b]) begin
                // every “middle” group is a fixed ByteWidth
                sram[addr_i[i]][ (b+1)*ByteWidth-1  -: ByteWidth ]
                  <= wdata_i[i][ (b+1)*ByteWidth-1  -: ByteWidth ];
              end
            end

            // handle the **last** byte-group with its constant LastWidth
            if (req_i[i] && we_i[i] && be_i[i][BeWidth-1]) begin
              sram[addr_i[i]][ (BeWidth-1)*ByteWidth +: (DataWidth - (BeWidth-1)*ByteWidth) ]
                <= wdata_i[i][ (BeWidth-1)*ByteWidth +: (DataWidth - (BeWidth-1)*ByteWidth) ];
            end
            

          end else begin
            r_addr_q[i] <= addr_i[i];
          end
        end
      end
    end
  end

  // assign output from pipeline or direct
  generate
    if (Latency == 0) begin : ZERO_LAT
      for (genvar p = 0; p < NumPorts; p++) begin : PORT
        assign rdata_o[p] = (req_i[p] && !we_i[p]) ? sram[addr_i[p]] : sram[r_addr_q[p]];
      end
    end else begin : WITH_LAT
      for (genvar p = 0; p < NumPorts; p++) begin : PORT
        assign rdata_o[p] = rdata_q[p][Latency-1];
      end
    end
  endgenerate

endmodule: tc_sram
