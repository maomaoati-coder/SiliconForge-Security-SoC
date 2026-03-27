// ============================================================
// anomaly_fsm —SiliconForge Security SoC V3.0
// 6状态安全FSM，组合输出，零延迟
// ============================================================
module anomaly_fsm (
    input  wire        clk, rst_n,
    input  wire [7:0]  cmd_in,
    input  wire        cmd_valid,
    output wire        alert, lock,
    output wire [2:0]  state_out
);
localparam IDLE=3'd0,MONITOR=3'd1,DETECT=3'd2,ALERT_S=3'd3,LOCK_S=3'd4,RESET_S=3'd5;
localparam ILLEGAL_CMD=8'hFF,PRIV_CMD=8'hAA,OVERFLOW=8'h55;
localparam ALERT_THRESH=4'd3,LOCK_THRESH=4'd8;
reg [2:0] state; reg [3:0] anomaly_cnt;
wire is_illegal=(cmd_in==ILLEGAL_CMD||cmd_in==PRIV_CMD||cmd_in==OVERFLOW);
wire cmd_fire=cmd_valid&&is_illegal;
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin state<=IDLE; anomaly_cnt<=0; end
    else case(state)
        IDLE:    if(cmd_valid) state<=MONITOR;
        MONITOR: if(!cmd_valid) state<=IDLE;
                 else if(cmd_fire) begin anomaly_cnt<=anomaly_cnt+1; state<=DETECT; end
        DETECT:  if(anomaly_cnt>=LOCK_THRESH) state<=LOCK_S;
                 else if(anomaly_cnt>=ALERT_THRESH) state<=ALERT_S;
                 else state<=MONITOR;
        ALERT_S: if(cmd_fire) begin anomaly_cnt<=anomaly_cnt+1; state<=DETECT; end
        LOCK_S:  ;
        RESET_S: state<=IDLE;
        default: state<=IDLE;
    endcase
end
assign alert=(state==ALERT_S)||(state==LOCK_S)||(state==DETECT&&anomaly_cnt>=ALERT_THRESH);
assign lock=(state==LOCK_S);
assign state_out=state;
endmodule

// ============================================================
// ro_puf_top — V3.0
// ============================================================
module ro_puf_top (
    input  wire        clk, rst_n, enable,
    input  wire [5:0]  sel,
    output reg  [63:0] puf_response,
    output reg         puf_valid
);
function [63:0] puf_model; input dummy; integer i;
    begin for(i=0;i<64;i=i+1) puf_model[i]=(i%2==1)^(i[3]&i[1]); end
