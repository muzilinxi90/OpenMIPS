`timescale 1ns / 1ps
//******************************************************************************
//  访存阶段：加载存储指令在此实现，异常处理在此实现
//  读数据存储器RAM时总是返回一个对齐的字给MEM模块
//  写数据存储器RAM时只能写指令要求写的字节、半字或者字
//******************************************************************************

`include "defines.v"

module mem(
    input wire rst,

    //来自执行阶段的信息
    input wire wreg_i,
    input wire[`RegAddrBus] wd_i,
    input wire[`RegBus] wdata_i,

    input wire[`RegBus] hi_i,
    input wire[`RegBus] lo_i,
    input wire whilo_i,

    //访存阶段结果
    output reg wreg_o,
    output reg[`RegAddrBus] wd_o,
    output reg[`RegBus] wdata_o,

    output reg[`RegBus] hi_o,
    output reg[`RegBus] lo_o,
    output reg whilo_o,

    //加载存储指令相关接口
    input wire[`AluOpBus] aluop_i,          //加载存储指令操作类型
    input wire[`DataAddrBus] mem_addr_i,    //加载存储指令对应的存储器地址
    input wire[`RegBus] reg2_i,             //存储指令要存储的数据或lwl/lwr要写入
                                            //目的寄存器的原始值
    //与数据Wishbone总线接口模块的交互信息
    output reg[`DataAddrBus] mem_addr_o,    //要访问的数据存储器的地址
    input wire[`DataBus] mem_data_i,        //从数据存储器读取的数据
    output reg[`DataBus] mem_data_o,         //要写入数据存储器的数据
    output reg mem_ce_o,                    //数据存储器使能信号
    output wire mem_we_o,                   //是否是写操作
    output reg[3:0] mem_sel_o,              //字节选择信号

    //LLbit寄存器相关接口(ll、sc指令)
    input wire LLbit_i,                 //LLbit模块给出的LLbit寄存器的值
    input wire wb_LLbit_we_i,           //回写阶段的指令是否要写LLbit寄存器(旁路信息)
    input wire wb_LLbit_value_i,        //回写阶段的指令要写入LLbit寄存器的值(旁路信息)
    output reg LLbit_we_o,              //访存阶段的指令是否要写LLbit寄存器
    output reg LLbit_value_o,           //访存阶段的指令要写入LLbit寄存器的值

    //协处理器访问指令相关接口
    input wire cp0_reg_we_i,
    input wire[4:0] cp0_reg_write_addr_i,
    input wire[`RegBus] cp0_reg_data_i,
    output reg cp0_reg_we_o,
    output reg[4:0] cp0_reg_write_addr_o,
    output reg[`RegBus] cp0_reg_data_o,

    //异常处理相关接口
    //来自执行阶段
    input wire[31:0] excepttype_i,                      //译码执行阶段收集到的异常信息
    input wire is_in_delayslot_i,                       //访存阶段指令是否是延迟槽指令
    input wire[`InstAddrBus] current_inst_address_i,    //访存阶段指令的地址
    //来自CP0模块
    input wire[`RegBus] cp0_status_i,
    input wire[`RegBus] cp0_cause_i,
    input wire[`RegBus] cp0_epc_i,
    //来自回写阶段的前推信息
    input wire wb_cp0_reg_we,
    input wire[4:0] wb_cp0_reg_write_addr,
    input wire[`RegBus] wb_cp0_reg_data,
    //向回写阶段输出
    output reg[31:0] excepttype_o,                      //最终的异常类型
    output wire is_in_delayslot_o,                      //访存阶段指令是否是延迟槽指令
    output wire[`InstAddrBus] current_inst_address_o,   //访存阶段指令的地址
    output wire[`RegBus] cp0_epc_o                      //CP0中EPC寄存器的最新值
    );

    reg mem_we;                         //访问数据存储器RAM读写控制
    reg LLbit;                          //保存LLbit寄存器的最新值
    wire[`RegBus] zero32;

    reg[`RegBus] cp0_status;            //用来保存CP0中Status寄存器的最新值
    reg[`RegBus] cp0_cause;             //用来保存CP0中Cause寄存器的最新值
    reg[`RegBus] cp0_epc;               //用来保存CP0中EPC寄存器的最新值


    //mem_we_o输出到数据存储器，表示是否是对数据存储器的写操作，如果发生了异常，那么
    //需要取消对数据存储器的写操作
    assign mem_we_o = mem_we & (~(|excepttype_o));

    assign zero32 = `ZeroWord;

    assign is_in_delayslot_o = is_in_delayslot_i;

    assign current_inst_address_o = current_inst_address_i;


    always @ ( * ) begin
        if(rst == `RstEnable) begin
            wd_o <= `NOPRegAddr;
            wreg_o <= `WriteDisable;
            wdata_o <= `ZeroWord;

            hi_o <= `ZeroWord;
            lo_o <= `ZeroWord;
            whilo_o <= `WriteDisable;

            mem_addr_o <= `ZeroWord;
            mem_we <= `WriteDisable;
            mem_sel_o <= 4'b0000;
            mem_data_o <= `ZeroWord;
            mem_ce_o <= `ChipDisable;

            LLbit_we_o <= 1'b0;
            LLbit_value_o <= 1'b0;

            cp0_reg_we_o <= `WriteDisable;
            cp0_reg_write_addr_o <= 5'b00000;
            cp0_reg_data_o <= `ZeroWord;

        end else begin
            wd_o <= wd_i;
            wreg_o <= wreg_i;
            wdata_o <= wdata_i;

            hi_o <= hi_i;
            lo_o <=lo_i;
            whilo_o <= whilo_i;

            mem_we <= `WriteDisable;
            mem_addr_o <= `ZeroWord;
            mem_sel_o <= 4'b1111;
            mem_ce_o <= `ChipDisable;

            LLbit_we_o <= 1'b0;
            LLbit_value_o <= 1'b0;

            cp0_reg_we_o <= cp0_reg_we_i;
            cp0_reg_write_addr_o <= cp0_reg_write_addr_i;
            cp0_reg_data_o <= cp0_reg_data_i;

            case(aluop_i)
                `EXE_LB_OP:begin                //对加载的字节符号扩展
                    mem_addr_o <= mem_addr_i;
                    mem_we <= `WriteDisable;
                    mem_ce_o <= `ChipEnable;
                    //使用case条件分支是参考了Wishbone总线相关规范：Wishbone总线会
                    //将要访问的地址末两位置0，返回一个对齐的32位字，要使用mem_sel_o
                    //选择需要的字节
                    case(mem_addr_i[1:0])
                        2'b00:begin
                            wdata_o <= {{24{mem_data_i[31]}},mem_data_i[31:24]};
                            mem_sel_o <= 4'b1000;
                        end
                        2'b01:begin
                            wdata_o <= {{24{mem_data_i[23]}},mem_data_i[23:16]};
                            mem_sel_o <= 4'b0100;
                        end
                        2'b10:begin
                            wdata_o <= {{24{mem_data_i[15]}},mem_data_i[15:8]};
                            mem_sel_o <= 4'b0010;
                        end
                        2'b11:begin
                            wdata_o <= {{24{mem_data_i[7]}},mem_data_i[7:0]};
                            mem_sel_o <= 4'b0001;
                        end
                        default:begin
                            wdata_o <= `ZeroWord;
                        end
                    endcase//case(mem_addr_i[1:0])
                end//EXE_LB_OP
                `EXE_LBU_OP:begin               //对加载的字节无符号扩展
                    mem_addr_o <= mem_addr_i;
                    mem_we <= `WriteDisable;
                    mem_ce_o <= `ChipEnable;
                    case(mem_addr_i[1:0])
                        2'b00:begin
                            wdata_o <= {{24{1'b0}},mem_data_i[31:24]};
                            mem_sel_o <= 4'b1000;
                        end
                        2'b01:begin
                            wdata_o <= {{24{1'b0}},mem_data_i[23:16]};
                            mem_sel_o <= 4'b0100;
                        end
                        2'b10:begin
                            wdata_o <= {{24{1'b0}},mem_data_i[15:8]};
                            mem_sel_o <= 4'b0010;
                        end
                        2'b11:begin
                            wdata_o <= {{24{1'b0}},mem_data_i[7:0]};
                            mem_sel_o <= 4'b0001;
                        end
                        default:begin
                            wdata_o <= `ZeroWord;
                        end
                    endcase//case(mem_addr_i[1:0])
                end//EXE_LBU_OP
                `EXE_LH_OP:begin
                    mem_addr_o <= mem_addr_i;
                    mem_we <= `WriteDisable;
                    mem_ce_o <= `ChipEnable;
                    case(mem_addr_i[1:0])
                        2'b00:begin
                            wdata_o <= {{16{mem_data_i[31]}},mem_data_i[31:16]};
                            mem_sel_o <= 4'b1100;
                        end
                        2'b10:begin
                            wdata_o <= {{16{mem_data_i[15]}},mem_data_i[15:0]};
                            mem_sel_o <= 4'b0011;
                        end
                        default:begin
                            wdata_o <= `ZeroWord;
                        end
                    endcase//case(mem_addr_i[1:0])
                end
                `EXE_LHU_OP:begin
                    mem_addr_o <= mem_addr_i;
                    mem_we <= `WriteDisable;
                    mem_ce_o <= `ChipEnable;
                    case(mem_addr_i[1:0])
                        2'b00:begin
                            wdata_o <= {{16{1'b0}},mem_data_i[31:16]};
                            mem_sel_o <= 4'b1100;
                        end
                        2'b10:begin
                            wdata_o <= {{16{1'b0}},mem_data_i[15:0]};
                            mem_sel_o <= 4'b0011;
                        end
                        default:begin
                            wdata_o <= `ZeroWord;
                        end
                    endcase//case(mem_addr_i[1:0])
                end
                `EXE_LW_OP:begin
                    mem_addr_o <= mem_addr_i;
                    mem_we <= `WriteDisable;
                    mem_ce_o <= `ChipEnable;
                    wdata_o <= mem_data_i;
                    mem_sel_o <= 4'b1111;
                end
                `EXE_LWL_OP:begin
                    mem_addr_o <= {mem_addr_i[31:2],2'b00}; //求对齐地址只需将后两位置0
                    mem_we <= `WriteDisable;
                    mem_ce_o <= `ChipEnable;
                    mem_sel_o <= 4'b1111;
                    case(mem_addr_i[1:0])
                        2'b00:begin
                            wdata_o <= mem_data_i[31:0];
                        end
                        2'b01:begin
                            wdata_o <= {mem_data_i[23:0],reg2_i[7:0]};
                        end
                        2'b10:begin
                            wdata_o <= {mem_data_i[15:0],reg2_i[15:0]};
                        end
                        2'b11:begin
                            wdata_o <= {mem_data_i[7:0],reg2_i[23:0]};
                        end
                        default:begin
                            wdata_o <= `ZeroWord;
                        end
                    endcase//case(mem_addr_i[1:0])
                end
                `EXE_LWR_OP:begin
                    mem_addr_o <= {mem_addr_i[31:2],2'b00};
                    mem_we <= `WriteDisable;
                    mem_ce_o <= `ChipEnable;
                    mem_sel_o <= 4'b1111;
                    case(mem_addr_i[1:0])
                        2'b00:begin
                            wdata_o <= {reg2_i[31:8],mem_data_i[31:24]};
                        end
                        2'b01:begin
                            wdata_o <= {reg2_i[31:16],mem_data_i[31:16]};
                        end
                        2'b10:begin
                            wdata_o <= {reg2_i[31:24],mem_data_i[31:8]};
                        end
                        2'b11:begin
                            wdata_o <= mem_data_i;
                        end
                        default:begin
                            wdata_o <= `ZeroWord;
                        end
                    endcase//case(mem_addr_i[1:0])
                end
                `EXE_SB_OP:begin
                    mem_addr_o <= mem_addr_i;
                    mem_we <= `WriteEnable;
                    mem_ce_o <= `ChipEnable;
                    mem_data_o <= {reg2_i[7:0],reg2_i[7:0],reg2_i[7:0],reg2_i[7:0]};
                    case(mem_addr_i[1:0])
                        2'b00:begin
                            mem_sel_o <= 4'b1000;
                        end
                        2'b01:begin
                            mem_sel_o <= 4'b0100;
                        end
                        2'b10:begin
                            mem_sel_o <= 4'b0010;
                        end
                        2'b11:begin
                            mem_sel_o <= 4'b0001;
                        end
                        default:begin
                            mem_sel_o <= 4'b0000;
                        end
                    endcase
                end
                `EXE_SH_OP:begin
                    mem_addr_o <= mem_addr_i;
                    mem_we <= `WriteEnable;
                    mem_ce_o <= `ChipEnable;
                    mem_data_o <= {reg2_i[15:0],reg2_i[15:0]};
                    case(mem_addr_i[1:0])
                        2'b00:begin
                            mem_sel_o <= 4'b1100;
                        end
                        2'b10:begin
                            mem_sel_o <= 4'b0011;
                        end
                        default:begin
                            mem_sel_o <= 4'b0000;
                        end
                    endcase
                end
                `EXE_SW_OP:begin
                    mem_addr_o <= mem_addr_i;
                    mem_we <= `WriteEnable;
                    mem_ce_o <= `ChipEnable;
                    mem_data_o <= reg2_i;
                    mem_sel_o <= 4'b1111;
                end
                `EXE_SWL_OP:begin
                    mem_addr_o <= {mem_addr_i[31:2],2'b00};
                    mem_we <= `WriteEnable;
                    mem_ce_o <= `ChipEnable;
                    case(mem_addr_i[1:0])
                        2'b00:begin
                            mem_sel_o <= 4'b1111;
                            mem_data_o <= reg2_i;
                        end
                        2'b01:begin     //mem_data_o前8位值任意，在sel控制下只写后3字节
                            mem_sel_o <= 4'b0111;
                            mem_data_o <= {zero32[7:0],reg2_i[31:8]};
                        end
                        2'b10:begin
                            mem_sel_o <= 4'b0011;
                            mem_data_o <= {zero32[15:0],reg2_i[31:16]};
                        end
                        2'b11:begin
                            mem_sel_o <= 4'b0001;
                            mem_data_o <= {zero32[23:0],reg2_i[31:24]};
                        end
                        default:begin
                            mem_sel_o <= 4'b0000;
                        end
                    endcase
                end
                `EXE_SWR_OP:begin
                    mem_addr_o <= {mem_addr_i[31:2],2'b00};
                    mem_we <= `WriteEnable;
                    mem_ce_o <= `ChipEnable;
                    case(mem_addr_i[1:0])
                        2'b00:begin
                            mem_sel_o <= 4'b1000;
                            mem_data_o <= {reg2_i[7:0],zero32[23:0]};
                        end
                        2'b01:begin
                            mem_sel_o <= 4'b1100;
                            mem_data_o <= {reg2_i[15:0],zero32[15:0]};
                        end
                        2'b10:begin
                            mem_sel_o <= 4'b1110;
                            mem_data_o <= {reg2_i[23:0],zero32[7:0]};
                        end
                        2'b11:begin
                            mem_sel_o <= 4'b1111;
                            mem_data_o <= reg2_i[31:0];
                        end
                        default:begin
                            mem_sel_o <= 4'b0000;
                        end
                    endcase
                end
                `EXE_LL_OP:begin
                    mem_addr_o <= mem_addr_i;
                    mem_we <= `WriteDisable;
                    wdata_o <= mem_data_i;
                    LLbit_we_o <= 1'b1;
                    LLbit_value_o <= 1'b1;
                    mem_sel_o <= 4'b1111;
                    mem_ce_o <= `ChipEnable;
                end
                `EXE_SC_OP:begin
                    if(LLbit == 1'b1) begin
                        LLbit_we_o <= 1'b1;
                        LLbit_value_o <= 1'b0;
                        mem_addr_o <= mem_addr_i;
                        mem_we <= `WriteEnable;
                        mem_data_o <= reg2_i;
                        wdata_o <= 32'b1;
                        mem_sel_o <= 4'b1111;
                        mem_ce_o <= `ChipEnable;
                    end else begin
                        wdata_o <= 32'b0;
                    end
                end
                default:begin
                end
            endcase//case(aluop_i)
        end//esle
    end//always


//******************************************************************************
// 获取LLbit寄存器的最新值：如果回写阶段的指令要写LLbit，那么回写阶段要写入的值就是
// LLbit寄存器的最新值，反之，LLbit模块给出的值LLbit_i是最新值
//******************************************************************************
    always @ ( * ) begin
        if(rst == `RstEnable) begin
            LLbit <= 1'b0;
        end else begin
            if(wb_LLbit_we_i == 1'b1) begin
                LLbit <= wb_LLbit_value_i;
            end else begin
                LLbit <= LLbit_i;
            end
        end
    end


//******************************************************************************
//  得到CP0中寄存器的最新值
//******************************************************************************
    //得到CP0中Status寄存器的最新值，步骤如下：
    //判断当前处于回写阶段的指令是否要写CP0中Status寄存器，如果要写，那么要写入的值就是
    //Status寄存器的最新值，反之，从CP0模块通过cp0_status_i接口传入的数据就是Status
    //寄存器的最新值
    always @ ( * ) begin
        if(rst == `RstEnable) begin
            cp0_status <= `ZeroWord;
        end else if((wb_cp0_reg_we == `WriteEnable) &&
                    (wb_cp0_reg_write_addr == `CP0_REG_STATUS)) begin
            cp0_status <= wb_cp0_reg_data;
        end else begin
            cp0_status <= cp0_status_i;
        end
    end

    //得到CP0中EPC寄存器的最新值，原理同Status寄存器
    always @ ( * ) begin
        if(rst == `RstEnable) begin
            cp0_epc <= `ZeroWord;
        end else if((wb_cp0_reg_we == `WriteEnable) &&
                    (wb_cp0_reg_write_addr == `CP0_REG_EPC)) begin
            cp0_epc <= wb_cp0_reg_data;
        end else begin
            cp0_epc <= cp0_epc_i;
        end
    end

    //将EPC寄存器的最新值通过接口cp0_epc_o输出
    assign cp0_epc_o = cp0_epc;

    //得到CP0中Cause寄存器的最新值，原理同Status寄存器
    //要注意的是：Cause寄存器只有几个字段是可写的
    always @ ( * ) begin
        if(rst == `RstEnable) begin
            cp0_cause <= `ZeroWord;
        end else if((wb_cp0_reg_we == `WriteEnable) &&
                    (wb_cp0_reg_write_addr == `CP0_REG_CAUSE)) begin
            cp0_cause[9:8] <= wb_cp0_reg_data[9:8];         //IP[1:0]字段
            cp0_cause[22] <= wb_cp0_reg_data[22];           //WP字段
            cp0_cause[23] <= wb_cp0_reg_data[23];           //IV字段
        end else begin
            cp0_cause <= cp0_cause_i;
        end
    end


//******************************************************************************
//  给出最终的异常类型
//******************************************************************************
    always @ ( * ) begin
        if(rst == `RstEnable) begin
            excepttype_o <= `ZeroWord;
        end else begin
            excepttype_o <= `ZeroWord;
            //当前处于访存阶段的指令的地址为0，表示处理器处于复位状态，或者刚刚发生异常，
            //正在清除流水线(flush为1)，或者流水线处于暂停状态，在这三种情况下都不处理
            //异常
            if(current_inst_address_i != `ZeroWord) begin
                //status[15:8]是否屏蔽相应中断，0表示屏蔽；cause[15:8]中断挂起字段；
                //status[1]EXL字段，表示是否处于异常级；status[0]中断使能
                if(((cp0_cause[15:8] & cp0_status[15:8]) != 8'h00) &&
                    (cp0_status[1] == 1'b0) && (cp0_status[0] == 1'b1)) begin
                    excepttype_o <= 32'h0000_0001;          //interrupt
                end else if(excepttype_i[8] == 1'b1) begin
                    excepttype_o <= 32'h0000_0008;          //syscall
                end else if(excepttype_i[9] == 1'b1) begin
                    excepttype_o <= 32'h0000_000a;          //inst_invalid
                end else if(excepttype_i[10] == 1'b1) begin
                    excepttype_o <= 32'h0000_000d;          //trap
                end else if(excepttype_i[11] == 1'b1) begin
                    excepttype_o <= 32'h0000_000c;          //ov
                end else if(excepttype_i[12] == 1'b1) begin
                    excepttype_o <= 32'h0000_000e;          //eret
                end
            end//if
        end//else
    end

endmodule
