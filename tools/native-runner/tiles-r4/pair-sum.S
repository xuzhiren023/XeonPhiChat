/* SPDX-License-Identifier: MIT. Generated isolated two-row candidate. */
#if !defined(__k1om__) || !defined(__KNC__) || defined(__AVX512F__)
#error Native Knights Corner IMCI required
#endif
.text
.p2align 4
.globl ggml_knc_q3_pair_native
.type ggml_knc_q3_pair_native, @function
ggml_knc_q3_pair_native:
/* scratch0=rdi, scratch1=rsi, Q8=rdx, packed0=rcx, packed1=r8, packedQ8=r9; remaining is arg7. */
movq 8(%rsp), %r10
vpxord %zmm0, %zmm0, %zmm0
vpxord %zmm1, %zmm1, %zmm1
vpxord %zmm2, %zmm2, %zmm2
vpxord %zmm3, %zmm3, %zmm3
vpxord %zmm12, %zmm12, %zmm12
vpxord %zmm13, %zmm13, %zmm13
vpxord %zmm14, %zmm14, %zmm14
vpxord %zmm15, %zmm15, %zmm15
vpbroadcastd .Lmask1(%rip), %zmm4
vpbroadcastd .Lmask3(%rip), %zmm5
vpbroadcastd .Lmask4(%rip), %zmm6
vpbroadcastd .Lmask15(%rip), %zmm7
vpbroadcastd .Lmask32(%rip), %zmm8
vmovaps 0(%rdx){sint8}, %zmm11
cmpq $0, %r10
jbe .Lpair3_0_0
vprefetch0 64(%rcx)
vprefetch0 0(%rcx)
vprefetch0 64(%r8)
vprefetch0 0(%r8)
vprefetch0 132(%r9)
.Lpair3_0_0:
cmpq $2, %r10
jbe .Lpair3_0_1
vprefetch1 252(%rcx)
vprefetch1 220(%rcx)
vprefetch1 252(%r8)
vprefetch1 220(%r8)
vprefetch1 588(%r9)
.Lpair3_0_1:
vmovdqa32 0(%rdi){uint8}, %zmm9
vpsrld $0, %zmm9, %zmm9
vpandd %zmm5, %zmm9, %zmm9
vmovdqa32 128(%rdi){uint8}, %zmm10
vpsrld $0, %zmm10, %zmm10
vpandd %zmm4, %zmm10, %zmm10
vpslld $2, %zmm10, %zmm10
vpord %zmm10, %zmm9, %zmm9
vpsubd %zmm6, %zmm9, %zmm9
vcvtfxpntdq2ps $0, %zmm9, %zmm9
vcvtfxpntdq2ps $0, 448(%rdi){1to16}, %zmm10
vmulps %zmm10, %zmm9, %zmm9
vfmadd231ps %zmm11, %zmm9, %zmm0
vmovdqa32 0(%rsi){uint8}, %zmm9
vpsrld $0, %zmm9, %zmm9
vpandd %zmm5, %zmm9, %zmm9
vmovdqa32 128(%rsi){uint8}, %zmm10
vpsrld $0, %zmm10, %zmm10
vpandd %zmm4, %zmm10, %zmm10
vpslld $2, %zmm10, %zmm10
vpord %zmm10, %zmm9, %zmm9
vpsubd %zmm6, %zmm9, %zmm9
vcvtfxpntdq2ps $0, %zmm9, %zmm9
vcvtfxpntdq2ps $0, 448(%rsi){1to16}, %zmm10
vmulps %zmm10, %zmm9, %zmm9
vfmadd231ps %zmm11, %zmm9, %zmm12
vmovaps 16(%rdx){sint8}, %zmm11
vmovdqa32 16(%rdi){uint8}, %zmm9
vpsrld $0, %zmm9, %zmm9
vpandd %zmm5, %zmm9, %zmm9
vmovdqa32 144(%rdi){uint8}, %zmm10
vpsrld $0, %zmm10, %zmm10
vpandd %zmm4, %zmm10, %zmm10
vpslld $2, %zmm10, %zmm10
vpord %zmm10, %zmm9, %zmm9
vpsubd %zmm6, %zmm9, %zmm9
vcvtfxpntdq2ps $0, %zmm9, %zmm9
vcvtfxpntdq2ps $0, 452(%rdi){1to16}, %zmm10
vmulps %zmm10, %zmm9, %zmm9
vfmadd231ps %zmm11, %zmm9, %zmm1
vmovdqa32 16(%rsi){uint8}, %zmm9
vpsrld $0, %zmm9, %zmm9
vpandd %zmm5, %zmm9, %zmm9
vmovdqa32 144(%rsi){uint8}, %zmm10
vpsrld $0, %zmm10, %zmm10
vpandd %zmm4, %zmm10, %zmm10
vpslld $2, %zmm10, %zmm10
vpord %zmm10, %zmm9, %zmm9
vpsubd %zmm6, %zmm9, %zmm9
vcvtfxpntdq2ps $0, %zmm9, %zmm9
vcvtfxpntdq2ps $0, 452(%rsi){1to16}, %zmm10
vmulps %zmm10, %zmm9, %zmm9
vfmadd231ps %zmm11, %zmm9, %zmm13
vmovaps 32(%rdx){sint8}, %zmm11
vmovdqa32 0(%rdi){uint8}, %zmm9
vpsrld $2, %zmm9, %zmm9
vpandd %zmm5, %zmm9, %zmm9
vmovdqa32 128(%rdi){uint8}, %zmm10
vpsrld $1, %zmm10, %zmm10
vpandd %zmm4, %zmm10, %zmm10
vpslld $2, %zmm10, %zmm10
vpord %zmm10, %zmm9, %zmm9
vpsubd %zmm6, %zmm9, %zmm9
vcvtfxpntdq2ps $0, %zmm9, %zmm9
vcvtfxpntdq2ps $0, 456(%rdi){1to16}, %zmm10
vmulps %zmm10, %zmm9, %zmm9
vfmadd231ps %zmm11, %zmm9, %zmm2
vmovdqa32 0(%rsi){uint8}, %zmm9
vpsrld $2, %zmm9, %zmm9
vpandd %zmm5, %zmm9, %zmm9
vmovdqa32 128(%rsi){uint8}, %zmm10
vpsrld $1, %zmm10, %zmm10
vpandd %zmm4, %zmm10, %zmm10
vpslld $2, %zmm10, %zmm10
vpord %zmm10, %zmm9, %zmm9
vpsubd %zmm6, %zmm9, %zmm9
vcvtfxpntdq2ps $0, %zmm9, %zmm9
vcvtfxpntdq2ps $0, 456(%rsi){1to16}, %zmm10
vmulps %zmm10, %zmm9, %zmm9
vfmadd231ps %zmm11, %zmm9, %zmm14
vmovaps 48(%rdx){sint8}, %zmm11
vmovdqa32 16(%rdi){uint8}, %zmm9
vpsrld $2, %zmm9, %zmm9
vpandd %zmm5, %zmm9, %zmm9
vmovdqa32 144(%rdi){uint8}, %zmm10
vpsrld $1, %zmm10, %zmm10
vpandd %zmm4, %zmm10, %zmm10
vpslld $2, %zmm10, %zmm10
vpord %zmm10, %zmm9, %zmm9
vpsubd %zmm6, %zmm9, %zmm9
vcvtfxpntdq2ps $0, %zmm9, %zmm9
vcvtfxpntdq2ps $0, 460(%rdi){1to16}, %zmm10
vmulps %zmm10, %zmm9, %zmm9
vfmadd231ps %zmm11, %zmm9, %zmm3
vmovdqa32 16(%rsi){uint8}, %zmm9
vpsrld $2, %zmm9, %zmm9
vpandd %zmm5, %zmm9, %zmm9
vmovdqa32 144(%rsi){uint8}, %zmm10
vpsrld $1, %zmm10, %zmm10
vpandd %zmm4, %zmm10, %zmm10
vpslld $2, %zmm10, %zmm10
vpord %zmm10, %zmm9, %zmm9
vpsubd %zmm6, %zmm9, %zmm9
vcvtfxpntdq2ps $0, %zmm9, %zmm9
vcvtfxpntdq2ps $0, 460(%rsi){1to16}, %zmm10
vmulps %zmm10, %zmm9, %zmm9
vfmadd231ps %zmm11, %zmm9, %zmm15
vmovaps 64(%rdx){sint8}, %zmm11
cmpq $0, %r10
jbe .Lpair3_64_0
vprefetch0 64(%rcx)
vprefetch0 0(%rcx)
vprefetch0 64(%r8)
vprefetch0 0(%r8)
vprefetch0 196(%r9)
.Lpair3_64_0:
cmpq $2, %r10
jbe .Lpair3_64_1
vprefetch1 252(%rcx)
vprefetch1 220(%rcx)
vprefetch1 252(%r8)
vprefetch1 220(%r8)
vprefetch1 652(%r9)
.Lpair3_64_1:
vmovdqa32 0(%rdi){uint8}, %zmm9
vpsrld $4, %zmm9, %zmm9
vpandd %zmm5, %zmm9, %zmm9
vmovdqa32 128(%rdi){uint8}, %zmm10
vpsrld $2, %zmm10, %zmm10
vpandd %zmm4, %zmm10, %zmm10
vpslld $2, %zmm10, %zmm10
vpord %zmm10, %zmm9, %zmm9
vpsubd %zmm6, %zmm9, %zmm9
vcvtfxpntdq2ps $0, %zmm9, %zmm9
vcvtfxpntdq2ps $0, 464(%rdi){1to16}, %zmm10
vmulps %zmm10, %zmm9, %zmm9
vfmadd231ps %zmm11, %zmm9, %zmm0
vmovdqa32 0(%rsi){uint8}, %zmm9
vpsrld $4, %zmm9, %zmm9
vpandd %zmm5, %zmm9, %zmm9
vmovdqa32 128(%rsi){uint8}, %zmm10
vpsrld $2, %zmm10, %zmm10
vpandd %zmm4, %zmm10, %zmm10
vpslld $2, %zmm10, %zmm10
vpord %zmm10, %zmm9, %zmm9
vpsubd %zmm6, %zmm9, %zmm9
vcvtfxpntdq2ps $0, %zmm9, %zmm9
vcvtfxpntdq2ps $0, 464(%rsi){1to16}, %zmm10
vmulps %zmm10, %zmm9, %zmm9
vfmadd231ps %zmm11, %zmm9, %zmm12
vmovaps 80(%rdx){sint8}, %zmm11
vmovdqa32 16(%rdi){uint8}, %zmm9
vpsrld $4, %zmm9, %zmm9
vpandd %zmm5, %zmm9, %zmm9
vmovdqa32 144(%rdi){uint8}, %zmm10
vpsrld $2, %zmm10, %zmm10
vpandd %zmm4, %zmm10, %zmm10
vpslld $2, %zmm10, %zmm10
vpord %zmm10, %zmm9, %zmm9
vpsubd %zmm6, %zmm9, %zmm9
vcvtfxpntdq2ps $0, %zmm9, %zmm9
vcvtfxpntdq2ps $0, 468(%rdi){1to16}, %zmm10
vmulps %zmm10, %zmm9, %zmm9
vfmadd231ps %zmm11, %zmm9, %zmm1
vmovdqa32 16(%rsi){uint8}, %zmm9
vpsrld $4, %zmm9, %zmm9
vpandd %zmm5, %zmm9, %zmm9
vmovdqa32 144(%rsi){uint8}, %zmm10
vpsrld $2, %zmm10, %zmm10
vpandd %zmm4, %zmm10, %zmm10
vpslld $2, %zmm10, %zmm10
vpord %zmm10, %zmm9, %zmm9
vpsubd %zmm6, %zmm9, %zmm9
vcvtfxpntdq2ps $0, %zmm9, %zmm9
vcvtfxpntdq2ps $0, 468(%rsi){1to16}, %zmm10
vmulps %zmm10, %zmm9, %zmm9
vfmadd231ps %zmm11, %zmm9, %zmm13
vmovaps 96(%rdx){sint8}, %zmm11
vmovdqa32 0(%rdi){uint8}, %zmm9
vpsrld $6, %zmm9, %zmm9
vpandd %zmm5, %zmm9, %zmm9
vmovdqa32 128(%rdi){uint8}, %zmm10
vpsrld $3, %zmm10, %zmm10
vpandd %zmm4, %zmm10, %zmm10
vpslld $2, %zmm10, %zmm10
vpord %zmm10, %zmm9, %zmm9
vpsubd %zmm6, %zmm9, %zmm9
vcvtfxpntdq2ps $0, %zmm9, %zmm9
vcvtfxpntdq2ps $0, 472(%rdi){1to16}, %zmm10
vmulps %zmm10, %zmm9, %zmm9
vfmadd231ps %zmm11, %zmm9, %zmm2
vmovdqa32 0(%rsi){uint8}, %zmm9
vpsrld $6, %zmm9, %zmm9
vpandd %zmm5, %zmm9, %zmm9
vmovdqa32 128(%rsi){uint8}, %zmm10
vpsrld $3, %zmm10, %zmm10
vpandd %zmm4, %zmm10, %zmm10
vpslld $2, %zmm10, %zmm10
vpord %zmm10, %zmm9, %zmm9
vpsubd %zmm6, %zmm9, %zmm9
vcvtfxpntdq2ps $0, %zmm9, %zmm9
vcvtfxpntdq2ps $0, 472(%rsi){1to16}, %zmm10
vmulps %zmm10, %zmm9, %zmm9
vfmadd231ps %zmm11, %zmm9, %zmm14
vmovaps 112(%rdx){sint8}, %zmm11
vmovdqa32 16(%rdi){uint8}, %zmm9
vpsrld $6, %zmm9, %zmm9
vpandd %zmm5, %zmm9, %zmm9
vmovdqa32 144(%rdi){uint8}, %zmm10
vpsrld $3, %zmm10, %zmm10
vpandd %zmm4, %zmm10, %zmm10
vpslld $2, %zmm10, %zmm10
vpord %zmm10, %zmm9, %zmm9
vpsubd %zmm6, %zmm9, %zmm9
vcvtfxpntdq2ps $0, %zmm9, %zmm9
vcvtfxpntdq2ps $0, 476(%rdi){1to16}, %zmm10
vmulps %zmm10, %zmm9, %zmm9
vfmadd231ps %zmm11, %zmm9, %zmm3
vmovdqa32 16(%rsi){uint8}, %zmm9
vpsrld $6, %zmm9, %zmm9
vpandd %zmm5, %zmm9, %zmm9
vmovdqa32 144(%rsi){uint8}, %zmm10
vpsrld $3, %zmm10, %zmm10
vpandd %zmm4, %zmm10, %zmm10
vpslld $2, %zmm10, %zmm10
vpord %zmm10, %zmm9, %zmm9
vpsubd %zmm6, %zmm9, %zmm9
vcvtfxpntdq2ps $0, %zmm9, %zmm9
vcvtfxpntdq2ps $0, 476(%rsi){1to16}, %zmm10
vmulps %zmm10, %zmm9, %zmm9
vfmadd231ps %zmm11, %zmm9, %zmm15
vmovaps 128(%rdx){sint8}, %zmm11
cmpq $1, %r10
jbe .Lpair3_128_0
vprefetch0 142(%rcx)
vprefetch0 110(%rcx)
vprefetch0 142(%r8)
vprefetch0 110(%r8)
vprefetch0 296(%r9)
.Lpair3_128_0:
cmpq $2, %r10
jbe .Lpair3_128_1
vprefetch1 284(%rcx)
vprefetch1 220(%rcx)
vprefetch1 284(%r8)
vprefetch1 220(%r8)
vprefetch1 716(%r9)
.Lpair3_128_1:
vmovdqa32 32(%rdi){uint8}, %zmm9
vpsrld $0, %zmm9, %zmm9
vpandd %zmm5, %zmm9, %zmm9
vmovdqa32 128(%rdi){uint8}, %zmm10
vpsrld $4, %zmm10, %zmm10
vpandd %zmm4, %zmm10, %zmm10
vpslld $2, %zmm10, %zmm10
vpord %zmm10, %zmm9, %zmm9
vpsubd %zmm6, %zmm9, %zmm9
vcvtfxpntdq2ps $0, %zmm9, %zmm9
vcvtfxpntdq2ps $0, 480(%rdi){1to16}, %zmm10
vmulps %zmm10, %zmm9, %zmm9
vfmadd231ps %zmm11, %zmm9, %zmm0
vmovdqa32 32(%rsi){uint8}, %zmm9
vpsrld $0, %zmm9, %zmm9
vpandd %zmm5, %zmm9, %zmm9
vmovdqa32 128(%rsi){uint8}, %zmm10
vpsrld $4, %zmm10, %zmm10
vpandd %zmm4, %zmm10, %zmm10
vpslld $2, %zmm10, %zmm10
vpord %zmm10, %zmm9, %zmm9
vpsubd %zmm6, %zmm9, %zmm9
vcvtfxpntdq2ps $0, %zmm9, %zmm9
vcvtfxpntdq2ps $0, 480(%rsi){1to16}, %zmm10
vmulps %zmm10, %zmm9, %zmm9
vfmadd231ps %zmm11, %zmm9, %zmm12
vmovaps 144(%rdx){sint8}, %zmm11
vmovdqa32 48(%rdi){uint8}, %zmm9
vpsrld $0, %zmm9, %zmm9
vpandd %zmm5, %zmm9, %zmm9
vmovdqa32 144(%rdi){uint8}, %zmm10
vpsrld $4, %zmm10, %zmm10
vpandd %zmm4, %zmm10, %zmm10
vpslld $2, %zmm10, %zmm10
vpord %zmm10, %zmm9, %zmm9
vpsubd %zmm6, %zmm9, %zmm9
vcvtfxpntdq2ps $0, %zmm9, %zmm9
vcvtfxpntdq2ps $0, 484(%rdi){1to16}, %zmm10
vmulps %zmm10, %zmm9, %zmm9
vfmadd231ps %zmm11, %zmm9, %zmm1
vmovdqa32 48(%rsi){uint8}, %zmm9
vpsrld $0, %zmm9, %zmm9
vpandd %zmm5, %zmm9, %zmm9
vmovdqa32 144(%rsi){uint8}, %zmm10
vpsrld $4, %zmm10, %zmm10
vpandd %zmm4, %zmm10, %zmm10
vpslld $2, %zmm10, %zmm10
vpord %zmm10, %zmm9, %zmm9
vpsubd %zmm6, %zmm9, %zmm9
vcvtfxpntdq2ps $0, %zmm9, %zmm9
vcvtfxpntdq2ps $0, 484(%rsi){1to16}, %zmm10
vmulps %zmm10, %zmm9, %zmm9
vfmadd231ps %zmm11, %zmm9, %zmm13
vmovaps 160(%rdx){sint8}, %zmm11
vmovdqa32 32(%rdi){uint8}, %zmm9
vpsrld $2, %zmm9, %zmm9
vpandd %zmm5, %zmm9, %zmm9
vmovdqa32 128(%rdi){uint8}, %zmm10
vpsrld $5, %zmm10, %zmm10
vpandd %zmm4, %zmm10, %zmm10
vpslld $2, %zmm10, %zmm10
vpord %zmm10, %zmm9, %zmm9
vpsubd %zmm6, %zmm9, %zmm9
vcvtfxpntdq2ps $0, %zmm9, %zmm9
vcvtfxpntdq2ps $0, 488(%rdi){1to16}, %zmm10
vmulps %zmm10, %zmm9, %zmm9
vfmadd231ps %zmm11, %zmm9, %zmm2
vmovdqa32 32(%rsi){uint8}, %zmm9
vpsrld $2, %zmm9, %zmm9
vpandd %zmm5, %zmm9, %zmm9
vmovdqa32 128(%rsi){uint8}, %zmm10
vpsrld $5, %zmm10, %zmm10
vpandd %zmm4, %zmm10, %zmm10
vpslld $2, %zmm10, %zmm10
vpord %zmm10, %zmm9, %zmm9
vpsubd %zmm6, %zmm9, %zmm9
vcvtfxpntdq2ps $0, %zmm9, %zmm9
vcvtfxpntdq2ps $0, 488(%rsi){1to16}, %zmm10
vmulps %zmm10, %zmm9, %zmm9
vfmadd231ps %zmm11, %zmm9, %zmm14
vmovaps 176(%rdx){sint8}, %zmm11
vmovdqa32 48(%rdi){uint8}, %zmm9
vpsrld $2, %zmm9, %zmm9
vpandd %zmm5, %zmm9, %zmm9
vmovdqa32 144(%rdi){uint8}, %zmm10
vpsrld $5, %zmm10, %zmm10
vpandd %zmm4, %zmm10, %zmm10
vpslld $2, %zmm10, %zmm10
vpord %zmm10, %zmm9, %zmm9
vpsubd %zmm6, %zmm9, %zmm9
vcvtfxpntdq2ps $0, %zmm9, %zmm9
vcvtfxpntdq2ps $0, 492(%rdi){1to16}, %zmm10
vmulps %zmm10, %zmm9, %zmm9
vfmadd231ps %zmm11, %zmm9, %zmm3
vmovdqa32 48(%rsi){uint8}, %zmm9
vpsrld $2, %zmm9, %zmm9
vpandd %zmm5, %zmm9, %zmm9
vmovdqa32 144(%rsi){uint8}, %zmm10
vpsrld $5, %zmm10, %zmm10
vpandd %zmm4, %zmm10, %zmm10
vpslld $2, %zmm10, %zmm10
vpord %zmm10, %zmm9, %zmm9
vpsubd %zmm6, %zmm9, %zmm9
vcvtfxpntdq2ps $0, %zmm9, %zmm9
vcvtfxpntdq2ps $0, 492(%rsi){1to16}, %zmm10
vmulps %zmm10, %zmm9, %zmm9
vfmadd231ps %zmm11, %zmm9, %zmm15
vmovaps 192(%rdx){sint8}, %zmm11
cmpq $1, %r10
jbe .Lpair3_192_0
vprefetch0 142(%rcx)
vprefetch0 110(%rcx)
vprefetch0 142(%r8)
vprefetch0 110(%r8)
vprefetch0 360(%r9)
.Lpair3_192_0:
cmpq $2, %r10
jbe .Lpair3_192_1
vprefetch1 284(%rcx)
vprefetch1 220(%rcx)
vprefetch1 284(%r8)
vprefetch1 220(%r8)
vprefetch1 780(%r9)
.Lpair3_192_1:
vmovdqa32 32(%rdi){uint8}, %zmm9
vpsrld $4, %zmm9, %zmm9
vpandd %zmm5, %zmm9, %zmm9
vmovdqa32 128(%rdi){uint8}, %zmm10
vpsrld $6, %zmm10, %zmm10
vpandd %zmm4, %zmm10, %zmm10
vpslld $2, %zmm10, %zmm10
vpord %zmm10, %zmm9, %zmm9
vpsubd %zmm6, %zmm9, %zmm9
vcvtfxpntdq2ps $0, %zmm9, %zmm9
vcvtfxpntdq2ps $0, 496(%rdi){1to16}, %zmm10
vmulps %zmm10, %zmm9, %zmm9
vfmadd231ps %zmm11, %zmm9, %zmm0
vmovdqa32 32(%rsi){uint8}, %zmm9
vpsrld $4, %zmm9, %zmm9
vpandd %zmm5, %zmm9, %zmm9
vmovdqa32 128(%rsi){uint8}, %zmm10
vpsrld $6, %zmm10, %zmm10
vpandd %zmm4, %zmm10, %zmm10
vpslld $2, %zmm10, %zmm10
vpord %zmm10, %zmm9, %zmm9
vpsubd %zmm6, %zmm9, %zmm9
vcvtfxpntdq2ps $0, %zmm9, %zmm9
vcvtfxpntdq2ps $0, 496(%rsi){1to16}, %zmm10
vmulps %zmm10, %zmm9, %zmm9
vfmadd231ps %zmm11, %zmm9, %zmm12
vmovaps 208(%rdx){sint8}, %zmm11
vmovdqa32 48(%rdi){uint8}, %zmm9
vpsrld $4, %zmm9, %zmm9
vpandd %zmm5, %zmm9, %zmm9
vmovdqa32 144(%rdi){uint8}, %zmm10
vpsrld $6, %zmm10, %zmm10
vpandd %zmm4, %zmm10, %zmm10
vpslld $2, %zmm10, %zmm10
vpord %zmm10, %zmm9, %zmm9
vpsubd %zmm6, %zmm9, %zmm9
vcvtfxpntdq2ps $0, %zmm9, %zmm9
vcvtfxpntdq2ps $0, 500(%rdi){1to16}, %zmm10
vmulps %zmm10, %zmm9, %zmm9
vfmadd231ps %zmm11, %zmm9, %zmm1
vmovdqa32 48(%rsi){uint8}, %zmm9
vpsrld $4, %zmm9, %zmm9
vpandd %zmm5, %zmm9, %zmm9
vmovdqa32 144(%rsi){uint8}, %zmm10
vpsrld $6, %zmm10, %zmm10
vpandd %zmm4, %zmm10, %zmm10
vpslld $2, %zmm10, %zmm10
vpord %zmm10, %zmm9, %zmm9
vpsubd %zmm6, %zmm9, %zmm9
vcvtfxpntdq2ps $0, %zmm9, %zmm9
vcvtfxpntdq2ps $0, 500(%rsi){1to16}, %zmm10
vmulps %zmm10, %zmm9, %zmm9
vfmadd231ps %zmm11, %zmm9, %zmm13
vmovaps 224(%rdx){sint8}, %zmm11
vmovdqa32 32(%rdi){uint8}, %zmm9
vpsrld $6, %zmm9, %zmm9
vpandd %zmm5, %zmm9, %zmm9
vmovdqa32 128(%rdi){uint8}, %zmm10
vpsrld $7, %zmm10, %zmm10
vpandd %zmm4, %zmm10, %zmm10
vpslld $2, %zmm10, %zmm10
vpord %zmm10, %zmm9, %zmm9
vpsubd %zmm6, %zmm9, %zmm9
vcvtfxpntdq2ps $0, %zmm9, %zmm9
vcvtfxpntdq2ps $0, 504(%rdi){1to16}, %zmm10
vmulps %zmm10, %zmm9, %zmm9
vfmadd231ps %zmm11, %zmm9, %zmm2
vmovdqa32 32(%rsi){uint8}, %zmm9
vpsrld $6, %zmm9, %zmm9
vpandd %zmm5, %zmm9, %zmm9
vmovdqa32 128(%rsi){uint8}, %zmm10
vpsrld $7, %zmm10, %zmm10
vpandd %zmm4, %zmm10, %zmm10
vpslld $2, %zmm10, %zmm10
vpord %zmm10, %zmm9, %zmm9
vpsubd %zmm6, %zmm9, %zmm9
vcvtfxpntdq2ps $0, %zmm9, %zmm9
vcvtfxpntdq2ps $0, 504(%rsi){1to16}, %zmm10
vmulps %zmm10, %zmm9, %zmm9
vfmadd231ps %zmm11, %zmm9, %zmm14
vmovaps 240(%rdx){sint8}, %zmm11
vmovdqa32 48(%rdi){uint8}, %zmm9
vpsrld $6, %zmm9, %zmm9
vpandd %zmm5, %zmm9, %zmm9
vmovdqa32 144(%rdi){uint8}, %zmm10
vpsrld $7, %zmm10, %zmm10
vpandd %zmm4, %zmm10, %zmm10
vpslld $2, %zmm10, %zmm10
vpord %zmm10, %zmm9, %zmm9
vpsubd %zmm6, %zmm9, %zmm9
vcvtfxpntdq2ps $0, %zmm9, %zmm9
vcvtfxpntdq2ps $0, 508(%rdi){1to16}, %zmm10
vmulps %zmm10, %zmm9, %zmm9
vfmadd231ps %zmm11, %zmm9, %zmm3
vmovdqa32 48(%rsi){uint8}, %zmm9
vpsrld $6, %zmm9, %zmm9
vpandd %zmm5, %zmm9, %zmm9
vmovdqa32 144(%rsi){uint8}, %zmm10
vpsrld $7, %zmm10, %zmm10
vpandd %zmm4, %zmm10, %zmm10
vpslld $2, %zmm10, %zmm10
vpord %zmm10, %zmm9, %zmm9
vpsubd %zmm6, %zmm9, %zmm9
vcvtfxpntdq2ps $0, %zmm9, %zmm9
vcvtfxpntdq2ps $0, 508(%rsi){1to16}, %zmm10
vmulps %zmm10, %zmm9, %zmm9
vfmadd231ps %zmm11, %zmm9, %zmm15
vaddps %zmm1, %zmm0, %zmm0
vaddps %zmm3, %zmm2, %zmm2
vaddps %zmm2, %zmm0, %zmm0
vcvtfxpntps2dq $0, %zmm0, %zmm0
vpermf32x4 $0x4e, %zmm0, %zmm4
vpaddd %zmm4, %zmm0, %zmm0
vpermf32x4 $0xb1, %zmm0, %zmm4
vpaddd %zmm4, %zmm0, %zmm0
vpshufd $0x4e, %zmm0, %zmm4
vpaddd %zmm4, %zmm0, %zmm0
vpshufd $0xb1, %zmm0, %zmm4
vpaddd %zmm4, %zmm0, %zmm0
vmovdqa32 %zmm0, 512(%rdi)
vaddps %zmm13, %zmm12, %zmm12
vaddps %zmm15, %zmm14, %zmm14
vaddps %zmm14, %zmm12, %zmm12
vcvtfxpntps2dq $0, %zmm12, %zmm12
vpermf32x4 $0x4e, %zmm12, %zmm4
vpaddd %zmm4, %zmm12, %zmm12
vpermf32x4 $0xb1, %zmm12, %zmm4
vpaddd %zmm4, %zmm12, %zmm12
vpshufd $0x4e, %zmm12, %zmm4
vpaddd %zmm4, %zmm12, %zmm12
vpshufd $0xb1, %zmm12, %zmm4
vpaddd %zmm4, %zmm12, %zmm12
vmovdqa32 %zmm12, 512(%rsi)
ret
.size ggml_knc_q3_pair_native, .-ggml_knc_q3_pair_native
.p2align 4
.globl ggml_knc_q4_pair_native
.type ggml_knc_q4_pair_native, @function
ggml_knc_q4_pair_native:
/* scratch0=rdi, scratch1=rsi, Q8=rdx, packed0=rcx, packed1=r8, packedQ8=r9; remaining is arg7. */
movq 8(%rsp), %r10
vpxord %zmm0, %zmm0, %zmm0
vpxord %zmm1, %zmm1, %zmm1
vpxord %zmm2, %zmm2, %zmm2
vpxord %zmm3, %zmm3, %zmm3
vpxord %zmm12, %zmm12, %zmm12
vpxord %zmm13, %zmm13, %zmm13
vpxord %zmm14, %zmm14, %zmm14
vpxord %zmm15, %zmm15, %zmm15
vpbroadcastd .Lmask1(%rip), %zmm4
vpbroadcastd .Lmask3(%rip), %zmm5
vpbroadcastd .Lmask4(%rip), %zmm6
vpbroadcastd .Lmask15(%rip), %zmm7
vpbroadcastd .Lmask32(%rip), %zmm8
vmovaps 0(%rdx){sint8}, %zmm11
cmpq $0, %r10
jbe .Lpair4_0_0
vprefetch0 80(%rcx)
vprefetch0 80(%r8)
vprefetch0 132(%r9)
.Lpair4_0_0:
cmpq $2, %r10
jbe .Lpair4_0_1
vprefetch1 304(%rcx)
vprefetch1 304(%r8)
vprefetch1 588(%r9)
.Lpair4_0_1:
vmovdqa32 0(%rdi){uint8}, %zmm9
vpsrld $0, %zmm9, %zmm9
vpandd %zmm7, %zmm9, %zmm9
vcvtfxpntdq2ps $0, %zmm9, %zmm9
vcvtfxpntdq2ps $0, 448(%rdi){1to16}, %zmm10
vmulps %zmm10, %zmm9, %zmm9
vfmadd231ps %zmm11, %zmm9, %zmm0
vmovdqa32 0(%rsi){uint8}, %zmm9
vpsrld $0, %zmm9, %zmm9
vpandd %zmm7, %zmm9, %zmm9
vcvtfxpntdq2ps $0, %zmm9, %zmm9
vcvtfxpntdq2ps $0, 448(%rsi){1to16}, %zmm10
vmulps %zmm10, %zmm9, %zmm9
vfmadd231ps %zmm11, %zmm9, %zmm12
vmovaps 16(%rdx){sint8}, %zmm11
vmovdqa32 16(%rdi){uint8}, %zmm9
vpsrld $0, %zmm9, %zmm9
vpandd %zmm7, %zmm9, %zmm9
vcvtfxpntdq2ps $0, %zmm9, %zmm9
vcvtfxpntdq2ps $0, 452(%rdi){1to16}, %zmm10
vmulps %zmm10, %zmm9, %zmm9
vfmadd231ps %zmm11, %zmm9, %zmm1
vmovdqa32 16(%rsi){uint8}, %zmm9
vpsrld $0, %zmm9, %zmm9
vpandd %zmm7, %zmm9, %zmm9
vcvtfxpntdq2ps $0, %zmm9, %zmm9
vcvtfxpntdq2ps $0, 452(%rsi){1to16}, %zmm10
vmulps %zmm10, %zmm9, %zmm9
vfmadd231ps %zmm11, %zmm9, %zmm13
vmovaps 32(%rdx){sint8}, %zmm11
vmovdqa32 0(%rdi){uint8}, %zmm9
vpsrld $4, %zmm9, %zmm9
vpandd %zmm7, %zmm9, %zmm9
vcvtfxpntdq2ps $0, %zmm9, %zmm9
vcvtfxpntdq2ps $0, 456(%rdi){1to16}, %zmm10
vmulps %zmm10, %zmm9, %zmm9
vfmadd231ps %zmm11, %zmm9, %zmm2
vmovdqa32 0(%rsi){uint8}, %zmm9
vpsrld $4, %zmm9, %zmm9
vpandd %zmm7, %zmm9, %zmm9
vcvtfxpntdq2ps $0, %zmm9, %zmm9
vcvtfxpntdq2ps $0, 456(%rsi){1to16}, %zmm10
vmulps %zmm10, %zmm9, %zmm9
vfmadd231ps %zmm11, %zmm9, %zmm14
vmovaps 48(%rdx){sint8}, %zmm11
vmovdqa32 16(%rdi){uint8}, %zmm9
vpsrld $4, %zmm9, %zmm9
vpandd %zmm7, %zmm9, %zmm9
vcvtfxpntdq2ps $0, %zmm9, %zmm9
vcvtfxpntdq2ps $0, 460(%rdi){1to16}, %zmm10
vmulps %zmm10, %zmm9, %zmm9
vfmadd231ps %zmm11, %zmm9, %zmm3
vmovdqa32 16(%rsi){uint8}, %zmm9
vpsrld $4, %zmm9, %zmm9
vpandd %zmm7, %zmm9, %zmm9
vcvtfxpntdq2ps $0, %zmm9, %zmm9
vcvtfxpntdq2ps $0, 460(%rsi){1to16}, %zmm10
vmulps %zmm10, %zmm9, %zmm9
vfmadd231ps %zmm11, %zmm9, %zmm15
vmovaps 64(%rdx){sint8}, %zmm11
cmpq $0, %r10
jbe .Lpair4_64_0
vprefetch0 112(%rcx)
vprefetch0 112(%r8)
vprefetch0 196(%r9)
.Lpair4_64_0:
cmpq $2, %r10
jbe .Lpair4_64_1
vprefetch1 336(%rcx)
vprefetch1 336(%r8)
vprefetch1 652(%r9)
.Lpair4_64_1:
vmovdqa32 32(%rdi){uint8}, %zmm9
vpsrld $0, %zmm9, %zmm9
vpandd %zmm7, %zmm9, %zmm9
vcvtfxpntdq2ps $0, %zmm9, %zmm9
vcvtfxpntdq2ps $0, 464(%rdi){1to16}, %zmm10
vmulps %zmm10, %zmm9, %zmm9
vfmadd231ps %zmm11, %zmm9, %zmm0
vmovdqa32 32(%rsi){uint8}, %zmm9
vpsrld $0, %zmm9, %zmm9
vpandd %zmm7, %zmm9, %zmm9
vcvtfxpntdq2ps $0, %zmm9, %zmm9
vcvtfxpntdq2ps $0, 464(%rsi){1to16}, %zmm10
vmulps %zmm10, %zmm9, %zmm9
vfmadd231ps %zmm11, %zmm9, %zmm12
vmovaps 80(%rdx){sint8}, %zmm11
vmovdqa32 48(%rdi){uint8}, %zmm9
vpsrld $0, %zmm9, %zmm9
vpandd %zmm7, %zmm9, %zmm9
vcvtfxpntdq2ps $0, %zmm9, %zmm9
vcvtfxpntdq2ps $0, 468(%rdi){1to16}, %zmm10
vmulps %zmm10, %zmm9, %zmm9
vfmadd231ps %zmm11, %zmm9, %zmm1
vmovdqa32 48(%rsi){uint8}, %zmm9
vpsrld $0, %zmm9, %zmm9
vpandd %zmm7, %zmm9, %zmm9
vcvtfxpntdq2ps $0, %zmm9, %zmm9
vcvtfxpntdq2ps $0, 468(%rsi){1to16}, %zmm10
vmulps %zmm10, %zmm9, %zmm9
vfmadd231ps %zmm11, %zmm9, %zmm13
vmovaps 96(%rdx){sint8}, %zmm11
vmovdqa32 32(%rdi){uint8}, %zmm9
vpsrld $4, %zmm9, %zmm9
vpandd %zmm7, %zmm9, %zmm9
vcvtfxpntdq2ps $0, %zmm9, %zmm9
vcvtfxpntdq2ps $0, 472(%rdi){1to16}, %zmm10
vmulps %zmm10, %zmm9, %zmm9
vfmadd231ps %zmm11, %zmm9, %zmm2
vmovdqa32 32(%rsi){uint8}, %zmm9
vpsrld $4, %zmm9, %zmm9
vpandd %zmm7, %zmm9, %zmm9
vcvtfxpntdq2ps $0, %zmm9, %zmm9
vcvtfxpntdq2ps $0, 472(%rsi){1to16}, %zmm10
vmulps %zmm10, %zmm9, %zmm9
vfmadd231ps %zmm11, %zmm9, %zmm14
vmovaps 112(%rdx){sint8}, %zmm11
vmovdqa32 48(%rdi){uint8}, %zmm9
vpsrld $4, %zmm9, %zmm9
vpandd %zmm7, %zmm9, %zmm9
vcvtfxpntdq2ps $0, %zmm9, %zmm9
vcvtfxpntdq2ps $0, 476(%rdi){1to16}, %zmm10
vmulps %zmm10, %zmm9, %zmm9
vfmadd231ps %zmm11, %zmm9, %zmm3
vmovdqa32 48(%rsi){uint8}, %zmm9
vpsrld $4, %zmm9, %zmm9
vpandd %zmm7, %zmm9, %zmm9
vcvtfxpntdq2ps $0, %zmm9, %zmm9
vcvtfxpntdq2ps $0, 476(%rsi){1to16}, %zmm10
vmulps %zmm10, %zmm9, %zmm9
vfmadd231ps %zmm11, %zmm9, %zmm15
vmovaps 128(%rdx){sint8}, %zmm11
cmpq $1, %r10
jbe .Lpair4_128_0
vprefetch0 160(%rcx)
vprefetch0 160(%r8)
vprefetch0 296(%r9)
.Lpair4_128_0:
cmpq $2, %r10
jbe .Lpair4_128_1
vprefetch1 368(%rcx)
vprefetch1 368(%r8)
vprefetch1 716(%r9)
.Lpair4_128_1:
vmovdqa32 64(%rdi){uint8}, %zmm9
vpsrld $0, %zmm9, %zmm9
vpandd %zmm7, %zmm9, %zmm9
vcvtfxpntdq2ps $0, %zmm9, %zmm9
vcvtfxpntdq2ps $0, 480(%rdi){1to16}, %zmm10
vmulps %zmm10, %zmm9, %zmm9
vfmadd231ps %zmm11, %zmm9, %zmm0
vmovdqa32 64(%rsi){uint8}, %zmm9
vpsrld $0, %zmm9, %zmm9
vpandd %zmm7, %zmm9, %zmm9
vcvtfxpntdq2ps $0, %zmm9, %zmm9
vcvtfxpntdq2ps $0, 480(%rsi){1to16}, %zmm10
vmulps %zmm10, %zmm9, %zmm9
vfmadd231ps %zmm11, %zmm9, %zmm12
vmovaps 144(%rdx){sint8}, %zmm11
vmovdqa32 80(%rdi){uint8}, %zmm9
vpsrld $0, %zmm9, %zmm9
vpandd %zmm7, %zmm9, %zmm9
vcvtfxpntdq2ps $0, %zmm9, %zmm9
vcvtfxpntdq2ps $0, 484(%rdi){1to16}, %zmm10
vmulps %zmm10, %zmm9, %zmm9
vfmadd231ps %zmm11, %zmm9, %zmm1
vmovdqa32 80(%rsi){uint8}, %zmm9
vpsrld $0, %zmm9, %zmm9
vpandd %zmm7, %zmm9, %zmm9
vcvtfxpntdq2ps $0, %zmm9, %zmm9
vcvtfxpntdq2ps $0, 484(%rsi){1to16}, %zmm10
vmulps %zmm10, %zmm9, %zmm9
vfmadd231ps %zmm11, %zmm9, %zmm13
vmovaps 160(%rdx){sint8}, %zmm11
vmovdqa32 64(%rdi){uint8}, %zmm9
vpsrld $4, %zmm9, %zmm9
vpandd %zmm7, %zmm9, %zmm9
vcvtfxpntdq2ps $0, %zmm9, %zmm9
vcvtfxpntdq2ps $0, 488(%rdi){1to16}, %zmm10
vmulps %zmm10, %zmm9, %zmm9
vfmadd231ps %zmm11, %zmm9, %zmm2
vmovdqa32 64(%rsi){uint8}, %zmm9
vpsrld $4, %zmm9, %zmm9
vpandd %zmm7, %zmm9, %zmm9
vcvtfxpntdq2ps $0, %zmm9, %zmm9
vcvtfxpntdq2ps $0, 488(%rsi){1to16}, %zmm10
vmulps %zmm10, %zmm9, %zmm9
vfmadd231ps %zmm11, %zmm9, %zmm14
vmovaps 176(%rdx){sint8}, %zmm11
vmovdqa32 80(%rdi){uint8}, %zmm9
vpsrld $4, %zmm9, %zmm9
vpandd %zmm7, %zmm9, %zmm9
vcvtfxpntdq2ps $0, %zmm9, %zmm9
vcvtfxpntdq2ps $0, 492(%rdi){1to16}, %zmm10
vmulps %zmm10, %zmm9, %zmm9
vfmadd231ps %zmm11, %zmm9, %zmm3
vmovdqa32 80(%rsi){uint8}, %zmm9
vpsrld $4, %zmm9, %zmm9
vpandd %zmm7, %zmm9, %zmm9
vcvtfxpntdq2ps $0, %zmm9, %zmm9
vcvtfxpntdq2ps $0, 492(%rsi){1to16}, %zmm10
vmulps %zmm10, %zmm9, %zmm9
vfmadd231ps %zmm11, %zmm9, %zmm15
vmovaps 192(%rdx){sint8}, %zmm11
cmpq $1, %r10
jbe .Lpair4_192_0
vprefetch0 192(%rcx)
vprefetch0 192(%r8)
vprefetch0 360(%r9)
.Lpair4_192_0:
cmpq $2, %r10
jbe .Lpair4_192_1
vprefetch1 400(%rcx)
vprefetch1 400(%r8)
vprefetch1 780(%r9)
.Lpair4_192_1:
vmovdqa32 96(%rdi){uint8}, %zmm9
vpsrld $0, %zmm9, %zmm9
vpandd %zmm7, %zmm9, %zmm9
vcvtfxpntdq2ps $0, %zmm9, %zmm9
vcvtfxpntdq2ps $0, 496(%rdi){1to16}, %zmm10
vmulps %zmm10, %zmm9, %zmm9
vfmadd231ps %zmm11, %zmm9, %zmm0
vmovdqa32 96(%rsi){uint8}, %zmm9
vpsrld $0, %zmm9, %zmm9
vpandd %zmm7, %zmm9, %zmm9
vcvtfxpntdq2ps $0, %zmm9, %zmm9
vcvtfxpntdq2ps $0, 496(%rsi){1to16}, %zmm10
vmulps %zmm10, %zmm9, %zmm9
vfmadd231ps %zmm11, %zmm9, %zmm12
vmovaps 208(%rdx){sint8}, %zmm11
vmovdqa32 112(%rdi){uint8}, %zmm9
vpsrld $0, %zmm9, %zmm9
vpandd %zmm7, %zmm9, %zmm9
vcvtfxpntdq2ps $0, %zmm9, %zmm9
vcvtfxpntdq2ps $0, 500(%rdi){1to16}, %zmm10
vmulps %zmm10, %zmm9, %zmm9
vfmadd231ps %zmm11, %zmm9, %zmm1
vmovdqa32 112(%rsi){uint8}, %zmm9
vpsrld $0, %zmm9, %zmm9
vpandd %zmm7, %zmm9, %zmm9
vcvtfxpntdq2ps $0, %zmm9, %zmm9
vcvtfxpntdq2ps $0, 500(%rsi){1to16}, %zmm10
vmulps %zmm10, %zmm9, %zmm9
vfmadd231ps %zmm11, %zmm9, %zmm13
vmovaps 224(%rdx){sint8}, %zmm11
vmovdqa32 96(%rdi){uint8}, %zmm9
vpsrld $4, %zmm9, %zmm9
vpandd %zmm7, %zmm9, %zmm9
vcvtfxpntdq2ps $0, %zmm9, %zmm9
vcvtfxpntdq2ps $0, 504(%rdi){1to16}, %zmm10
vmulps %zmm10, %zmm9, %zmm9
vfmadd231ps %zmm11, %zmm9, %zmm2
vmovdqa32 96(%rsi){uint8}, %zmm9
vpsrld $4, %zmm9, %zmm9
vpandd %zmm7, %zmm9, %zmm9
vcvtfxpntdq2ps $0, %zmm9, %zmm9
vcvtfxpntdq2ps $0, 504(%rsi){1to16}, %zmm10
vmulps %zmm10, %zmm9, %zmm9
vfmadd231ps %zmm11, %zmm9, %zmm14
vmovaps 240(%rdx){sint8}, %zmm11
vmovdqa32 112(%rdi){uint8}, %zmm9
vpsrld $4, %zmm9, %zmm9
vpandd %zmm7, %zmm9, %zmm9
vcvtfxpntdq2ps $0, %zmm9, %zmm9
vcvtfxpntdq2ps $0, 508(%rdi){1to16}, %zmm10
vmulps %zmm10, %zmm9, %zmm9
vfmadd231ps %zmm11, %zmm9, %zmm3
vmovdqa32 112(%rsi){uint8}, %zmm9
vpsrld $4, %zmm9, %zmm9
vpandd %zmm7, %zmm9, %zmm9
vcvtfxpntdq2ps $0, %zmm9, %zmm9
vcvtfxpntdq2ps $0, 508(%rsi){1to16}, %zmm10
vmulps %zmm10, %zmm9, %zmm9
vfmadd231ps %zmm11, %zmm9, %zmm15
vaddps %zmm1, %zmm0, %zmm0
vaddps %zmm3, %zmm2, %zmm2
vaddps %zmm2, %zmm0, %zmm0
vcvtfxpntps2dq $0, %zmm0, %zmm0
vpermf32x4 $0x4e, %zmm0, %zmm4
vpaddd %zmm4, %zmm0, %zmm0
vpermf32x4 $0xb1, %zmm0, %zmm4
vpaddd %zmm4, %zmm0, %zmm0
vpshufd $0x4e, %zmm0, %zmm4
vpaddd %zmm4, %zmm0, %zmm0
vpshufd $0xb1, %zmm0, %zmm4
vpaddd %zmm4, %zmm0, %zmm0
vmovdqa32 %zmm0, 512(%rdi)
vaddps %zmm13, %zmm12, %zmm12
vaddps %zmm15, %zmm14, %zmm14
vaddps %zmm14, %zmm12, %zmm12
vcvtfxpntps2dq $0, %zmm12, %zmm12
vpermf32x4 $0x4e, %zmm12, %zmm4
vpaddd %zmm4, %zmm12, %zmm12
vpermf32x4 $0xb1, %zmm12, %zmm4
vpaddd %zmm4, %zmm12, %zmm12
vpshufd $0x4e, %zmm12, %zmm4
vpaddd %zmm4, %zmm12, %zmm12
vpshufd $0xb1, %zmm12, %zmm4
vpaddd %zmm4, %zmm12, %zmm12
vmovdqa32 %zmm12, 512(%rsi)
ret
.size ggml_knc_q4_pair_native, .-ggml_knc_q4_pair_native
.p2align 4
.globl ggml_knc_q5_pair_native
.type ggml_knc_q5_pair_native, @function
ggml_knc_q5_pair_native:
/* scratch0=rdi, scratch1=rsi, Q8=rdx, packed0=rcx, packed1=r8, packedQ8=r9; remaining is arg7. */
movq 8(%rsp), %r10
vpxord %zmm0, %zmm0, %zmm0
vpxord %zmm1, %zmm1, %zmm1
vpxord %zmm2, %zmm2, %zmm2
vpxord %zmm3, %zmm3, %zmm3
vpxord %zmm24, %zmm24, %zmm24
vpxord %zmm25, %zmm25, %zmm25
vpxord %zmm26, %zmm26, %zmm26
vpxord %zmm27, %zmm27, %zmm27
vpbroadcastd .Lmask15(%rip), %zmm4
vpbroadcastd .Lmask1(%rip), %zmm5
vmovdqa32 128(%rdi){uint8}, %zmm6
vmovdqa32 144(%rdi){uint8}, %zmm7
vmovdqa32 128(%rsi){uint8}, %zmm28
vmovdqa32 144(%rsi){uint8}, %zmm29
vmovaps 0(%rdx){sint8}, %zmm14
vmovaps (0+16)(%rdx){sint8}, %zmm15
vmovaps (0+32)(%rdx){sint8}, %zmm16
vmovaps (0+48)(%rdx){sint8}, %zmm17
cmpq $0, %r10
jbe .Lpair5_0_0
vprefetch0 112(%rcx)
vprefetch0 16(%rcx)
vprefetch0 112(%r8)
vprefetch0 16(%r8)
vprefetch0 132(%r9)
.Lpair5_0_0:
cmpq $2, %r10
jbe .Lpair5_0_1
vprefetch1 400(%rcx)
vprefetch1 368(%rcx)
vprefetch1 400(%r8)
vprefetch1 368(%r8)
vprefetch1 588(%r9)
.Lpair5_0_1:
vmovdqa32 0(%rdi){uint8}, %zmm8
vmovdqa32 (0+16)(%rdi){uint8}, %zmm9
vpandd %zmm4, %zmm8, %zmm10
vpandd %zmm4, %zmm9, %zmm11
vpsrld $4, %zmm8, %zmm12
vpsrld $4, %zmm9, %zmm13
vpsrld $0, %zmm6, %zmm20
vpsrld $0, %zmm7, %zmm21
vpsrld $(0+1), %zmm6, %zmm22
vpsrld $(0+1), %zmm7, %zmm23
vpandd %zmm5, %zmm20, %zmm20
vpandd %zmm5, %zmm21, %zmm21
vpandd %zmm5, %zmm22, %zmm22
vpandd %zmm5, %zmm23, %zmm23
vpslld $4, %zmm20, %zmm20
vpslld $4, %zmm21, %zmm21
vpslld $4, %zmm22, %zmm22
vpslld $4, %zmm23, %zmm23
vpord %zmm20, %zmm10, %zmm10
vpord %zmm21, %zmm11, %zmm11
vpord %zmm22, %zmm12, %zmm12
vpord %zmm23, %zmm13, %zmm13
vcvtfxpntdq2ps $0, (448+4*0)(%rdi){1to16}, %zmm18
vcvtfxpntdq2ps $0, (448+4*(0+1))(%rdi){1to16}, %zmm19
vcvtfxpntdq2ps $0, %zmm10, %zmm10
vcvtfxpntdq2ps $0, %zmm11, %zmm11
vcvtfxpntdq2ps $0, %zmm12, %zmm12
vcvtfxpntdq2ps $0, %zmm13, %zmm13
vmulps %zmm18, %zmm10, %zmm10
vmulps %zmm18, %zmm11, %zmm11
vmulps %zmm19, %zmm12, %zmm12
vmulps %zmm19, %zmm13, %zmm13
vfmadd231ps %zmm14, %zmm10, %zmm0
vfmadd231ps %zmm15, %zmm11, %zmm1
vfmadd231ps %zmm16, %zmm12, %zmm2
vfmadd231ps %zmm17, %zmm13, %zmm3
vmovdqa32 0(%rsi){uint8}, %zmm8
vmovdqa32 (0+16)(%rsi){uint8}, %zmm9
vpandd %zmm4, %zmm8, %zmm10
vpandd %zmm4, %zmm9, %zmm11
vpsrld $4, %zmm8, %zmm12
vpsrld $4, %zmm9, %zmm13
vpsrld $0, %zmm28, %zmm20
vpsrld $0, %zmm29, %zmm21
vpsrld $(0+1), %zmm28, %zmm22
vpsrld $(0+1), %zmm29, %zmm23
vpandd %zmm5, %zmm20, %zmm20
vpandd %zmm5, %zmm21, %zmm21
vpandd %zmm5, %zmm22, %zmm22
vpandd %zmm5, %zmm23, %zmm23
vpslld $4, %zmm20, %zmm20
vpslld $4, %zmm21, %zmm21
vpslld $4, %zmm22, %zmm22
vpslld $4, %zmm23, %zmm23
vpord %zmm20, %zmm10, %zmm10
vpord %zmm21, %zmm11, %zmm11
vpord %zmm22, %zmm12, %zmm12
vpord %zmm23, %zmm13, %zmm13
vcvtfxpntdq2ps $0, (448+4*0)(%rsi){1to16}, %zmm18
vcvtfxpntdq2ps $0, (448+4*(0+1))(%rsi){1to16}, %zmm19
vcvtfxpntdq2ps $0, %zmm10, %zmm10
vcvtfxpntdq2ps $0, %zmm11, %zmm11
vcvtfxpntdq2ps $0, %zmm12, %zmm12
vcvtfxpntdq2ps $0, %zmm13, %zmm13
vmulps %zmm18, %zmm10, %zmm10
vmulps %zmm18, %zmm11, %zmm11
vmulps %zmm19, %zmm12, %zmm12
vmulps %zmm19, %zmm13, %zmm13
vfmadd231ps %zmm14, %zmm10, %zmm24
vfmadd231ps %zmm15, %zmm11, %zmm25
vfmadd231ps %zmm16, %zmm12, %zmm26
vfmadd231ps %zmm17, %zmm13, %zmm27
vmovaps 64(%rdx){sint8}, %zmm14
vmovaps (64+16)(%rdx){sint8}, %zmm15
vmovaps (64+32)(%rdx){sint8}, %zmm16
vmovaps (64+48)(%rdx){sint8}, %zmm17
cmpq $0, %r10
jbe .Lpair5_64_0
vprefetch0 144(%rcx)
vprefetch0 16(%rcx)
vprefetch0 144(%r8)
vprefetch0 16(%r8)
vprefetch0 196(%r9)
.Lpair5_64_0:
cmpq $2, %r10
jbe .Lpair5_64_1
vprefetch1 432(%rcx)
vprefetch1 368(%rcx)
vprefetch1 432(%r8)
vprefetch1 368(%r8)
vprefetch1 652(%r9)
.Lpair5_64_1:
vmovdqa32 32(%rdi){uint8}, %zmm8
vmovdqa32 (32+16)(%rdi){uint8}, %zmm9
vpandd %zmm4, %zmm8, %zmm10
vpandd %zmm4, %zmm9, %zmm11
vpsrld $4, %zmm8, %zmm12
vpsrld $4, %zmm9, %zmm13
vpsrld $2, %zmm6, %zmm20
vpsrld $2, %zmm7, %zmm21
vpsrld $(2+1), %zmm6, %zmm22
vpsrld $(2+1), %zmm7, %zmm23
vpandd %zmm5, %zmm20, %zmm20
vpandd %zmm5, %zmm21, %zmm21
vpandd %zmm5, %zmm22, %zmm22
vpandd %zmm5, %zmm23, %zmm23
vpslld $4, %zmm20, %zmm20
vpslld $4, %zmm21, %zmm21
vpslld $4, %zmm22, %zmm22
vpslld $4, %zmm23, %zmm23
vpord %zmm20, %zmm10, %zmm10
vpord %zmm21, %zmm11, %zmm11
vpord %zmm22, %zmm12, %zmm12
vpord %zmm23, %zmm13, %zmm13
vcvtfxpntdq2ps $0, (448+4*2)(%rdi){1to16}, %zmm18
vcvtfxpntdq2ps $0, (448+4*(2+1))(%rdi){1to16}, %zmm19
vcvtfxpntdq2ps $0, %zmm10, %zmm10
vcvtfxpntdq2ps $0, %zmm11, %zmm11
vcvtfxpntdq2ps $0, %zmm12, %zmm12
vcvtfxpntdq2ps $0, %zmm13, %zmm13
vmulps %zmm18, %zmm10, %zmm10
vmulps %zmm18, %zmm11, %zmm11
vmulps %zmm19, %zmm12, %zmm12
vmulps %zmm19, %zmm13, %zmm13
vfmadd231ps %zmm14, %zmm10, %zmm0
vfmadd231ps %zmm15, %zmm11, %zmm1
vfmadd231ps %zmm16, %zmm12, %zmm2
vfmadd231ps %zmm17, %zmm13, %zmm3
vmovdqa32 32(%rsi){uint8}, %zmm8
vmovdqa32 (32+16)(%rsi){uint8}, %zmm9
vpandd %zmm4, %zmm8, %zmm10
vpandd %zmm4, %zmm9, %zmm11
vpsrld $4, %zmm8, %zmm12
vpsrld $4, %zmm9, %zmm13
vpsrld $2, %zmm28, %zmm20
vpsrld $2, %zmm29, %zmm21
vpsrld $(2+1), %zmm28, %zmm22
vpsrld $(2+1), %zmm29, %zmm23
vpandd %zmm5, %zmm20, %zmm20
vpandd %zmm5, %zmm21, %zmm21
vpandd %zmm5, %zmm22, %zmm22
vpandd %zmm5, %zmm23, %zmm23
vpslld $4, %zmm20, %zmm20
vpslld $4, %zmm21, %zmm21
vpslld $4, %zmm22, %zmm22
vpslld $4, %zmm23, %zmm23
vpord %zmm20, %zmm10, %zmm10
vpord %zmm21, %zmm11, %zmm11
vpord %zmm22, %zmm12, %zmm12
vpord %zmm23, %zmm13, %zmm13
vcvtfxpntdq2ps $0, (448+4*2)(%rsi){1to16}, %zmm18
vcvtfxpntdq2ps $0, (448+4*(2+1))(%rsi){1to16}, %zmm19
vcvtfxpntdq2ps $0, %zmm10, %zmm10
vcvtfxpntdq2ps $0, %zmm11, %zmm11
vcvtfxpntdq2ps $0, %zmm12, %zmm12
vcvtfxpntdq2ps $0, %zmm13, %zmm13
vmulps %zmm18, %zmm10, %zmm10
vmulps %zmm18, %zmm11, %zmm11
vmulps %zmm19, %zmm12, %zmm12
vmulps %zmm19, %zmm13, %zmm13
vfmadd231ps %zmm14, %zmm10, %zmm24
vfmadd231ps %zmm15, %zmm11, %zmm25
vfmadd231ps %zmm16, %zmm12, %zmm26
vfmadd231ps %zmm17, %zmm13, %zmm27
vmovaps 128(%rdx){sint8}, %zmm14
vmovaps (128+16)(%rdx){sint8}, %zmm15
vmovaps (128+32)(%rdx){sint8}, %zmm16
vmovaps (128+48)(%rdx){sint8}, %zmm17
cmpq $1, %r10
jbe .Lpair5_128_0
vprefetch0 224(%rcx)
vprefetch0 192(%rcx)
vprefetch0 224(%r8)
vprefetch0 192(%r8)
vprefetch0 296(%r9)
.Lpair5_128_0:
cmpq $2, %r10
jbe .Lpair5_128_1
vprefetch1 464(%rcx)
vprefetch1 368(%rcx)
vprefetch1 464(%r8)
vprefetch1 368(%r8)
vprefetch1 716(%r9)
.Lpair5_128_1:
vmovdqa32 64(%rdi){uint8}, %zmm8
vmovdqa32 (64+16)(%rdi){uint8}, %zmm9
vpandd %zmm4, %zmm8, %zmm10
vpandd %zmm4, %zmm9, %zmm11
vpsrld $4, %zmm8, %zmm12
vpsrld $4, %zmm9, %zmm13
vpsrld $4, %zmm6, %zmm20
vpsrld $4, %zmm7, %zmm21
vpsrld $(4+1), %zmm6, %zmm22
vpsrld $(4+1), %zmm7, %zmm23
vpandd %zmm5, %zmm20, %zmm20
vpandd %zmm5, %zmm21, %zmm21
vpandd %zmm5, %zmm22, %zmm22
vpandd %zmm5, %zmm23, %zmm23
vpslld $4, %zmm20, %zmm20
vpslld $4, %zmm21, %zmm21
vpslld $4, %zmm22, %zmm22
vpslld $4, %zmm23, %zmm23
vpord %zmm20, %zmm10, %zmm10
vpord %zmm21, %zmm11, %zmm11
vpord %zmm22, %zmm12, %zmm12
vpord %zmm23, %zmm13, %zmm13
vcvtfxpntdq2ps $0, (448+4*4)(%rdi){1to16}, %zmm18
vcvtfxpntdq2ps $0, (448+4*(4+1))(%rdi){1to16}, %zmm19
vcvtfxpntdq2ps $0, %zmm10, %zmm10
vcvtfxpntdq2ps $0, %zmm11, %zmm11
vcvtfxpntdq2ps $0, %zmm12, %zmm12
vcvtfxpntdq2ps $0, %zmm13, %zmm13
vmulps %zmm18, %zmm10, %zmm10
vmulps %zmm18, %zmm11, %zmm11
vmulps %zmm19, %zmm12, %zmm12
vmulps %zmm19, %zmm13, %zmm13
vfmadd231ps %zmm14, %zmm10, %zmm0
vfmadd231ps %zmm15, %zmm11, %zmm1
vfmadd231ps %zmm16, %zmm12, %zmm2
vfmadd231ps %zmm17, %zmm13, %zmm3
vmovdqa32 64(%rsi){uint8}, %zmm8
vmovdqa32 (64+16)(%rsi){uint8}, %zmm9
vpandd %zmm4, %zmm8, %zmm10
vpandd %zmm4, %zmm9, %zmm11
vpsrld $4, %zmm8, %zmm12
vpsrld $4, %zmm9, %zmm13
vpsrld $4, %zmm28, %zmm20
vpsrld $4, %zmm29, %zmm21
vpsrld $(4+1), %zmm28, %zmm22
vpsrld $(4+1), %zmm29, %zmm23
vpandd %zmm5, %zmm20, %zmm20
vpandd %zmm5, %zmm21, %zmm21
vpandd %zmm5, %zmm22, %zmm22
vpandd %zmm5, %zmm23, %zmm23
vpslld $4, %zmm20, %zmm20
vpslld $4, %zmm21, %zmm21
vpslld $4, %zmm22, %zmm22
vpslld $4, %zmm23, %zmm23
vpord %zmm20, %zmm10, %zmm10
vpord %zmm21, %zmm11, %zmm11
vpord %zmm22, %zmm12, %zmm12
vpord %zmm23, %zmm13, %zmm13
vcvtfxpntdq2ps $0, (448+4*4)(%rsi){1to16}, %zmm18
vcvtfxpntdq2ps $0, (448+4*(4+1))(%rsi){1to16}, %zmm19
vcvtfxpntdq2ps $0, %zmm10, %zmm10
vcvtfxpntdq2ps $0, %zmm11, %zmm11
vcvtfxpntdq2ps $0, %zmm12, %zmm12
vcvtfxpntdq2ps $0, %zmm13, %zmm13
vmulps %zmm18, %zmm10, %zmm10
vmulps %zmm18, %zmm11, %zmm11
vmulps %zmm19, %zmm12, %zmm12
vmulps %zmm19, %zmm13, %zmm13
vfmadd231ps %zmm14, %zmm10, %zmm24
vfmadd231ps %zmm15, %zmm11, %zmm25
vfmadd231ps %zmm16, %zmm12, %zmm26
vfmadd231ps %zmm17, %zmm13, %zmm27
vmovaps 192(%rdx){sint8}, %zmm14
vmovaps (192+16)(%rdx){sint8}, %zmm15
vmovaps (192+32)(%rdx){sint8}, %zmm16
vmovaps (192+48)(%rdx){sint8}, %zmm17
cmpq $1, %r10
jbe .Lpair5_192_0
vprefetch0 256(%rcx)
vprefetch0 192(%rcx)
vprefetch0 256(%r8)
vprefetch0 192(%r8)
vprefetch0 360(%r9)
.Lpair5_192_0:
cmpq $2, %r10
jbe .Lpair5_192_1
vprefetch1 496(%rcx)
vprefetch1 368(%rcx)
vprefetch1 496(%r8)
vprefetch1 368(%r8)
vprefetch1 780(%r9)
.Lpair5_192_1:
vmovdqa32 96(%rdi){uint8}, %zmm8
vmovdqa32 (96+16)(%rdi){uint8}, %zmm9
vpandd %zmm4, %zmm8, %zmm10
vpandd %zmm4, %zmm9, %zmm11
vpsrld $4, %zmm8, %zmm12
vpsrld $4, %zmm9, %zmm13
vpsrld $6, %zmm6, %zmm20
vpsrld $6, %zmm7, %zmm21
vpsrld $(6+1), %zmm6, %zmm22
vpsrld $(6+1), %zmm7, %zmm23
vpandd %zmm5, %zmm20, %zmm20
vpandd %zmm5, %zmm21, %zmm21
vpandd %zmm5, %zmm22, %zmm22
vpandd %zmm5, %zmm23, %zmm23
vpslld $4, %zmm20, %zmm20
vpslld $4, %zmm21, %zmm21
vpslld $4, %zmm22, %zmm22
vpslld $4, %zmm23, %zmm23
vpord %zmm20, %zmm10, %zmm10
vpord %zmm21, %zmm11, %zmm11
vpord %zmm22, %zmm12, %zmm12
vpord %zmm23, %zmm13, %zmm13
vcvtfxpntdq2ps $0, (448+4*6)(%rdi){1to16}, %zmm18
vcvtfxpntdq2ps $0, (448+4*(6+1))(%rdi){1to16}, %zmm19
vcvtfxpntdq2ps $0, %zmm10, %zmm10
vcvtfxpntdq2ps $0, %zmm11, %zmm11
vcvtfxpntdq2ps $0, %zmm12, %zmm12
vcvtfxpntdq2ps $0, %zmm13, %zmm13
vmulps %zmm18, %zmm10, %zmm10
vmulps %zmm18, %zmm11, %zmm11
vmulps %zmm19, %zmm12, %zmm12
vmulps %zmm19, %zmm13, %zmm13
vfmadd231ps %zmm14, %zmm10, %zmm0
vfmadd231ps %zmm15, %zmm11, %zmm1
vfmadd231ps %zmm16, %zmm12, %zmm2
vfmadd231ps %zmm17, %zmm13, %zmm3
vmovdqa32 96(%rsi){uint8}, %zmm8
vmovdqa32 (96+16)(%rsi){uint8}, %zmm9
vpandd %zmm4, %zmm8, %zmm10
vpandd %zmm4, %zmm9, %zmm11
vpsrld $4, %zmm8, %zmm12
vpsrld $4, %zmm9, %zmm13
vpsrld $6, %zmm28, %zmm20
vpsrld $6, %zmm29, %zmm21
vpsrld $(6+1), %zmm28, %zmm22
vpsrld $(6+1), %zmm29, %zmm23
vpandd %zmm5, %zmm20, %zmm20
vpandd %zmm5, %zmm21, %zmm21
vpandd %zmm5, %zmm22, %zmm22
vpandd %zmm5, %zmm23, %zmm23
vpslld $4, %zmm20, %zmm20
vpslld $4, %zmm21, %zmm21
vpslld $4, %zmm22, %zmm22
vpslld $4, %zmm23, %zmm23
vpord %zmm20, %zmm10, %zmm10
vpord %zmm21, %zmm11, %zmm11
vpord %zmm22, %zmm12, %zmm12
vpord %zmm23, %zmm13, %zmm13
vcvtfxpntdq2ps $0, (448+4*6)(%rsi){1to16}, %zmm18
vcvtfxpntdq2ps $0, (448+4*(6+1))(%rsi){1to16}, %zmm19
vcvtfxpntdq2ps $0, %zmm10, %zmm10
vcvtfxpntdq2ps $0, %zmm11, %zmm11
vcvtfxpntdq2ps $0, %zmm12, %zmm12
vcvtfxpntdq2ps $0, %zmm13, %zmm13
vmulps %zmm18, %zmm10, %zmm10
vmulps %zmm18, %zmm11, %zmm11
vmulps %zmm19, %zmm12, %zmm12
vmulps %zmm19, %zmm13, %zmm13
vfmadd231ps %zmm14, %zmm10, %zmm24
vfmadd231ps %zmm15, %zmm11, %zmm25
vfmadd231ps %zmm16, %zmm12, %zmm26
vfmadd231ps %zmm17, %zmm13, %zmm27
vaddps %zmm1, %zmm0, %zmm0
vaddps %zmm3, %zmm2, %zmm2
vaddps %zmm2, %zmm0, %zmm0
vcvtfxpntps2dq $0, %zmm0, %zmm0
vpermf32x4 $0x4e, %zmm0, %zmm4
vpaddd %zmm4, %zmm0, %zmm0
vpermf32x4 $0xb1, %zmm0, %zmm4
vpaddd %zmm4, %zmm0, %zmm0
vpshufd $0x4e, %zmm0, %zmm4
vpaddd %zmm4, %zmm0, %zmm0
vpshufd $0xb1, %zmm0, %zmm4
vpaddd %zmm4, %zmm0, %zmm0
vmovdqa32 %zmm0, 512(%rdi)
vaddps %zmm25, %zmm24, %zmm24
vaddps %zmm27, %zmm26, %zmm26
vaddps %zmm26, %zmm24, %zmm24
vcvtfxpntps2dq $0, %zmm24, %zmm24
vpermf32x4 $0x4e, %zmm24, %zmm4
vpaddd %zmm4, %zmm24, %zmm24
vpermf32x4 $0xb1, %zmm24, %zmm4
vpaddd %zmm4, %zmm24, %zmm24
vpshufd $0x4e, %zmm24, %zmm4
vpaddd %zmm4, %zmm24, %zmm24
vpshufd $0xb1, %zmm24, %zmm4
vpaddd %zmm4, %zmm24, %zmm24
vmovdqa32 %zmm24, 512(%rsi)
ret
.size ggml_knc_q5_pair_native, .-ggml_knc_q5_pair_native
.p2align 4
.globl ggml_knc_q6_pair_native
.type ggml_knc_q6_pair_native, @function
ggml_knc_q6_pair_native:
/* scratch0=rdi, scratch1=rsi, Q8=rdx, packed0=rcx, packed1=r8, packedQ8=r9; remaining is arg7. */
movq 8(%rsp), %r10
vpxord %zmm0, %zmm0, %zmm0
vpxord %zmm1, %zmm1, %zmm1
vpxord %zmm2, %zmm2, %zmm2
vpxord %zmm3, %zmm3, %zmm3
vpxord %zmm12, %zmm12, %zmm12
vpxord %zmm13, %zmm13, %zmm13
vpxord %zmm14, %zmm14, %zmm14
vpxord %zmm15, %zmm15, %zmm15
vpbroadcastd .Lmask1(%rip), %zmm4
vpbroadcastd .Lmask3(%rip), %zmm5
vpbroadcastd .Lmask4(%rip), %zmm6
vpbroadcastd .Lmask15(%rip), %zmm7
vpbroadcastd .Lmask32(%rip), %zmm8
vmovaps 0(%rdx){sint8}, %zmm11
cmpq $0, %r10
jbe .Lpair6_0_0
vprefetch0 64(%rcx)
vprefetch0 160(%rcx)
vprefetch0 64(%r8)
vprefetch0 160(%r8)
vprefetch0 132(%r9)
.Lpair6_0_0:
cmpq $2, %r10
jbe .Lpair6_0_1
vprefetch1 420(%rcx)
vprefetch1 548(%rcx)
vprefetch1 420(%r8)
vprefetch1 548(%r8)
vprefetch1 588(%r9)
.Lpair6_0_1:
vmovdqa32 0(%rdi){uint8}, %zmm9
vpsrld $0, %zmm9, %zmm9
vpandd %zmm7, %zmm9, %zmm9
vmovdqa32 128(%rdi){uint8}, %zmm10
vpsrld $0, %zmm10, %zmm10
vpandd %zmm5, %zmm10, %zmm10
vpslld $4, %zmm10, %zmm10
vpord %zmm10, %zmm9, %zmm9
vpsubd %zmm8, %zmm9, %zmm9
vcvtfxpntdq2ps $0, %zmm9, %zmm9
vcvtfxpntdq2ps $0, 448(%rdi){1to16}, %zmm10
vmulps %zmm10, %zmm9, %zmm9
vfmadd231ps %zmm11, %zmm9, %zmm0
vmovdqa32 0(%rsi){uint8}, %zmm9
vpsrld $0, %zmm9, %zmm9
vpandd %zmm7, %zmm9, %zmm9
vmovdqa32 128(%rsi){uint8}, %zmm10
vpsrld $0, %zmm10, %zmm10
vpandd %zmm5, %zmm10, %zmm10
vpslld $4, %zmm10, %zmm10
vpord %zmm10, %zmm9, %zmm9
vpsubd %zmm8, %zmm9, %zmm9
vcvtfxpntdq2ps $0, %zmm9, %zmm9
vcvtfxpntdq2ps $0, 448(%rsi){1to16}, %zmm10
vmulps %zmm10, %zmm9, %zmm9
vfmadd231ps %zmm11, %zmm9, %zmm12
vmovaps 16(%rdx){sint8}, %zmm11
vmovdqa32 16(%rdi){uint8}, %zmm9
vpsrld $0, %zmm9, %zmm9
vpandd %zmm7, %zmm9, %zmm9
vmovdqa32 144(%rdi){uint8}, %zmm10
vpsrld $0, %zmm10, %zmm10
vpandd %zmm5, %zmm10, %zmm10
vpslld $4, %zmm10, %zmm10
vpord %zmm10, %zmm9, %zmm9
vpsubd %zmm8, %zmm9, %zmm9
vcvtfxpntdq2ps $0, %zmm9, %zmm9
vcvtfxpntdq2ps $0, 452(%rdi){1to16}, %zmm10
vmulps %zmm10, %zmm9, %zmm9
vfmadd231ps %zmm11, %zmm9, %zmm1
vmovdqa32 16(%rsi){uint8}, %zmm9
vpsrld $0, %zmm9, %zmm9
vpandd %zmm7, %zmm9, %zmm9
vmovdqa32 144(%rsi){uint8}, %zmm10
vpsrld $0, %zmm10, %zmm10
vpandd %zmm5, %zmm10, %zmm10
vpslld $4, %zmm10, %zmm10
vpord %zmm10, %zmm9, %zmm9
vpsubd %zmm8, %zmm9, %zmm9
vcvtfxpntdq2ps $0, %zmm9, %zmm9
vcvtfxpntdq2ps $0, 452(%rsi){1to16}, %zmm10
vmulps %zmm10, %zmm9, %zmm9
vfmadd231ps %zmm11, %zmm9, %zmm13
vmovaps 32(%rdx){sint8}, %zmm11
vmovdqa32 32(%rdi){uint8}, %zmm9
vpsrld $0, %zmm9, %zmm9
vpandd %zmm7, %zmm9, %zmm9
vmovdqa32 128(%rdi){uint8}, %zmm10
vpsrld $2, %zmm10, %zmm10
vpandd %zmm5, %zmm10, %zmm10
vpslld $4, %zmm10, %zmm10
vpord %zmm10, %zmm9, %zmm9
vpsubd %zmm8, %zmm9, %zmm9
vcvtfxpntdq2ps $0, %zmm9, %zmm9
vcvtfxpntdq2ps $0, 456(%rdi){1to16}, %zmm10
vmulps %zmm10, %zmm9, %zmm9
vfmadd231ps %zmm11, %zmm9, %zmm2
vmovdqa32 32(%rsi){uint8}, %zmm9
vpsrld $0, %zmm9, %zmm9
vpandd %zmm7, %zmm9, %zmm9
vmovdqa32 128(%rsi){uint8}, %zmm10
vpsrld $2, %zmm10, %zmm10
vpandd %zmm5, %zmm10, %zmm10
vpslld $4, %zmm10, %zmm10
vpord %zmm10, %zmm9, %zmm9
vpsubd %zmm8, %zmm9, %zmm9
vcvtfxpntdq2ps $0, %zmm9, %zmm9
vcvtfxpntdq2ps $0, 456(%rsi){1to16}, %zmm10
vmulps %zmm10, %zmm9, %zmm9
vfmadd231ps %zmm11, %zmm9, %zmm14
vmovaps 48(%rdx){sint8}, %zmm11
vmovdqa32 48(%rdi){uint8}, %zmm9
vpsrld $0, %zmm9, %zmm9
vpandd %zmm7, %zmm9, %zmm9
vmovdqa32 144(%rdi){uint8}, %zmm10
vpsrld $2, %zmm10, %zmm10
vpandd %zmm5, %zmm10, %zmm10
vpslld $4, %zmm10, %zmm10
vpord %zmm10, %zmm9, %zmm9
vpsubd %zmm8, %zmm9, %zmm9
vcvtfxpntdq2ps $0, %zmm9, %zmm9
vcvtfxpntdq2ps $0, 460(%rdi){1to16}, %zmm10
vmulps %zmm10, %zmm9, %zmm9
vfmadd231ps %zmm11, %zmm9, %zmm3
vmovdqa32 48(%rsi){uint8}, %zmm9
vpsrld $0, %zmm9, %zmm9
vpandd %zmm7, %zmm9, %zmm9
vmovdqa32 144(%rsi){uint8}, %zmm10
vpsrld $2, %zmm10, %zmm10
vpandd %zmm5, %zmm10, %zmm10
vpslld $4, %zmm10, %zmm10
vpord %zmm10, %zmm9, %zmm9
vpsubd %zmm8, %zmm9, %zmm9
vcvtfxpntdq2ps $0, %zmm9, %zmm9
vcvtfxpntdq2ps $0, 460(%rsi){1to16}, %zmm10
vmulps %zmm10, %zmm9, %zmm9
vfmadd231ps %zmm11, %zmm9, %zmm15
vmovaps 64(%rdx){sint8}, %zmm11
cmpq $0, %r10
jbe .Lpair6_64_0
vprefetch0 64(%rcx)
vprefetch0 160(%rcx)
vprefetch0 64(%r8)
vprefetch0 160(%r8)
vprefetch0 196(%r9)
.Lpair6_64_0:
cmpq $2, %r10
jbe .Lpair6_64_1
vprefetch1 420(%rcx)
vprefetch1 548(%rcx)
vprefetch1 420(%r8)
vprefetch1 548(%r8)
vprefetch1 652(%r9)
.Lpair6_64_1:
vmovdqa32 0(%rdi){uint8}, %zmm9
vpsrld $4, %zmm9, %zmm9
vpandd %zmm7, %zmm9, %zmm9
vmovdqa32 128(%rdi){uint8}, %zmm10
vpsrld $4, %zmm10, %zmm10
vpandd %zmm5, %zmm10, %zmm10
vpslld $4, %zmm10, %zmm10
vpord %zmm10, %zmm9, %zmm9
vpsubd %zmm8, %zmm9, %zmm9
vcvtfxpntdq2ps $0, %zmm9, %zmm9
vcvtfxpntdq2ps $0, 464(%rdi){1to16}, %zmm10
vmulps %zmm10, %zmm9, %zmm9
vfmadd231ps %zmm11, %zmm9, %zmm0
vmovdqa32 0(%rsi){uint8}, %zmm9
vpsrld $4, %zmm9, %zmm9
vpandd %zmm7, %zmm9, %zmm9
vmovdqa32 128(%rsi){uint8}, %zmm10
vpsrld $4, %zmm10, %zmm10
vpandd %zmm5, %zmm10, %zmm10
vpslld $4, %zmm10, %zmm10
vpord %zmm10, %zmm9, %zmm9
vpsubd %zmm8, %zmm9, %zmm9
vcvtfxpntdq2ps $0, %zmm9, %zmm9
vcvtfxpntdq2ps $0, 464(%rsi){1to16}, %zmm10
vmulps %zmm10, %zmm9, %zmm9
vfmadd231ps %zmm11, %zmm9, %zmm12
vmovaps 80(%rdx){sint8}, %zmm11
vmovdqa32 16(%rdi){uint8}, %zmm9
vpsrld $4, %zmm9, %zmm9
vpandd %zmm7, %zmm9, %zmm9
vmovdqa32 144(%rdi){uint8}, %zmm10
vpsrld $4, %zmm10, %zmm10
vpandd %zmm5, %zmm10, %zmm10
vpslld $4, %zmm10, %zmm10
vpord %zmm10, %zmm9, %zmm9
vpsubd %zmm8, %zmm9, %zmm9
vcvtfxpntdq2ps $0, %zmm9, %zmm9
vcvtfxpntdq2ps $0, 468(%rdi){1to16}, %zmm10
vmulps %zmm10, %zmm9, %zmm9
vfmadd231ps %zmm11, %zmm9, %zmm1
vmovdqa32 16(%rsi){uint8}, %zmm9
vpsrld $4, %zmm9, %zmm9
vpandd %zmm7, %zmm9, %zmm9
vmovdqa32 144(%rsi){uint8}, %zmm10
vpsrld $4, %zmm10, %zmm10
vpandd %zmm5, %zmm10, %zmm10
vpslld $4, %zmm10, %zmm10
vpord %zmm10, %zmm9, %zmm9
vpsubd %zmm8, %zmm9, %zmm9
vcvtfxpntdq2ps $0, %zmm9, %zmm9
vcvtfxpntdq2ps $0, 468(%rsi){1to16}, %zmm10
vmulps %zmm10, %zmm9, %zmm9
vfmadd231ps %zmm11, %zmm9, %zmm13
vmovaps 96(%rdx){sint8}, %zmm11
vmovdqa32 32(%rdi){uint8}, %zmm9
vpsrld $4, %zmm9, %zmm9
vpandd %zmm7, %zmm9, %zmm9
vmovdqa32 128(%rdi){uint8}, %zmm10
vpsrld $6, %zmm10, %zmm10
vpandd %zmm5, %zmm10, %zmm10
vpslld $4, %zmm10, %zmm10
vpord %zmm10, %zmm9, %zmm9
vpsubd %zmm8, %zmm9, %zmm9
vcvtfxpntdq2ps $0, %zmm9, %zmm9
vcvtfxpntdq2ps $0, 472(%rdi){1to16}, %zmm10
vmulps %zmm10, %zmm9, %zmm9
vfmadd231ps %zmm11, %zmm9, %zmm2
vmovdqa32 32(%rsi){uint8}, %zmm9
vpsrld $4, %zmm9, %zmm9
vpandd %zmm7, %zmm9, %zmm9
vmovdqa32 128(%rsi){uint8}, %zmm10
vpsrld $6, %zmm10, %zmm10
vpandd %zmm5, %zmm10, %zmm10
vpslld $4, %zmm10, %zmm10
vpord %zmm10, %zmm9, %zmm9
vpsubd %zmm8, %zmm9, %zmm9
vcvtfxpntdq2ps $0, %zmm9, %zmm9
vcvtfxpntdq2ps $0, 472(%rsi){1to16}, %zmm10
vmulps %zmm10, %zmm9, %zmm9
vfmadd231ps %zmm11, %zmm9, %zmm14
vmovaps 112(%rdx){sint8}, %zmm11
vmovdqa32 48(%rdi){uint8}, %zmm9
vpsrld $4, %zmm9, %zmm9
vpandd %zmm7, %zmm9, %zmm9
vmovdqa32 144(%rdi){uint8}, %zmm10
vpsrld $6, %zmm10, %zmm10
vpandd %zmm5, %zmm10, %zmm10
vpslld $4, %zmm10, %zmm10
vpord %zmm10, %zmm9, %zmm9
vpsubd %zmm8, %zmm9, %zmm9
vcvtfxpntdq2ps $0, %zmm9, %zmm9
vcvtfxpntdq2ps $0, 476(%rdi){1to16}, %zmm10
vmulps %zmm10, %zmm9, %zmm9
vfmadd231ps %zmm11, %zmm9, %zmm3
vmovdqa32 48(%rsi){uint8}, %zmm9
vpsrld $4, %zmm9, %zmm9
vpandd %zmm7, %zmm9, %zmm9
vmovdqa32 144(%rsi){uint8}, %zmm10
vpsrld $6, %zmm10, %zmm10
vpandd %zmm5, %zmm10, %zmm10
vpslld $4, %zmm10, %zmm10
vpord %zmm10, %zmm9, %zmm9
vpsubd %zmm8, %zmm9, %zmm9
vcvtfxpntdq2ps $0, %zmm9, %zmm9
vcvtfxpntdq2ps $0, 476(%rsi){1to16}, %zmm10
vmulps %zmm10, %zmm9, %zmm9
vfmadd231ps %zmm11, %zmm9, %zmm15
vmovaps 128(%rdx){sint8}, %zmm11
cmpq $1, %r10
jbe .Lpair6_128_0
vprefetch0 210(%rcx)
vprefetch0 338(%rcx)
vprefetch0 210(%r8)
vprefetch0 338(%r8)
vprefetch0 296(%r9)
.Lpair6_128_0:
cmpq $2, %r10
jbe .Lpair6_128_1
vprefetch1 484(%rcx)
vprefetch1 580(%rcx)
vprefetch1 484(%r8)
vprefetch1 580(%r8)
vprefetch1 716(%r9)
.Lpair6_128_1:
vmovdqa32 64(%rdi){uint8}, %zmm9
vpsrld $0, %zmm9, %zmm9
vpandd %zmm7, %zmm9, %zmm9
vmovdqa32 160(%rdi){uint8}, %zmm10
vpsrld $0, %zmm10, %zmm10
vpandd %zmm5, %zmm10, %zmm10
vpslld $4, %zmm10, %zmm10
vpord %zmm10, %zmm9, %zmm9
vpsubd %zmm8, %zmm9, %zmm9
vcvtfxpntdq2ps $0, %zmm9, %zmm9
vcvtfxpntdq2ps $0, 480(%rdi){1to16}, %zmm10
vmulps %zmm10, %zmm9, %zmm9
vfmadd231ps %zmm11, %zmm9, %zmm0
vmovdqa32 64(%rsi){uint8}, %zmm9
vpsrld $0, %zmm9, %zmm9
vpandd %zmm7, %zmm9, %zmm9
vmovdqa32 160(%rsi){uint8}, %zmm10
vpsrld $0, %zmm10, %zmm10
vpandd %zmm5, %zmm10, %zmm10
vpslld $4, %zmm10, %zmm10
vpord %zmm10, %zmm9, %zmm9
vpsubd %zmm8, %zmm9, %zmm9
vcvtfxpntdq2ps $0, %zmm9, %zmm9
vcvtfxpntdq2ps $0, 480(%rsi){1to16}, %zmm10
vmulps %zmm10, %zmm9, %zmm9
vfmadd231ps %zmm11, %zmm9, %zmm12
vmovaps 144(%rdx){sint8}, %zmm11
vmovdqa32 80(%rdi){uint8}, %zmm9
vpsrld $0, %zmm9, %zmm9
vpandd %zmm7, %zmm9, %zmm9
vmovdqa32 176(%rdi){uint8}, %zmm10
vpsrld $0, %zmm10, %zmm10
vpandd %zmm5, %zmm10, %zmm10
vpslld $4, %zmm10, %zmm10
vpord %zmm10, %zmm9, %zmm9
vpsubd %zmm8, %zmm9, %zmm9
vcvtfxpntdq2ps $0, %zmm9, %zmm9
vcvtfxpntdq2ps $0, 484(%rdi){1to16}, %zmm10
vmulps %zmm10, %zmm9, %zmm9
vfmadd231ps %zmm11, %zmm9, %zmm1
vmovdqa32 80(%rsi){uint8}, %zmm9
vpsrld $0, %zmm9, %zmm9
vpandd %zmm7, %zmm9, %zmm9
vmovdqa32 176(%rsi){uint8}, %zmm10
vpsrld $0, %zmm10, %zmm10
vpandd %zmm5, %zmm10, %zmm10
vpslld $4, %zmm10, %zmm10
vpord %zmm10, %zmm9, %zmm9
vpsubd %zmm8, %zmm9, %zmm9
vcvtfxpntdq2ps $0, %zmm9, %zmm9
vcvtfxpntdq2ps $0, 484(%rsi){1to16}, %zmm10
vmulps %zmm10, %zmm9, %zmm9
vfmadd231ps %zmm11, %zmm9, %zmm13
vmovaps 160(%rdx){sint8}, %zmm11
vmovdqa32 96(%rdi){uint8}, %zmm9
vpsrld $0, %zmm9, %zmm9
vpandd %zmm7, %zmm9, %zmm9
vmovdqa32 160(%rdi){uint8}, %zmm10
vpsrld $2, %zmm10, %zmm10
vpandd %zmm5, %zmm10, %zmm10
vpslld $4, %zmm10, %zmm10
vpord %zmm10, %zmm9, %zmm9
vpsubd %zmm8, %zmm9, %zmm9
vcvtfxpntdq2ps $0, %zmm9, %zmm9
vcvtfxpntdq2ps $0, 488(%rdi){1to16}, %zmm10
vmulps %zmm10, %zmm9, %zmm9
vfmadd231ps %zmm11, %zmm9, %zmm2
vmovdqa32 96(%rsi){uint8}, %zmm9
vpsrld $0, %zmm9, %zmm9
vpandd %zmm7, %zmm9, %zmm9
vmovdqa32 160(%rsi){uint8}, %zmm10
vpsrld $2, %zmm10, %zmm10
vpandd %zmm5, %zmm10, %zmm10
vpslld $4, %zmm10, %zmm10
vpord %zmm10, %zmm9, %zmm9
vpsubd %zmm8, %zmm9, %zmm9
vcvtfxpntdq2ps $0, %zmm9, %zmm9
vcvtfxpntdq2ps $0, 488(%rsi){1to16}, %zmm10
vmulps %zmm10, %zmm9, %zmm9
vfmadd231ps %zmm11, %zmm9, %zmm14
vmovaps 176(%rdx){sint8}, %zmm11
vmovdqa32 112(%rdi){uint8}, %zmm9
vpsrld $0, %zmm9, %zmm9
vpandd %zmm7, %zmm9, %zmm9
vmovdqa32 176(%rdi){uint8}, %zmm10
vpsrld $2, %zmm10, %zmm10
vpandd %zmm5, %zmm10, %zmm10
vpslld $4, %zmm10, %zmm10
vpord %zmm10, %zmm9, %zmm9
vpsubd %zmm8, %zmm9, %zmm9
vcvtfxpntdq2ps $0, %zmm9, %zmm9
vcvtfxpntdq2ps $0, 492(%rdi){1to16}, %zmm10
vmulps %zmm10, %zmm9, %zmm9
vfmadd231ps %zmm11, %zmm9, %zmm3
vmovdqa32 112(%rsi){uint8}, %zmm9
vpsrld $0, %zmm9, %zmm9
vpandd %zmm7, %zmm9, %zmm9
vmovdqa32 176(%rsi){uint8}, %zmm10
vpsrld $2, %zmm10, %zmm10
vpandd %zmm5, %zmm10, %zmm10
vpslld $4, %zmm10, %zmm10
vpord %zmm10, %zmm9, %zmm9
vpsubd %zmm8, %zmm9, %zmm9
vcvtfxpntdq2ps $0, %zmm9, %zmm9
vcvtfxpntdq2ps $0, 492(%rsi){1to16}, %zmm10
vmulps %zmm10, %zmm9, %zmm9
vfmadd231ps %zmm11, %zmm9, %zmm15
vmovaps 192(%rdx){sint8}, %zmm11
cmpq $1, %r10
jbe .Lpair6_192_0
vprefetch0 210(%rcx)
vprefetch0 338(%rcx)
vprefetch0 210(%r8)
vprefetch0 338(%r8)
vprefetch0 360(%r9)
.Lpair6_192_0:
cmpq $2, %r10
jbe .Lpair6_192_1
vprefetch1 484(%rcx)
vprefetch1 580(%rcx)
vprefetch1 484(%r8)
vprefetch1 580(%r8)
vprefetch1 780(%r9)
.Lpair6_192_1:
vmovdqa32 64(%rdi){uint8}, %zmm9
vpsrld $4, %zmm9, %zmm9
vpandd %zmm7, %zmm9, %zmm9
vmovdqa32 160(%rdi){uint8}, %zmm10
vpsrld $4, %zmm10, %zmm10
vpandd %zmm5, %zmm10, %zmm10
vpslld $4, %zmm10, %zmm10
vpord %zmm10, %zmm9, %zmm9
vpsubd %zmm8, %zmm9, %zmm9
vcvtfxpntdq2ps $0, %zmm9, %zmm9
vcvtfxpntdq2ps $0, 496(%rdi){1to16}, %zmm10
vmulps %zmm10, %zmm9, %zmm9
vfmadd231ps %zmm11, %zmm9, %zmm0
vmovdqa32 64(%rsi){uint8}, %zmm9
vpsrld $4, %zmm9, %zmm9
vpandd %zmm7, %zmm9, %zmm9
vmovdqa32 160(%rsi){uint8}, %zmm10
vpsrld $4, %zmm10, %zmm10
vpandd %zmm5, %zmm10, %zmm10
vpslld $4, %zmm10, %zmm10
vpord %zmm10, %zmm9, %zmm9
vpsubd %zmm8, %zmm9, %zmm9
vcvtfxpntdq2ps $0, %zmm9, %zmm9
vcvtfxpntdq2ps $0, 496(%rsi){1to16}, %zmm10
vmulps %zmm10, %zmm9, %zmm9
vfmadd231ps %zmm11, %zmm9, %zmm12
vmovaps 208(%rdx){sint8}, %zmm11
vmovdqa32 80(%rdi){uint8}, %zmm9
vpsrld $4, %zmm9, %zmm9
vpandd %zmm7, %zmm9, %zmm9
vmovdqa32 176(%rdi){uint8}, %zmm10
vpsrld $4, %zmm10, %zmm10
vpandd %zmm5, %zmm10, %zmm10
vpslld $4, %zmm10, %zmm10
vpord %zmm10, %zmm9, %zmm9
vpsubd %zmm8, %zmm9, %zmm9
vcvtfxpntdq2ps $0, %zmm9, %zmm9
vcvtfxpntdq2ps $0, 500(%rdi){1to16}, %zmm10
vmulps %zmm10, %zmm9, %zmm9
vfmadd231ps %zmm11, %zmm9, %zmm1
vmovdqa32 80(%rsi){uint8}, %zmm9
vpsrld $4, %zmm9, %zmm9
vpandd %zmm7, %zmm9, %zmm9
vmovdqa32 176(%rsi){uint8}, %zmm10
vpsrld $4, %zmm10, %zmm10
vpandd %zmm5, %zmm10, %zmm10
vpslld $4, %zmm10, %zmm10
vpord %zmm10, %zmm9, %zmm9
vpsubd %zmm8, %zmm9, %zmm9
vcvtfxpntdq2ps $0, %zmm9, %zmm9
vcvtfxpntdq2ps $0, 500(%rsi){1to16}, %zmm10
vmulps %zmm10, %zmm9, %zmm9
vfmadd231ps %zmm11, %zmm9, %zmm13
vmovaps 224(%rdx){sint8}, %zmm11
vmovdqa32 96(%rdi){uint8}, %zmm9
vpsrld $4, %zmm9, %zmm9
vpandd %zmm7, %zmm9, %zmm9
vmovdqa32 160(%rdi){uint8}, %zmm10
vpsrld $6, %zmm10, %zmm10
vpandd %zmm5, %zmm10, %zmm10
vpslld $4, %zmm10, %zmm10
vpord %zmm10, %zmm9, %zmm9
vpsubd %zmm8, %zmm9, %zmm9
vcvtfxpntdq2ps $0, %zmm9, %zmm9
vcvtfxpntdq2ps $0, 504(%rdi){1to16}, %zmm10
vmulps %zmm10, %zmm9, %zmm9
vfmadd231ps %zmm11, %zmm9, %zmm2
vmovdqa32 96(%rsi){uint8}, %zmm9
vpsrld $4, %zmm9, %zmm9
vpandd %zmm7, %zmm9, %zmm9
vmovdqa32 160(%rsi){uint8}, %zmm10
vpsrld $6, %zmm10, %zmm10
vpandd %zmm5, %zmm10, %zmm10
vpslld $4, %zmm10, %zmm10
vpord %zmm10, %zmm9, %zmm9
vpsubd %zmm8, %zmm9, %zmm9
vcvtfxpntdq2ps $0, %zmm9, %zmm9
vcvtfxpntdq2ps $0, 504(%rsi){1to16}, %zmm10
vmulps %zmm10, %zmm9, %zmm9
vfmadd231ps %zmm11, %zmm9, %zmm14
vmovaps 240(%rdx){sint8}, %zmm11
vmovdqa32 112(%rdi){uint8}, %zmm9
vpsrld $4, %zmm9, %zmm9
vpandd %zmm7, %zmm9, %zmm9
vmovdqa32 176(%rdi){uint8}, %zmm10
vpsrld $6, %zmm10, %zmm10
vpandd %zmm5, %zmm10, %zmm10
vpslld $4, %zmm10, %zmm10
vpord %zmm10, %zmm9, %zmm9
vpsubd %zmm8, %zmm9, %zmm9
vcvtfxpntdq2ps $0, %zmm9, %zmm9
vcvtfxpntdq2ps $0, 508(%rdi){1to16}, %zmm10
vmulps %zmm10, %zmm9, %zmm9
vfmadd231ps %zmm11, %zmm9, %zmm3
vmovdqa32 112(%rsi){uint8}, %zmm9
vpsrld $4, %zmm9, %zmm9
vpandd %zmm7, %zmm9, %zmm9
vmovdqa32 176(%rsi){uint8}, %zmm10
vpsrld $6, %zmm10, %zmm10
vpandd %zmm5, %zmm10, %zmm10
vpslld $4, %zmm10, %zmm10
vpord %zmm10, %zmm9, %zmm9
vpsubd %zmm8, %zmm9, %zmm9
vcvtfxpntdq2ps $0, %zmm9, %zmm9
vcvtfxpntdq2ps $0, 508(%rsi){1to16}, %zmm10
vmulps %zmm10, %zmm9, %zmm9
vfmadd231ps %zmm11, %zmm9, %zmm15
vaddps %zmm1, %zmm0, %zmm0
vaddps %zmm3, %zmm2, %zmm2
vaddps %zmm2, %zmm0, %zmm0
vcvtfxpntps2dq $0, %zmm0, %zmm0
vpermf32x4 $0x4e, %zmm0, %zmm4
vpaddd %zmm4, %zmm0, %zmm0
vpermf32x4 $0xb1, %zmm0, %zmm4
vpaddd %zmm4, %zmm0, %zmm0
vpshufd $0x4e, %zmm0, %zmm4
vpaddd %zmm4, %zmm0, %zmm0
vpshufd $0xb1, %zmm0, %zmm4
vpaddd %zmm4, %zmm0, %zmm0
vmovdqa32 %zmm0, 512(%rdi)
vaddps %zmm13, %zmm12, %zmm12
vaddps %zmm15, %zmm14, %zmm14
vaddps %zmm14, %zmm12, %zmm12
vcvtfxpntps2dq $0, %zmm12, %zmm12
vpermf32x4 $0x4e, %zmm12, %zmm4
vpaddd %zmm4, %zmm12, %zmm12
vpermf32x4 $0xb1, %zmm12, %zmm4
vpaddd %zmm4, %zmm12, %zmm12
vpshufd $0x4e, %zmm12, %zmm4
vpaddd %zmm4, %zmm12, %zmm12
vpshufd $0xb1, %zmm12, %zmm4
vpaddd %zmm4, %zmm12, %zmm12
vmovdqa32 %zmm12, 512(%rsi)
ret
.size ggml_knc_q6_pair_native, .-ggml_knc_q6_pair_native
.section .rodata
.p2align 2
.Lmask1:
.long 1
.Lmask3:
.long 3
.Lmask4:
.long 4
.Lmask15:
.long 15
.Lmask32:
.long 32
.section .note.GNU-stack,"",@progbits
