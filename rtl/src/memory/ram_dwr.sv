`timescale 1ns / 1ps

`include "header.vh"

module ram32_dwr #(
   parameter SIZE = 16384,  // 64 K
   parameter INIT_FILE = ""
) (
   input clk_i,
   input rst_ni,

   input               req_i,
   input               we_i,
   input        [ 3:0] be_i,
   input        [31:0] addr_i,
   input        [31:0] wdata_i,
   output logic        rvalid_o,
   output logic [31:0] rdata_o

   ,input logic program_rx_i
   ,output logic system_reset_o
   ,output logic prog_mode_led_o

   // New outputs for DRAM programming
   ,output logic dram_write_we_o,
   output logic [31:0] dram_write_addr_o,
   output logic [31:0] dram_write_data_o,
   output logic dram_write_rst_o,
   output logic dram_mode_o
);

   localparam int ADDR_W = $clog2(SIZE*4);

   logic [ADDR_W-1:0] mem_addr;
   assign mem_addr = addr_i[ADDR_W-1+2:2];

   function integer clogb2;
   input integer depth;
     for (clogb2=0; depth>0; clogb2=clogb2+1)
       depth = depth >> 1;
   endfunction
   
   localparam NB_COL = 4;
   localparam COL_WIDTH = 8;
   localparam RAM_DEPTH = SIZE*4;
   localparam ADDR_MSB = clogb2(RAM_DEPTH) + 1;
   localparam CPU_CLK   = `CPU_CLK;
   localparam BAUD_RATE = `BAUD_RATE;
   
   // =========================================================================
   // RAM BLOCK
   // =========================================================================
   
   reg [(NB_COL*COL_WIDTH)-1:0] ram [RAM_DEPTH];
   
   generate
   if (INIT_FILE != "") begin: use_init_file
     initial
       $readmemh(INIT_FILE, ram, 0, RAM_DEPTH-1);
   end else begin: init_bram_to_zero
     integer ram_index;
     initial
       for (ram_index = 0; ram_index < RAM_DEPTH; ram_index = ram_index + 1)
         ram[ram_index] = {(NB_COL*COL_WIDTH){1'b0}};
   end
   endgenerate
   
   wire [ADDR_W-1:0] write_addr;
   wire [(NB_COL*COL_WIDTH)-1:0] write_data;
   wire [3:0] write_be;
   wire write_en;
   
   reg [31:0] ram_rdata;

   always @(posedge clk_i) begin
      if (write_en) begin
         for (int i = 0; i < 4; i++) 
            if (write_be[i]) 
               ram[write_addr][i*8+:8] <= write_data[i*8+:8];
      end
      ram_rdata <= ram[mem_addr];
   end

   localparam RESET_SEQUENCE    = "RESETTTTT";

   // Programming state machine signals
   localparam PROGRAM_SEQUENCE    = "TEKNOFEST";
   localparam DRAMWRITE_SEQUENCE  = "DRAMWRITE"; // New sequence
   localparam PROG_SEQ_LENGTH     = 9;
   localparam SEQ_BREAK_THRESHOLD = 32'd1000000;
   
   reg [PROG_SEQ_LENGTH*8-1:0] received_sequence;
   
   reg rvalid_r;
   always @(posedge clk_i or negedge rst_ni) begin
      if (!rst_ni)
         rvalid_r <= 1'b0;
      else if(received_sequence == RESET_SEQUENCE)
         rvalid_r <= 1'b0;
      else
         rvalid_r <= req_i;
   end
   
   // =========================================================================
   // BOOTROM INITIALIZATION CONTROLLER
   // =========================================================================
   
   reg [31:0] boot_rom_addr;
   wire [31:0] boot_rom_rdata;
   reg boot_in_progress;
   reg boot_done;
   
   bootrom boot_mem (
      .addr_i(boot_rom_addr),
      .rdata_o(boot_rom_rdata)
   );
   
   always @(posedge clk_i or negedge rst_ni) begin
      if (!rst_ni) begin
         if (`USE_BOOTROM) begin
            boot_rom_addr <= 32'd0;
            boot_in_progress <= 1'b1;  
            boot_done <= 1'b0;
         end else begin
            boot_in_progress <= 1'b0;
            boot_done <= 1'b1;
         end
      end
      else if(received_sequence == RESET_SEQUENCE) begin
         if (`USE_BOOTROM) begin
            boot_rom_addr <= 32'd0;
            boot_in_progress <= 1'b1;  
            boot_done <= 1'b0;
         end else begin
            boot_in_progress <= 1'b0;
            boot_done <= 1'b1;
         end
      end
      else begin
         if (boot_in_progress) begin
            if (boot_rom_addr < RAM_DEPTH-1) begin
               boot_rom_addr <= boot_rom_addr + 1'b1;
            end else begin
               boot_in_progress <= 1'b0;
               boot_done <= 1'b1;
            end
         end
      end
   end

   wire boot_write_en = boot_in_progress;
   wire [ADDR_W-1:0] boot_write_addr = boot_rom_addr[ADDR_W-1:0];
   wire [31:0] boot_write_data = boot_rom_rdata;
   wire [3:0] boot_write_be = 4'hF;
   
   // =========================================================================
   // PROGRAMMING CONTROLLER 
   // =========================================================================
   
   // Signals for TEKNOFEST programming
   reg  [clogb2(RAM_DEPTH-1)-1:0] prog_addr;
   reg [31:0] prog_instruction;
   reg prog_inst_valid;
   reg prog_sys_rst_n;
   wire [31:0] ram_prog_data = prog_instruction;
   wire ram_prog_data_valid = prog_inst_valid;
   reg [31:0] prog_intr_number;
   reg [31:0] prog_intr_ctr;

   // Signals for DRAMWRITE programming
   reg [31:0] dram_prog_size;
   reg [31:0] dram_prog_ctr;
   reg [31:0] dram_prog_addr;
   reg [31:0] dram_prog_instruction;
   reg dram_prog_inst_valid;
   reg dram_prog_sys_rst_n;
   
   reg [3:0] rcv_seq_ctr;
   reg [31:0] sequence_break_ctr;
   wire sequence_break = sequence_break_ctr == SEQ_BREAK_THRESHOLD;
   
   wire [31:0] prog_uart_do;
   wire ram_prog_rd_en;
   
   localparam SequenceWait           = 4'b0000;
   localparam SequenceReceive        = 4'b0001;
   localparam SequenceCheck          = 4'b0011;
   localparam SequenceLengthCalc     = 4'b0010;
   localparam SequenceProgram        = 4'b0110;
   localparam SequenceFinish         = 4'b0100;
   localparam SequenceDramWriteLengthCalc = 4'b1010;
   localparam SequenceDramWriteProgram    = 4'b1110;
   localparam SequenceDramWriteFinish     = 4'b1100;
   
   reg [3:0] state_prog;
   reg [3:0] state_prog_next;
   reg [1:0] instruction_byte_ctr;
   
   wire prog_write_en = prog_mode_led_o && ram_prog_data_valid;
   wire [ADDR_W-1:0] prog_write_addr = prog_addr;
   wire [31:0] prog_write_data = ram_prog_data;
   wire [3:0] prog_write_be = 4'hF;
   
   always @(posedge clk_i or negedge rst_ni) begin
      if (!rst_ni) begin
        state_prog <= SequenceWait;
      end
      else if(received_sequence == RESET_SEQUENCE) begin
        state_prog <= SequenceWait;
      end
      else begin
        state_prog <= state_prog_next;
      end
   end

   always @(*) begin
      state_prog_next = state_prog;
      case (state_prog)
        SequenceWait: begin
          if (prog_uart_do != ~0) begin
            state_prog_next = SequenceReceive;
          end
        end
        SequenceReceive: begin
          if (prog_uart_do != ~0) begin
            if (rcv_seq_ctr == PROG_SEQ_LENGTH-1) begin
              state_prog_next = SequenceCheck;
            end
          end else if (sequence_break) begin
            state_prog_next = SequenceWait;
          end
        end
        SequenceCheck: begin
          if (received_sequence == PROGRAM_SEQUENCE) begin
            state_prog_next = SequenceLengthCalc;
          end else if (received_sequence == DRAMWRITE_SEQUENCE) begin
            state_prog_next = SequenceDramWriteLengthCalc;
          end else begin
            state_prog_next = SequenceWait;
          end
        end
        SequenceLengthCalc: begin
          if ((prog_uart_do != ~0) && &instruction_byte_ctr) begin
            state_prog_next = SequenceProgram;
          end
        end
        SequenceProgram: begin
          if (prog_intr_ctr == prog_intr_number) begin
            state_prog_next = SequenceFinish;
          end
        end
        SequenceFinish: begin
          state_prog_next = SequenceWait;
        end
        SequenceDramWriteLengthCalc: begin
          if ((prog_uart_do != ~0) && &instruction_byte_ctr) begin
            state_prog_next = SequenceDramWriteProgram;
          end
        end
        SequenceDramWriteProgram: begin
          if (dram_prog_ctr == dram_prog_size) begin
            state_prog_next = SequenceDramWriteFinish;
          end
        end
        SequenceDramWriteFinish: begin
          state_prog_next = SequenceWait;
        end
        default: begin
        end
      endcase
   end

   always @(posedge clk_i or negedge rst_ni) begin
      if (!rst_ni) begin
        instruction_byte_ctr <= 2'b0;
        prog_instruction     <= 32'h0;
        prog_intr_number     <= 32'h0;
        prog_intr_ctr        <= 32'h0;
        sequence_break_ctr   <= 32'h0;
        received_sequence    <= 72'h0;
        rcv_seq_ctr          <= 4'h0;
        prog_inst_valid      <= 1'b0;
        prog_sys_rst_n       <= 1'b1;
        prog_addr            <= 'h0;
        dram_prog_size       <= 32'h0;
        dram_prog_ctr        <= 32'h0;
        dram_prog_addr       <= 32'h0;
        dram_prog_instruction<= 32'h0;
        dram_prog_inst_valid <= 1'b0;
        dram_prog_sys_rst_n  <= 1'b1;
      end
      else if(received_sequence == RESET_SEQUENCE) begin
        instruction_byte_ctr <= 2'b0;
        prog_instruction     <= 32'h0;
        prog_intr_number     <= 32'h0;
        prog_intr_ctr        <= 32'h0;
        sequence_break_ctr   <= 32'h0;
        received_sequence    <= 72'h0;
        rcv_seq_ctr          <= 4'h0;
        prog_inst_valid      <= 1'b0;
        prog_sys_rst_n       <= 1'b1;
        prog_addr            <= 'h0;
        dram_prog_size       <= 32'h0;
        dram_prog_ctr        <= 32'h0;
        dram_prog_addr       <= 32'h0;
        dram_prog_instruction<= 32'h0;
        dram_prog_inst_valid <= 1'b0;
        dram_prog_sys_rst_n  <= 1'b1;
      end
      else begin
        prog_inst_valid <= 1'b0;
        dram_prog_inst_valid <= 1'b0;
        prog_sys_rst_n <= 1'b1;
        dram_prog_sys_rst_n <= 1'b1;
        
        if(!system_reset_o) begin
          prog_addr <= 'h0;
        end
        else if (prog_mode_led_o && ram_prog_data_valid) begin
          prog_addr <= prog_addr + 1'b1;
        end
        
        if (dram_write_we_o) begin
          dram_prog_addr <= dram_prog_addr + 'h4;
        end
        
        case (state_prog)
          SequenceWait: begin
            instruction_byte_ctr <= 2'b0;
            prog_instruction     <= 32'h0;
            prog_intr_number     <= 32'h0;
            prog_intr_ctr        <= 32'h0;
            sequence_break_ctr   <= 32'h0;
            received_sequence    <= 72'h0;
            rcv_seq_ctr          <= 4'h0;
            prog_inst_valid      <= 1'b0;
            prog_sys_rst_n       <= 1'b1;
            dram_prog_size       <= 32'h0;
            dram_prog_ctr        <= 32'h0;
            dram_prog_addr       <= 32'h0;
            dram_prog_instruction<= 32'h0;
            dram_prog_inst_valid <= 1'b0;
            dram_prog_sys_rst_n  <= 1'b1;
            if (prog_uart_do != ~0) begin
              rcv_seq_ctr <= rcv_seq_ctr + 4'h1;
              received_sequence <= {received_sequence[PROG_SEQ_LENGTH*8-9:0],prog_uart_do[7:0]};
            end
          end
          SequenceReceive: begin
            if (prog_uart_do != ~0) begin
              received_sequence <= {received_sequence[PROG_SEQ_LENGTH*8-9:0],prog_uart_do[7:0]};
              if (rcv_seq_ctr == PROG_SEQ_LENGTH-1) begin
                rcv_seq_ctr <= 4'h0;
              end else begin
                rcv_seq_ctr <= rcv_seq_ctr + 4'h1;
              end
            end else begin
              if (sequence_break) begin
                sequence_break_ctr <= 32'h0;
                rcv_seq_ctr        <= 4'h0;
              end else begin
                sequence_break_ctr <= sequence_break_ctr + 32'h1;
              end
            end
          end
          SequenceCheck: begin
            instruction_byte_ctr <= 2'b0;
          end
          SequenceLengthCalc: begin
            prog_intr_ctr <= 32'h0;
            if (prog_uart_do != ~0) begin
              prog_intr_number <= {prog_intr_number[3*8-1:0],prog_uart_do[7:0]};
              if (&instruction_byte_ctr) begin
                instruction_byte_ctr <= 2'b0;
              end else begin
                instruction_byte_ctr <= instruction_byte_ctr + 2'b1;
              end
            end
          end
          SequenceProgram: begin
            if (prog_uart_do != ~0) begin
              prog_instruction <= {prog_instruction[3*8-1:0],prog_uart_do[7:0]};
              if (&instruction_byte_ctr) begin
                instruction_byte_ctr <= 2'b0;
                prog_inst_valid      <= 1'b1;
                prog_intr_ctr        <= prog_intr_ctr + 32'h1;
              end else begin
                instruction_byte_ctr <= instruction_byte_ctr + 2'b1;
                prog_inst_valid      <= 1'b0;
              end
            end else begin
              prog_inst_valid      <= 1'b0;
            end
          end
          SequenceFinish: begin
            prog_sys_rst_n <= 1'b0;
          end
          SequenceDramWriteLengthCalc: begin
            dram_prog_ctr <= 32'h0;
            dram_prog_addr <= 32'h0;
            if (prog_uart_do != ~0) begin
              dram_prog_size <= {dram_prog_size[3*8-1:0],prog_uart_do[7:0]};
              if (&instruction_byte_ctr) begin
                instruction_byte_ctr <= 2'b0;
              end else begin
                instruction_byte_ctr <= instruction_byte_ctr + 2'b1;
              end
            end
          end
          SequenceDramWriteProgram: begin
            if (prog_uart_do != ~0) begin
              dram_prog_instruction <= {dram_prog_instruction[3*8-1:0],prog_uart_do[7:0]};
              if (&instruction_byte_ctr) begin
                instruction_byte_ctr <= 2'b0;
                dram_prog_inst_valid <= 1'b1;
                dram_prog_ctr        <= dram_prog_ctr + 32'h1;
              end else begin
                instruction_byte_ctr <= instruction_byte_ctr + 2'b1;
                dram_prog_inst_valid <= 1'b0;
              end
            end else begin
              dram_prog_inst_valid <= 1'b0;
            end
          end
          SequenceDramWriteFinish: begin
            dram_prog_sys_rst_n <= 1'b0;
          end
          default: begin
          end
        endcase
      end
   end

   // =========================================================================
   // STANDARD CPU INTERFACE
   // =========================================================================
   
   wire cpu_write_en = req_i && we_i && boot_done;
   wire [ADDR_W-1:0] cpu_write_addr = mem_addr;
   wire [31:0] cpu_write_data = wdata_i;
   wire [3:0] cpu_write_be = be_i;
   
   // =========================================================================
   // ARBITRATION BETWEEN ACCESS SOURCES
   // =========================================================================
   
   assign write_en = boot_write_en ? 1'b1 :
                    prog_write_en ? 1'b1 :
                    cpu_write_en;
   
   assign write_addr = boot_write_en ? boot_write_addr :
                      prog_write_en ? prog_write_addr :
                      cpu_write_addr;
   
   assign write_data = boot_write_en ? boot_write_data :
                      prog_write_en ? prog_write_data :
                      cpu_write_data;
   
   assign write_be = boot_write_en ? boot_write_be :
                    prog_write_en ? prog_write_be :
                    cpu_write_be;
                   
   // Output assignments
   assign rvalid_o = rvalid_r;
   assign rdata_o = ram_rdata;
   assign prog_mode_led_o = (state_prog == SequenceProgram);
   assign system_reset_o = prog_sys_rst_n && boot_done;
   assign ram_prog_rd_en = (state_prog != SequenceFinish) && (state_prog != SequenceDramWriteFinish);

   // New DRAM output assignments
   assign dram_write_we_o   = dram_prog_inst_valid;
   assign dram_write_addr_o = dram_prog_addr;
   assign dram_write_data_o = dram_prog_instruction;
   assign dram_write_rst_o  = !dram_prog_sys_rst_n;
   assign dram_mode_o = (state_prog == SequenceDramWriteProgram);
   
   // =========================================================================
   // UART FOR PROGRAMMING
   // =========================================================================
   
   simpleuart #(
     .DEFAULT_DIV(CPU_CLK/BAUD_RATE)
   )
   simpleuart (
      .clk         (clk_i),
      .resetn      (rst_ni),
      .ser_tx      (),
      .ser_rx      (program_rx_i),
      .reg_div_we  (4'h0),
      .reg_div_di  (32'h0),
      .reg_div_do  (),
      .reg_dat_we  (1'b0),
      .reg_dat_re  (ram_prog_rd_en),
      .reg_dat_di  (32'h0),
      .reg_dat_do  (prog_uart_do)
   );

   initial begin
      boot_rom_addr = 0;
      boot_in_progress = `USE_BOOTROM && (INIT_FILE == "");
      boot_done = ~`USE_BOOTROM || (INIT_FILE != "");
      prog_addr = 'h0;
      state_prog = SequenceWait;
      rvalid_r = 0;
      instruction_byte_ctr = 2'b0;
      prog_instruction = 32'h0;
      prog_intr_number = 32'h0;
      prog_intr_ctr = 32'h0;
      sequence_break_ctr = 32'h0;
      received_sequence = 72'h0;
      rcv_seq_ctr = 4'h0;
      prog_inst_valid = 1'b0;
      prog_sys_rst_n = 1'b1;
      dram_prog_size       = 32'h0;
      dram_prog_ctr        = 32'h0;
      dram_prog_addr       = 32'h0;
      dram_prog_instruction= 32'h0;
      dram_prog_inst_valid = 1'b0;
      dram_prog_sys_rst_n  = 1'b1;
   end

endmodule
