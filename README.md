# 数字电路与系统设计 Lab3：UART 串口回环通信

## 实验信息

- **课程**：北京大学信息科学技术学院 数字电路与系统设计课程
- **实验名称**：Lab3 - UART 串口回环通信

## 实验简介

本实验设计并实现了一个 UART（Universal Asynchronous Receiver/Transmitter）串口通信系统，支持全双工异步通信，并实现了大小写字母自动转换的回环功能。系统包含以下模块：

- **波特率生成器 (UART_BaudGen.v)**：根据拨码开关配置生成标准波特率时钟及16倍采样时钟。
- **UART 发射器 (UART_Transmitter.v)**：实现并串转换，按起始位+8数据位+偶校验位+停止位格式发送数据。
- **UART 接收器 (UART_Receiver.v)**：实现串并转换，使用 Bclk16 过采样在 bit 中心采样，支持偶校验检测。
- **UART 顶层模块 (UART.v)**：集成波特率生成器、发射器和接收器。
- **回环控制器 (uart_loopback.v)**：接收数据后自动进行大小写转换并回传。

## 文件结构

```
UART/
├── README.md                           # 本文件
├── serial_debug.py                     # Python 串口测试脚本
├── UART.srcs/
│   ├── sources_1/new/                  # 设计源文件
│   │   ├── UART_BaudGen.v              # 波特率生成器
│   │   ├── UART_Transmitter.v          # UART 发射器
│   │   ├── UART_Receiver.v             # UART 接收器（Bclk16 过采样）
│   │   ├── UART.v                      # UART 顶层模块
│   │   └── uart_loopback.v             # 回环控制器（含 LED 调试输出）
│   ├── constrs_1/new/                  # 约束文件
│   │   └── basys3.xdc                  # Basys3 引脚约束
│   └── sim_1/new/                      # 仿真测试文件
│       ├── echo_tb.v                   # 回环功能仿真测试
│       └── uart2uart_tb.v              # 双向通信仿真测试
└── serial_test.py                      # 备用测试脚本
```

## 功能说明

### 1. UART 通信协议

| 参数 | 值 |
|------|-----|
| 数据位 | 8 位 |
| 校验位 | 偶校验 (Even Parity) |
| 停止位 | 1 位 |
| 帧格式 | 起始位 + D0-D7 + 校验位 + 停止位 |

### 2. 波特率配置

通过 Basys3 右侧 4 位拨码开关 (`SW0-SW3`) 选择波特率：

| SW3-SW0 | freq_ctrl | 波特率 |
|---------|-----------|--------|
| 0000 | 4'b0000 | 2400 bps |
| 0001 | 4'b0001 | 4800 bps |
| 0010 | 4'b0010 | 9600 bps |
| 0011 | 4'b0011 | 19200 bps |
| 0100 | 4'b0100 | 57600 bps |
| **0101** | **4'b0101** | **115200 bps**（默认） |
| 0110 | 4'b0110 | 230400 bps |
| 0111 | 4'b0111 | 460800 bps |
| 1000 | 4'b1000 | 921600 bps |

> **注意**：默认使用 115200 bps，对应拨码开关 SW0=ON, SW1=OFF, SW2=ON, SW3=OFF。

### 3. 回环转换规则

| 输入 | 输出 | 说明 |
|------|------|------|
| 'a'-'z' | 'A'-'Z' | 小写转大写 |
| 'A'-'Z' | 'a'-'z' | 大写转小写 |
| 其他字符 | 原样返回 | 不做转换 |

### 4. LED 调试输出

`uart_loopback.v` 提供 16 位 LED 调试输出：

| LED | 说明 |
|-----|------|
| LD15~LD8 | 收到的原始数据（latched_data） |
| LD7~LD0 | 转换后的数据（converted_data） |

## 运行方法

### 1. 创建 Vivado 工程

1. 打开 Vivado，点击 **Create Project**
2. 选择工程存放路径，**RTL Project**，勾选 **Do not specify sources at this time**
3. 选择目标器件：**xc7a35tcpg236-1**（Basys3）
4. 点击 **Finish**

### 2. 添加源文件和约束

1. 在左侧 Sources 面板中，右键 **Design Sources → Add Sources**
2. 选择 **Add Files**，找到 `UART.srcs/sources_1/new/` 文件夹，选中所有 `.v` 文件
3. 右键 **Constraints → Add Sources**，添加 `UART.srcs/constrs_1/new/basys3.xdc`
4. 右键 **Simulation Sources → Add Sources**，添加 `sim_1/new/` 下的测试文件

### 3. 运行仿真

在 Flow Navigator 中点击 **Run Simulation → Run Behavioral Simulation**，选择测试文件观察波形。

使用命令行仿真（需要 Icarus Verilog）：

```bash
iverilog -o sim_out -I UART.srcs/sources_1/new \
    UART.srcs/sources_1/new/UART_Receiver.v \
    UART.srcs/sources_1/new/UART_Transmitter.v \
    UART.srcs/sources_1/new/UART_BaudGen.v \
    UART.srcs/sources_1/new/UART.v \
    UART.srcs/sources_1/new/uart_loopback.v \
    UART.srcs/sim_1/new/echo_tb.v
vvp sim_out
```

### 4. 综合、实现、生成比特流

点击 **Generate Bitstream**（会自动完成综合和实现），等待流程完成。

### 5. 下载到 Basys3 板卡

1. 连接 Basys3 开发板到电脑（USB-UART 口）
2. 点击 **Open Hardware Manager → Open Target → Auto Connect**
3. 右键设备，选择 **Program Device**，选择生成的 `.bit` 文件，点击 **Program**
4. 按一次 **btnC** 按钮复位

## 上板测试

### 方法一：Python 脚本

确保安装 `pyserial`：

```bash
pip install pyserial
```

修改 `serial_debug.py` 中的 `PORT` 为实际 COM 口（设备管理器查看），然后运行：

```bash
python serial_debug.py
```

脚本会自动测试单 bit 传输、大小写转换和原始回环，输出 PASS/FAIL 结果。

### 方法二：COMTool 串口工具

1. 下载 [COMTool](https://github.com/Neutree/COMTool)
2. 打开 COMTool，配置串口参数：
   - **端口**：COM4（根据设备管理器调整）
   - **波特率**：115200
   - **数据位**：8
   - **校验**：Even（偶校验）
   - **停止位**：1
3. 点击 **打开串口**
4. 在发送区输入十六进制数据（如 `61`）或 ASCII 字符（如 `a`），点击发送
5. 接收区应显示转换后的结果（如 `41` 或 `A`）

### 测试用例

| 发送 | 期望接收 | 说明 |
|------|---------|------|
| `a` (0x61) | `A` (0x41) | 小写→大写 |
| `A` (0x41) | `a` (0x61) | 大写→小写 |
| `z` (0x7A) | `Z` (0x5A) | 小写→大写 |
| `Z` (0x5A) | `z` (0x7A) | 大写→小写 |
| `U` (0x55) | `u` (0x75) | 大写→小写 |
| `5` (0x35) | `5` (0x35) | 数字不变 |
| `!` (0x21) | `!` (0x21) | 特殊字符不变 |

## 作者

- GitHub: [52HZ-GGG](https://github.com/52HZ-GGG)
