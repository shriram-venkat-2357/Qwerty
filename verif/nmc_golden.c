/*
 * nmc_golden.c
 * ------------
 * Implementation of the DRAFT golden model. See nmc_golden.h for the
 * documented assumptions this is built on - all marked placeholder
 * until confirmed against the team's frozen algorithm spec.
 */

#include "nmc_golden.h"
#include <string.h>

void nmc_golden_reset(nmc_state_t *st)
{
    memset(st, 0, sizeof(*st));
    st->status = NMC_STATUS_READY;
}

void nmc_golden_ldw(nmc_state_t *st, const uint32_t *weight_words, uint32_t nwords)
{
    if (nwords > NMC_MAX_WORDS) {
        st->status |= NMC_STATUS_ERROR;
        return;
    }
    memcpy(st->weight_words, weight_words, nwords * sizeof(uint32_t));
    st->weight_len = nwords * 32u; /* bits */
    st->status &= ~NMC_STATUS_READY;
    st->status |= NMC_STATUS_BUSY;
    /* Golden model: transfer completes instantly (non-blocking in RTL,
     * modeled here as immediately done since there's no timing model) */
    st->status &= ~NMC_STATUS_BUSY;
    st->status |= NMC_STATUS_DONE | NMC_STATUS_READY;
}

void nmc_golden_lda(nmc_state_t *st, const int8_t *acts, uint32_t nacts)
{
    if (nacts > NMC_MAX_WORDS) {
        st->status |= NMC_STATUS_ERROR;
        return;
    }
    memcpy(st->activations, acts, nacts * sizeof(int8_t));
    st->act_len = nacts;
    st->status &= ~NMC_STATUS_READY;
    st->status |= NMC_STATUS_BUSY;
    st->status &= ~NMC_STATUS_BUSY;
    st->status |= NMC_STATUS_DONE | NMC_STATUS_READY;
}

/* Extract weight bit i (0-indexed) from packed weight_words */
static inline int weight_bit(const nmc_state_t *st, uint32_t i)
{
    uint32_t word = st->weight_words[i / 32u];
    return (word >> (i % 32u)) & 0x1u;
}

void nmc_golden_run(nmc_state_t *st, int32_t threshold, uint32_t n_outputs)
{
    if (n_outputs == 0 || n_outputs > NMC_MAX_OUT || (n_outputs & 1u)) {
        st->status |= NMC_STATUS_ERROR;
        return;
    }
    if (st->weight_len == 0 || st->act_len == 0) {
        st->status |= NMC_STATUS_ERROR;
        return;
    }

    st->status &= ~NMC_STATUS_READY;
    st->status |= NMC_STATUS_BUSY;

    uint32_t window = st->act_len < st->weight_len / 32u ? st->act_len
                                                           : st->weight_len / 32u;
    if (window == 0) window = st->act_len; /* fallback for small inputs */

    /* Stage 1: binary-weight dot product + sign threshold per output neuron */
    for (uint32_t n = 0; n < n_outputs; n++) {
        int32_t acc = 0;
        for (uint32_t i = 0; i < window && i < st->act_len; i++) {
            uint32_t widx = (n + i) % st->weight_len;
            int32_t w = weight_bit(st, widx) ? 1 : -1;
            acc += w * (int32_t)st->activations[i];
        }
        st->acc_out[n] = (acc >= threshold) ? 1 : 0; /* sign/threshold activation */
    }

    /* Stage 2: 2:1 max-pool across adjacent outputs */
    st->result_len = n_outputs / 2u;
    for (uint32_t p = 0; p < st->result_len; p++) {
        int32_t a = st->acc_out[2 * p];
        int32_t b = st->acc_out[2 * p + 1];
        st->result[p] = (a > b) ? a : b;
    }

    st->status &= ~NMC_STATUS_BUSY;
    st->status |= NMC_STATUS_DONE | NMC_STATUS_READY;
}

uint32_t nmc_golden_rd(nmc_state_t *st, uint32_t sel)
{
    if (sel == 0) {
        return st->status;
    }
    uint32_t idx = sel - 1u;
    if (idx >= st->result_len) {
        st->status |= NMC_STATUS_ERROR;
        return 0xFFFFFFFFu;
    }
    return (uint32_t)st->result[idx];
}
