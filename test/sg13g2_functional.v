// ============================================================================
// Functional-only models for IHP SG13G2 standard cells
// For gate-level simulation with iverilog (no timing checks)
// ============================================================================

`timescale 1ns/1ps

// DFF with async reset (active-low), Q and QB outputs
module sg13g2_dfrbpq_1 (Q, D, RESET_B, CLK);
    output reg Q;
    input D, RESET_B, CLK;
    always @(posedge CLK or negedge RESET_B)
        if (!RESET_B) Q <= 1'b0;
        else Q <= D;
endmodule

// AND2
module sg13g2_and2_1 (X, A, B);
    output X;
    input A, B;
    assign X = A & B;
endmodule

// AND3
module sg13g2_and3_1 (X, A, B, C);
    output X;
    input A, B, C;
    assign X = A & B & C;
endmodule

// AND4
module sg13g2_and4_1 (X, A, B, C, D);
    output X;
    input A, B, C, D;
    assign X = A & B & C & D;
endmodule

// OR2
module sg13g2_or2_1 (X, A, B);
    output X;
    input A, B;
    assign X = A | B;
endmodule

// NAND2
module sg13g2_nand2_1 (Y, A, B);
    output Y;
    input A, B;
    assign Y = ~(A & B);
endmodule

// NAND2B (A_N is inverted input)
module sg13g2_nand2b_1 (Y, A_N, B);
    output Y;
    input A_N, B;
    assign Y = ~(~A_N & B);
endmodule

// NAND3
module sg13g2_nand3_1 (Y, A, B, C);
    output Y;
    input A, B, C;
    assign Y = ~(A & B & C);
endmodule

// NAND3B (A_N is inverted input)
module sg13g2_nand3b_1 (Y, A_N, B, C);
    output Y;
    input A_N, B, C;
    assign Y = ~(~A_N & B & C);
endmodule

// NAND4
module sg13g2_nand4_1 (Y, A, B, C, D);
    output Y;
    input A, B, C, D;
    assign Y = ~(A & B & C & D);
endmodule

// NOR2
module sg13g2_nor2_1 (Y, A, B);
    output Y;
    input A, B;
    assign Y = ~(A | B);
endmodule

// NOR2B (one inverted input)
module sg13g2_nor2b_1 (Y, A, B_N);
    output Y;
    input A, B_N;
    assign Y = ~(A | ~B_N);
endmodule

// NOR3
module sg13g2_nor3_1 (Y, A, B, C);
    output Y;
    input A, B, C;
    assign Y = ~(A | B | C);
endmodule

// NOR4
module sg13g2_nor4_1 (Y, A, B, C, D);
    output Y;
    input A, B, C, D;
    assign Y = ~(A | B | C | D);
endmodule

// INV
module sg13g2_inv_1 (Y, A);
    output Y;
    input A;
    assign Y = ~A;
endmodule

// XOR2
module sg13g2_xor2_1 (X, A, B);
    output X;
    input A, B;
    assign X = A ^ B;
endmodule

// XNOR2 (netlist uses Y as output name)
module sg13g2_xnor2_1 (Y, A, B);
    output Y;
    input A, B;
    assign Y = ~(A ^ B);
endmodule

// MUX2 (select: S, inputs: A0, A1)
module sg13g2_mux2_1 (X, A0, A1, S);
    output X;
    input A0, A1, S;
    assign X = S ? A1 : A0;
endmodule

// A21OI: Y = ~((A1 & A2) | B)
module sg13g2_a21oi_1 (Y, A1, A2, B1);
    output Y;
    input A1, A2, B1;
    assign Y = ~((A1 & A2) | B1);
endmodule

// A221OI: Y = ~((A1 & A2) | (B1 & B2) | C1)
module sg13g2_a221oi_1 (Y, A1, A2, B1, B2, C1);
    output Y;
    input A1, A2, B1, B2, C1;
    assign Y = ~((A1 & A2) | (B1 & B2) | C1);
endmodule

// A22OI: Y = ~((A1 & A2) | (B1 & B2))
module sg13g2_a22oi_1 (Y, A1, A2, B1, B2);
    output Y;
    input A1, A2, B1, B2;
    assign Y = ~((A1 & A2) | (B1 & B2));
endmodule

// O21AI: Y = ~((A1 | A2) & B1)
module sg13g2_o21ai_1 (Y, A1, A2, B1);
    output Y;
    input A1, A2, B1;
    assign Y = ~((A1 | A2) & B1);
endmodule

// OR3
module sg13g2_or3_1 (X, A, B, C);
    output X;
    input A, B, C;
    assign X = A | B | C;
endmodule

// A21O: X = (A1 & A2) | B1
module sg13g2_a21o_1 (X, A1, A2, B1);
    output X;
    input A1, A2, B1;
    assign X = (A1 & A2) | B1;
endmodule
