`timescale 1ns / 1ps
//******************************************************************************
//                          试商法实现除法模块
//******************************************************************************

`include "defines.v"

module div(
    input wire rst,
    input wire clk,

    input wire signed_div_i,            //是否是有符号除法
    input wire[31:0] opdata1_i,         //被除数
    input wire[31:0] opdata2_i,         //除数
    input wire start_i,                 //是否开始除法运算
    input wire annul_i,                 //是否取消除法运算

    output reg[63:0] result_o,          //除法运算结果
    output reg ready_o                  //除法运算是否结束
    );

    wire[32:0] div_temp;
    reg[5:0] cnt;                       //记录试商法进行了几轮，32时结束
    reg[64:0] dividend;
    reg[1:0] state;
    reg[31:0] divisor;
    reg[31:0] temp_op1;
    reg[31:0] temp_op2;

    // dividend的低32位保存的是被除数、中间结果，第k次迭代结束的时候dividend[k:0]保存
    // 的就是当前得到的中间结果，dividend[31:k+1]保存的就是被除数中还没有参与运算的数
    // 据，dividend高32位是每次迭代时的被减数，所以dividend[63:32]就是被减数minuend，
    // divisor就是除数n，此处进行的就是(minuend - n)运算，结果保存在div_temp中
    assign div_temp = {1'b0,dividend[63:32]} - {1'b0,divisor};

    always @ ( posedge clk ) begin
        if(rst == `RstEnable) begin
            state <= `DivFree;
            ready_o <= `DivResultNotReady;
            result_o <= {`ZeroWord,`ZeroWord};
        end else begin
            case(state)
                //**************************************************************
                //                        DivFree状态
                // 分三种情况：
                // 1)开始除法运算，但除数为0，那么进入DivByZero状态
                // 2)开始除法运算，且除数不为0，那么进入DivOn状态，初始化cnt为0，如果
                // 是有符号除法，且被除数或者除数为负，那么对被除数或者除数取补码。除
                // 数保存到divisor中，将被除数的最高位保存到dividend的第32位，准备进
                // 行第一次迭代
                // 3)没有开始除法运算，保持ready_o为DivResultNotReady，保持result_o
                // 为0
                //**************************************************************
                `DivFree:begin
                    if(start_i == `DivStart  && annul_i == 1'b0) begin
                        if(opdata2_i == `ZeroWord) begin    //除数为0
                            state <= `DivByZero;
                        end else begin                      //除数不为0
                            state <= `DivOn;
                            cnt <= 6'b000000;
                            if(signed_div_i == 1'b1 && opdata1_i[31] == 1'b1) begin
                                temp_op1 = ~opdata1_i + 1;      //被除数取补码
                            end else begin
                                temp_op1 = opdata1_i;
                            end
                            if(signed_div_i == 1'b1 && opdata2_i[31] == 1'b1) begin
                                temp_op2 = ~opdata2_i + 1;      //除数取补码
                            end else begin
                                temp_op2 = opdata2_i;
                            end
                            dividend <= {`ZeroWord,`ZeroWord};
                            dividend[32:1] <= temp_op1;
                            divisor <= temp_op2;
                        end//else
                    end else begin                          //没有开始除法运算
                        ready_o <= `DivResultNotReady;
                        result_o <= {`ZeroWord,`ZeroWord};
                    end
                end//DivFree

                //**************************************************************
                //                        DivByZero状态
                // 如果进入DivByZero状态，那么直接进入DivEnd状态，除法结束，且结果为0
                //**************************************************************
                `DivByZero:begin
                    dividend <= {`ZeroWord,`ZeroWord};
                    state <= `DivEnd;
                end//DivByZero

                //**************************************************************
                //                          DivOn状态
                // 分三种情况：
                // 1)如果输入信号annul_i为1，表示处理器取消除法运算，那么DIV模块直接
                // 回到DivFree状态
                // 2)如果annul_i为0，且cnt不为32，那么表示试商法还没有结束，此时如果
                // 减法结果div_temp为负，那么此次迭代结果是0；如果减法结果div_temp为
                // 正，那么此次迭代结果是1；dividend的最低位保存每次的迭代结果。同时
                // 保持DivOn状态，cnt加1
                // 3)如果annul_i为0，且cnt为32，那么表示试商法结束，如果是有符号除法，
                // 且被除数、除数一正一负，那么将试商法的结果取补码，得到最终的结果，此
                // 处的商、余数都要取补码。商保存在dividend的低32位，余数保存在dividend
                // 的高32位。同时进入DivEnd状态
                //**************************************************************
                `DivOn:begin
                    if(annul_i == 1'b0) begin
                        if(cnt != 6'b100000) begin
                            if(div_temp[32] == 1'b1) begin
                                // 如果div_temp[32]为1，表示(minuend-n)结果小于0，
                                // 将dividend向左移一位，这样就将被除数还没有参与运
                                // 算的最高位加入到下一次迭代的被减数中，同时将0追加
                                // 到中间结果
                                dividend <= {dividend[63:0],1'b0};  //左移一位
                            end else begin
                                // 如果div_temp[32]为0，表示(minuend-n)结果大于等
                                // 于0，将减法的结果与被除数还没有参与运算的最高位加
                                // 入到下一次迭代的被减数中，同时将1追加到中间结果
                                dividend <= {div_temp[31:0],dividend[31:0],1'b1};
                            end
                            cnt <= cnt + 1;
                        end else begin      //试商法结束
                            if((signed_div_i == 1'b1) &&    //商取补码
                                ((opdata1_i[31] ^ opdata2_i[31]) == 1'b1)) begin
                                dividend[31:0] <= (~dividend[31:0] + 1);
                            end
                            if((signed_div_i == 1'b1) &&    //余数取补码,余数与被除数符号一致
                                ((opdata1_i[31] ^ dividend[64]) == 1'b1)) begin
                                dividend[64:33] <= (~dividend[64:33] + 1);
                            end
                            state <= `DivEnd;           //进入DivEnd状态
                            cnt <= 6'b000000;           //cnt清零
                        end//else
                    end else begin         //如果annul_i为1，直接回到DivFree状态
                        state <= `DivFree;
                    end
                end//DivOn

                //**************************************************************
                //                          DivEnd状态
                // 除法运算结束，result_o的宽度是64位，其高32位存储余数，低32位存储商，
                // 设置输出信号ready_o为DivResultReady，表示除法结束，然后等待EX模块
                // 送来DivStop信号，当EX模块送来DivStop信号时，DIV模块回到DivFree状态
                //**************************************************************
                `DivEnd:begin
                    result_o <= {dividend[64:33],dividend[31:0]};
                    ready_o <= `DivResultReady;
                    if(start_i == `DivStop) begin
                        state <= `DivFree;
                        ready_o <= `DivResultNotReady;
                        result_o <= {`ZeroWord,`ZeroWord};
                    end
                end//DivEnd
            endcase//case(state)
        end//else
    end//always
endmodule
