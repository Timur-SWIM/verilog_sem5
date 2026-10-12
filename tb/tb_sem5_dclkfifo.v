`timescale 1ns/1ps

module tb_sem5_dclkfifo;

localparam DATA_WIDTH = 8;
localparam ADDR_WIDTH = 3;
localparam DEPTH      = (1 << ADDR_WIDTH);

reg                   wr_clk;
reg                   wr_rst;
reg                   wr_en;
reg  [DATA_WIDTH-1:0] data_in;
wire                  full;

reg                   rd_clk;
reg                   rd_rst;
reg                   rd_en;
wire [DATA_WIDTH-1:0] data_out;
wire                  empty;

integer errors;
integer i;
integer round;
integer timeout;
reg [DATA_WIDTH-1:0] expected;
reg [DATA_WIDTH-1:0] held_data;

sem5_dclkfifo #(
    .DATA_WIDTH(DATA_WIDTH),
    .ADDR_WIDTH(ADDR_WIDTH)
) dut (
    .wr_clk  (wr_clk),
    .wr_rst  (wr_rst),
    .wr_en   (wr_en),
    .data_in (data_in),
    .full    (full),
    .rd_clk  (rd_clk),
    .rd_rst  (rd_rst),
    .rd_en   (rd_en),
    .data_out(data_out),
    .empty   (empty)
);

// Independent clocks: 100 MHz write clock and about 71 MHz read clock.
initial begin
    wr_clk = 1'b0;
    forever #5 wr_clk = ~wr_clk;
end

initial begin
    rd_clk = 1'b0;
    forever #7 rd_clk = ~rd_clk;
end

task write_word;
    input [DATA_WIDTH-1:0] value;
    begin
        @(negedge wr_clk);
        data_in = value;
        wr_en   = 1'b1;
        @(posedge wr_clk);
        #1;
        @(negedge wr_clk);
        wr_en   = 1'b0;
    end
endtask

task read_and_check;
    input [DATA_WIDTH-1:0] value;
    begin
        // The write pointer needs two rd_clk cycles to cross clock domains.
        timeout = 0;
        while ((empty !== 1'b0) && (timeout < 20)) begin
            @(posedge rd_clk);
            #1;
            timeout = timeout + 1;
        end

        if (empty !== 1'b0) begin
            $display("ERROR: timeout waiting for empty to deassert at %0t", $time);
            errors = errors + 1;
        end
        else begin
            @(negedge rd_clk);
            rd_en = 1'b1;
            @(posedge rd_clk);
            #1;

            if (data_out !== value) begin
                $display("ERROR: read 0x%0h, expected 0x%0h at %0t",
                         data_out, value, $time);
                errors = errors + 1;
            end

            @(negedge rd_clk);
            rd_en = 1'b0;
        end
    end
endtask

task wait_until_full;
    begin
        timeout = 0;
        while ((full !== 1'b1) && (timeout < 20)) begin
            @(posedge wr_clk);
            #1;
            timeout = timeout + 1;
        end
        if (full !== 1'b1) begin
            $display("ERROR: timeout waiting for full at %0t", $time);
            errors = errors + 1;
        end
    end
endtask

task wait_until_empty;
    begin
        timeout = 0;
        while ((empty !== 1'b1) && (timeout < 20)) begin
            @(posedge rd_clk);
            #1;
            timeout = timeout + 1;
        end
        if (empty !== 1'b1) begin
            $display("ERROR: timeout waiting for empty at %0t", $time);
            errors = errors + 1;
        end
    end
endtask

initial begin
    $dumpfile("wave.vcd");
    $dumpvars(0, tb_sem5_dclkfifo);

    errors  = 0;
    wr_rst  = 1'b1;
    rd_rst  = 1'b1;
    wr_en   = 1'b0;
    rd_en   = 1'b0;
    data_in = {DATA_WIDTH{1'b0}};

    repeat (4) @(posedge wr_clk);
    repeat (4) @(posedge rd_clk);
    @(negedge wr_clk);
    wr_rst = 1'b0;
    @(negedge rd_clk);
    rd_rst = 1'b0;

    repeat (2) @(posedge wr_clk);
    #1;
    if (full !== 1'b0) begin
        $display("ERROR: full is asserted after reset at %0t", $time);
        errors = errors + 1;
    end
    if (empty !== 1'b1) begin
        $display("ERROR: empty is deasserted after reset at %0t", $time);
        errors = errors + 1;
    end

    // An attempted read while empty must not change data_out.
    held_data = data_out;
    @(negedge rd_clk);
    rd_en = 1'b1;
    repeat (2) @(posedge rd_clk);
    #1;
    rd_en = 1'b0;
    if ((data_out !== held_data) || (empty !== 1'b1)) begin
        $display("ERROR: empty read changed FIFO state at %0t", $time);
        errors = errors + 1;
    end

    // Basic transfer also checks pointer synchronization between domains.
    write_word(8'hA5);
    read_and_check(8'hA5);
    wait_until_empty;

    // Repeated fill/drain cycles check full, overflow protection, ordering,
    // and binary/Gray pointer wrap-around.
    for (round = 0; round < 3; round = round + 1) begin
        for (i = 0; i < DEPTH; i = i + 1) begin
            expected = (round * DEPTH) + i + 8'h20;
            write_word(expected);
        end

        wait_until_full;

        // A write while full must be ignored.
        @(negedge wr_clk);
        data_in = 8'hEE;
        wr_en   = 1'b1;
        @(posedge wr_clk);
        #1;
        if (full !== 1'b1) begin
            $display("ERROR: full deasserted after blocked write at %0t", $time);
            errors = errors + 1;
        end
        @(negedge wr_clk);
        wr_en = 1'b0;

        for (i = 0; i < DEPTH; i = i + 1) begin
            expected = (round * DEPTH) + i + 8'h20;
            read_and_check(expected);
        end

        wait_until_empty;

        // Let the read pointer propagate back before the next fill cycle.
        timeout = 0;
        while ((full !== 1'b0) && (timeout < 20)) begin
            @(posedge wr_clk);
            #1;
            timeout = timeout + 1;
        end
        if (full !== 1'b0) begin
            $display("ERROR: full did not clear after reads at %0t", $time);
            errors = errors + 1;
        end
    end

    if (errors == 0)
        $display("PASS: all asynchronous FIFO tests completed successfully");
    else
        $display("FAIL: %0d error(s) detected", errors);

    #20;
    $finish;
end

endmodule
