/* SPDX-License-Identifier: MIT
 * Packed layouts and block arithmetic follow GGML and the MIT KNC kernels.
 * Reuse one aligned Q8 block across a row tile; never expand model weights. */
#include "knc-mq.h"
#include <string.h>
#include <stdlib.h>

#if !defined(__k1om__) && !defined(GGML_KNC_TEST_EMULATION)
#    error Native K1OM required; host semantics must be explicitly enabled
#endif

#define DECLARE_BLOCK(q)                                                                                        \
    extern void ggml_knc_q##q##_block_native(const uint8_t *, const uint8_t *, const int8_t *, const int32_t *, \
                                             const uint8_t *, const uint8_t *, size_t, int32_t *)
DECLARE_BLOCK(3);
DECLARE_BLOCK(4);
DECLARE_BLOCK(5);
DECLARE_BLOCK(6);

struct ggml_knc_mq_scratch {
    uint8_t low[128] __attribute__((aligned(64)));
    uint8_t high[64] __attribute__((aligned(64)));
    int8_t  y[256] __attribute__((aligned(64)));
    int32_t scales[16] __attribute__((aligned(64)));
    int32_t lanes[16] __attribute__((aligned(64)));
    int32_t bsums[16];
    float   yd;
};

/* Read-only table preserves every binary16 payload without initialization. */
static const uint32_t knc_half_bits[65536] __attribute__((aligned(64))) = {
#include "half-table.inc"
};
static inline __attribute__((always_inline)) float load_half(const uint8_t * p) {
    const uint32_t h = p[0] | ((uint32_t) p[1] << 8);
    const uint32_t bits = knc_half_bits[h];
    float value;
    memcpy(&value, &bits, sizeof(value));
    return value;
}

static void stage_activation(struct ggml_knc_mq_scratch * s, const uint8_t * y) {
    uint32_t bits;
    memcpy(s->y, y + 4, sizeof(s->y));
    for (int j = 0; j < 16; ++j) {
        const uint32_t v = y[260 + 2 * j] | ((uint32_t) y[261 + 2 * j] << 8);
        s->bsums[j]      = v < 32768 ? (int32_t) v : (int32_t) v - 65536;
    }
#ifdef __k1om__
    /* GCC 5 can turn memcpy into an alignment-requiring VBROADCASTSS. */
    __asm__("movl %1, %0" : "=r"(bits) : "m"(*(const unsigned char(*)[4]) y));
#else
    memcpy(&bits, y, sizeof(bits));
#endif
    memcpy(&s->yd, &bits, sizeof(bits));
#ifdef GGML_KNC_MQ_TEST_STAGING
    extern void ggml_knc_mq_test_staged(void);
    ggml_knc_mq_test_staged();
#endif
}

static int32_t reduce(const struct ggml_knc_mq_scratch * s) {
    return s->lanes[0] + s->lanes[1] + s->lanes[2] + s->lanes[3] + s->lanes[4] + s->lanes[5] + s->lanes[6] + s->lanes[7] + s->lanes[8] + s->lanes[9] + s->lanes[10] + s->lanes[11] + s->lanes[12] + s->lanes[13] + s->lanes[14] + s->lanes[15];
}

/* KNC scalar metadata uses x87. Preserve its extended block expression until
 * the float row accumulator is updated; a float function return rounds early. */
static inline long double block_q3(struct ggml_knc_mq_scratch * s,
                                   const uint8_t *              x,
                                   const uint8_t *              y,
                                   size_t                       remaining) {
    memcpy(s->low, x + 32, 64);
    memcpy(s->high, x, 32);
    for (int j = 0; j < 16; ++j) {
        s->scales[j] = (((x[96 + j % 8] >> (j / 8 * 4)) & 15) | (((x[104 + j % 4] >> (j / 4 * 2)) & 3) << 4)) - 32;
    }
    ggml_knc_q3_block_native(s->low, s->high, s->y, s->scales, x, y, remaining, s->lanes);
    return ((long double) load_half(x + 108) * s->yd) * reduce(s);
}