endfunction
localparam PUF_IDLE=2'd0,PUF_SAMPLE=2'd1,PUF_DONE=2'd2;
reg [1:0] puf_state; reg [7:0] sample_cnt; reg [63:0] puf_raw;
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin puf_state<=PUF_IDLE; puf_response<=0; puf_valid<=0; sample_cnt<=0; puf_raw<=0; end
    else case(puf_state)
        PUF_IDLE:   begin puf_valid<=0; if(enable) begin puf_state<=PUF_SAMPLE; sample_cnt<=0; puf_raw<=puf_model(1'b0); end end
        PUF_SAMPLE: if(sample_cnt<8'd31) sample_cnt<=sample_cnt+1; else puf_state<=PUF_DONE;
        PUF_DONE:   begin puf_response<=puf_raw; puf_valid<=1; if(!enable) begin puf_state<=PUF_IDLE; puf_valid<=0; end end
        default:    puf_state<=PUF_IDLE;
    endcase
end
endmodule

// ============================================================
// bio_hash_top — V3.0
// ============================================================
module bio_hash_top (
    input  wire        clk, rst_n, start,
    input  wire [63:0] puf_data, bio_data,
    output reg  [127:0] token,
    output reg  [63:0]  phys_xor,
    output reg          hash_valid
);
localparam [31:0] RC0=32'h9e3779b9,RC1=32'h6c62272e,RC2=32'h07bb0142,RC3=32'hcfbcd459;
localparam ROT_A=5'd13,ROT_B=5'd17;
localparam H_IDLE=3'd0,H_INIT=3'd1,H_ROUND=3'd2,H_FINALIZE=3'd3,H_DONE=3'd4;
reg [2:0] h_state; reg [3:0] round_cnt;
reg [31:0] s0,s1,s2,s3;
function [31:0] rotl32; input [31:0] v; input [4:0] a;
    begin rotl32 = (v <<a) | (v >>(32 - a)); end endfunction
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin h_state<=H_IDLE; round_cnt<=0; s0<=0;s1<=0;s2<=0;s3<=0; token<=0; phys_xor<=0; hash_valid<=0; end
    else case(h_state)
        H_IDLE:     begin hash_valid<=0; if(start) h_state<=H_INIT; end
        H_INIT:     begin s0<=puf_data[63:32]^RC0; s1<=puf_data[31:0]^RC1;
                          s2<=bio_data[63:32]^RC2; s3<=bio_data[31:0]^RC3;
                          round_cnt<=0; h_state<=H_ROUND; end
        H_ROUND:    begin s0<=s0+s1+RC0; s2<=s2+s3+RC2;
                          s1<=rotl32(s1,ROT_A)^(s0+s1+RC0); s3<=rotl32(s3,ROT_B)^(s2+s3+RC2);
                          round_cnt<=round_cnt+1; if(round_cnt>=4'd7) h_state<=H_FINALIZE; end
        H_FINALIZE: begin token<={s0^RC1,s1^RC3,s2^RC0,s3^RC2};
                          phys_xor<={s0^s2,s1^s3}^puf_data; h_state<=H_DONE; end
        H_DONE:     begin hash_valid<=1; if(!start) begin h_state<=H_IDLE; hash_valid<=0; end end
        default:    h_state<=H_IDLE;
    endcase
end
endmodule

// ============================================================
// security_soc_top — SiliconForge Security SoC V3.0
// 顶层集成：三模块全链路整合
// ============================================================
module security_soc_top (
    input  wire        clk,
    input  wire        rst_n,
    // 外部命令接口（接anomaly_fsm）
    input  wire [7:0]  cmd_in,
    input  wire        cmd_valid,
    // PUF控制接口
    input  wire        puf_enable,
    input  wire [5:0]  puf_sel,
    // 生物特征数据接口
    input  wire [63:0] bio_data,
    input  wire        hash_start,
    // 输出接口
    output wire        sys_alert,      // 系统告警
    output wire        sys_lock,       // 系统锁定
    output wire [2:0]  fsm_state,      // FSM状态（调试）
    output wire [63:0] puf_fingerprint,// PUF指纹输出
    output wire        puf_ready,      // PUF就绪
    output wire [127:0] identity_token,// 128bit身份令牌
    output wire [63:0]  audit_xor,     // Phys-XOR审计值
    output wire         token_valid    // 令牌有效
);

// ── 内部连线 ──────────────────────────────
wire [63:0] puf_to_hash;   // PUF→Hash数据总线
wire        puf_valid_int;

// ── 模块实例化 ────────────────────────────
anomaly_fsm u_fsm (
    .clk       (clk),
    .rst_n     (rst_n),
    .cmd_in    (cmd_in),
    .cmd_valid (cmd_valid),
    .alert     (sys_alert),
    .lock      (sys_lock),
    .state_out (fsm_state)
);

ro_puf_top u_puf (
    .clk         (clk),
    .rst_n       (rst_n),
    .enable      (puf_enable),
    .sel         (puf_sel),
    .puf_response(puf_to_hash),
    .puf_valid   (puf_valid_int)
);

bio_hash_top u_hash (
    .clk       (clk),
    .rst_n     (rst_n),
    .start     (hash_start && puf_valid_int), // PUF就绪才能启动Hash
    .puf_data  (puf_to_hash),
    .bio_data  (bio_data),
    .token     (identity_token),
    .phys_xor  (audit_xor),
    .hash_valid(token_valid)
);

// PUF输出透传
assign puf_fingerprint = puf_to_hash;
assign puf_ready       = puf_valid_int;

endmodule
