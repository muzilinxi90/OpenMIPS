`timescale 1ns / 1ps
//**********************************************
//暂时保存取指阶段取得的指令，以及对应的指令地址，
//并在下一个时钟传递到译码阶段
//**********************************************

module if_id(
    input wire clk,
    input wire rst,

    //来自取指阶段的信号
    input wire[`InstAddrBus] if_pc,
    input wire[`InstBus] if_inst,

    //对应译码阶段的信号
    output reg[`InstAddrBus] id_pc,
    output reg[`InstBus] id_inst
    );

    always @ ( posedge clk ) begin
        if(rst == `RstEnable) begin
            id_pc <= `ZeroWord;             //复位时pc为0
            id_inst <= `ZeroWord;           //复位时指令为0
        end else begin
            id_pc <= if_pc;
            id_inst <= if_inst;
        end
    end
endmodule