static inline long double block_q4(struct ggml_knc_mq_scratch * s,
                                   const uint8_t *              x,
                                   const uint8_t *              y,
                                   size_t                       remaining) {
    int32_t correction = 0;
    memcpy(s->low, x + 16, 128);
    for (int j = 0; j < 4; ++j) {
        const int s0 = x[4 + j] & 63;
        const int m0 = x[8 + j] & 63;
        const int s1 = (x[12 + j] & 15) | ((x[4 + j] >> 6) << 4);
        const int m1 = (x[12 + j] >> 4) | ((x[8 + j] >> 6) << 4);
        s->scales[2*j] = s->scales[2*j+1] = s0;
        s->scales[2*j+8] = s->scales[2*j+9] = s1;
        correction += m0 * (s->bsums[2*j] + s->bsums[2*j+1]);
        correction += m1 * (s->bsums[2*j+8] + s->bsums[2*j+9]);
    }
    ggml_knc_q4_block_native(s->low, s->high, s->y, s->scales, x, y, remaining, s->lanes);
    return ((long double) load_half(x) * s->yd) * reduce(s) - ((long double) load_half(x + 2) * s->yd) * correction;
}

static inline long double block_q5(struct ggml_knc_mq_scratch * s,
                                   const uint8_t *              x,
                                   const uint8_t *              y,
                                   size_t                       remaining) {
    int32_t correction = 0;
    memcpy(s->low, x + 48, 128);
    memcpy(s->high, x + 16, 32);
    for (int j = 0; j < 4; ++j) {
        const int s0 = x[4 + j] & 63;
        const int m0 = x[8 + j] & 63;
        const int s1 = (x[12 + j] & 15) | ((x[4 + j] >> 6) << 4);
        const int m1 = (x[12 + j] >> 4) | ((x[8 + j] >> 6) << 4);
        s->scales[j] = s0;
        s->scales[j+4] = s1;
        correction += m0 * (s->bsums[2*j] + s->bsums[2*j+1]);
        correction += m1 * (s->bsums[2*j+8] + s->bsums[2*j+9]);
    }
    ggml_knc_q5_block_native(s->low, s->high, s->y, s->scales, x, y, remaining, s->lanes);
    /* The established Q5 glue uses x87 extended products and rounds only
     * after adding a complete block to its float accumulator. Rounding a
     * returned block to float first changes later Q8 quantization decisions.
     * Keep that native instruction order explicitly, without fast-math. */
    return ((long double) reduce(s) * s->yd) * load_half(x) - ((long double) correction * s->yd) * load_half(x + 2);
}

static inline long double block_q6(struct ggml_knc_mq_scratch * s,
                                   const uint8_t *              x,
                                   const uint8_t *              y,
                                   size_t                       remaining) {
    memcpy(s->low, x, 128);
    memcpy(s->high, x + 128, 64);
    for (int j = 0; j < 16; ++j) {
        s->scales[j] = x[192 + j] < 128 ? x[192 + j] : (int) x[192 + j] - 256;
    }
    ggml_knc_q6_block_native(s->low, s->high, s->y, s->scales, x, y, remaining, s->lanes);
    return ((long double) load_half(x + 208) * s->yd) * reduce(s);
}

#define DEFINE_TILE(q, stride)                                                                         \
    static void tile_q##q(size_t blocks, size_t rows, const uint8_t * weights, size_t row_stride,      \
                          const uint8_t * activations, float * out) {                                  \
        struct ggml_knc_mq_scratch scratch;                                                            \
        float                      sums[GGML_KNC_MQ_MAX_ROWS] = { 0 };                                 \
        for (size_t b = 0; b < blocks; ++b) {                                                          \
            const uint8_t * y = activations + b * 292;                                                 \
            stage_activation(&scratch, y);                                                             \
            for (size_t r = 0; r < rows; ++r) {                                                        \
                sums[r] += block_q##q(&scratch, weights + r * row_stride + b * stride, y, blocks - b); \
            }                                                                                          \
        }                                                                                              \
        for (size_t r = 0; r < rows; ++r) {                                                            \
            out[r] = sums[r];                                                                          \
        }                                                                                              \
    }
