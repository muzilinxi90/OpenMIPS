`timescale 1ns / 1ps
//******************************************************************************
//   暂时保存取指阶段取得的指令以及对应的指令地址，并在下一个时钟传递到译码阶段
//******************************************************************************

`include "defines.v"

module if_id(
    input wire rst,
    input wire clk,

    //来自取指阶段的信号
    input wire[`InstAddrBus] if_pc,
    input wire[`InstBus] if_inst,

    //送往译码阶段的信号
    output reg[`InstAddrBus] id_pc,
    output reg[`InstBus] id_inst,

    //来自ctrl的控制信号
    input wire[5:0] stall,

    //异常相关流水线清除信号
    input wire flush
    );

    always @ ( posedge clk ) begin
        if(rst == `RstEnable) begin
            id_pc <= `ZeroWord;             //复位时pc为0
            id_inst <= `ZeroWord;           //复位时指令为0
        //flush为1表示异常发生，要清除流水线，所以复位id_pc、id_inst寄存器的值
        end else if(flush == 1'b1) begin
            id_pc <= `ZeroWord;
            id_inst <= `ZeroWord;
        //当stall[1]为Stop，stall[2]为NoStop时，表示取指阶段暂停，而译码阶段继续，
        //所以使用空指令作为下一个周期进入译码阶段的指令
        end else if(stall[1] == `Stop && stall[2] == `NoStop) begin
            id_pc <= `ZeroWord;
            id_inst <= `ZeroWord;
        //当stall[1]为NoStop时，取指阶段继续，取得的指令进入译码阶段
        end else if(stall[1] == `NoStop) begin
            id_pc <= if_pc;
            id_inst <= if_inst;
        end
        //其余情况下(流水线暂停)，保持译码阶段的寄存器id_pc、id_inst不变
    end
    
endmodule
