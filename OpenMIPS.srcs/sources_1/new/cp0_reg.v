`timescale 1ns / 1ps

//******************************************************************************
//                              协处理器CP0
//  只实现了CP0中的Count、Compare、Status、Cause、EPC、PRId、Config7个寄存器的部分
//功能
//******************************************************************************

`include "defines.v"

module cp0_reg(
    input wire rst,
    input wire clk,

    input wire we_i,                //是否要写CP0中的寄存器
    input wire[4:0] waddr_i,        //要写入的CP0寄存器的地址
    input wire[`RegBus] data_i,     //要写入CP0中寄存器的数据

    input wire[4:0] raddr_i,        //要读取的CP0寄存器的地址
    output reg[`RegBus] data_o,     //读出的CP0某个寄存器的值

    input wire[5:0] int_i,          //6个外部硬件中断输入

    output reg[`RegBus] count_o,    //Count寄存器的值
    output reg[`RegBus] compare_o,  //Compare寄存器的值
    output reg[`RegBus] status_o,   //Status寄存器的值
    output reg[`RegBus] cause_o,    //Cause寄存器的值
    output reg[`RegBus] epc_o,      //EPC寄存器的值
    output reg[`RegBus] config_o,   //Config寄存器的值
    output reg[`RegBus] prid_o,     //PRId寄存器的值

    output reg timer_int_o,         //是否有定时中断发生

    //异常相关输入接口
    input wire[31:0] excepttype_i,              //最终的异常类型
    input wire[`RegBus] current_inst_addr_i,    //发生异常的指令地址
    input wire is_in_delayslot_i                //发生异常的指令是否是延迟槽指令
    );

