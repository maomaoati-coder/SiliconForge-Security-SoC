// ============================================================
// RO-PUF — SiliconForge Security SoC V3.0
// 64路环形振荡器，生成64bit芯片唯一物理指纹
// ⚠️ 仿真版：RO频率差异通过参数延迟模拟
// ============================================================
module ro_puf_top (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        enable,       // PUF采样使能
    input  wire [5:0]  sel,          // 选择哪一对RO（0-63）
    output reg  [63:0] puf_response, // 64bit指纹输出
    output reg         puf_valid     // 指纹有效标志
);

// ============================================================
// 仿真模型：用计数器差值模拟RO频率差
// 真实芯片：RO频率差由工艺偏差决定（不可克隆）
// ============================================================

// 64对"虚拟RO"：用参数差值代表频率快慢
// 奇数对：A快于B → 输出1；偶数对：B快于A → 输出0
// 此模式保证汉明重量≈32（均匀随机性）
function [63:0] puf_model;
    input dummy;
    integer i;
    begin
        for (i = 0; i < 64; i = i + 1) begin
            // 奇偶交替+高位扰动，模拟真实PUF分布
            puf_model[i] = (i % 2 == 1) ^ (i[3] & i[1]);
        end
    end
endfunction

// 采样状态机
localparam PUF_IDLE    = 2'd0;
localparam PUF_SAMPLE  = 2'd1;
localparam PUF_DONE    = 2'd2;

reg [1:0]  puf_state;
reg [7:0]  sample_cnt;   // 采样等待计数（稳定时间）
reg [63:0] puf_raw;      // 原始PUF输出

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        puf_state    <= PUF_IDLE;
        puf_response <= 64'd0;
        puf_valid    <= 1'b0;
        sample_cnt   <= 8'd0;
        puf_raw      <= 64'd0;
    end else begin
        case (puf_state)
            PUF_IDLE: begin
                puf_valid <= 1'b0;
                if (enable) begin
                    puf_state  <= PUF_SAMPLE;
                    sample_cnt <= 8'd0;
                    puf_raw    <= puf_model(1'b0);  // 调用模型
                end
            end

            PUF_SAMPLE: begin
                // 等待32周期稳定（模拟RO计数窗口）
                if (sample_cnt < 8'd31) begin
                    sample_cnt <= sample_cnt + 1;
                end else begin
                    puf_state <= PUF_DONE;
                end
            end

            PUF_DONE: begin
                puf_response <= puf_raw;
                puf_valid    <= 1'b1;
                if (!enable) begin
                    puf_state <= PUF_IDLE;
                    puf_valid <= 1'b0;
                end
            end

            default: puf_state <= PUF_IDLE;
        endcase
    end
end

endmodule
