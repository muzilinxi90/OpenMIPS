`timescale 1ns / 1ps
//******************************************************************
//  时钟分频模块：将输入时钟分频为1000Hz(周期1ms)，用于刷新数码管
//  目前芯片的输入时钟为100MHz(PIN W5)
//******************************************************************
`define N 100000
// `define N 2                             //仿真

module clk_div(
    input wire rst,
    input wire clk,
    output reg clk_div
    );

    reg[31:0] count;                    //32位计数器

    always @ ( posedge clk) begin
        if(rst == `RstEnable) begin
            count <= 0;
            clk_div <= 1'b0;
        end
        else if(count < `N-1) begin
            count <= count + 1'b1;
        end
        else begin
            count <= 0;
            clk_div <= ~clk_div;
        end
    end
endmodule
