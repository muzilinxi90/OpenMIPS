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
    output reg[`RegBus] wdata_o         //执行阶段指令最终要写入目的寄存器的值
    );

    //保存逻辑运算的结果
    reg[`RegBus] logicout;
    //保存移位运算结果
    reg[`RegBus] shiftres;

//********************************************************************
//  第一段：依据aluop_i指示的运算子类型进行运算
//********************************************************************
    //逻辑运算
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

    //移位运算
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

//********************************************************************
//  第二段：依据alusel_i指示的运算类型，选择一个运算结果作为最终的结果
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
            default:begin
                wdata_o <= `ZeroWord;
            end
        endcase
    end

endmodule
