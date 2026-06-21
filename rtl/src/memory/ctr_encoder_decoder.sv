module ctr_encoder_decoder #(parameter KEY = 256'hDEADBEEFCAFEF00DBAADF00D1234567887654321ABCDEF01FEDCBA9876543210) (
    input  wire [31:0] row_number,
    input  wire [31:0] data_in,
    output wire [31:0] data_out
);

    wire [31:0] keystream_val;

    ctr_keystream_generator keygen (
        .key        (KEY),
        .row_number (row_number),
        .keystream  (keystream_val)
    );

    assign data_out = data_in ^ keystream_val;
endmodule
