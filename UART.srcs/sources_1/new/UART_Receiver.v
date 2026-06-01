`timescale 1ns / 1ps

module UART_Receiver (
    input BaudClock,      //Baud clock = 16x baud rate
    input Reset,          //system reset
    input RxD,            //receive data input
    input Ready,          //read pulse for Dout
    output [7:0] Dout,    //received data out
    output reg Valid,     //received data ready to read
    output reg RxParityErr //received parity error
);

reg [3:0] BaudCount;     //divide baud clock by 16
wire BaudRate;           //baud rate clock
reg [2:0] Rcnt;          //receive bit count
reg [7:0] Rreg;          //receive shift register
reg [7:0] Rbuf;          //receive buffer register
reg RparBit;             //receive parity bit
wire StartDetect;        //start bit detected flag
reg [3:0] Rstate;        //receiver state
reg [3:0] StartState;    //start detection state

parameter Ridle   = 4'b0001,
          Rshift  = 4'b0010,
          Rparity = 4'b0100,
          Rstop   = 4'b1000;

parameter Start0 = 4'b0001,
          Start1 = 4'b0010,
          Start2 = 4'b0100,
          Start3 = 4'b1000;

initial Rreg = 8'h00;    //for simulation

//Baud rate is BaudClock / 16
always @(posedge Reset or posedge BaudClock)
    if (Reset)
        BaudCount <= 4'b0000;
    else
        BaudCount <= BaudCount + 1;

assign BaudRate = BaudCount[3];

//Start bit detection and baud clock divider
always @(posedge Reset or posedge BaudClock) begin
    if (Reset)
        StartState <= Start0;  //search for start bit
    else
        case (StartState)
            Start0: if (RxD == 1'b0) StartState <= Start1;  //start bit detected
            Start1: if (RxD == 1'b1) StartState <= Start0;  //false start bit
                    else if (BaudCount == 4'b0111) StartState <= Start2;  //8 Baud16 ticks
            Start2: if (Rstate[1] == 1'b1) StartState <= Start3;  //Cancel StartDetect
            Start3: if (Rstate[0] == 1'b1) StartState <= Start0;  //start over in idle
        endcase
end

assign StartDetect = StartState[2];

//Receive shift register
always @(posedge BaudRate)
    if (Rstate[1])
        Rreg <= {RxD, Rreg[7:1]};  //shift receive data

//Receive parity calculation
always @(posedge StartDetect or posedge BaudRate)  //trigger with baud rate clock
    if (StartDetect) begin
        RparBit <= 1'b0;      //reset parity bit
        RxParityErr <= 1'b0;  //reset parity error flag
    end
    else if (Rstate[1])
        RparBit <= RparBit ^ RxD;  //calculate parity

//Received data on outputs
always @(posedge Reset or posedge BaudRate)
    if (Reset)
        Valid <= 1'b0;
    else if (Rstate == Rstop)
        Valid <= 1'b1;
    else if (Ready)
        Valid <= 1'b0;

assign Dout = Rreg;

//Receive controller
always @(posedge Reset or posedge BaudRate) begin
    if (Reset)
        Rstate <= Ridle;  //reset to initial state
    else
        case (Rstate)
            Ridle: if (StartDetect == 1'b1) begin
                       Rstate <= Rshift;  //shift after start detected
                       Rcnt <= 3'b000;    //reset bit counter
                   end
            Rshift: if (Rcnt == 3'b111)
                        Rstate <= Rparity;  //parity state after 8 bits
                    else
                        Rcnt <= Rcnt + 1;   //increment bit count
            Rparity: begin
                         Rstate <= Rstop;
                         if (RxD != RparBit)
                             RxParityErr <= 1;
                     end
            Rstop: Rstate <= Ridle;
        endcase
end

endmodule