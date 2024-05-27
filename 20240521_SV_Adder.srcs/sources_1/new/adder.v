`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2024/05/21 11:14:33
// Design Name: 
// Module Name: adder
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module adder (
    input        clk,
    input        reset,
    input        valid,
    input  [3:0] a,
    input  [3:0] b,
    output [3:0] sum,
    output       carry
);

    reg [3:0] sum_reg, sum_next;
    reg carry_reg, carry_next;

    assign sum = sum_reg;
    assign carry = carry_reg;

    // register (f/f)
    always @(posedge clk, posedge reset) begin
        if (reset) begin
            sum_reg   <= 0;
            carry_reg <= 1'b0;
        end else begin
            sum_reg   <= sum_next;
            carry_reg <= carry_next;
        end
    end

    // combinational logic circuit
    always @(*) begin
        carry_next = carry_reg;
        sum_next   = sum_reg;
        if (valid) begin
            {carry_next, sum_next} = a + b;
        end
    end

endmodule
