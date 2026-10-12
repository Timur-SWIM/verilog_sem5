module sem5_dclkfifo #(
    parameter  DATA_WIDTH = 8,
    parameter ADDR_WIDTH = 4
)(
    input wire wr_clk,
    input wire wr_rst,
    input wire wr_en,
    input wire [DATA_WIDTH-1:0] data_in,
    output reg full,

    input wire rd_clk,
    input wire rd_rst,
    input wire rd_en,
    output reg [DATA_WIDTH-1:0] data_out,
    output reg empty
);

// MEM
localparam DEPTH = (1 << ADDR_WIDTH);

reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];

// Binary pointers
reg [ADDR_WIDTH:0] wr_p_bin;
reg [ADDR_WIDTH:0] rd_p_bin;

wire [ADDR_WIDTH:0] wr_p_bin_next;
wire [ADDR_WIDTH:0] rd_p_bin_next;

assign wr_p_bin_next =
    wr_p_bin + ((wr_en && !full) ? 1'b1 : 1'b0);

assign rd_p_bin_next =
    rd_p_bin + ((rd_en && !empty) ? 1'b1 : 1'b0);

// Gray pointers
reg [ADDR_WIDTH:0] wr_p_gray;
reg [ADDR_WIDTH:0] rd_p_gray;

wire [ADDR_WIDTH:0] wr_p_gray_next;
wire [ADDR_WIDTH:0] rd_p_gray_next;

assign wr_p_gray_next =
    (wr_p_bin_next >> 1) ^ wr_p_bin_next;

assign rd_p_gray_next =
    (rd_p_bin_next >> 1) ^ rd_p_bin_next;

// WRITE
always @(posedge wr_clk) begin
    if (wr_en && !full) begin
        mem[wr_p_bin[ADDR_WIDTH-1:0]] <= data_in;
    end
end

// READ
always @(posedge rd_clk) begin
    if (rd_rst) begin
        data_out <= 0;
    end
    else if (rd_en && !empty) begin
        data_out <= mem[rd_p_bin[ADDR_WIDTH-1:0]];
    end
end

// SYNC
// wr pointer -> read clock domain
reg [ADDR_WIDTH:0] wr_p_gray_sync1;
reg [ADDR_WIDTH:0] wr_p_gray_sync2;

always @(posedge rd_clk ) begin
    if (rd_rst) begin
        wr_p_gray_sync1 <= 0;
        wr_p_gray_sync2 <= 0;
    end
    else begin 
        wr_p_gray_sync1 <= wr_p_gray;
        wr_p_gray_sync2 <= wr_p_gray_sync1;
    end
end

// SYNC
// rd pointer -> write clock domain
reg [ADDR_WIDTH:0] rd_p_gray_sync1;
reg [ADDR_WIDTH:0] rd_p_gray_sync2;

always @(posedge wr_clk ) begin
    if (wr_rst) begin
        rd_p_gray_sync1 <= 0;
        rd_p_gray_sync2 <= 0;
    end
    else begin
        rd_p_gray_sync1 <= rd_p_gray;
        rd_p_gray_sync2 <= rd_p_gray_sync1;
    end
end

// EMPTY
wire empty_next;
assign empty_next =
    (rd_p_gray_next == wr_p_gray_sync2);

// FULL
wire full_next;
assign full_next =
    (wr_p_gray_next ==
        {
            ~rd_p_gray_sync2[ADDR_WIDTH:ADDR_WIDTH-1],
             rd_p_gray_sync2[ADDR_WIDTH-2:0]
        });


always @(posedge wr_clk) begin
    if (wr_rst) begin
        wr_p_bin  <= 0;
        wr_p_gray <= 0;
        full <= 0;
    end
    else begin
        wr_p_bin  <= wr_p_bin_next;
        wr_p_gray <= wr_p_gray_next;
        full <= full_next;
    end
end

always @(posedge rd_clk) begin
    if (rd_rst) begin
        rd_p_bin  <= 0;
        rd_p_gray <= 0;
        empty <= 1;
    end
    else begin
        rd_p_bin  <= rd_p_bin_next;
        rd_p_gray <= rd_p_gray_next;
        empty <= empty_next;
    end
end
endmodule
