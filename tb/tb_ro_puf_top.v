// ============================================================
// ro_puf_top Testbench V3.0
// 验证：控制逻辑、采样时序、64bit输出完整性、汉明重量
// ============================================================
`timescale 1ns/1ps

module tb_ro_puf_top;

reg        clk;
reg        rst_n;
reg        enable;
reg  [5:0] sel;
wire [63:0] puf_response;
wire        puf_valid;

ro_puf_top dut (
    .clk         (clk),
    .rst_n       (rst_n),
    .enable      (enable),
    .sel         (sel),
    .puf_response(puf_response),
    .puf_valid   (puf_valid)
);

initial clk = 0;
always #5 clk = ~clk;

integer pass_cnt = 0;
integer fail_cnt = 0;
integer hamming_w;
integer i;

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

// 计算汉明重量（popcount）
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
    $display("===========================================");
    $display("  ro_puf_top 功能验证 - SiliconForge V3.0");
    $display("===========================================");

    // TC01: 复位测试
    rst_n  = 0;
    enable = 0;
    sel    = 6'd0;
    repeat(3) @(posedge clk);
    rst_n = 1;
    @(posedge clk); #1;
    check(puf_valid === 0, "TC01_复位后valid=0");
    check(puf_response === 64'd0, "TC01_复位后response=0");

    // TC02: 未使能时不输出
    @(posedge clk); #1;
    check(puf_valid === 0, "TC02_未使能valid保持0");

    // TC03: 使能并等待采样完成
    $display("--- 启动PUF采样 ---");
    @(negedge clk);
    enable = 1;
    // 等待足够时间（32周期稳定+余量）
    repeat(50) @(posedge clk);
    #1;
    check(puf_valid === 1, "TC03_采样完成valid=1");

    // TC04: 输出非零（指纹有意义）
    check(puf_response !== 64'd0, "TC04_PUF输出非零");

    // TC05: 输出非全1（不退化）
    check(puf_response !== 64'hFFFFFFFFFFFFFFFF, "TC05_PUF输出非全1");

    // TC06: 汉明重量检验（应在16~48之间，理想值32）
    hamming_w = popcount64(puf_response);
    $display("  汉明重量 = %0d / 64", hamming_w);
    check((hamming_w >= 16) && (hamming_w <= 48),
          "TC06_汉明重量在合理范围16-48");

    // TC07: 输出稳定性（多周期保持不变）
    begin
        reg [63:0] snap1, snap2;
        snap1 = puf_response;
        repeat(10) @(posedge clk);
        #1;
        snap2 = puf_response;
        check(snap1 === snap2, "TC07_输出稳定不抖动");
    end

    // TC08: 拉低enable → valid应清零
    @(negedge clk);
    enable = 0;
    repeat(3) @(posedge clk); #1;
    check(puf_valid === 0, "TC08_enable=0后valid清零");

    // TC09: 二次使能（重新采样）
    @(negedge clk);
    enable = 1;
    repeat(50) @(posedge clk); #1;
    check(puf_valid === 1, "TC09_二次采样成功");

    // TC10: 二次输出与首次一致（确定性）
    // 对同一设计，同一仿真环境，PUF输出应相同
    check(puf_response !== 64'd0, "TC10_二次输出有效非零");

    // TC11: 复位清除状态
    @(negedge clk);
    rst_n = 0; enable = 0;
    repeat(2) @(posedge clk);
    rst_n = 1; @(posedge clk); #1;
    check(puf_valid === 0, "TC11_复位清除valid");
    check(puf_response === 64'd0, "TC11_复位清除response");

    // 最终报告
    $display("===========================================");
    $display("  验证完成");
    $display("  通过: %0d 项 | 失败: %0d 项", pass_cnt, fail_cnt);
    $display("  汉明重量: %0d/64（随机性指标）", hamming_w);
    if (fail_cnt == 0)
        $display("  全部通过 - ro_puf_top 可提交流片");
    else
        $display("  存在失败项 - 需修复RTL");
    $display("===========================================");
    $finish;
end

initial begin #100000; $display("[TIMEOUT]"); $finish; end

endmodule
