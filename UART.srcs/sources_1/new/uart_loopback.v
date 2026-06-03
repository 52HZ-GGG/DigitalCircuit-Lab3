module uart_loopback #(
    parameter SYS_FREQ = 100_000_000
)(
    input Clock,
    input Reset,        
    input [3:0] freq_ctrl,
    output TxD,
    input RxD,
    output [15:0] LEDS        // 调试LED: [15:8]=收到的原始数据, [7:0]=转换后的数据
);

wire Din_Ready, Dout_Valid;
wire [7:0] Dout;
reg [7:0] Din;
reg Din_Valid, Dout_Ready;

// 接收器输出（原始数据）
reg latched;
reg [7:0] latched_data;
wire [7:0] converted_data;  // 组合逻辑：实时大小写转换结果

// 接收器已修复，Dout直接包含正确数据

reg  state;
parameter Receive = 1'b0,
            Transmit = 1'b1;


UART #(.SYS_FREQ(SYS_FREQ))
    uart (
    .Clock(Clock),
    .Reset(Reset),
    .Baud(),              //未使用
    .Baud16(),            //未使�?
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



//状态机设计
always @(posedge Reset or posedge Clock) begin
    if(Reset) begin
        state <= Receive;
    end else begin
        case (state)
            Receive: if(Dout_Valid) state <= Transmit;
                else state <= Receive;
            Transmit: if(Din_Ready && latched) state <= Receive;
                else state <= Transmit;
            default: state <= Receive;
        endcase
    end
end

//latched信号控制
always @(posedge Clock or posedge Reset) begin
    if(Reset) begin
        latched <= 0;
    end else case (state)
        Receive: begin
            latched <= 0;
        end
        Transmit: begin
            if(latched) begin
                latched <= 1;
            end else if(!Din_Ready) latched <= 1;  // 发射器接手后置1
        end
        default: begin
            latched <= 0;
        end
    endcase
end

//握手机制
always @(posedge Clock or posedge Reset) begin
    if(Reset) begin
        Din_Valid <= 1'b0;
        Dout_Ready <= 1'b0;
    end else case (state)
        Receive: begin
            Din_Valid <= 1'b0;
            Dout_Ready <= 1'b0;
        end
        Transmit: begin
            if(latched) begin
                Din_Valid <= 1'b0;
                Dout_Ready <= 1'b1;
            end else if(Din_Ready) begin
                Din_Valid <= 1'b1;
                Dout_Ready <= 1'b0;
            end
        end
        default: begin
            Din_Valid <= 1'b0;
            Dout_Ready <= 1'b0;
        end
    endcase
end



//数据处理
always @(posedge Clock or posedge Reset) begin
    if(Reset) begin
        Din <= 8'b0;
        latched_data <= 8'b0;
    end else case (state)
        Receive: begin
            Din <= 8'b0;
            if(Dout_Valid) latched_data <= Dout;
        end
        Transmit: begin
            if(latched_data <= 8'b01111010 && latched_data >= 8'b01100001) begin
                Din <= latched_data - 32;
            end else if(latched_data <= 8'b01011010 && latched_data >= 8'b01000001) begin
                Din <= latched_data + 32;
            end else Din <= latched_data;
        end
        default: begin
            Din <= 8'b0;
            if(Dout_Valid) latched_data <= Dout;
        end
    endcase
end

// 组合逻辑：实时大小写转换（与数据处理逻辑一致，但不依赖状态机）
assign converted_data = (latched_data <= 8'h7A && latched_data >= 8'h61) ? latched_data - 8'd32 :
                        (latched_data <= 8'h5A && latched_data >= 8'h41) ? latched_data + 8'd32 :
                        latched_data;

// LED输出：始终常亮
assign LEDS[15:8] = latched_data;    // LD15~LD8: 收到的原始数据
assign LEDS[7:0]  = converted_data;  // LD7~LD0:  转换后的数据
endmodule
