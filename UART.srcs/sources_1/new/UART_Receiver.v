`timescale 1ns / 1ps
// 接收器：Bclk16过采样，在bit中心采样
// 解决原始接收器因StartDetect延迟导致的采样偏移问题
module UART_Receiver (
    input BaudClock,      // Bclk16 = 16x baud rate（DDS精确生成）
    input Reset,
    input RxD,
    input Ready,
    output [7:0] Dout,
    output reg Valid,
    output reg RxParityErr
);

reg [3:0] bit_cnt;       // bit内计数 0~15（16个Bclk16=1个bit周期）
reg [3:0] Rcnt;          // 已收数据位 0~8
reg [7:0] Rreg;          // 接收寄存器
reg RparBit;             // 校验累积
reg RxD_prev;            // 用于下降沿检测
reg [1:0] state;         // 0=idle, 1=data, 2=parity, 3=stop

wire falling_edge = RxD_prev && !RxD;
wire bit_sample   = (bit_cnt == 4'd8);  // bit中心（第8个Bclk16）

initial begin Rreg=8'h00; state=0; end

always @(posedge BaudClock or posedge Reset) begin
    if (Reset) RxD_prev <= 1;
    else RxD_prev <= RxD;
end

// bit计数器：起始位下降沿时同步，之后每16个Bclk16=1个bit
always @(posedge BaudClock or posedge Reset) begin
    if (Reset)
        bit_cnt <= 0;
    else if (falling_edge && state==0)
        bit_cnt <= 0;  // 起始位下降沿：同步
    else if (bit_cnt == 4'd15)
        bit_cnt <= 0;
    else
        bit_cnt <= bit_cnt + 1;
end

// 主状态机 + 移位（合并，消除竞态）
always @(posedge BaudClock or posedge Reset) begin
    if (Reset) begin
        state <= 0;
        Rcnt <= 0;
        Rreg <= 0;
        RparBit <= 0;
        RxParityErr <= 0;
        Valid <= 0;
    end else begin
        // Valid由Ready清除
        if (Ready) Valid <= 0;

        if (bit_sample) begin  // 仅在bit中心操作
            case (state)
            0: begin // idle：bit_cnt==8时应处于起始位中心，确认RxD==0
                if (!RxD) begin
                    state <= 1;
                    Rcnt <= 0;
                    RparBit <= 0;
                    RxParityErr <= 0;
                end
            end

            1: begin // data：采集D0~D7
                Rreg <= {RxD, Rreg[7:1]};
                RparBit <= RparBit ^ RxD;
                if (Rcnt == 7) state <= 2;  // 下一个是校验位
                Rcnt <= Rcnt + 1;
            end

            2: begin // parity：检查校验位
                if (RxD != RparBit) RxParityErr <= 1;
                state <= 3;
            end

            3: begin // stop：输出数据
                Valid <= 1;
                state <= 0;
            end
            endcase
        end
    end
end

assign Dout = Rreg;

endmodule
