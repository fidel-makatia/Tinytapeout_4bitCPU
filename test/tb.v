// ============================================================================
// Testbench — Nibble 4-bit CPU
// ============================================================================
// Runs 5 test programs and verifies CPU behavior:
//   Test 1: Basic ALU (LDI, ADD, SUB, AND, OR, XOR, NOT)
//   Test 2: Shift operations (SHL, SHR)
//   Test 3: Branching (JMP, JZ, JNZ, JC)
//   Test 4: Counter loop (counts 0 to 15 then halts)
//   Test 5: Fibonacci sequence (4-bit)
// ============================================================================

`timescale 1ns / 1ps

module tb;

    reg        clk;
    reg        rst_n;
    reg        ena;
    reg  [7:0] ui_in;
    wire [7:0] uo_out;
    reg  [7:0] uio_in;
    wire [7:0] uio_out;
    wire [7:0] uio_oe;

    // Decode outputs for readability
    wire [3:0] acc    = uo_out[3:0];
    wire       carry  = uo_out[4];
    wire       zero   = uo_out[5];
    wire       halted = uo_out[6];
    wire       phase  = uo_out[7];
    wire [3:0] pc     = uio_out[3:0];

    // Test infrastructure
    integer test_num;
    integer pass_count;
    integer fail_count;
    integer total_tests;

    // Program ROM (16 x 8-bit instructions per test)
    reg [7:0] rom [0:15];

    // DUT
    tt_um_fidel_makatia_4bit_cpu dut (
        .clk     (clk),
        .rst_n   (rst_n),
        .ena     (ena),
        .ui_in   (ui_in),
        .uo_out  (uo_out),
        .uio_in  (uio_in),
        .uio_out (uio_out),
        .uio_oe  (uio_oe)
    );

    // Clock: 10ns period (100 MHz)
    initial clk = 0;
    always #5 clk = ~clk;

    // Drive instruction from ROM based on PC
    always @(*) begin
        ui_in = rom[pc];
    end

    // ---- Helper tasks ----

    task reset_cpu;
        begin
            rst_n = 0;
            ena   = 1;
            uio_in = 8'b0;
            @(posedge clk);
            @(posedge clk);
            @(negedge clk);  // release reset mid-cycle so next posedge is clean FETCH
            rst_n = 1;
        end
    endtask

    // Run N full instructions (2 clocks each: FETCH + EXECUTE)
    // After this task, the Nth instruction's result is visible in acc/flags
    task run_cycles;
        input integer n;
        integer i;
        begin
            for (i = 0; i < n; i = i + 1) begin
                @(posedge clk);  // FETCH edge
                @(posedge clk);  // EXECUTE edge -> results latched
            end
            #1;  // small delay so registered outputs are visible
        end
    endtask

    // Check accumulator value
    task check_acc;
        input [3:0] expected;
        input [255:0] label;  // wide enough for string
        begin
            total_tests = total_tests + 1;
            if (acc === expected) begin
                $display("  [PASS] %0s: ACC = %0d (expected %0d)", label, acc, expected);
                pass_count = pass_count + 1;
            end else begin
                $display("  [FAIL] %0s: ACC = %0d (expected %0d)", label, acc, expected);
                fail_count = fail_count + 1;
            end
        end
    endtask

    // Check a flag
    task check_flag;
        input       actual;
        input       expected;
        input [255:0] label;
        begin
            total_tests = total_tests + 1;
            if (actual === expected) begin
                $display("  [PASS] %0s: %0b (expected %0b)", label, actual, expected);
                pass_count = pass_count + 1;
            end else begin
                $display("  [FAIL] %0s: %0b (expected %0b)", label, actual, expected);
                fail_count = fail_count + 1;
            end
        end
    endtask

    // Clear ROM
    task clear_rom;
        integer i;
        begin
            for (i = 0; i < 16; i = i + 1)
                rom[i] = 8'h00;  // NOP
        end
    endtask

    // ---- Opcode encoding helpers ----
    // {opcode[3:0], imm[3:0]}
    `define NOP      8'h00
    `define LDI(imm) {4'h1, imm}
    `define ADD(imm) {4'h2, imm}
    `define SUB(imm) {4'h3, imm}
    `define AND(imm) {4'h4, imm}
    `define OR(imm)  {4'h5, imm}
    `define XOR(imm) {4'h6, imm}
    `define NOT      8'h70
    `define SHL      8'h80
    `define SHR      8'h90
    `define JMP(adr) {4'hA, adr}
    `define JZ(adr)  {4'hB, adr}
    `define JC(adr)  {4'hC, adr}
    `define JNZ(adr) {4'hD, adr}
    `define INP      8'hE0
    `define HLT      8'hF0

    // ================================================================
    // Main test sequence
    // ================================================================
    initial begin
        $dumpfile("tb.vcd");
        $dumpvars(0, tb);

        pass_count  = 0;
        fail_count  = 0;
        total_tests = 0;

        $display("");
        $display("============================================================");
        $display("  Nibble 4-bit CPU — Verification Suite");
        $display("============================================================");

        // ============================================================
        // TEST 1: Basic ALU Operations
        // ============================================================
        test_num = 1;
        $display("");
        $display("--- Test %0d: Basic ALU Operations ---", test_num);

        clear_rom;
        //  0: LDI 5       -> A = 5
        //  1: ADD 3       -> A = 8
        //  2: SUB 2       -> A = 6
        //  3: AND 0xC     -> A = 6 & 12 = 4
        //  4: OR  0x1     -> A = 4 | 1 = 5
        //  5: XOR 0xF     -> A = 5 ^ 15 = 10
        //  6: NOT         -> A = ~10 = 5
        //  7: LDI 0       -> A = 0, Z=1
        //  8: SUB 1       -> A = 15 (underflow), C=1
        //  9: HLT
        rom[0]  = `LDI(4'd5);
        rom[1]  = `ADD(4'd3);
        rom[2]  = `SUB(4'd2);
        rom[3]  = `AND(4'd12);
        rom[4]  = `OR(4'd1);
        rom[5]  = `XOR(4'd15);
        rom[6]  = `NOT;
        rom[7]  = `LDI(4'd0);
        rom[8]  = `SUB(4'd1);
        rom[9]  = `HLT;

        reset_cpu;

        run_cycles(1);  // LDI 5
        check_acc(4'd5, "LDI 5");

        run_cycles(1);  // ADD 3
        check_acc(4'd8, "ADD 3 (5+3=8)");

        run_cycles(1);  // SUB 2
        check_acc(4'd6, "SUB 2 (8-2=6)");

        run_cycles(1);  // AND 12
        check_acc(4'd4, "AND 12 (6&12=4)");

        run_cycles(1);  // OR 1
        check_acc(4'd5, "OR 1 (4|1=5)");

        run_cycles(1);  // XOR 15
        check_acc(4'd10, "XOR 15 (5^15=10)");

        run_cycles(1);  // NOT
        check_acc(4'd5, "NOT (~10=5)");

        run_cycles(1);  // LDI 0
        check_acc(4'd0, "LDI 0");
        check_flag(zero, 1'b1, "Z flag after LDI 0");

        run_cycles(1);  // SUB 1 -> underflow
        check_acc(4'd15, "SUB 1 (0-1=15 underflow)");
        check_flag(carry, 1'b1, "C flag after underflow");

        run_cycles(1);  // HLT
        check_flag(halted, 1'b1, "HLT");

        // ============================================================
        // TEST 2: Shift Operations
        // ============================================================
        test_num = 2;
        $display("");
        $display("--- Test %0d: Shift Operations ---", test_num);

        clear_rom;
        //  0: LDI 1       -> A = 0001
        //  1: SHL         -> A = 0010, C=0
        //  2: SHL         -> A = 0100, C=0
        //  3: SHL         -> A = 1000, C=0
        //  4: SHL         -> A = 0000, C=1, Z=1
        //  5: LDI 8       -> A = 1000
        //  6: SHR         -> A = 0100, C=0
        //  7: SHR         -> A = 0010, C=0
        //  8: SHR         -> A = 0001, C=0
        //  9: SHR         -> A = 0000, C=1, Z=1
        // 10: HLT
        rom[0]  = `LDI(4'd1);
        rom[1]  = `SHL;
        rom[2]  = `SHL;
        rom[3]  = `SHL;
        rom[4]  = `SHL;
        rom[5]  = `LDI(4'd8);
        rom[6]  = `SHR;
        rom[7]  = `SHR;
        rom[8]  = `SHR;
        rom[9]  = `SHR;
        rom[10] = `HLT;

        reset_cpu;

        run_cycles(1);  // LDI 1
        check_acc(4'd1, "LDI 1");

        run_cycles(1);  // SHL
        check_acc(4'd2, "SHL (1<<1=2)");
        check_flag(carry, 1'b0, "C after SHL 1");

        run_cycles(1);  // SHL
        check_acc(4'd4, "SHL (2<<1=4)");

        run_cycles(1);  // SHL
        check_acc(4'd8, "SHL (4<<1=8)");

        run_cycles(1);  // SHL -> overflow
        check_acc(4'd0, "SHL (8<<1=0 overflow)");
        check_flag(carry, 1'b1, "C after SHL overflow");
        check_flag(zero, 1'b1, "Z after SHL to 0");

        run_cycles(1);  // LDI 8
        check_acc(4'd8, "LDI 8");

        run_cycles(1);  // SHR
        check_acc(4'd4, "SHR (8>>1=4)");

        run_cycles(1);  // SHR
        check_acc(4'd2, "SHR (4>>1=2)");

        run_cycles(1);  // SHR
        check_acc(4'd1, "SHR (2>>1=1)");

        run_cycles(1);  // SHR -> underflow
        check_acc(4'd0, "SHR (1>>1=0)");
        check_flag(carry, 1'b1, "C after SHR underflow");
        check_flag(zero, 1'b1, "Z after SHR to 0");

        // ============================================================
        // TEST 3: Branch Instructions
        // ============================================================
        test_num = 3;
        $display("");
        $display("--- Test %0d: Branch Instructions ---", test_num);

        clear_rom;
        //  0: LDI 0       -> A=0, Z=1
        //  1: JZ  4       -> should jump to 4 (Z is set)
        //  2: LDI 15      -> SHOULD NOT EXECUTE
        //  3: HLT         -> SHOULD NOT EXECUTE
        //  4: LDI 7       -> A=7
        //  5: JNZ 8       -> should jump to 8 (Z is clear)
        //  6: LDI 15      -> SHOULD NOT EXECUTE
        //  7: HLT         -> SHOULD NOT EXECUTE
        //  8: ADD 9       -> A=7+9=16=0 (overflow), C=1
        //  9: JC  12      -> should jump to 12 (C is set)
        // 10: LDI 15      -> SHOULD NOT EXECUTE
        // 11: HLT         -> SHOULD NOT EXECUTE
        // 12: JMP 14      -> unconditional jump to 14
        // 13: HLT         -> SHOULD NOT EXECUTE
        // 14: LDI 3       -> A=3 (final value)
        // 15: HLT
        rom[0]  = `LDI(4'd0);
        rom[1]  = `JZ(4'd4);
        rom[2]  = `LDI(4'd15);
        rom[3]  = `HLT;
        rom[4]  = `LDI(4'd7);
        rom[5]  = `JNZ(4'd8);
        rom[6]  = `LDI(4'd15);
        rom[7]  = `HLT;
        rom[8]  = `ADD(4'd9);
        rom[9]  = `JC(4'd12);
        rom[10] = `LDI(4'd15);
        rom[11] = `HLT;
        rom[12] = `JMP(4'd14);
        rom[13] = `HLT;
        rom[14] = `LDI(4'd3);
        rom[15] = `HLT;

        reset_cpu;

        run_cycles(1);  // LDI 0
        check_acc(4'd0, "LDI 0");
        check_flag(zero, 1'b1, "Z set for branch");

        run_cycles(1);  // JZ 4 -> should branch
        // After JZ, PC should be 4, next FETCH loads rom[4]

        run_cycles(1);  // LDI 7 (at addr 4)
        check_acc(4'd7, "JZ taken -> LDI 7 at addr 4");

        run_cycles(1);  // JNZ 8 -> should branch (Z=0 after LDI 7)

        run_cycles(1);  // ADD 9 (at addr 8) -> 7+9=16=0, C=1
        check_acc(4'd0, "JNZ taken -> ADD 9 at addr 8 (7+9=0)");
        check_flag(carry, 1'b1, "C set after overflow");

        run_cycles(1);  // JC 12 -> should branch

        run_cycles(1);  // JMP 14 (at addr 12)

        run_cycles(1);  // LDI 3 (at addr 14)
        check_acc(4'd3, "JMP chain -> LDI 3 at addr 14");

        run_cycles(1);  // HLT (at addr 15)
        check_flag(halted, 1'b1, "HLT after branch chain");

        // ============================================================
        // TEST 4: Counter Loop (0 to 15, then halt)
        // ============================================================
        test_num = 4;
        $display("");
        $display("--- Test %0d: Counter Loop (0->15) ---", test_num);

        clear_rom;
        //  0: LDI 0       -> A = 0
        //  1: ADD 1       -> A = A + 1
        //  2: JNZ 1       -> loop back if A != 0
        //  3: HLT         -> halt when A wraps to 0 (after 15+1)
        rom[0] = `LDI(4'd0);
        rom[1] = `ADD(4'd1);
        rom[2] = `JNZ(4'd1);
        rom[3] = `HLT;

        reset_cpu;

        // Run: 1 (LDI) + 15*(ADD+JNZ) + 1*(ADD wrap) + 1*(JNZ fall-thru) + 1*(HLT)
        // = 1 + 30 + 1 + 1 + 1 = 34 instructions? Let me trace:
        // LDI 0 -> A=0
        // ADD 1 -> A=1, JNZ 1 -> branch
        // ADD 1 -> A=2, JNZ 1 -> branch
        // ...
        // ADD 1 -> A=15, JNZ 1 -> branch
        // ADD 1 -> A=0 (wrap), Z=1, JNZ 1 -> NO branch (falls through)
        // HLT
        // Total: 1 + 16*2 + 1 = 34 instructions

        // Run LDI first
        run_cycles(1);
        check_acc(4'd0, "Counter init");

        // Run 15 iterations (ADD + JNZ each = 2 instructions)
        run_cycles(2 * 15);
        check_acc(4'd15, "Counter at 15");

        // One more ADD wraps to 0, then JNZ falls through
        run_cycles(2);
        check_acc(4'd0, "Counter wrapped to 0");
        check_flag(zero, 1'b1, "Z after wrap");

        // HLT
        run_cycles(1);
        check_flag(halted, 1'b1, "HLT after count loop");

        // ============================================================
        // TEST 5: Fibonacci (4-bit: 0,1,1,2,3,5,8,13)
        // ============================================================
        test_num = 5;
        $display("");
        $display("--- Test %0d: Fibonacci Sequence ---", test_num);

        // Fibonacci using only accumulator + XOR swap trick:
        // We use two memory-less "registers" by exploiting the
        // accumulator and the input port. We'll drive uio_in to
        // feed back values.
        //
        // Simpler approach: just compute known fib values with ADD
        //  0: LDI 0       -> fib(0) = 0
        //  1: ADD 1       -> fib(1) = 1 (A = 0+1 = 1)
        //  2: ADD 0       -> fib(2) = 1 (A = 1+0 = 1)
        //  3: ADD 1       -> fib(3) = 2 (A = 1+1 = 2)
        //  4: ADD 1       -> fib(4) = 3 (A = 2+1 = 3)
        //  5: ADD 2       -> fib(5) = 5 (A = 3+2 = 5)
        //  6: ADD 3       -> fib(6) = 8 (A = 5+3 = 8)
        //  7: ADD 5       -> fib(7) = 13 (A = 8+5 = 13)
        //  8: HLT
        clear_rom;
        rom[0] = `LDI(4'd0);
        rom[1] = `ADD(4'd1);
        rom[2] = `ADD(4'd0);
        rom[3] = `ADD(4'd1);
        rom[4] = `ADD(4'd1);
        rom[5] = `ADD(4'd2);
        rom[6] = `ADD(4'd3);
        rom[7] = `ADD(4'd5);
        rom[8] = `HLT;

        reset_cpu;

        run_cycles(1); check_acc(4'd0,  "fib(0) = 0");
        run_cycles(1); check_acc(4'd1,  "fib(1) = 1");
        run_cycles(1); check_acc(4'd1,  "fib(2) = 1");
        run_cycles(1); check_acc(4'd2,  "fib(3) = 2");
        run_cycles(1); check_acc(4'd3,  "fib(4) = 3");
        run_cycles(1); check_acc(4'd5,  "fib(5) = 5");
        run_cycles(1); check_acc(4'd8,  "fib(6) = 8");
        run_cycles(1); check_acc(4'd13, "fib(7) = 13");
        run_cycles(1); check_flag(halted, 1'b1, "HLT after Fibonacci");

        // ============================================================
        // TEST 6: Input Port
        // ============================================================
        test_num = 6;
        $display("");
        $display("--- Test %0d: Input Port ---", test_num);

        clear_rom;
        //  0: IN          -> A = port_in
        //  1: ADD 1       -> A = A + 1
        //  2: HLT
        rom[0] = `INP;
        rom[1] = `ADD(4'd1);
        rom[2] = `HLT;

        reset_cpu;
        uio_in = {4'b1001, 4'b0000};  // port_in = 9 (upper nibble)

        run_cycles(1);  // IN
        check_acc(4'd9, "IN (port=9)");

        run_cycles(1);  // ADD 1
        check_acc(4'd10, "ADD 1 (9+1=10)");

        run_cycles(1);  // HLT
        check_flag(halted, 1'b1, "HLT after IN test");

        // ============================================================
        // Summary
        // ============================================================
        $display("");
        $display("============================================================");
        $display("  RESULTS: %0d / %0d passed", pass_count, total_tests);
        if (fail_count == 0)
            $display("  ALL TESTS PASSED");
        else
            $display("  %0d TESTS FAILED", fail_count);
        $display("============================================================");
        $display("");

        $finish;
    end

    // Timeout watchdog
    initial begin
        #100000;
        $display("ERROR: Simulation timeout!");
        $finish;
    end

endmodule
