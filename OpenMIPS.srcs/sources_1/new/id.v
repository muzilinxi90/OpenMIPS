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
    output reg wreg_o                       //译码阶段的指令是否有要写入的目的寄存器
    );

    //取得指令的指令码，功能码
    //对于ori指令只需通过判断第26-31bit的值，即可判断是否是ori指令
    wire[5:0] op = inst_i[31:26];           //六位指令op
    wire[4:0] op2 = inst_i[10:6];           //R类指令sa部分
    wire[5:0] op3 = inst_i[5:0];            //R类指令func部分
    wire[4:0] op4 = inst_i[20:16];          //R类指令rt部分

    //保存指令执行需要的立即数
    reg[`RegBus] imm;

    //指示指令是否有效
    reg instvalid;

//******************************************************
//  第一段：对指令进行译码
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
        end else begin
            aluop_o <= `EXE_NOP_OP;
            alusel_o <= `EXE_RES_NOP;
            wd_o <= inst_i[15:11];          //R类指令rd部分，目的寄存器
            wreg_o <= `WriteDisable;
            instvalid <= `InstInvalid;
            reg1_read_o <= 1'b0;
            reg2_read_o <= 1'b0;
            reg1_addr_o <= inst_i[25:21];   //I类rs源操作数寄存器地址部分
            reg2_read_o <= inst_i[20:16];   //I类rd目的寄存器地址部分
            imm <= `ZeroWord;

            case (op)
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
                    imm <= {16'b0,inst_i[15:0]};
                    //指令执行要写的目的寄存器地址
                    wd_o <= inst_i[20:16];
                    //ori指令是有效指令
                    instvalid <= `InstValid;
                end

                default:begin
                end
            endcase//case
        end//else
    end//always

//******************************************************
//  第二段：确定进行运算的源操作数1
//******************************************************
    always @ ( * ) begin
        if(rst == `RstEnable) begin
            reg1_o <= `ZeroWord;
        end else if(reg1_read_o == 1'b1) begin
            reg1_o <= reg1_data_i;   //regfile读端口1的输出值
        end else if(reg1_read_o == 1'b0) begin
            reg1_o <= imm;
        end else begin
            reg1_o <= `ZeroWord;
        end
    end

//******************************************************
//  第三段：确定进行运算的源操作数2
//******************************************************
    always @ ( * ) begin
        if(rst == `RstEnable) begin
            reg2_o <= `ZeroWord;
        end else if(reg2_read_o == 1'b1) begin
            reg2_o <= reg2_data_i;   //regfile读端口2的输出值
        end else if(reg2_read_o == 1'b0) begin
            reg2_o <= imm;
        end else begin
            reg2_o <= `ZeroWord;
        end
    end
endmodule
