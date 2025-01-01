`timescale 1ns / 1ps
module region_tb(

    );
    parameter infile = "image_273x182.hex";
    parameter rows = 273, cols = 182;
    parameter clk_cycle = 10;
    
    reg clk, rstn;
   initial begin
        clk = 0;
        rstn = 0;
        
        #20 rstn = 1;
        
        #20 rstn = 0;

        #100 clk = 1;
        
        forever #(clk_cycle/2) clk = ~clk;
   end
   
   region #(.infile("D:\\NoC\\ima\\image\\image_273x182.hex"), .outfile("D:\\NoC\\ima\\image\\image_output.hex"), .rows(rows),.cols(cols))DUT(.clk(clk), .rstn(rstn));
endmodule
