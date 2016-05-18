`timescale 1ns / 1ps
//******************************************************************************
// 对指令进行译码，得到最终运算的类型、子类型、源操作数1、源操作数2、要写入的
// 目的寄存器地址等
//
//                            代码重构
// 1)译码部分可以重构，利用操作码op和函数码op3完全可以区分开大部分指令，使用其他条件的
// 单独处理
// 2)每条指令下的输出赋值如果符合默认情况可以删除掉
//******************************************************************************

`include "defines.v"

module id(
    input wire rst,
    input wire[`InstAddrBus] pc_i,          //译码阶段的指令对应的地址
    input wire[`InstBus] inst_i,            //译码阶段的指令

    //与指令存储器ROM的接口
    //输出到regfile的信息
    output reg reg1_read_o,                 //Regfile模块的第一个读寄存器端口的使能信号
    output reg reg2_read_o,                 //Regfile模块的第二个读寄存器端口的使能信号
    output reg[`RegAddrBus] reg1_addr_o,    //Regfile模块的第一个读寄存器端口的读地址信号
    output reg[`RegAddrBus] reg2_addr_o,    //Regfile模块的第二个读寄存器端口的读地址信号
    //读取的regfile的值
    input wire[`RegBus] reg1_data_i,        //从Regfile输入的第一个读寄存器端口的输入
    input wire[`RegBus] reg2_data_i,        //从Regfile输入的第二个读寄存器端口的输入

    //送到执行阶段的信息
    output reg[`AluOpBus] aluop_o,          //译码阶段的指令要进行的运算的子类型
    output reg[`AluSelBus] alusel_o,        //译码阶段的指令要进行的运算的类型
    output reg[`RegBus] reg1_o,             //译码阶段的指令要进行的运算的源操作数1
    output reg[`RegBus] reg2_o,             //译码阶段的指令要进行的运算的源操作数2
    output reg wreg_o,                      //译码阶段的指令是否有要写入的通用寄存器
    output reg[`RegAddrBus] wd_o,           //译码阶段的指令要写入的目的寄存器地址

    //用于加载存储指令，将指令传递到执行阶段
    output wire[`RegBus] inst_o,

    //执行阶段指令的运算结果前推
    input wire ex_wreg_i,
    input wire[`RegAddrBus] ex_wd_i,
    input wire[`RegBus] ex_wdata_i,

    //访存阶段指令的运算结果前推
    input wire mem_wreg_i,
    input wire[`RegAddrBus] mem_wd_i,
    input wire[`RegBus] mem_wdata_i,

    //加载、存储指令输出暂停流水线信号
    output wire stallreq,

    //转移指令相关控制信号
    //传递到PC模块
    output reg branch_flag_o,
    output reg[`RegBus] branch_target_address_o,
    //传递到下一级流水线
    output reg[`RegBus] link_addr_o,                //返回地址
    output reg is_in_delayslot_o,                   //传递到EX阶段
    //如果一条指令为分支跳转指令，会设置next_inst_in_delayslot_o为true，表示下一条
    //指令为延迟槽指令，next_inst_in_delayslot_o连接到ID/EX模块的next_inst_in_delayslot_i,
    //经过ID/EX时序逻辑的一个时钟周期延迟，从ID/EX模块的is_in_delayslot_o输出到ID模块
    //的is_in_delayslot_i，此时下一条指令正好在译码阶段，表示此指令为延迟槽指令
    input wire is_in_delayslot_i,
    output reg next_inst_in_delayslot_o,

    //用于解决load相关新增加的接口
    input wire[`AluOpBus] ex_aluop_i,

    //异常处理相关接口
    output wire[31:0] excepttype_o,                     //收集的异常信息
    output wire[`InstAddrBus] current_inst_address_o    //译码阶段指令的地址
    );

