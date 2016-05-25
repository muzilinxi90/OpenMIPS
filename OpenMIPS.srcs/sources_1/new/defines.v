//******************************************************************************
//                             项目的全部宏定义
//******************************************************************************

//***************************   全局的宏定义   **********************************
`define RstEnable 1'b1              //复位信号有效
`define RstDisable 1'b0             //复位信号无效
`define ZeroWord 32'h0000_0000      //32位的数值0
`define WriteEnable 1'b1            //使能写
`define WriteDisable 1'b0           //禁止写
`define ReadEnable 1'b1             //使能读
`define ReadDisable 1'b0            //禁止读
`define AluOpBus 7:0                //译码阶段的输出aluop_o的宽度
`define AluSelBus 2:0               //译码阶段的输出alusel_o的宽度
`define True_v  1'b1                //逻辑“真”
`define False_v 1'b0                //逻辑“假”
`define ChipEnable  1'b1            //芯片使能
`define ChipDisable 1'b0            //芯片禁止


//***************************  与具体指令有关的宏定义  ***************************
//逻辑操作指令SPECIAL类的功能码
`define EXE_AND 6'b100100           //and指令功能码
`define EXE_OR 6'b100101            //or指令功能码
`define EXE_XOR 6'b100110           //xor指令功能码
`define EXE_NOR 6'b100111           //nor指令功能码
//逻辑操作指令其他指令码
`define EXE_ANDI 6'b001100          //andi指令码
`define EXE_ORI 6'b001101           //ori指令码
`define EXE_XORI 6'b001110          //xori指令码
`define EXE_LUI 6'b001111           //lui指令码

//移位操作指令功能码
`define EXE_SLL 6'b000000           //sll指令功能码
`define EXE_SLLV 6'b000100          //sllv指令功能码
`define EXE_SRL 6'b000010           //srl指令功能码
`define EXE_SRLV 6'b000110          //srlv指令功能码
`define EXE_SRA 6'b000011           //sra指令功能码
`define EXE_SRAV 6'b000111          //srav指令功能码

//移动操作指令功能码
`define EXE_MOVZ 6'b001010          //movz指令功能码
`define EXE_MOVN 6'b001011          //movn指令功能码
`define EXE_MFHI 6'b010000          //mfhi指令功能码
`define EXE_MTHI 6'b010001          //mthi指令功能码
`define EXE_MFLO 6'b010010          //mflo指令功能码
`define EXE_MTLO 6'b010011          //mtlo指令功能码

//算术操作指令
`define EXE_SLT 6'b101010           //slt指令功能码
`define EXE_SLTU 6'b101011          //sltu指令功能码
`define EXE_SLTI 6'b001010          //slti指令码
`define EXE_SLTIU 6'b001011         //sltiu指令码
`define EXE_ADD 6'b100000           //add指令功能码
`define EXE_ADDU 6'b100001          //addu指令功能码
`define EXE_SUB 6'b100010           //sub指令功能码
`define EXE_SUBU 6'b100011          //subu指令功能码
`define EXE_ADDI 6'b001000          //addi指令码
`define EXE_ADDIU 6'b001001         //addiu指令码
`define EXE_CLZ 6'b100000           //clz指令功能码
`define EXE_CLO 6'b100001           //clo指令功能码

`define EXE_MULT 6'b011000          //mult指令功能码
`define EXE_MULTU 6'b011001         //multu指令功能码
`define EXE_MUL 6'b000010           //mul指令功能码

`define EXE_MADD 6'b000000          //madd指令功能码
`define EXE_MADDU 6'b000001         //maddu指令功能码
`define EXE_MSUB 6'b000100          //msub指令功能码
`define EXE_MSUBU 6'b000101         //msubu指令功能码

`define EXE_DIV 6'b011010           //div指令功能码
`define EXE_DIVU 6'b011011          //divu指令功能码