DEFINE_TILE(3, 110)
DEFINE_TILE(4, 144)
DEFINE_TILE(5, 176)
DEFINE_TILE(6, 210)

/* Assembly offsets are checked against the C ABI, never guessed at runtime. */
_Static_assert(offsetof(struct ggml_knc_mq_scratch, high) == 128, "pair high ABI");
_Static_assert(offsetof(struct ggml_knc_mq_scratch, scales) == 448, "pair scale ABI");
_Static_assert(offsetof(struct ggml_knc_mq_scratch, lanes) == 512, "pair output ABI");
extern void ggml_knc_q3_pair_native(struct ggml_knc_mq_scratch *, struct ggml_knc_mq_scratch *, const int8_t *, const uint8_t *, const uint8_t *, const uint8_t *, size_t);
static inline int32_t pair_stage_q3(struct ggml_knc_mq_scratch *s, const uint8_t *x) {

    memcpy(s->low, x + 32, 64);
    memcpy(s->high, x, 32);
    for (int j = 0; j < 16; ++j) {
        s->scales[j] = (((x[96 + j % 8] >> (j / 8 * 4)) & 15) | (((x[104 + j % 4] >> (j / 4 * 2)) & 3) << 4)) - 32;
    }

    return 0;
}
static inline long double pair_finish_q3(const struct ggml_knc_mq_scratch *s, const uint8_t *x, int32_t correction) {
    (void)correction;
    return ((long double) load_half(x + 108) * s->yd) * s->lanes[0];
}
extern void ggml_knc_q4_pair_native(struct ggml_knc_mq_scratch *, struct ggml_knc_mq_scratch *, const int8_t *, const uint8_t *, const uint8_t *, const uint8_t *, size_t);
static inline int32_t pair_stage_q4(struct ggml_knc_mq_scratch *s, const uint8_t *x) {

    int32_t correction = 0;
    memcpy(s->low, x + 16, 128);
    for (int j = 0; j < 4; ++j) {
        const int s0 = x[4 + j] & 63;
        const int m0 = x[8 + j] & 63;
        const int s1 = (x[12 + j] & 15) | ((x[4 + j] >> 6) << 4);
        const int m1 = (x[12 + j] >> 4) | ((x[8 + j] >> 6) << 4);
        s->scales[2*j] = s->scales[2*j+1] = s0;
        s->scales[2*j+8] = s->scales[2*j+9] = s1;
        correction += m0 * (s->bsums[2*j] + s->bsums[2*j+1]);
        correction += m1 * (s->bsums[2*j+8] + s->bsums[2*j+9]);
    }

    return correction;
}
static inline long double pair_finish_q4(const struct ggml_knc_mq_scratch *s, const uint8_t *x, int32_t correction) {
    (void)correction;
    return ((long double) load_half(x) * s->yd) * s->lanes[0] - ((long double) load_half(x + 2) * s->yd) * correction;
}
extern void ggml_knc_q5_pair_native(struct ggml_knc_mq_scratch *, struct ggml_knc_mq_scratch *, const int8_t *, const uint8_t *, const uint8_t *, const uint8_t *, size_t);
static inline int32_t pair_stage_q5(struct ggml_knc_mq_scratch *s, const uint8_t *x) {

    int32_t correction = 0;
    memcpy(s->low, x + 48, 128);
    memcpy(s->high, x + 16, 32);
    for (int j = 0; j < 4; ++j) {
        const int s0 = x[4 + j] & 63;
        const int m0 = x[8 + j] & 63;
        const int s1 = (x[12 + j] & 15) | ((x[4 + j] >> 6) << 4);
        const int m1 = (x[12 + j] >> 4) | ((x[8 + j] >> 6) << 4);
        s->scales[j] = s0;
        s->scales[j+4] = s1;
        correction += m0 * (s->bsums[2*j] + s->bsums[2*j+1]);
        correction += m1 * (s->bsums[2*j+8] + s->bsums[2*j+9]);
    }

    return correction;
}
static inline long double pair_finish_q5(const struct ggml_knc_mq_scratch *s, const uint8_t *x, int32_t correction) {
    (void)correction;
    return ((long double) s->lanes[0] * s->yd) * load_half(x) - ((long double) correction * s->yd) * load_half(x + 2);
}
extern void ggml_knc_q6_pair_native(struct ggml_knc_mq_scratch *, struct ggml_knc_mq_scratch *, const int8_t *, const uint8_t *, const uint8_t *, const uint8_t *, size_t);
static inline int32_t pair_stage_q6(struct ggml_knc_mq_scratch *s, const uint8_t *x) {

    memcpy(s->low, x, 128);
    memcpy(s->high, x + 128, 64);
    for (int j = 0; j < 16; ++j) {
        s->scales[j] = x[192 + j] < 128 ? x[192 + j] : (int) x[192 + j] - 256;
    }

    return 0;
}
static inline long double pair_finish_q6(const struct ggml_knc_mq_scratch *s, const uint8_t *x, int32_t correction) {
    (void)correction;
    return ((long double) load_half(x + 208) * s->yd) * s->lanes[0];
}
static void pair_tile_q3(size_t blocks, size_t rows, const uint8_t *weights, size_t row_stride,
                                      const uint8_t *activations, float *out) {
    struct ggml_knc_mq_scratch scratch[2];
    float sums[GGML_KNC_MQ_MAX_ROWS] = {0};
    for (size_t b=0; b<blocks; ++b) {
        const uint8_t *y=activations+b*292;
        stage_activation(&scratch[0],y);
        scratch[1].yd=scratch[0].yd;
        memcpy(scratch[1].bsums,scratch[0].bsums,sizeof(scratch[0].bsums));
        size_t r=0;
        for (; r+1<rows; r+=2) {
            const uint8_t *x0=weights+r*row_stride+b*110, *x1=x0+row_stride;
            const int32_t c0=pair_stage_q3(&scratch[0],x0), c1=pair_stage_q3(&scratch[1],x1);
            ggml_knc_q3_pair_native(&scratch[0],&scratch[1],scratch[0].y,x0,x1,y,blocks-b);
            sums[r] += pair_finish_q3(&scratch[0],x0,c0);
            sums[r+1] += pair_finish_q3(&scratch[1],x1,c1);
        }
        if (r<rows) sums[r] += block_q3(&scratch[0],weights+r*row_stride+b*110,y,blocks-b);
    }
    for (size_t r=0; r<rows; ++r) out[r]=sums[r];
}
static void pair_tile_q4(size_t blocks, size_t rows, const uint8_t *weights, size_t row_stride,
                                      const uint8_t *activations, float *out) {
    struct ggml_knc_mq_scratch scratch[2];
    float sums[GGML_KNC_MQ_MAX_ROWS] = {0};
    for (size_t b=0; b<blocks; ++b) {
        const uint8_t *y=activations+b*292;
        stage_activation(&scratch[0],y);
        scratch[1].yd=scratch[0].yd;
        memcpy(scratch[1].bsums,scratch[0].bsums,sizeof(scratch[0].bsums));
        size_t r=0;
        for (; r+1<rows; r+=2) {
            const uint8_t *x0=weights+r*row_stride+b*144, *x1=x0+row_stride;
            const int32_t c0=pair_stage_q4(&scratch[0],x0), c1=pair_stage_q4(&scratch[1],x1);
            ggml_knc_q4_pair_native(&scratch[0],&scratch[1],scratch[0].y,x0,x1,y,blocks-b);
            sums[r] += pair_finish_q4(&scratch[0],x0,c0);
            sums[r+1] += pair_finish_q4(&scratch[1],x1,c1);
        }
        if (r<rows) sums[r] += block_q4(&scratch[0],weights+r*row_stride+b*144,y,blocks-b);
    }
    for (size_t r=0; r<rows; ++r) out[r]=sums[r];
}
static void pair_tile_q5(size_t blocks, size_t rows, const uint8_t *weights, size_t row_stride,
                                      const uint8_t *activations, float *out) {
    struct ggml_knc_mq_scratch scratch[2];
    float sums[GGML_KNC_MQ_MAX_ROWS] = {0};
    for (size_t b=0; b<blocks; ++b) {
        const uint8_t *y=activations+b*292;
        stage_activation(&scratch[0],y);
        scratch[1].yd=scratch[0].yd;
        memcpy(scratch[1].bsums,scratch[0].bsums,sizeof(scratch[0].bsums));
        size_t r=0;
        for (; r+1<rows; r+=2) {
            const uint8_t *x0=weights+r*row_stride+b*176, *x1=x0+row_stride;
            const int32_t c0=pair_stage_q5(&scratch[0],x0), c1=pair_stage_q5(&scratch[1],x1);
            ggml_knc_q5_pair_native(&scratch[0],&scratch[1],scratch[0].y,x0,x1,y,blocks-b);
            sums[r] += pair_finish_q5(&scratch[0],x0,c0);
            sums[r+1] += pair_finish_q5(&scratch[1],x1,c1);
        }
        if (r<rows) sums[r] += block_q5(&scratch[0],weights+r*row_stride+b*176,y,blocks-b);
    }
    for (size_t r=0; r<rows; ++r) out[r]=sums[r];
}
static void pair_tile_q6(size_t blocks, size_t rows, const uint8_t *weights, size_t row_stride,
                                      const uint8_t *activations, float *out) {
    struct ggml_knc_mq_scratch scratch[2];
    float sums[GGML_KNC_MQ_MAX_ROWS] = {0};
    for (size_t b=0; b<blocks; ++b) {
        const uint8_t *y=activations+b*292;
        stage_activation(&scratch[0],y);
        scratch[1].yd=scratch[0].yd;
        memcpy(scratch[1].bsums,scratch[0].bsums,sizeof(scratch[0].bsums));
        size_t r=0;
        for (; r+1<rows; r+=2) {
            const uint8_t *x0=weights+r*row_stride+b*210, *x1=x0+row_stride;
            const int32_t c0=pair_stage_q6(&scratch[0],x0), c1=pair_stage_q6(&scratch[1],x1);
            ggml_knc_q6_pair_native(&scratch[0],&scratch[1],scratch[0].y,x0,x1,y,blocks-b);
            sums[r] += pair_finish_q6(&scratch[0],x0,c0);
            sums[r+1] += pair_finish_q6(&scratch[1],x1,c1);
        }
        if (r<rows) sums[r] += block_q6(&scratch[0],weights+r*row_stride+b*210,y,blocks-b);
    }
    for (size_t r=0; r<rows; ++r) out[r]=sums[r];
}
ggml_knc_mq_tile_fn ggml_knc_mq_kernel(int bits) {
    switch (bits) {
        case 3:
            return getenv("GGML_KNC_TEXT_PAIR") && !strcmp(getenv("GGML_KNC_TEXT_PAIR"),"1") ? pair_tile_q3 : tile_q3;
        case 4:
            return getenv("GGML_KNC_TEXT_PAIR") && !strcmp(getenv("GGML_KNC_TEXT_PAIR"),"1") ? pair_tile_q4 : tile_q4;
        case 5:
            return getenv("GGML_KNC_TEXT_PAIR") && !strcmp(getenv("GGML_KNC_TEXT_PAIR"),"1") ? pair_tile_q5 : tile_q5;
        case 6:
            return getenv("GGML_KNC_TEXT_PAIR") && !strcmp(getenv("GGML_KNC_TEXT_PAIR"),"1") ? pair_tile_q6 : tile_q6;
        default:
            return NULL;
    }
}

