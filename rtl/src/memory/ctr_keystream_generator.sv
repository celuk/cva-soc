module ctr_keystream_generator (
    input  wire [255:0] key,
    input  wire [31:0]  row_number,
    output wire [31:0]  keystream
);

    wire [255:0] temp_0;
    wire [255:0] temp_1;
    wire [255:0] temp_2;
    wire [255:0] temp_3;

    assign temp_0 = key ^ {8{row_number}};
    assign temp_1 = temp_0 ^ (temp_0 << 13) ^ (temp_0 >> 17);
    assign temp_2 = temp_1 + {8{32'h9E3779B9}};
    assign temp_3 = temp_2 ^ (temp_2 << 7) ^ (temp_2 >> 12);

    assign keystream = temp_3[255:224] ^ temp_3[223:192] ^ temp_3[191:160] ^ temp_3[159:128] ^
                       temp_3[127:96]  ^ temp_3[95:64]   ^ temp_3[63:32]   ^ temp_3[31:0];
endmodule
