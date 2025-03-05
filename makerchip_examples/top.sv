`line 2 "top.tlv" 0
//_\SV

// ------------------------
// SystemVerilog data types

typedef logic [15:0] mips_word;
typedef logic  [7:0] mips_byte;
typedef logic  [2:0] mips_reg;


typedef enum bit [3:0] {
    op_add  = 4'b0001,
    op_and  = 4'b0101,
    op_br   = 4'b0000,
    op_jmp  = 4'b1100,   /* also RET */
    op_jsr  = 4'b0100,   /* also JSRR */
    op_ldb  = 4'b0010,
    op_ldi  = 4'b1010,
    op_lea  = 4'b1110,
    op_not  = 4'b1001,
    op_ldr  = 4'b0110,
    op_rti  = 4'b1000,
    op_shf  = 4'b1101,
    op_stb  = 4'b0011,
    op_sti  = 4'b1011,
    op_str  = 4'b0111,
    op_trap = 4'b1111
} mips_opcode;

typedef enum bit [3:0] {
    alu_add,
    alu_and,
    alu_not
} mips_aluop;






module top(input wire clk, input wire reset, input wire [31:0] cyc_cnt, output wire passed, output wire failed);    /* verilator lint_save */ /* verilator lint_off UNOPTFLAT */  bit [256:0] RW_rand_raw; bit [256+63:0] RW_rand_vect; pseudo_rand #(.WIDTH(257)) pseudo_rand (clk, reset, RW_rand_raw[256:0]); assign RW_rand_vect[256+63:0] = {RW_rand_raw[62:0], RW_rand_raw};  /* verilator lint_restore */  /* verilator lint_off WIDTH */ /* verilator lint_off UNOPTFLAT */
`include "top_gen.sv" //_\TLV
   /*
   
   // Fetch pipe fetches an insruction.
   |fetch
      @1   // "fetch1"
      @2   // "fetch2"
   // A pipeline for execution, beginning from fetch response from memory.
   |exe
      @2   // "fetch2"
      @3   // "fetch3"
      @4   // "decode"
      @5   // exe ("add", "and", "not", "calc_addr", "br")
      @6   // "ld1/st1", "br_taken", or next "fetch 1"
      @7   // "st2", next "fetch 1" after "br_taken"
   // Pipeline for memory response for fetch/load/store.
   // Stages align with those of the instruction fetch response.
   |resp
      @2   // "ld1/st2"
      @3   // "ld2", IR, next "fetch1" for store
      @4   // next "fetch1" for load
   */
   
   // Fetch next instruction
   //_|fetch
      // Next PC
      //_@0
         assign FETCH_reset_a0 = reset;
         
         assign FETCH_valid_br_taken_a0 = EXE_valid_br_taken_a6;
         assign FETCH_pc_a0[15:0] =
            FETCH_reset_a0 ? 16'b0 :
            (FETCH_valid_br_taken_a0 && FETCH_instr_valid_a1)
               ? // Add to PC (increment or branch).
                 FETCH_pc_a1 +
                    (FETCH_instr_valid_a1
                       ? // increment
                         16'd2
                       : // branch
                         {{7{EXE_offset9_a6[8]}},  // sign ext
                          EXE_offset9_a6})         // branch target
               : FETCH_pc_a1[15:0];
               
      // Next instruction
      //_@1
         assign FETCH_instr_valid_a1 =
            // first instruction
            (FETCH_reset_a2 && ! FETCH_reset_a1) ||
            // store
            (RESP_mem_resp_a3 && RESP_StorePending_a3) ||  // /top|resp>>2$st_resp_valid, but better timing.
            // load
            RESP_ld_resp_valid_a4 ||
            // else (alu, branch not-taken)
            EXE_valid_exe_inst_a6;
   
   // Execute the instruction that was fetched.
   //_|exe
      //@2
      //   $reset = *reset;
         
      //_@3
         assign EXE_instr_valid_a3      = RESP_fetch_resp_valid_a3;    
         assign EXE_ir_a3[15:0] = EXE_instr_valid_a3 ? RESP_mem_rdata_a3 :
                                    EXE_ir_a4[15:0];
      
      // Decode
      //_@4
         // Condition on valid instruction if pipelined implementation.
         //_?$instr_valid
            // Instruction fields:
            assign EXE_opcode_a4[3:0]  = EXE_ir_a4[15:12];
            assign EXE_dest_a4[2:0]    = EXE_ir_a4[11:9];
            assign EXE_src1_a4[2:0]    = EXE_ir_a4[8:6];
            assign EXE_src2_a4[2:0]    = EXE_ir_a4[2:0];
            assign EXE_offset6_a4[5:0] = EXE_ir_a4[5:0];
            assign EXE_offset9_a4[8:0] = EXE_ir_a4[8:0];
         
            // Opcode Decode:
            always_comb begin
               casez(EXE_opcode_a4)
                  op_add:  EXE_aluop_a4[3:0] = alu_add;
                  op_and:  EXE_aluop_a4 = alu_and;
                  op_not:  EXE_aluop_a4 = alu_not;
                  default: EXE_aluop_a4 = 'x;
               endcase end
            assign EXE_br_a4 = EXE_opcode_a4 == op_br;
         assign EXE_valid_ld_a4 = EXE_instr_valid_a4 && EXE_opcode_a4 == op_ldr;
         assign EXE_valid_st_a4 = EXE_instr_valid_a4 && EXE_opcode_a4 == op_str;
         assign EXE_valid_mem_instr_a4 = EXE_valid_ld_a4 || EXE_valid_st_a4;
            
      // Regfile
      //_@4
         regfile rf(.clk(clk),
                    .load(RESP_ld_resp_valid_a3),
                    .in((EXE_instr_valid_a4 && ! EXE_valid_mem_instr_a4)
                              ? EXE_rslt_a5 :
                                RESP_mem_rdata_a3),
                    .src_a(EXE_src1_a4),
                    .src_b(EXE_src2_a4),
                    .dest(EXE_dest_a4),
                    .reg_a(EXE_reg_a_a4[15:0]),
                    .reg_b(EXE_reg_b_a4[15:0]));

      // ALU
      //_@5
         assign EXE_adj_offset6_a5[15:0] = {{10{EXE_offset6_a5[5]}}, EXE_offset6_a5};
         alu alu(.aluop(EXE_aluop_a5),
                 .a(EXE_reg_a_a5),
                 .b(EXE_valid_mem_instr_a5 ? EXE_adj_offset6_a5 : EXE_reg_b_a5),
                 .f(EXE_rslt_a5[15:0]));

      // Branch target
      //_@5
         assign EXE_cc_a5[2:0] = {EXE_rslt_a5[15], EXE_rslt_a5 == 16'b0, | EXE_rslt_a5[14:0]};
      //_@6
         assign EXE_valid_br_taken_a6 = EXE_instr_valid_a6 && EXE_br_a6 &&
                           EXE_cc_a6 == EXE_dest_a6;  // CCCOMP
         // Cases that go to "fetch 1" after "exe".
         assign EXE_valid_exe_inst_a6 = EXE_instr_valid_a6 && !(EXE_valid_mem_instr_a6 || EXE_valid_br_taken_a6);
         
      // MAR/MDR
      //_@5
         assign EXE_mar_a5[15:0] =
            EXE_valid_mem_instr_a5          ? EXE_rslt_a5 :             // ld/st
            FETCH_instr_valid_a1 ? FETCH_pc_a1 :  // instruction load
                                        EXE_mar_a6[15:0];
         // Note: MDR as spec'ed holds both ld and store data, which gets in the way for
         //       a pipelined design, so I just let load data stage separately.
         assign EXE_mdr_a5[15:0] =
            EXE_valid_st_a5     ? EXE_rslt_a5 :     // st
                            EXE_mdr_a6[15:0];
      // Memory
      //_@6
         assign EXE_fetch_a6 = FETCH_instr_valid_a2;
         // Just return random data for now, 2 cycles later.
         assign EXE_mem_rdata_a6[15:0] = RW_rand_vect[(0 + (0)) % 257 +: 16];
         assign EXE_mem_op_a6 = EXE_valid_mem_instr_a6 || EXE_fetch_a6;
         assign EXE_mem_resp_a6 = EXE_mem_op_a8;
   
   // Handle response from memory, whether fetch, ld, or st.
   //_|resp
      //_@1
         assign RESP_reset_a1 = reset;
      //_@2
         // Remember the purpose of the memory operation: fetch, load, or store.
         assign {RESP_FetchPending_a1,
          RESP_LoadPending_a1,
          RESP_next_store_pending_a2} =
            RESP_reset_a2 || RESP_mem_resp_a2        ? 3'b000 :
            FETCH_instr_valid_a2  ? 3'b100 :
            EXE_valid_ld_a6       ? 3'b010 :
            EXE_valid_st_a7       ? 3'b001 :
                                         {RESP_FetchPending_a2, RESP_LoadPending_a2, RESP_StorePending_a2};  // $RETAIN
         assign RESP_StorePending_a1 = RESP_next_store_pending_a2;
         
      // This pipeline is fed from memory response.
      //_@2
         assign RESP_mem_resp_a2 = EXE_mem_resp_a6;
         assign RESP_mem_rdata_a2[15:0] = EXE_mem_rdata_a6;
         
      // Characterize response.
      //_@3
         assign RESP_ld_resp_valid_a3    = RESP_mem_resp_a3 && RESP_LoadPending_a3;
         //$st_resp_valid    = $mem_resp && $StorePending;
         assign RESP_fetch_resp_valid_a3 = RESP_mem_resp_a3 && RESP_FetchPending_a3;
         
   
   // ---------
   // Testbench
   // ---------
   
   // Just run for fixed number of cycles
   assign L0_reset_a0 = reset;
   assign L0_Cnt_n1[15:0] = L0_reset_a0 ? 16'b0 :
                               L0_Cnt_a0 + 16'b1;
   assign passed = L0_Cnt_a0 > 16'd100;

//_\SV
endmodule




// -------------
// ALU

module alu
(
    input mips_aluop aluop,
    input mips_word a, b,
    output mips_word f
);

always_comb
begin
    case (aluop)
        alu_add: f = a + b;
        alu_and: f = a & b;
        alu_not: f = ~a;
        default: f = f;
    endcase
end

endmodule : alu



// ---------------
// Register File

module regfile
(
    input clk,
    input load,
    input mips_word in,
    input mips_reg src_a, src_b, dest,
    output mips_word reg_a, reg_b
);

mips_word data [7:0];

initial
begin
    for (int i = 0; i < $size(data); i++)
    begin
        data[i] = 16'b0;
    end
end

always_ff @(posedge clk)
begin
    if (load == 1)
    begin
        data[dest] = in;
    end
end

always_comb
begin
    reg_a = data[src_a];
    reg_b = data[src_b];
end

endmodule : regfile


// Undefine macros defined by SandPiper (in "top_gen.sv").
`undef BOGUS_USE
