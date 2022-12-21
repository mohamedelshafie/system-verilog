class transaction;
    //declaring the transaction items
  rand bit [3:0] a;
  rand bit [3:0] b;
  rand bit [1:0] op;
       bit [6:0] c;
       bit [6:0] out;
  function void display(string name);
    $display("-------------------------");
    $display("- %s ",name);
    $display("-------------------------");
    $display("- a = %0d, b = %0d",a,b);
    $display("- op = %0d",op);
    $display("- c = %0d",c);
    $display("- out = %0d",out);
    $display("-------------------------");
  endfunction
endclass //transaction

//-------------------------------------------------------------

class driver;
    //used to count the number of transactions
    int no_transactions;
  
    //creating virtual interface handle
    virtual intf vif;
  
    //creating mailbox handle
    mailbox gen2driv;
  
    //constructor
    function new(virtual intf vif,mailbox gen2driv);
    //getting the interface
    this.vif = vif;
    //getting the mailbox handles from  environment 
    this.gen2driv = gen2driv;
    endfunction
  
    //Reset task, Reset the Interface signals to default/initial values
    task reset;
        wait(vif.reset);
        $display("[ DRIVER ] ----- Reset Started -----");
        vif.a <= 0;
        vif.b <= 0;
        wait(!vif.reset);
        $display("[ DRIVER ] ----- Reset Ended   -----");
    endtask
    
    //drivers the transaction items to interface signals
    task main;
        forever begin
        transaction trans;
        gen2driv.get(trans);
        @(posedge vif.clk);
        vif.a     <= trans.a;
        vif.b     <= trans.b;
        vif.op     <= trans.op;
        @(posedge vif.clk);
        trans.c   = vif.c;
        vif.out     <= trans.out;
        @(posedge vif.clk);
        trans.display("[ Driver ]");
        no_transactions++;
        end
    endtask
endclass //driver



//-----------------------------------------------------------


class generator;
    //declaring transaction class 
    rand transaction trans;
    
    //repeat count, to specify number of items to generate
    int  repeat_count;
    
    //mailbox, to generate and send the packet to driver
    mailbox gen2driv;
    
    //event, to indicate the end of transaction generation
    event ended;
    
    //coverage:
    covergroup cg;
        cp1:coverpoint trans.a;
        cp2:coverpoint trans.b;
        cp3:coverpoint trans.op;
        cp4:cross trans.a,trans.b,trans.op;

    endgroup


    //constructor
    function new(mailbox gen2driv);
        //getting the mailbox handle from env, in order to share the transaction packet between the generator and driver, the same mailbox is shared between both.
        this.gen2driv = gen2driv;
        cg = new();
    endfunction
    
    //main task, generates(create and randomizes) the repeat_count number of transaction packets and puts into mailbox
    task main();
        repeat(repeat_count) begin
        trans = new();
        
        if( !trans.randomize() ) $fatal("Gen:: trans randomization failed");
        cg.sample();
        trans.display("[ Generator ]");
        gen2driv.put(trans);
        end
        -> ended; //triggering indicatesthe end of generation
    endtask
endclass //generator

//-----------------------------------------------------------------

interface intf(input logic clk,reset);
  
  //declaring the signals
  
  logic [3:0] a;
  logic [3:0] b;
  logic       c;
  logic [3:0] out;
  logic [1:0] op;
  
endinterface

//---------------------------------------------------------------

class monitor;
    //creating virtual interface handle
    virtual intf vif;
    
    //creating mailbox handle
    mailbox mon2scb;
    
    //constructor
    function new(virtual intf vif,mailbox mon2scb);
        //getting the interface
        this.vif = vif;
        //getting the mailbox handles from  environment 
        this.mon2scb = mon2scb;
    endfunction
    
    //Samples the interface signal and send the sample packet to scoreboard
    task main;
        forever begin
        transaction trans;
        trans = new();
        @(posedge vif.clk);
        #1; //give time for monitor to catch the right signals
        trans.a   = vif.a;
        trans.b   = vif.b;
        trans.op   = vif.op;
        @(posedge vif.clk);
        trans.c   = vif.c;
        trans.out   = vif.out;
        @(posedge vif.clk);
        mon2scb.put(trans);
        trans.display("[ Monitor ]");
        end
    endtask
endclass //monitor

//---------------------------------------------------------------

