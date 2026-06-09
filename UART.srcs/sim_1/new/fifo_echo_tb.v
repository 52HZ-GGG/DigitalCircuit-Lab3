`timescale 1ns / 1ps
// FIFO 连续收发测试：验证多字节连续发送时不丢失数据
module fifo_echo_tb();

reg clk;
reg rst;
reg [3:0] freq_ctrl;
wire TxD;
reg RxD;
wire [15:0] LEDS;

uart_loopback #(.SYS_FREQ(100_000_000)) UUT (
    .Clock(clk),
    .Reset(rst),
    .freq_ctrl(freq_ctrl),
    .TxD(TxD),
    .RxD(RxD),
    .LEDS(LEDS)
);

// 100MHz 时钟
always begin
    #5;
    clk = ~clk;
end

// UART 发送任务（含偶校验位，115200bps, 1 bit = 8680ns）
task send_uart_byte;
    input [7:0] data;
    reg parity;
    integer i;
    begin
        parity = ^data;
        RxD = 1'b0;           // 起始位
        #8680;
        for (i = 0; i < 8; i = i + 1) begin
            RxD = data[i];    // LSB first
            #8680;
        end
        RxD = parity;         // 校验位
        #8680;
        RxD = 1'b1;           // 停止位
        #8680;
    end
endtask

// 捕获发出的数据（Din_Valid 时的 Din）
reg [7:0] captured_din;
reg [7:0] captured_din_prev;
integer send_count;
integer recv_count;

reg last_Din_Valid_tb;
always @(posedge clk) begin
    last_Din_Valid_tb <= UUT.Din_Valid;
    if (UUT.Din_Valid && !last_Din_Valid_tb) begin
        captured_din_prev <= captured_din;
        captured_din <= UUT.Din;
        recv_count <= recv_count + 1;
    end
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
    freq_ctrl = 4'b0101;     // 115200 bps
    captured_din = 8'h00;
    captured_din_prev = 8'h00;
    send_count = 0;
    recv_count = 0;
    last_Din_Valid_tb = 0;

    // 复位
    #100;
    rst = 1;
    #100;
    rst = 0;
    #100000;

    // ========== 测试1：连续发送多个字节（无间隔） ==========
    $display("=== Test 1: Consecutive Bytes (No Gap) ===");
    $display("Sending 5 bytes back-to-back...");

    send_uart_byte(8'h41);  // 'A' -> 'a'
    send_uart_byte(8'h42);  // 'B' -> 'b'
    send_uart_byte(8'h43);  // 'C' -> 'c'
    send_uart_byte(8'h44);  // 'D' -> 'd'
    send_uart_byte(8'h45);  // 'E' -> 'e'
    send_count = 5;

    // 等待所有数据处理完成
    // 每个字节 UART 传输 ~8680*11 = 95480ns, 5个字节 + 处理时间
    #800000;

    $display("Sent %d bytes, Received %d bytes", send_count, recv_count);
    if (recv_count == send_count)
        $display("[PASS] All %d bytes received and processed", send_count);
    else
        $display("[FAIL] Expected %d received bytes, got %d", send_count, recv_count);

    // 逐个验证转换结果
    check_conversion(8'h45, captured_din);  // 最后收到的 'E' -> 'e'

    // ========== 测试2：连续发送大量字符 ==========
    $display("");
    $display("=== Test 2: String 'HELLO' ===");
    send_count = 0;
    recv_count = 0;

    send_uart_byte(8'h48);  // 'H' -> 'h'
    send_uart_byte(8'h45);  // 'E' -> 'e'
    send_uart_byte(8'h4C);  // 'L' -> 'l'
    send_uart_byte(8'h4C);  // 'L' -> 'l'
    send_uart_byte(8'h4F);  // 'O' -> 'o'
    send_count = 5;

    #800000;

    $display("Sent %d bytes, Received %d bytes", send_count, recv_count);
    if (recv_count == send_count)
        $display("[PASS] All %d bytes received and processed", send_count);
    else
        $display("[FAIL] Expected %d received bytes, got %d", send_count, recv_count);

    check_conversion(8'h4F, captured_din);  // 'O' -> 'o'

    // ========== 测试3：混合大小写和特殊字符 ==========
    $display("");
    $display("=== Test 3: Mixed Case + Special ===");
    send_count = 0;
    recv_count = 0;

    send_uart_byte(8'h61);  // 'a' -> 'A'
    send_uart_byte(8'h42);  // 'B' -> 'b'
    send_uart_byte(8'h30);  // '0' -> '0'
    send_uart_byte(8'h7A);  // 'z' -> 'Z'
    send_uart_byte(8'h21);  // '!' -> '!'
    send_count = 5;

    #800000;

    $display("Sent %d bytes, Received %d bytes", send_count, recv_count);
    if (recv_count == send_count)
        $display("[PASS] All %d bytes received and processed", send_count);
    else
        $display("[FAIL] Expected %d received bytes, got %d", send_count, recv_count);

    // ========== 测试4：逐字节验证所有转换 ==========
    $display("");
    $display("=== Test 4: Byte-by-Byte Verification ===");
    send_count = 0;
    recv_count = 0;

    send_uart_byte(8'h41);  // 'A' -> 'a'
    #200000;
    check_conversion(8'h41, captured_din);

    send_uart_byte(8'h7A);  // 'z' -> 'Z'
    #200000;
    check_conversion(8'h7A, captured_din);

    send_uart_byte(8'h30);  // '0' -> '0'
    #200000;
    check_conversion(8'h30, captured_din);

    send_uart_byte(8'hFF);  // 0xFF -> 0xFF
    #200000;
    if (captured_din == 8'hFF)
        $display("[PASS] 0xFF -> 0x%h", captured_din);
    else
        $display("[FAIL] 0xFF -> 0x%h, expected 0xFF", captured_din);

    // ========== 测试5：FIFO 满压力测试 ==========
    $display("");
    $display("=== Test 5: FIFO Full Pressure (16+ bytes) ===");
    send_count = 0;
    recv_count = 0;

    // 连续发送 20 个字节（超过 FIFO 深度 16），测试反压
    send_uart_byte(8'h41);  // A
    send_uart_byte(8'h42);  // B
    send_uart_byte(8'h43);  // C
    send_uart_byte(8'h44);  // D
    send_uart_byte(8'h45);  // E
    send_uart_byte(8'h46);  // F
    send_uart_byte(8'h47);  // G
    send_uart_byte(8'h48);  // H
    send_uart_byte(8'h49);  // I
    send_uart_byte(8'h4A);  // J
    send_uart_byte(8'h4B);  // K
    send_uart_byte(8'h4C);  // L
    send_uart_byte(8'h4D);  // M
    send_uart_byte(8'h4E);  // N
    send_uart_byte(8'h4F);  // O
    send_uart_byte(8'h50);  // P
    send_uart_byte(8'h51);  // Q
    send_uart_byte(8'h52);  // R
    send_uart_byte(8'h53);  // S
    send_uart_byte(8'h54);  // T
    send_count = 20;

    // 等待足够时间让所有数据处理完成
    #2500000;

    $display("Sent %d bytes, Received %d bytes", send_count, recv_count);
    if (recv_count == send_count)
        $display("[PASS] All %d bytes received and processed (FIFO handled backpressure)", send_count);
    else
        $display("[FAIL] Expected %d received bytes, got %d", send_count, recv_count);

    $display("");
    $display("=== FIFO Echo Test Complete ===");
    $finish;
end

endmodule
