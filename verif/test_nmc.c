/*
 * test_nmc.c
 * ----------
 * Verification tests for the Custom-0 NMC accelerator.
 *
 * Two modes, selected automatically by the __riscv macro:
 *
 *   HOST (x86, e.g. `gcc test_nmc.c nmc_golden.c -o test_nmc`):
 *     Runs the golden model standalone against hand-picked inputs and
 *     checks its output against hand-calculated expected values. This
 *     validates the golden model's own arithmetic before it's trusted
 *     as a reference.
 *
 *   TARGET (riscv32-unknown-elf-gcc, run on RTL sim / ISS / hardware):
 *     Runs BOTH the real driver (nmc_driver.h, issues actual custom-0
 *     instructions to rtl/core's nmc_unit) and the golden model on the
 *     identical input data, then compares results bit-for-bit. This is
 *     the actual RTL-vs-golden verification step.
 *
 * NOTE: nmc_unit RTL does not exist in the repo yet (only decoder, ALU,
 * pipeline, regfile, etc. were found under rtl/core). The TARGET path
 * below is written and ready, but cannot be exercised until Shriram
 * adds an nmc_unit module and wires the custom-0 opcode into the
 * decoder/control_unit.
 */

#include <stdio.h>
#include <stdint.h>
#include "nmc_golden.h"

#if defined(__riscv)
#include "nmc_driver.h"
#endif

static int g_fail_count = 0;

static void check(const char *name, uint32_t actual, uint32_t expected)
{
    if (actual == expected) {
        printf("PASS: %s (got 0x%08x)\n", name, actual);
    } else {
        printf("FAIL: %s -- got 0x%08x, expected 0x%08x\n", name, actual, expected);
        g_fail_count++;
    }
}

int main(void)
{
    nmc_state_t st;
    nmc_golden_reset(&st);

    /* --- Test 1: all-positive weights, positive activations, low threshold
     *     -> every neuron should fire (output = 1), pooled result also 1 */
    uint32_t weights_all1[1] = { 0xFFFFFFFFu }; /* 32 weight bits, all = +1 */
    int8_t   acts_pos[4]     = { 5, 5, 5, 5 };

    nmc_golden_ldw(&st, weights_all1, 1);
    nmc_golden_lda(&st, acts_pos, 4);
    nmc_golden_run(&st, /*threshold=*/1, /*n_outputs=*/4);

    for (uint32_t i = 0; i < 2; i++) {
        char label[32];
        snprintf(label, sizeof(label), "test1 result[%u] == 1", i);
        check(label, nmc_golden_rd(&st, i + 1), 1);
    }
    check("test1 status DONE|READY set",
          nmc_golden_rd(&st, 0) & (NMC_STATUS_DONE | NMC_STATUS_READY),
          NMC_STATUS_DONE | NMC_STATUS_READY);

    /* --- Test 2: all-negative weights (bit=0 -> -1), positive activations,
     *     low threshold -> every neuron should NOT fire (output = 0) */
    nmc_golden_reset(&st);
    uint32_t weights_all0[1] = { 0x00000000u };
    nmc_golden_ldw(&st, weights_all0, 1);
    nmc_golden_lda(&st, acts_pos, 4);
    nmc_golden_run(&st, /*threshold=*/1, /*n_outputs=*/4);

    for (uint32_t i = 0; i < 2; i++) {
        char label[32];
        snprintf(label, sizeof(label), "test2 result[%u] == 0", i);
        check(label, nmc_golden_rd(&st, i + 1), 0);
    }

    /* --- Test 3: error path -- nmc.run called before any lda/ldw should
     *     set the ERROR status bit */
    nmc_golden_reset(&st);
    nmc_golden_run(&st, 0, 2);
    check("test3 ERROR bit set on run-before-load",
          nmc_golden_rd(&st, 0) & NMC_STATUS_ERROR, NMC_STATUS_ERROR);

#if defined(__riscv)
    /* --- Test 4 (TARGET ONLY): compare real driver/RTL output against
     *     golden model on identical inputs. Requires nmc_unit RTL to
     *     exist and be wired up -- currently a placeholder call. */
    nmc_golden_reset(&st);
    nmc_golden_ldw(&st, weights_all1, 1);
    nmc_golden_lda(&st, acts_pos, 4);
    nmc_golden_run(&st, 1, 4);
    uint32_t golden_r1 = nmc_golden_rd(&st, 1);

    nmc_ldw((uint32_t)weights_all1, 1);
    nmc_lda((uint32_t)acts_pos, 4);
    nmc_run(1, 4);
    uint32_t rtl_r1 = nmc_rd(1);

    check("test4 RTL result[0] matches golden", rtl_r1, golden_r1);
#endif

    printf("\n=== %s ===\n", g_fail_count == 0 ? "ALL TESTS PASSED" : "SOME TESTS FAILED");
    return g_fail_count == 0 ? 0 : 1;
}
