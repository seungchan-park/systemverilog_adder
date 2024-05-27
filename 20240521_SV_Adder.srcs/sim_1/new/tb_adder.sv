`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2024/05/21 11:32:42
// Design Name: 
// Module Name: tb_adder
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

interface adder_intf;
    logic       clk;
    logic       reset;
    logic       valid;
    logic [3:0] a;
    logic [3:0] b;
    logic [3:0] sum;
    logic       carry;
endinterface  //adder_intf

class transaction;
    rand logic [3:0] a;
    rand logic [3:0] b;
    logic      [3:0] sum;
    logic            carry;
    //    rand logic       valid;

    task display(string name);
        $display("[%s] a:%d, b:%d, carry:%d, sum:%d", name, a, b, carry, sum);
    endtask
endclass  //transaction

class generator;
    transaction tr;  // handler
    mailbox #(transaction) gen2drv_mbox;
    event genNextEvent1;

    function new();
        tr = new();  // reference를 준다
    endfunction  //new()

    task run();
        repeat (1000) begin
            assert (tr.randomize())  // tr안의 변수의 random값을 만든다
            else $error("tr.randomize() error!");
            gen2drv_mbox.put(tr);  // mailbox에 put
            tr.display("GEN");
            @(genNextEvent1);  // trigger신호를 받을 때까지 대기
        end
    endtask
endclass  //generator

class driver;
    virtual adder_intf adder_if1;  // 가상 물리X interface
    mailbox #(transaction) gen2drv_mbox;
    transaction trans;
    event monNextEvent;

    function new(virtual adder_intf adder_if2);  // 실제를 받아온다
        this.adder_if1 = adder_if2; // copy : virtual(this 클래스) = original(매개변수)
    endfunction  //new()

    task reset();
        adder_if1.a     <= 0;
        adder_if1.b     <= 0;
        adder_if1.valid <= 1'b0;
        adder_if1.reset <= 1'b1;
        repeat (5) @(adder_if1.clk);
        adder_if1.reset <= 1'b0;
    endtask

    task run();
        forever begin  // 계속 반복
            gen2drv_mbox.get(
                trans);  // blocking code, 값을 받을 때까지 대기
            adder_if1.a     <= trans.a;
            adder_if1.b     <= trans.b;
            adder_if1.valid <= 1'b1;
            trans.display("DRV");
            @(posedge adder_if1.clk);  // 1 clk 대기
            adder_if1.valid <= 1'b0;
            @(posedge adder_if1.clk);  // 1 clk 대기 
            ->monNextEvent;  // triggering
        end
    endtask
endclass  //driver

class monitor;
    virtual adder_intf adder_if3;  // 보통 이름은 똑같이 만든다
    mailbox #(transaction) mon2scb_mbox;
    transaction trans;
    event monNextEvent;

    function new(virtual adder_intf adder_if4);
        this.adder_if3 = adder_if4;
        trans = new();
    endfunction  //new()

    task run();
        forever begin
            @(monNextEvent);
            trans.a     = adder_if3.a;
            trans.b     = adder_if3.b;
            trans.sum   = adder_if3.sum;
            trans.carry = adder_if3.carry;
            mon2scb_mbox.put(trans);
            trans.display("MON");
        end
    endtask
endclass  //monitor

class scoreboard;
    mailbox #(transaction) mon2scb_mbox;
    transaction trans;
    event genNextEvent;

    int total_cnt, pass_cnt, fail_cnt;

    function new();
        total_cnt = 0;
        pass_cnt  = 0;
        fail_cnt  = 0;
    endfunction  //new()

    task run();
        forever begin
            mon2scb_mbox.get(trans);
            trans.display("SCB");
            if ((trans.a + trans.b) == {trans.carry, trans.sum}) begin // (trans.a + trans.b) <- golden reference, reference model
                $display(" --> PASS ! %d + %d = %d", trans.a, trans.b, {
                         trans.carry, trans.sum});
                pass_cnt++;
            end else begin
                $display(" --> FAIL ! %d + %d = %d", trans.a, trans.b, {
                         trans.carry, trans.sum});
                fail_cnt++;
            end
            total_cnt++;
            ->genNextEvent;  // generator trigger
        end
    endtask
endclass  //scoreboard

module tb_adder ();  // main 시작점

    adder_intf adder_if ();  // 실제 물리적 interface 생성
    generator gen;
    driver drv;
    monitor mon;
    scoreboard scb;

    event genNextEvent;
    event monNextEvent;

    mailbox #(transaction) gen2drv_mbox;
    mailbox #(transaction) mon2scb_mbox;

    adder dut (
        .clk  (adder_if.clk),
        .reset(adder_if.reset),
        .valid(adder_if.valid),
        .a    (adder_if.a),
        .b    (adder_if.b),
        .sum  (adder_if.sum),
        .carry(adder_if.carry)
    );

    always #5 adder_if.clk = ~adder_if.clk;

    initial begin
        adder_if.clk   = 1'b0;
        adder_if.reset = 1'b1;
    end

    initial begin
        gen2drv_mbox = new();
        mon2scb_mbox = new();

        gen = new();
        drv = new(adder_if);  // 실체화를 통해 객체를 만들면서 실제 interface handler를 전달
        mon = new(adder_if);
        scb = new();

        gen.genNextEvent1 = genNextEvent;
        scb.genNextEvent = genNextEvent;  // event, event1, event2가 연결
        mon.monNextEvent = monNextEvent;
        drv.monNextEvent = monNextEvent;

        gen.gen2drv_mbox = gen2drv_mbox;
        drv.gen2drv_mbox = gen2drv_mbox;
        mon.mon2scb_mbox = mon2scb_mbox;
        scb.mon2scb_mbox = mon2scb_mbox;

        drv.reset();

        fork  // 독립적 동시실행
            gen.run();
            drv.run();
            mon.run();
            scb.run();
        join_any  // 프로세스 중에 하나라도 끝나면 다음라인 실행

        $display("==================================");
        $display("==         Final Report         ==");
        $display("==================================");
        $display("Total Test : %d", scb.total_cnt);
        $display("Pass Count : %d", scb.pass_cnt);
        $display("Fail Count : %d", scb.fail_cnt);
        $display("==================================");
        $display("test bench is finished!");
        $display("==================================");
        #10 $finish;
    end
endmodule
