`timescale 1ns/1ps

module tb_anomaly_fsm;

reg        clk;
reg        rst_n;
reg [7:0]  cmd_in;
reg        cmd_valid;
wire       alert;
wire       lock;
wire [2:0] state_out;

anomaly_fsm dut (
    .clk      (clk),
    .rst_n    (rst_n),
    .cmd_in   (cmd_in),
    .cmd_valid(cmd_valid),
    .alert    (alert),
    .lock     (lock),
    .state_out(state_out)
);

// 时钟
initial clk = 0;
always #5 clk = ~clk;

integer pass_cnt;
integer fail_cnt;

// ---- 任务：发送指令 ----
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

// ---- 任务：检查输出（ASCII标签，≤8字符）----
task check;
    input       exp_alert;
    input       exp_lock;
    input [63:0] label;
    begin
        if (alert === exp_alert && lock === exp_lock) begin
            $display("[PASS] %s | alert=%b lock=%b", label, alert, lock);
            pass_cnt = pass_cnt + 1;
        end else begin
            $display("[FAIL] %s | exp a=%b l=%b | got a=%b l=%b",
                     label, exp_alert, exp_lock, alert, lock);
            fail_cnt = fail_cnt + 1;
        end
    end
endtask

// ---- 主流程 ----
initial begin
    // EPWave波形输出
    $dumpfile("dump.vcd");
    $dumpvars(0, tb_anomaly_fsm);

    pass_cnt = 0;
    fail_cnt = 0;

    $display("=========================================");
    $display("  anomaly_fsm Verification - SF V2.0");
    $display("=========================================");

    // TC01: 复位
    rst_n     = 0;
    cmd_in    = 8'h00;
    cmd_valid = 0;
    repeat(3) @(posedge clk);
    rst_n = 1;
    @(posedge clk); #1;
    check(0, 0, "TC01_RST");

    // TC02: 正常指令
    send_cmd(8'h10);
    @(posedge clk); #1;
    check(0, 0, "TC02_NRM1");
    send_cmd(8'h20);
    @(posedge clk); #1;
    check(0, 0, "TC02_NRM2");

    // TC03: cmd_valid拉低回IDLE
    @(negedge clk);
    cmd_valid = 0;
    repeat(2) @(posedge clk); #1;
    check(0, 0, "TC03_IDLE");

    // TC04/05: 非法指令→DETECT→ALERT
    $display("--- Trigger anomaly sequence ---");
    send_cmd(8'hFF);
    @(posedge clk); #1;
    send_cmd(8'hFF);
    @(posedge clk); #1;
    send_cmd(8'hFF);
    @(posedge clk); #1;
    check(1, 0, "TC05_ALERT");

    // TC06: 特权指令
    send_cmd(8'hAA);
    @(posedge clk); #1;
    send_cmd(8'hAA);
    @(posedge clk); #1;
    send_cmd(8'hAA);
    @(posedge clk); #1;

    // TC07: 持续非法→LOCK
    send_cmd(8'h55);
    send_cmd(8'hFF);
    send_cmd(8'hAA);
    repeat(5) begin
        send_cmd(8'hFF);
        @(posedge clk); #1;
    end
    @(posedge clk); #1;
    check(1, 1, "TC07_LOCK");

    // TC08: 锁定状态保持
    send_cmd(8'h00);
    @(posedge clk); #1;
    check(1, 1, "TC08_LCK1");
    send_cmd(8'h10);
    @(posedge clk); #1;
    check(1, 1, "TC08_LCK2");

    // TC09: 硬件复位解锁
    @(negedge clk);
    rst_n = 0;
    repeat(2) @(posedge clk);
    rst_n = 1;
    @(posedge clk); #1;
    check(0, 0, "TC09_UNLOCK");

    // TC10: 溢出指令
    send_cmd(8'h55);
    @(posedge clk); #1;
    send_cmd(8'h55);
    @(posedge clk); #1;
    $display("--- TC10 overflow sent ---");

    // TC11: 复位稳定
    @(negedge clk);
    rst_n = 0;
    @(posedge clk);
    rst_n = 1;
    @(posedge clk); #1;
    check(0, 0, "TC11_STABLE");

    // 报告
    $display("=========================================");
    $display("  PASS: %0d", pass_cnt);
    $display("  FAIL: %0d", fail_cnt);
    if (fail_cnt == 0)
        $display("  ALL PASS - Ready for tapeout");
    else
        $display("  FAILED - Fix RTL");
    $display("=========================================");
    $finish;
end

// 超时保护
initial begin
    #50000;
    $display("[TIMEOUT]");
    $finish;
end

endmodule