typedef void (*panel_block_fn)(const uint8_t *, const uint8_t *, const int8_t *, const int32_t *,
                                int32_t *, const uint8_t *, size_t);
#define DECLARE_PANEL(q) \
    extern void ggml_knc_q##q##_panel_native(const uint8_t *, const uint8_t *, const int8_t *, const int32_t *, \
                                            int32_t *, const uint8_t *, size_t)
DECLARE_PANEL(3);
DECLARE_PANEL(4);
DECLARE_PANEL(5);
DECLARE_PANEL(6);

void ggml_knc_mq_panel(int bits, size_t blocks, size_t rows, const uint8_t * weights, size_t row_stride,
                       const uint8_t * activations, size_t col_stride, float * out, size_t out_stride) {
    struct ggml_knc_mq_scratch scratch;
    int8_t y[4][256] __attribute__((aligned(64)));
    int32_t lanes[4][16] __attribute__((aligned(64)));
    int32_t bsums[4][16];
    float yd[4], sums[4][GGML_KNC_MQ_MAX_ROWS] = {{0}};
    panel_block_fn fn = bits == 3 ? ggml_knc_q3_panel_native : bits == 4 ? ggml_knc_q4_panel_native :
                        bits == 5 ? ggml_knc_q5_panel_native : ggml_knc_q6_panel_native;
    const size_t stride = bits == 3 ? 110 : bits == 4 ? 144 : bits == 5 ? 176 : 210;
    for (size_t b = 0; b < blocks; ++b) {
        for (int c = 0; c < 4; ++c) {
            stage_activation(&scratch, activations + c * col_stride + b * 292);
            memcpy(y[c], scratch.y, sizeof(y[c]));
            memcpy(bsums[c], scratch.bsums, sizeof(bsums[c]));
            yd[c] = scratch.yd;
        }
        for (size_t r = 0; r < rows; ++r) {
            const uint8_t * x = weights + r * row_stride + b * stride;
            int32_t mins[8] = {0};
            float d, dmin = 0;
            if (bits == 3) {
                memcpy(scratch.low, x + 32, 64);
                memcpy(scratch.high, x, 32);
                for (int j = 0; j < 16; ++j) {
                    scratch.scales[j] = (((x[96 + j%8] >> (j/8*4)) & 15) |
                                         (((x[104 + j%4] >> (j/4*2)) & 3) << 4)) - 32;
                }
                d = load_half(x + 108);
            } else if (bits == 6) {
                memcpy(scratch.low, x, 128);
                memcpy(scratch.high, x + 128, 64);
                for (int j = 0; j < 16; ++j) {
                    scratch.scales[j] = x[192+j] < 128 ? x[192+j] : (int)x[192+j] - 256;
                }
                d = load_half(x + 208);
            } else {
                memcpy(scratch.low, x + (bits == 4 ? 16 : 48), 128);
                if (bits == 5) { memcpy(scratch.high, x + 16, 32); }
                for (int j = 0; j < 8; ++j) {
                    const int sc = j < 4 ? x[4+j] & 63 : (x[8+j] & 15) | ((x[j] >> 6) << 4);
                    mins[j] = j < 4 ? x[8+j] & 63 : (x[8+j] >> 4) | ((x[4+j] >> 6) << 4);
                    if (bits == 5) { scratch.scales[j] = sc; }
                    else { scratch.scales[2*j] = scratch.scales[2*j+1] = sc; }
                }
                d = load_half(x);
                dmin = load_half(x + 2);
            }
            fn(scratch.low, scratch.high, &y[0][0], scratch.scales, &lanes[0][0], x, blocks - b);
            for (int c = 0; c < 4; ++c) {
                int32_t dot = 0, correction = 0;
                for (int j = 0; j < 16; ++j) { dot += lanes[c][j]; }
                if (bits == 4 || bits == 5) {
                    for (int j = 0; j < 8; ++j) { correction += mins[j] * (bsums[c][2*j] + bsums[c][2*j+1]); }
                }
                /* Preserve the established per-block x87 expression and float store. */
                if (bits == 5) {
                    sums[c][r] += ((long double) dot * yd[c]) * d - ((long double) correction * yd[c]) * dmin;
                } else if (bits == 4) {
                    sums[c][r] += ((long double) d * yd[c]) * dot - ((long double) dmin * yd[c]) * correction;
                } else {
                    sums[c][r] += ((long double) d * yd[c]) * dot;
                }
            }
        }
    }
    for (int c = 0; c < 4; ++c) {
        for (size_t r = 0; r < rows; ++r) { out[c * out_stride + r] = sums[c][r]; }
    }
}