//分支跳转指令
`define EXE_J 6'b000010             //j指令码
`define EXE_JAL 6'b000011           //jal指令码
`define EXE_JALR 6'b001001          //jalr功能码
`define EXE_JR 6'b001000            //jr功能码
`define EXE_BEQ 6'b000100           //beq指令码
`define EXE_BGEZ 5'b00001           //bgez功能码2
`define EXE_BGEZAL 5'b10001         //bgezal功能码2
`define EXE_BGTZ 6'b000111          //bgtz指令码
`define EXE_BLEZ 6'b000110          //blez指令码
`define EXE_BLTZ 5'b00000           //bltz功能码2
`define EXE_BLTZAL 5'b10000         //bltzal功能码2
`define EXE_BNE 6'b000101           //bne指令码

//加载存储指令
`define EXE_LB 6'b100000            //lb指令码
`define EXE_LBU 6'b100100           //lbu指令码
`define EXE_LH 6'b100001            //lh指令码
`define EXE_LHU 6'b100101           //Lhu指令码
`define EXE_LW 6'b100011            //lw指令码
`define EXE_LWL 6'b100010           //lwl指令码
`define EXE_LWR 6'b100110           //lwr指令码
`define EXE_SB 6'b101000            //sb指令码
`define EXE_SH 6'b101001            //sh指令码
`define EXE_SW 6'b101011            //sw指令码
`define EXE_SWL 6'b101010           //swl指令码
`define EXE_SWR 6'b101110           //swr指令码
`define EXE_LL 6'b110000            //ll指令码
`define EXE_SC 6'b111000            //sc指令码

//异常相关指令
//不包含立即数的自陷指令(指令码为SPECIAL类，根据功能码区分)
`define EXE_TEQ 6'b110100
`define EXE_TGE 6'b110000
`define EXE_TGEU 6'b110001
`define EXE_TLT 6'b110010
`define EXE_TLTU 6'b110011
`define EXE_TNE 6'b110110
//含立即数的自陷指令(指令码为REGIMM类，根据20～16bit区分)
`define EXE_TEQI 5'b01100
`define EXE_TGEI 5'b01000
`define EXE_TGEIU 5'b01001
`define EXE_TLTI 5'b01010
`define EXE_TLTIU 5'b01011
`define EXE_TNEI 5'b01110

`define EXE_SYSCALL 6'b001100
`define EXE_ERET 32'b010000_1_0000_0000_0000_0000_000_011000

//空指令
`define EXE_NOP 6'b000000           //空指令功能码
`define SSNOP 32'h0000_0040         //SSNOP指令

//其他特殊指令
`define EXE_SYNC 6'b001111          //sync指令功能码
`define EXE_PREF 6'b110011          //pref指令码

`define EXE_SPECIAL_INST 6'b000000  //SPECIAL类指令的指令码
`define EXE_SPECIAL2_INST 6'b011100 //SPECIAL2类指令的指令码
`define EXE_REGIMM_INST 6'b000001   //REGIMM类转移指令

//*********************AluOp：指令要执行的运算子类型（ID输出到EX）*****************
//逻辑操作指令
`define EXE_AND_OP 8'b0010_0100
`define EXE_OR_OP 8'b0010_0101
`define EXE_XOR_OP 8'b0010_0110
`define EXE_NOR_OP 8'b0010_0111
`define EXE_ANDI_OP 8'b0101_1001
`define EXE_ORI_OP 8'b0101_1010
`define EXE_XORI_OP 8'b0101_1011
`define EXE_LUI_OP 8'b0101_1100

//移位操作指令
`define EXE_SLL_OP 8'b0111_1100
`define EXE_SLLV_OP 8'b0000_0100
`define EXE_SRL_OP 8'b0000_0010
`define EXE_SRLV_OP 8'b0000_0110
`define EXE_SRA_OP 8'b0000_0011
`define EXE_SRAV_OP 8'b0000_0111

//移动操作指令
`define EXE_MOVZ_OP 8'b0000_1010
`define EXE_MOVN_OP 8'b0000_1011
`define EXE_MFHI_OP 8'b0001_0000
`define EXE_MTHI_OP 8'b0001_0001
`define EXE_MFLO_OP 8'b0001_0010
`define EXE_MTLO_OP 8'b0001_0011

//算术操作指令
`define EXE_SLT_OP 8'b0010_1010
`define EXE_SLTU_OP 8'b0010_1011
`define EXE_SLTI_OP 8'b0101_0111
`define EXE_SLTIU_OP 8'b0101_1000
`define EXE_ADD_OP 8'b0010_0000
`define EXE_ADDU_OP 8'b0010_0001
`define EXE_SUB_OP 8'b0010_0010
`define EXE_SUBU_OP 8'b0010_0011
`define EXE_ADDI_OP 8'b0101_0101
`define EXE_ADDIU_OP 8'b0101_0110
`define EXE_CLZ_OP 8'b1011_0000
`define EXE_CLO_OP 8'b1011_0001

`define EXE_MULT_OP 8'b0001_1000
`define EXE_MULTU_OP 8'b0001_1001
`define EXE_MUL_OP 8'b1010_1001

