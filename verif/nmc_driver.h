/*
 * nmc_driver.h
 * ------------
 * Bare-metal C driver for the Custom-0 NMC accelerator instructions,
 * per docs/Custom-0 ISA Specification (Draft v0.1, opcode 0x0B / 0001011).
 *
 * Uses RV32's `.insn r` inline-assembly directive to emit the exact
 * R-type encoding without needing toolchain/binutils support for the
 * custom mnemonics. This ONLY assembles/runs correctly when compiled
 * for a bare-metal RV32IM(Zicsr) target (e.g. riscv32-unknown-elf-gcc)
 * and executed on real hardware or an RTL/ISS simulator - it will not
 * run on this x86 dev machine.
 *
 * .insn r syntax:  .insn r opcode, funct3, funct7, rd, rs1, rs2
 */

#ifndef NMC_DRIVER_H
#define NMC_DRIVER_H

#include <stdint.h>

#define NMC_OPCODE 0x0B   /* custom-0, binary 0001011 */
#define NMC_STATUS_CSR 0x7C0

#if defined(__riscv)

static inline uint32_t nmc_ldw(uint32_t base_addr, uint32_t nwords)
{
    uint32_t rd;
    __asm__ volatile (
        ".insn r %3, 0, 0, %0, %1, %2\n"
        : "=r"(rd)
        : "r"(base_addr), "r"(nwords), "i"(NMC_OPCODE)
    );
    return rd;
}

static inline uint32_t nmc_lda(uint32_t base_addr, uint32_t nwords)
{
    uint32_t rd;
    __asm__ volatile (
        ".insn r %3, 1, 0, %0, %1, %2\n"
        : "=r"(rd)
        : "r"(base_addr), "r"(nwords), "i"(NMC_OPCODE)
    );
    return rd;
}

static inline uint32_t nmc_run(uint32_t cfg_selector, uint32_t cfg_value)
{
    uint32_t rd;
    __asm__ volatile (
        ".insn r %3, 2, 0, %0, %1, %2\n"
        : "=r"(rd)
        : "r"(cfg_selector), "r"(cfg_value), "i"(NMC_OPCODE)
    );
    return rd;
}

static inline uint32_t nmc_rd(uint32_t sel)
{
    uint32_t rd;
    __asm__ volatile (
        ".insn r %2, 3, 0, %0, %1, x0\n"
        : "=r"(rd)
        : "r"(sel), "i"(NMC_OPCODE)
    );
    return rd;
}

static inline uint32_t nmc_read_status_csr(void)
{
    uint32_t val;
    __asm__ volatile ("csrr %0, 0x7C0" : "=r"(val));
    return val;
}

#else /* !__riscv : stub so this header/tooling can still be reviewed/built on x86 */

static inline uint32_t nmc_ldw(uint32_t base_addr, uint32_t nwords)
{ (void)base_addr; (void)nwords; return 0; }
static inline uint32_t nmc_lda(uint32_t base_addr, uint32_t nwords)
{ (void)base_addr; (void)nwords; return 0; }
static inline uint32_t nmc_run(uint32_t cfg_selector, uint32_t cfg_value)
{ (void)cfg_selector; (void)cfg_value; return 0; }
static inline uint32_t nmc_rd(uint32_t sel)
{ (void)sel; return 0; }
static inline uint32_t nmc_read_status_csr(void) { return 0; }

#endif /* __riscv */

#endif /* NMC_DRIVER_H */
