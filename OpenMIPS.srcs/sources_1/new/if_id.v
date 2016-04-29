`timescale 1ns / 1ps
//**********************************************
//暂时保存取指阶段取得的指令，以及对应的指令地址，
//并在下一个时钟传递到译码阶段
//**********************************************

`include "defines.v"

module if_id(
    input wire clk,
    input wire rst,

    //来自ctrl的控制信号
    input wire[5:0] stall,

    //来自取指阶段的信号
    input wire[`InstAddrBus] if_pc,
    input wire[`InstBus] if_inst,

    //对应译码阶段的信号
    output reg[`InstAddrBus] id_pc,
    output reg[`InstBus] id_inst
    );

    // 1)当stall[1]为Stop，stall[2]为NoStop时，表示取指阶段暂停，而译码阶段继续，
    // 所以使用空指令作为下一个周期进入译码阶段的指令
    // 2)当stall[1]为NoStop时，取指阶段继续，取得的指令进入译码阶段
    // 3)其余情况下，保持译码阶段的寄存器id_pc、id_inst不变
    always @ ( posedge clk ) begin
        if(rst == `RstEnable) begin
            id_pc <= `ZeroWord;             //复位时pc为0
            id_inst <= `ZeroWord;           //复位时指令为0
        end else if(stall[1] == `Stop && stall[2] == `NoStop) begin
            id_pc <= `ZeroWord;
            id_inst <= `ZeroWord;
        end else if(stall[1] == `NoStop) begin
            id_pc <= if_pc;
            id_inst <= if_inst;
        end
    end
endmodule
