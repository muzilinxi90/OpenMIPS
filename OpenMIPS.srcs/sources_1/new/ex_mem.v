`timescale 1ns / 1ps
//******************************************************************************
//          将执行阶段取得的运算结果，在下一个时钟传递到流水线访存阶段
//******************************************************************************

`include "defines.v"

module ex_mem(
    input wire rst,
    input wire clk,

    //来自ctrl的控制信息
    input wire[5:0] stall,
    input wire flush,

    //来自执行阶段的信息
    input wire ex_wreg,
    input wire[`RegAddrBus] ex_wd,
    input wire[`RegBus] ex_wdata,

    input wire[`RegBus] ex_hi,
    input wire[`RegBus] ex_lo,
    input wire ex_whilo,

    //送到访存阶段的信息
    output reg mem_wreg,
    output reg[`RegAddrBus] mem_wd,
    output reg[`RegBus] mem_wdata,

    output reg[`RegBus] mem_hi,
    output reg[`RegBus] mem_lo,
    output reg mem_whilo,

    //乘累加、乘累减运算数据接口：回传回EX模块
    input wire[`DoubleRegBus] hilo_i,
    input wire[1:0] cnt_i,
    output reg[`DoubleRegBus] hilo_o,
    output reg[1:0] cnt_o,

    //加载存储指令相关接口
    input wire[`AluOpBus] ex_aluop,
    input wire[`DataAddrBus] ex_mem_addr,
    input wire[`RegBus] ex_reg2,
    output reg[`AluOpBus] mem_aluop,
    output reg[`DataAddrBus] mem_mem_addr,
    output reg[`RegBus] mem_reg2,

    //协处理器访问指令相关接口
    input wire ex_cp0_reg_we,
    input wire[4:0] ex_cp0_reg_write_addr,
    input wire[`RegBus] ex_cp0_reg_data,
    output reg mem_cp0_reg_we,
    output reg[4:0] mem_cp0_reg_write_addr,
    output reg[`RegBus] mem_cp0_reg_data,

    //异常处理相关接口
    input wire[31:0] ex_excepttype,                     //译码执行阶段收集到的异常信息
    input wire ex_is_in_delayslot,                      //执行阶段指令是否是延迟槽指令
    input wire[`InstAddrBus] ex_current_inst_address,   //执行阶段指令的地址
    output reg[31:0] mem_excepttype,                    //译码执行阶段收集到的异常信息
    output reg mem_is_in_delayslot,                     //访存阶段指令是否是延迟槽指令
    output reg[`InstAddrBus] mem_current_inst_address   //访存阶段指令的地址
    );

    // 1)当stall[3]为Stop，stall[4]为NoStop时，表示执行阶段暂停，而访存阶段
    // 继续，所以使用空指令作为下一个周期进入访存阶段的指令;在执行阶段暂停的时候，
    // 将输入信号hilo_i通过输出接口hilo_o送出，输入信号cnt_i通过输出接口cnt_o
    // 送出，其余时刻hilo_o、cnt_o为0
    // 2)当stall[3]为NoStop时，执行阶段继续，执行后的指令进入访存阶段
    // 3)其余情况下，保持访存阶段的寄存器mem_wb、mem_wreg、mem_wdata、mem_hi、
    // mem_lo、mem_whilo不变
    always @ ( posedge clk ) begin
        if(rst == `RstEnable) begin
            mem_wreg <= `WriteDisable;
            mem_wd <= `NOPRegAddr;
            mem_wdata <= `ZeroWord;

            mem_hi <= `ZeroWord;
            mem_lo <= `ZeroWord;
            mem_whilo <= `WriteDisable;

            hilo_o <= {`ZeroWord, `ZeroWord};
            cnt_o <= 2'b00;

            mem_aluop <= `EXE_NOP_OP;
            mem_mem_addr <= `ZeroWord;
            mem_reg2 <= `ZeroWord;

            mem_cp0_reg_we <= `WriteDisable;
            mem_cp0_reg_write_addr <= 5'b00000;
            mem_cp0_reg_data <= `ZeroWord;

            mem_excepttype <= `ZeroWord;
            mem_is_in_delayslot <= `NotInDelaySlot;
            mem_current_inst_address <= `ZeroWord;

        end else if(flush == 1'b1) begin
            mem_wreg <= `WriteDisable;
            mem_wd <= `NOPRegAddr;
            mem_wdata <= `ZeroWord;

            mem_hi <= `ZeroWord;
            mem_lo <= `ZeroWord;
            mem_whilo <= `WriteDisable;

            hilo_o <= {`ZeroWord,`ZeroWord};
            cnt_o <= 2'b00;

            mem_aluop <= `EXE_NOP_OP;
            mem_mem_addr <= `ZeroWord;
            mem_reg2 <= `ZeroWord;

            mem_cp0_reg_we <= `WriteDisable;
            mem_cp0_reg_write_addr <= 5'b00000;
            mem_cp0_reg_data <= `ZeroWord;

            mem_excepttype <= `ZeroWord;
            mem_is_in_delayslot <= `NotInDelaySlot;
            mem_current_inst_address <= `ZeroWord;

        end else if(stall[3] == `Stop && stall[4] == `NoStop) begin
            mem_wreg <= `WriteDisable;
            mem_wd <= `NOPRegAddr;
            mem_wdata <= `ZeroWord;

            mem_hi <= `ZeroWord;
            mem_lo <= `ZeroWord;
            mem_whilo <= `WriteDisable;

            //执行阶段暂停时，之后的阶段不暂停时，回传到EX模块用于乘累加、乘累减运算
            hilo_o <= hilo_i;
            cnt_o <= cnt_i;

            mem_aluop <= `EXE_NOP_OP;
            mem_mem_addr <= `ZeroWord;
            mem_reg2 <= `ZeroWord;

            mem_cp0_reg_we <= `WriteDisable;
            mem_cp0_reg_write_addr <= 5'b00000;
            mem_cp0_reg_data <= `ZeroWord;

            mem_excepttype <= `ZeroWord;
            mem_is_in_delayslot <= `NotInDelaySlot;
            mem_current_inst_address <= `ZeroWord;

        end else if(stall[3] == `NoStop) begin
            mem_wreg <= ex_wreg;
            mem_wd <= ex_wd;
            mem_wdata <= ex_wdata;

            mem_hi <= ex_hi;
            mem_lo <= ex_lo;
            mem_whilo <= ex_whilo;

            //流水线不暂停时，该信息不起作用，其他信息传到流水线下一阶段
            hilo_o <= {`ZeroWord, `ZeroWord};
            cnt_o <= 2'b00;

            mem_aluop <= ex_aluop;
            mem_mem_addr <= ex_mem_addr;
            mem_reg2 <= ex_reg2;

            mem_cp0_reg_we <= ex_cp0_reg_we;
            mem_cp0_reg_write_addr <= ex_cp0_reg_write_addr;
            mem_cp0_reg_data <= ex_cp0_reg_data;

            mem_excepttype <= ex_excepttype;
            mem_is_in_delayslot <= ex_is_in_delayslot;
            mem_current_inst_address <= ex_current_inst_address;

        end else begin
            //流水线暂停时，回传到EX模块用于乘累加、乘累减运算
            hilo_o <= hilo_i;
            cnt_o <= cnt_i;
        end
    end

endmodule
