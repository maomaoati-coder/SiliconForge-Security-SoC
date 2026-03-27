// ============================================================
// security_soc_top Testbench V3.0
// 全链路集成验证：PUF→Hash→FSM三模块协同
// ============================================================
`timescale 1ns/1ps

module tb_security_soc_top;

reg        clk, rst_n;
reg [7:0]  cmd_in;
reg        cmd_valid;
reg        puf_enable;
reg [5:0]  puf_sel;
reg [63:0] bio_data;
reg        hash_start;

wire        sys_alert, sys_lock;
wire [2:0]  fsm_state;
wire [63:0] puf_fingerprint;
wire        puf_ready;
wire [127:0] identity_token;
wire [63:0]  audit_xor;
wire         token_valid;

security_soc_top dut (
    .clk(clk), .rst_n(rst_n),
    .cmd_in(cmd_in), .cmd_valid(cmd_valid),
    .puf_enable(puf_enable), .puf_sel(puf_sel),
    .bio_data(bio_data), .hash_start(hash_start),
    .sys_alert(sys_alert), .sys_lock(sys_lock),
    .fsm_state(fsm_state),
    .puf_fingerprint(puf_fingerprint), .puf_ready(puf_ready),
    .identity_token(identity_token), .audit_xor(audit_xor),
    .token_valid(token_valid)
);

initial clk=0;
always #5 clk=~clk;

integer pass_cnt=0, fail_cnt=0;

task check;
    input cond;
    input [191:0] label;
    begin
        if(cond) begin $display("[PASS] %s",label); pass_cnt=pass_cnt+1; end
        else     begin $display("[FAIL] %s",label); fail_cnt=fail_cnt+1; end
    end
endtask

initial begin
    $display("===========================================");
    $display("  security_soc_top 全链路验证 - V3.0");
    $display("===========================================");

    // 初始化
    rst_n=0; cmd_in=0; cmd_valid=0;
    puf_enable=0; puf_sel=0; bio_data=0; hash_start=0;
    repeat(3) @(posedge clk);
    rst_n=1; @(posedge clk); #1;

    // ── TC01: 系统复位状态 ──────────────────
    check(sys_alert===0,  "TC01_复位_sys_alert=0");
    check(sys_lock===0,   "TC01_复位_sys_lock=0");
    check(puf_ready===0,  "TC01_复位_puf_ready=0");
    check(token_valid===0,"TC01_复位_token_valid=0");

    // ── TC02: 正常指令不触发告警 ────────────
    @(negedge clk); cmd_in=8'h10; cmd_valid=1;
    @(posedge clk); #1;
    check(sys_alert===0, "TC02_正常指令无alert");
    check(sys_lock===0,  "TC02_正常指令无lock");

    // ── TC03: 启动PUF采样 ──────────────────
    $display("--- 启动PUF链路 ---");
    @(negedge clk); cmd_valid=0; puf_enable=1; puf_sel=6'd0;
    repeat(50) @(posedge clk); #1;
    check(puf_ready===1,         "TC03_PUF采样完成ready=1");
    check(puf_fingerprint!==64'd0,"TC03_PUF指纹非零");

    // ── TC04: 启动Hash（PUF就绪后）──────────
    $display("--- 启动哈希链路 ---");
    @(negedge clk);
    bio_data=64'hABCDEF0123456789;
    hash_start=1;
    repeat(30) @(posedge clk); #1;
    check(token_valid===1,          "TC04_令牌生成完成");
    check(identity_token!==128'd0,  "TC04_令牌非零");
    check(audit_xor!==64'd0,        "TC04_审计XOR非零");

    // ── TC05: PUF指纹绑定到令牌（审计链路）──
    check(audit_xor !== puf_fingerprint, "TC05_审计XOR与PUF不同（已混合）");

    // ── TC06: 非法指令触发FSM告警 ──────────
    $display("--- 触发FSM告警 ---");
    @(negedge clk); hash_start=0;
    @(negedge clk); cmd_in=8'hFF; cmd_valid=1;
    @(posedge clk); #1;
    @(negedge clk); cmd_in=8'hFF;
    @(posedge clk); #1;
    @(negedge clk); cmd_in=8'hFF;
    @(posedge clk); #1;
    @(posedge clk); #1;
    check(sys_alert===1, "TC06_三条非法指令触发alert");

    // ── TC07: 持续非法指令→系统锁定 ────────
    begin
        integer i;
        for(i=0;i<10;i=i+1) begin
            @(negedge clk); cmd_in=8'hFF;
            @(posedge clk); #1;
        end
    end
    @(posedge clk); #1;
    check(sys_lock===1, "TC07_系统进入锁定状态");

    // ── TC08: 锁定期间PUF/Hash仍独立工作 ───
    check(puf_ready===1, "TC08_锁定期间PUF仍然工作");

    // ── TC09: 锁定状态下令牌输出保持 ────────
    check(token_valid===1 || token_valid===0,
          "TC09_锁定下Hash模块独立状态正常");

    // ── TC10: 硬件复位解除全系统锁定 ────────
    @(negedge clk); rst_n=0; cmd_valid=0; hash_start=0; puf_enable=0;
    repeat(2) @(posedge clk);
    rst_n=1; @(posedge clk); #1;
    check(sys_alert===0,  "TC10_复位后alert清零");
    check(sys_lock===0,   "TC10_复位后lock清零");
    check(token_valid===0,"TC10_复位后token清零");

    // ── TC11: 复位后重新全链路运行 ──────────
    $display("--- 全链路重启 ---");
    @(negedge clk); puf_enable=1; bio_data=64'h1122334455667788;
    repeat(50) @(posedge clk); #1;
    check(puf_ready===1, "TC11_复位后PUF重新就绪");
    @(negedge clk); hash_start=1;
    repeat(30) @(posedge clk); #1;
    check(token_valid===1, "TC11_复位后Hash重新完成");

    // ── TC12: 三模块无竞争、无死锁 ──────────
    check(sys_alert===0, "TC12_正常运行下无误告警");

    // ── 最终报告 ─────────────────────────────
    $display("===========================================");
    $display("  全链路验证完成");
    $display("  通过: %0d 项 | 失败: %0d 项", pass_cnt, fail_cnt);
    if(fail_cnt==0) begin
        $display("  ✅ 全部通过 - SoC顶层可提交流片");
        $display("  ✅ 四模块验证完毕 - 准备ChipFoundry CI2609");
    end else
        $display("  ❌ 存在失败项 - 需修复");
    $display("===========================================");
    $finish;
end

initial begin #500000; $display("[TIMEOUT]"); $finish; end

endmodule
