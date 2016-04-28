`timescale 1ns / 1ps
//********************************************
//  对指令进行译码，得到最终运算的类型、子类型、
//  源操作数1、源操作数2、要写入的目的寄存器地址等
//********************************************

module id(
    input wire rst,
    input wire[`InstAddrBus] pc_i,          //译码阶段的指令对应的地址
    input wire[`InstBus] inst_i,            //译码阶段的指令

    //读取的regfile的值
    input wire[`RegBus] reg1_data_i,        //从Regfile输入的第一个读寄存器端口的输入
    input wire[`RegBus] reg2_data_i,        //从Regfile输入的第二个读寄存器端口的输入

    //输出到regfile的信息
    output reg reg1_read_o,                 //Regfile模块的第一个读寄存器端口的使能信号
    output reg reg2_read_o,                 //Regfile模块的第二个读寄存器端口的使能信号
    output reg[`RegAddrBus] reg1_addr_o,    //Regfile模块的第一个读寄存器端口的读地址信号
    output reg[`RegAddrBus] reg2_addr_o,    //Regfile模块的第二个读寄存器端口的读地址信号

    //送到执行阶段的信息
    output reg[`AluOpBus] aluop_o,          //译码阶段的指令要进行的运算的子类型
    output reg[`AluSelBus] alusel_o,        //译码阶段的指令要进行的运算的类型
    output reg[`RegBus] reg1_o,             //译码阶段的指令要进行的运算的源操作数1
    output reg[`RegBus] reg2_o,             //译码阶段的指令要进行的运算的源操作数2
    output reg[`RegAddrBus] wd_o,           //译码阶段的指令要写入的目的寄存器地址
    output reg wreg_o,                      //译码阶段的指令是否有要写入的通用寄存器

    //执行阶段指令的运算结果前推
    input wire ex_wreg_i,
    input wire[`RegAddrBus] ex_wd_i,
    input wire[`RegBus] ex_wdata_i,

    //访存阶段指令的运算结果前推
    input wire mem_wreg_i,
    input wire[`RegAddrBus] mem_wd_i,
    input wire[`RegBus] mem_wdata_i
    );

