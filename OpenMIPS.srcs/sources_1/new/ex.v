`timescale 1ns / 1ps
//********************************************
//  运算执行
//********************************************

module ex(
    input wire rst,

    //译码阶段送到执行阶段的信息
    input wire[`AluOpBus] aluop_i,
    input wire[`AluSelBus] alusel_i,
    input wire[`RegBus] reg1_i,
    input wire[`RegBus] reg2_i,
    input wire[`RegAddrBus] wd_i,
    input wire wreg_i,

    //执行的结果
    output reg[`RegAddrBus] wd_o,       //执行阶段指令最终要写入的目的寄存器地址
    output reg wreg_o,                  //执行阶段指令最终是否有目的寄存器
    output reg[`RegBus] wdata_o,        //执行阶段指令最终要写入目的寄存器的值

    //HILO模块给出的HI、LO寄存器的值
    input wire[`RegBus] hi_i,
    input wire[`RegBus] lo_i,

    //执行阶段的指令对HI/LO寄存器的写操作请求
    output reg[`RegBus] hi_o,
    output reg[`RegBus] lo_o,
    output reg whilo_o,

    //访存阶段返回到执行阶段的HI/LO数据通路，用于检测HI/LO寄存器的数据相关
    input wire[`RegBus] mem_hi_i,
    input wire[`RegBus] mem_lo_i,
    input wire mem_whilo_i,

    //回写阶段返回到执行阶段的HI/LO数据通路，用于检测HI/LO寄存器的数据相关
    input wire[`RegBus] wb_hi_i,
    input wire[`RegBus] wb_lo_i,
    input wire wb_whilo_i

    );

    //保存逻辑运算的结果
    reg[`RegBus] logicout;
    //保存移位运算结果
    reg[`RegBus] shiftres;
    //移动操作的结果
    reg[`RegBus] moveres;
    //保存HI寄存器的最新值
    reg[`RegBus] HI;
    //保存LO寄存器的最新值
    reg[`RegBus] LO;

//********************************************************************
//  依据aluop_i指示的运算子类型进行运算
//********************************************************************
    //************************逻辑运算******************************
    always @ ( * ) begin
        if(rst == `RstEnable) begin
            logicout <= `ZeroWord;
        end else begin
            case(aluop_i)
                `EXE_AND_OP:begin
                    logicout <= reg1_i & reg2_i;
                end
                `EXE_OR_OP:begin
                logicout <= reg1_i | reg2_i;
                end
                `EXE_XOR_OP:begin
                    logicout <= reg1_i ^ reg2_i;
                end
                `EXE_NOR_OP:begin
                    logicout <= ~(reg1_i | reg2_i);
                end
                default:begin
                    logicout <= `ZeroWord;
                end
            endcase
        end//else
    end//always

    //***********************移位运算*******************************
    always @ ( * ) begin
        if(rst == `RstEnable) begin
            shiftres <= `ZeroWord;
        end else begin
            case(aluop_i)
                `EXE_SLL_OP:begin
                    shiftres <= reg2_i << reg1_i[4:0];
                end
                `EXE_SRL_OP:begin
                    shiftres <= reg2_i >> reg1_i[4:0];
                end
                `EXE_SRA_OP:begin
                    //(数据逻辑右移n位,32个1逻辑左移32-n位,两部分或运算相当于算术右移)
                    shiftres <= ({32{reg2_i[31]}}<<(6'd32 - {reg1_i[4:0]}))
                                | reg2_i >> reg1_i[4:0];
                end
                default:begin
                    shiftres <= `ZeroWord;
                end
            endcase
        end//else
    end//always

    //************************移动操作***************************
    //得到最新的HI、LO寄存器的值，此处要解决数据相关问题
    always @ ( * ) begin
        if(rst == `RstEnable) begin
            {HI,LO} <= {`ZeroWord,`ZeroWord};
        end else if(mem_whilo_i == `WriteEnable) begin
            {HI,LO} <= {mem_hi_i,mem_lo_i};
        end else if(wb_whilo_i == `WriteEnable) begin
            {HI,LO} <= {wb_hi_i,wb_lo_i};
        end else begin
            {HI,LO} <= {hi_i,lo_i};
        end
    end

    //MFHI、MFLO、MOVN、MOVZ指令
    always @ ( * ) begin
        if(rst == `RstEnable) begin
            moveres <= `ZeroWord;
        end else begin
            moveres <= `ZeroWord;
            case(aluop_i)
                `EXE_MFHI_OP:begin
                    moveres <= HI;
                end
                `EXE_MFLO_OP:begin
                    moveres <= LO;
                end
                `EXE_MOVZ_OP:begin
                    moveres <= reg1_i;
                end
                `EXE_MOVN_OP:begin
                    moveres <= reg1_i;
                end
                default:begin
                end
            endcase
        end//else
    end//always

//********************************************************************
//  依据alusel_i指示的运算类型，选择一个运算结果作为最终的结果(写回通用寄存器)
//********************************************************************
    always @ ( * ) begin
        wd_o <= wd_i;                       //要写的目的寄存器地址
        wreg_o <= wreg_i;                   //是否要写目的寄存器
        case(alusel_i)
            `EXE_RES_LOGIC:begin
                wdata_o <= logicout;        //wdata_o中存放运算结果
            end
            `EXE_RES_SHIFT:begin
                wdata_o <= shiftres;
            end
            `EXE_RES_MOVE:begin
                wdata_o <= moveres;
            end
            default:begin
                wdata_o <= `ZeroWord;
            end
        endcase
    end

    //MTHI、MTLO指令特殊处理
    always @ ( * ) begin
        if(rst == `RstEnable) begin
            whilo_o <= `WriteDisable;
            hi_o <= `ZeroWord;
            lo_o <= `ZeroWord;
        end else if(aluop_i == `EXE_MTHI_OP) begin
            whilo_o <= `WriteEnable;
            hi_o <= reg1_i;         //写HI寄存器，LO不变
            lo_o <= LO;
        end else if(aluop_i == `EXE_MTLO_OP) begin
            whilo_o <= `WriteEnable;
            hi_o <= HI;             //写LO寄存器，HI不变
            lo_o <= reg1_i;
        end else begin
            whilo_o <= `WriteDisable;
            hi_o <= `ZeroWord;
            lo_o <= `ZeroWord;
        end
    end

endmodule
