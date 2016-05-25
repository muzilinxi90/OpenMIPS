`timescale 1ns / 1ps
//******************************************************************************
//                              EX模块
//******************************************************************************

`include "defines.v"

module ex(
    input wire rst,

    //译码阶段送到执行阶段的信息
    input wire[`AluOpBus] aluop_i,
    input wire[`AluSelBus] alusel_i,
    input wire[`RegBus] reg1_i,
    input wire[`RegBus] reg2_i,
    input wire wreg_i,
    input wire[`RegAddrBus] wd_i,

    //执行的结果
    output reg wreg_o,                  //执行阶段指令最终是否有目的寄存器
    output reg[`RegAddrBus] wd_o,       //执行阶段指令最终要写入的目的寄存器地址
    output reg[`RegBus] wdata_o,        //执行阶段指令最终要写入目的寄存器的值
    output reg[`RegBus] hi_o,
    output reg[`RegBus] lo_o,
    output reg whilo_o,

    //HILO模块给出的HI、LO寄存器的值
    input wire[`RegBus] hi_i,
    input wire[`RegBus] lo_i,

    //访存阶段返回到执行阶段的HI/LO数据通路，用于检测HI/LO寄存器的数据相关
    input wire[`RegBus] mem_hi_i,
    input wire[`RegBus] mem_lo_i,
    input wire mem_whilo_i,

    //回写阶段返回到执行阶段的HI/LO数据通路，用于检测HI/LO寄存器的数据相关
    input wire[`RegBus] wb_hi_i,
    input wire[`RegBus] wb_lo_i,
    input wire wb_whilo_i,

    //输出到ctrl的请求流水线暂停信号
    output reg stallreq,

    //用于乘累加、乘累减运算的数据接口
    input wire[`DoubleRegBus] hilo_temp_i,  //第一个执行周期得到的乘法结果
    input wire[1:0] cnt_i,                  //当前处于执行阶段的第几个时钟周期
    output reg[`DoubleRegBus] hilo_temp_o,  //第一个执行周期得到的乘法结果
    output reg[1:0] cnt_o,                  //下一个时钟周期处于执行阶段的第几个时钟周期

    //与DIV模块连接的接口
    input wire[`DoubleRegBus] div_result_i,
    input wire div_ready_i,
    output reg[`RegBus] div_opdata1_o,
    output reg[`RegBus] div_opdata2_o,
    output reg div_start_o,
    output reg signed_div_o,

    //处于执行阶段的转移指令要保存的返回地址
    input wire[`InstAddrBus] link_address_i,
    //当前执行阶段的指令是否位于延迟槽(异常处理过程中使用)
    input wire is_in_delayslot_i,

    //加载存储指令相关接口
    input wire[`InstBus] inst_i,            //接收未译码的原始指令
    output wire[`AluOpBus] aluop_o,         //向访存阶段输出加载存储指令类型
    output wire[`DataAddrBus] mem_addr_o,   //加载存储指令对应的存储器地址
    output wire[`RegBus] reg2_o,            //存储指令要存储的数据或lwl/lwr指令要
                                            //加载到目的寄存器的原始值
    //协处理器相关接口
    //访存阶段的指令是否要写CP0中的寄存器(数据前推)
    input wire mem_cp0_reg_we,
    input wire[4:0] mem_cp0_reg_write_addr,
    input wire[`RegBus] mem_cp0_reg_data,
    //回写阶段的指令是否要写CP0中的寄存器(数据前推)
    input wire wb_cp0_reg_we,
    input wire[4:0] wb_cp0_reg_write_addr,
    input wire[`RegBus] wb_cp0_reg_data,
    //与CP0直接相连，用于读取其中指定的寄存器的值
    output reg[4:0] cp0_reg_read_addr_o,
    input wire[`RegBus] cp0_reg_data_i,
    //向流水线下一级传递，用于写CP0中的指定寄存器
    output reg cp0_reg_we_o,
    output reg[4:0] cp0_reg_write_addr_o,
    output reg[`RegBus] cp0_reg_data_o,

    //异常处理相关
    input wire[31:0] excepttype_i,                      //译码阶段收集到的异常信息
    input wire[`InstAddrBus] current_inst_address_i,    //执行阶段指令的地址
    output wire[31:0] excepttype_o,                     //译码和执行阶段收集到的异常信息
    //传递到访存阶段，当异常发生时，这两个信息用来确定保存到EPC寄存器的值
    output wire[`InstAddrBus] current_inst_address_o,   //执行阶段指令的地址
    output wire is_in_delayslot_o                       //执行阶段的指令是否是延迟槽指令
    );

    //保存逻辑运算的结果
    reg[`RegBus] logicout;
    //保存移位运算结果
    reg[`RegBus] shiftres;
    //移动操作的结果
    reg[`RegBus] moveres;
    //保存算术运算的结果
    reg[`RegBus] arithmeticres;
    //保存HI寄存器的最新值
    reg[`RegBus] HI;
    //保存LO寄存器的最新值
    reg[`RegBus] LO;
    //保存乘法结果，宽度为64位
    reg[`DoubleRegBus] mulres;

    //算术运算相关中间变量
    wire[`RegBus] reg2_i_mux;       //保存输入的第二个操作数reg2_i的补码
    wire[`RegBus] reg1_i_not;       //保存输入的第一个操作数reg1_i取反后的值
    wire[`RegBus] result_sum;       //保存加法结果
    wire ov_sum;                    //保存溢出情况
    wire reg1_eq_reg2;              //第一个操作数是否等于第二个操作数
    wire reg1_lt_reg2;              //第一个操作数是否小于第二个操作数
    wire[`RegBus] opdata1_mult;     //乘法操作中的被乘数
    wire[`RegBus] opdata2_mult;     //乘法操作中的乘数
    wire[`DoubleRegBus] hilo_temp;  //临时保存乘法结果，宽度为64位
    reg[`DoubleRegBus] hilo_temp1;  //临时保存乘累加累减运算结果

    reg stallreq_for_madd_msub;     //请求流水线暂停
    reg stallreq_for_div;           //是否由于除法运算导致流水线暂停

    reg trapassert;                 //表示是否有自陷异常
    reg ovassert;                   //表示是否有溢出异常


    //执行阶段输出的异常信息就是译码阶段的异常信息加上自陷异常、溢出异常的信息，
    //其中第10bit表示是否有自陷异常，第11bit表示是否有溢出异常
    assign excepttype_o = {excepttype_i[31:12],ovassert,trapassert,
                            excepttype_i[9:8],8'h00};

    assign is_in_delayslot_o = is_in_delayslot_i;

    assign current_inst_address_o = current_inst_address_i;


//******************************************************************************
//                  依据aluop_i指示的运算子类型进行运算
//******************************************************************************

//********************************逻辑运算***************************************
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

//********************************移位运算***************************************
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

//**********************************移动操作*************************************
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
                `EXE_MFC0_OP:begin
                    //要从CP0中读取的寄存器的地址
                    cp0_reg_read_addr_o <= inst_i[15:11];
                    //读取到的CP0中指定寄存器的值
                    moveres <= cp0_reg_data_i;
                    //判断是否存在数据相关
                    if(mem_cp0_reg_we == `WriteEnable &&
                        mem_cp0_reg_write_addr == inst_i[15:11]) begin
                        moveres <= mem_cp0_reg_data;
                    end else if(wb_cp0_reg_we == `WriteEnable &&
                        wb_cp0_reg_write_addr == inst_i[15:11]) begin
                        moveres <= wb_cp0_reg_data;
                    end
                end
                default:begin
                end
            endcase
        end//else
    end//always

//********************************算术运算***************************************
    //一、计算变量的值
    //1.如果是减法运算、有符号比较运算、有符号自陷指令，那么reg2_i_mux等于第二个操作数
    //reg2_i的补码，否则就等于第二个操作数
    assign reg2_i_mux = (
                         (aluop_i == `EXE_SUB_OP)  ||
                         (aluop_i == `EXE_SUBU_OP) ||
                         (aluop_i == `EXE_SLT_OP)  ||
                         (aluop_i == `EXE_TGE_OP)  ||
                         (aluop_i == `EXE_TGEI_OP) ||
                         (aluop_i == `EXE_TLT_OP)  ||
                         (aluop_i == `EXE_TLTI_OP)
                        ) ? ((~reg2_i)+1) : reg2_i;

    // 2.分三种情况：
    //     1)如果是加法运算，此时reg2_i_mux就是第二个操作数reg2_i,所以result_sum
    //     就是加法运算的结果;
    //     2)如果是减法运算，此时reg2_i_mux是第二个操作数reg2_i的补码，所以
    //     result_sum就是减法运算的结果
    //     3)如果是有符号比较运算或有符号自陷指令，此时reg2_i_mux也是第二个操作数
    //     reg2_i的补码，所以result_sum也是减法运算的结果，可以通过判断减法的结果是否
    //     小于零，进而判断第一个操作数reg1_i是否小于第二个操作数reg2_i
    assign result_sum = reg1_i + reg2_i_mux;

    // 3.计算是否溢出。加法指令(add和addi)、减法指令(sub)执行时，需要判断是否溢出，
    // 满足以下两种情况之一时，有溢出：
    //     1)reg1_i为正数，reg2_i_mux为正数，但是两者之和为负数
    //     2)reg1_i为负数，reg2_i_mux为负数，但是两者之和为正数
    assign ov_sum = ((!reg1_i[31] && !reg2_i_mux[31]) && result_sum[31]) ||
                    ((reg1_i[31] && reg2_i_mux[31]) && (!result_sum[31]));

    // 4.计算操作数1是否小于操作数2,分两种情况:
    //     1)当前指令为有符号比较指令或者有符号自陷异常指令时，此时又分为3种情况:
    //         a)reg1_i为负数、reg2_i为正数，显然reg1_i小于reg2_i
    //         b)reg1_i为正数、reg2_i为正数，并且reg1_i减去reg2_i的值小于0
    //           (即result_sum为负)，此时也有reg1_i小于reg2_i
    //         c)reg1_i为负数、reg2_i为负数，并且reg1_i减去reg2_i的值小于0
    //           (即result_sum为负)，此时也有reg1_i小于reg2_i
    //     2)当前指令为无符号比较指令或者无符号自陷异常指令时，直接使用比较运算符比较
    //       reg1_i和reg2_i(冒号后面的分支)
    assign reg1_lt_reg2 = (
                            (aluop_i == `EXE_SLT_OP)  ||
                            (aluop_i == `EXE_TGE_OP)  ||
                            (aluop_i == `EXE_TGEI_OP) ||
                            (aluop_i == `EXE_TLT_OP)  ||
                            (aluop_i == `EXE_TLTI_OP)
                          ) ? ((reg1_i[31] && !reg2_i[31]) ||
                           (!reg1_i[31] && !reg2_i[31] && result_sum[31]) ||
                           (reg1_i[31] && reg2_i[31] && result_sum[31]))
                            : (reg1_i < reg2_i);

    // 5.对操作数1逐位取反，赋给reg1_i_not
    assign reg1_i_not = ~reg1_i;


    //二、依据不同的算术运算类型，给arithmeticres变量赋值
    always @ ( * ) begin
        if(rst == `RstEnable) begin
            arithmeticres <= `ZeroWord;
        end else begin
            case(aluop_i)
                `EXE_SLT_OP, `EXE_SLTU_OP:begin
                    arithmeticres <= reg1_lt_reg2;
                end
                `EXE_ADD_OP, `EXE_ADDU_OP, `EXE_ADDI_OP, `EXE_ADDIU_OP:begin
                    arithmeticres <= result_sum;
                end
                `EXE_SUB_OP, `EXE_SUBU_OP:begin
                    arithmeticres <= result_sum;
                end
                `EXE_CLZ_OP:begin
                    arithmeticres <= reg1_i[31] ? 0 :
                                     reg1_i[30] ? 1 :
                                     reg1_i[29] ? 2 :
                                     reg1_i[28] ? 3 :
                                     reg1_i[27] ? 4 :
                                     reg1_i[26] ? 5 :
                                     reg1_i[25] ? 6 :
                                     reg1_i[24] ? 7 :
                                     reg1_i[23] ? 8 :
                                     reg1_i[22] ? 9 :
                                     reg1_i[21] ? 10 :
                                     reg1_i[20] ? 11 :
                                     reg1_i[19] ? 12 :
                                     reg1_i[18] ? 13 :
                                     reg1_i[17] ? 14 :
                                     reg1_i[16] ? 15 :
                                     reg1_i[15] ? 16 :
                                     reg1_i[14] ? 17 :
                                     reg1_i[13] ? 18 :
                                     reg1_i[12] ? 19 :
                                     reg1_i[11] ? 20 :
                                     reg1_i[10] ? 21 :
                                     reg1_i[9]  ? 22 :
                                     reg1_i[8]  ? 23 :
                                     reg1_i[7]  ? 24 :
                                     reg1_i[6]  ? 25 :
                                     reg1_i[5]  ? 26 :
                                     reg1_i[4]  ? 27 :
                                     reg1_i[3]  ? 28 :
                                     reg1_i[2]  ? 29 :
                                     reg1_i[1]  ? 30 :
                                     reg1_i[0]  ? 31 : 32;
                end
                `EXE_CLO_OP:begin
                    arithmeticres <= reg1_i_not[31] ? 0 :
                                     reg1_i_not[30] ? 1 :
                                     reg1_i_not[29] ? 2 :
                                     reg1_i_not[28] ? 3 :
                                     reg1_i_not[27] ? 4 :
                                     reg1_i_not[26] ? 5 :
                                     reg1_i_not[25] ? 6 :
                                     reg1_i_not[24] ? 7 :
                                     reg1_i_not[23] ? 8 :
                                     reg1_i_not[22] ? 9 :
                                     reg1_i_not[21] ? 10 :
                                     reg1_i_not[20] ? 11 :
                                     reg1_i_not[19] ? 12 :
                                     reg1_i_not[18] ? 13 :
                                     reg1_i_not[17] ? 14 :
                                     reg1_i_not[16] ? 15 :
                                     reg1_i_not[15] ? 16 :
                                     reg1_i_not[14] ? 17 :
                                     reg1_i_not[13] ? 18 :
                                     reg1_i_not[12] ? 19 :
                                     reg1_i_not[11] ? 20 :
                                     reg1_i_not[10] ? 21 :
                                     reg1_i_not[9]  ? 22 :
                                     reg1_i_not[8]  ? 23 :
                                     reg1_i_not[7]  ? 24 :
                                     reg1_i_not[6]  ? 25 :
                                     reg1_i_not[5]  ? 26 :
                                     reg1_i_not[4]  ? 27 :
                                     reg1_i_not[3]  ? 28 :
                                     reg1_i_not[2]  ? 29 :
                                     reg1_i_not[1]  ? 30 :
                                     reg1_i_not[0]  ? 31 : 32;
                end
                default:begin
                    arithmeticres <= `ZeroWord;
                end
            endcase//case(aluop_i)
        end//else
    end


    //三、进行乘法运算
    // 1.取得乘法运算的被乘数，如果是有符号乘法且被乘数是负数，那么取补码
    assign opdata1_mult = (((aluop_i == `EXE_MUL_OP) ||
                            (aluop_i == `EXE_MULT_OP) ||
                            (aluop_i == `EXE_MADD_OP) ||
                            (aluop_i == `EXE_MSUB_OP)) &&
                            (reg1_i[31] == 1'b1)) ? (~reg1_i+1) : reg1_i;

    // 2.取得乘法运算的乘数，如果是有符号乘法且乘数是负数，那么取补码
    assign opdata2_mult = (((aluop_i == `EXE_MUL_OP) ||
                            (aluop_i == `EXE_MULT_OP) ||
                            (aluop_i == `EXE_MADD_OP) ||
                            (aluop_i == `EXE_MSUB_OP)) &&
                            (reg2_i[31] == 1'b1)) ? (~reg2_i+1) : reg2_i;

    // 3.得到临时乘法结果，保存在变量hilo_temp中
    assign hilo_temp = opdata1_mult * opdata2_mult;

    // 4.对临时乘法结果进行修正，最终的乘法结果保存在变量mulres中，主要有两点:
    //     1)如果是有符号乘法指令mult、mul、madd、msub，那么需要修正临时乘法结果如下:
    //         a)如果被乘数与乘数两者一正一负，那么需要对临时乘法结果hilo_temp
    //         求补码，作为最终的乘法结果，赋给变量mulres
    //         b)如果被乘数与乘数同号，那么hilo_temp的值就作为最终的乘法结果，
    //         赋给变量mulres
    //     2)如果是无符号乘法指令multu，那么hilo_temp的值就作为最终的乘法结果，
    //     赋值给变量mulres
    always @ ( * ) begin
        if(rst == `RstEnable) begin
            mulres <= {`ZeroWord, `ZeroWord};
        end else if((aluop_i == `EXE_MULT_OP) ||
                    (aluop_i == `EXE_MUL_OP) ||
                    (aluop_i == `EXE_MADD_OP) ||
                    (aluop_i == `EXE_MSUB_OP)) begin
            if(reg1_i[31] ^ reg2_i[31] == 1'b1) begin
                mulres <= ~hilo_temp + 1;
            end else begin
                mulres <= hilo_temp;
            end
        end else begin
            mulres <= hilo_temp;
        end
    end

    //madd、maddu、msub、msubu指令处理
    always @ ( * ) begin
        if(rst == `RstEnable) begin
            hilo_temp_o <= {`ZeroWord,`ZeroWord};
            cnt_o <= 2'b00;
            stallreq_for_madd_msub <= `NoStop;
        end else begin
            case(aluop_i)
                `EXE_MADD_OP, `EXE_MADDU_OP:begin
                    if(cnt_i == 2'b00) begin            //执行阶段第一个时钟周期
                        hilo_temp_o <= mulres;
                        cnt_o <= 2'b01;
                        hilo_temp1 <= {`ZeroWord,`ZeroWord};
                        stallreq_for_madd_msub <= `Stop;
                    end else if(cnt_i == 2'b01) begin   //执行阶段第二个时钟周期
                        hilo_temp_o <= {`ZeroWord,`ZeroWord};
                        cnt_o <= 2'b10;
                        hilo_temp1 <= hilo_temp_i + {HI,LO};
                        stallreq_for_madd_msub <= `NoStop;
                    end//else if(cnt_i == 2'b01)
                end//EXE_MADD_OP, EXE_MADDU_OP
                `EXE_MSUB_OP, `EXE_MSUBU_OP:begin
                    if(cnt_i == 2'b00) begin
                        hilo_temp_o <= ~mulres + 1;
                        cnt_o <= 2'b01;
                        stallreq_for_madd_msub <= `Stop;
                    end else if(cnt_i == 2'b01) begin
                        hilo_temp_o <= {`ZeroWord, `ZeroWord};
                        cnt_o <= 2'b10;
                        hilo_temp1 <= hilo_temp_i + {HI,LO};
                        stallreq_for_madd_msub <= `NoStop;
                    end//else if(cnt_i == 2'b01)
                end//EXE_MSUB_OP, EXE_MSUBU_OP
                default:begin
                    hilo_temp_o <= {`ZeroWord, `ZeroWord};
                    cnt_o <= 2'b00;
                    stallreq_for_madd_msub <= `NoStop;
                end
            endcase//case(aluop_i)
        end//else
    end

    //除法运算:输出DIV模块控制信息，获取DIV模块给出的结果
    always @ ( * ) begin
        if(rst == `RstEnable) begin
            stallreq_for_div <= `NoStop;
            div_opdata1_o <= `ZeroWord;
            div_opdata2_o <= `ZeroWord;
            div_start_o <= `DivStop;
            signed_div_o <= 1'b0;
        end else begin
            stallreq_for_div <= `NoStop;
            div_opdata1_o <= `ZeroWord;
            div_opdata2_o <= `ZeroWord;
            div_start_o <= `DivStop;
            signed_div_o <= 1'b0;
            case(aluop_i)
                `EXE_DIV_OP:begin
                    if(div_ready_i == `DivResultNotReady) begin
                        div_opdata1_o <= reg1_i;        //被除数
                        div_opdata2_o <= reg2_i;        //除数
                        div_start_o <= `DivStart;       //开始除法运算
                        signed_div_o <= 1'b1;           //有符号除法
                        stallreq_for_div <= `Stop;      //请求流水线暂停
                    end else if(div_ready_i == `DivResultReady) begin
                        div_opdata1_o <= reg1_i;
                        div_opdata2_o <= reg2_i;
                        div_start_o <= `DivStop;        //结束除法运算
                        signed_div_o <= 1'b1;
                        stallreq_for_div <= `NoStop;    //不再请求流水线暂停
                    end else begin
                        div_opdata1_o <= `ZeroWord;
                        div_opdata2_o <= `ZeroWord;
                        div_start_o <= `DivStop;
                        signed_div_o <= 1'b0;
                        stallreq_for_div <= `NoStop;
                    end
                end
                `EXE_DIVU_OP:begin
                    if(div_ready_i == `DivResultNotReady) begin
                        div_opdata1_o <= reg1_i;
                        div_opdata2_o <= reg2_i;
                        div_start_o <= `DivStart;
                        signed_div_o <= 1'b0;
                        stallreq_for_div <= `Stop;
                    end else if(div_ready_i == `DivResultReady) begin
                        div_opdata1_o <= reg1_i;
                        div_opdata2_o <= reg2_i;
                        div_start_o <= `DivStop;
                        signed_div_o <= 1'b0;
                        stallreq_for_div <= `NoStop;
                    end else begin
                        div_opdata1_o <= `ZeroWord;
                        div_opdata2_o <= `ZeroWord;
                        div_start_o <= `DivStop;
                        signed_div_o <= 1'b0;
                        stallreq_for_div <= `NoStop;
                    end
                end
                default:begin
                end
            endcase
        end//slse
    end

    //暂停流水线
    always @ ( * ) begin
        stallreq = stallreq_for_madd_msub || stallreq_for_div;
    end

//**************************判断是否发生自陷异常**********************************
//依据上面得到的比较结果，判断是否满足自陷指令的条件，从而给出变量trapassert的值
    always @ ( * ) begin
        if(rst == `RstEnable) begin
            trapassert <= `TrapNotAssert;
        end else begin
            trapassert <= `TrapNotAssert;
            case(aluop_i)
                `EXE_TEQ_OP,`EXE_TEQI_OP:begin
                    if(reg1_i == reg2_i) begin
                        trapassert <= `TrapAssert;
                    end
                end
                `EXE_TGE_OP,`EXE_TGEI_OP,`EXE_TGEU_OP,`EXE_TGEIU_OP:begin
                    if(~reg1_lt_reg2) begin
                        trapassert <= `TrapAssert;
                    end
                end
                `EXE_TLT_OP,`EXE_TLTI_OP,`EXE_TLTU_OP,`EXE_TLTIU_OP:begin
                    if(reg1_lt_reg2) begin
                        trapassert <= `TrapAssert;
                    end
                end
                `EXE_TNE_OP,`EXE_TNEI_OP:begin
                    if(reg1_i != reg2_i) begin
                        trapassert <= `TrapAssert;
                    end
                end
                default:begin
                    trapassert <= `TrapNotAssert;
                end
            endcase//case(aluop_i)
        end//else
    end//always


//******************************************************************************
//  依据alusel_i指示的运算类型，选择一个运算结果作为最终的结果(写回通用寄存器)
//******************************************************************************
    always @ ( * ) begin
        wd_o <= wd_i;                       //要写的目的寄存器地址

        //如果是add、addi、sub、subi指令，且发生溢出，那么设置wreg_o为WriteDisable,
        //表示不写目的寄存器；依据指令类型以及ov_sum的值判断是否发生溢出异常，从而给出
        //变量ovassert的值
        if(((aluop_i == `EXE_ADD_OP) || (aluop_i == `EXE_ADDI_OP) ||
            (aluop_i == `EXE_SUB_OP)) && (ov_sum == 1'b1)) begin
            wreg_o <= `WriteDisable;
            ovassert <= 1'b1;               //发生了溢出异常
        end else begin
            wreg_o <= wreg_i;
            ovassert <= 1'b0;               //没有发生溢出异常
        end

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
            `EXE_RES_ARITHMETIC:begin
                wdata_o <= arithmeticres;
            end
            `EXE_RES_MUL:begin
                wdata_o <= mulres[31:0];
            end
            `EXE_RES_JUMP_BRANCH:begin
                wdata_o <= link_address_i;
            end
            default:begin
                wdata_o <= `ZeroWord;
            end
        endcase
    end


//******************************************************************************
//                          特殊寄存器HI、LO写入控制
//******************************************************************************
    always @ ( * ) begin
        if(rst == `RstEnable) begin
            whilo_o <= `WriteDisable;
            hi_o <= `ZeroWord;
            lo_o <= `ZeroWord;
        end else if((aluop_i == `EXE_MULT_OP) ||
                    (aluop_i == `EXE_MULTU_OP)) begin
            whilo_o <= `WriteEnable;
            hi_o <= mulres[63:32];
            lo_o <= mulres[31:0];
        end else if(aluop_i == `EXE_MTHI_OP) begin
            whilo_o <= `WriteEnable;
            hi_o <= reg1_i;         //写HI寄存器，LO不变
            lo_o <= LO;
        end else if(aluop_i == `EXE_MTLO_OP) begin
            whilo_o <= `WriteEnable;
            hi_o <= HI;             //写LO寄存器，HI不变
            lo_o <= reg1_i;
        end else if((aluop_i == `EXE_MADD_OP) ||
                    (aluop_i == `EXE_MADDU_OP)) begin
            whilo_o <= `WriteEnable;
            hi_o <= hilo_temp1[63:32];
            lo_o <= hilo_temp1[31:0];
        end else if((aluop_i == `EXE_MSUB_OP) ||
                    (aluop_i == `EXE_MSUBU_OP)) begin
            whilo_o <= `WriteEnable;
            hi_o <= hilo_temp1[63:32];
            lo_o <= hilo_temp1[31:0];
        end else if((aluop_i == `EXE_DIV_OP) ||
                    (aluop_i == `EXE_DIVU_OP)) begin
            whilo_o <= `WriteEnable;
            hi_o <= div_result_i[63:32];
            lo_o <= div_result_i[31:0];
        end else begin
            whilo_o <= `WriteDisable;
            hi_o <= `ZeroWord;
            lo_o <= `ZeroWord;
        end
    end


//******************************************************************************
//                          加载存储指令相关处理过程
//******************************************************************************
    //aluop_o传递到访存阶段，届时将利用其确定加载、存储类型
    assign aluop_o = aluop_i;
    //mem_addr_o会传递到访存阶段，是加载存储指令对应的存储器地址，此处的reg1_i就是加载
    //存储指令中地址为base的通用寄存器的值，inst_i[15:0]就是指令中的offset
    assign mem_addr_o = reg1_i + {{16{inst_i[15]}},inst_i[15:0]};
    //reg2_i是存储指令要存储的数据，或者lwl、lwr指令要加载到的目的寄存器的原始值
    assign reg2_o = reg2_i;


//******************************************************************************
//                            mtc0指令执行过程
//******************************************************************************
    always @ ( * ) begin
        if(rst == `RstEnable) begin
            cp0_reg_we_o <= `WriteDisable;
            cp0_reg_write_addr_o <= 5'b00000;
            cp0_reg_data_o <= `ZeroWord;
        end else if(aluop_i == `EXE_MTC0_OP) begin
            cp0_reg_we_o <= `WriteEnable;
            cp0_reg_write_addr_o <= inst_i[15:11];
            cp0_reg_data_o <= reg1_i;
        end else begin
            cp0_reg_we_o <= `WriteDisable;
            cp0_reg_write_addr_o <= 5'b00000;
            cp0_reg_data_o <= `ZeroWord;
        end
    end

endmodule
