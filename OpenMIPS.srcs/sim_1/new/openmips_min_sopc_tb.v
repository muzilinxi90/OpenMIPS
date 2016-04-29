`timescale 1ns / 1ps
//******************************************************************************
//              仿真测试程序test bench
//******************************************************************************

// `include "defines.v"          //ModelSim仿真时去掉注释

module openmips_min_sopc_tb();
    //输入激励
    reg CLOCK;
    reg rst;
    reg[`RegAddrBus] sw;
    reg sw_HL;
    reg write;

    //输出
    wire[`DispDataBus] a_to_g;
    wire dp;
    wire[`DispAnBus] an;

    //每隔5ns，CLOCK信号翻转一次，周期10ns，频率100MHz
    initial begin
        CLOCK = 1'b0;
        forever #5 CLOCK = ~CLOCK;
    end

    //最初时刻，复位信号有效，在第100ns，复位信号无效，最小SOPC开始运行
    //运行1000ns后，停止仿真
    initial begin
        rst = `RstEnable;
        write = 1'b1;
        sw_HL = 1'b0;
        sw = 5'b00001;
        #100 rst = `RstDisable;
        #400 sw_HL = 1'b1;
        #1000 $stop;
    end

    //例化最小SOPC
    openmips_min_sopc openmips_min_sopc0(
        .clk(CLOCK),
        .rst(rst),
        .disp_a_to_g(a_to_g),
        .disp_an(an),
        .dp(dp),
        .sw(sw),
        .sw_HL(sw_HL),
        .write(write)
        );
endmodule
