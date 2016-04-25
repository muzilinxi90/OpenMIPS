`timescale 1ns / 1ps
//******************************************************************
//  顶层模块：CPU + 指令ROM + 数码管显示 + 分频电路
//  最小SOPC实现，实例化OpenMIPS和指令存储器ROM
//******************************************************************

module openmips_min_sopc(
    input wire clk,
    input wire rst,
    //与数码管相连接的输出
    output wire[`DispDataBus] disp_a_to_g,
    output wire[`DispAnBus] disp_an,
    output wire dp,
    //与拨码开关相连接的输入
    input wire[`RegAddrBus] sw,
    input wire sw_HL,
    input wire write
    );

    //连接指令存储器
    wire[`InstAddrBus] inst_addr;
    wire[`InstBus] inst;
    wire rom_ce;

    //连接分频模块
    wire clk_div;

    //连接CPU与数码管译码模块
    wire[`RegBus] reg_display_rdata;
    wire[`RegAddrBus] display_reg_raddr;

    //例化处理器OpenMIPS
    openmips openmips0(
        .clk(clk),
        .rst(rst),
        .rom_addr_o(inst_addr),
        .rom_data_i(inst),
        .rom_ce_o(rom_ce),
        .display_reg_raddr(display_reg_raddr),
        .reg_display_rdata(reg_display_rdata)
        );

    //例化指令存储器ROM
    inst_rom inst_rom0(
        .ce(rom_ce),
        .addr(inst_addr),
        .inst(inst),
        .write(write)
        );

    //例化分频器模块
    clk_div clk_div0(
        .rst(rst),
        .clk(clk),
        .clk_div(clk_div)
        );

    //例化数码管译码模块
    regfile_display regfile_display0(
        .rst(rst),
        .clk(clk_div),
        .sw(sw),
        .sw_HL(sw_HL),
        .rdata(reg_display_rdata),
        .raddr(display_reg_raddr),
        .a_to_g(disp_a_to_g),
        .dp(dp),
        .an(disp_an)
        );

endmodule
