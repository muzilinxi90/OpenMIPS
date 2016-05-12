`timescale 1ns / 1ps
//******************************************************************************
//                              数据存储器RAM
// 设计时使用4个8位存储器代替一个32位存储器。读操作时，从4个8位存储器中各读出一个字节，
// 组合为一个32位的数据输出(地址对齐)；写操作时，依据sel的值，修改其中特定存储器对应的
// 字节即可，因此地址addr的最低两位不需要使用。
// 其中data_mem3是一个字内的低地址，最低两位为00，data_mem0是一个字内的高地址，最低
// 两位为11
//******************************************************************************

`include "defines.v"

module data_ram(
    input wire clk,
    input wire ce,          //数据存储器使能信号
    input wire we,          //是否是写操作，为1表示写操作
    input wire[`DataAddrBus] addr,
    input wire[3:0] sel,
    input wire[`DataBus] data_i,
    output reg[`DataBus] data_o
    );

    //定义四个字节数组
    reg[`ByteWidth] data_mem0[0:`DataMemNum-1];
    reg[`ByteWidth] data_mem1[0:`DataMemNum-1];
    reg[`ByteWidth] data_mem2[0:`DataMemNum-1];
    reg[`ByteWidth] data_mem3[0:`DataMemNum-1];

    //写操作
    always @ ( posedge clk ) begin
        if(ce == `ChipDisable) begin
            data_o <= `ZeroWord;
        end else if(we == `WriteEnable) begin
            if(sel[3] == 1'b1) begin
                data_mem3[addr[`DataMemNumLog2+1:2]] <= data_i[31:24];
            end
            if(sel[2] == 1'b1) begin
                data_mem2[addr[`DataMemNumLog2+1:2]] <= data_i[23:16];
            end
            if(sel[1] == 1'b1) begin
                data_mem1[addr[`DataMemNumLog2+1:2]] <= data_i[15:8];
            end
            if(sel[0] == 1'b1) begin
                data_mem0[addr[`DataMemNumLog2+1:2]] <= data_i[7:0];
            end
        end
    end

    //读操作：不管读地址是什么，均送出对齐地址的一个字
    always @ ( * ) begin
        if(ce == `ChipDisable) begin
            data_o <= `ZeroWord;
        end else if(we == `WriteDisable) begin
            data_o <= {data_mem3[addr[`DataMemNumLog2+1:2]],
                    data_mem2[addr[`DataMemNumLog2+1:2]],
                    data_mem1[addr[`DataMemNumLog2+1:2]],
                    data_mem0[addr[`DataMemNumLog2+1:2]]};
        end else begin
            data_o <= `ZeroWord;
        end
    end

endmodule