`define EXE_MADD_OP 8'b1010_0110
`define EXE_MADDU_OP 8'b1010_1000
`define EXE_MSUB_OP 8'b1010_1010
`define EXE_MSUBU_OP 8'b1010_1011

`define EXE_DIV_OP 8'b0001_1010
`define EXE_DIVU_OP 8'b0001_1011

//分支跳转指令
`define EXE_J_OP 8'b0100_1111
`define EXE_JAL_OP 8'b0101_0000
`define EXE_JALR_OP 8'b0000_1001
`define EXE_JR_OP 8'b0000_1000
`define EXE_BEQ_OP 8'b0101_0001
`define EXE_BGEZ_OP 8'b0100_0001
`define EXE_BGEZAL_OP 8'b0100_1011
`define EXE_BGTZ_OP 8'b0101_0100
`define EXE_BLEZ_OP 8'b0101_0011
`define EXE_BLTZ_OP 8'b0100_0000
`define EXE_BLTZAL_OP 8'b0100_1010
`define EXE_BNE_OP 8'b0101_0010

//加载存储指令
`define EXE_LB_OP 8'b1110_0000
`define EXE_LBU_OP 8'b1110_0100
`define EXE_LH_OP 8'b1110_0001
`define EXE_LHU_OP 8'b1110_0101
`define EXE_LW_OP 8'b1110_0011
`define EXE_LWL_OP 8'b1110_0010
`define EXE_LWR_OP 8'b1110_0110
`define EXE_SB_OP 8'b1110_1000
`define EXE_SH_OP 8'b1110_1001
`define EXE_SW_OP 8'b1110_1011
`define EXE_SWL_OP 8'b1110_1010
`define EXE_SWR_OP 8'b1110_1110
`define EXE_LL_OP 8'b1111_0000
`define EXE_SC_OP 8'b1111_1000

//协处理器访问指令
`define EXE_MFC0_OP 8'b0101_1101
`define EXE_MTC0_OP 8'b0110_0000

//异常相关指令
`define EXE_TEQ_OP 8'b0011_0100
`define EXE_TGE_OP 8'b0011_0000
`define EXE_TGEU_OP 8'b0011_0001
`define EXE_TLT_OP 8'b0011_0010
`define EXE_TLTU_OP 8'b0011_0011
`define EXE_TNE_OP 8'b0011_0110

`define EXE_TEQI_OP 8'b0100_1000
`define EXE_TGEI_OP 8'b0100_0100
`define EXE_TGEIU_OP 8'b0100_0101
`define EXE_TLTI_OP 8'b0100_0110
`define EXE_TLTIU_OP 8'b0100_0111
`define EXE_TNEI_OP 8'b0100_1001

`define EXE_SYSCALL_OP 8'b0000_1100
`define EXE_ERET_OP 8'b0110_1011

