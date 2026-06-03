import serial
import time
import sys

# ========== 串口配置 ==========
PORT = 'COM4'          # 根据设备管理器修改
BAUD = 115200
TIMEOUT = 1            # 接收超时(秒)
INTER_BYTE_DELAY = 0.3 # 每次测试间隔(秒)

def open_serial():
    """打开串口"""
    ser = serial.Serial(
        port=PORT,
        baudrate=BAUD,
        bytesize=8,
        parity='E',      # 偶校验，匹配FPGA的UART_Transmitter/Receiver
        stopbits=1,
        timeout=TIMEOUT
    )
    print(f"串口已打开: {ser.name}")
    print(f"配置: {BAUD} bps, 8E1 (偶校验)")
    print(f"等待 FPGA 复位完成...")
    time.sleep(2)  # 等待FPGA复位和UART稳定
    ser.reset_input_buffer()
    ser.reset_output_buffer()
    return ser

def send_and_receive(ser, data_byte):
    """发送一个字节并接收回环数据"""
    ser.reset_input_buffer()
    ser.write(bytes([data_byte]))
    time.sleep(INTER_BYTE_DELAY)
    if ser.in_waiting > 0:
        received = ser.read(ser.in_waiting)
        return received[0] if len(received) == 1 else received
    return None

def expected_converted(data_byte):
    """计算期望的大小写转换结果"""
    if 0x61 <= data_byte <= 0x7A:       # a-z → A-Z
        return data_byte - 0x20
    elif 0x41 <= data_byte <= 0x5A:     # A-Z → a-z
        return data_byte + 0x20
    else:
        return data_byte                # 其他字符不变

def test_single_bits(ser):
    """单bit测试：定位哪些位被错误采样"""
    print("=" * 60)
    print("测试1: 单Bit测试 (验证接收器采样)")
    print("=" * 60)
    print(f"{'发送':>8} {'二进制':>12} {'收到':>8} {'二进制':>12} {'结果':>6}")
    print("-" * 60)

    passed = 0
    failed = 0

    for i in range(8):
        sent = 1 << i
        received = send_and_receive(ser, sent)
        if received is None:
            print(f"  0x{sent:02X}   {sent:08b}     --    --------    超时")
            failed += 1
            continue
        if isinstance(received, bytes):
            received = received[0]
        match = "PASS" if received == sent else "FAIL"
        if match == "PASS":
            passed += 1
        else:
            failed += 1
        print(f"  0x{sent:02X}   {sent:08b}   0x{received:02X}   {received:08b}   {match}")

    print("-" * 60)
    print(f"结果: {passed}/8 通过, {failed}/8 失败")
    print()
    return failed == 0

def test_case_conversion(ser):
    """大小写转换测试"""
    print("=" * 60)
    print("测试2: 大小写转换测试")
    print("=" * 60)
    print(f"{'发送':>8} {'收到':>8} {'期望':>8} {'结果':>6}")
    print("-" * 60)

    test_cases = [
        (0x61, 'a'), (0x41, 'A'),       # 字母大小写
        (0x7A, 'z'), (0x5A, 'Z'),
        (0x55, 'U'), (0x75, 'u'),
        (0x35, '5'), (0x21, '!'),       # 非字母不变
    ]

    passed = 0
    failed = 0

    for data_byte, label in test_cases:
        expected = expected_converted(data_byte)
        received = send_and_receive(ser, data_byte)
        if received is None:
            print(f"  '{label}' 0x{data_byte:02X}    --    0x{expected:02X}    超时")
            failed += 1
            continue
        if isinstance(received, bytes):
            received = received[0]
        match = "PASS" if received == expected else "FAIL"
        if match == "PASS":
            passed += 1
        else:
            failed += 1
        print(f"  '{label}' 0x{data_byte:02X}   0x{received:02X}   0x{expected:02X}   {match}")

    print("-" * 60)
    print(f"结果: {passed}/{len(test_cases)} 通过, {failed}/{len(test_cases)} 失败")
    print()
    return failed == 0

def test_raw_loopback(ser):
    """原始回环测试：发送不触发转换的值，验证数据完整性"""
    print("=" * 60)
    print("测试3: 原始回环测试 (非字母字符，不触发转换)")
    print("=" * 60)
    print(f"{'发送':>8} {'收到':>8} {'结果':>6}")
    print("-" * 60)

    test_values = [0x00, 0x0F, 0xF0, 0xFF, 0x30, 0x39, 0x20, 0x7F]
    passed = 0
    failed = 0

    for sent in test_values:
        received = send_and_receive(ser, sent)
        if received is None:
            print(f"  0x{sent:02X}     --    超时")
            failed += 1
            continue
        if isinstance(received, bytes):
            received = received[0]
        match = "PASS" if received == sent else "FAIL"
        if match == "PASS":
            passed += 1
        else:
            failed += 1
        print(f"  0x{sent:02X}   0x{received:02X}   {match}")

    print("-" * 60)
    print(f"结果: {passed}/{len(test_values)} 通过, {failed}/{len(test_values)} 失败")
    print()
    return failed == 0

def main():
    print()
    print("╔══════════════════════════════════════╗")
    print("║     UART Loopback 回环测试工具       ║")
    print("╚══════════════════════════════════════╝")
    print()

    try:
        ser = open_serial()
    except serial.SerialException as e:
        print(f"无法打开串口 {PORT}: {e}")
        print("请检查: 1) COM口号  2) FPGA是否连接  3) 是否被其他程序占用")
        sys.exit(1)

    results = []
    results.append(("单Bit测试", test_single_bits(ser)))
    results.append(("大小写转换", test_case_conversion(ser)))
    results.append(("原始回环", test_raw_loopback(ser)))

    ser.close()
    print("串口已关闭")
    print()

    # 总结
    print("=" * 60)
    print("测试总结")
    print("=" * 60)
    for name, passed in results:
        status = "PASS" if passed else "FAIL"
        print(f"  [{status}] {name}")
    print()

    all_passed = all(r[1] for r in results)
    if all_passed:
        print("所有测试通过!")
    else:
        print("存在失败的测试，请检查硬件配置。")
    print()

if __name__ == "__main__":
    main()
