`timescale 1ns / 1ps
//********************************************************************
//  目前ori指令不需要访问数据存储器，此阶段只是简单地将执行结果向回写传递
//********************************************************************

module mem(
    input wire rst,

    //来自执行阶段的信息
    input wire[`RegAddrBus] wd_i,
    input wire wreg_i,
    input wire[`RegBus] wdata_i,

    //访存阶段结果
    output reg[`RegAddrBus] wd_o,
    output reg wreg_o,
    output reg[`RegBus] wdata_o
    );

    always @ ( * ) begin
        if(rst == `RstEnable) begin
            wd_o <= `NOPRegAddr;
            wreg_o <= `WriteDisable;
            wdata_o <= `ZeroWord;
        end else begin
            wd_o <= wd_i;
            wreg_o <= wreg_i;
            wdata_o <= wdata_i;
        end
    end
endmodule