//***********************  分析指令，判断指令的操作种类  **************************
    //6位指令码op
    wire[5:0] op = inst_i[31:26];
    //op2为移位位数shamt
    wire[4:0] op2 = inst_i[10:6];
    //6位功能码op3
    wire[5:0] op3 = inst_i[5:0];
    //指令rt段，部分指令用此字段区分
    wire[4:0] op4 = inst_i[20:16];

    //保存指令执行需要的立即数
    reg[`RegBus] imm;

    //指示指令是否有效，无效指令会产生异常
    reg instvalid;

    //转移指令相关
    wire[`RegBus] pc_plus_8;
    wire[`RegBus] pc_plus_4;
    wire[`RegBus] imm_sll2_signedext;

    //要读取的寄存器1是否与上一条指令存在load相关
    reg stallreq_for_reg1_loadrelate;
    //要读取的寄存器2是否与上一条指令存在load相关
    reg stallreq_for_reg2_loadrelate;
    //上一条指令是否是加载指令
    wire pre_inst_is_load;

    //异常相关
    reg excepttype_is_syscall;          //是否是系统调用异常syscall
    reg excepttype_is_eret;             //是否是异常返回指令eret


    assign pc_plus_8 = pc_i + 8;        //保存当前译码阶段指令后面第2条指令地址
    assign pc_plus_4 = pc_i + 4;        //保存当前译码阶段指令后面紧接着的指令地址

    //imm_sll2_signedext对应分支指令中的offset左移两位，再符号扩展至32位的值
    assign imm_sll2_signedext ={{14{inst_i[15]}},inst_i[15:0],2'b00};

    assign stallreq = stallreq_for_reg1_loadrelate | stallreq_for_reg2_loadrelate;

    //依据输入信号ex_aluop_i的值，判断上一条指令是否是加载指令(会更改寄存器值的指令)
    assign pre_inst_is_load = ((ex_aluop_i == `EXE_LB_OP) ||
                              (ex_aluop_i == `EXE_LBU_OP)||
                              (ex_aluop_i == `EXE_LH_OP) ||
                              (ex_aluop_i == `EXE_LHU_OP)||
                              (ex_aluop_i == `EXE_LW_OP) ||
                              (ex_aluop_i == `EXE_LWR_OP)||
                              (ex_aluop_i == `EXE_LWL_OP)||
                              (ex_aluop_i == `EXE_LL_OP) ||
                              (ex_aluop_i == `EXE_SC_OP)) ? 1'b1 : 1'b0;

    assign inst_o = inst_i;

    //excepttype_o的低8bit留给外部中断，第8bit表示是否是syscall指令引起的系统调用异常，
    //第9bit表示是否是无效指令引起的异常，第12bit表示是否是eret指令，eret指令认为是一种
    //特殊的异常——返回异常
    assign excepttype_o = {19'b0,excepttype_is_eret,2'b00,instvalid,
                            excepttype_is_syscall,8'b0000_0000};

    //输入信号pc_i就是当前处于译码阶段的指令的地址
    assign current_inst_address_o = pc_i;

//******************************************************************************
//  第一段：对指令进行译码,从三方面信息考虑:
//  1.要执行的运算:alusel、aluop
//  2.要读取的寄存器(操作数)情况:reg1、reg2、imm
//  3.要写入的目的寄存器:wreg_o、wd_o
//******************************************************************************
    always @ ( * ) begin
        if(rst == `RstEnable) begin
            aluop_o <= `EXE_NOP_OP;
            alusel_o <= `EXE_RES_NOP;
            reg1_read_o <= 1'b0;
            reg2_read_o <= 1'b0;
            reg1_addr_o <= `NOPRegAddr;
            reg2_addr_o <= `NOPRegAddr;
            imm <= `ZeroWord;
            wreg_o <= `WriteDisable;
            wd_o <= `NOPRegAddr;
            instvalid <= `InstValid;

            branch_flag_o <= `NotBranch;
            branch_target_address_o <= `ZeroWord;

            link_addr_o <= `ZeroWord;

            next_inst_in_delayslot_o <= `NotInDelaySlot;

            excepttype_is_syscall <= `False_v;
            excepttype_is_eret <= `False_v;

        //复位无效,设置各个信息的默认值
        end else begin
            aluop_o <= `EXE_NOP_OP;
            alusel_o <= `EXE_RES_NOP;
            reg1_read_o <= 1'b0;
            reg2_read_o <= 1'b0;
            reg1_addr_o <= inst_i[25:21];           //默认源操作数1地址为rs
            reg2_addr_o <= inst_i[20:16];           //默认源操作数2地址为rt
            imm <= `ZeroWord;                       //默认立即数imm
            wreg_o <= `WriteDisable;
            wd_o <= inst_i[15:11];                  //默认目的寄存器地址为rd

            branch_flag_o <= `NotBranch;
            branch_target_address_o <= `ZeroWord;

            link_addr_o <= `ZeroWord;

            next_inst_in_delayslot_o <= `NotInDelaySlot;

            excepttype_is_syscall <= `False_v;      //默认没有系统调用异常
            excepttype_is_eret <= `False_v;         //默认不是eret指令
            instvalid <= `InstInvalid;              //默认是无效指令

            //译码部分，由op指令码分支
            case(op)
                //指令码是SPECIAL
                `EXE_SPECIAL_INST:begin
                    case(op2)
                        //SPECIAL类中op2部分为0的指令
                        5'b00000:begin
                            //功能码op3分支
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
                                `EXE_DIV:begin
                                    wreg_o <= `WriteDisable;
                                    aluop_o <= `EXE_DIV_OP;
                                    reg1_read_o <= 1'b1;
                                    reg2_read_o <= 1'b1;
                                    instvalid <= `InstValid;
                                end
                                `EXE_DIVU:begin
                                    wreg_o <= `WriteDisable;
                                    aluop_o <= `EXE_DIVU_OP;
                                    reg1_read_o <= 1'b1;
                                    reg2_read_o <= 1'b1;
                                    instvalid <= `InstValid;
                                end
                                `EXE_JR:begin
                                    wreg_o <= `WriteDisable;
                                    aluop_o <= `EXE_JR_OP;
                                    alusel_o <= `EXE_RES_JUMP_BRANCH;
                                    reg1_read_o <= 1'b1;
                                    reg2_read_o <= 1'b0;
                                    link_addr_o <= `ZeroWord;
                                    branch_target_address_o <= reg1_o;
                                    branch_flag_o <= `Branch;
                                    next_inst_in_delayslot_o <= `InDelaySlot;
                                    instvalid <= `InstValid;
                                end
                                `EXE_JALR:begin
                                    wreg_o <= `WriteEnable;
                                    aluop_o <= `EXE_JALR_OP;
                                    alusel_o <= `EXE_RES_JUMP_BRANCH;
                                    reg1_read_o <= 1'b1;
                                    reg2_read_o <= 1'b0;
                                    wd_o <= inst_i[15:11];
                                    link_addr_o <= pc_plus_8;
                                    branch_target_address_o <= reg1_o;
                                    branch_flag_o <= `Branch;
                                    next_inst_in_delayslot_o <= `InDelaySlot;
                                    instvalid <= `InstValid;
                                end
                                default:begin
                                end
                            endcase//case(op3)
                        end//5'b00000
                        default:begin
                        end
                    endcase//case(op2)

                    //SPECIAL类中op2不为0的指令，需要以功能码op3来分支
                    case(op3)
                        `EXE_TEQ:begin
                            aluop_o <= `EXE_TEQ_OP;
                            alusel_o <= `EXE_RES_NOP;
                            reg1_read_o <= 1'b1;
                            reg2_read_o <= 1'b1;
                            wreg_o <= `WriteDisable;
                            instvalid <= `InstValid;
                        end
                        `EXE_TGE:begin
                            aluop_o <= `EXE_TGE_OP;
                            alusel_o <= `EXE_RES_NOP;
                            reg1_read_o <= 1'b1;
                            reg2_read_o <= 1'b1;
                            wreg_o <= `WriteDisable;
                            instvalid <= `InstValid;
                        end
                        `EXE_TGEU:begin
                            aluop_o <= `EXE_TGEU_OP;
                            alusel_o <= `EXE_RES_NOP;
                            reg1_read_o <= 1'b1;
                            reg2_read_o <= 1'b1;
                            wreg_o <= `WriteDisable;
                            instvalid <= `InstValid;
                        end
                        `EXE_TLT:begin
                            aluop_o <= `EXE_TLT_OP;
                            alusel_o <= `EXE_RES_NOP;
                            reg1_read_o <= 1'b1;
                            reg2_read_o <= 1'b1;
                            wreg_o <= `WriteDisable;
                            instvalid <= `InstValid;
                        end
                        `EXE_TLTU:begin
                            aluop_o <= `EXE_TLTU_OP;
                            alusel_o <= `EXE_RES_NOP;
                            reg1_read_o <= 1'b1;
                            reg2_read_o <= 1'b1;
                            wreg_o <= `WriteDisable;
                            instvalid <= `InstValid;
                        end
                        `EXE_TNE:begin
                            aluop_o <= `EXE_TNE_OP;
                            alusel_o <= `EXE_RES_NOP;
                            reg1_read_o <= 1'b1;
                            reg2_read_o <= 1'b1;
                            wreg_o <= `WriteDisable;
                            instvalid <= `InstValid;
                        end
                        `EXE_SYSCALL:begin
                            aluop_o <= `EXE_SYSCALL_OP;
                            alusel_o <= `EXE_RES_NOP;
                            reg1_read_o <= 1'b0;
                            reg2_read_o <= 1'b0;
                            wreg_o <= `WriteDisable;
                            instvalid <= `InstValid;
                            excepttype_is_syscall <= `True_v;
                        end
                        default:begin
                        end
                    endcase//op3
                end//`EXE_SPECIAL_INST


                //以指令码op就可以区分的指令
                //与立即数指令
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
                        `EXE_MADD:begin
                            wreg_o <= `WriteDisable;
                            aluop_o <= `EXE_MADD_OP;
                            alusel_o <= `EXE_RES_MUL;   //此处没有作用
                            reg1_read_o <= 1'b1;
                            reg2_read_o <= 1'b1;
                            instvalid <= `InstValid;
                        end
                        `EXE_MADDU:begin
                            wreg_o <= `WriteDisable;
                            aluop_o <= `EXE_MADDU_OP;
                            alusel_o <= `EXE_RES_MUL;
                            reg1_read_o <= 1'b1;
                            reg2_read_o <= 1'b1;
                            instvalid <= `InstValid;
                        end
                        `EXE_MSUB:begin
                            wreg_o <= `WriteDisable;
                            aluop_o <= `EXE_MSUB_OP;
                            alusel_o <= `EXE_RES_MUL;
                            reg1_read_o <= 1'b1;
                            reg2_read_o <= 1'b1;
                            instvalid <= `InstValid;
                        end
                        `EXE_MSUBU:begin
                            wreg_o <= `WriteDisable;
                            aluop_o <= `EXE_MSUBU_OP;
                            alusel_o <= `EXE_RES_MUL;
                            reg1_read_o <= 1'b1;
                            reg2_read_o <= 1'b1;
                            instvalid <= `InstValid;
                        end
                        default:begin
                        end
                    endcase//case(op3)
                end//EXE_SPECIAL2_INST

                `EXE_J:begin
                    wreg_o <= `WriteDisable;
                    aluop_o <= `EXE_J_OP;
                    alusel_o <= `EXE_RES_JUMP_BRANCH;
                    reg1_read_o <= 1'b0;
                    reg2_read_o <= 1'b0;
                    link_addr_o <= `ZeroWord;
                    branch_flag_o <= `Branch;
                    next_inst_in_delayslot_o <= `InDelaySlot;
                    instvalid <= `InstValid;
                    branch_target_address_o <=
                    {pc_plus_4[31:28],inst_i[25:0],2'b00};
                end
                `EXE_JAL:begin
                    wreg_o <= `WriteEnable;
                    aluop_o <= `EXE_JAL_OP;
                    alusel_o <= `EXE_RES_JUMP_BRANCH;
                    reg1_read_o <= 1'b0;
                    reg2_read_o <= 1'b0;
                    wd_o <= 5'b11111;
                    link_addr_o <= pc_plus_8;
                    branch_flag_o <= `Branch;
                    next_inst_in_delayslot_o <= `InDelaySlot;
                    instvalid <= `InstValid;
                    branch_target_address_o <=
                    {pc_plus_4[31:28],inst_i[25:0],2'b00};
                end
                `EXE_BEQ:begin
                    wreg_o <= `WriteDisable;
                    aluop_o <= `EXE_BEQ_OP;
                    alusel_o <= `EXE_RES_JUMP_BRANCH;
                    reg1_read_o <= 1'b1;
                    reg2_read_o <= 1'b1;
                    instvalid <= `InstValid;
                    if(reg1_o == reg2_o) begin
                        branch_target_address_o <=
                        pc_plus_4 + imm_sll2_signedext;
                        branch_flag_o <= `Branch;
                        next_inst_in_delayslot_o <= `InDelaySlot;
                    end
                end
                `EXE_BGTZ:begin
                    wreg_o <= `WriteDisable;
                    aluop_o <= `EXE_BGTZ_OP;
                    alusel_o <= `EXE_RES_JUMP_BRANCH;
                    reg1_read_o <= 1'b1;
                    reg2_read_o <= 1'b0;
                    instvalid <= `InstValid;
                    if((reg1_o[31] == 1'b0) && (reg1_o != `ZeroWord)) begin
                        branch_target_address_o <=
                        pc_plus_4 + imm_sll2_signedext;
                        branch_flag_o <= `Branch;
                        next_inst_in_delayslot_o <= `InDelaySlot;
                    end
                end
                `EXE_BLEZ:begin
                    wreg_o <= `WriteDisable;
                    aluop_o <= `EXE_BLEZ_OP;
                    alusel_o <= `EXE_RES_JUMP_BRANCH;
                    reg1_read_o <= 1'b1;
                    reg2_read_o <= 1'b0;
                    instvalid <= `InstValid;
                    if((reg1_o[31] == 1'b1) || (reg1_o == `ZeroWord)) begin
                        branch_target_address_o <=
                        pc_plus_4 + imm_sll2_signedext;
                        branch_flag_o <= `Branch;
                        next_inst_in_delayslot_o <= `InDelaySlot;
                    end
                end
                `EXE_BNE:begin
                    wreg_o <= `WriteDisable;
                    aluop_o <= `EXE_BLEZ_OP;
                    alusel_o <= `EXE_RES_JUMP_BRANCH;
                    reg1_read_o <= 1'b1;
                    reg2_read_o <= 1'b1;
                    instvalid <= `InstValid;
                    if(reg1_o != reg2_o) begin
                        branch_target_address_o <=
                        pc_plus_4 + imm_sll2_signedext;
                        branch_flag_o <= `Branch;
                        next_inst_in_delayslot_o <= `InDelaySlot;
                    end
                end

                `EXE_REGIMM_INST:begin
                    case(op4)
                        `EXE_BGEZ:begin
                            wreg_o <= `WriteDisable;
                            aluop_o <= `EXE_BGEZ_OP;
                            alusel_o <= `EXE_RES_JUMP_BRANCH;
                            reg1_read_o <= 1'b1;
                            reg2_read_o <= 1'b0;
                            instvalid <= `InstValid;
                            if(reg1_o[31] == 1'b0) begin
                                branch_target_address_o <=
                                pc_plus_4 + imm_sll2_signedext;
                                branch_flag_o <= `Branch;
                                next_inst_in_delayslot_o <= `InDelaySlot;
                            end
                        end
                        `EXE_BGEZAL:begin
                            wreg_o <= `WriteEnable;
                            aluop_o <= `EXE_BGEZAL_OP;
                            alusel_o <= `EXE_RES_JUMP_BRANCH;
                            reg1_read_o <= 1'b1;
                            reg2_read_o <= 1'b0;
                            link_addr_o <= pc_plus_8;
                            wd_o <= 5'b11111;
                            instvalid <= `InstValid;
                            if(reg1_o[31] == 1'b0) begin
                                branch_target_address_o <=
                                pc_plus_4 + imm_sll2_signedext;
                                branch_flag_o <= `Branch;
                                next_inst_in_delayslot_o <= `InDelaySlot;
                            end
                        end
                        `EXE_BLTZ:begin
                            wreg_o <= `WriteDisable;
                            aluop_o <= `EXE_BGEZAL_OP;
                            alusel_o <= `EXE_RES_JUMP_BRANCH;
                            reg1_read_o <= 1'b1;
                            reg2_read_o <= 1'b0;
                            instvalid <= `InstValid;
                            if(reg1_o[31] == 1'b1) begin
                                branch_target_address_o <=
                                pc_plus_4 + imm_sll2_signedext;
                                branch_flag_o <= `Branch;
                                next_inst_in_delayslot_o <= `InDelaySlot;
                            end
                        end
                        `EXE_BLTZAL:begin
                            wreg_o <= `WriteEnable;
                            aluop_o <= `EXE_BGEZAL_OP;
                            alusel_o <= `EXE_RES_JUMP_BRANCH;
                            reg1_read_o <= 1'b1;
                            reg2_read_o <= 1'b0;
                            link_addr_o <= pc_plus_8;
                            wd_o <= 5'b11111;
                            instvalid <= `InstValid;
                            if(reg1_o[31] == 1'b1) begin
                                branch_target_address_o <=
                                pc_plus_4 + imm_sll2_signedext;
                                branch_flag_o <= `Branch;
                                next_inst_in_delayslot_o <= `InDelaySlot;
                            end
                        end
                        `EXE_TEQI:begin
                            aluop_o <= `EXE_TEQI_OP;
                            alusel_o <= `EXE_RES_NOP;
                            reg1_read_o <= 1'b1;
                            reg2_read_o <= 1'b0;
                            imm <= {{16{inst_i[15]}},inst_i[15:0]};
                            wreg_o <= `WriteDisable;
                            instvalid <= `InstValid;
                        end
                        `EXE_TGEI:begin
                            aluop_o <= `EXE_TGEI_OP;
                            alusel_o <= `EXE_RES_NOP;
                            reg1_read_o <= 1'b1;
                            reg2_read_o <= 1'b0;
                            imm <= {{16{inst_i[15]}},inst_i[15:0]};
                            wreg_o <= `WriteDisable;
                            instvalid <= `InstValid;
                        end
                        `EXE_TGEIU:begin
                            aluop_o <= `EXE_TGEIU_OP;
                            alusel_o <= `EXE_RES_NOP;
                            reg1_read_o <= 1'b1;
                            reg2_read_o <= 1'b0;
                            imm <= {{16{inst_i[15]}},inst_i[15:0]};
                            wreg_o <= `WriteDisable;
                            instvalid <= `InstValid;
                        end
                        `EXE_TLTI:begin
                            aluop_o <= `EXE_TLTI_OP;
                            alusel_o <= `EXE_RES_NOP;
                            reg1_read_o <= 1'b1;
                            reg2_read_o <= 1'b0;
                            imm <= {{16{inst_i[15]}},inst_i[15:0]};
                            wreg_o <= `WriteDisable;
                            instvalid <= `InstValid;
                        end
                        `EXE_TLTIU:begin
                            aluop_o <= `EXE_TLTIU_OP;
                            alusel_o <= `EXE_RES_NOP;
                            reg1_read_o <= 1'b1;
                            reg2_read_o <= 1'b0;
                            imm <= {{16{inst_i[15]}},inst_i[15:0]};
                            wreg_o <= `WriteDisable;
                            instvalid <= `InstValid;
                        end
                        `EXE_TNEI:begin
                            aluop_o <= `EXE_TNEI_OP;
                            alusel_o <= `EXE_RES_NOP;
                            reg1_read_o <= 1'b1;
                            reg2_read_o <= 1'b0;
                            imm <= {{16{inst_i[15]}},inst_i[15:0]};
                            wreg_o <= `WriteDisable;
                            instvalid <= `InstValid;
                        end
                        default:begin
                        end
                    endcase//case(op4)
                end//EXE_REGIMM_INST

                `EXE_LB:begin
                    wreg_o <= `WriteEnable;
                    aluop_o <= `EXE_LB_OP;
                    alusel_o <= `EXE_RES_LOAD_STORE;
                    reg1_read_o <= 1'b1;
                    reg2_read_o <= 1'b0;
                    wd_o <= inst_i[20:16];
                    instvalid <= `InstValid;
                end
                `EXE_LBU:begin
                    wreg_o <= `WriteEnable;
                    aluop_o <= `EXE_LBU_OP;
                    alusel_o <= `EXE_RES_LOAD_STORE;
                    reg1_read_o <= 1'b1;
                    reg2_read_o <= 1'b0;
                    wd_o <= inst_i[20:16];
                    instvalid <= `InstValid;
                end
                `EXE_LH:begin
                    wreg_o <= `WriteEnable;
                    aluop_o <= `EXE_LH_OP;
                    alusel_o <= `EXE_RES_LOAD_STORE;
                    reg1_read_o <= 1'b1;
                    reg2_read_o <= 1'b0;
                    wd_o <= inst_i[20:16];
                    instvalid <= `InstValid;
                end
                `EXE_LHU:begin
                    wreg_o <= `WriteEnable;
                    aluop_o <= `EXE_LHU_OP;
                    alusel_o <= `EXE_RES_LOAD_STORE;
                    reg1_read_o <= 1'b1;
                    reg2_read_o <= 1'b0;
                    wd_o <= inst_i[20:16];
                    instvalid <= `InstValid;
                end
                `EXE_LW:begin
                    wreg_o <= `WriteEnable;
                    aluop_o <= `EXE_LW_OP;
                    alusel_o <= `EXE_RES_LOAD_STORE;
                    reg1_read_o <= 1'b1;
                    reg2_read_o <= 1'b0;
                    wd_o <= inst_i[20:16];
                    instvalid <= `InstValid;
                end
                `EXE_LWL:begin
                    wreg_o <= `WriteEnable;
                    aluop_o <= `EXE_LWL_OP;
                    alusel_o <= `EXE_RES_LOAD_STORE;
                    reg1_read_o <= 1'b1;
                    reg2_read_o <= 1'b1;    //保持目的寄存器低位不变，因此要读出寄存器中的值
                    wd_o <= inst_i[20:16];
                    instvalid <= `InstValid;
                end
                `EXE_LWR:begin
                    wreg_o <= `WriteEnable;
                    aluop_o <= `EXE_LWR_OP;
                    alusel_o <= `EXE_RES_LOAD_STORE;
                    reg1_read_o <= 1'b1;
                    reg2_read_o <= 1'b1;
                    wd_o <= inst_i[20:16];
                    instvalid <= `InstValid;
                end
                `EXE_SB:begin
                    wreg_o <= `WriteDisable;
                    aluop_o <= `EXE_SB_OP;
                    alusel_o <= `EXE_RES_LOAD_STORE;
                    reg1_read_o <= 1'b1;
                    reg2_read_o <= 1'b1;
                    instvalid <= `InstValid;
                end
                `EXE_SH:begin
                    wreg_o <= `WriteDisable;
                    aluop_o <= `EXE_SH_OP;
                    alusel_o <= `EXE_RES_LOAD_STORE;
                    reg1_read_o <= 1'b1;
                    reg2_read_o <= 1'b1;
                    instvalid <= `InstValid;
                end
                `EXE_SW:begin
                    wreg_o <= `WriteDisable;
                    aluop_o <= `EXE_SW_OP;
                    alusel_o <= `EXE_RES_LOAD_STORE;
                    reg1_read_o <= 1'b1;
                    reg2_read_o <= 1'b1;
                    instvalid <= `InstValid;
                end
                `EXE_SWL:begin
                    wreg_o <= `WriteDisable;
                    aluop_o <= `EXE_SWL_OP;
                    alusel_o <= `EXE_RES_LOAD_STORE;
                    reg1_read_o <= 1'b1;
                    reg2_read_o <= 1'b1;
                    instvalid <= `InstValid;
                end
                `EXE_SWR:begin
                    wreg_o <= `WriteDisable;
                    aluop_o <= `EXE_SWR_OP;
                    alusel_o <= `EXE_RES_LOAD_STORE;
                    reg1_read_o <= 1'b1;
                    reg2_read_o <= 1'b1;
                    instvalid <= `InstValid;
                end
                `EXE_LL:begin
                    wreg_o <= `WriteEnable;
                    aluop_o <= `EXE_LL_OP;
                    alusel_o <= `EXE_RES_LOAD_STORE;
                    reg1_read_o <= 1'b1;
                    reg2_read_o <= 1'b0;
                    wd_o <= inst_i[20:16];
                    instvalid <= `InstValid;
                end
                `EXE_SC:begin
                    wreg_o <= `WriteEnable;
                    aluop_o <= `EXE_SC_OP;
                    alusel_o <= `EXE_RES_LOAD_STORE;
                    reg1_read_o <= 1'b1;
                    reg2_read_o <= 1'b1;
                    wd_o <= inst_i[20:16];
                    instvalid <= `InstValid;
                end
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

            //mfc0指令
            if(inst_i[31:21] == 11'b010000_00000 &&
                inst_i[10:0] == 11'b00000000_000) begin
                aluop_o <= `EXE_MFC0_OP;
                alusel_o <= `EXE_RES_MOVE;
                wd_o <= inst_i[20:16];
                wreg_o <= `WriteEnable;
                instvalid <= `InstValid;
                reg1_read_o <= 1'b0;
                reg2_read_o <= 1'b0;
            //mtc0指令
            end else if(inst_i[31:21] == 11'b010000_00100 &&
                inst_i[10:0] == 11'b00000000_000) begin
                aluop_o <= `EXE_MTC0_OP;
                alusel_o <= `EXE_RES_NOP;
                wreg_o <= `WriteDisable;
                instvalid <= `InstValid;
                reg1_read_o <= 1'b1;
                reg2_read_o <= 1'b0;
                reg1_addr_o <= inst_i[20:16];
            //eret指令
            end else if(inst_i == `EXE_ERET) begin
                aluop_o <= `EXE_ERET_OP;
                alusel_o <= `EXE_RES_NOP;
                reg1_read_o <= 1'b0;
                reg2_read_o <= 1'b0;
                wreg_o <= `WriteDisable;
                instvalid <= `InstValid;
                excepttype_is_eret <= `True_v;
            end

        end//else(复位信号无效，设置各个信号默认值)
    end//always

//******************************************************************************
//                      第二段：确定进行运算的源操作数1
//  为了解决相邻指令RAW数据相关和隔一条指令的RAW数据相关，给reg1_o赋值的过程增加了两
//种情况：
//  1.如果regfile模块读端口1要读取的寄存器就是执行阶段要写的目的寄存器，那么直接把执行
//阶段的结果ex_wdata_i作为reg1_o的值
//  2.如果regfile模块读端口1要读取的寄存器就是访存阶段要写的目的寄存器，那么直接把访存
//阶段的结果mem_wdata_i作为reg1_o的值
//
//  解决load相关问题：如果上一条指令是加载指令，且该加载指令要加载到的目的寄存器就是
//当前指令要通过regfile模块读端口1读取的通用寄存器，那么表示存在load相关，设置
//stallreq_for_reg1_loadrelate为Stop
//******************************************************************************
    always @ ( * ) begin
        stallreq_for_reg1_loadrelate <= `NoStop;
        if(rst == `RstEnable) begin
            reg1_o <= `ZeroWord;
        end else if((pre_inst_is_load == 1'b1) && (ex_wd_i == reg1_addr_o) &&
                    (reg1_read_o == 1'b1)) begin
            stallreq_for_reg1_loadrelate <= `Stop;
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
//
//  解决load相关问题：如果上一条指令是加载指令，且该加载指令要加载到的目的寄存器就是
//当前指令要通过regfile模块读端口2读取的通用寄存器，那么表示存在load相关，设置
//stallreq_for_reg2_loadrelate为Stop
//******************************************************************************
    always @ ( * ) begin
        stallreq_for_reg2_loadrelate <= `NoStop;
        if(rst == `RstEnable) begin
            reg2_o <= `ZeroWord;
        end else if((pre_inst_is_load == 1'b1) && (ex_wd_i == reg2_addr_o) &&
                    (reg2_read_o == 1'b1)) begin
            stallreq_for_reg2_loadrelate <= `Stop;
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

//******************************************************************************
//  输出变量is_in_delayslot_o表示当前译码阶段指令是否是延迟槽指令
//******************************************************************************
    always @ ( * ) begin
        if(rst == `RstEnable) begin
            is_in_delayslot_o <= `NotInDelaySlot;
        end else begin
            is_in_delayslot_o <= is_in_delayslot_i;
        end
    end

endmodule
