`timescale 1ns / 1ps
//***********************************************
//  将译码阶段取得的运算类型、源操作数、要写的目的
//  寄存器地址等结果，在下一个时钟传递到流水线执行
//***********************************************

`include "defines.v"

module id_ex(
    input wire clk,
    input wire rst,

    //来自ctrl模块的信息
    input wire[5:0] stall,

    //从译码阶段传递过来的信息
    input wire[`AluSelBus] id_alusel,   //译码阶段指令运算类型
    input wire[`AluOpBus] id_aluop,     //译码阶段指令运算子类型
    input wire[`RegBus] id_reg1,        //译码阶段指令源操作数1
    input wire[`RegBus] id_reg2,        //译码阶段指令源操作数2
    input wire[`RegAddrBus] id_wd,      //译码阶段指令目的寄存器地址
    input wire id_wreg,                 //译码阶段指令是否有目的寄存器

    //传递到执行阶段的信息
    output reg[`AluSelBus] ex_alusel,   //执行阶段指令运算类型
    output reg[`AluOpBus] ex_aluop,     //执行阶段指令运算子类型
    output reg[`RegBus] ex_reg1,        //执行阶段指令源操作数1
    output reg[`RegBus] ex_reg2,        //执行阶段指令源操作数2
    output reg[`RegAddrBus] ex_wd,      //执行阶段指令目的寄存器地址
    output reg ex_wreg                  //执行阶段指令是否有目的寄存器
    );

    // 1.当stall[2]为Stop，stall[3]为NoStop时，表示译码阶段暂停，而执行阶段
    // 继续，所以使用空指令作为下一个周期进入执行阶段的指令
    // 2.当stall[2]为NoStop时，译码阶段继续，译码后的指令进入执行阶段
    // 3.其余情况下，保持执行阶段的寄存器ex_aluop、ex_alusel、ex_reg1、ex_reg2、
    // ex_wd、ex_wreg不变
    always @ ( posedge clk ) begin
        if(rst == `RstEnable) begin
            ex_aluop <= `EXE_NOP_OP;
            ex_alusel <= `EXE_RES_NOP;
            ex_reg1 <= `ZeroWord;
            ex_reg2 <= `ZeroWord;
            ex_wd <= `NOPRegAddr;
            ex_wreg <= `WriteDisable;
        end else if(stall[2] == `Stop && stall[3] == `NoStop) begin
            ex_aluop <= `EXE_NOP_OP;
            ex_alusel <= `EXE_RES_NOP;
            ex_reg1 <= `ZeroWord;
            ex_reg2 <= `ZeroWord;
            ex_wd <= `NOPRegAddr;
            ex_wreg <= `WriteDisable;
        end else if(stall[2] == `NoStop) begin
            ex_aluop <= id_aluop;
            ex_alusel <= id_alusel;
            ex_reg1 <= id_reg1;
            ex_reg2 <= id_reg2;
            ex_wd <= id_wd;
            ex_wreg <= id_wreg;
        end
    end
endmodule
