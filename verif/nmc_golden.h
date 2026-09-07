/*
 * nmc_golden.h
 * ------------
 * Bit-accurate C GOLDEN MODEL for the Custom-0 Near-Memory Compute (NMC)
 * accelerator described in docs/Custom-0 ISA Specification (Draft v0.1).
 *
 * STATUS: DRAFT / PLACEHOLDER (v0.1)
 * This models the *interface* behavior exactly as frozen in the ISA spec
 * (nmc.ldw / nmc.lda / nmc.run / nmc.rd + nmc_status CSR). The internal
 * *compute* behavior (what nmc.run mathematically does) was NOT frozen
 * in the spec, so the assumptions below are placeholders based on the
 * repo README ("binary-weight LeNet workload", "128x64 1-bit CiM SRAM
 * array"). CONFIRM / REVISE these assumptions with Shriram (RTL) and
 * Vanmathi (memory/synthesis) before treating this as the reference
 * for RTL-vs-golden comparison.
 *
 * ASSUMPTIONS (flag for team review):
 *   1. Weights are 1-bit, packed 32-per-word, encoding: bit=1 -> +1,
 *      bit=0 -> -1  (standard binary-weight-network encoding).
 *   2. Activations are int8_t, one activation per weight bit, same
 *      packing count (NMC_MAX_LEN words each) for ldw/lda.
 *   3. nmc.run computes, per output neuron n:
 *          acc[n] = sum_i ( (weight_bit_i ? +1 : -1) * activation_i )
 *      over a configurable window length, then applies a threshold
 *      (config value) to produce a binary output bit (sign activation,
 *      the standard BNN nonlinearity), then performs 2:1 max-pooling
 *      across adjacent output neurons.
 *   4. nmc_status CSR bits: bit0=busy, bit1=done, bit2=error, bit3=ready
 *      (order matches spec's listed bit names, LSB-first placeholder).
 */

#ifndef NMC_GOLDEN_H
#define NMC_GOLDEN_H

#include <stdint.h>
#include <stddef.h>

#define NMC_MAX_WORDS   64u   /* placeholder capacity, matches 64-col CiM array */
#define NMC_MAX_OUT     32u   /* placeholder max output neurons before pooling */

/* nmc_status CSR (0x7C0) bit positions - placeholder order, confirm with team */
#define NMC_STATUS_BUSY   (1u << 0)
#define NMC_STATUS_DONE   (1u << 1)
#define NMC_STATUS_ERROR  (1u << 2)
#define NMC_STATUS_READY  (1u << 3)

typedef struct {
    uint32_t weight_words[NMC_MAX_WORDS]; /* packed 1-bit weights */
    uint32_t weight_len;                  /* number of valid weight bits loaded */

    int8_t   activations[NMC_MAX_WORDS];  /* one activation per weight bit */
    uint32_t act_len;                     /* number of valid activations loaded */

    int32_t  acc_out[NMC_MAX_OUT];        /* pre-pool accumulator/sign outputs */
    int32_t  result[NMC_MAX_OUT / 2];     /* post-pool result buffer */
    uint32_t result_len;                  /* number of valid pooled outputs */

    uint32_t status;                      /* mirrors nmc_status CSR (0x7C0) */
} nmc_state_t;

/* Reset all state (equivalent to accelerator power-on / soft reset) */
void nmc_golden_reset(nmc_state_t *st);

/* nmc.ldw: rs1=base address (unused in golden model, data passed directly),
 * rs2=length in words. Here we pass the source buffer directly since the
 * golden model has no separate memory image. */
void nmc_golden_ldw(nmc_state_t *st, const uint32_t *weight_words, uint32_t nwords);

/* nmc.lda: loads activation data (int8 per element) */
void nmc_golden_lda(nmc_state_t *st, const int8_t *acts, uint32_t nacts);

/* nmc.run: rs1=config/selector (here: threshold value), rs2=extra config
 * (here: number of output neurons to compute before pooling, must be even) */
void nmc_golden_run(nmc_state_t *st, int32_t threshold, uint32_t n_outputs);

/* nmc.rd: rd=destination, rs1=select (0 = read status CSR value,
 * 1..N = read pooled result[sel-1]) */
uint32_t nmc_golden_rd(nmc_state_t *st, uint32_t sel);

#endif /* NMC_GOLDEN_H */