//其他特殊指令
`define EXE_NOP_OP 8'b0000_0000

`define EXE_PREF_OP 8'b1111_0011
`define EXE_SYNC_OP 8'b0000_1111


//*****************AluSel：指令要执行的运算类型（ID输出到EX）**********************
`define EXE_RES_LOGIC 3'b001
`define EXE_RES_SHIFT 3'b010
`define EXE_RES_MOVE 3'b011
`define EXE_RES_ARITHMETIC 3'b100
`define EXE_RES_MUL 3'b101
`define EXE_RES_JUMP_BRANCH 3'b110
`define EXE_RES_LOAD_STORE 3'b111

`define EXE_RES_NOP 3'b000              //指令执行后没有需要写入通用寄存器的结果


//*************************  与指令存储器ROM有关的宏定义  ************************
`define InstAddrBus 31:0            //ROM的地址总线宽度
`define InstBus 31:0                //ROM的数据总线宽度
`define InstMemNum 32768            //ROM的实际大小为128KB(32*1024条32位(4字节)指令)
`define InstRealAddrBus 17          //ROM实际使用的地址线宽度


//********************  与通用寄存器堆Regfile有关的宏定义  ***********************
`define RegAddrBus 4:0              //Regfile模块的地址线宽度
`define RegBus 31:0                 //Regfile模块的数据线宽度
`define RegWidth 32                 //通用寄存器的宽度
`define DoubleRegWidth 64           //两倍的通用寄存器的宽度
`define DoubleRegBus 63:0           //两倍的通用寄存器的数据线宽度
`define RegNum 32                   //通用寄存器的数量
`define RegNumLog2 5                //寻址通用寄存器使用的地址位数
`define NOPRegAddr 5'b00000         //$0寄存器地址


//*******************  与流水线暂停机制模块ctrl有关的宏定义  **********************
`define Stop 1'b1                   //流水线暂停
`define NoStop 1'b0                 //流水线继续


//************************   与除法模块相关的宏定义    ***************************
`define DivFree 2'b00
`define DivByZero 2'b01
`define DivOn 2'b10
`define DivEnd 2'b11
`define DivResultReady 1'b1
`define DivResultNotReady 1'b0
`define DivStart 1'b1
`define DivStop 1'b0


//**************************    转移指令相关宏定义   *****************************
`define Branch 1'b1                 //转移
`define NotBranch 1'b0              //不转移
`define InDelaySlot 1'b1            //在延迟槽中
`define NotInDelaySlot 1'b0         //不在延迟槽中


//***********************    数据存储器RAM相关宏定义    **************************
`define DataAddrBus 31:0            //地址总线宽度
`define DataBus 31:0                //数据总线宽度
`define DataMemNum 131072           //RAM大小，单位是字，此处是128K word(4字节)
`define DataMemNumLog2 19           //实际使用的地址宽度
`define ByteWidth 7:0               //字节宽度


//******************************    异常相关    *********************************
`define InstValid 1'b0              //指令有效，无效指令异常instvalid标记为0
`define InstInvalid 1'b1            //指令无效，无效指令异常instvalid标记为1
`define InterruptAssert 1'b1
`define InterruptNotAssert 1'b0
`define TrapAssert 1'b1
`define TrapNotAssert 1'b0


//**********************    定义CP0中各个寄存器的地址    *************************
`define CP0_REG_COUNT 5'b01001      //标号9
`define CP0_REG_COMPARE 5'b01011    //标号11
`define CP0_REG_STATUS 5'b01100     //标号12
`define CP0_REG_CAUSE 5'b01101      //标号13
`define CP0_REG_EPC 5'b01110        //标号14
`define CP0_REG_PRId 5'b01111       //标号15
`define CP0_REG_CONFIG 5'b10000     //标号16


//****************************Wishbone总线接口相关*******************************
`define WB_IDLE 2'b00               //空闲状态
`define WB_BUSY 2'b01               //总线忙状态
`define WB_WAIT_FOR_FLUSHING 2'b10
`define WB_WAIT_FOR_STALL 2'b11     //等待暂停结束状态
