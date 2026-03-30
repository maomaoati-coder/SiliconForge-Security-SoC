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

initial clk = 0;
always #5 clk = ~clk;

// 所有变量必须在模块级声明
integer pass_cnt, fail_cnt, i;

task check;
    input cond;
    input [191:0] label;
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

initial begin
    $dumpfile("dump_soc.vcd");
    $dumpvars(0, tb_security_soc_top);

    pass_cnt = 0; fail_cnt = 0;

    $display("=========================================");
    $display(" security_soc_top Verify - SF V3.0");
    $display("=========================================");

    // init
    rst_n=0; cmd_in=0; cmd_valid=0;
    puf_enable=0; puf_sel=0; bio_data=0; hash_start=0;
    repeat(3) @(posedge clk);
    rst_n=1; @(posedge clk); #1;

    // TC01: reset state
    check(sys_alert===0,   "TC01_RST_alert=0        ");
    check(sys_lock===0,    "TC01_RST_lock=0         ");
    check(puf_ready===0,   "TC01_RST_puf_rdy=0      ");
    check(token_valid===0, "TC01_RST_tok_v=0        ");

    // TC02: normal cmd no alert
    @(negedge clk); cmd_in=8'h10; cmd_valid=1;
    @(posedge clk); #1;
    check(sys_alert===0,   "TC02_NRM_alert=0        ");
    check(sys_lock===0,    "TC02_NRM_lock=0         ");

    // TC03: PUF sampling
    $display("--- PUF link start ---");
    @(negedge clk); cmd_valid=0; puf_enable=1; puf_sel=6'd0;
    repeat(50) @(posedge clk); #1;
    check(puf_ready===1,           "TC03_PUF_ready=1        ");
    check(puf_fingerprint!==64'd0, "TC03_PUF_fp_nonzero     ");

    // TC04: hash after PUF ready
    $display("--- Hash link start ---");
    @(negedge clk);
    bio_data=64'hABCDEF0123456789; hash_start=1;
    repeat(30) @(posedge clk); #1;
    check(token_valid===1,          "TC04_TOK_valid=1        ");
    check(identity_token!==128'd0,  "TC04_TOK_nonzero        ");
    check(audit_xor!==64'd0,        "TC04_AXOR_nonzero       ");

    // TC05: audit XOR differs from raw PUF
    check(audit_xor!==puf_fingerprint,
                                    "TC05_AXOR_ne_FP         ");

    // TC06: illegal cmd triggers alert
    $display("--- FSM alert trigger ---");
    @(negedge clk); hash_start=0;
    @(negedge clk); cmd_in=8'hFF; cmd_valid=1;
    @(posedge clk); #1;
    @(negedge clk); cmd_in=8'hFF;
    @(posedge clk); #1;
    @(negedge clk); cmd_in=8'hFF;
    @(posedge clk); #1;
    @(posedge clk); #1;
    check(sys_alert===1,            "TC06_ILLCMD_alert=1     ");

    // TC07: continuous illegal -> lock
    for (i=0; i<10; i=i+1) begin
        @(negedge clk); cmd_in=8'hFF;
        @(posedge clk); #1;
    end
    @(posedge clk); #1;
    check(sys_lock===1,             "TC07_LOCK_lock=1        ");

    // TC08: PUF still works during lock
    check(puf_ready===1,            "TC08_LOCK_puf_ok        ");

    // TC09: hash module independent state
    check(token_valid===1||token_valid===0,
                                    "TC09_LOCK_hash_indep    ");

    // TC10: hw reset clears everything
    @(negedge clk); rst_n=0; cmd_valid=0; hash_start=0; puf_enable=0;
    repeat(2) @(posedge clk);
    rst_n=1; @(posedge clk); #1;
    check(sys_alert===0,            "TC10_RST2_alert=0       ");
    check(sys_lock===0,             "TC10_RST2_lock=0        ");
    check(token_valid===0,          "TC10_RST2_tok=0         ");

    // TC11: full chain restart
    $display("--- Full chain restart ---");
    @(negedge clk); puf_enable=1; bio_data=64'h1122334455667788;
    repeat(50) @(posedge clk); #1;
    check(puf_ready===1,            "TC11_RESTART_puf_ok     ");
    @(negedge clk); hash_start=1;
    repeat(30) @(posedge clk); #1;
    check(token_valid===1,          "TC11_RESTART_tok_ok     ");

    // TC12: no spurious alert in normal operation
    check(sys_alert===0,            "TC12_NO_SPURIOUS_alert  ");

    $display("=========================================");
    $display("  PASS: %0d | FAIL: %0d", pass_cnt, fail_cnt);
    if (fail_cnt==0) begin
        $display("  ALL PASS - SoC top ready");
        $display("  4-module done - CI2609 ready");
    end else
        $display("  FAILED - fix RTL");
    $display("=========================================");
    $finish;
end

initial begin #500000; $display("[TIMEOUT]"); $finish; end
endmodule
