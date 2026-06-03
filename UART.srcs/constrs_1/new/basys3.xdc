## Basys3 约束文件 - UART 回环设计
## 适用于 xc7a35tcpg236-1 (Basys3)

## 时钟信号 (100MHz) - Pin W5
set_property PACKAGE_PIN W5 [get_ports Clock]
set_property IOSTANDARD LVCMOS33 [get_ports Clock]
create_clock -period 10.000 -name sys_clk -waveform {0.000 5.000} [get_ports Clock]

## 复位按钮 (btnC) - Pin U18
set_property PACKAGE_PIN U18 [get_ports Reset]
set_property IOSTANDARD LVCMOS33 [get_ports Reset]

## 拨码开关 SW0-SW3 (freq_ctrl[3:0])
set_property PACKAGE_PIN V17 [get_ports {freq_ctrl[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {freq_ctrl[0]}]

set_property PACKAGE_PIN V16 [get_ports {freq_ctrl[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {freq_ctrl[1]}]

set_property PACKAGE_PIN W16 [get_ports {freq_ctrl[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {freq_ctrl[2]}]

set_property PACKAGE_PIN W17 [get_ports {freq_ctrl[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {freq_ctrl[3]}]

## UART 引脚 (通过板载 USB-UART 桥接芯片 FTDI)
## TxD: FPGA -> PC (Pin A18)
set_property PACKAGE_PIN A18 [get_ports TxD]
set_property IOSTANDARD LVCMOS33 [get_ports TxD]

## RxD: PC -> FPGA (Pin B18)
set_property PACKAGE_PIN B18 [get_ports RxD]
set_property IOSTANDARD LVCMOS33 [get_ports RxD]

## 调试LED (LD0-LD15)
## LEDS[7:0] = Din (转换后发出的数据) - LD0~LD7
set_property PACKAGE_PIN U16 [get_ports {LEDS[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {LEDS[0]}]
set_property PACKAGE_PIN E19 [get_ports {LEDS[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {LEDS[1]}]
set_property PACKAGE_PIN U19 [get_ports {LEDS[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {LEDS[2]}]
set_property PACKAGE_PIN V19 [get_ports {LEDS[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {LEDS[3]}]
set_property PACKAGE_PIN W18 [get_ports {LEDS[4]}]
set_property IOSTANDARD LVCMOS33 [get_ports {LEDS[4]}]
set_property PACKAGE_PIN U15 [get_ports {LEDS[5]}]
set_property IOSTANDARD LVCMOS33 [get_ports {LEDS[5]}]
set_property PACKAGE_PIN U14 [get_ports {LEDS[6]}]
set_property IOSTANDARD LVCMOS33 [get_ports {LEDS[6]}]
set_property PACKAGE_PIN V14 [get_ports {LEDS[7]}]
set_property IOSTANDARD LVCMOS33 [get_ports {LEDS[7]}]
## LEDS[15:8] = latched_data (收到的原始数据) - LD8~LD15
set_property PACKAGE_PIN V13 [get_ports {LEDS[8]}]
set_property IOSTANDARD LVCMOS33 [get_ports {LEDS[8]}]
set_property PACKAGE_PIN V3 [get_ports {LEDS[9]}]
set_property IOSTANDARD LVCMOS33 [get_ports {LEDS[9]}]
set_property PACKAGE_PIN W3 [get_ports {LEDS[10]}]
set_property IOSTANDARD LVCMOS33 [get_ports {LEDS[10]}]
set_property PACKAGE_PIN U3 [get_ports {LEDS[11]}]
set_property IOSTANDARD LVCMOS33 [get_ports {LEDS[11]}]
set_property PACKAGE_PIN P3 [get_ports {LEDS[12]}]
set_property IOSTANDARD LVCMOS33 [get_ports {LEDS[12]}]
set_property PACKAGE_PIN N3 [get_ports {LEDS[13]}]
set_property IOSTANDARD LVCMOS33 [get_ports {LEDS[13]}]
set_property PACKAGE_PIN P1 [get_ports {LEDS[14]}]
set_property IOSTANDARD LVCMOS33 [get_ports {LEDS[14]}]
set_property PACKAGE_PIN L1 [get_ports {LEDS[15]}]
set_property IOSTANDARD LVCMOS33 [get_ports {LEDS[15]}]

## 配置电压标准 (必须设置)
set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]

## BITSTREAM 配置
set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]
set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 4 [current_design]
