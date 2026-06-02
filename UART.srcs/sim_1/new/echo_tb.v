`timescale 1ns / 1ps
module echo_tb();

reg clk;
reg rst;
reg [3:0] freq_ctrl;
wire TxD;
reg RxD;

uart_loopback #(.SYS_FREQ(100_000_000)) UUT (
    .Clock(clk),
    .Reset(rst),
    .freq_ctrl(freq_ctrl),
    .TxD(TxD),
    .RxD(RxD)
);

// 100MHz 时钟
always begin
    #5;
    clk = ~clk;
end

// UART 发送任务（含偶校验位）
task send_uart_byte;
    input [7:0] data;
    reg parity;
    integer i;
    begin
        parity = ^data;
        RxD = 1'b0;
        #8680;
        for (i = 0; i < 8; i = i + 1) begin
            RxD = data[i];
            #8680;
        end
        RxD = parity;
        #8680;
        RxD = 1'b1;
        #8680;
    end
endtask

// 捕获 Din_Valid 时的 Din 值
reg [7:0] captured_din;
always @(posedge clk) begin
    if (UUT.Din_Valid)
        captured_din <= UUT.Din;
end

// 验证转换结果
reg [7:0] expected;
task check_conversion;
    input [7:0] sent;
    input [7:0] converted;
    begin
        if (sent >= 8'h61 && sent <= 8'h7A)
            expected = sent - 8'h20;
        else if (sent >= 8'h41 && sent <= 8'h5A)
            expected = sent + 8'h20;
        else
            expected = sent;

        if (converted == expected)
            $display("[PASS] '%c' (0x%h) -> '%c' (0x%h)", sent, sent, converted, converted);
        else
            $display("[FAIL] '%c' (0x%h) -> '%c' (0x%h), expected '%c' (0x%h)",
                     sent, sent, converted, converted, expected, expected);
    end
endtask

initial begin
    clk = 0;
    rst = 0;
    RxD = 1'b1;
    freq_ctrl = 4'b0101;
    captured_din = 8'h00;

    #100;
    rst = 1;
    #100;
    rst = 0;
    #100000;

    $display("=== UART Loopback Test (Case Conversion) ===");
    $display("");

    send_uart_byte(8'h55);  // 'U' -> 'u'
    #200000;
    check_conversion(8'h55, captured_din);

    send_uart_byte(8'h61);  // 'a' -> 'A'
    #200000;
    check_conversion(8'h61, captured_din);

    send_uart_byte(8'h41);  // 'A' -> 'a'
    #200000;
    check_conversion(8'h41, captured_din);

    send_uart_byte(8'h35);  // '5' -> '5'
    #200000;
    check_conversion(8'h35, captured_din);

    send_uart_byte(8'h7A);  // 'z' -> 'Z'
    #200000;
    check_conversion(8'h7A, captured_din);

    send_uart_byte(8'h5A);  // 'Z' -> 'z'
    #200000;
    check_conversion(8'h5A, captured_din);

    $display("");
    $display("=== Test Complete ===");
    $finish;
end

endmodule
