`timescale 1ns / 1ps
//***************************************************************
//  时钟分频模块测试程序
//***************************************************************


module clk_div_sim();
    reg CLOCK_100;          //模块仿真输入信号用reg型
    reg rst;
    wire clk_div;           //模块仿真输出信号用wire型

    //每隔5ns翻转一次，周期为10ns，频率为100MHz
    initial begin
        CLOCK_100 = 1'b0;
        forever #5 CLOCK_100 = ~CLOCK_100;
    end

    //仿真过程
    initial begin
        rst = `RstEnable;
        #100 rst = `RstDisable;
        #1000 $stop;
    end

    //例化分频器模块
    clk_div clk_div0(
        .rst(rst),
        .clk(CLOCK_100),
        .clk_div(clk_div)
        );
endmodule
