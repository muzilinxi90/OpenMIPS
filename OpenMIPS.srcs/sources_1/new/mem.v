`timescale 1ns / 1ps
//********************************************************************
//  访存阶段：加载存储指令在此实现
//  读数据存储器RAM时总是返回一个对齐的字给MEM模块
//  写数据存储器RAM时只能写指令要求写的字节、半字或者字
//********************************************************************

`include "defines.v"

module mem(
    input wire rst,

    //来自执行阶段的信息
    input wire[`RegAddrBus] wd_i,
    input wire wreg_i,
    input wire[`RegBus] wdata_i,
    input wire[`RegBus] hi_i,
    input wire[`RegBus] lo_i,
    input wire whilo_i,

    //访存阶段结果
    output reg[`RegAddrBus] wd_o,
    output reg wreg_o,
    output reg[`RegBus] wdata_o,
    output reg[`RegBus] hi_o,
    output reg[`RegBus] lo_o,
    output reg whilo_o,

    //加载存储指令相关接口
    input wire[`AluOpBus] aluop_i,      //加载存储指令操作类型
    input wire[`RegBus] mem_addr_i,     //加载存储指令对应的存储器地址
    input wire[`RegBus] reg2_i,         //存储指令要存储的数据或lwl/lwr要写入目的寄存器的原始值
    //与数据存储器RAM的交互接口
    input wire[`RegBus] mem_data_i,     //从数据存储器读取的数据
    output reg[`RegBus] mem_addr_o,     //要访问的数据存储器的地址
    output wire mem_we_o,               //是否是写操作
    output reg[3:0] mem_sel_o,          //字节选择信号
    output reg[`RegBus] mem_data_o,     //要写入数据存储器的数据
    output reg mem_ce_o                 //数据存储器使能信号
    );

    wire[`RegBus] zero32;
    reg mem_we;

    assign mem_we_o = mem_we;
    assign zero32 = `ZeroWord;

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
            case(aluop_i)
                `EXE_LB_OP:begin                //对加载的字节符号扩展
                    mem_addr_o <= mem_addr_i;
                    mem_we <= `WriteDisable;
                    mem_ce_o <= `ChipEnable;
                    //使用case条件分支是参考了Wishbone总线相关规范，为后期添加
                    //Wishbone总线接口做准备
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
                default:begin
                end
            endcase//case(aluop_i)
        end//esle
    end//always

endmodule
