`timescale 1ns / 1ps
//******************    给出指令地址    ***********************

`include "defines.v"

module pc_reg(
    input wire clk,                     //时钟信号
    input wire rst,                     //复位信号

    //来自控制模块ctrl
    input wire[5:0] stall,

    //来自ID模块的信息(转移指令相关)
    input wire branch_flag_i,
    input wire[`RegBus] branch_target_address_i,

    output reg[`InstAddrBus] pc,        //要读取的指令地址
    output reg ce                       //指令存储器使能信号
    );

    always @ ( posedge clk ) begin
        if(rst == `RstEnable) begin
            ce <= `ChipDisable;         //复位时指令存储器禁用
        end else begin
            ce <= `ChipEnable;          //复位结束后，指令存储器使能
        end
    end

    //当stall[0]为NoStop时，PC加4，否则保持PC不变
    always @ ( posedge clk ) begin
        if(ce == `ChipDisable) begin
            pc <= 32'h0000_0000;        //指令存储器禁用的时，PC为0
        end else if(stall[0] == `NoStop) begin
            if(branch_flag_i == `Branch) begin
                pc <= branch_target_address_i;
            end else begin
                pc <= (pc + 32'h4);     //指令存储器使能时，PC值每时钟周期增加4
            end
        end
    end

endmodule
