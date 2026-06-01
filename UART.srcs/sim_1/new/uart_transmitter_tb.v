`timescale 1ns / 1ps

module uart_transmitter_tb();

reg Clk;
reg Rst;
reg [7:0] Din;
reg Din_Valid;
wire TxD;
wire Din_Ready;

UART_Transmitter inst_transmitter (
    .BaudClock(Clk),
    .Reset(Rst),
    .Din(Din),
    .Valid(Din_Valid),
    .TxD(TxD),
    .Ready(Din_Ready)
);

//Generate 100MHz clock
always begin
    #5;
    Clk = !Clk;
end

initial begin
    Clk = 0;
    Rst = 0;
    Din_Valid = 0;
    Din = 8'b0;

    #100;
    Rst = 1;
    #10;
    Rst = 0;
    #10;

    Din = 8'b1010_1010;
    #40;
    Din_Valid = 1;
    #10;
    Din_Valid = 0;
    #500;
    //as you run it...should see 10101010 show up on the data out line

    Din = 8'b0011_1011;
    #40;
    Din_Valid = 1;
    #10;
    Din_Valid = 0;
    #500;
    //as you run it...should see 00111011 show up on the data out line

    Din = 8'b1010_0010;
    #40;
    Din_Valid = 1;
    #10;
    Din_Valid = 0;
    #500;
    //as you run it...should see 10100010 show up on the data out line

end

endmodule