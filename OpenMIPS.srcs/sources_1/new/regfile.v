`timescale 1ns / 1ps
//******************************************************************************
//  32个32位通用整数寄存器，可以同时进行两个寄存器的读操作和一个寄存器的写操作
//******************************************************************************

`include "defines.v"

module regfile(
    input wire rst,
    input wire clk,

    //写端口
    input wire we,
    input wire[`RegAddrBus] waddr,
    input wire[`RegBus] wdata,

    //读端口1
    input wire re1,
    input wire[`RegAddrBus] raddr1,
    output reg[`RegBus] rdata1,

    //读端口2
    input wire re2,
    input wire[`RegAddrBus] raddr2,
    output reg[`RegBus] rdata2
    );

//******************************************************************************
//  第一段：定义32个32位通用寄存器
//******************************************************************************
    reg[`RegBus] regs[0:`RegNum-1];

//******************************************************************************
//  第二段：写操作(回写阶段也在此)
//  MIPS32架构规定$0的值为硬件连线至0，所以不要写入
//  写操作是时序逻辑电路，发生在时钟信号上升沿
//******************************************************************************
    always @ ( posedge clk ) begin
        if(rst == `RstDisable) begin
            if((we == `WriteEnable) && (waddr != `RegNumLog2'b0)) begin
                regs[waddr] <= wdata;
            end
        end
    end

//******************************************************************************
//  第三段：读端口1的读操作
//  读寄存器操作是组合逻辑电路，也就是一旦输入的要读取寄存器地址raddr1或者raddr2发生变
//  化，那么会立即给出新地址对应的寄存器的值
//******************************************************************************
    always @ ( * ) begin
        if(rst == `RstEnable) begin
            rdata1 <= `ZeroWord;
        end else if(raddr1 == `RegNumLog2'b0) begin
            rdata1 <= `ZeroWord;
        //此处解决了相隔两条指令的RAW数据相关
        end else if((raddr1 == waddr) && (we == `WriteEnable) && (re1 == `ReadEnable)) begin
            rdata1 <= wdata;
        end else if(re1 == `ReadEnable) begin
            rdata1 <= regs[raddr1];
        end else begin
            rdata1 <= `ZeroWord;
        end
    end

//******************************************************************************
//  第四段：读端口2的读操作
//******************************************************************************
    always @ ( * ) begin
        if(rst == `RstEnable) begin
            rdata2 <= `ZeroWord;
        end else if(raddr2 == `RegNumLog2'b0) begin
            rdata2 <= `ZeroWord;
        //此处解决了相隔两条指令的RAW数据相关
        end else if((raddr2 == waddr) && (we == `WriteEnable) && (re2 == `ReadEnable)) begin
            rdata2 <= wdata;
        end else if(re2 == `ReadEnable) begin
            rdata2 <= regs[raddr2];
        end else begin
            rdata2 <= `ZeroWord;
        end
    end

endmodule
