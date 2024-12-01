//`timescale 1ns/1ps

/////////////////////Package/////////////////////////
package pkg;
	int no_of_transactions=1;
endpackage
/////////////////////RTL//////////////////////////
module mod15_count(input clk,rst,load,mode,input [3:0]din,output reg [3:0]dout);
	always@(posedge clk)
		begin
			if(rst)
				dout<=0;
			else if(load)
				dout<=din;
			else if(mode==0)
				begin
					if(dout==4'd14)
						dout<=0;
					else
						dout<=dout+1'b1;
				end
			else if(mode==1)
				begin
					if(dout==0)
						dout<=14;
					else
						dout<=dout-1'b1;
				end
			else
				dout<=dout;
		end
endmodule

//               interface          //
interface count_if(input bit clk);
	logic rst;
	logic load;
	logic mode;
	logic [3:0]din;
	logic [3:0]dout;
clocking wr_drv_cb@(posedge clk);
	default input #1 output #1;
	output rst;
	output load;
	output mode;
	output din;
endclocking 
clocking rd_mon_cb@(posedge clk);
	default input #1 output #1;
	input dout;
endclocking
clocking wr_mon_cb@(posedge clk);
	default input #1 output #1;
	input rst;
	input load;
	input mode;
	input din;
endclocking

modport wr_drv_mp(clocking wr_drv_cb);
modport rd_mon_mp(clocking rd_mon_cb);
modport wr_mon_mp(clocking wr_mon_cb);

endinterface

//           transaction class      //
class count_trans ;
	rand bit rst;
	rand bit mode;
	rand bit load;
	rand bit [3:0]din;
	bit [3:0]dout;
	constraint c1{ din inside{[0:14]};}
	constraint c2{ rst dist{ 0:=10,1:=1};}
	constraint c3{load dist{0:=10,1:=2};};
	constraint c4{mode dist {[0:1]:/10};}
static int no_of_rst_trans;
static int no_of_load_trans;
static int no_of_mode_trans;
static int no_of_trans_id;

function void display(input string s);
	$display("%s",s);
	$display("=========================================");
	$display("transaction id is %d",no_of_trans_id);
	$display("reset=%d,load=%d,mode=%d",rst,load,mode);
	$display("Data in =%d",din);
	$display("Data out =%d",dout);
	$display("=========================================");
endfunction
function void post_randomize;
	if(rst==1)
		no_of_rst_trans++;
	if(load==1)
		no_of_load_trans++;
	if(mode==1)
		no_of_mode_trans++;
	display("Randomized data");
endfunction
endclass 

////////////            generator        ////////////

class count_gen;
	count_trans data1;
	count_trans data2;
	mailbox #(count_trans) gen2wr;
	
	function new(mailbox #(count_trans) gen2wr);
		this.gen2wr=gen2wr;
		data1=new();
	endfunction
virtual task start();
	fork
		begin
			for(int i=0;i<pkg::no_of_transactions;i++)
				begin 
					data1.no_of_trans_id++;
					assert(data1.randomize());
					data2=new data1;
					gen2wr.put(data2);
				end 
		end 
	join_none 
endtask 
endclass

/////////////////////    write driver       ///////////////////

class count_wr_drv;
	virtual count_if.wr_drv_mp wr_drv_if;
	mailbox #(count_trans) gen2wr;
	count_trans data2duv;
function new(virtual count_if.wr_drv_mp wr_drv_if,
			mailbox #(count_trans) gen2wr);
			this.wr_drv_if=wr_drv_if;
			this.gen2wr=gen2wr;
endfunction
	virtual task drive();
		repeat(2)
			begin 
			@(wr_drv_if.wr_drv_cb)
				wr_drv_if.wr_drv_cb.rst<=data2duv.rst;
				wr_drv_if.wr_drv_cb.load<=data2duv.load;
				wr_drv_if.wr_drv_cb.mode<=data2duv.mode;
				wr_drv_if.wr_drv_cb.din<=data2duv.din;
			end 
			
endtask
	virtual task start();
		fork 
			forever 
				begin 
					gen2wr.get(data2duv);
					drive();
				end 
		join_none;
	endtask 
   /* virtual task drive();
		repeat(2)
			begin 
			@(wr_drv_if.wr_drv_cb)
				wr_drv_if.wr_drv_cb.rst<=data2duv.rst;
				wr_drv_if.wr_drv_cb.load<=data2duv.load;
				wr_drv_if.wr_drv_cb.mode<=data2duv.mode;
				wr_drv_if.wr_drv_cb.din<=data2duv.din;
			end 
			
endtask*/
endclass
//           write monitor        //

class count_wr_monitor;
	virtual count_if.wr_mon_mp wr_mon_if;
	mailbox #(count_trans)wr2rm;
	count_trans data2rm;
	
	function new(virtual count_if.wr_mon_mp wr_mon_if,
				mailbox #(count_trans)wr2rm);
		this.wr_mon_if=wr_mon_if;
		this.wr2rm=wr2rm;
		data2rm=new();
	endfunction 
	virtual task monitor();
		repeat(2)
		@(wr_mon_if.wr_mon_cb);
			begin 
				data2rm.rst=wr_mon_if.wr_mon_cb.rst;
				data2rm.load=wr_mon_if.wr_mon_cb.load;
				data2rm.mode=wr_mon_if.wr_mon_cb.mode;
				data2rm.din=wr_mon_if.wr_mon_cb.din;
			end
	endtask
	virtual task start();
		fork 
			forever 
				begin 
				//	wr2rm.get(data2rm);
					monitor();
					wr2rm.put(data2rm);
				end 
		join_none 
	endtask 
	
	/*virtual task monitor();
		repeat(2)
		@(wr_mon_if.wr_mon_cb);
			begin 
				data2rm.rst=wr_mon_if.wr_mon_cb.rst;
				data2rm.load=wr_mon_if.wr_mon_cb.load;
				data2rm.mode=wr_mon_if.wr_mon_cb.mode;
				data2rm.din=wr_mon_if.wr_mon_cb.din;
			end
	endtask*/
endclass 

//        read monitor      //
class count_rd_monitor;
	virtual count_if.rd_mon_mp rd_mon_if;
	mailbox #(count_trans)rd2sb;
	count_trans data2sb = new();
	function new(virtual count_if.rd_mon_mp rd_mon_if,
				mailbox #(count_trans)rd2sb);
		this.rd_mon_if=rd_mon_if;
		this.rd2sb=rd2sb;
	endfunction 
virtual task start();
	fork 
		forever 
			begin
			 monitor();
			 rd2sb.put(data2sb);
			 // monitor();
			 end 
	join_none 
endtask 
virtual task monitor();
	@(rd_mon_if.rd_mon_cb);
		begin 
			data2sb.dout=rd_mon_if.rd_mon_cb.dout;
end
endtask
endclass

//      reference model      //

class count_rf_model;
	count_trans mon_data;
	mailbox #(count_trans)wr2rm;
	mailbox #(count_trans)rm2sb;
	logic [3:0]array;
	function new(mailbox #(count_trans)wr2rm,
				mailbox #(count_trans)rm2sb);
		this.wr2rm=wr2rm;
		this.rm2sb=rm2sb;
	endfunction 
	
	virtual task start();
		fork 
			begin
			forever
				begin 
					wr2rm.get(mon_data);
					count_rm(mon_data);
					mon_data.dout=array;
					rm2sb.put(mon_data);
				end 
			end
		join_none
	endtask 
	virtual task count_rm(count_trans mon_data);
		begin 
			if(mon_data.rst)
				array<=0;
			else if(mon_data.load)
				array<=mon_data.din;
			else if(mon_data.mode==0)
				begin 
					if(array==4'd15)
						array<=4'd0;
					else 
						array<=array+1'b1;
				end 
			else if(mon_data.mode ==1)
				begin 
					if(array==0)
						array<=15;
					else 
						array<=array-1'b1;
				end 
		end 
	endtask 
endclass
	
//          score board          //

class count_sb;
	event DONE;
	int data_verified=0;
	int rm_data_count=0;
	int mon_data_count=0;
	
	count_trans rm_data;
	count_trans cov_data;
	count_trans mon_sb;
	mailbox #(count_trans)rm2sb;
	mailbox #(count_trans)mon2sb;
	
	covergroup mem_coverage;
		
		A: coverpoint cov_data.mode{
						bins ZERO={0};
						bins ONE={1};}
		B: coverpoint cov_data.dout{
					   bins ZE={0};
                       bins ON={1};
                       bins TW={2};
                       bins THR={3};  
                       bins FO={4};
                       bins FI={5};
                       bins SI={6};
                       bins SE={7};
                       bins EI={8};
                       bins NI={9};
                       bins TE={10};
                       bins EL={11};
					   bins TW1={12};
					   bins TH1={13};
					   bins FO1={14};
                                 }
      READxADD: cross A,B; 
      
   endgroup : mem_coverage
	function new(mailbox #(count_trans) rm2sb,
                mailbox #(count_trans) mon2sb);
      this.rm2sb    = rm2sb;
      this.mon2sb = mon2sb;
      mem_coverage  = new;    
   endfunction: new			
						
virtual task check(count_trans rddata);
   begin
     if(rm_data.dout == rddata.dout)
        $display("Count Matches %d",rddata.dout);
     else
        $display("Count Not matches");
	end
data_verified++;
cov_data=new rm_data;
mem_coverage.sample();
if(data_verified>=pkg::no_of_transactions)
	begin
		->DONE;
	end
endtask

virtual task start();
	fork
		forever
			begin
				rm2sb.get(rm_data);
				rm_data_count++;
				mon2sb.get(mon_sb);
				mon_data_count++;
				check(mon_sb);
			end
    join_none
endtask

virtual function void report();
      $display(" ------------------------ SCOREBOARD REPORT ----------------------- \n ");
      $display(" %0d Model Data Generated, %0d Monito Data Recevied, %0d  Data Verified \n",
                                             rm_data_count,mon_data_count,data_verified);
      $display(" ------------------------------------------------------------------ \n ");
   endfunction: report
    
endclass
				

////////////////////////////////Environment//////////////////////////
class count_env;

virtual count_if.wr_drv_mp wr_drv_if;
virtual count_if.wr_mon_mp wr_mon_if;
virtual count_if.rd_mon_mp rd_mon_if;

mailbox #(count_trans) gen2wr =new();
mailbox #(count_trans) wr2rm = new();
mailbox #(count_trans) rd2sb=new();
mailbox #(count_trans) rm2sb=new();

count_gen gen_h;
count_wr_drv wr_drv_h;
count_rd_monitor rd_mon_h;
count_wr_monitor wr_mon_h;
count_rf_model ref_mod_h;
count_sb sb_h;

function new(virtual count_if.wr_drv_mp wr_drv_if,virtual count_if.wr_mon_mp wr_mon_if,virtual count_if.rd_mon_mp rd_mon_if);
   this.wr_drv_if=wr_drv_if;
   this.wr_mon_if=wr_mon_if;
   this.rd_mon_if=rd_mon_if;
   endfunction          

virtual task build;
    gen_h=new(gen2wr);
    wr_drv_h=new(wr_drv_if,gen2wr);
    wr_mon_h=new(wr_mon_if,wr2rm);
    rd_mon_h=new(rd_mon_if,rd2sb);
    ref_mod_h=new(wr2rm,rm2sb);
    sb_h=new(rm2sb,rd2sb);
    endtask
task start();
    gen_h.start();
    wr_drv_h.start();
    wr_mon_h.start();
    rd_mon_h.start();
    ref_mod_h.start();
    sb_h.start();
   endtask
  
   task stop();
      wait(sb_h.DONE.triggered);
   endtask : stop 
task run();
     start();
     stop();
     sb_h.report();
   endtask
endclass 
////////////////////////// TEST CASE/////////////////////
class test;
//int no_of_transactions=1;
	virtual count_if.wr_drv_mp wr_drv_if;
	virtual count_if.wr_mon_mp wr_mon_if;
	virtual count_if.rd_mon_mp rd_mon_if;

count_env env_h;
function new(virtual count_if.wr_drv_mp wr_drv_if,virtual count_if.wr_mon_mp wr_mon_if,virtual count_if.rd_mon_mp rd_mon_if);
   this.wr_drv_if=wr_drv_if;
   this.wr_mon_if=wr_mon_if;
   this.rd_mon_if=rd_mon_if;
   env_h=new(wr_drv_if,wr_mon_if,rd_mon_if);
endfunction    
task build();
	begin
		pkg::no_of_transactions =500;
	env_h.build;
	end
endtask
task run();
	begin 
		env_h.run();
		$finish;
	end
endtask
endclass
/* ///////////////////////////////////Top module/////////////////////
*/
module top();
	import pkg::*;
    parameter cycle = 10;
    reg clk;
    count_if duv_if(clk);
    test test_h;

    mod15_count duv(
        .clk(clk),
        .rst(duv_if.rst),
        .load(duv_if.load),
        .mode(duv_if.mode),
        .din(duv_if.din),
        .dout(duv_if.dout)
    );

    initial begin
        test_h = new(duv_if, duv_if, duv_if);
        test_h.build();
        test_h.run();
    end

    initial begin
        clk = 1'b0;
        forever #(cycle / 2) clk = ~clk;
    end
endmodule



