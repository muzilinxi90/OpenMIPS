`timescale 1ns / 1ps
//*****************************************************************
//      指令存储器ROM
//*****************************************************************

`include "defines.v"

module inst_rom(
    input wire ce,
    input wire[`InstAddrBus] addr,
    output reg[`InstBus] inst
    );

    //定义一个数组，大小是InstMemNum,元素宽度是InstBus
    //共4*1024个32位字，128KB空间
    reg[`InstBus] inst_mem[0:`InstMemNum-1];

    //使用文件inst_rom.data初始化指令存储器，用于仿真模块中对激励向量的描述，
    //inst_rom.txt是一个文本文件，里面每行存储一条32位宽度的指令（十六进制），
    //系统函数$readmemh将inst_rom.txt中的数据一次填写到inst_mem数组中
    //如果要综合，需要修改这里初始化存储器的方法
    initial $readmemh("C:/Users/LMX/Desktop/MyProject/TestFile/TimerIntTest.data",inst_mem);

    //板级测试，程序写死在ROM中
    // always @ ( * ) begin
    //     inst_mem[0] <= 32'h3401_1234;
    //     inst_mem[1] <= 32'h3402_8765;
    //     inst_mem[2] <= 32'h0002_1C00;
    //     inst_mem[3] <= 32'h0003_2403;
    //     inst_mem[4] <= 32'h0024_2820;
    //     inst_mem[5] <= 32'h0024_3022;
    //     inst_mem[6] <= 32'h0024_0018;
    //     inst_mem[7] <= 32'h0000_3810;
    //     inst_mem[8] <= 32'h0000_4012;
    //     inst_mem[9] <= 32'h0081_001A;
    //     inst_mem[10] <= 32'h0000_4810;
    //     inst_mem[11] <= 32'h0000_5012;
    // end

    //当复位信号无效时，依据输入的地址，给出指令存储器ROM中对应的元素
    always @ ( * ) begin
        if(ce == `ChipDisable) begin
            inst <= `ZeroWord;
        end else begin
            //地址是按字节的，因此指令地址从地址线第2位到第19位，
            //指令有四个字节，指令内字节地址为0~1位
            inst <= inst_mem[addr[`InstRealAddrBus-1:2]];
        end
    end
endmodule
