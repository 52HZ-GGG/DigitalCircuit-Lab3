`timescale 1ns / 1ps
module UART_BaudGen_tb;
reg clk, rst;
wire Baud, Baud16;

UART_BaudGen #(.SYS_FREQ(100_000_000)) BG (
    .Clock(clk), .Reset(rst), .Bclk(Baud), .Bclk16(Baud16), .freq_ctrl(4'b0101)
);

always begin #5; clk = !clk; end

always @(posedge Baud16)
    $display("t=%0t: Baud16 posedge, Baud=%b", $time, Baud);

always @(posedge Baud)
    $display("t=%0t: >>> Baud posedge <<<", $time);

initial begin
    clk = 0; rst = 0;
    #100; rst = 1; #10; rst = 0;
    #50000;
    $display("Done");
    $finish;
end
endmodule
