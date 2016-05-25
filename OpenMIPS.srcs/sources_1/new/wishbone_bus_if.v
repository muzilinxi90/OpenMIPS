`timescale 1ns / 1ps
//******************************************************************************
//                          Wishbone总线接口模块
//  整个模块可以分为两个部分：与CPU交互的组合逻辑电路部分，以及与外设交互的时序逻辑电路
//部分，二者一并组成了Wishbone总线接口
//******************************************************************************

`include "defines.v"

module wishbone_bus_if(
    input wire rst,
    input wire clk,

    //与CTRL模块的接口
    input wire[5:0] stall_i,                //CTRL模块传入的流水线暂停信号
    input wire flush_i,                     //CTRL模块传入的流水线清除信号
    output reg stallreq,                    //请求流水线暂停的信号

    //CPU侧接口
    input wire cpu_ce_i,                    //来自处理器的访问请求信号
    input wire cpu_we_i,                    //来自处理器的读写操作指示信号
    input wire[3:0] cpu_sel_i,              //来自处理器的字节选择信号
    input wire[`RegBus] cpu_addr_i,         //来自处理器的地址信号
    input wire[`RegBus] cpu_data_i,         //来自处理器的数据
    output reg[`RegBus] cpu_data_o,         //输出到处理器的数据

    //Wishbone侧接口
    output reg[`RegBus] wishbone_addr_o,    //Wishbone总线输出的地址
    input wire[`RegBus] wishbone_data_i,    //Wishbone总线输入的数据
    output reg[`RegBus] wishbone_data_o,    //Wishbone总线输出的数据
    output reg wishbone_we_o,               //Wishbone总线写使能信号
    output reg[3:0] wishbone_sel_o,         //Wishbone总线字节选择信号
    output reg wishbone_cyc_o,              //Wishbone总线周期信号
    output reg wishbone_stb_o,              //Wishbone总线选通信号
    input wire wishbone_ack_i               //Wishbone总线操作成功响应信号
    );

    reg[1:0] wishbone_state;                //保存Wishbone总线接口模块的状态
    reg[`RegBus] rd_buf;                    //寄存通过Wishbone总线访问到的数据(读缓存)

//******************************************************************************
//               第一段：控制状态转化的时序电路(与外设的接口部分)
//******************************************************************************
    always @ ( posedge clk ) begin
        if(rst == `RstEnable) begin
            wishbone_state <= `WB_IDLE;     //进入空闲状态
            wishbone_addr_o <= `ZeroWord;
            wishbone_data_o <= `ZeroWord;
            wishbone_we_o <= `WriteDisable;
            wishbone_sel_o <= 4'b0000;
            wishbone_cyc_o <= 1'b0;
            wishbone_stb_o <= 1'b0;
            rd_buf <= `ZeroWord;
        end else begin
            case(wishbone_state)
                `WB_IDLE:begin              //空闲状态
                    if((cpu_ce_i == 1'b1) && (flush_i == `False_v)) begin
                        wishbone_addr_o <= cpu_addr_i;
                        wishbone_data_o <= cpu_data_i;
                        wishbone_we_o <= cpu_we_i;
                        wishbone_sel_o <= cpu_sel_i;
                        wishbone_cyc_o <= 1'b1;
                        wishbone_stb_o <= 1'b1;
                        rd_buf <= `ZeroWord;
                        wishbone_state <= `WB_BUSY;         //进入总线忙状态
                    end
                end
                `WB_BUSY:begin              //总线忙状态
                    if(wishbone_ack_i == 1'b1) begin
                        //从设备返回ACK为1时表示准备好数据，主设备检测到后采样数据，
                        //撤销选通信号和总线周期信号，完成读数据的过程
                        if(cpu_we_i == `WriteDisable) begin
                            rd_buf <= wishbone_data_i;
                        end
                        //读写操作共有的过程
                        wishbone_stb_o <= 1'b0;
                        wishbone_cyc_o <= 1'b0;
                        wishbone_addr_o <= `ZeroWord;
                        wishbone_data_o <= `ZeroWord;
                        wishbone_we_o <= `WriteDisable;
                        wishbone_sel_o <= 4'b0000;
                        //状态转换
                        wishbone_state <= `WB_IDLE;         //进入空闲状态
                        if(stall_i != 6'b000000) begin
                            wishbone_state <= `WB_WAIT_FOR_STALL;   //进入等待暂停结束状态
                        end
                    //还没有收到总线响应时发生了异常，导致处理器要清除流水线
                    end else if(flush_i == `True_v) begin
                        wishbone_stb_o <= 1'b0;
                        wishbone_cyc_o <= 1'b0;
                        wishbone_addr_o <= `ZeroWord;
                        wishbone_data_o <= `ZeroWord;
                        wishbone_we_o <= `WriteDisable;
                        wishbone_sel_o <= 4'b0000;
                        rd_buf <= `ZeroWord;
                        wishbone_state <= `WB_IDLE;         //进入空闲状态
                    end
                end
                `WB_WAIT_FOR_STALL:begin                    //进入等待暂停结束状态
                    if(stall_i == 6'b000000) begin
                        wishbone_state <= `WB_IDLE;         //暂停结束进入空闲状态
                    end
                end
                default:begin
                end
            endcase
        end//else
    end//always


//******************************************************************************
//           第二段：给处理器接口信号赋值的组合电路(与CPU的接口部分)
//******************************************************************************
    always @ ( * ) begin
        if(rst == `RstEnable) begin
            stallreq <= `NoStop;
            cpu_data_o <= `ZeroWord;
        end else begin
            stallreq <= `NoStop;
            case(wishbone_state)
                `WB_IDLE:begin                          //空闲状态
                    //需要暂停流水线以等待总线访问结束
                    if((cpu_ce_i == 1'b1) && (flush_i == `False_v)) begin
                        stallreq <= `Stop;
                        cpu_data_o <= `ZeroWord;
                    end
                end
                `WB_BUSY:begin                          //总线忙状态
                    //收到从设备响应，表示总线访问结束，流水线继续
                    if(wishbone_ack_i == 1'b1) begin
                        stallreq <= `NoStop;
                        //读操作
                        if(wishbone_we_o == `WriteDisable) begin
                            //这里应该是rd_buf???还是不需要暂停的读操作???
                            cpu_data_o <= wishbone_data_i;
                        //写操作
                        end else begin
                            cpu_data_o <= `ZeroWord;
                        end
                    //未收到从设备响应，表示总线访问还未结束，保持流水线暂停
                    end else begin
                        stallreq <= `Stop;
                        cpu_data_o <= `ZeroWord;
                    end
                end
                `WB_WAIT_FOR_STALL:begin                //等待暂停结束状态
                    //此时总线访问已经结束，所以继续流水线
                    stallreq <= `NoStop;
                    cpu_data_o <= rd_buf;
                end
                default:begin
                end
            endcase
        end//else
    end//always

endmodule
