/*
 * tests/program_e2e.S
 * D8 End-to-End CNN Layer Driver
 * 
 * Memory Layout (DMEM):
 *   0x1000 : Weights (512 bytes per 128x32 layer)
 *   0x2000 : Activations (16 bytes per 128-bit vector)
 *   0x3000 : Output Results (4 bytes per layer, for B's golden-diff TB)
 *   0x4000 : Thresholds (128 bytes, for Decision 0002)
 *
 * Custom-0 ISA (opcode 0x0B):
 *   funct3=0: nmc.ldw  rs1=base, rs2=row_count
 *   funct3=1: nmc.lda  rs1=base, rs2=word_count
 *   funct3=2: nmc.run  (executes 1 kernel position)
 *   funct3=3: nmc.rd   rd=result
 *   funct3=4: nmc.cfg  rs1=col_addr, rs2=threshold (Decision 0002)
 *
 * Status CSR (0x7C0):
 *   bit 0: busy, bit 1: done, bit 2: error, bit 3: ready
 */

.section .text
.global _start

/* Constants */
.set CSR_STATUS, 0x7C0
.set OPCODE_CUSTOM0, 0x0B
.set FUNCT3_LDW, 0x0
.set FUNCT3_LDA, 0x1
.set FUNCT3_RUN, 0x2
.set FUNCT3_RD,  0x3
.set FUNCT3_CFG, 0x4

.set BASE_WEIGHTS, 0x1000
.set BASE_ACTS,    0x2000
.set BASE_OUT,     0x3000
.set BASE_THR,     0x4000

_start:
    /* Initialize base pointers */
    li s0, BASE_WEIGHTS
    li s1, BASE_ACTS
    li s2, BASE_OUT
    li s3, BASE_THR

    /* Loop over 10 synthetic layers (adjust as needed for real CNN) */
    li s4, 10

layer_loop:
    beqz s4, end_program

    /* --- 1. Load Weights (128 rows) --- */
    li a1, 128
    mv a0, s0
    .insn r OPCODE_CUSTOM0, FUNCT3_LDW, 0, x0, a0, a1
    call wait_done

    /* --- 2. Load Activations (128 bits = 4 words) --- */
    li a1, 4
    mv a0, s1
    .insn r OPCODE_CUSTOM0, FUNCT3_LDA, 0, x0, a0, a1
    call wait_done

    /* --- 3. Load Thresholds (Decision 0002 Placeholder) --- */
    /* Uncomment when C provides the threshold vector:
    li t0, 32
cfg_loop:
    addi t0, t0, -1
    li t1, 0x0          # rs2 = threshold value (replace with actual load from BASE_THR)
    mv t2, t0           # rs1 = column address
    .insn r OPCODE_CUSTOM0, FUNCT3_CFG, 0, x0, t2, t1
    bnez t0, cfg_loop
    */

    /* --- 4. Execute Conv (9 kernel positions) --- */
    li t0, 9
run_loop:
    .insn r OPCODE_CUSTOM0, FUNCT3_RUN, 0, x0, x0, x0
    call wait_done
    addi t0, t0, -1
    bnez t0, run_loop

    /* --- 5. Read Result --- */
    .insn r OPCODE_CUSTOM0, FUNCT3_RD, 0, a2, x0, x0

    /* Store result to DMEM for B's golden-diff testbench */
    sw a2, 0(s2)

    /* Advance pointers for next layer */
    addi s0, s0, 512   # Next weight block (128 rows * 32 bits = 512 bytes)
    addi s1, s1, 16    # Next act block (128 bits = 16 bytes)
    addi s2, s2, 4     # Next output slot
    addi s4, s4, -1
    j layer_loop

end_program:
    j end_program      # Hang on completion

/* ---------------------------------------------------------
 * wait_done: Polls CSR 0x7C0 until 'done' (bit 1) is set.
 * Traps if 'error' (bit 2) is set.
 * --------------------------------------------------------- */
wait_done:
poll_loop:
    csrr t0, CSR_STATUS
    andi t1, t0, 0x4       # Check error bit
    bnez t1, error_trap
    andi t1, t0, 0x2       # Check done bit
    beqz t1, poll_loop     # Loop if not done
    ret

error_trap:
    j error_trap           # Infinite loop on hardware error
