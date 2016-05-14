`timescale 1ns / 1ps
//********************************************************************
//  顶层模块(CPU):对流水线各个阶段的模块进行例化、连接，主要声明连线
//  Vivado中设置为top模块不用包含其他模块，否则出现多重定义错误
//********************************************************************

`include "defines.v"

module openmips(
    input wire clk,
    input wire rst,

    //与指令存储器ROM的连接
    input  wire[`InstBus] rom_data_i,        //从指令存储器取得的指令
    output wire[`InstAddrBus] rom_addr_o,    //输出到指令存储器的地址
    output wire rom_ce_o,                    //指令存储器使能信号

    //与数据存储器RAM连接接口
    input wire[`RegBus] ram_data_i,
    output wire[`RegBus] ram_addr_o,
    output wire[`RegBus] ram_data_o,
    output wire ram_we_o,
    output wire[3:0] ram_sel_o,
    output wire ram_ce_o,

    //外部中断和时钟中断
    input wire[5:0] int_i,
    output wire timer_int_o,

    //寄存器数据的数码管展示模块连接
    input wire[`RegAddrBus] display_reg_raddr,
    output wire[`RegBus] reg_display_rdata
    );

    //连接PC与IF/ID模块的变量
    wire[`InstAddrBus] pc;

    //连接IF/ID模块与ID模块的变量
    wire[`InstAddrBus] id_pc_i;
    wire[`InstBus] id_inst_i;

    //连接ID模块与ID/EX模块的变量
    wire[`AluOpBus] id_aluop_o;
    wire[`AluSelBus] id_alusel_o;
    wire[`RegBus] id_reg1_o;
    wire[`RegBus] id_reg2_o;
    wire id_wreg_o;
    wire[`RegAddrBus] id_wd_o;
    wire id_is_in_delayslot_o;
    wire[`RegBus] id_link_address_o;
    wire[`RegBus] id_inst_o;

    //连接ID/EX模块与EX模块的变量
    wire[`AluOpBus] ex_aluop_i;
    wire[`AluSelBus] ex_alusel_i;
    wire[`RegBus] ex_reg1_i;
    wire[`RegBus] ex_reg2_i;
    wire ex_wreg_i;
    wire[`RegAddrBus] ex_wd_i;
    wire ex_is_in_delayslot_i;
    wire[`RegBus] ex_link_address_i;
    wire[`RegBus] ex_inst_i;

    //连接EX模块与EX/MEM模块的变量
    wire ex_wreg_o;
    wire[`RegAddrBus] ex_wd_o;
    wire[`RegBus] ex_wdata_o;
    wire[`RegBus] ex_hi_o;
    wire[`RegBus] ex_lo_o;
    wire ex_whilo_o;
    wire[`RegBus] ex_mem_addr_o;
    wire[`RegBus] ex_reg1_o;
    wire[`RegBus] ex_reg2_o;
    //解决load相关：EX模块回传给ID模块的指令码
    wire[`AluOpBus] ex_aluop_o;
    //协处理器访问指令相关
    wire ex_cp0_reg_we_o;
    wire[4:0] ex_cp0_reg_write_addr_o;
    wire[`RegBus] ex_cp0_reg_data_o;

    //连接EX/MEM模块与MEM模块的变量
    wire mem_wreg_i;
    wire[`RegAddrBus] mem_wd_i;
    wire[`RegBus] mem_wdata_i;
    wire[`RegBus] mem_hi_i;
    wire[`RegBus] mem_lo_i;
    wire mem_whilo_i;
    wire[`AluOpBus] mem_aluop_i;
    wire[`RegBus] mem_mem_addr_i;
    wire[`RegBus] mem_reg1_i;
    wire[`RegBus] mem_reg2_i;
    wire mem_cp0_reg_we_i;
    wire[4:0] mem_cp0_reg_write_addr_i;
    wire[`RegBus] mem_cp0_reg_data_i;

    //连接MEM模块与MEM/WB模块的变量
    wire mem_wreg_o;
    wire[`RegAddrBus] mem_wd_o;
    wire[`RegBus] mem_wdata_o;
    wire[`RegBus] mem_hi_o;
    wire[`RegBus] mem_lo_o;
    wire mem_whilo_o;
    wire mem_LLbit_we_o;
    wire mem_LLbit_value_o;
    wire mem_cp0_reg_we_o;
    wire[4:0] mem_cp0_reg_write_addr_o;
    wire[`RegBus] mem_cp0_reg_data_o;

    //连接MEM/WB模块与回写阶段输入(各类寄存器)的变量
    wire wb_wreg_i;
    wire[`RegAddrBus] wb_wd_i;
    wire[`RegBus] wb_wdata_i;
    wire[`RegBus] wb_hi_i;
    wire[`RegBus] wb_lo_i;
    wire wb_whilo_i;
    wire wb_LLbit_we_i;
    wire wb_LLbit_value_i;
    wire wb_cp0_reg_we_i;
    wire[4:0] wb_cp0_reg_write_addr_i;
    wire[`RegBus] wb_cp0_reg_data_i;

    //连接ID模块与通用寄存器regfile模块的变量
    wire reg1_read;
    wire reg2_read;
    wire[`RegBus] reg1_data;
    wire[`RegBus] reg2_data;
    wire[`RegAddrBus] reg1_addr;
    wire[`RegAddrBus] reg2_addr;

    //连接EX模块和hilo模块输出
    wire[`RegBus] hi;
    wire[`RegBus] lo;

    //用于连接EX和EX_MEM模块之间实现乘累加、累减指令的信号
    wire[`DoubleRegBus] hilo_temp_o;
    wire[1:0] cnt_o;
    wire[`DoubleRegBus] hilo_temp_i;
    wire[1:0] cnt_i;

    //连接EX模块和DIV模块的信号
    wire[`DoubleRegBus] div_result;
    wire div_ready;
    wire[`RegBus] div_opdata1;
    wire[`RegBus] div_opdata2;
    wire div_start;
    wire div_annul;
    wire signed_div;

    //转移指令及延迟槽相关信号(PC和ID、ID/EX之间)
    wire is_in_delayslot_i;
    wire is_in_delayslot_o;
    wire next_inst_in_delayslot_o;
    wire id_branch_flag_o;
    wire[`RegBus] branch_target_address;

    //连接ctrl和其他各个模块
    wire[5:0] stall;
    wire stallreq_from_id;
    wire stallreq_from_ex;

    //LLbit寄存器模块输出
    wire LLbit_o;

    //CP0与EX模块连接
    wire[4:0] cp0_raddr_i;
    wire[`RegBus] cp0_data_o;

    //PC_reg例化
    pc_reg pc_reg0(
        .clk(clk),
        .rst(rst),
        .stall(stall),
        .pc(pc),
        .ce(rom_ce_o),
        .branch_flag_i(id_branch_flag_o),
        .branch_target_address_i(branch_target_address)
        );

    assign rom_addr_o = pc;         //指令存储器的输入地址就是PC的值

    //IF/ID模块例化
    if_id if_id0(
        .clk(clk),
        .rst(rst),
        .stall(stall),
        .if_pc(pc),
        .if_inst(rom_data_i),
        .id_pc(id_pc_i),
        .id_inst(id_inst_i)
        );

    //ID模块例化
    id id0(
        .rst(rst),
        .pc_i(id_pc_i),
        .inst_i(id_inst_i),

        //解决load相关从EX模块回传的指令码
        .ex_aluop_i(ex_aluop_o),

        //来自regfile模块的输入
        .reg1_data_i(reg1_data),
        .reg2_data_i(reg2_data),

        //送到regfile模块的信息
        .reg1_read_o(reg1_read),
        .reg2_read_o(reg2_read),
        .reg1_addr_o(reg1_addr),
        .reg2_addr_o(reg2_addr),

        //送到ID/EX模块的信息
        .aluop_o(id_aluop_o),
        .alusel_o(id_alusel_o),
        .reg1_o(id_reg1_o),
        .reg2_o(id_reg2_o),
        .wd_o(id_wd_o),
        .wreg_o(id_wreg_o),
        .inst_o(id_inst_o),

        //EX阶段指令结果的数据通路信息
        .ex_wreg_i(ex_wreg_o),
        .ex_wd_i(ex_wd_o),
        .ex_wdata_i(ex_wdata_o),

        //MEM阶段指令结果的数据通路信息
        .mem_wreg_i(mem_wreg_o),
        .mem_wd_i(mem_wd_o),
        .mem_wdata_i(mem_wdata_o),

        //输出到ctrl的暂停流水线请求
        .stallreq(stallreq_from_id),

        //转移指令相关
        .is_in_delayslot_i(is_in_delayslot_i),
        .is_in_delayslot_o(id_is_in_delayslot_o),
        .next_inst_in_delayslot_o(next_inst_in_delayslot_o),
        .branch_flag_o(id_branch_flag_o),
        .branch_target_address_o(branch_target_address),
        .link_addr_o(id_link_address_o)
        );

    //通用寄存器regfile模块例化
    regfile regfile1(
        .clk(clk),
        .rst(rst),

        //通用寄存器写回端输入
        .we(wb_wreg_i),
        .waddr(wb_wd_i),
        .wdata(wb_wdata_i),

        //ID端取操作数输入
        .re1(reg1_read),
        .raddr1(reg1_addr),
        .rdata1(reg1_data),
        .re2(reg2_read),
        .raddr2(reg2_addr),
        .rdata2(reg2_data),

        //与数码管展示模块相连
        .raddr3(display_reg_raddr),
        .rdata3(reg_display_rdata)
        );

    //ID/EX模块例化
    id_ex id_ex0(
        .clk(clk),
        .rst(rst),

        .stall(stall),

        //从ID模块传递过来的信息
        .id_aluop(id_aluop_o),
        .id_alusel(id_alusel_o),
        .id_reg1(id_reg1_o),
        .id_reg2(id_reg2_o),
        .id_wd(id_wd_o),
        .id_wreg(id_wreg_o),
        .id_link_address(id_link_address_o),
        .id_is_in_delayslot(id_is_in_delayslot_o),
        .next_inst_in_delayslot_i(next_inst_in_delayslot_o),
        .id_inst(id_inst_o),

        //传递到EX模块的信息
        .ex_aluop(ex_aluop_i),
        .ex_alusel(ex_alusel_i),
        .ex_reg1(ex_reg1_i),
        .ex_reg2(ex_reg2_i),
        .ex_wd(ex_wd_i),
        .ex_wreg(ex_wreg_i),
        .ex_link_address(ex_link_address_i),
        .ex_is_in_delayslot(ex_is_in_delayslot_i),
        .is_in_delayslot_o(is_in_delayslot_i),
        .ex_inst(ex_inst_i)
        );

    //EX模块例化
    ex ex0(
        .rst(rst),

        //从ID/EX模块传递过来的信息
        .aluop_i(ex_aluop_i),
        .alusel_i(ex_alusel_i),
        .reg1_i(ex_reg1_i),
        .reg2_i(ex_reg2_i),
        .wd_i(ex_wd_i),
        .wreg_i(ex_wreg_i),

        //从hilo_reg传递过来的信息
        .hi_i(hi),
        .lo_i(lo),

        //MEM模块传回的HILO数据通路信息
        .mem_hi_i(mem_hi_o),
        .mem_lo_i(mem_lo_o),
        .mem_whilo_i(mem_whilo_o),

        //WB模块传回的HILO数据通路信息
        .wb_hi_i(wb_hi_i),
        .wb_lo_i(wb_lo_i),
        .wb_whilo_i(wb_whilo_i),

        //输出到EX/MEM模块的信息
        .wd_o(ex_wd_o),
        .wreg_o(ex_wreg_o),
        .wdata_o(ex_wdata_o),
        .hi_o(ex_hi_o),
        .lo_o(ex_lo_o),
        .whilo_o(ex_whilo_o),

        //输出到ctrl的暂停流水线信号
        .stallreq(stallreq_from_ex),

        //与EX_MEM模块连接用于乘累加、累减指令的信号
        .hilo_temp_i(hilo_temp_i),
        .cnt_i(cnt_i),
        .hilo_temp_o(hilo_temp_o),
        .cnt_o(cnt_o),

        //与DIV模块连接
        .div_opdata1_o(div_opdata1),
        .div_opdata2_o(div_opdata2),
        .signed_div_o(signed_div),
        .div_start_o(div_start),
        .div_ready_i(div_ready),
        .div_result_i(div_result),

        //转移指令相关
        .link_address_i(ex_link_address_i),
        .is_in_delayslot_i(ex_is_in_delayslot_i),

        //加载存储指令相关
        .inst_i(ex_inst_i),
        .aluop_o(ex_aluop_o),
        .mem_addr_o(ex_mem_addr_o),
        .reg2_o(ex_reg2_o),

        //协处理器访问指令相关
        .mem_cp0_reg_we(mem_cp0_reg_we_o),
        .mem_cp0_reg_write_addr(mem_cp0_reg_write_addr_o),
        .mem_cp0_reg_data(mem_cp0_reg_data_o),

        .wb_cp0_reg_we(wb_cp0_reg_we_i),
        .wb_cp0_reg_write_addr(wb_cp0_reg_write_addr_i),
        .wb_cp0_reg_data(wb_cp0_reg_data_i),

        .cp0_reg_we_o(ex_cp0_reg_we_o),
        .cp0_reg_write_addr_o(ex_cp0_reg_write_addr_o),
        .cp0_reg_data_o(ex_cp0_reg_data_o),

        .cp0_reg_read_addr_o(cp0_raddr_i),
        .cp0_reg_data_i(cp0_data_o)
        );

    //EX/MEM模块例化
    ex_mem ex_mem0(
        .clk(clk),
        .rst(rst),

        .stall(stall),

        //来自EX模块的信息
        .ex_wd(ex_wd_o),
        .ex_wreg(ex_wreg_o),
        .ex_wdata(ex_wdata_o),
        .ex_hi(ex_hi_o),
        .ex_lo(ex_lo_o),
        .ex_whilo(ex_whilo_o),

        //送到MEM模块的信息
        .mem_wd(mem_wd_i),
        .mem_wreg(mem_wreg_i),
        .mem_wdata(mem_wdata_i),
        .mem_hi(mem_hi_i),
        .mem_lo(mem_lo_i),
        .mem_whilo(mem_whilo_i),

        //与EX模块连接用于乘累加、累减指令的信号
        .hilo_i(hilo_temp_o),
        .cnt_i(cnt_o),
        .hilo_o(hilo_temp_i),
        .cnt_o(cnt_i),

        //加载存储指令信息传递
        .ex_aluop(ex_aluop_o),
        .ex_mem_addr(ex_mem_addr_o),
        .ex_reg2(ex_reg2_o),
        .mem_aluop(mem_aluop_i),
        .mem_mem_addr(mem_mem_addr_i),
        .mem_reg2(mem_reg2_i),

        //协处理器访问指令相关
        .ex_cp0_reg_we(ex_cp0_reg_we_o),
        .ex_cp0_reg_write_addr(ex_cp0_reg_write_addr_o),
        .ex_cp0_reg_data(ex_cp0_reg_data_o),
        .mem_cp0_reg_we(mem_cp0_reg_we_i),
        .mem_cp0_reg_write_addr(mem_cp0_reg_write_addr_i),
        .mem_cp0_reg_data(mem_cp0_reg_data_i)
        );

    //MEM模块例化
    mem mem0(
        .rst(rst),

        //来自EX/MEM模块的信息
        .wd_i(mem_wd_i),
        .wreg_i(mem_wreg_i),
        .wdata_i(mem_wdata_i),
        .hi_i(mem_hi_i),
        .lo_i(mem_lo_i),
        .whilo_i(mem_whilo_i),

        .aluop_i(mem_aluop_i),
        .mem_addr_i(mem_mem_addr_i),
        .reg2_i(mem_reg2_i),

        //送到MEM/WB模块的信息
        .wd_o(mem_wd_o),
        .wreg_o(mem_wreg_o),
        .wdata_o(mem_wdata_o),
        .hi_o(mem_hi_o),
        .lo_o(mem_lo_o),
        .whilo_o(mem_whilo_o),

        //来自memory的信息
        .mem_data_i(ram_data_i),
        //送到memory的信息
        .mem_addr_o(ram_addr_o),
        .mem_we_o(ram_we_o),
        .mem_sel_o(ram_sel_o),
        .mem_data_o(ram_data_o),

        //LLbit寄存器相关信息
        .LLbit_i(LLbit_o),
        .wb_LLbit_we_i(wb_LLbit_we_i),
        .wb_LLbit_value_i(wb_LLbit_value_i),
        .LLbit_we_o(mem_LLbit_we_o),
        .LLbit_value_o(mem_LLbit_value_o),

        //协处理器访问指令相关
        .cp0_reg_we_i(mem_cp0_reg_we_i),
        .cp0_reg_write_addr_i(mem_cp0_reg_write_addr_i),
        .cp0_reg_data_i(mem_cp0_reg_data_i),
        .cp0_reg_we_o(mem_cp0_reg_we_o),
        .cp0_reg_write_addr_o(mem_cp0_reg_write_addr_o),
        .cp0_reg_data_o(mem_cp0_reg_data_o)
        );

    //MEM/WB模块例化
    mem_wb mem_wb0(
        .clk(clk),
        .rst(rst),

        .stall(stall),

        //来自MEM模块的信息
        .mem_wd(mem_wd_o),
        .mem_wreg(mem_wreg_o),
        .mem_wdata(mem_wdata_o),
        .mem_hi(mem_hi_o),
        .mem_lo(mem_lo_o),
        .mem_whilo(mem_whilo_o),

        //送到回写阶段(regfile)的信息
        .wb_wd(wb_wd_i),
        .wb_wreg(wb_wreg_i),
        .wb_wdata(wb_wdata_i),
        .wb_hi(wb_hi_i),
        .wb_lo(wb_lo_i),
        .wb_whilo(wb_whilo_i),

        //LLbit寄存器相关信息
        .mem_LLbit_we(mem_LLbit_we_o),
        .mem_LLbit_value(mem_LLbit_value_o),
        .wb_LLbit_we(wb_LLbit_we_i),
        .wb_LLbit_value(wb_LLbit_value_i),

        //协处理器访问指令相关
        .mem_cp0_reg_we(mem_cp0_reg_we_o),
        .mem_cp0_reg_write_addr(mem_cp0_reg_write_addr_o),
        .mem_cp0_reg_data(mem_cp0_reg_data_o),
        .wb_cp0_reg_we(wb_cp0_reg_we_i),
        .wb_cp0_reg_write_addr(wb_cp0_reg_write_addr_i),
        .wb_cp0_reg_data(wb_cp0_reg_data_i)
        );

    //例化特殊寄存器HI/LO
    hilo_reg hilo_reg0(
        .clk(clk),
        .rst(rst),

        //写端口
        .we(wb_whilo_i),
        .hi_i(wb_hi_i),
        .lo_i(wb_lo_i),

        //读端口
        .hi_o(hi),
        .lo_o(lo)
        );

    //例化流水线暂停控制模块ctrl
    ctrl ctrl0(
        .rst(rst),
        .stallreq_from_id(stallreq_from_id),
        .stallreq_from_ex(stallreq_from_ex),
        .stall(stall)
        );

    //例化除法模块div
    div div0(
        .clk(clk),
        .rst(rst),

        .signed_div_i(signed_div),
        .opdata1_i(div_opdata1),
        .opdata2_i(div_opdata2),
        .start_i(div_start),
        //暂时固定为0，异常处理时修改
        .annul_i(1'b0),

        .ready_o(div_ready),
        .result_o(div_result)
        );

    //例化LLbit寄存器模块
    LLbit_reg LLbit_reg0(
        .rst(rst),
        .clk(clk),
        .flush(1'b0),
        .we(wb_LLbit_we_i),
        .LLbit_i(wb_LLbit_value_i),
        .LLbit_o(LLbit_o)
        );

    //例化CP0模块
    cp0_reg cp0_reg0(
        .rst(rst),
        .clk(clk),

        .we_i(wb_cp0_reg_we_i),
        .waddr_i(wb_cp0_reg_write_addr_i),
        .data_i(wb_cp0_reg_data_i),

        .raddr_i(cp0_raddr_i),
        .data_o(cp0_data_o),

        .int_i(int_i)
        );

endmodule
