`timescale 1ns/1ps
module tb_ro_puf_top;

reg        clk, rst_n, enable;
reg  [5:0] sel;
wire [63:0] puf_response;
wire        puf_valid;

ro_puf_top dut (
    .clk(clk), .rst_n(rst_n), .enable(enable),
    .sel(sel), .puf_response(puf_response), .puf_valid(puf_valid)
);

initial clk = 0;
always #5 clk = ~clk;

integer pass_cnt, fail_cnt, hamming_w, i;
reg [63:0] snap1, snap2;

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

function integer popcount64;
    input [63:0] val;
    integer k, cnt;
    begin
        cnt = 0;
        for (k = 0; k < 64; k = k + 1)
            cnt = cnt + val[k];
        popcount64 = cnt;
    end
endfunction

initial begin
    $dumpfile("dump_puf.vcd");
    $dumpvars(0, tb_ro_puf_top);

    pass_cnt = 0; fail_cnt = 0;
    $display("=========================================");
    $display("  ro_puf_top Verify - SiliconForge V3.0");
    $display("=========================================");

    // TC01: reset
    rst_n=0; enable=0; sel=6'd0;
    repeat(3) @(posedge clk);
    rst_n=1; @(posedge clk); #1;
    check(puf_valid===0,     "TC01_RST_valid=0  ");
    check(puf_response===64'd0, "TC01_RST_resp=0   ");

    // TC02: no enable
    @(posedge clk); #1;
    check(puf_valid===0, "TC02_NO_EN_valid=0  ");

    // TC03: enable, wait sample
    $display("--- PUF sampling start ---");
    @(negedge clk); enable=1;
    repeat(50) @(posedge clk); #1;
    check(puf_valid===1, "TC03_SAMPLE_valid=1 ");

    // TC04: output non-zero
    check(puf_response!==64'd0,
          "TC04_RESP_nonzero   ");

    // TC05: output not all-1
    check(puf_response!==64'hFFFFFFFFFFFFFFFF,
          "TC05_RESP_not_all1  ");

    // TC06: hamming weight 16~48
    hamming_w = popcount64(puf_response);
    $display("  Hamming weight = %0d / 64", hamming_w);
    check((hamming_w>=16)&&(hamming_w<=48),
          "TC06_HAMMING_16to48 ");

    // TC07: output stable
    snap1 = puf_response;
    repeat(10) @(posedge clk); #1;
    snap2 = puf_response;
    check(snap1===snap2, "TC07_STABLE_nodrift ");

    // TC08: enable=0 -> valid=0
    @(negedge clk); enable=0;
    repeat(3) @(posedge clk); #1;
    check(puf_valid===0, "TC08_DIS_valid=0    ");

    // TC09: re-enable
    @(negedge clk); enable=1;
    repeat(50) @(posedge clk); #1;
    check(puf_valid===1, "TC09_REEN_valid=1   ");

    // TC10: second output non-zero
    check(puf_response!==64'd0,
          "TC10_REEN_nonzero   ");

    // TC11: reset clears
    @(negedge clk); rst_n=0; enable=0;
    repeat(2) @(posedge clk);
    rst_n=1; @(posedge clk); #1;
    check(puf_valid===0,      "TC11_RST2_valid=0   ");
    check(puf_response===64'd0,"TC11_RST2_resp=0    ");

    $display("=========================================");
    $display("  PASS: %0d | FAIL: %0d", pass_cnt, fail_cnt);
    $display("  Hamming: %0d/64", hamming_w);
    if (fail_cnt==0)
        $display("  ALL PASS - ro_puf_top ready");
    else
        $display("  FAILED - fix RTL");
    $display("=========================================");
    $finish;
end

initial begin #100000; $display("[TIMEOUT]"); $finish; end
endmodule
