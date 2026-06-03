//Universal Asynchronous Receiver/Transmitter (UART)
module UART #(
    parameter SYS_FREQ = 100_000_000
)(
    input Clock,          //system clock
    input Reset,          //system reset
    output Baud, Baud16,  //baud rate and 16x baud rate
    input [7:0] Din,      //parallel inputs
    output [7:0] Dout,    //parallel outputs
    input Din_Valid, Dout_Ready,  //read-write pulse
    output TxD,           //transmit line
    input RxD,            //receive line
    output Din_Ready, Dout_Valid, //transmitter-receiver ready
    input [3:0] freq_ctrl //4位拨位开关,用于控制FPGA 串口通信速率
);

UART_BaudGen #(.SYS_FREQ(SYS_FREQ))
    BG (.Clock(Clock), .Reset(Reset), .Bclk(Baud), .Bclk16(Baud16), .freq_ctrl(freq_ctrl));

UART_Transmitter TX (
    .BaudClock(Baud),    //Baud clock
    .Reset(Reset),
    .Din(Din),           //transmit data in
    .Valid(Din_Valid),   //write pulse for Din
    .TxD(TxD),           //transmit data output
    .Ready(Din_Ready)    //transmitter ready for new data
);

UART_Receiver RX (
    .BaudClock(Baud16),  //Baud clock
    .Reset(Reset),
    .Dout(Dout),         //receive data out
    .Ready(Dout_Ready),  //read pulse for Dout
    .RxD(RxD),           //receive data input
    .Valid(Dout_Valid),  //received data ready to read
    .RxParityErr()       //parity error (未使用)
);

endmodule