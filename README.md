# 数字电路与系统设计 Lab3：UART 串口回环通信

## 实验信息

- **课程**：北京大学信息科学技术学院 数字电路与系统设计课程
- **实验名称**：Lab3 - UART 串口回环通信

## 实验简介

本实验设计并实现了一个 UART（Universal Asynchronous Receiver/Transmitter）串口通信系统，支持全双工异步通信，并实现了大小写字母自动转换的回环功能。系统包含以下模块：

- **波特率生成器 (UART_BaudGen.v)**：根据拨码开关配置生成标准波特率时钟及16倍采样时钟。
- **UART 发射器 (UART_Transmitter.v)**：实现并串转换，按起始位+8数据位+偶校验位+停止位格式发送数据。
- **UART 接收器 (UART_Receiver.v)**：实现串并转换，支持16倍过采样和偶校验检测。
- **UART 顶层模块 (UART.v)**：集成波特率生成器、发射器和接收器。
- **回环控制器 (uart_loopback.v)**：接收数据后自动进行大小写转换并回传。

## 文件结构

```
UART.srcs/
├── sources_1/new/                  # 设计源文件
│   ├── UART_BaudGen.v              # 波特率生成器
│   ├── UART_Transmitter.v          # UART 发射器
│   ├── UART_Receiver.v             # UART 接收器
│   ├── UART.v                      # UART 顶层模块
│   └── uart_loopback.v             # 回环控制器
└── sim_1/new/                      # 仿真测试文件
    ├── echo_tb.v                   # 回环功能仿真测试
    └── uart2uart_tb.v              # 双向通信仿真测试
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

通过4位拨码开关 (`freq_ctrl`) 选择波特率：

| freq_ctrl | 波特率 |
|-----------|--------|
| 4'b0000 | 2400 bps |
| 4'b0001 | 4800 bps |
| 4'b0010 | 9600 bps |
| 4'b0011 | 19200 bps |
| 4'b0100 | 57600 bps |
| 4'b0101 | 115200 bps |
| 4'b0110 | 230400 bps |
| 4'b0111 | 460800 bps |
| 4'b1000 | 921600 bps |

### 3. 回环转换规则

| 输入 | 输出 | 说明 |
|------|------|------|
| 'a'-'z' | 'A'-'Z' | 小写转大写 |
| 'A'-'Z' | 'a'-'z' | 大写转小写 |
| 其他字符 | 原样返回 | 不做转换 |

## 运行方法

### 1. 创建 Vivado 工程

1. 打开 Vivado，点击 **Create Project**
2. 选择工程存放路径，**RTL Project**，勾选 **Do not specify sources at this time**
3. 选择目标器件：**xc7a35tcpg236-1**（Basys3）
4. 点击 **Finish**

### 2. 添加源文件

1. 在左侧 Sources 面板中，右键 **Design Sources → Add Sources**
2. 选择 **Add Files**，找到 `UART.srcs/sources_1/new/` 文件夹，选中所有 `.v` 文件
3. 同理，右键 **Simulation Sources → Add Sources**，添加 `sim_1/new/` 下的测试文件

### 3. 运行仿真

在 Flow Navigator 中点击 **Run Simulation → Run Behavioral Simulation**，选择测试文件观察波形。

### 4. 综合、实现、生成比特流

点击 **Generate Bitstream**（会自动完成综合和实现），等待流程完成。

### 5. 下载到 Basys3 板卡

1. 连接 Basys3 开发板到电脑
2. 点击 **Open Hardware Manager → Open Target → Auto Connect**
3. 右键设备，选择 **Program Device**，选择生成的 `.bit` 文件，点击 **Program**

## 作者

- GitHub: [52HZ-GGG](https://github.com/52HZ-GGG)
