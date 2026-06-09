`timescale 1ns / 1ps
// 同步FIFO：用于UART接收端缓冲，防止连续数据丢失
module uart_fifo #(
    parameter DATA_WIDTH = 8,
    parameter ADDR_WIDTH = 4,               // 2^4 = 16 深度
    parameter DEPTH = (1 << ADDR_WIDTH)      // 16
)(
    input  wire                    clk,
    input  wire                    rst_n,    // 低有效复位
    input  wire [DATA_WIDTH-1:0]  din,
    input  wire                   wr_en,
    input  wire                   rd_en,
    output reg  [DATA_WIDTH-1:0]  dout,
    output wire                   full,
    output wire                   empty,
    output wire [ADDR_WIDTH:0]   data_count  // 当前数据量 0~16
);

reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];
reg [ADDR_WIDTH-1:0] wr_ptr, rd_ptr;
reg [ADDR_WIDTH:0]   count;

// 满/空标志
assign full  = (count == DEPTH);
assign empty = (count == 0);
assign data_count = count;

// 写操作
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        wr_ptr <= 0;
    end else if (wr_en && !full) begin
        mem[wr_ptr] <= din;
        wr_ptr <= wr_ptr + 1;
    end
end

// 读操作
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        rd_ptr <= 0;
        dout <= 0;
    end else if (rd_en && !empty) begin
        dout <= mem[rd_ptr];
        rd_ptr <= rd_ptr + 1;
    end
end

// 数据计数
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        count <= 0;
    else begin
        case ({wr_en && !full, rd_en && !empty})
            2'b10:   count <= count + 1;  // 仅写
            2'b01:   count <= count - 1;  // 仅读
            2'b11:   count <= count;       // 同时读写，数量不变
            default: count <= count;       // 无操作
        endcase
    end
end

endmodule
