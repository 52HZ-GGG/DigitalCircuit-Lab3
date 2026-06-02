module UART_BaudGen #(
    parameter SYS_FREQ = 100_000_000
)(
    input Clock,          //system clock
    input Reset,          //system reset
    output reg Bclk16,    //Bclk16 = 16x Bclk
    output reg Bclk,          //baud rate clock
    input [3:0] freq_ctrl //4-bit DIP switch for baud rate selection
);
reg [11:0] Count;
reg [11:0] Division;
reg [3:0] BclkCount;

// 用组合逻辑（always @(*)）根据拨码开关选择分频系数
// 公式：Division = 100_000_000 / (波特率 × 16)
always @(*) begin
    case (freq_ctrl)
        4'b0000: Division = 12'd2604;  // 2400 bps
        4'b0001: Division = 12'd1302;  // 4800 bps
        4'b0010: Division = 12'd651;   // 9600 bps
        4'b0011: Division = 12'd326;   // 19200 bps
        4'b0100: Division = 12'd109;   // 57600 bps
        4'b0101: Division = 12'd54;    // 115200 bps（基础波特率）
        4'b0110: Division = 12'd27;    // 230400 bps
        4'b0111: Division = 12'd14;    // 460800 bps
        4'b1000: Division = 12'd7;     // 921600 bps
        default: Division = 12'd54;    // 默认115200
    endcase
end


// 生成16倍波特率时钟（脉冲方式，不是翻转）
always @(posedge Clock or posedge Reset) begin
    if(Reset) begin
        Count <= 12'b0;
        Bclk16 <= 1'b0;
    end else if(Count == Division - 1) begin
        Count <= 12'b0;
        Bclk16 <= 1'b1;   // 产生一个时钟周期的高脉冲
    end else begin
        Count <= Count + 1;
        Bclk16 <= 1'b0;
    end
end


//从16倍时钟中生成标准波特率时钟（脉冲方式）
always @(posedge Clock or posedge Reset) begin
    if(Reset) begin
        Bclk <= 1'b0;
        BclkCount <= 4'b0;
    end else if(Bclk16) begin
        if(BclkCount == 4'd15) begin
            BclkCount <= 4'b0;
            Bclk <= 1'b1;  // 产生一个时钟周期的高脉冲
        end else begin
            BclkCount <= BclkCount + 1;
            Bclk <= 1'b0;
        end
    end else begin
        Bclk <= 1'b0;
    end
end

endmodule
