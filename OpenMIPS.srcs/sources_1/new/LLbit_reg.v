`timescale 1ns / 1ps
//******************************************************************************
//                              LLbit寄存器
//******************************************************************************

`include "defines.v"

module LLbit_reg(
    input wire rst,
    input wire clk,
    input wire flush,       //异常是否发生，为1表示异常发生，为0表示没有异常
    input wire we,          //是否要写LLbit寄存器
    input wire LLbit_i,     //要写到LLbit寄存器的值
    output reg LLbit_o      //读端口(LLbit值旁路返回到MEM模块)
    );

    always @ ( posedge clk ) begin
        if(rst == `RstEnable) begin
            LLbit_o <= 1'b0;
        end else if(flush == 1'b1) begin      //如果异常发生，设置LLbit_o为0
            LLbit_o <= 1'b0;
        end else if(we == `WriteEnable) begin
            LLbit_o <= LLbit_i;
        end
    end
    
endmodule
