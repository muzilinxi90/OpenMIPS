//*******************************************************
//                  项目的全部宏定义
//  将此文件Set Global Include后，其他文件不用再包含
//*******************************************************

//*************   全局的宏定义   ****************
`define RstEnable 1'b1              //复位信号有效
`define RstDisable 1'b0             //复位信号无效
`define ZeroWord 32'h0000_0000      //32位的数值0
`define WriteEnable 1'b1            //使能写
`define WriteDisable 1'b0           //禁止写
`define ReadEnable 1'b1             //使能读
`define ReadDisable 1'b0            //禁止读
`define AluOpBus 7:0                //译码阶段的输出aluop_o的宽度
`define AluSelBus 2:0               //译码阶段的输出alusel_o的宽度
`define InstValid 1'b0              //指令有效
`define InstInvalid 1'b1            //指令无效
`define True_v  1'b1                //逻辑“真”
`define False_v 1'b0                //逻辑“假”
`define ChipEnable  1'b1            //芯片使能
`define ChipDisable 1'b0            //芯片禁止


//************  与具体指令有关的宏定义  *************
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

//空指令
`define EXE_NOP 6'b000000           //空指令功能码
`define SSNOP 32'h0000_0040         //SSNOP指令

//其他特殊指令
`define EXE_SYNC 6'b001111          //sync指令功能码
`define EXE_PREF 6'b110011          //pref指令码
`define EXE_SPECIAL_INST 6'b000000  //SPECIAL类指令的指令码


//*********AluOp：指令要执行的运算子类型（ID输出到EX）***********
`define EXE_AND_OP 8'b0010_0100
`define EXE_OR_OP 8'b0010_0101
`define EXE_XOR_OP 8'b0010_0110
`define EXE_NOR_OP 8'b0010_0111
`define EXE_ANDI_OP 8'b0101_1001
`define EXE_ORI_OP 8'b0101_1010
`define EXE_XORI_OP 8'b0101_1011
`define EXE_LUI_OP 8'b0101_1100

`define EXE_SLL_OP 8'b0111_1100
`define EXE_SLLV_OP 8'b0000_0100
`define EXE_SRL_OP 8'b0000_0010
`define EXE_SRLV_OP 8'b0000_0110
`define EXE_SRA_OP 8'b0000_0011
`define EXE_SRAV_OP 8'b0000_0111

`define EXE_MOVZ_OP 8'b0000_1010
`define EXE_MOVN_OP 8'b0000_1011
`define EXE_MFHI_OP 8'b0001_0000
`define EXE_MTHI_OP 8'b0001_0001
`define EXE_MFLO_OP 8'b0001_0010
`define EXE_MTLO_OP 8'b0001_0011

`define EXE_NOP_OP 8'b0000_0000


//*********AluSel：指令要执行的运算类型（ID输出到EX）************
`define EXE_RES_LOGIC 3'b001
`define EXE_RES_SHIFT 3'b010
`define EXE_RES_MOVE 3'b011 

`define EXE_RES_NOP 3'b000


//************  与指令存储器ROM有关的宏定义  ***********
`define InstAddrBus 31:0            //ROM的地址总线宽度
`define InstBus 31:0                //ROM的数据总线宽度
`define InstMemNum 4096             //ROM的实际大小为128KB(4*1024条32位指令)
`define InstRealAddrbus 19          //ROM实际使用的地址线宽度


//***********  与通用寄存器堆Regfile有关的宏定义  *************
`define RegAddrBus 4:0              //Regfile模块的地址线宽度
`define RegBus 31:0                 //Regfile模块的数据线宽度
`define RegWidth 32                 //通用寄存器的宽度
`define DoubleRegWidth 64           //两倍的通用寄存器的宽度
`define DoubleRegBus 63:0           //两倍的通用寄存器的数据线宽度
`define RegNum 32                   //通用寄存器的数量
`define RegNumLog2 5                //寻址通用寄存器使用的地址位数
`define NOPRegAddr 5'b00000         //$0寄存器地址

//***************** 与4位数码管相关宏定义 **********************
`define DispDataBus 6:0             //4位数码管数据总线宽度
`define DispAnBus 3:0               //4位数码管选通信号宽度
