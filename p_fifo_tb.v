`timescale 1ns/1ps
module p_fifo_tb();
       reg reset_n;
       reg wr_CLK;
       reg rd_CLK;
       reg [15:0] din;
       wire [15:0] dout;
       wire [15:0] data_out;
       wire wr_en;
       wire rd_en;
       wire full;
       wire empty;
p_fifo p_fifo_inst(
       .reset_n(reset_n),
       .wr_CLK(wr_CLK),
       .rd_CLK(rd_CLK),
       .din(din),
       .dout(dout),
       .wr_en(wr_en),
       .rd_en(rd_en),
       .full(full),
       .empty(empty)
);    
initial begin
reset_n=0;
wr_CLK=0;
rd_CLK=0;
#50;
reset_n=1;
#1_000_000;
$stop;
end
assign wr_en=(reset_n==0)?0:!full;
always@(posedge wr_CLK or negedge reset_n)
      if(!reset_n)
          din<=0;
      else if(wr_en)begin
          if(din==7)
             din<=0;
          else 
             din<=din+1'd1;
     end
assign rd_en=!empty;
assign data_out=dout;
always #10 wr_CLK=~wr_CLK;
always #15 rd_CLK=~rd_CLK;
endmodule