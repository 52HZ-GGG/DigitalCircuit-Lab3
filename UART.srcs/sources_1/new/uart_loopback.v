module uart_loopback #(
    parameter SYS_FREQ = 100_000_000
)(
    input Clock,
    input Reset,
    input [3:0] freq_ctrl,
    output TxD,
    input RxD,
    output [15:0] LEDS
);

// UART 接口信号
wire Din_Ready, Dout_Valid;
wire [7:0] Dout;
reg [7:0] Din;
reg Din_Valid, Dout_Ready;

// FIFO 信号
wire [7:0] fifo_dout;
wire fifo_full, fifo_empty;
wire [4:0] fifo_data_count;
wire fifo_wr_en;
reg fifo_rd_en;

// 数据通路
reg latched;
reg [7:0] latched_data;
wire [7:0] converted_data;

// 四状态 FSM
reg [1:0] state;
parameter Receive  = 2'd0,
            RdEn    = 2'd1,
            RdData  = 2'd2,
            Transmit = 2'd3;

// ==================== UART 实例化 ====================
UART #(.SYS_FREQ(SYS_FREQ))
    uart (
    .Clock(Clock),
    .Reset(Reset),
    .Baud(),
    .Baud16(),
    .Din(Din),
    .Dout(Dout),
    .Din_Valid(Din_Valid),
    .Dout_Ready(Dout_Ready),
    .TxD(TxD),
    .RxD(RxD),
    .Din_Ready(Din_Ready),
    .Dout_Valid(Dout_Valid),
    .freq_ctrl(freq_ctrl)
);

// ==================== Dout_Valid 上升沿检测 ====================
// Dout_Valid 是 Baud16 时钟域信号。
// 用上升沿检测确保每个字节只写入 FIFO 一次。
// Valid 持续多个 Baud16 周期（直到 Ready 清除），所以上升沿可靠。
reg Dout_Valid_prev;
always @(posedge Clock or posedge Reset) begin
    if (Reset)
        Dout_Valid_prev <= 1'b0;
    else
        Dout_Valid_prev <= Dout_Valid;
end
wire Dout_Valid_rising = Dout_Valid && !Dout_Valid_prev;

// ==================== RX FIFO 实例化 ====================
assign fifo_wr_en = Dout_Valid_rising && !fifo_full;

uart_fifo #(
    .DATA_WIDTH(8),
    .ADDR_WIDTH(4)
) rx_fifo (
    .clk(Clock),
    .rst_n(~Reset),
    .din(Dout),
    .wr_en(fifo_wr_en),
    .rd_en(fifo_rd_en),
    .dout(fifo_dout),
    .full(fifo_full),
    .empty(fifo_empty),
    .data_count(fifo_data_count)
);

// ==================== Dout_Ready 脉冲 ====================
// wr_en 在 Dout_Valid_rising 拍写入 FIFO（组合逻辑，同一拍生效）
// Dout_Ready 在下一拍通知接收器清除 Valid
// 这样 FIFO 写入发生在接收器清除 Valid 之前
reg fifo_wr_en_prev;
always @(posedge Clock or posedge Reset) begin
    if (Reset)
        fifo_wr_en_prev <= 1'b0;
    else
        fifo_wr_en_prev <= fifo_wr_en;
end

// ==================== 状态机 ====================
always @(posedge Clock or posedge Reset) begin
    if (Reset)
        state <= Receive;
    else case (state)
        Receive:  if (!fifo_empty) state <= RdEn;
        RdEn:     state <= RdData;
        RdData:   state <= Transmit;
        Transmit: if (Din_Ready && latched) state <= Receive;
        default:  state <= Receive;
    endcase
end

// ==================== FIFO 读使能 ====================
always @(posedge Clock or posedge Reset) begin
    if (Reset)
        fifo_rd_en <= 1'b0;
    else
        fifo_rd_en <= (state == RdEn) ? 1'b1 : 1'b0;
end

// ==================== latched 信号控制 ====================
always @(posedge Clock or posedge Reset) begin
    if (Reset)
        latched <= 0;
    else case (state)
        Receive, RdEn, RdData: latched <= 0;
        Transmit: begin
            if (latched) latched <= 1;
            else if (!Din_Ready) latched <= 1;
        end
        default: latched <= 0;
    endcase
end

// ==================== 握手机制 ====================
always @(posedge Clock or posedge Reset) begin
    if (Reset) begin
        Din_Valid <= 1'b0;
        Dout_Ready <= 1'b0;
    end else begin
        // Dout_Ready: FIFO 写入后一拍脉冲，通知接收器清除 Valid
        // 不在 Receive 状态持续断言，避免在数据接收期间清除 Valid
        Dout_Ready <= fifo_wr_en_prev;
        // Din_Valid: Transmit 状态的握手
        case (state)
            Transmit: begin
                if (latched)
                    Din_Valid <= 1'b0;
                else if (Din_Ready)
                    Din_Valid <= 1'b1;
                else
                    Din_Valid <= 1'b0;
            end
            default: Din_Valid <= 1'b0;
        endcase
    end
end

// ==================== 数据处理 ====================
always @(posedge Clock or posedge Reset) begin
    if (Reset) begin
        Din <= 8'b0;
        latched_data <= 8'b0;
    end else case (state)
        Receive, RdEn, RdData: Din <= 8'b0;
        Transmit: begin
            latched_data <= fifo_dout;
            if (fifo_dout >= 8'h61 && fifo_dout <= 8'h7A)
                Din <= fifo_dout - 8'd32;
            else if (fifo_dout >= 8'h41 && fifo_dout <= 8'h5A)
                Din <= fifo_dout + 8'd32;
            else
                Din <= fifo_dout;
        end
        default: Din <= 8'b0;
    endcase
end

// 组合逻辑：实时大小写转换
assign converted_data = (latched_data >= 8'h61 && latched_data <= 8'h7A) ? latched_data - 8'd32 :
                        (latched_data >= 8'h41 && latched_data <= 8'h5A) ? latched_data + 8'd32 :
                        latched_data;

// LED 输出
assign LEDS[15:8] = latched_data;
assign LEDS[7:0]  = converted_data;

endmodule