extern void ggml_knc_q6_panel8_native(const uint8_t *, const uint8_t *, const int8_t *, const int32_t *, int32_t *, const uint8_t *, size_t);
void ggml_knc_mq_panel8(size_t blocks, size_t rows, const uint8_t *weights, size_t row_stride,
                       const uint8_t *activations, size_t col_stride, float *out, size_t out_stride) {
    struct ggml_knc_mq_scratch scratch;
    int8_t y[8][256] __attribute__((aligned(64)));
    int32_t lanes[8][16] __attribute__((aligned(64)));
    float yd[8], sums[8][GGML_KNC_MQ_MAX_ROWS]={{0}};
    for (size_t b=0; b<blocks; ++b) {
        for (int c=0; c<8; ++c) {
            stage_activation(&scratch,activations+c*col_stride+b*292);
            memcpy(y[c],scratch.y,sizeof(y[c])); yd[c]=scratch.yd;
        }
        for (size_t r=0; r<rows; ++r) {
            const uint8_t *x=weights+r*row_stride+b*210;
            memcpy(scratch.low,x,128); memcpy(scratch.high,x+128,64);
            for (int j=0;j<16;++j) scratch.scales[j]=x[192+j]<128 ? x[192+j] : (int)x[192+j]-256;
            const float d=load_half(x+208);
            ggml_knc_q6_panel8_native(scratch.low,scratch.high,&y[0][0],scratch.scales,&lanes[0][0],x,blocks-b);
            for (int c=0;c<8;++c) {
                int32_t dot=0;
                for (int j=0;j<16;++j) dot+=lanes[c][j];
                sums[c][r] += ((long double)d * yd[c]) * dot;
            }
        }
    }
    for (int c=0;c<8;++c) for (size_t r=0;r<rows;++r) out[c*out_stride+r]=sums[c][r];
}

