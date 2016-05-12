`timescale 1ns / 1ps
//********************************************************************
//  将执行阶段取得的运算结果，在下一个时钟传递到流水线访存阶段
//********************************************************************

`include "defines.v"

module ex_mem(
    input wire clk,
    input wire rst,

    //来自ctrl的控制信息
    input wire[5:0] stall,

    //来自执行阶段的信息
    input wire[`RegAddrBus] ex_wd,
    input wire ex_wreg,
    input wire[`RegBus] ex_wdata,
    input wire[`RegBus] ex_hi,
    input wire[`RegBus] ex_lo,
    input wire ex_whilo,

    //送到访存阶段的信息
    output reg[`RegAddrBus] mem_wd,
    output reg mem_wreg,
    output reg[`RegBus] mem_wdata,
    output reg[`RegBus] mem_hi,
    output reg[`RegBus] mem_lo,
    output reg mem_whilo,

    //乘累加、乘累减运算数据接口
    input wire[`DoubleRegBus] hilo_i,
    input wire[1:0] cnt_i,
    output reg[`DoubleRegBus] hilo_o,
    output reg[1:0] cnt_o,

    //加载存储指令相关接口
    input wire[`AluOpBus] ex_aluop,
    input wire[`RegBus] ex_mem_addr,
    input wire[`RegBus] ex_reg2,
    output reg[`AluOpBus] mem_aluop,
    output reg[`RegBus] mem_mem_addr,
    output reg[`RegBus] mem_reg2
    );

    // 1)当stall[3]为Stop，stall[4]为NoStop时，表示执行阶段暂停，而访存阶段
    // 继续，所以使用空指令作为下一个周期进入访存阶段的指令;在执行阶段暂停的时候，
    // 将输入信号hilo_i通过输出接口hilo_o送出，输入信号cnt_i通过输出接口cnt_o
    // 送出，其余时刻hilo_o、cnt_o为0
    // 2)当stall[3]为NoStop时，执行阶段继续，执行后的指令进入访存阶段
    // 3)其余情况下，保持访存阶段的寄存器mem_wb、mem_wreg、mem_wdata、mem_hi、
    // mem_lo、mem_whilo不变
    always @ ( posedge clk ) begin
        if(rst == `RstEnable) begin
            mem_wd <= `NOPRegAddr;
            mem_wreg <= `WriteDisable;
            mem_wdata <= `ZeroWord;
            mem_hi <= `ZeroWord;
            mem_lo <= `ZeroWord;
            mem_whilo <= `WriteDisable;
            hilo_o <= {`ZeroWord, `ZeroWord};
            cnt_o <= 2'b00;
            mem_aluop <= `EXE_NOP_OP;
            mem_mem_addr <= `ZeroWord;
            mem_reg2 <= `ZeroWord;
        end else if(stall[3] == `Stop && stall[4] == `NoStop) begin
            mem_wd <= `NOPRegAddr;
            mem_wreg <= `WriteDisable;
            mem_wdata <= `ZeroWord;
            mem_hi <= `ZeroWord;
            mem_lo <= `ZeroWord;
            mem_whilo <= `WriteDisable;
            hilo_o <= hilo_i;
            cnt_o <= cnt_i;
            mem_aluop <= `EXE_NOP_OP;
            mem_mem_addr <= `ZeroWord;
            mem_reg2 <= `ZeroWord;
        end else if(stall[3] == `NoStop) begin
            mem_wd <= ex_wd;
            mem_wreg <= ex_wreg;
            mem_wdata <= ex_wdata;
            mem_hi <= ex_hi;
            mem_lo <= ex_lo;
            mem_whilo <= ex_whilo;
            hilo_o <= {`ZeroWord, `ZeroWord};
            cnt_o <= 2'b00;
            mem_aluop <= ex_aluop;
            mem_mem_addr <= ex_mem_addr;
            mem_reg2 <= ex_reg2;
        end else begin
            hilo_o <= hilo_i;
            cnt_o <= cnt_i;
        end
    end
endmodule
