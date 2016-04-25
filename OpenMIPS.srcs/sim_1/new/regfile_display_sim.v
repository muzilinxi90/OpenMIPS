`timescale 1ns / 1ps
//*****************************************************************
//  regfile数据显示模块测试
//*****************************************************************

module regfile_display_sim(

    );
    reg CLOCK;
    reg rst;
    reg[`RegAddrBus] sw;
    reg sw_HL;
    reg[`RegBus] rdata;
    wire[`RegAddrBus] raddr;
    wire[6:0] a_to_g;
    wire dp;
    wire[3:0] an;

    initial begin
        CLOCK = 1'b0;
        forever #5 CLOCK = ~CLOCK;
    end

    initial begin
        rst = `RstEnable;
        sw_HL = 1'b0;
        #100 rst = `RstDisable;
        #0 rdata = 32'h7654_3210;
        #400 sw_HL = 1'b1;
        #1000 $stop;
    end

    //例化模块
    regfile_display regfile_display0(
        .rst(rst),
        .clk(CLOCK),
        .sw(sw),
        .sw_HL(sw_HL),
        .rdata(rdata),
        .raddr(raddr),
        .a_to_g(a_to_g),
        .dp(dp),
        .an(an)
        );
endmodule
