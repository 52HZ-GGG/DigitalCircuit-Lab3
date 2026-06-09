`timescale 1ns / 1ps
module comprehensive_echo_tb();

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

// UART 发送任务（含偶校验位，默认115200bps）
task send_uart_byte;
    input [7:0] data;
    reg parity;
    integer i;
    begin
        parity = ^data;
        RxD = 1'b0;  // 起始位
        #8680;       // 1/115200 ≈ 8680ns
        for (i = 0; i < 8; i = i + 1) begin
            RxD = data[i];
            #8680;
        end
        RxD = parity;  // 校验位
        #8680;
        RxD = 1'b1;    // 停止位
        #8680;
    end
endtask

// UART 发送任务（可指定位时间，用于不同波特率测试）
task send_uart_byte_baud;
    input [7:0] data;
    input integer bit_time;
    reg parity;
    integer i;
    begin
        parity = ^data;
        RxD = 1'b0;
        #bit_time;
        for (i = 0; i < 8; i = i + 1) begin
            RxD = data[i];
            #bit_time;
        end
        RxD = parity;
        #bit_time;
        RxD = 1'b1;
        #bit_time;
    end
endtask

// 发送错误校验的任务
task send_uart_byte_wrong_parity;
    input [7:0] data;
    reg parity;
    integer i;
    begin
        parity = ~(^data);  // 故意发送错误的校验位
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

// 捕获 Din_Valid 上升沿时的 Din 值
reg [7:0] captured_din;
reg last_Din_Valid;
always @(posedge clk) begin
    last_Din_Valid <= UUT.Din_Valid;
    if (UUT.Din_Valid && !last_Din_Valid)
        captured_din <= UUT.Din;
end

// 监控 LEDS 输出（仅在变化时打印）
reg [15:0] last_LEDS;
always @(posedge clk) begin
    if (LEDS != 16'h0000 && LEDS != last_LEDS) begin
        $display("t=%0t: LEDS=0x%h (原始数据:0x%h, 转换后:0x%h)", $time, LEDS, LEDS[15:8], LEDS[7:0]);
    end
    last_LEDS <= LEDS;
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

// 测试计数器
integer pass_count = 0;
integer fail_count = 0;

task check_and_count;
    input [7:0] sent;
    input [7:0] converted;
    begin
        if (sent >= 8'h61 && sent <= 8'h7A)
            expected = sent - 8'h20;
        else if (sent >= 8'h41 && sent <= 8'h5A)
            expected = sent + 8'h20;
        else
            expected = sent;

        if (converted == expected) begin
            $display("[PASS] '%c' (0x%h) -> '%c' (0x%h)", sent, sent, converted, converted);
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] '%c' (0x%h) -> '%c' (0x%h), expected '%c' (0x%h)",
                     sent, sent, converted, converted, expected, expected);
            fail_count = fail_count + 1;
        end

        // 检查 LEDS 输出
        if (LEDS[15:8] == sent && LEDS[7:0] == expected) begin
            $display("[PASS] LEDS正确: 原始数据=0x%h, 转换后=0x%h", LEDS[15:8], LEDS[7:0]);
        end else begin
            $display("[FAIL] LEDS错误: 期望原始数据=0x%h, 转换后=0x%h, 实际LEDs=0x%h",
                     sent, expected, LEDS);
            fail_count = fail_count + 1;
        end
    end
endtask

initial begin
    clk = 0;
    rst = 0;
    RxD = 1'b1;
    freq_ctrl = 4'b0101;  // 115200 bps
    captured_din = 8'h00;
    last_Din_Valid = 0;
    last_LEDS = 16'h0000;

    // ============================================
    // 测试1: 复位功能测试
    // ============================================
    $display("==========================================");
    $display("测试1: 复位功能测试");
    $display("==========================================");

    #100;
    rst = 1;
    #1000;
    rst = 0;
    #100000;

    // 检查复位后LEDS状态
    $display("复位后LEDS状态: 0x%h", LEDS);
    if (LEDS == 16'h0000) begin
        $display("[PASS] 复位后LEDS正确清零");
        pass_count = pass_count + 1;
    end else begin
        $display("[FAIL] 复位后LEDS未清零: 0x%h", LEDS);
        fail_count = fail_count + 1;
    end

    // ============================================
    // 测试2: 基本字母大小写转换测试
    // ============================================
    $display("");
    $display("==========================================");
    $display("测试2: 基本字母大小写转换测试");
    $display("==========================================");

    // 大写字母测试
    send_uart_byte(8'h41);  // 'A' -> 'a'
    #200000;
    check_and_count(8'h41, captured_din);

    send_uart_byte(8'h5A);  // 'Z' -> 'z'
    #200000;
    check_and_count(8'h5A, captured_din);

    send_uart_byte(8'h4D);  // 'M' -> 'm'
    #200000;
    check_and_count(8'h4D, captured_din);

    // 小写字母测试
    send_uart_byte(8'h61);  // 'a' -> 'A'
    #200000;
    check_and_count(8'h61, captured_din);

    send_uart_byte(8'h7A);  // 'z' -> 'Z'
    #200000;
    check_and_count(8'h7A, captured_din);

    send_uart_byte(8'h6D);  // 'm' -> 'M'
    #200000;
    check_and_count(8'h6D, captured_din);

    // ============================================
    // 测试3: 边界条件测试
    // ============================================
    $display("");
    $display("==========================================");
    $display("测试3: 边界条件测试");
    $display("==========================================");

    // 大写字母边界
    send_uart_byte(8'h40);  // '@' (A-1) - 不是字母，应该不变
    #200000;
    check_and_count(8'h40, captured_din);

    send_uart_byte(8'h5B);  // '[' (Z+1) - 不是字母，应该不变
    #200000;
    check_and_count(8'h5B, captured_din);

    // 小写字母边界
    send_uart_byte(8'h60);  // '`' (a-1) - 不是字母，应该不变
    #200000;
    check_and_count(8'h60, captured_din);

    send_uart_byte(8'h7B);  // '{' (z+1) - 不是字母，应该不变
    #200000;
    check_and_count(8'h7B, captured_din);

    // ============================================
    // 测试4: 数字和特殊字符测试
    // ============================================
    $display("");
    $display("==========================================");
    $display("测试4: 数字和特殊字符测试");
    $display("==========================================");

    // 数字测试
    send_uart_byte(8'h30);  // '0'
    #200000;
    check_and_count(8'h30, captured_din);

    send_uart_byte(8'h39);  // '9'
    #200000;
    check_and_count(8'h39, captured_din);

    send_uart_byte(8'h35);  // '5'
    #200000;
    check_and_count(8'h35, captured_din);

    // 特殊字符测试
    send_uart_byte(8'h21);  // '!'
    #200000;
    check_and_count(8'h21, captured_din);

    send_uart_byte(8'h40);  // '@'
    #200000;
    check_and_count(8'h40, captured_din);

    send_uart_byte(8'h23);  // '#'
    #200000;
    check_and_count(8'h23, captured_din);

    send_uart_byte(8'h24);  // '$'
    #200000;
    check_and_count(8'h24, captured_din);

    // ============================================
    // 测试5: 全范围字符测试
    // ============================================
    $display("");
    $display("==========================================");
    $display("测试5: 全范围字符测试");
    $display("==========================================");

    // 测试ASCII码的各个范围
    send_uart_byte(8'h00);  // NULL
    #200000;
    check_and_count(8'h00, captured_din);

    send_uart_byte(8'h20);  // 空格
    #200000;
    check_and_count(8'h20, captured_din);

    send_uart_byte(8'h7F);  // DEL
    #200000;
    check_and_count(8'h7F, captured_din);

    send_uart_byte(8'hFF);  // 最大值
    #200000;
    check_and_count(8'hFF, captured_din);

    // ============================================
    // 测试6: 连续快速传输测试
    // ============================================
    $display("");
    $display("==========================================");
    $display("测试6: 连续快速传输测试");
    $display("==========================================");

    // 快速连续发送多个字符
    send_uart_byte(8'h41);  // 'A'
    #100000;
    send_uart_byte(8'h42);  // 'B'
    #100000;
    send_uart_byte(8'h43);  // 'C'
    #300000;

    // ============================================
    // 测试7: 不同波特率测试
    // ============================================
    $display("");
    $display("==========================================");
    $display("测试7: 不同波特率测试");
    $display("==========================================");

    // 切换到19200波特率 (freq_ctrl=3, Division=326)
    freq_ctrl = 4'b0011;
    #100000;

    // 19200波特率: Division=326, 位时间=16*326*10=52160ns
    send_uart_byte_baud(8'h55, 52160);  // 'U' -> 'u'
    #2000000;
    check_and_count(8'h55, captured_din);

    // 切换到57600波特率 (freq_ctrl=4, Division=109)
    freq_ctrl = 4'b0100;
    #100000;

    // 57600波特率: Division=109, 位时间=16*109*10=17440ns
    send_uart_byte_baud(8'h55, 17440);  // 'U' -> 'u'
    #500000;
    check_and_count(8'h55, captured_din);

    // 切换回115200波特率
    freq_ctrl = 4'b0101;
    #100000;

    // ============================================
    // 测试8: 长时间稳定性测试
    // ============================================
    $display("");
    $display("==========================================");
    $display("测试8: 长时间稳定性测试");
    $display("==========================================");

    // 发送多个字符测试稳定性
    send_uart_byte(8'h48);  // 'H'
    #200000;
    check_and_count(8'h48, captured_din);

    send_uart_byte(8'h65);  // 'e'
    #200000;
    check_and_count(8'h65, captured_din);

    send_uart_byte(8'h6C);  // 'l'
    #200000;
    check_and_count(8'h6C, captured_din);

    send_uart_byte(8'h6C);  // 'l'
    #200000;
    check_and_count(8'h6C, captured_din);

    send_uart_byte(8'h6F);  // 'o'
    #200000;
    check_and_count(8'h6F, captured_din);

    // ============================================
    // 测试9: 校验和测试
    // ============================================
    $display("");
    $display("==========================================");
    $display("测试9: 校验和测试");
    $display("==========================================");

    // 测试各种校验和情况
    send_uart_byte(8'h00);  // 0个1，校验位=0
    #200000;
    check_and_count(8'h00, captured_din);

    send_uart_byte(8'h01);  // 1个1，校验位=1
    #200000;
    check_and_count(8'h01, captured_din);

    send_uart_byte(8'h03);  // 2个1，校验位=0
    #200000;
    check_and_count(8'h03, captured_din);

    send_uart_byte(8'h07);  // 3个1，校验位=1
    #200000;
    check_and_count(8'h07, captured_din);

    send_uart_byte(8'hFF);  // 8个1，校验位=0
    #200000;
    check_and_count(8'hFF, captured_din);

    // ============================================
    // 测试10: 二进制模式测试
    // ============================================
    $display("");
    $display("==========================================");
    $display("测试10: 二进制模式测试");
    $display("==========================================");

    // 测试各种二进制模式
    send_uart_byte(8'h55);  // 01010101
    #200000;
    check_and_count(8'h55, captured_din);

    send_uart_byte(8'hAA);  // 10101010
    #200000;
    check_and_count(8'hAA, captured_din);

    send_uart_byte(8'h0F);  // 00001111
    #200000;
    check_and_count(8'h0F, captured_din);

    send_uart_byte(8'hF0);  // 11110000
    #200000;
    check_and_count(8'hF0, captured_din);

    // ============================================
    // 测试结果统计
    // ============================================
    $display("");
    $display("==========================================");
    $display("测试结果统计");
    $display("==========================================");
    $display("通过: %0d", pass_count);
    $display("失败: %0d", fail_count);
    $display("总计: %0d", pass_count + fail_count);
    $display("==========================================");

    if (fail_count == 0)
        $display("所有测试通过!");
    else
        $display("有 %0d 个测试失败!", fail_count);

    $display("");
    $display("=== 综合测试完成 ===");
    $finish;
end

endmodule