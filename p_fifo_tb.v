`timescale 1ns / 1ps
module Asy_FIFO_tb();
   localparam WIDTH=16;
   localparam DEPTH=8;
   
   reg reset_n;
   reg wr_CLK;
   reg rd_CLK;
   reg wr_en;
   reg rd_en;
   reg [WIDTH-1:0] din;
   wire [WIDTH-1:0] dout;
   wire full;
   wire empty;
   wire almost_full;
   wire almost_empty;
   wire overflow;
   wire underflow;
   
   reg [WIDTH-1:0] model_mem [0:255];
   integer model_wr_ptr;
   integer model_rd_ptr;
   integer model_cnt;
   integer wr_times;
   integer rd_times;
   integer i;
   
 Asy_FIFO #(
    .width(WIDTH),
    .depth(DEPTH)
  )  Asy_FIFO_inst(
   .reset_n(reset_n),
   .wr_CLK(wr_CLK),
   .rd_CLK(rd_CLK),
   .wr_en(wr_en),
   .rd_en(rd_en),
   .din(din),
   .dout(dout),
   .full(full),
   .empty(empty),
   .almost_full(almost_full),
   .almost_empty(almost_empty),
   .overflow(overflow),
   .underflow(underflow)
 );
//时钟
 initial wr_CLK=0;
 always #5 wr_CLK=~wr_CLK;
 
 initial rd_CLK=0;
 always #7 rd_CLK=~rd_CLK;
//task 
    //写事务
        task write_one(input [WIDTH-1:0] data);
           begin
             @(posedge wr_CLK);
             while(full===1'b1)@(posedge wr_CLK);
             din<=data;
             wr_en<=1'b1;
             @(posedge wr_CLK);
             wr_en<=1'b0;
             //参考模型
             model_mem[model_wr_ptr]=data;
             model_wr_ptr=model_wr_ptr+1;
             model_cnt=model_cnt+1;
          end
       endtask
    //读事务
       task read_one;
           begin
             @(posedge rd_CLK);
             while(empty===1'b1)@(posedge rd_CLK);
             rd_en<=1'b1;
             @(posedge rd_CLK);
             rd_en<=1'b0;
             #1;
             if(dout!==model_mem[model_rd_ptr])begin
                  $display("FAIL @%0t:dout=%h,exp=%h",$time,dout,model_mem[model_rd_ptr]);
                  $finish;
             end
             $display("READ OK:dout=%h",dout);
             model_rd_ptr=model_rd_ptr+1;
             model_cnt=model_cnt-1;
          end
       endtask
     //overflow
       task write_overflow;
          begin
             @(posedge wr_CLK);
             din<=16'hffff;
             wr_en<=1'b1;
             @(posedge wr_CLK);
             wr_en<=1'b0;
             #1;
             if(overflow!==1'b1)begin
                 $display("FAIL:overflow should be 1 after write to full FIFO");
                 $finish;
             end
             $display("WRITE OVERFLOW OK");
          end
       endtask    
     //underflow
       task read_underflow;
          begin
            @(posedge rd_CLK);
            rd_en<=1'b1;
            @(posedge rd_CLK);
            rd_en<=1'b0;  
            #1;
            if(underflow!==1'b1)begin
                $display("FAIL:underflow should be 1 after read from empty FIFO");
                $finish;
            end
            $display("READ UNDERFLOW OK");
          end
        endtask
//看门狗    
   initial begin
      #10000;
      $display("FAIL: TIMEOUT! simulation hung somewhere");
      $finish;
   end
//剧本
 initial begin
   reset_n=0;
   wr_en=0;
   rd_en=0;
   din=16'b0;
   model_wr_ptr=0;
   model_rd_ptr=0;
   model_cnt=0;
   wr_times=0;
   rd_times=0;
   repeat(5)@(posedge wr_CLK);
   
   reset_n<=1;
   repeat(4)@(posedge rd_CLK);
  //测试1：复位后初态
   if(empty!==1'b1)begin
      $display("FAIL:empty should be 1 after reset");
      $finish;
   end
   if(full!==1'b0)begin
      $display("FAIL:full should be 0 after reset");
      $finish;
   end
   if(dout!=={WIDTH{1'b0}})begin
      $display("FAIL:dout should be 0 after reset");
      $finish;
   end
   $display("TEST POINT 1 PASSED:reset state OK");
  //测试2
   write_one(16'h1111);
   write_one(16'h2222);
   write_one(16'h3333);
   
   read_one;
   read_one;
   read_one;
   
   $display("TEST POINT 2 PASSED:3 write + 3 read OK");
  //测试3
   for(i=0;i<DEPTH;i=i+1)
      write_one(16'h1000+i);
   
   @(posedge wr_CLK);
   #1;
   if(full!==1'b1)begin
      $display("FAIL:full should be 1 after %0d writes",DEPTH);
      $finish;
   end
   $display("FULL FLAG OK");
   
   write_overflow;
   
   for(i=0;i<DEPTH;i=i+1)
      read_one;
   
   if(model_cnt!==0)begin
      $display("FAIL:model_cnt should be 0,got %0d",model_cnt);
      $finish;
   end
   $display("TEST POINT 3 PASSED:full + overflow OK");
  //测试4
   for(i=0;i<DEPTH;i=i+1)
      write_one(16'h2000+i);
      
   for(i=0;i<DEPTH;i=i+1)
      read_one;
   
   @(posedge rd_CLK);
   #1;
   if(empty!==1'b1)begin
      $display("FAIL:empty should be 1 after %0d reads",DEPTH);
      $finish;
   end
   $display("EMPTY FLAG OK");
   
   read_underflow;
   
   if(model_cnt!==0)begin
      $display("FAIL:model_cnt should be 0,got %0d",model_cnt);
      $finish;
   end
   $display("TEST POINT 4 PASSED:empty + underflow OK");
  //测试5
   for(i=0;i<100;i=i+1)begin
      if($random & 1)begin
        if(model_cnt<DEPTH)begin
          write_one($random & 16'hffff);
          wr_times=wr_times + 1;
        end
        else begin
          read_one;
          rd_times=rd_times+1;
        end
      end
      else begin
         if(model_cnt>0)begin
             read_one;
             rd_times=rd_times+1;
         end
         else begin
             write_one($random & 16'hffff);
             wr_times=wr_times+1;
         end
     end
  end
 //收尾
   while(model_cnt>0)
       read_one;
       
   if(model_cnt!==0)begin
       $display("FAIL:model_cnt should be 0,got %0d",model_cnt);
       $finish;
   end
   $display("TEST POINT 5 PASSED:random stress %0d writes + %0d reads OK",wr_times,rd_times);
   $finish;
   end
endmodule

