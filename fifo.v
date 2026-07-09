module Asy_FIFO
      #(parameter width=16,
        parameter depth=8
       )(
       input reset_n,
       input wr_CLK,
       input rd_CLK,
       input [width-1:0]din,
       input wr_en,
       input rd_en,
       output reg full,
       output reg empty,
       output [width-1:0]dout
    );

       reg [width-1:0] mem [depth-1:0];
       reg [3:0] wr_add;
       wire [3:0] wr_add_next;
       wire [3:0] wr_add_gray_next;
       reg [3:0] wp;
       reg [3:0] rd0_wp;
       reg [3:0] rd1_wp;
       reg [3:0] rd_add;
       wire [3:0] rd_add_next;
       wire [3:0] rd_add_gray_next;
       reg [3:0] rp;
       reg [3:0] wr0_rp;
       reg [3:0] wr1_rp;
       wire r_full;
       wire r_empty;
//输入数据
always@(posedge wr_CLK or negedge reset_n)
      if(reset_n && wr_en && !full)
          mem[wr_add]<=din;
//输出数据
assign dout=mem[rd_add];
//写时钟域
assign wr_add_next=wr_add+(wr_en & ~full);
assign wr_add_gray_next=(wr_add_next>>1)^wr_add_next;
always@(posedge wr_CLK or negedge reset_n)
      if(!reset_n)begin
          wr_add<=0;
          wp<=0;
      end
      else begin
          wr_add<=wr_add_next;
          wp<=wr_add_gray_next;
      end
//跨时钟域
always@(posedge rd_CLK)
      rd0_wp<=wp;
always@(posedge rd_CLK)
      rd1_wp<=rd0_wp;
//读时钟域
assign rd_add_next=rd_add+(rd_en & ~empty);
assign rd_add_gray_next=(rd_add_next>>1)^rd_add_next;
always@(posedge rd_CLK or negedge reset_n)
       if(!reset_n)begin
            rp<=0;
            rd_add<=0;
       end
       else begin
            rd_add<=rd_add_next;
            rp<=rd_add_gray_next;
       end
//跨时钟域
always@(posedge wr_CLK)
     wr0_rp<=rp;
always@(posedge wr_CLK)
     wr1_rp<=wr0_rp;
//空状态判断
assign r_empty=(rd1_wp==rd_add_gray_next)?1:0;
always@(posedge rd_CLK or negedge reset_n)
      if(!reset_n)
          empty<=1;
      else
          empty<=r_empty;
//满信号判断
assign r_full=(~wr1_rp[3:2]==wr_add_gray_next[3:2])?1:0;
always@(posedge wr_CLK or negedge reset_n)
       if(!reset_n)
            full<=0;
       else
            full<=r_full;
endmodule
