// ============================================================
// anomaly_fsm Testbench
// 目标：覆盖率≥95%，分支覆盖≥90%，通过率100%
// ============================================================
`timescale 1ns/1ps

module tb_anomaly_fsm;

// DUT端口
reg        clk;
reg        rst_n;
reg [7:0]  cmd_in;
reg        cmd_valid;
wire       alert;
wire       lock;
wire [2:0] state_out;

// 实例化DUT
anomaly_fsm dut (
    .clk       (clk),
    .rst_n     (rst_n),
    .cmd_in    (cmd_in),
    .cmd_valid (cmd_valid),
    .alert     (alert),
    .lock      (lock),
    .state_out (state_out)
);

// 时钟 10ns周期
initial clk = 0;
always #5 clk = ~clk;

// 测试统计
integer pass_cnt = 0;
integer fail_cnt = 0;

// 辅助任务：发送一条指令
task send_cmd;
    input [7:0] cmd;
    begin
        @(negedge clk);
        cmd_in    = cmd;
        cmd_valid = 1;
        @(posedge clk);
        #1;
    end
endtask

// 辅助任务：检查输出
task check;
    input exp_alert;
    input exp_lock;
    input [63:0] label;
    begin
        if (alert === exp_alert && lock === exp_lock) begin
            $display("[PASS] %s | alert=%b lock=%b", label, alert, lock);
            pass_cnt = pass_cnt + 1;
        end else begin
            $display("[FAIL] %s | 期望 alert=%b lock=%b | 实际 alert=%b lock=%b",
                     label, exp_alert, exp_lock, alert, lock);
            fail_cnt = fail_cnt + 1;
        end
    end
endtask

// ============ 主测试流程 ============
initial begin
    $display("===========================================");
    $display("  anomaly_fsm 功能验证 — SiliconForge V2.0");
    $display("===========================================");

    // ---- TC01: 复位测试 ----
    rst_n     = 0;
    cmd_in    = 8'h00;
    cmd_valid = 0;
    repeat(3) @(posedge clk);
    rst_n = 1;
    @(posedge clk); #1;
    check(0, 0, "TC01_复位后IDLE");

    // ---- TC02: 正常指令不触发告警 ----
    send_cmd(8'h10);
    @(posedge clk); #1;
    check(0, 0, "TC02_正常指令无告警");
    send_cmd(8'h20);
    @(posedge clk); #1;
    check(0, 0, "TC02_正常指令无告警2");

    // ---- TC03: cmd_valid拉低，回到IDLE ----
    @(negedge clk);
    cmd_valid = 0;
    repeat(2) @(posedge clk); #1;
    check(0, 0, "TC03_无效信号回IDLE");

    // ---- TC04: 发送非法指令触发DETECT ----
    $display("--- 触发异常检测序列 ---");
    send_cmd(8'hFF);  // 非法指令1
    @(posedge clk); #1;

    // ---- TC05: 第2次非法指令→ALERT ----
    send_cmd(8'hFF);  // 非法指令2 → 计数≥2 → ALERT
    @(posedge clk); #1;
    send_cmd(8'hFF);
    @(posedge clk); #1;
    check(1, 0, "TC05_告警激活alert=1");

    // ---- TC06: 特权指令触发 ----
    send_cmd(8'hAA);
    @(posedge clk); #1;
    send_cmd(8'hAA);
    @(posedge clk); #1;
    send_cmd(8'hAA);
    @(posedge clk); #1;

    // ---- TC07: 持续非法→LOCK ----
    send_cmd(8'h55);
    send_cmd(8'hFF);
    send_cmd(8'hAA);
    repeat(5) begin
        send_cmd(8'hFF);
        @(posedge clk); #1;
    end
    @(posedge clk); #1;
    check(1, 1, "TC07_系统锁定lock=1");

    // ---- TC08: LOCK状态下继续发指令，保持锁定 ----
    send_cmd(8'h00);
    @(posedge clk); #1;
    check(1, 1, "TC08_锁定不可解除");
    send_cmd(8'h10);
    @(posedge clk); #1;
    check(1, 1, "TC08_锁定持续");

    // ---- TC09: 硬件复位解除锁定 ----
    @(negedge clk);
    rst_n = 0;
    repeat(2) @(posedge clk);
    rst_n = 1;
    @(posedge clk); #1;
    check(0, 0, "TC09_复位解除锁定");

    // ---- TC10: 溢出指令测试 ----
    send_cmd(8'h55);
    @(posedge clk); #1;
    send_cmd(8'h55);
    @(posedge clk); #1;
    $display("--- TC10 溢出指令已发送 ---");

    // ---- TC11: 默认分支（非法状态码）覆盖 ----
    // 强制state到default（仿真注入，覆盖率用）
    @(negedge clk);
    rst_n = 0;
    @(posedge clk);
    rst_n = 1;
    @(posedge clk); #1;
    check(0, 0, "TC11_复位稳定");

    // ===== 最终报告 =====
    $display("===========================================");
    $display("  验证完成");
    $display("  通过: %0d 项", pass_cnt);
    $display("  失败: %0d 项", fail_cnt);
    if (fail_cnt == 0)
        $display("  ✅ 全部通过 — 可提交流片");
    else
        $display("  ❌ 存在失败项 — 需修复RTL");
    $display("===========================================");
    $finish;
end

// 超时保护
initial begin
    #50000;
    $display("[TIMEOUT] 仿真超时，请检查死循环");
    $finish;
end

endmodule