extern void ggml_knc_q6_panel16_native(const uint8_t *, const uint8_t *, const int8_t *, const int32_t *, int32_t *, const uint8_t *, size_t);
void ggml_knc_mq_panel16(size_t blocks, size_t rows, const uint8_t *weights, size_t row_stride,
                       const uint8_t *activations, size_t col_stride, float *out, size_t out_stride) {
    struct ggml_knc_mq_scratch scratch;
    int8_t y[16][256] __attribute__((aligned(64)));
    int32_t lanes[16][16] __attribute__((aligned(64)));
    float yd[16], sums[16][GGML_KNC_MQ_MAX_ROWS]={{0}};
    for (size_t b=0; b<blocks; ++b) {
        for (int c=0; c<16; ++c) {
            stage_activation(&scratch,activations+c*col_stride+b*292);
            memcpy(y[c],scratch.y,sizeof(y[c])); yd[c]=scratch.yd;
        }
        for (size_t r=0; r<rows; ++r) {
            const uint8_t *x=weights+r*row_stride+b*210;
            memcpy(scratch.low,x,128); memcpy(scratch.high,x+128,64);
            for (int j=0;j<16;++j) scratch.scales[j]=x[192+j]<128 ? x[192+j] : (int)x[192+j]-256;
            const float d=load_half(x+208);
            ggml_knc_q6_panel16_native(scratch.low,scratch.high,&y[0][0],scratch.scales,&lanes[0][0],x,blocks-b);
            for (int c=0;c<16;++c) {
                int32_t dot=0;
                for (int j=0;j<16;++j) dot+=lanes[c][j];
                sums[c][r] += ((long double)d * yd[c]) * dot;
            }
        }
    }
    for (int c=0;c<16;++c) for (size_t r=0;r<rows;++r) out[c*out_stride+r]=sums[c][r];
}

