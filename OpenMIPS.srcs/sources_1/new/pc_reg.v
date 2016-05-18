`timescale 1ns / 1ps
//******************************************************************************
//                        程序计数器PC，给出指令地址
//******************************************************************************

`include "defines.v"

module pc_reg(
    input wire rst,                     //复位信号
    input wire clk,                     //时钟信号

    output reg ce,                      //指令存储器使能信号
    output reg[`InstAddrBus] pc,        //要读取的指令地址

    //来自控制模块ctrl
    input wire[5:0] stall,

    //来自ID模块的信息(转移指令相关)
    input wire branch_flag_i,
    input wire[`InstAddrBus] branch_target_address_i,

    //异常处理相关
    input wire flush,                   //流水线清除信号
    input wire[`InstAddrBus] new_pc     //异常处理例程入口地址
    );

    always @ ( posedge clk ) begin
        if(rst == `RstEnable) begin
            ce <= `ChipDisable;         //复位时指令存储器禁用
        end else begin
            ce <= `ChipEnable;          //复位结束后，指令存储器使能
        end
    end


    always @ ( posedge clk ) begin
        //指令存储器禁用的时，PC为0
        if(ce == `ChipDisable) begin
            pc <= 32'h0000_0000;
        //指令存储器使能时
        end else begin
            //输入信号flush为1表示异常发生，将从CTRL模块给出的异常处理例程入口地址
            //new_pc处取指执行
            if(flush == 1'b1) begin
                pc <= new_pc;
            //当stall[0]为NoStop时，PC加4或跳转；否则保持PC不变(流水线暂停)
            end else if(stall[0] == `NoStop) begin
                if(branch_flag_i == `Branch) begin
                    pc <= branch_target_address_i;
                end else begin
                    pc <= (pc + 32'h4);
                end
            end//else if(stall[0] == `NoStop)
        end//else(ce == `ChipEnable)
    end//always

endmodule
