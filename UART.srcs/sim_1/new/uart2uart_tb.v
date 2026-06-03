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

integer pass_count = 0;
integer fail_count = 0;

UART #(.SYS_FREQ(100_000_000)) UART1 (
    .Clock(clk), .Reset(rst),
    .Baud(Baud_1), .Baud16(Baud16_1),
    .Din(Din_1), .Dout(Dout_1),
    .Din_Valid(Din_Valid_1), .Dout_Ready(Dout_Ready_1),
    .TxD(TxD_1), .RxD(RxD_1),
    .Din_Ready(Din_Ready_1), .Dout_Valid(Dout_Valid_1),
    .freq_ctrl(freq_ctrl_1)
);

UART #(.SYS_FREQ(100_000_000)) UART2 (
    .Clock(clk), .Reset(rst),
    .Baud(Baud_2), .Baud16(Baud16_2),
    .Din(Din_2), .Dout(Dout_2),
    .Din_Valid(Din_Valid_2), .Dout_Ready(Dout_Ready_2),
    .TxD(TxD_2), .RxD(RxD_2),
    .Din_Ready(Din_Ready_2), .Dout_Valid(Dout_Valid_2),
    .freq_ctrl(freq_ctrl_2)
);

assign RxD_1 = TxD_2;
assign RxD_2 = TxD_1;

// 100MHz 时钟
always begin #5; clk = !clk; end

// ========== 发送任务 ==========
task send_uart1;
    input [7:0] data;
    begin
        wait (Din_Ready_1);
        @(posedge clk);
        Din_1 = data;
        Din_Valid_1 = 1;
        @(negedge clk);
        wait (!Din_Ready_1);
        Din_Valid_1 = 0;
    end
endtask

task send_uart2;
    input [7:0] data;
    begin
        wait (Din_Ready_2);
        @(posedge clk);
        Din_2 = data;
        Din_Valid_2 = 1;
        @(negedge clk);
        wait (!Din_Ready_2);
        Din_Valid_2 = 0;
    end
endtask

// ========== 接收验证任务（Dout_Ready保持到Dout_Valid清除）==========
task check_uart1;
    input [7:0] expected;
    begin
        wait (Dout_Valid_1);
        @(posedge clk);
        if (Dout_1 !== expected) begin
            $display("[FAIL] UART1 expected %h, got %h", expected, Dout_1);
            fail_count = fail_count + 1;
        end else begin
            $display("[PASS] UART1 received %h", Dout_1);
            pass_count = pass_count + 1;
        end
        Dout_Ready_1 = 1;
        wait (!Dout_Valid_1);  // 等到Valid清除
        @(posedge clk);
        Dout_Ready_1 = 0;
    end
endtask

task check_uart2;
    input [7:0] expected;
    begin
        wait (Dout_Valid_2);
        @(posedge clk);
        if (Dout_2 !== expected) begin
            $display("[FAIL] UART2 expected %h, got %h", expected, Dout_2);
            fail_count = fail_count + 1;
        end else begin
            $display("[PASS] UART2 received %h", Dout_2);
            pass_count = pass_count + 1;
        end
        Dout_Ready_2 = 1;
        wait (!Dout_Valid_2);  // 等到Valid清除
        @(posedge clk);
        Dout_Ready_2 = 0;
    end
endtask

// ========== 主测试 ==========
initial begin
    clk = 0;
    rst = 0;
    Din_1 = 0; Din_2 = 0;
    Din_Valid_1 = 0; Dout_Ready_1 = 0;
    Din_Valid_2 = 0; Dout_Ready_2 = 0;
    freq_ctrl_1 = 4'b0101;
    freq_ctrl_2 = 4'b0101;

    #100; rst = 1; #10; rst = 0; #1000;

    // ===== 测试1: A → B =====
    $display("");
    $display("=== Test 1: A -> B (0xAA) ===");
    send_uart1(8'hAA);
    check_uart2(8'hAA);
    #2000;

    // ===== 测试2: B → A =====
    $display("");
    $display("=== Test 2: B -> A (0x3C) ===");
    send_uart2(8'h3C);
    check_uart1(8'h3C);
    #2000;

    // ===== 测试3: 双工同时通信 =====
    $display("");
    $display("=== Test 3: Duplex (A->B: 0x55, B->A: 0xAA) ===");
    fork
        send_uart1(8'h55);
        send_uart2(8'hAA);
    join
    #200000;  // 等待传输完成（11bit × 8680ns ≈ 95μs，留余量）
    fork
        check_uart2(8'h55);
        check_uart1(8'hAA);
    join
    #2000;

    // ===== 测试4: 双工 + 不同数据 =====
    $display("");
    $display("=== Test 4: Duplex (A->B: 0x61, B->A: 0x42) ===");
    fork
        send_uart1(8'h61);
        send_uart2(8'h42);
    join
    #200000;
    fork
        check_uart2(8'h61);
        check_uart1(8'h42);
    join
    #2000;

    // ===== 测试5: 双工 + 边界值 =====
    $display("");
    $display("=== Test 5: Duplex (A->B: 0x00, B->A: 0xFF) ===");
    fork
        send_uart1(8'h00);
        send_uart2(8'hFF);
    join
    #200000;
    fork
        check_uart2(8'h00);
        check_uart1(8'hFF);
    join
    #2000;

    // ===== 测试6: 连续双向交替 =====
    $display("");
    $display("=== Test 6: Alternating A<->B ===");
    send_uart1(8'h11);
    check_uart2(8'h11);
    send_uart2(8'h22);
    check_uart1(8'h22);
    send_uart1(8'h33);
    check_uart2(8'h33);
    send_uart2(8'h44);
    check_uart1(8'h44);

    // ===== 结果 =====
    #1000;
    $display("");
    $display("========================================");
    $display("  Results: %0d PASS, %0d FAIL", pass_count, fail_count);
    $display("========================================");
    $display("");
    $finish;
end

endmodule