//***************  分析指令，判断指令的操作种类  *******************
    //6位指令码op
    wire[5:0] op = inst_i[31:26];
    //如果op为SPECIAL类指令，再判断op2是否为0
    wire[4:0] op2 = inst_i[10:6];
    //6位功能码op3，如果op2为0，需要op3判断
    wire[5:0] op3 = inst_i[5:0];
    //指令rt段
    wire[4:0] op4 = inst_i[20:16];

    //保存指令执行需要的立即数
    reg[`RegBus] imm;

    //指示指令是否有效
    reg instvalid;

//******************************************************
//  第一段：对指令进行译码,从三方面信息考虑:
//  1.要读取的寄存器(操作数)情况:reg1、reg2、imm
//  2.要执行的运算:alusel、aluop
//  3.要写入的目的寄存器:wreg_o、wd_o
//******************************************************
    always @ ( * ) begin
        if(rst == `RstEnable) begin
            aluop_o <= `EXE_NOP_OP;
            alusel_o <= `EXE_RES_NOP;
            wd_o <= `NOPRegAddr;
            wreg_o <= `WriteDisable;
            instvalid <= `InstValid;
            reg1_read_o <= 1'b0;
            reg2_read_o <= 1'b0;
            reg1_addr_o <= `NOPRegAddr;
            reg2_addr_o <= `NOPRegAddr;
            imm <= 32'b0;

        //复位无效,设置各个信息的默认值
        end else begin
            aluop_o <= `EXE_NOP_OP;
            alusel_o <= `EXE_RES_NOP;
            wd_o <= inst_i[15:11];          //默认目的寄存器地址为rd
            wreg_o <= `WriteDisable;
            instvalid <= `InstInvalid;
            reg1_read_o <= 1'b0;
            reg2_read_o <= 1'b0;
            reg1_addr_o <= inst_i[25:21];   //默认源操作数1地址为rs
            reg2_addr_o <= inst_i[20:16];   //默认源操作数2地址为rt
            imm <= `ZeroWord;               //默认立即数imm

            //译码部分
            case(op)
                //指令码是SPECIAL
                `EXE_SPECIAL_INST:begin
                    case(op2)
                        //op2全0
                        5'b00000:begin
                            case(op3)
                                `EXE_OR:begin
                                    wreg_o <= `WriteEnable;
                                    aluop_o <= `EXE_OR_OP;
                                    alusel_o <= `EXE_RES_LOGIC;
                                    reg1_read_o <= 1'b1;
                                    reg2_read_o <= 1'b1;
                                    instvalid <= `InstValid;
                                end
                                `EXE_AND:begin
                                    wreg_o <= `WriteEnable;
                                    aluop_o <= `EXE_AND_OP;
                                    alusel_o <= `EXE_RES_LOGIC;
                                    reg1_read_o <= 1'b1;
                                    reg2_read_o <= 1'b1;
                                    instvalid <= `InstValid;
                                end
                                `EXE_XOR:begin
                                    wreg_o <= `WriteEnable;
                                    aluop_o <= `EXE_XOR_OP;
                                    alusel_o <= `EXE_RES_LOGIC;
                                    reg1_read_o <= 1'b1;
                                    reg2_read_o <= 1'b1;
                                    instvalid <= `InstValid;
                                end
                                `EXE_NOR:begin
                                    wreg_o <= `WriteEnable;
                                    aluop_o <= `EXE_NOR_OP;
                                    alusel_o <= `EXE_RES_LOGIC;
                                    reg1_read_o <= 1'b1;
                                    reg2_read_o <= 1'b1;
                                    instvalid <= `InstValid;
                                end
                                `EXE_SLLV:begin
                                    wreg_o <= `WriteEnable;
                                    aluop_o <= `EXE_SLL_OP;
                                    alusel_o <= `EXE_RES_SHIFT;
                                    reg1_read_o <= 1'b1;
                                    reg2_read_o <= 1'b1;
                                    instvalid <= `InstValid;
                                end
                                `EXE_SRLV:begin
                                    wreg_o <= `WriteEnable;
                                    aluop_o <= `EXE_SRL_OP;
                                    alusel_o <= `EXE_RES_SHIFT;
                                    reg1_read_o <= 1'b1;
                                    reg2_read_o <= 1'b1;
                                    instvalid <= `InstValid;
                                end
                                `EXE_SRAV:begin
                                    wreg_o <= `WriteEnable;
                                    aluop_o <= `EXE_SRA_OP;
                                    alusel_o <= `EXE_RES_SHIFT;
                                    reg1_read_o <= 1'b1;
                                    reg2_read_o <= 1'b1;
                                    instvalid <= `InstValid;
                                end
                                `EXE_SYNC:begin
                                    wreg_o <= `WriteDisable;
                                    aluop_o <= `EXE_NOP_OP;
                                    alusel_o <= `EXE_RES_NOP;
                                    reg1_read_o <= 1'b0;
                                    reg2_read_o <= 1'b1;
                                    instvalid <= `InstValid;
                                end
                                `EXE_MFHI:begin
                                    wreg_o <= `WriteEnable;
                                    aluop_o <= `EXE_MFHI_OP;
                                    alusel_o <= `EXE_RES_MOVE;
                                    reg1_read_o <= 1'b0;
                                    reg2_read_o <= 1'b0;
                                    instvalid <= `InstValid;
                                end
                                `EXE_MFLO:begin
                                    wreg_o <= `WriteEnable;
                                    aluop_o <= `EXE_MFLO_OP;
                                    alusel_o <= `EXE_RES_MOVE;
                                    reg1_read_o <= 1'b0;
                                    reg2_read_o <= 1'b0;
                                    instvalid <= `InstValid;
                                end
                                `EXE_MTHI:begin
                                    wreg_o <= `WriteDisable;
                                    aluop_o <= `EXE_MTHI_OP;
                                    reg1_read_o <= 1'b1;
                                    reg2_read_o <= 1'b0;
                                    instvalid <= `InstValid;
                                end
                                `EXE_MTLO:begin
                                    wreg_o <= `WriteDisable;
                                    aluop_o <= `EXE_MTLO_OP;
                                    reg1_read_o <= 1'b1;
                                    reg2_read_o <= 1'b0;
                                    instvalid <= `InstValid;
                                end
                                `EXE_MOVN:begin
                                    aluop_o <= `EXE_MOVN_OP;
                                    alusel_o <= `EXE_RES_MOVE;
                                    reg1_read_o <= 1'b1;
                                    reg2_read_o <= 1'b1;
                                    instvalid <= `InstValid;
                                    //reg2_o的值就是地址为rt的通用寄存器的值
                                    if(reg2_o != `ZeroWord) begin
                                        wreg_o <= `WriteEnable;
                                    end else begin
                                        wreg_o <= `WriteDisable;
                                    end
                                end
                                `EXE_MOVZ:begin
                                    aluop_o <= `EXE_MOVZ_OP;
                                    alusel_o <= `EXE_RES_MOVE;
                                    reg1_read_o <= 1'b1;
                                    reg2_read_o <= 1'b1;
                                    instvalid <= `InstValid;
                                    if(reg2_o == `ZeroWord) begin
                                        wreg_o <= `WriteEnable;
                                    end else begin
                                        wreg_o <= `WriteDisable;
                                    end
                                end
                                `EXE_SLT:begin
                                    wreg_o <= `WriteEnable;
                                    aluop_o <= `EXE_SLT_OP;
                                    alusel_o <= `EXE_RES_ARITHMETIC;
                                    reg1_read_o <= 1'b1;
                                    reg2_read_o <= 1'b1;
                                    instvalid <= `InstValid;
                                end
                                `EXE_SLTU:begin
                                    wreg_o <= `WriteEnable;
                                    aluop_o <= `EXE_SLTU_OP;
                                    alusel_o <= `EXE_RES_ARITHMETIC;
                                    reg1_read_o <= 1'b1;
                                    reg2_read_o <= 1'b1;
                                    instvalid <= `InstValid;
                                end
                                `EXE_ADD:begin
                                    wreg_o <= `WriteEnable;
                                    aluop_o <= `EXE_ADD_OP;
                                    alusel_o <= `EXE_RES_ARITHMETIC;
                                    reg1_read_o <= 1'b1;
                                    reg2_read_o <= 1'b1;
                                    instvalid <= `InstValid;
                                end
                                `EXE_ADDU:begin
                                    wreg_o <= `WriteEnable;
                                    aluop_o <= `EXE_ADDU_OP;
                                    alusel_o <= `EXE_RES_ARITHMETIC;
                                    reg1_read_o <= 1'b1;
                                    reg2_read_o <= 1'b1;
                                    instvalid <= `InstValid;
                                end
                                `EXE_SUB:begin
                                    wreg_o <= `WriteEnable;
                                    aluop_o <= `EXE_SUB_OP;
                                    alusel_o <= `EXE_RES_ARITHMETIC;
                                    reg1_read_o <= 1'b1;
                                    reg2_read_o <= 1'b1;
                                    instvalid <= `InstValid;
                                end
                                `EXE_SUBU:begin
                                    wreg_o <= `WriteEnable;
                                    aluop_o <= `EXE_SUBU_OP;
                                    alusel_o <= `EXE_RES_ARITHMETIC;
                                    reg1_read_o <= 1'b1;
                                    reg2_read_o <= 1'b1;
                                    instvalid <= `InstValid;
                                end
                                `EXE_MULT:begin
                                    wreg_o <= `WriteDisable;
                                    aluop_o <= `EXE_MULT_OP;
                                    reg1_read_o <= 1'b1;
                                    reg2_read_o <= 1'b1;
                                    instvalid <= `InstValid;
                                end
                                `EXE_MULTU:begin
                                    wreg_o <= `WriteDisable;
                                    aluop_o <= `EXE_MULTU_OP;
                                    reg1_read_o <= 1'b1;
                                    reg2_read_o <= 1'b1;
                                    instvalid <= `InstValid;
                                end
                                default:begin
                                end
                            endcase//case(op3)
                        end//5'b00000
                        default:begin
                        end
                    endcase//case(op2)
                end//`EXE_SPECIAL_INST

                //与立即数指令(指令码op)
                `EXE_ANDI:begin
                    wreg_o <= `WriteEnable;
                    aluop_o <= `EXE_AND_OP;
                    alusel_o <= `EXE_RES_LOGIC;
                    reg1_read_o <= 1'b1;
                    reg2_read_o <= 1'b0;
                    imm <= {16'h0, inst_i[15:0]};
                    wd_o <= inst_i[20:16];
                    instvalid <= `InstValid;
                end
                //或立即数指令
                `EXE_ORI:begin
                    //ori指令需要将结果写入目的寄存器
                    wreg_o <= `WriteEnable;
                    //运算的子类型是逻辑“或”运算
                    aluop_o <= `EXE_OR_OP;
                    //运算类型是逻辑运算
                    alusel_o <= `EXE_RES_LOGIC;
                    //需要通过regfile的读端口1读取寄存器
                    reg1_read_o <= 1'b1;
                    //不需要通过regfile的读端口2读取寄存器
                    reg2_read_o <= 1'b0;
                    //指令执行需要的立即数
                    imm <= {16'h0,inst_i[15:0]};
                    //指令执行要写的目的寄存器地址
                    wd_o <= inst_i[20:16];
                    //ori指令是有效指令
                    instvalid <= `InstValid;
                end
                //异或立即数
                `EXE_XORI:begin
                    wreg_o <= `WriteEnable;
                    aluop_o <= `EXE_XOR_OP;
                    alusel_o <= `EXE_RES_LOGIC;
                    reg1_read_o <= 1'b1;
                    reg2_read_o <= 1'b0;
                    imm <= {16'h0, inst_i[15:0]};
                    wd_o <= inst_i[20:16];
                    instvalid <= `InstValid;
                end
                //lui指令
                `EXE_LUI:begin
                    wreg_o <= `WriteEnable;
                    aluop_o <= `EXE_OR_OP;
                    alusel_o <= `EXE_RES_LOGIC;
                    reg1_read_o <= 1'b1;
                    reg2_read_o <= 1'b0;
                    imm <= {inst_i[15:0],16'h0};
                    wd_o <= inst_i[20:16];
                    instvalid <= `InstValid;
                end
                //pref指令
                `EXE_PREF:begin
                    wreg_o <= `WriteDisable;
                    aluop_o <= `EXE_NOP_OP;
                    alusel_o <= `EXE_RES_NOP;
                    reg1_read_o <= 1'b0;
                    reg2_read_o <= 1'b0;
                    instvalid <= `InstValid;
                end
                //slti指令
                `EXE_SLTI:begin
                    wreg_o <= `WriteEnable;
                    aluop_o <= `EXE_SLT_OP;
                    alusel_o <= `EXE_RES_ARITHMETIC;
                    reg1_read_o <= 1'b1;
                    reg2_read_o <= 1'b0;
                    imm <= {{16{inst_i[15]}},inst_i[15:0]};
                    wd_o <= inst_i[20:16];
                    instvalid <= `InstValid;
                end
                //sltiu指令
                `EXE_SLTIU:begin
                    wreg_o <= `WriteEnable;
                    aluop_o <= `EXE_SLTU_OP;
                    alusel_o <= `EXE_RES_ARITHMETIC;
                    reg1_read_o <= 1'b1;
                    reg2_read_o <= 1'b0;
                    imm <= {{16{inst_i[15]}},inst_i[15:0]};
                    wd_o <= inst_i[20:16];
                    instvalid <= `InstValid;
                end
                //addi指令
                `EXE_ADDI:begin
                    wreg_o <= `WriteEnable;
                    aluop_o <= `EXE_ADDI_OP;
                    alusel_o <= `EXE_RES_ARITHMETIC;
                    reg1_read_o <= 1'b1;
                    reg2_read_o <= 1'b0;
                    imm <= {{16{inst_i[15]}},inst_i[15:0]};
                    wd_o <= inst_i[20:16];
                    instvalid <= `InstValid;
                end
                //addiu指令
                `EXE_ADDIU:begin
                    wreg_o <= `WriteEnable;
                    aluop_o <= `EXE_ADDIU_OP;
                    alusel_o <= `EXE_RES_ARITHMETIC;
                    reg1_read_o <= 1'b1;
                    reg2_read_o <= 1'b0;
                    imm <= {{16{inst_i[15]}},inst_i[15:0]};
                    wd_o <= inst_i[20:16];
                    instvalid <= `InstValid;
                end
                `EXE_SPECIAL2_INST:begin
                    case(op3)
                        `EXE_CLZ:begin
                            wreg_o <= `WriteEnable;
                            aluop_o <= `EXE_CLZ_OP;
                            alusel_o <= `EXE_RES_ARITHMETIC;
                            reg1_read_o <= 1'b1;
                            reg2_read_o <= 1'b0;
                            instvalid <= `InstValid;
                        end
                        `EXE_CLO:begin
                            wreg_o <= `WriteEnable;
                            aluop_o <= `EXE_CLO_OP;
                            alusel_o <= `EXE_RES_ARITHMETIC;
                            reg1_read_o <= 1'b1;
                            reg2_read_o <= 1'b0;
                            instvalid <= `InstValid;
                        end
                        `EXE_MUL:begin
                            wreg_o <= `WriteEnable;
                            aluop_o <= `EXE_MUL_OP;
                            alusel_o <= `EXE_RES_MUL;
                            reg1_read_o <= 1'b1;
                            reg2_read_o <= 1'b1;
                            instvalid <= `InstValid;
                        end
                        default:begin
                        end
                    endcase//case(op3)
                end//EXE_SPECIAL2_INST
                default:begin
                end
            endcase//case(op)

            //sll、srl、sra指令:目的地址rd,立即数为sa
            if(inst_i[31:21] == 11'b00000000000) begin
                if(op3 == `EXE_SLL) begin
                    wreg_o <= `WriteEnable;
                    aluop_o <= `EXE_SLL_OP;
                    alusel_o <= `EXE_RES_SHIFT;
                    reg1_read_o <= 1'b0;
                    reg2_read_o <= 1'b1;
                    imm[4:0] <= inst_i[10:6];
                    wd_o <= inst_i[15:11];
                    instvalid <= `InstValid;
                end else if(op3 == `EXE_SRL) begin
                    wreg_o <= `WriteEnable;
                    aluop_o <= `EXE_SRL_OP;
                    alusel_o <= `EXE_RES_SHIFT;
                    reg1_read_o <= 1'b0;
                    reg2_read_o <= 1'b1;
                    imm[4:0] <= inst_i[10:6];
                    wd_o <= inst_i[15:11];
                    instvalid <= `InstValid;
                end else if(op3 == `EXE_SRA) begin
                    wreg_o <= `WriteEnable;
                    aluop_o <= `EXE_SRA_OP;
                    alusel_o <= `EXE_RES_SHIFT;
                    reg1_read_o <= 1'b0;
                    reg2_read_o <= 1'b1;
                    imm[4:0] <= inst_i[10:6];
                    wd_o <= inst_i[15:11];
                    instvalid <= `InstValid;
                end
            end//if(sll/srl/sra)
        end//else
    end//always

//******************************************************************************
//                      第二段：确定进行运算的源操作数1
//  为了解决相邻指令RAW数据相关和隔一条指令的RAW数据相关，给reg1_o赋值的过程增加了两
//种情况：
//  1.如果regfile模块读端口1要读取的寄存器就是执行阶段要写的目的寄存器，那么直接把执行
//阶段的结果ex_wdata_i作为reg1_o的值
//  2.如果regfile模块读端口1要读取的寄存器就是访存阶段要写的目的寄存器，那么直接把访存
//阶段的结果mem_wdata_i作为reg1_o的值
//******************************************************************************
    always @ ( * ) begin
        if(rst == `RstEnable) begin
            reg1_o <= `ZeroWord;
            //解决相邻指令间RAW数据相关的数据通路
        end else if((reg1_read_o == 1'b1) && (ex_wreg_i == 1'b1)
                    && (ex_wd_i == reg1_addr_o)) begin
            reg1_o <= ex_wdata_i;
            //解决间隔一条指令间RAW数据相关的数据通路
        end else if((reg1_read_o == 1'b1) && (mem_wreg_i == 1'b1)
                    && (mem_wd_i == reg1_addr_o)) begin
            reg1_o <= mem_wdata_i;
        end else if(reg1_read_o == 1'b1) begin
            reg1_o <= reg1_data_i;   //regfile读端口1的输出值
        end else if(reg1_read_o == 1'b0) begin      //为0即使用立即数
            reg1_o <= imm;
        end else begin
            reg1_o <= `ZeroWord;
        end
    end

//******************************************************************************
//                      第三段：确定进行运算的源操作数2
//  为了解决相邻指令RAW数据相关和隔一条指令的RAW数据相关，给reg2_o赋值的过程增加了两
//种情况：
//  1.如果regfile模块读端口2要读取的寄存器就是执行阶段要写的目的寄存器，那么直接把执行
//阶段的结果ex_wdata_i作为reg2_o的值
//  2.如果regfile模块读端口2要读取的寄存器就是访存阶段要写的目的寄存器，那么直接把访存
//阶段的结果mem_wdata_i作为reg2_o的值
//******************************************************************************
    always @ ( * ) begin
        if(rst == `RstEnable) begin
            reg2_o <= `ZeroWord;
            //解决相邻指令间RAW数据相关的数据通路
        end else if((reg2_read_o == 1'b1) && (ex_wreg_i == 1'b1)
                    && (ex_wd_i == reg2_addr_o)) begin
            reg2_o <= ex_wdata_i;
            //解决间隔一条指令间RAW数据相关的数据通路
        end else if((reg2_read_o == 1'b1) && (mem_wreg_i == 1'b1)
                    && (mem_wd_i == reg2_addr_o)) begin
            reg2_o <= mem_wdata_i;
        end else if(reg2_read_o == 1'b1) begin
            reg2_o <= reg2_data_i;   //regfile读端口2的输出值
        end else if(reg2_read_o == 1'b0) begin
            reg2_o <= imm;
        end else begin
            reg2_o <= `ZeroWord;
        end
    end
endmodule
