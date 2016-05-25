`timescale 1ns / 1ps
//******************************************************************************
//      顶层模块(CPU):对流水线各个阶段的模块进行例化、连接，主要声明连线
//******************************************************************************

`include "defines.v"

module openmips(
    input wire rst,
    input wire clk,

    //指令Wishbone总线
    output wire[`RegBus] iwishbone_addr_o,
    input wire[`RegBus] iwishbone_data_i,
    output wire[`RegBus] iwishbone_data_o,
    output wire iwishbone_we_o,
    output wire[3:0] iwishbone_sel_o,
    output wire iwishbone_cyc_o,
    output wire iwishbone_stb_o,
    input wire iwishbone_ack_i,

    //数据Wishbone总线
    output wire[`RegBus] dwishbone_addr_o,
    input wire[`RegBus] dwishbone_data_i,
    output wire[`RegBus] dwishbone_data_o,
    output wire dwishbone_we_o,
    output wire[3:0] dwishbone_sel_o,
    output wire dwishbone_cyc_o,
    output wire dwishbone_stb_o,
    input wire dwishbone_ack_i,

    //外部中断和时钟中断
    input wire[5:0] int_i,
    output wire timer_int_o
    );

    //连接PC模块、指令Wishbone总线接口模块、IF/ID模块
    wire[`InstAddrBus] pc;
    wire[`InstBus] inst_i;                  //以IF/ID模块为主体的命名
    wire rom_ce;

    //连接IF/ID模块与ID模块
    wire[`InstAddrBus] id_pc_i;             //以ID模块为主体的命名
    wire[`InstBus] id_inst_i;

    //连接ID模块与ID/EX模块
    wire[`AluOpBus] id_aluop_o;
    wire[`AluSelBus] id_alusel_o;
    wire[`RegBus] id_reg1_o;
    wire[`RegBus] id_reg2_o;
    wire id_wreg_o;
    wire[`RegAddrBus] id_wd_o;
    wire id_is_in_delayslot_o;
    wire[`RegBus] id_link_address_o;
    wire[`RegBus] id_inst_o;
    wire[31:0] id_excepttype_o;
    wire[`RegBus] id_current_inst_address_o;

    //连接ID/EX模块与EX模块
    wire[`AluOpBus] ex_aluop_i;             //以EX模块为主体的命名
    wire[`AluSelBus] ex_alusel_i;
    wire[`RegBus] ex_reg1_i;
    wire[`RegBus] ex_reg2_i;
    wire ex_wreg_i;
    wire[`RegAddrBus] ex_wd_i;
    wire ex_is_in_delayslot_i;
    wire[`RegBus] ex_link_address_i;
    wire[`RegBus] ex_inst_i;
    wire[31:0] ex_excepttype_i;
    wire[`RegBus] ex_current_inst_address_i;

    //连接EX模块与EX/MEM模块
    wire ex_wreg_o;
    wire[`RegAddrBus] ex_wd_o;
    wire[`RegBus] ex_wdata_o;
    wire[`RegBus] ex_hi_o;
    wire[`RegBus] ex_lo_o;
    wire ex_whilo_o;
    wire[`AluOpBus] ex_aluop_o;
    wire[`RegBus] ex_mem_addr_o;
    wire[`RegBus] ex_reg2_o;
    //协处理器访问指令相关
    wire ex_cp0_reg_we_o;
    wire[4:0] ex_cp0_reg_write_addr_o;
    wire[`RegBus] ex_cp0_reg_data_o;
    //异常处理相关
    wire[31:0] ex_excepttype_o;
    wire[`InstAddrBus] ex_current_inst_address_o;
    wire ex_is_in_delayslot_o;

    //连接EX/MEM模块与MEM模块
    wire mem_wreg_i;                            //以MEM模块为主体的命名
    wire[`RegAddrBus] mem_wd_i;
    wire[`RegBus] mem_wdata_i;
    wire[`RegBus] mem_hi_i;
    wire[`RegBus] mem_lo_i;
    wire mem_whilo_i;
    wire[`AluOpBus] mem_aluop_i;
    wire[`RegBus] mem_mem_addr_i;
    wire[`RegBus] mem_reg2_i;
    wire mem_cp0_reg_we_i;
    wire[4:0] mem_cp0_reg_write_addr_i;
    wire[`RegBus] mem_cp0_reg_data_i;
    wire[31:0] mem_excepttype_i;
    wire mem_is_in_delayslot_i;
    wire[`InstAddrBus] mem_current_inst_address_i;

    //连接MEM模块与MEM/WB模块
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
    wire[31:0] mem_excepttype_o;
    wire mem_is_in_delayslot_o;
    wire[`InstAddrBus] mem_current_inst_address_o;

    //连接MEM/WB模块与回写阶段输入(各类寄存器：hilo_reg、LLbit_reg、cp0_reg)
    wire wb_wreg_i;                             //以回写阶段为主体的命名
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
    wire[31:0] wb_excepttype_i;
    wire wb_is_in_delayslot_i;
    wire[`InstAddrBus] wb_current_inst_address_i;

    //连接ID模块与通用寄存器regfile模块
    wire reg1_read;
    wire reg2_read;
    wire[`RegBus] reg1_data;
    wire[`RegBus] reg2_data;
    wire[`RegAddrBus] reg1_addr;
    wire[`RegAddrBus] reg2_addr;

    //连接EX模块和HILO模块输出
    wire[`RegBus] hi;
    wire[`RegBus] lo;

    //连接EX和EX_MEM模块之间实现乘累加、累减指令
    wire[`DoubleRegBus] hilo_temp_o;
    wire[1:0] cnt_o;
    wire[`DoubleRegBus] hilo_temp_i;
    wire[1:0] cnt_i;

    //连接EX模块和DIV模块
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
    wire stallreq_from_if;
    wire stallreq_from_id;
    wire stallreq_from_ex;
    wire stallreq_from_mem;

    //LLbit寄存器模块输出
    wire LLbit_o;

    //连接CP0与EX模块
    wire[4:0] cp0_raddr_i;                      //以CP0模块为主体的命名
    wire[`RegBus] cp0_data_o;

    //清除流水线信号
    wire flush;
    //异常处理例程入口地址线
    wire[`InstAddrBus] new_pc;

    //CP0各个寄存器的输出
    wire[`RegBus] cp0_count;
    wire[`RegBus] cp0_compare;
    wire[`RegBus] cp0_status;
    wire[`RegBus] cp0_cause;
    wire[`RegBus] cp0_epc;
    wire[`RegBus] cp0_config;
    wire[`RegBus] cp0_prid;

    //回写阶段向访存阶段前推的EPC寄存器的最新值
    wire[`RegBus] latest_epc;

    //连接MEM模块与数据Wishbone总线接口模块
    wire[31:0] ram_addr_o;                      //以数据总线接口为主体的命名
    wire[`RegBus] ram_data_i;
    wire[`RegBus] ram_data_o;
    wire ram_ce_o;
    wire ram_we_o;
    wire[3:0] ram_sel_o;


    //PC模块实例化
    pc_reg pc_reg0(
        .rst(rst),
        .clk(clk),

        .ce(rom_ce),
        .pc(pc),

        .stall(stall),
        .flush(flush),
        .new_pc(new_pc),

        .branch_flag_i(id_branch_flag_o),
        .branch_target_address_i(branch_target_address)
        );

    //IF/ID模块实例化
    if_id if_id0(
        .rst(rst),
        .clk(clk),

        .if_pc(pc),
        .if_inst(inst_i),

        .id_pc(id_pc_i),
        .id_inst(id_inst_i),

        .stall(stall),
        .flush(flush)
        );

    //ID模块实例化
    id id0(
        .rst(rst),
        .pc_i(id_pc_i),
        .inst_i(id_inst_i),

        //送到regfile模块的信息
        .reg1_read_o(reg1_read),
        .reg2_read_o(reg2_read),
        .reg1_addr_o(reg1_addr),
        .reg2_addr_o(reg2_addr),
        //来自regfile模块的输入
        .reg1_data_i(reg1_data),
        .reg2_data_i(reg2_data),

        //送到ID/EX模块的信息
        .aluop_o(id_aluop_o),
        .alusel_o(id_alusel_o),
        .reg1_o(id_reg1_o),
        .reg2_o(id_reg2_o),
        .wreg_o(id_wreg_o),
        .wd_o(id_wd_o),
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
        .branch_flag_o(id_branch_flag_o),
        .branch_target_address_o(branch_target_address),

        .link_addr_o(id_link_address_o),
        .is_in_delayslot_o(id_is_in_delayslot_o),

        .is_in_delayslot_i(is_in_delayslot_i),
        .next_inst_in_delayslot_o(next_inst_in_delayslot_o),

        //解决load相关从EX模块回传的指令码
        .ex_aluop_i(ex_aluop_o),

        //异常处理相关
        .excepttype_o(id_excepttype_o),
        .current_inst_address_o(id_current_inst_address_o)
        );

    //通用寄存器regfile模块实例化
    regfile regfile1(
        .rst(rst),
        .clk(clk),

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
        .rdata2(reg2_data)
        );

    //ID/EX模块实例化
    id_ex id_ex0(
        .rst(rst),
        .clk(clk),

        .stall(stall),
        .flush(flush),

        //从ID模块传递过来的信息
        .id_aluop(id_aluop_o),
        .id_alusel(id_alusel_o),
        .id_reg1(id_reg1_o),
        .id_reg2(id_reg2_o),
        .id_wreg(id_wreg_o),
        .id_wd(id_wd_o),
        .id_link_address(id_link_address_o),
        .id_is_in_delayslot(id_is_in_delayslot_o),
        .id_inst(id_inst_o),
        .id_current_inst_address(id_current_inst_address_o),
        .id_excepttype(id_excepttype_o),

        //传递到EX模块的信息
        .ex_aluop(ex_aluop_i),
        .ex_alusel(ex_alusel_i),
        .ex_reg1(ex_reg1_i),
        .ex_reg2(ex_reg2_i),
        .ex_wreg(ex_wreg_i),
        .ex_wd(ex_wd_i),
        .ex_link_address(ex_link_address_i),
        .ex_is_in_delayslot(ex_is_in_delayslot_i),
        .ex_inst(ex_inst_i),
        .ex_current_inst_address(ex_current_inst_address_i),
        .ex_excepttype(ex_excepttype_i),

        //与ID交互，判断下一条指令是否是延迟槽指令
        .next_inst_in_delayslot_i(next_inst_in_delayslot_o),
        .is_in_delayslot_o(is_in_delayslot_i)
        );

    //EX模块实例化
    ex ex0(
        .rst(rst),

        //从ID/EX模块传递过来的信息
        .aluop_i(ex_aluop_i),
        .alusel_i(ex_alusel_i),
        .reg1_i(ex_reg1_i),
        .reg2_i(ex_reg2_i),
        .wreg_i(ex_wreg_i),
        .wd_i(ex_wd_i),

        //输出到EX/MEM模块的信息
        .wreg_o(ex_wreg_o),
        .wd_o(ex_wd_o),
        .wdata_o(ex_wdata_o),
        .hi_o(ex_hi_o),
        .lo_o(ex_lo_o),
        .whilo_o(ex_whilo_o),

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

        //输出到ctrl的暂停流水线信号
        .stallreq(stallreq_from_ex),

        //与EX_MEM模块连接用于乘累加、累减指令的信号
        .hilo_temp_i(hilo_temp_i),
        .cnt_i(cnt_i),
        .hilo_temp_o(hilo_temp_o),
        .cnt_o(cnt_o),

        //与DIV模块连接
        .div_result_i(div_result),
        .div_ready_i(div_ready),
        .div_opdata1_o(div_opdata1),
        .div_opdata2_o(div_opdata2),
        .div_start_o(div_start),
        .signed_div_o(signed_div),

        //转移指令相关
        .link_address_i(ex_link_address_i),
        .is_in_delayslot_i(ex_is_in_delayslot_i),

        //加载存储指令相关
        .inst_i(ex_inst_i),
        .aluop_o(ex_aluop_o),
        .mem_addr_o(ex_mem_addr_o),
        .reg2_o(ex_reg2_o),

        //协处理器访问指令相关
        //MEM阶段数据前推
        .mem_cp0_reg_we(mem_cp0_reg_we_o),
        .mem_cp0_reg_write_addr(mem_cp0_reg_write_addr_o),
        .mem_cp0_reg_data(mem_cp0_reg_data_o),
        //WB阶段数据前推
        .wb_cp0_reg_we(wb_cp0_reg_we_i),
        .wb_cp0_reg_write_addr(wb_cp0_reg_write_addr_i),
        .wb_cp0_reg_data(wb_cp0_reg_data_i),
        //读CP0中的寄存器
        .cp0_reg_read_addr_o(cp0_raddr_i),
        .cp0_reg_data_i(cp0_data_o),
        //传递到下一级流水线
        .cp0_reg_we_o(ex_cp0_reg_we_o),
        .cp0_reg_write_addr_o(ex_cp0_reg_write_addr_o),
        .cp0_reg_data_o(ex_cp0_reg_data_o),

        //异常处理相关
        .excepttype_i(ex_excepttype_i),
        .current_inst_address_i(ex_current_inst_address_i),
        .excepttype_o(ex_excepttype_o),
        .current_inst_address_o(ex_current_inst_address_o),
        .is_in_delayslot_o(ex_is_in_delayslot_o)
        );

    //EX/MEM模块实例化
    ex_mem ex_mem0(
        .rst(rst),
        .clk(clk),

        .stall(stall),
        .flush(flush),

        //来自EX模块的信息
        .ex_wreg(ex_wreg_o),
        .ex_wd(ex_wd_o),
        .ex_wdata(ex_wdata_o),
        .ex_hi(ex_hi_o),
        .ex_lo(ex_lo_o),
        .ex_whilo(ex_whilo_o),

        //送到MEM模块的信息
        .mem_wreg(mem_wreg_i),
        .mem_wd(mem_wd_i),
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
        .mem_cp0_reg_data(mem_cp0_reg_data_i),

        //异常处理相关
        .ex_excepttype(ex_excepttype_o),
        .ex_is_in_delayslot(ex_is_in_delayslot_o),
        .ex_current_inst_address(ex_current_inst_address_o),
        .mem_excepttype(mem_excepttype_i),
        .mem_is_in_delayslot(mem_is_in_delayslot_i),
        .mem_current_inst_address(mem_current_inst_address_i)
        );

    //MEM模块实例化
    mem mem0(
        .rst(rst),

        //来自EX/MEM模块的信息
        .wreg_i(mem_wreg_i),
        .wd_i(mem_wd_i),
        .wdata_i(mem_wdata_i),
        .hi_i(mem_hi_i),
        .lo_i(mem_lo_i),
        .whilo_i(mem_whilo_i),

        //送到MEM/WB模块的信息
        .wreg_o(mem_wreg_o),
        .wd_o(mem_wd_o),
        .wdata_o(mem_wdata_o),
        .hi_o(mem_hi_o),
        .lo_o(mem_lo_o),
        .whilo_o(mem_whilo_o),

        .aluop_i(mem_aluop_i),
        .mem_addr_i(mem_mem_addr_i),
        .reg2_i(mem_reg2_i),

        .mem_addr_o(ram_addr_o),
        .mem_data_i(ram_data_i),
        .mem_data_o(ram_data_o),
        .mem_ce_o(ram_ce_o),
        .mem_we_o(ram_we_o),
        .mem_sel_o(ram_sel_o),

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
        .cp0_reg_data_o(mem_cp0_reg_data_o),

        //异常处理相关
        .excepttype_i(mem_excepttype_i),
        .is_in_delayslot_i(mem_is_in_delayslot_i),
        .current_inst_address_i(mem_current_inst_address_i),
        //CP0寄存器输入
        .cp0_status_i(cp0_status),
        .cp0_cause_i(cp0_cause),
        .cp0_epc_i(cp0_epc),
        //回写阶段CP0的数据前推
        .wb_cp0_reg_we(wb_cp0_reg_we_i),
        .wb_cp0_reg_write_addr(wb_cp0_reg_write_addr_i),
        .wb_cp0_reg_data(wb_cp0_reg_data_i),

        .excepttype_o(mem_excepttype_o),
        .is_in_delayslot_o(mem_is_in_delayslot_o),
        .current_inst_address_o(mem_current_inst_address_o),
        .cp0_epc_o(latest_epc)
        );

    //MEM/WB模块实例化
    mem_wb mem_wb0(
        .rst(rst),
        .clk(clk),

        .stall(stall),
        .flush(flush),

        //来自MEM模块的信息
        .mem_wreg(mem_wreg_o),
        .mem_wd(mem_wd_o),
        .mem_wdata(mem_wdata_o),
        .mem_hi(mem_hi_o),
        .mem_lo(mem_lo_o),
        .mem_whilo(mem_whilo_o),

        //送到回写阶段(regfile)的信息
        .wb_wreg(wb_wreg_i),
        .wb_wd(wb_wd_i),
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

    //特殊寄存器HI/LO实例化
    hilo_reg hilo_reg0(
        .rst(rst),
        .clk(clk),

        //写端口
        .we(wb_whilo_i),
        .hi_i(wb_hi_i),
        .lo_i(wb_lo_i),

        //读端口
        .hi_o(hi),
        .lo_o(lo)
        );

    //流水线暂停控制模块ctrl实例化
    ctrl ctrl0(
        .rst(rst),

        .stallreq_from_if(stallreq_from_if),
        .stallreq_from_id(stallreq_from_id),
        .stallreq_from_ex(stallreq_from_ex),
        .stallreq_from_mem(stallreq_from_mem),

        .stall(stall),

        .excepttype_i(mem_excepttype_o),
        .cp0_epc_i(latest_epc),
        .new_pc(new_pc),

        .flush(flush)
        );

    //除法模块DIV实例化
    div div0(
        .rst(rst),
        .clk(clk),

        .signed_div_i(signed_div),
        .opdata1_i(div_opdata1),
        .opdata2_i(div_opdata2),
        .start_i(div_start),
        .annul_i(flush),

        .result_o(div_result),
        .ready_o(div_ready)
        );

    //LLbit寄存器模块实例化
    LLbit_reg LLbit_reg0(
        .rst(rst),
        .clk(clk),
        .flush(flush),
        .we(wb_LLbit_we_i),
        .LLbit_i(wb_LLbit_value_i),
        .LLbit_o(LLbit_o)
        );

    //CP0模块实例化
    cp0_reg cp0_reg0(
        .rst(rst),
        .clk(clk),

        .we_i(wb_cp0_reg_we_i),
        .waddr_i(wb_cp0_reg_write_addr_i),
        .data_i(wb_cp0_reg_data_i),

        .raddr_i(cp0_raddr_i),
        .data_o(cp0_data_o),

        .excepttype_i(mem_excepttype_o),
        .int_i(int_i),
        .current_inst_addr_i(mem_current_inst_address_o),
        .is_in_delayslot_i(mem_is_in_delayslot_o),

        .count_o(cp0_count),
        .compare_o(cp0_compare),
        .status_o(cp0_status),
        .cause_o(cp0_cause),
        .epc_o(cp0_epc),
        .config_o(cp0_config),
        .prid_o(cp0_prid),

        .timer_int_o(timer_int_o)
        );

    //例化指令Wishbone总线接口模块
    wishbone_bus_if iwishbone_bus_if(
        .rst(rst),
        .clk(clk),

        //控制模块交互信息
        .stall_i(stall),
        .flush_i(flush),
        .stallreq(stallreq_from_if),

        //CPU侧读写操作信息(与PC、IF/ID模块交互)
        .cpu_ce_i(rom_ce),
        .cpu_we_i(1'b0),                //指令存储器始终为读操作
        .cpu_sel_i(4'b1111),            //指令为4个字节32位有效字长
        .cpu_addr_i(pc),
        .cpu_data_i(32'h0000_0000),     //指令存储器没有写入操作
        .cpu_data_o(inst_i),

        //Wishbone总线侧接口
        .wishbone_addr_o(iwishbone_addr_o),
        .wishbone_data_i(iwishbone_data_i),
        .wishbone_data_o(iwishbone_data_o),
        .wishbone_we_o(iwishbone_we_o),
        .wishbone_sel_o(iwishbone_sel_o),
        .wishbone_cyc_o(iwishbone_cyc_o),
        .wishbone_stb_o(iwishbone_stb_o),
        .wishbone_ack_i(iwishbone_ack_i)
        );

    //例化数据Wishbone总线接口模块
    wishbone_bus_if dwishbone_bus_if(
        .rst(rst),
        .clk(clk),

        //控制模块交互信息
        .stall_i(stall),
        .flush_i(flush),
        .stallreq(stallreq_from_mem),

        //CPU侧读写操作信息(与MEM模块交互)
        .cpu_ce_i(ram_ce_o),
        .cpu_we_i(ram_we_o),
        .cpu_sel_i(ram_sel_o),
        .cpu_addr_i(ram_addr_o),
        .cpu_data_i(ram_data_o),
        .cpu_data_o(ram_data_i),

        //Wishbone总线侧接口
        .wishbone_addr_o(dwishbone_addr_o),
        .wishbone_data_i(dwishbone_data_i),
        .wishbone_data_o(dwishbone_data_o),
        .wishbone_we_o(dwishbone_we_o),
        .wishbone_sel_o(dwishbone_sel_o),
        .wishbone_cyc_o(dwishbone_cyc_o),
        .wishbone_stb_o(dwishbone_stb_o),
        .wishbone_ack_i(dwishbone_ack_i)
        );

endmodule