class scoreboard;
    //creating mailbox handle
    mailbox mon2scb;
    
    //used to count the number of transactions
    int no_transactions;
    int error;//count no. of transactions gives error
    int pass;//count no. of transactions passes
    //constructor
    function new(mailbox mon2scb);
        //getting the mailbox handles from  environment 
        this.mon2scb = mon2scb;
    endfunction
    
    //Compares the Actual result with the expected result
    task main;
        transaction trans;
        forever begin
        mon2scb.get(trans);
        case (trans.op)
            0: begin
                if((trans.a+trans.b) == {trans.c,trans.out})begin
                    $display("Result is as Expected");
                    pass++;
                end
                else begin
                    $error("Wrong Result.\n\tExpeced: %0d Actual: %0d",(trans.a+trans.b),{trans.c,trans.out});
                    error++;
                end
            end
            1: begin
                if((trans.a ^ trans.b) == {trans.c,trans.out})begin
                    $display("Result is as Expected");
                    pass++;
                end
                else begin
                    $error("Wrong Result.\n\tExpeced: %0d Actual: %0d",(trans.a ^ trans.b),{trans.c,trans.out});
                    error++;
                end
            end
            2: begin
                if((trans.a & trans.b) == {trans.c,trans.out})begin
                    $display("Result is as Expected");
                    pass++;
                end
                else begin
                    $error("Wrong Result.\n\tExpeced: %0d Actual: %0d",(trans.a & trans.b),{trans.c,trans.out});
                    error++;
                end
            end
            3: begin
                if((trans.a | trans.b) == {trans.c,trans.out})begin
                    $display("Result is as Expected");
                    pass++;
                end
                else begin
                    $error("Wrong Result.\n\tExpeced: %0d Actual: %0d",(trans.a | trans.b),{trans.c,trans.out});
                    error++;
                end
            end
            default: $error("wrong operand");
        endcase
        
        no_transactions++;
        trans.display("[ Scoreboard ]");
        $display("error: %0d, pass: %0d",error,pass);
        end
    endtask
endclass //scoreboard

//-------------------------------------------------------------

class enviroment;
    
    //generator and driver instance
    generator 	gen;
    driver    	driv;
    monitor   	mon;
    scoreboard	scb;
    
    //mailbox handle's
    mailbox gen2driv;
    mailbox mon2scb;
    
    //virtual interface
    virtual intf vif;
    
    //constructor
    function new(virtual intf vif);
        //get the interface from test
        this.vif = vif;
        
        //creating the mailbox
        gen2driv = new();
        mon2scb  = new();
        
        //creating generator and driver
        gen  = new(gen2driv);
        driv = new(vif,gen2driv);
        mon  = new(vif,mon2scb);
        scb  = new(mon2scb);
    endfunction
    
    //
    task pre_test();
        driv.reset();
    endtask
    
    task test();
        fork 
        gen.main();
        driv.main();
        mon.main();
        scb.main();
        join_any
    endtask
    
    task post_test();
        wait(gen.ended.triggered);
        wait(gen.repeat_count == driv.no_transactions);
        wait(gen.repeat_count == scb.no_transactions);
    endtask  
    
    //run task
    task run;
        pre_test();
        test();
        post_test();
        $display("coverage= %0.2f",gen.cg.get_inst_coverage());
        $finish;
    endtask
    
endclass //enviroment

//------------------------------------------------------------

program test(intf i_intf);
  
  //declaring environment instance
  enviroment env;
  
  initial begin
    //creating environment
    env = new(i_intf);
    
    //setting the repeat count of generator
    env.gen.repeat_count = 8000;
    
    //calling run of env
    env.run();
  end
endprogram

//----------------------------------------------------------

module tbench_top;
    
    //clock and reset signal declaration
    bit clk;
    bit reset;
    
    //clock generation
    always #5 clk = ~clk;
    
    //reset Generation
    initial begin
        reset = 1;
        #5 reset =0;
    end
    
    
    //creatinng instance of interface
    intf i_intf(clk,reset);
    
    //Testcase instance, interface handle is passed to test as an argument
    test t1(i_intf);
    
    //DUT instance, interface signals are connected to the DUT ports
    ALU DUT (

        .a(i_intf.a),
        .b(i_intf.b),
        .op(i_intf.op),
        .c(i_intf.c),
        .out(i_intf.out)
    );
    
    //enabling the wave dump
    initial begin 
        $dumpfile("dump.vcd"); $dumpvars;
        //$display("coverage= %0.2f",t1.env.gen.cg.get_coverage());
    end
endmodule