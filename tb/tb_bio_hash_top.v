// ============================================================
// bio_hash_top Testbench V3.0
// ============================================================
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

integer pass_cnt = 0, fail_cnt = 0;

task check;
    input cond;
    input [127:0] label;
    begin
        if (cond) begin
            $display("[PASS] %s", label);
            pass_cnt = pass_cnt + 1;
        end else begin
            $display("[FAIL] %s", label);
            fail_cnt = fail_cnt + 1;
        end
    end
endtask

task run_hash;
    input [63:0] puf, bio;
    begin
        @(negedge clk);
        puf_data = puf;
        bio_data = bio;
        start = 1;
        // 等待hash_valid（最多30周期：INIT+8轮ROUND+FINALIZE+DONE）
        repeat(30) begin
            @(posedge clk);
            if (hash_valid) disable run_hash;
        end
        #1;
    end
endtask

reg [127:0] token_snap1, token_snap2;
reg [63:0]  xor_snap1;

initial begin
    $display("===========================================");
    $display("  bio_hash_top 功能验证 - SiliconForge V3.0");
    $display("===========================================");

    // TC01: 复位
    rst_n=0; start=0; puf_data=64'd0; bio_data=64'd0;
    repeat(3) @(posedge clk);
    rst_n=1; @(posedge clk); #1;
    check(hash_valid===0, "TC01_复位后valid=0");
    check(token===128'd0, "TC01_复位后token=0");

    // TC02: 未触发start时不运算
    @(posedge clk); #1;
    check(hash_valid===0, "TC02_未start无输出");

    // TC03: 标准输入，完成运算
    $display("--- 运行ARX哈希 ---");
    run_hash(64'hDEADBEEFCAFEBABE, 64'h0123456789ABCDEF);
    check(hash_valid===1, "TC03_hash_valid=1");

    // TC04: 令牌非零
    check(token !== 128'd0, "TC04_token非零");

    // TC05: 令牌非全1（未退化）
    check(token !== 128'hFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF,
          "TC05_token非全1");

    // TC06: phys_xor非零
    check(phys_xor !== 64'd0, "TC06_phys_xor非零");

    // TC07: 保存结果，验证确定性（相同输入→相同输出）
    token_snap1 = token;
    xor_snap1   = phys_xor;

    // 拉低start，回IDLE
    @(negedge clk); start=0;
    repeat(3) @(posedge clk); #1;
    check(hash_valid===0, "TC07_start=0后valid清零");

    // TC08: 重新运算，结果一致
    run_hash(64'hDEADBEEFCAFEBABE, 64'h0123456789ABCDEF);
    token_snap2 = token;
    check(token_snap1 === token_snap2, "TC08_相同输入输出确定");

    // TC09: 不同输入 → 不同token（雪崩效应）
    @(negedge clk); start=0;
    repeat(2) @(posedge clk);
    run_hash(64'hFFFFFFFFFFFFFFFF, 64'h0000000000000000);
    check(token !== token_snap1, "TC09_不同输入产生不同token");

    // TC10: phys_xor与puf_data相关（非独立）
    check(phys_xor !== xor_snap1, "TC10_phys_xor随输入变化");

    // TC11: 全零输入仍产生有效输出
    @(negedge clk); start=0;
    repeat(2) @(posedge clk);
    run_hash(64'd0, 64'd0);
    check(hash_valid===1, "TC11_全零输入valid=1");
    check(token !== 128'd0, "TC11_全零输入token非零（RC扰动）");

    // TC12: 复位清除
    @(negedge clk); rst_n=0; start=0;
    repeat(2) @(posedge clk);
    rst_n=1; @(posedge clk); #1;
    check(hash_valid===0, "TC12_复位清除valid");
    check(token===128'd0, "TC12_复位清除token");

    $display("===========================================");
    $display("  验证完成");
    $display("  通过: %0d 项 | 失败: %0d 项", pass_cnt, fail_cnt);
    if (fail_cnt==0)
        $display("  全部通过 - bio_hash_top 可提交流片");
    else
        $display("  存在失败项 - 需修复RTL");
    $display("===========================================");
    $finish;
end

initial begin #200000; $display("[TIMEOUT]"); $finish; end

endmodule