extern void ggml_knc_q3_wide_native(const uint8_t*,const uint8_t*,const int8_t*,const int32_t*,int32_t*,const uint8_t*,size_t);
extern void ggml_knc_q4_wide_native(const uint8_t*,const uint8_t*,const int8_t*,const int32_t*,int32_t*,const uint8_t*,size_t);
extern void ggml_knc_q5_wide_native(const uint8_t*,const uint8_t*,const int8_t*,const int32_t*,int32_t*,const uint8_t*,size_t);
extern void ggml_knc_q6_wide_native(const uint8_t*,const uint8_t*,const int8_t*,const int32_t*,int32_t*,const uint8_t*,size_t);
void ggml_knc_mq_wide(int bits, size_t blocks, size_t rows, const uint8_t * weights, size_t row_stride,
                       const uint8_t * activations, size_t col_stride, float * out, size_t out_stride) {
    struct ggml_knc_mq_scratch scratch;
    int8_t y[16][256] __attribute__((aligned(64)));
    int32_t lanes[16][16] __attribute__((aligned(64)));
    int32_t bsums[16][16];
    float yd[16], sums[16][GGML_KNC_MQ_MAX_ROWS] = {{0}};
    panel_block_fn fn = bits == 3 ? ggml_knc_q3_wide_native : bits == 4 ? ggml_knc_q4_wide_native :
                        bits == 5 ? ggml_knc_q5_wide_native : ggml_knc_q6_wide_native;
    const size_t stride = bits == 3 ? 110 : bits == 4 ? 144 : bits == 5 ? 176 : 210;
    for (size_t b = 0; b < blocks; ++b) {
        for (int c = 0; c < 16; ++c) {
            stage_activation(&scratch, activations + c * col_stride + b * 292);
            memcpy(y[c], scratch.y, sizeof(y[c]));
            memcpy(bsums[c], scratch.bsums, sizeof(bsums[c]));
            yd[c] = scratch.yd;
        }
        for (size_t r = 0; r < rows; ++r) {
            const uint8_t * x = weights + r * row_stride + b * stride;
            int32_t mins[8] = {0};
            float d, dmin = 0;
            if (bits == 3) {
                memcpy(scratch.low, x + 32, 64);
                memcpy(scratch.high, x, 32);
                for (int j = 0; j < 16; ++j) {
                    scratch.scales[j] = (((x[96 + j%8] >> (j/8*4)) & 15) |
                                         (((x[104 + j%4] >> (j/4*2)) & 3) << 4)) - 32;
                }
                d = load_half(x + 108);
            } else if (bits == 6) {
                memcpy(scratch.low, x, 128);
                memcpy(scratch.high, x + 128, 64);
                for (int j = 0; j < 16; ++j) {
                    scratch.scales[j] = x[192+j] < 128 ? x[192+j] : (int)x[192+j] - 256;
                }
                d = load_half(x + 208);
            } else {
                memcpy(scratch.low, x + (bits == 4 ? 16 : 48), 128);
                if (bits == 5) { memcpy(scratch.high, x + 16, 32); }
                for (int j = 0; j < 8; ++j) {
                    const int sc = j < 4 ? x[4+j] & 63 : (x[8+j] & 15) | ((x[j] >> 6) << 4);
                    mins[j] = j < 4 ? x[8+j] & 63 : (x[8+j] >> 4) | ((x[4+j] >> 6) << 4);
                    if (bits == 5) { scratch.scales[j] = sc; }
                    else { scratch.scales[2*j] = scratch.scales[2*j+1] = sc; }
                }
                d = load_half(x);
                dmin = load_half(x + 2);
            }
            fn(scratch.low, scratch.high, &y[0][0], scratch.scales, &lanes[0][0], x, blocks - b);
            for (int c = 0; c < 16; ++c) {
                int32_t dot = 0, correction = 0;
                for (int j = 0; j < 16; ++j) { dot += lanes[c][j]; }
                if (bits == 4 || bits == 5) {
                    for (int j = 0; j < 8; ++j) { correction += mins[j] * (bsums[c][2*j] + bsums[c][2*j+1]); }
                }
                /* Preserve the established per-block x87 expression and float store. */
                if (bits == 5) {
                    sums[c][r] += ((long double) dot * yd[c]) * d - ((long double) correction * yd[c]) * dmin;
                } else if (bits == 4) {
                    sums[c][r] += ((long double) d * yd[c]) * dot - ((long double) dmin * yd[c]) * correction;
                } else {
                    sums[c][r] += ((long double) d * yd[c]) * dot;
                }
            }
        }
    }
    for (int c = 0; c < 16; ++c) {
        for (size_t r = 0; r < rows; ++r) { out[c * out_stride + r] = sums[c][r]; }
    }
}
