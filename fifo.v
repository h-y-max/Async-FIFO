module Asy_FIFO
     #(parameter width=16,
       parameter depth=8,
       parameter ptr_width=$clog2(depth)+1'd1,
       parameter almost_full_th=depth-2,
       parameter almost_empty_th=2
     )(input reset_n,
       input wr_CLK,
       input rd_CLK,
       input wr_en,
       input rd_en,
       input [width-1:0] din,
       output reg [width-1:0] dout,
       output reg full,
       output reg empty,
       output reg almost_empty,
       output reg almost_full,
       output reg overflow,
       output reg underflow
    );
       
       localparam addr_width=$clog2(depth);
       localparam real_depth=1<<addr_width;
       
       reg [width-1:0] mem [0:real_depth-1];
       reg wr_sync_rst0;
       reg wr_sync_rst1;
       wire wr_sync_reset_n;
       reg rd_sync_rst0;
       reg rd_sync_rst1;
       wire rd_sync_reset_n;
       wire r_full;
       wire r_empty;
       wire almost_full_comb;
       wire almost_empty_comb;
       
       reg [ptr_width-1:0] wr_add;
       reg [ptr_width-1:0] wp;
       reg [ptr_width-1:0] rd0_wp;
       reg [ptr_width-1:0] rd1_wp;
       wire [ptr_width-1:0] wr_add_next;
       wire [ptr_width-1:0] wr_add_gray_next;
   
       reg [ptr_width-1:0] rd_add;
       reg [ptr_width-1:0] rp;
       reg [ptr_width-1:0] wr0_rp;
       reg [ptr_width-1:0] wr1_rp;
       wire [ptr_width-1:0] rd_add_next;
       wire [ptr_width-1:0] rd_add_gray_next; 
//格雷码转二进制码
     function [ptr_width-1:0] gray_2bin;
          input [ptr_width-1:0] gray;
          reg [ptr_width-1:0] bin;
          integer i;
          begin
             bin[ptr_width-1]=gray[ptr_width-1];
             for(i=ptr_width-2;i>=0;i=i-1)
                bin[i]=gray[i]^bin[i+1];
             gray_2bin=bin;
          end
     endfunction
//异步复位，同步释放
   //写
     always@(posedge wr_CLK or negedge reset_n)
         if(!reset_n)begin
            wr_sync_rst0<=1'd0;
            wr_sync_rst1<=1'd0;
         end
         else begin
            wr_sync_rst0<=1'd1;
            wr_sync_rst1<=wr_sync_rst0;
         end
      
      assign wr_sync_reset_n=wr_sync_rst1;
   //读
     always@(posedge rd_CLK or negedge reset_n)
         if(!reset_n)begin
            rd_sync_rst0<=1'd0;
            rd_sync_rst1<=1'd0;
         end
         else begin
            rd_sync_rst0<=1'd1;
            rd_sync_rst1<=rd_sync_rst0;
         end
      
      assign rd_sync_reset_n=rd_sync_rst1;
//输入数据
    always@(posedge wr_CLK)
         if(wr_sync_reset_n && wr_en && !full)
               mem[wr_add[addr_width-1:0]]<=din;
//输出数据
    always@(posedge rd_CLK or negedge rd_sync_reset_n)
          if(!rd_sync_reset_n)
               dout<={width{1'b0}};
          else if(rd_en && !empty)
               dout<=mem[rd_add[addr_width-1:0]];
//写时钟域
     assign wr_add_next=wr_add + (wr_en && !full);
     assign wr_add_gray_next=(wr_add_next>>1)^wr_add_next;
     always@(posedge wr_CLK or negedge wr_sync_reset_n)
          if(!wr_sync_reset_n)begin
              wr_add<={ptr_width{1'b0}};
              wp<={ptr_width{1'b0}};
          end
          else begin
              wr_add<=wr_add_next;
              wp<=wr_add_gray_next;
          end
//跨读时钟域
      always@(posedge rd_CLK or negedge rd_sync_reset_n)
          if(!rd_sync_reset_n)begin
             rd0_wp<={ptr_width{1'b0}};
             rd1_wp<={ptr_width{1'b0}};
          end
          else begin
             rd0_wp<=wp;
             rd1_wp<=rd0_wp;
          end
//读时钟域
     assign rd_add_next=rd_add + (rd_en && !empty);
     assign rd_add_gray_next=(rd_add_next>>1)^rd_add_next;
     always@(posedge rd_CLK or negedge rd_sync_reset_n)
          if(!rd_sync_reset_n)begin
              rd_add<={ptr_width{1'b0}};
              rp<={ptr_width{1'b0}};
          end
          else begin
              rd_add<=rd_add_next;
              rp<=rd_add_gray_next;
          end
//跨写时钟域
      always@(posedge wr_CLK or negedge wr_sync_reset_n)
          if(!wr_sync_reset_n)begin
             wr0_rp<={ptr_width{1'b0}};
             wr1_rp<={ptr_width{1'b0}};
          end
          else begin
             wr0_rp<=rp;
             wr1_rp<=wr0_rp;
          end   
//满信号判断
      wire [ptr_width-1:0] rd_ptr_bin_wr;
      wire [ptr_width-1:0] wr_fifo_cnt;
      
      assign rd_ptr_bin_wr=gray_2bin(wr1_rp);
      assign wr_fifo_cnt=wr_add - rd_ptr_bin_wr;
      assign r_full=(wr_fifo_cnt>=depth);
      assign almost_full_comb=(wr_fifo_cnt>=almost_full_th);
      
      always@(posedge wr_CLK or negedge wr_sync_reset_n)
            if(!wr_sync_reset_n)begin
                full<=1'd0;
                almost_full<=1'd0;
                overflow<=1'd0;
            end
            else begin
                full<=r_full;
                almost_full<=almost_full_comb;
                overflow<=(wr_en && full);
            end
//空信号判断
      wire [ptr_width-1:0] wr_ptr_bin_rd;
      wire [ptr_width-1:0] rd_fifo_cnt;
      
      assign wr_ptr_bin_rd=gray_2bin(rd1_wp);
      assign rd_fifo_cnt=wr_ptr_bin_rd - rd_add;
      assign almost_empty_comb=(rd_fifo_cnt<=almost_empty_th);
      assign r_empty=(rd_add_gray_next==rd1_wp);
      
      always@(posedge rd_CLK or negedge rd_sync_reset_n)
            if(!rd_sync_reset_n)begin
                empty<=1'd1;
                almost_empty<=1'd1;
                underflow<=1'd0;
            end
            else begin
                empty<=r_empty;   
                almost_empty<=almost_empty_comb;
                underflow<=(rd_en && empty);
            end      
endmodule
