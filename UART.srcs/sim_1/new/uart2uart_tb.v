`timescale 1ns / 1ps
module uart2uart_tb();

reg clk;
reg rst;
reg [7:0] Din_1, Din_2;
reg Din_Valid_1, Dout_Ready_1, Din_Valid_2, Dout_Ready_2;
reg [3:0] freq_ctrl_1, freq_ctrl_2;
wire TxD_1, TxD_2;
wire RxD_1, RxD_2;
wire Din_Ready_1, Dout_Valid_1, Din_Ready_2, Dout_Valid_2;
wire [7:0] Dout_1, Dout_2;
wire Baud_1, Baud16_1, Baud_2, Baud16_2;

UART #(.SYS_FREQ(100_000_000)) UART1 (
    .Clock(clk),
    .Reset(rst),
    .Baud(Baud_1),
    .Baud16(Baud16_1),
    .Din(Din_1),
    .Dout(Dout_1),
    .Din_Valid(Din_Valid_1),
    .Dout_Ready(Dout_Ready_1),
    .TxD(TxD_1),
    .RxD(RxD_1),
    .Din_Ready(Din_Ready_1),
    .Dout_Valid(Dout_Valid_1),
    .freq_ctrl(freq_ctrl_1)
);

UART #(.SYS_FREQ(100_000_000)) UART2 (
    .Clock(clk),
    .Reset(rst),
    .Baud(Baud_2),
    .Baud16(Baud16_2),
    .Din(Din_2),
    .Dout(Dout_2),
    .Din_Valid(Din_Valid_2),
    .Dout_Ready(Dout_Ready_2),
    .TxD(TxD_2),
    .RxD(RxD_2),
    .Din_Ready(Din_Ready_2),
    .Dout_Valid(Dout_Valid_2),
    .freq_ctrl(freq_ctrl_2)
);

assign RxD_1 = TxD_2;
assign RxD_2 = TxD_1;

always begin
    #5;
    clk = !clk;
end

initial begin
    clk = 0;
    rst = 0;
    Din_1 = 8'b0;
    Din_2 = 8'b0;
    Din_Valid_1 = 0;
    Dout_Ready_1 = 0;
    Din_Valid_2 = 0;
    Dout_Ready_2 = 0;
    freq_ctrl_1 = 4'b0101; //115200 bps
    freq_ctrl_2 = 4'b0101; //115200 bps

#100;
rst = 1;
#10;
rst = 0;

// ========== A → B ==========
wait (Din_Ready_1);
@(posedge clk);
Din_1 = 8'b1010_1010;
Din_Valid_1 = 1;
@(negedge clk);             // 等半个系统时钟确保数据稳定
wait (!Din_Ready_1);        // 等发射器确认接收（Ready变低=开始发送）
Din_Valid_1 = 0;

wait (Dout_Valid_2);
@(posedge clk);
if (Dout_2 !== 8'hAA)
    $display("ERROR: A->B expected AA, got %h", Dout_2);
else
    $display("PASS:  A->B sent AA, received %h", Dout_2);
Dout_Ready_2 = 1;
@(posedge clk);
Dout_Ready_2 = 0;

// ========== B → A ==========
wait (Din_Ready_2);
@(posedge clk);
Din_2 = 8'b0011_1100;
Din_Valid_2 = 1;
@(negedge clk);
wait (!Din_Ready_2);        // 等发射器确认接收（Ready变低=开始发送）
Din_Valid_2 = 0;

wait (Dout_Valid_1);
@(posedge clk);
if (Dout_1 !== 8'h3C)
    $display("ERROR: B->A expected 3C, got %h", Dout_1);
else
    $display("PASS:  B->A sent 3C, received %h", Dout_1);
Dout_Ready_1 = 1;
@(posedge clk);
Dout_Ready_1 = 0;

// ========== finish ==========
#500;
$display("Simulation finished.");
$finish;

end

endmodule
