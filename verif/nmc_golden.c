#include "nmc_golden.h"

void nmc_compute_column(uint32_t *w, uint32_t *act, int shift_amt, int thr, int clr, int *acc, int *out_act) {
    int pc = 0;
    for(int i = 0; i < 4; i++) {
        uint32_t xnor_val = ~(w[i] ^ act[i]);
        pc += __builtin_popcount(xnor_val); 
    }
    int dot = (2 * pc) - 128;
    int scaled = dot << shift_amt;
    *acc = clr ? scaled : (*acc + scaled);
    *out_act = (*acc >= thr) ? 1 : 0;
}

int nmc_pool(int p0, int p1, int p2, int p3) {
    return (p0 | p1 | p2 | p3);
}
