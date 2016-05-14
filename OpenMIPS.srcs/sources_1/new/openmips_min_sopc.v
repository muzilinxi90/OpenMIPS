`timescale 1ns / 1ps
//******************************************************************
//  顶层模块：CPU + 指令ROM + 数码管显示 + 分频电路
//  最小SOPC实现，实例化OpenMIPS和指令存储器ROM
//******************************************************************

`include "defines.v"

module openmips_min_sopc(
    input wire clk,
    input wire rst,

    //与数码管相连接的输出
    output wire[`DispDataBus] disp_a_to_g,
    output wire[`DispAnBus] disp_an,
    output wire dp,
    //与拨码开关相连接的输入
    input wire[`RegAddrBus] sw,
    input wire sw_HL
    );

    //连接指令存储器ROM
    wire[`InstAddrBus] inst_addr;
    wire[`InstBus] inst;
    wire rom_ce;

    //连接数据存储器RAM
    wire mem_ce_i;
    wire mem_we_i;
    wire[`DataAddrBus] mem_addr_i;
    wire[`DataBus] mem_data_i;
    wire[`DataBus] mem_data_o;
    wire[3:0] mem_sel_i;

    //外部中断和时钟中断
    wire[5:0] int;
    wire timer_int;

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

        .ram_ce_o(mem_ce_i),
        .ram_we_o(mem_we_i),
        .ram_addr_o(mem_addr_i),
        .ram_data_o(mem_data_i),
        .ram_data_i(mem_data_o),
        .ram_sel_o(mem_sel_i),

        .display_reg_raddr(display_reg_raddr),
        .reg_display_rdata(reg_display_rdata),

        .int_i(int),
        .timer_int_o(timer_int)
        );

    //例化指令存储器ROM
    inst_rom inst_rom0(
        .ce(rom_ce),
        .addr(inst_addr),
        .inst(inst)
        );

    //例化数据存储器RAM
    data_ram data_ram0(
        .clk(clk),
        .ce(mem_ce_i),
        .we(mem_we_i),
        .addr(mem_addr_i),
        .data_i(mem_data_i),
        .data_o(mem_data_o),
        .sel(mem_sel_i)
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
