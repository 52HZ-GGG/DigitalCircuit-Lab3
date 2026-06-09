`timescale 1ns / 1ps
// 接收器：Bclk16过采样，在bit中心采样
// Valid 在 stop 状态自动清除，不需要外部 Ready 信号
module UART_Receiver (
    input BaudClock,      // Bclk16 = 16x baud rate
    input Reset,
    input RxD,
    input Ready,          // 保留接口兼容性，但不再用于清除 Valid
    output [7:0] Dout,
    output reg Valid,
    output reg RxParityErr
);

reg [3:0] bit_cnt;
reg [3:0] Rcnt;
reg [7:0] Rreg;
reg RparBit;
reg RxD_prev;
reg [1:0] state;         // 0=idle, 1=data, 2=parity, 3=stop

wire falling_edge = RxD_prev && !RxD;
wire bit_sample   = (bit_cnt == 4'd8);

initial begin Rreg=8'h00; state=0; end

always @(posedge BaudClock or posedge Reset) begin
    if (Reset) RxD_prev <= 1;
    else RxD_prev <= RxD;
end

// bit计数器
always @(posedge BaudClock or posedge Reset) begin
    if (Reset)
        bit_cnt <= 0;
    else if (falling_edge && state==0)
        bit_cnt <= 0;
    else if (bit_cnt == 4'd15)
        bit_cnt <= 0;
    else
        bit_cnt <= bit_cnt + 1;
end

// 主状态机
always @(posedge BaudClock or posedge Reset) begin
    if (Reset) begin
        state <= 0;
        Rcnt <= 0;
        Rreg <= 0;
        RparBit <= 0;
        RxParityErr <= 0;
        Valid <= 0;
    end else if (bit_sample) begin
        case (state)
        0: begin // idle
            Valid <= 0;  // 在 idle 状态清除 Valid
            if (!RxD) begin
                state <= 1;
                Rcnt <= 0;
                RparBit <= 0;
                RxParityErr <= 0;
            end
        end

        1: begin // data
            Rreg <= {RxD, Rreg[7:1]};
            RparBit <= RparBit ^ RxD;
            if (Rcnt == 7) state <= 2;
            Rcnt <= Rcnt + 1;
        end

        2: begin // parity
            if (RxD != RparBit) RxParityErr <= 1;
            state <= 3;
        end

        3: begin // stop
            Valid <= 1;   // 设置 Valid（仅持续一个 Baud16 周期）
            state <= 0;   // 立即回到 idle
        end
        endcase
    end
end

assign Dout = Rreg;

endmodule
