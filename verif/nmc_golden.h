#ifndef NMC_GOLDEN_H
#define NMC_GOLDEN_H
#include 

void nmc_compute_column(uint32_t *w, uint32_t *act, int shift_amt, int thr, int clr, int *acc, int *out_act);
int nmc_pool(int p0, int p1, int p2, int p3);

#endif
