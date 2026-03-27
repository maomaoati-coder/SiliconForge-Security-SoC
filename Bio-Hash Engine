// ============================================================
// Bio-Hash Engine — SiliconForge Security SoC V3.0
// ARX（Add-Rotate-XOR）哈希，128bit身份令牌 + Phys-XOR审计
// ============================================================
module bio_hash_top (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        start,          // 开始哈希运算
    input  wire [63:0] puf_data,       // 来自RO-PUF的64bit指纹
    input  wire [63:0] bio_data,       // 外部生物特征数据
    output reg  [127:0] token,         // 128bit身份令牌输出
    output reg  [63:0]  phys_xor,      // Phys-XOR审计链路
    output reg          hash_valid     // 运算完成标志
);

// ARX轮常数（固定，基于黄金比例派生）
localparam [31:0] RC0 = 32'h9e3779b9;
localparam [31:0] RC1 = 32'h6c62272e;
localparam [31:0] RC2 = 32'h07bb0142;
localparam [31:0] RC3 = 32'hcfbcd459;

// 旋转量
localparam ROT_A = 5'd13;
localparam ROT_B = 5'd17;
localparam ROT_C = 5'd21;

// 状态机
localparam H_IDLE    = 3'd0;
localparam H_INIT    = 3'd1;
localparam H_ROUND   = 3'd2;
localparam H_FINALIZE= 3'd3;
localparam H_DONE    = 3'd4;

reg [2:0]  h_state;
reg [3:0]  round_cnt;   // 最多8轮ARX

// 工作寄存器（128bit状态，拆成4×32bit）
reg [31:0] s0, s1, s2, s3;

// 32bit循环左移
function [31:0] rotl32;
    input [31:0] val;
    input [4:0]  amt;
    begin rotl32 = (val << amt) | (val >> (32 - amt)); end
endfunction

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        h_state   <= H_IDLE;
        round_cnt <= 4'd0;
        s0 <= 32'd0; s1 <= 32'd0;
        s2 <= 32'd0; s3 <= 32'd0;
        token     <= 128'd0;
        phys_xor  <= 64'd0;
        hash_valid<= 1'b0;
    end else begin
        case (h_state)

            H_IDLE: begin
                hash_valid <= 1'b0;
                if (start) h_state <= H_INIT;
            end

            H_INIT: begin
                // 用PUF+生物数据初始化状态
                s0 <= puf_data[63:32] ^ RC0;
                s1 <= puf_data[31:0]  ^ RC1;
                s2 <= bio_data[63:32] ^ RC2;
                s3 <= bio_data[31:0]  ^ RC3;
                round_cnt <= 4'd0;
                h_state   <= H_ROUND;
            end

            H_ROUND: begin
                // ARX轮函数：Add → Rotate → XOR
                // 第一步：加法混合
                s0 <= s0 + s1;
                s2 <= s2 + s3;
                // 第二步：旋转
                s1 <= rotl32(s1, ROT_A);
                s3 <= rotl32(s3, ROT_B);
                // 第三步：XOR
                s1 <= rotl32(s1, ROT_A) ^ (s0 + s1);
                s3 <= rotl32(s3, ROT_B) ^ (s2 + s3);
                // 交叉混合
                s0 <= s0 + s1 + RC0;
                s2 <= s2 + s3 + RC2;

                round_cnt <= round_cnt + 1;
                if (round_cnt >= 4'd7) h_state <= H_FINALIZE;
            end

            H_FINALIZE: begin
                // 生成128bit令牌
                token[127:96] <= s0 ^ RC1;
                token[95:64]  <= s1 ^ RC3;
                token[63:32]  <= s2 ^ RC0;
                token[31:0]   <= s3 ^ RC2;
                // Phys-XOR审计：令牌与PUF的关联审计值
                phys_xor <= {s0 ^ s2, s1 ^ s3} ^ puf_data;
                h_state  <= H_DONE;
            end

            H_DONE: begin
                hash_valid <= 1'b1;
                if (!start) begin
                    h_state    <= H_IDLE;
                    hash_valid <= 1'b0;
                end
            end

            default: h_state <= H_IDLE;
        endcase
    end
end

endmodule
