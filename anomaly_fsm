// ============================================================
// 异常检测FSM — SiliconForge Security SoC V3.0
// 6状态安全状态机，实时拦截非法指令
// ============================================================
module anomaly_fsm (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [7:0]  cmd_in,       // 输入指令
    input  wire        cmd_valid,    // 指令有效
    output reg         alert,        // 异常告警
    output reg         lock,         // 系统锁定
    output reg  [2:0]  state_out     // 当前状态（调试）
);

// 状态定义
localparam IDLE    = 3'd0;
localparam MONITOR = 3'd1;
localparam DETECT  = 3'd2;
localparam ALERT_S = 3'd3;
localparam LOCK_S  = 3'd4;
localparam RESET_S = 3'd5;

// 非法指令阈值
localparam ILLEGAL_CMD = 8'hFF;  // 全1为非法
localparam PRIV_CMD    = 8'hAA;  // 特权指令
localparam OVERFLOW    = 8'h55;  // 溢出指令

reg [2:0] state, next_state;
reg [3:0] anomaly_cnt;  // 异常计数器

// 状态寄存器
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state       <= IDLE;
        anomaly_cnt <= 4'd0;
    end else begin
        state <= next_state;
        if (state == DETECT)
            anomaly_cnt <= anomaly_cnt + 1;
        else if (state == RESET_S)
            anomaly_cnt <= 4'd0;
    end
end

// 次态逻辑
always @(*) begin
    next_state = state;
    case (state)
        IDLE: begin
            if (cmd_valid)
                next_state = MONITOR;
        end
        MONITOR: begin
            if (!cmd_valid)
                next_state = IDLE;
            else if (cmd_in == ILLEGAL_CMD ||
                     cmd_in == PRIV_CMD   ||
                     cmd_in == OVERFLOW)
                next_state = DETECT;
        end
        DETECT: begin
            if (anomaly_cnt >= 4'd2)
                next_state = ALERT_S;
            else
                next_state = MONITOR;
        end
        ALERT_S: begin
            if (anomaly_cnt >= 4'd5)
                next_state = LOCK_S;
            else
                next_state = MONITOR;
        end
        LOCK_S: begin
            // 锁定状态，等待硬件复位
            next_state = LOCK_S;
        end
        RESET_S: begin
            next_state = IDLE;
        end
        default: next_state = IDLE;
    endcase
end

// 输出逻辑
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        alert     <= 1'b0;
        lock      <= 1'b0;
        state_out <= 3'd0;
    end else begin
        state_out <= next_state;
        case (next_state)
            IDLE:    begin alert <= 0; lock <= 0; end
            MONITOR: begin alert <= 0; lock <= 0; end
            DETECT:  begin alert <= 0; lock <= 0; end
            ALERT_S: begin alert <= 1; lock <= 0; end
            LOCK_S:  begin alert <= 1; lock <= 1; end
            RESET_S: begin alert <= 0; lock <= 0; end
            default: begin alert <= 0; lock <= 0; end
        endcase
    end
end

endmodule
