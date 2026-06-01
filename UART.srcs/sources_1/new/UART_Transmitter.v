module UART_Transmitter (
    input BaudClock,      //baud rate
    input Reset,          //system reset
    input [7:0] Din,      //transmit data in
    input Valid,          //write pulse for Din
    output reg TxD,           //transmit data output
    output reg Ready          //transmitter ready for new data
);

reg [4:0] Tstate;        //transmit state
reg [2:0] Tcnt;          //transmit bit count
reg [7:0] Treg;          //transmit shift register
reg TparBit;             //transmit parity bit

parameter Tidle = 5'b00001,
        Tstart = 5'b00010,
        Tdata = 5'b00100,
        Tparity = 5'b01000,
        Tstop = 5'b10000;

//transmit controller
always @(posedge Reset or posedge BaudClock) begin
    if(Reset) Tstate <= Tidle;
    else
        case (Tstate)
            Tidle: if(Valid) Tstate <= Tstart;
            Tstart: Tstate <= Tdata;
            Tdata: if(Tcnt == 3'b111) Tstate <= Tparity;
            Tparity: Tstate <= Tstop;
            Tstop: Tstate <= Tidle;
        endcase
end

always @(posedge Reset or posedge BaudClock) begin
    if(Reset) begin
        Tcnt <= 3'b000;
        Treg <= 8'b0;
        TparBit <= 1'b0;
    end else if(Tstate[0]) begin
        Tcnt <= 3'b000;
        TxD <= 1'b1;  //idle state
        Treg <= 8'b0;
        TparBit <= 1'b0;
    end else if(Tstate[1]) begin 
        TxD <= 1'b0;
        Treg <= Din;
        TparBit <= ^Din;  //even parity
    end else if(Tstate[2]) begin
            TxD <= Treg[0];
            Treg <= Treg >> 1;
            Tcnt <= Tcnt + 1;
    end else if(Tstate[3]) begin
        TxD <= TparBit;
    end else if(Tstate[4]) begin
        TxD <= 1'b1;
    end
end

always @(posedge Reset or posedge BaudClock) begin
    if(Reset) Ready <= 1'b1;
    else if(Tstate == Tidle) Ready <= 1'b1;
    else if(Tstate != Tidle) Ready <= 1'b0;
    else if(Valid) Ready <= 1'b0;
end

endmodule