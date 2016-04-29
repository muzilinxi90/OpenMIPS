`timescale 1ns / 1ps
//******************************************************************
//  32个寄存器数据显示模块：
//  1.向regfile中输入raddr3(5bit),re3,regfile返回rdata3(32bit)
//  2.5个开关sw0~sw4控制raddr3,sw15控制显示高16位还是低16位
//  3.译码输出给数码管：8位数据位,4位选通位
//  4.时钟为分频后的1000Hz,每1ms刷新一个数码管
//  5.复位时全部点亮
//******************************************************************

`include "defines.v"

//数码管0~F数字编码
`define DISP_0 7'b1000000
`define DISP_1 7'b1111001
`define DISP_2 7'b0100100
`define DISP_3 7'b0110000
`define DISP_4 7'b0011001
`define DISP_5 7'b0010010
`define DISP_6 7'b0000010
`define DISP_7 7'b1111000
`define DISP_8 7'b0000000
`define DISP_9 7'b0010000
`define DISP_A 7'b0001000
`define DISP_b 7'b0000011
`define DISP_C 7'b1000110
`define DISP_d 7'b0100001
`define DISP_E 7'b0000110
`define DISP_F 7'b0001110

`define SW_HIGH 1'b1
`define SW_LOW 1'b0

module regfile_display(
    input wire rst,
    input wire clk,
    //与regfile交换数据相关
    input wire[`RegAddrBus] sw,
    input wire sw_HL,
    input wire[`RegBus] rdata,
    output reg[`RegAddrBus] raddr,
    //与数码管相关
    output reg[`DispDataBus] a_to_g,
    output wire dp,
    output reg[`DispAnBus] an
    );

    //计数器
    reg[1:0] count;
    //高低16位控制寄存器
    reg[15:0] data_HL;
    //转换成数码管编码前的4位二进制数
    reg[3:0] digit;

    //小数点熄灭
    assign dp = 1'b1;

    //从寄存器取数据
    always @ ( * ) begin
        raddr <= sw;
    end

    //计数器计数
    always @ ( posedge clk ) begin
        if(rst == `RstEnable) begin
            count <= 0;
        end else if(count < 3) begin
            count <= count + 1;
        end else begin
            count <= 0;
        end
    end

    //32位数据高低16位选择
    always @ ( * ) begin
        case(sw_HL)
            `SW_LOW: data_HL <= rdata[15:0];
            `SW_HIGH:data_HL <= rdata[31:16];
            default:;
        endcase
    end

    //16位数据中轮到显示的4位选择
    always @ ( * ) begin
        case(count)
            0:digit <= data_HL[3:0];
            1:digit <= data_HL[7:4];
            2:digit <= data_HL[11:8];
            3:digit <= data_HL[15:12];
            default:;
        endcase
    end

    //4位数据译码成数码管编码
    always @ ( * ) begin
        case(digit)
            0:a_to_g <= `DISP_0;
            1:a_to_g <= `DISP_1;
            2:a_to_g <= `DISP_2;
            3:a_to_g <= `DISP_3;
            4:a_to_g <= `DISP_4;
            5:a_to_g <= `DISP_5;
            6:a_to_g <= `DISP_6;
            7:a_to_g <= `DISP_7;
            8:a_to_g <= `DISP_8;
            9:a_to_g <= `DISP_9;
            10:a_to_g <= `DISP_A;
            11:a_to_g <= `DISP_b;
            12:a_to_g <= `DISP_C;
            13:a_to_g <= `DISP_d;
            14:a_to_g <= `DISP_E;
            15:a_to_g <= `DISP_F;
            default:;
        endcase
    end

    //循环刷新的选通信号控制
    always @ ( * ) begin
        case(count)
            0:an <= 4'b1110;
            1:an <= 4'b1101;
            2:an <= 4'b1011;
            3:an <= 4'b0111;
            default:;
        endcase
    end
    //数码管显示
endmodule