//******************************************************************************
//                     对CP0中寄存器的写操作：时序逻辑
//  PRId、Config不可以写，Cause寄存器只有其中的IP[1:0]、IV、WP三个字段可写
//******************************************************************************
    always @ ( posedge clk ) begin
        if(rst == `RstEnable) begin

            //Count寄存器的初始值
            count_o <= `ZeroWord;

            //Compare寄存器的初始值
            compare_o <= `ZeroWord;

            //Status寄存器的初始值：其中CU字段为0001，表示协处理器CP0存在
            status_o <= 32'b0001_0000_0000_0000_0000_0000_0000_0000;

            //Cause寄存器的初始值
            cause_o <= `ZeroWord;

            //EPC寄存器的初始值
            epc_o <= `ZeroWord;

            //Config寄存器的初始值：其中BE字段为1，表示工作在大端模式(MSB)
            config_o <= 32'b0000_0000_0000_0000_1000_0000_0000_0000;

            //PRId寄存器的初始值：其中制作者是L，对应的是0x48(自行定义的)；
            //类型是0x1，表示是基本类型；版本号是1.0
            prid_o <= 32'b0000_0000_0100_1100_0000_0001_0000_0010;

            timer_int_o <= `InterruptNotAssert;

        end else begin

            count_o <= count_o + 1;      //Count寄存器的值在每个时钟周期加1
            cause_o[15:10] <= int_i;     //Cause寄存器的10-15位保存外部中断声明

            //当Compare寄存器不为0，且Count寄存器的值等于Compare寄存器的值时，
            //将输出信号timer_int_o置为1，表示时钟中断发生
            if(compare_o != `ZeroWord && count_o == compare_o) begin
                timer_int_o <= `InterruptAssert;
            end

            if(we_i == `WriteEnable) begin
                case(waddr_i)
                    `CP0_REG_COUNT:begin            //写Count寄存器
                        count_o <= data_i;
                    end
                    `CP0_REG_COMPARE:begin          //写Compare寄存器
                        compare_o <= data_i;
                        //表示取消时钟中断的声明
                        timer_int_o <= `InterruptNotAssert;
                    end
                    `CP0_REG_STATUS:begin           //写Status寄存器
                        status_o <= data_i;
                    end
                    `CP0_REG_EPC:begin              //写EPC寄存器
                        epc_o <= data_i;
                    end
                    `CP0_REG_CAUSE:begin            //写Cause寄存器
                        //Cause寄存器只有IP[1:0]、IV、WP字段是可写的
                        cause_o[9:8] <= data_i[9:8];    //IP[1:0]
                        cause_o[23] <= data_i[23];      //IV
                        cause_o[22] <= data_i[22];      //WP
                    end
                endcase
            end//if(we_i == `WriteEnable)

            case(excepttype_i)
                32'h0000_0001:begin                 //外部中断
                    //已经在访存阶段判断了是否处于异常级
                    if(is_in_delayslot_i == `InDelaySlot) begin
                        epc_o <= current_inst_addr_i - 4;
                        cause_o[31] <= 1'b1;        //Cause寄存器的BD字段
                    end else begin
                        epc_o <= current_inst_addr_i;
                        cause_o[31] <= 1'b0;
                    end
                    status_o[1] <= 1'b1;            //Status寄存器的EXL字段
                    cause_o[6:2] <= 5'b00000;       //Cause寄存器的ExcCode字段
                end
                32'h0000_0008:begin                 //系统调用异常syscall
                    //Status[1]为EXL字段，表示是否处于异常级
                    if(status_o[1] == 1'b0) begin
                        if(is_in_delayslot_i == `InDelaySlot) begin
                            epc_o <= current_inst_addr_i - 4;
                            cause_o[31] <= 1'b1;
                        end else begin
                            epc_o <= current_inst_addr_i;
                            cause_o[31] <= 1'b0;
                        end
                    end
                    //如果EXL字段为1，表示当前已经处于异常级了，又发生了新的异常，那么
                    //只需要将异常原因保存到Cause寄存器的ExcCode字段
                    status_o[1] <= 1'b1;
                    cause_o[6:2] <= 5'b01000;
                end
                32'h0000_000a:begin                 //无效指令异常
                    if(status_o[1] == 1'b0) begin
                        if(is_in_delayslot_i == `InDelaySlot) begin
                            epc_o <= current_inst_addr_i - 4;
                            cause_o[31] <= 1'b1;
                        end else begin
                            epc_o <= current_inst_addr_i;
                            cause_o[31] <= 1'b0;
                        end
                    end
                    status_o[1] <= 1'b1;
                    cause_o[6:2] <= 5'b01010;
                end
                32'h0000_000d:begin                 //自陷异常
                    if(status_o[1] == 1'b0) begin
                        if(is_in_delayslot_i == `InDelaySlot) begin
                            epc_o <= current_inst_addr_i - 4;
                            cause_o[31] <= 1'b1;
                        end else begin
                            epc_o <= current_inst_addr_i;
                            cause_o[31] <= 1'b0;
                        end
                    end
                    status_o[1] <= 1'b1;
                    cause_o[6:2] <= 5'b01101;
                end
                32'h0000_000c:begin                 //溢出异常
                    if(status_o[1] <= 1'b0) begin
                        if(is_in_delayslot_i == `InDelaySlot) begin
                            epc_o <= current_inst_addr_i - 4;
                            cause_o[31] <= 1'b1;
                        end else begin
                            epc_o <= current_inst_addr_i;
                            cause_o[31] <= 1'b0;
                        end
                    end
                    status_o[1] <= 1'b1;
                    cause_o[6:2] <= 5'b01100;
                end
                32'h0000_000e:begin                 //异常返回指令eret
                    status_o[1] <= 1'b0;
                end
                default:begin
                end
            endcase
        end//else
    end


//******************************************************************************
//                      对CP0中寄存器的读操作：组合逻辑
//******************************************************************************
    always @ ( * ) begin
        if(rst == `RstEnable) begin
            data_o <= `ZeroWord;
        end else begin
            case(raddr_i)
                `CP0_REG_COUNT:begin                //读Count寄存器
                    data_o <= count_o;
                end
                `CP0_REG_COMPARE:begin              //读Compare寄存器
                    data_o <= compare_o;
                end
                `CP0_REG_STATUS:begin               //读Status寄存器
                    data_o <= status_o;
                end
                `CP0_REG_CAUSE:begin                //读Cause寄存器
                    data_o <= cause_o;
                end
                `CP0_REG_EPC:begin                  //读EPC寄存器
                    data_o <= epc_o;
                end
                `CP0_REG_PRId:begin                 //读PRId寄存器
                    data_o <= prid_o;
                end
                `CP0_REG_CONFIG:begin               //读Config寄存器
                    data_o <= config_o;
                end
                default:begin
                end
            endcase
        end//else
    end

endmodule
