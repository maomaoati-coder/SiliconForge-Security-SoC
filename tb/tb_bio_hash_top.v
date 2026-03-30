`timescale 1ns/1ps
module tb_bio_hash_top;

reg         clk, rst_n, start;
reg  [63:0] puf_data, bio_data;
wire [127:0] token;
wire [63:0]  phys_xor;
wire         hash_valid;

bio_hash_top dut (
    .clk(clk), .rst_n(rst_n), .start(start),
    .puf_data(puf_data), .bio_data(bio_data),
    .token(token), .phys_xor(phys_xor), .hash_valid(hash_valid)
);

initial clk = 0;
always #5 clk = ~clk;

integer pass_cnt, fail_cnt, wait_cnt;
reg [127:0] token_snap1, token_snap2;
reg [63:0]  xor_snap1;

task check;
    input cond;
    input [127:0] label;
    begin
        if (cond) begin
            $display("[PASS] %s", label); pass_cnt = pass_cnt + 1;
        end else begin
            $display("[FAIL] %s", label); fail_cnt = fail_cnt + 1;
        end
    end
endtask

// 安全等待：最多30周期，valid拉高即退出
task run_hash;
    input [63:0] puf, bio;
    begin
        @(negedge clk);
        puf_data = puf; bio_data = bio; start = 1;
        wait_cnt = 0;
        while (hash_valid !== 1 && wait_cnt < 30) begin
            @(posedge clk); #1;
            wait_cnt = wait_cnt + 1;
        end
    end
endtask

initial begin
    $dumpfile("dump_hash.vcd");
    $dumpvars(0, tb_bio_hash_top);

    pass_cnt=0; fail_cnt=0;
    $display("=========================================");
    $display(" bio_hash_top Verify - SiliconForge V3.0");
    $display("=========================================");

    // TC01: reset
    rst_n=0; start=0; puf_data=64'd0; bio_data=64'd0;
    repeat(3) @(posedge clk);
    rst_n=1; @(posedge clk); #1;
    check(hash_valid===0,  "TC01_RST_valid=0    ");
    check(token===128'd0,  "TC01_RST_token=0    ");

    // TC02: no start
    @(posedge clk); #1;
    check(hash_valid===0,  "TC02_NOSTART_v=0    ");

    // TC03: run hash
    $display("--- ARX hash start ---");
    run_hash(64'hDEADBEEFCAFEBABE, 64'h0123456789ABCDEF);
    check(hash_valid===1,  "TC03_DONE_valid=1   ");

    // TC04: token non-zero
    check(token!==128'd0,  "TC04_TOKEN_nonzero  ");

    // TC05: token not all-1
    check(token!==128'hFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF,
                           "TC05_TOKEN_not_all1 ");

    // TC06: phys_xor non-zero
    check(phys_xor!==64'd0,"TC06_XOR_nonzero    ");

    // TC07: start=0 -> valid=0
    token_snap1 = token;
    xor_snap1   = phys_xor;
    @(negedge clk); start=0;
    repeat(3) @(posedge clk); #1;
    check(hash_valid===0,  "TC07_DIS_valid=0    ");

    // TC08: same input -> same output
    run_hash(64'hDEADBEEFCAFEBABE, 64'h0123456789ABCDEF);
    token_snap2 = token;
    check(token_snap1===token_snap2,
                           "TC08_DETERM_same    ");

    // TC09: different input -> different token
    @(negedge clk); start=0;
    repeat(2) @(posedge clk);
    run_hash(64'hFFFFFFFFFFFFFFFF, 64'h0000000000000000);
    check(token!==token_snap1,
                           "TC09_DIFF_avalanche  ");

    // TC10: phys_xor changes with input
    check(phys_xor!==xor_snap1,
                           "TC10_XOR_changes    ");

    // TC11: all-zero input still valid
    @(negedge clk); start=0;
    repeat(2) @(posedge clk);
    run_hash(64'd0, 64'd0);
    check(hash_valid===1,  "TC11_ZERO_valid=1   ");
    check(token!==128'd0,  "TC11_ZERO_token_ok  ");

    // TC12: reset clears
    @(negedge clk); rst_n=0; start=0;
    repeat(2) @(posedge clk);
    rst_n=1; @(posedge clk); #1;
    check(hash_valid===0,  "TC12_RST2_valid=0   ");
    check(token===128'd0,  "TC12_RST2_token=0   ");

    $display("=========================================");
    $display("  PASS: %0d | FAIL: %0d", pass_cnt, fail_cnt);
    if (fail_cnt==0)
        $display("  ALL PASS - bio_hash_top ready");
    else
        $display("  FAILED - fix RTL");
    $display("=========================================");
    $finish;
end

initial begin #200000; $display("[TIMEOUT]"); $finish; end
endmodule
