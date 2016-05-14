`timescale 1ns / 1ps
//********************************************************************
//  将访存阶段的运算结果，在下一个时钟传递到回写阶段
//********************************************************************

`include "defines.v"

module mem_wb(
    input wire clk,
    input wire rst,

    //来自ctrl模块的信息
    input wire[5:0] stall,

    //访存阶段的结果
    input wire[`RegAddrBus] mem_wd,
    input wire mem_wreg,
    input wire[`RegBus] mem_wdata,

    input wire[`RegBus] mem_hi,
    input wire[`RegBus] mem_lo,
    input wire mem_whilo,

    //送到回写阶段的信息
    output reg[`RegAddrBus] wb_wd,
    output reg wb_wreg,
    output reg[`RegBus] wb_wdata,

    output reg[`RegBus] wb_hi,
    output reg[`RegBus] wb_lo,
    output reg wb_whilo,

    //LLbit寄存器相关接口
    input wire mem_LLbit_we,
    input wire mem_LLbit_value,
    output reg wb_LLbit_we,
    output reg wb_LLbit_value,

    //协处理器访问指令相关接口
    input wire mem_cp0_reg_we,
    input wire[4:0] mem_cp0_reg_write_addr,
    input wire[`RegBus] mem_cp0_reg_data,
    output reg wb_cp0_reg_we,
    output reg[4:0] wb_cp0_reg_write_addr,
    output reg[`RegBus] wb_cp0_reg_data
    );

    // 1)当stall[4]为Stop，stall[5]为NoStop时，表示访存阶段暂停，而回写阶段继续，
    // 所以用空指令作为下一个周期进入回写阶段的指令
    // 2)当stall[4]为NoStop时，访存阶段继续，访存后的指令进入回写阶段
    // 3)其余情况下，保持回写阶段寄存器wb_wd、wb_wreg、wb_wdata、wb_hi、wb_lo、
    // wb_whilo不变
    always @ ( posedge clk ) begin
        if(rst == `RstEnable) begin
            wb_wd <= `NOPRegAddr;
            wb_wreg <= `WriteDisable;
            wb_wdata <= `ZeroWord;

            wb_hi <= `ZeroWord;
            wb_lo <= `ZeroWord;
            wb_whilo <= `WriteDisable;

            wb_LLbit_we <= 1'b0;
            wb_LLbit_value <= 1'b0;

            wb_cp0_reg_we <= `WriteDisable;
            wb_cp0_reg_write_addr <= 5'b00000;
            wb_cp0_reg_data <= `ZeroWord;

        end else if(stall[4] == `Stop && stall[5] == `NoStop) begin
            wb_wd <= `NOPRegAddr;
            wb_wreg <= `WriteDisable;
            wb_wdata <= `ZeroWord;

            wb_hi <= `ZeroWord;
            wb_lo <= `ZeroWord;
            wb_whilo <= `WriteDisable;

            wb_LLbit_we <= 1'b0;
            wb_LLbit_value <= 1'b0;

            wb_cp0_reg_we <= `WriteDisable;
            wb_cp0_reg_write_addr <= 5'b00000;
            wb_cp0_reg_data <= `ZeroWord;

        end else if(stall[4] == `NoStop) begin
            wb_wd <= mem_wd;
            wb_wreg <= mem_wreg;
            wb_wdata <= mem_wdata;

            wb_hi <= mem_hi;
            wb_lo <= mem_lo;
            wb_whilo <= mem_whilo;

            wb_LLbit_we <= mem_LLbit_we;
            wb_LLbit_value <= mem_LLbit_value;

            wb_cp0_reg_we <= mem_cp0_reg_we;
            wb_cp0_reg_write_addr <= mem_cp0_reg_write_addr;
            wb_cp0_reg_data <= mem_cp0_reg_data;
        end
    end
endmodule
