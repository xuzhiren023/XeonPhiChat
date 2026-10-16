/* SPDX-License-Identifier: MIT */
#if !defined(__k1om__) || !defined(__KNC__) || defined(__AVX512F__)
#error Native KNC required
#endif
.text
.p2align 4
.globl ggml_knc_q3_wide_native
.type ggml_knc_q3_wide_native,@function
ggml_knc_q3_wide_native:
movq 8(%rsp),%r10
cmpq $1,%r10
jbe .Lskip3
vprefetch0 110(%r9)
.Lskip3:
vpxord %zmm12,%zmm12,%zmm12
vpxord %zmm13,%zmm13,%zmm13
vpxord %zmm14,%zmm14,%zmm14
vpxord %zmm15,%zmm15,%zmm15
vpxord %zmm16,%zmm16,%zmm16
vpxord %zmm17,%zmm17,%zmm17
vpxord %zmm18,%zmm18,%zmm18
vpxord %zmm19,%zmm19,%zmm19
vpxord %zmm20,%zmm20,%zmm20
vpxord %zmm21,%zmm21,%zmm21
vpxord %zmm22,%zmm22,%zmm22
vpxord %zmm23,%zmm23,%zmm23
vpxord %zmm24,%zmm24,%zmm24
vpxord %zmm25,%zmm25,%zmm25
vpxord %zmm26,%zmm26,%zmm26
vpxord %zmm27,%zmm27,%zmm27
vpbroadcastd .Lmask1(%rip), %zmm4
vpbroadcastd .Lmask3(%rip), %zmm5
vpbroadcastd .Lmask4(%rip), %zmm6
vpbroadcastd .Lmask15(%rip), %zmm7
vpbroadcastd .Lmask32(%rip), %zmm8
vmovdqa32 0(%rdi){uint8}, %zmm9
vpsrld $0, %zmm9, %zmm9
vpandd %zmm5, %zmm9, %zmm9
vmovdqa32 0(%rsi){uint8}, %zmm10
vpsrld $0, %zmm10, %zmm10
vpandd %zmm4, %zmm10, %zmm10
vpslld $2, %zmm10, %zmm10
vpord %zmm10, %zmm9, %zmm9
vpsubd %zmm6, %zmm9, %zmm9
vcvtfxpntdq2ps $0, %zmm9, %zmm9
vcvtfxpntdq2ps $0, 0(%rcx){1to16}, %zmm10
vmulps %zmm10, %zmm9, %zmm9
vmovaps 0(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm12
vmovaps 256(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm13
vmovaps 512(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm14
vmovaps 768(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm15
vmovaps 1024(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm16
vmovaps 1280(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm17
vmovaps 1536(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm18
vmovaps 1792(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm19
vmovaps 2048(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm20
vmovaps 2304(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm21
vmovaps 2560(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm22
vmovaps 2816(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm23
vmovaps 3072(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm24
vmovaps 3328(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm25
vmovaps 3584(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm26
vmovaps 3840(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm27
vmovdqa32 16(%rdi){uint8}, %zmm9
vpsrld $0, %zmm9, %zmm9
vpandd %zmm5, %zmm9, %zmm9
vmovdqa32 16(%rsi){uint8}, %zmm10
vpsrld $0, %zmm10, %zmm10
vpandd %zmm4, %zmm10, %zmm10
vpslld $2, %zmm10, %zmm10
vpord %zmm10, %zmm9, %zmm9
vpsubd %zmm6, %zmm9, %zmm9
vcvtfxpntdq2ps $0, %zmm9, %zmm9
vcvtfxpntdq2ps $0, 4(%rcx){1to16}, %zmm10
vmulps %zmm10, %zmm9, %zmm9
vmovaps 16(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm12
vmovaps 272(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm13
vmovaps 528(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm14
vmovaps 784(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm15
vmovaps 1040(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm16
vmovaps 1296(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm17
vmovaps 1552(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm18
vmovaps 1808(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm19
vmovaps 2064(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm20
vmovaps 2320(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm21
vmovaps 2576(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm22
vmovaps 2832(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm23
vmovaps 3088(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm24
vmovaps 3344(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm25
vmovaps 3600(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm26
vmovaps 3856(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm27
vmovdqa32 0(%rdi){uint8}, %zmm9
vpsrld $2, %zmm9, %zmm9
vpandd %zmm5, %zmm9, %zmm9
vmovdqa32 0(%rsi){uint8}, %zmm10
vpsrld $1, %zmm10, %zmm10
vpandd %zmm4, %zmm10, %zmm10
vpslld $2, %zmm10, %zmm10
vpord %zmm10, %zmm9, %zmm9
vpsubd %zmm6, %zmm9, %zmm9
vcvtfxpntdq2ps $0, %zmm9, %zmm9
vcvtfxpntdq2ps $0, 8(%rcx){1to16}, %zmm10
vmulps %zmm10, %zmm9, %zmm9
vmovaps 32(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm12
vmovaps 288(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm13
vmovaps 544(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm14
vmovaps 800(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm15
vmovaps 1056(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm16
vmovaps 1312(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm17
vmovaps 1568(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm18
vmovaps 1824(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm19
vmovaps 2080(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm20
vmovaps 2336(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm21
vmovaps 2592(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm22
vmovaps 2848(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm23
vmovaps 3104(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm24
vmovaps 3360(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm25
vmovaps 3616(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm26
vmovaps 3872(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm27
vmovdqa32 16(%rdi){uint8}, %zmm9
vpsrld $2, %zmm9, %zmm9
vpandd %zmm5, %zmm9, %zmm9
vmovdqa32 16(%rsi){uint8}, %zmm10
vpsrld $1, %zmm10, %zmm10
vpandd %zmm4, %zmm10, %zmm10
vpslld $2, %zmm10, %zmm10
vpord %zmm10, %zmm9, %zmm9
vpsubd %zmm6, %zmm9, %zmm9
vcvtfxpntdq2ps $0, %zmm9, %zmm9
vcvtfxpntdq2ps $0, 12(%rcx){1to16}, %zmm10
vmulps %zmm10, %zmm9, %zmm9
vmovaps 48(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm12
vmovaps 304(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm13
vmovaps 560(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm14
vmovaps 816(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm15
vmovaps 1072(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm16
vmovaps 1328(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm17
vmovaps 1584(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm18
vmovaps 1840(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm19
vmovaps 2096(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm20
vmovaps 2352(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm21
vmovaps 2608(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm22
vmovaps 2864(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm23
vmovaps 3120(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm24
vmovaps 3376(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm25
vmovaps 3632(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm26
vmovaps 3888(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm27
vmovdqa32 0(%rdi){uint8}, %zmm9
vpsrld $4, %zmm9, %zmm9
vpandd %zmm5, %zmm9, %zmm9
vmovdqa32 0(%rsi){uint8}, %zmm10
vpsrld $2, %zmm10, %zmm10
vpandd %zmm4, %zmm10, %zmm10
vpslld $2, %zmm10, %zmm10
vpord %zmm10, %zmm9, %zmm9
vpsubd %zmm6, %zmm9, %zmm9
vcvtfxpntdq2ps $0, %zmm9, %zmm9
vcvtfxpntdq2ps $0, 16(%rcx){1to16}, %zmm10
vmulps %zmm10, %zmm9, %zmm9
vmovaps 64(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm12
vmovaps 320(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm13
vmovaps 576(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm14
vmovaps 832(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm15
vmovaps 1088(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm16
vmovaps 1344(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm17
vmovaps 1600(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm18
vmovaps 1856(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm19
vmovaps 2112(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm20
vmovaps 2368(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm21
vmovaps 2624(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm22
vmovaps 2880(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm23
vmovaps 3136(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm24
vmovaps 3392(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm25
vmovaps 3648(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm26
vmovaps 3904(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm27
vmovdqa32 16(%rdi){uint8}, %zmm9
vpsrld $4, %zmm9, %zmm9
vpandd %zmm5, %zmm9, %zmm9
vmovdqa32 16(%rsi){uint8}, %zmm10
vpsrld $2, %zmm10, %zmm10
vpandd %zmm4, %zmm10, %zmm10
vpslld $2, %zmm10, %zmm10
vpord %zmm10, %zmm9, %zmm9
vpsubd %zmm6, %zmm9, %zmm9
vcvtfxpntdq2ps $0, %zmm9, %zmm9
vcvtfxpntdq2ps $0, 20(%rcx){1to16}, %zmm10
vmulps %zmm10, %zmm9, %zmm9
vmovaps 80(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm12
vmovaps 336(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm13
vmovaps 592(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm14
vmovaps 848(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm15
vmovaps 1104(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm16
vmovaps 1360(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm17
vmovaps 1616(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm18
vmovaps 1872(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm19
vmovaps 2128(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm20
vmovaps 2384(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm21
vmovaps 2640(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm22
vmovaps 2896(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm23
vmovaps 3152(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm24
vmovaps 3408(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm25
vmovaps 3664(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm26
vmovaps 3920(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm27
vmovdqa32 0(%rdi){uint8}, %zmm9
vpsrld $6, %zmm9, %zmm9
vpandd %zmm5, %zmm9, %zmm9
vmovdqa32 0(%rsi){uint8}, %zmm10
vpsrld $3, %zmm10, %zmm10
vpandd %zmm4, %zmm10, %zmm10
vpslld $2, %zmm10, %zmm10
vpord %zmm10, %zmm9, %zmm9
vpsubd %zmm6, %zmm9, %zmm9
vcvtfxpntdq2ps $0, %zmm9, %zmm9
vcvtfxpntdq2ps $0, 24(%rcx){1to16}, %zmm10
vmulps %zmm10, %zmm9, %zmm9
vmovaps 96(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm12
vmovaps 352(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm13
vmovaps 608(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm14
vmovaps 864(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm15
vmovaps 1120(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm16
vmovaps 1376(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm17
vmovaps 1632(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm18
vmovaps 1888(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm19
vmovaps 2144(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm20
vmovaps 2400(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm21
vmovaps 2656(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm22
vmovaps 2912(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm23
vmovaps 3168(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm24
vmovaps 3424(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm25
vmovaps 3680(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm26
vmovaps 3936(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm27
vmovdqa32 16(%rdi){uint8}, %zmm9
vpsrld $6, %zmm9, %zmm9
vpandd %zmm5, %zmm9, %zmm9
vmovdqa32 16(%rsi){uint8}, %zmm10
vpsrld $3, %zmm10, %zmm10
vpandd %zmm4, %zmm10, %zmm10
vpslld $2, %zmm10, %zmm10
vpord %zmm10, %zmm9, %zmm9
vpsubd %zmm6, %zmm9, %zmm9
vcvtfxpntdq2ps $0, %zmm9, %zmm9
vcvtfxpntdq2ps $0, 28(%rcx){1to16}, %zmm10
vmulps %zmm10, %zmm9, %zmm9
vmovaps 112(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm12
vmovaps 368(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm13
vmovaps 624(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm14
vmovaps 880(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm15
vmovaps 1136(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm16
vmovaps 1392(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm17
vmovaps 1648(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm18
vmovaps 1904(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm19
vmovaps 2160(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm20
vmovaps 2416(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm21
vmovaps 2672(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm22
vmovaps 2928(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm23
vmovaps 3184(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm24
vmovaps 3440(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm25
vmovaps 3696(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm26
vmovaps 3952(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm27
vmovdqa32 32(%rdi){uint8}, %zmm9
vpsrld $0, %zmm9, %zmm9
vpandd %zmm5, %zmm9, %zmm9
vmovdqa32 0(%rsi){uint8}, %zmm10
vpsrld $4, %zmm10, %zmm10
vpandd %zmm4, %zmm10, %zmm10
vpslld $2, %zmm10, %zmm10
vpord %zmm10, %zmm9, %zmm9
vpsubd %zmm6, %zmm9, %zmm9
vcvtfxpntdq2ps $0, %zmm9, %zmm9
vcvtfxpntdq2ps $0, 32(%rcx){1to16}, %zmm10
vmulps %zmm10, %zmm9, %zmm9
vmovaps 128(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm12
vmovaps 384(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm13
vmovaps 640(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm14
vmovaps 896(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm15
vmovaps 1152(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm16
vmovaps 1408(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm17
vmovaps 1664(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm18
vmovaps 1920(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm19
vmovaps 2176(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm20
vmovaps 2432(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm21
vmovaps 2688(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm22
vmovaps 2944(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm23
vmovaps 3200(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm24
vmovaps 3456(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm25
vmovaps 3712(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm26
vmovaps 3968(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm27
vmovdqa32 48(%rdi){uint8}, %zmm9
vpsrld $0, %zmm9, %zmm9
vpandd %zmm5, %zmm9, %zmm9
vmovdqa32 16(%rsi){uint8}, %zmm10
vpsrld $4, %zmm10, %zmm10
vpandd %zmm4, %zmm10, %zmm10
vpslld $2, %zmm10, %zmm10
vpord %zmm10, %zmm9, %zmm9
vpsubd %zmm6, %zmm9, %zmm9
vcvtfxpntdq2ps $0, %zmm9, %zmm9
vcvtfxpntdq2ps $0, 36(%rcx){1to16}, %zmm10
vmulps %zmm10, %zmm9, %zmm9
vmovaps 144(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm12
vmovaps 400(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm13
vmovaps 656(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm14
vmovaps 912(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm15
vmovaps 1168(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm16
vmovaps 1424(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm17
vmovaps 1680(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm18
vmovaps 1936(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm19
vmovaps 2192(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm20
vmovaps 2448(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm21
vmovaps 2704(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm22
vmovaps 2960(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm23
vmovaps 3216(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm24
vmovaps 3472(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm25
vmovaps 3728(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm26
vmovaps 3984(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm27
vmovdqa32 32(%rdi){uint8}, %zmm9
vpsrld $2, %zmm9, %zmm9
vpandd %zmm5, %zmm9, %zmm9
vmovdqa32 0(%rsi){uint8}, %zmm10
vpsrld $5, %zmm10, %zmm10
vpandd %zmm4, %zmm10, %zmm10
vpslld $2, %zmm10, %zmm10
vpord %zmm10, %zmm9, %zmm9
vpsubd %zmm6, %zmm9, %zmm9
vcvtfxpntdq2ps $0, %zmm9, %zmm9
vcvtfxpntdq2ps $0, 40(%rcx){1to16}, %zmm10
vmulps %zmm10, %zmm9, %zmm9
vmovaps 160(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm12
vmovaps 416(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm13
vmovaps 672(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm14
vmovaps 928(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm15
vmovaps 1184(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm16
vmovaps 1440(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm17
vmovaps 1696(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm18
vmovaps 1952(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm19
vmovaps 2208(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm20
vmovaps 2464(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm21
vmovaps 2720(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm22
vmovaps 2976(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm23
vmovaps 3232(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm24
vmovaps 3488(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm25
vmovaps 3744(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm26
vmovaps 4000(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm27
vmovdqa32 48(%rdi){uint8}, %zmm9
vpsrld $2, %zmm9, %zmm9
vpandd %zmm5, %zmm9, %zmm9
vmovdqa32 16(%rsi){uint8}, %zmm10
vpsrld $5, %zmm10, %zmm10
vpandd %zmm4, %zmm10, %zmm10
vpslld $2, %zmm10, %zmm10
vpord %zmm10, %zmm9, %zmm9
vpsubd %zmm6, %zmm9, %zmm9
vcvtfxpntdq2ps $0, %zmm9, %zmm9
vcvtfxpntdq2ps $0, 44(%rcx){1to16}, %zmm10
vmulps %zmm10, %zmm9, %zmm9
vmovaps 176(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm12
vmovaps 432(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm13
vmovaps 688(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm14
vmovaps 944(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm15
vmovaps 1200(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm16
vmovaps 1456(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm17
vmovaps 1712(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm18
vmovaps 1968(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm19
vmovaps 2224(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm20
vmovaps 2480(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm21
vmovaps 2736(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm22
vmovaps 2992(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm23
vmovaps 3248(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm24
vmovaps 3504(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm25
vmovaps 3760(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm26
vmovaps 4016(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm27
vmovdqa32 32(%rdi){uint8}, %zmm9
vpsrld $4, %zmm9, %zmm9
vpandd %zmm5, %zmm9, %zmm9
vmovdqa32 0(%rsi){uint8}, %zmm10
vpsrld $6, %zmm10, %zmm10
vpandd %zmm4, %zmm10, %zmm10
vpslld $2, %zmm10, %zmm10
vpord %zmm10, %zmm9, %zmm9
vpsubd %zmm6, %zmm9, %zmm9
vcvtfxpntdq2ps $0, %zmm9, %zmm9
vcvtfxpntdq2ps $0, 48(%rcx){1to16}, %zmm10
vmulps %zmm10, %zmm9, %zmm9
vmovaps 192(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm12
vmovaps 448(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm13
vmovaps 704(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm14
vmovaps 960(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm15
vmovaps 1216(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm16
vmovaps 1472(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm17
vmovaps 1728(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm18
vmovaps 1984(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm19
vmovaps 2240(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm20
vmovaps 2496(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm21
vmovaps 2752(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm22
vmovaps 3008(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm23
vmovaps 3264(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm24
vmovaps 3520(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm25
vmovaps 3776(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm26
vmovaps 4032(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm27
vmovdqa32 48(%rdi){uint8}, %zmm9
vpsrld $4, %zmm9, %zmm9
vpandd %zmm5, %zmm9, %zmm9
vmovdqa32 16(%rsi){uint8}, %zmm10
vpsrld $6, %zmm10, %zmm10
vpandd %zmm4, %zmm10, %zmm10
vpslld $2, %zmm10, %zmm10
vpord %zmm10, %zmm9, %zmm9
vpsubd %zmm6, %zmm9, %zmm9
vcvtfxpntdq2ps $0, %zmm9, %zmm9
vcvtfxpntdq2ps $0, 52(%rcx){1to16}, %zmm10
vmulps %zmm10, %zmm9, %zmm9
vmovaps 208(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm12
vmovaps 464(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm13
vmovaps 720(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm14
vmovaps 976(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm15
vmovaps 1232(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm16
vmovaps 1488(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm17
vmovaps 1744(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm18
vmovaps 2000(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm19
vmovaps 2256(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm20
vmovaps 2512(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm21
vmovaps 2768(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm22
vmovaps 3024(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm23
vmovaps 3280(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm24
vmovaps 3536(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm25
vmovaps 3792(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm26
vmovaps 4048(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm27
vmovdqa32 32(%rdi){uint8}, %zmm9
vpsrld $6, %zmm9, %zmm9
vpandd %zmm5, %zmm9, %zmm9
vmovdqa32 0(%rsi){uint8}, %zmm10
vpsrld $7, %zmm10, %zmm10
vpandd %zmm4, %zmm10, %zmm10
vpslld $2, %zmm10, %zmm10
vpord %zmm10, %zmm9, %zmm9
vpsubd %zmm6, %zmm9, %zmm9
vcvtfxpntdq2ps $0, %zmm9, %zmm9
vcvtfxpntdq2ps $0, 56(%rcx){1to16}, %zmm10
vmulps %zmm10, %zmm9, %zmm9
vmovaps 224(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm12
vmovaps 480(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm13
vmovaps 736(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm14
vmovaps 992(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm15
vmovaps 1248(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm16
vmovaps 1504(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm17
vmovaps 1760(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm18
vmovaps 2016(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm19
vmovaps 2272(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm20
vmovaps 2528(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm21
vmovaps 2784(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm22
vmovaps 3040(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm23
vmovaps 3296(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm24
vmovaps 3552(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm25
vmovaps 3808(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm26
vmovaps 4064(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm27
vmovdqa32 48(%rdi){uint8}, %zmm9
vpsrld $6, %zmm9, %zmm9
vpandd %zmm5, %zmm9, %zmm9
vmovdqa32 16(%rsi){uint8}, %zmm10
vpsrld $7, %zmm10, %zmm10
vpandd %zmm4, %zmm10, %zmm10
vpslld $2, %zmm10, %zmm10
vpord %zmm10, %zmm9, %zmm9
vpsubd %zmm6, %zmm9, %zmm9
vcvtfxpntdq2ps $0, %zmm9, %zmm9
vcvtfxpntdq2ps $0, 60(%rcx){1to16}, %zmm10
vmulps %zmm10, %zmm9, %zmm9
vmovaps 240(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm12
vmovaps 496(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm13
vmovaps 752(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm14
vmovaps 1008(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm15
vmovaps 1264(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm16
vmovaps 1520(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm17
vmovaps 1776(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm18
vmovaps 2032(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm19
vmovaps 2288(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm20
vmovaps 2544(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm21
vmovaps 2800(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm22
vmovaps 3056(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm23
vmovaps 3312(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm24
vmovaps 3568(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm25
vmovaps 3824(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm26
vmovaps 4080(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm27
vcvtfxpntps2dq $0,%zmm12,%zmm12
vmovdqa32 %zmm12,0(%r8)
vcvtfxpntps2dq $0,%zmm13,%zmm13
vmovdqa32 %zmm13,64(%r8)
vcvtfxpntps2dq $0,%zmm14,%zmm14
vmovdqa32 %zmm14,128(%r8)
vcvtfxpntps2dq $0,%zmm15,%zmm15
vmovdqa32 %zmm15,192(%r8)
vcvtfxpntps2dq $0,%zmm16,%zmm16
vmovdqa32 %zmm16,256(%r8)
vcvtfxpntps2dq $0,%zmm17,%zmm17
vmovdqa32 %zmm17,320(%r8)
vcvtfxpntps2dq $0,%zmm18,%zmm18
vmovdqa32 %zmm18,384(%r8)
vcvtfxpntps2dq $0,%zmm19,%zmm19
vmovdqa32 %zmm19,448(%r8)
vcvtfxpntps2dq $0,%zmm20,%zmm20
vmovdqa32 %zmm20,512(%r8)
vcvtfxpntps2dq $0,%zmm21,%zmm21
vmovdqa32 %zmm21,576(%r8)
vcvtfxpntps2dq $0,%zmm22,%zmm22
vmovdqa32 %zmm22,640(%r8)
vcvtfxpntps2dq $0,%zmm23,%zmm23
vmovdqa32 %zmm23,704(%r8)
vcvtfxpntps2dq $0,%zmm24,%zmm24
vmovdqa32 %zmm24,768(%r8)
vcvtfxpntps2dq $0,%zmm25,%zmm25
vmovdqa32 %zmm25,832(%r8)
vcvtfxpntps2dq $0,%zmm26,%zmm26
vmovdqa32 %zmm26,896(%r8)
vcvtfxpntps2dq $0,%zmm27,%zmm27
vmovdqa32 %zmm27,960(%r8)
ret
.size ggml_knc_q3_wide_native,.-ggml_knc_q3_wide_native
.p2align 4
.globl ggml_knc_q4_wide_native
.type ggml_knc_q4_wide_native,@function
ggml_knc_q4_wide_native:
movq 8(%rsp),%r10
cmpq $1,%r10
jbe .Lskip4
vprefetch0 144(%r9)
.Lskip4:
vpxord %zmm12,%zmm12,%zmm12
vpxord %zmm13,%zmm13,%zmm13
vpxord %zmm14,%zmm14,%zmm14
vpxord %zmm15,%zmm15,%zmm15
vpxord %zmm16,%zmm16,%zmm16
vpxord %zmm17,%zmm17,%zmm17
vpxord %zmm18,%zmm18,%zmm18
vpxord %zmm19,%zmm19,%zmm19
vpxord %zmm20,%zmm20,%zmm20
vpxord %zmm21,%zmm21,%zmm21
vpxord %zmm22,%zmm22,%zmm22
vpxord %zmm23,%zmm23,%zmm23
vpxord %zmm24,%zmm24,%zmm24
vpxord %zmm25,%zmm25,%zmm25
vpxord %zmm26,%zmm26,%zmm26
vpxord %zmm27,%zmm27,%zmm27
vpbroadcastd .Lmask1(%rip), %zmm4
vpbroadcastd .Lmask3(%rip), %zmm5
vpbroadcastd .Lmask4(%rip), %zmm6
vpbroadcastd .Lmask15(%rip), %zmm7
vpbroadcastd .Lmask32(%rip), %zmm8
vmovdqa32 0(%rdi){uint8}, %zmm9
vpsrld $0, %zmm9, %zmm9
vpandd %zmm7, %zmm9, %zmm9
vcvtfxpntdq2ps $0, %zmm9, %zmm9
vcvtfxpntdq2ps $0, 0(%rcx){1to16}, %zmm10
vmulps %zmm10, %zmm9, %zmm9
vmovaps 0(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm12
vmovaps 256(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm13
vmovaps 512(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm14
vmovaps 768(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm15
vmovaps 1024(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm16
vmovaps 1280(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm17
vmovaps 1536(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm18
vmovaps 1792(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm19
vmovaps 2048(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm20
vmovaps 2304(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm21
vmovaps 2560(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm22
vmovaps 2816(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm23
vmovaps 3072(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm24
vmovaps 3328(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm25
vmovaps 3584(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm26
vmovaps 3840(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm27
vmovdqa32 16(%rdi){uint8}, %zmm9
vpsrld $0, %zmm9, %zmm9
vpandd %zmm7, %zmm9, %zmm9
vcvtfxpntdq2ps $0, %zmm9, %zmm9
vcvtfxpntdq2ps $0, 4(%rcx){1to16}, %zmm10
vmulps %zmm10, %zmm9, %zmm9
vmovaps 16(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm12
vmovaps 272(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm13
vmovaps 528(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm14
vmovaps 784(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm15
vmovaps 1040(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm16
vmovaps 1296(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm17
vmovaps 1552(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm18
vmovaps 1808(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm19
vmovaps 2064(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm20
vmovaps 2320(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm21
vmovaps 2576(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm22
vmovaps 2832(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm23
vmovaps 3088(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm24
vmovaps 3344(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm25
vmovaps 3600(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm26
vmovaps 3856(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm27
vmovdqa32 0(%rdi){uint8}, %zmm9
vpsrld $4, %zmm9, %zmm9
vpandd %zmm7, %zmm9, %zmm9
vcvtfxpntdq2ps $0, %zmm9, %zmm9
vcvtfxpntdq2ps $0, 8(%rcx){1to16}, %zmm10
vmulps %zmm10, %zmm9, %zmm9
vmovaps 32(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm12
vmovaps 288(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm13
vmovaps 544(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm14
vmovaps 800(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm15
vmovaps 1056(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm16
vmovaps 1312(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm17
vmovaps 1568(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm18
vmovaps 1824(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm19
vmovaps 2080(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm20
vmovaps 2336(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm21
vmovaps 2592(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm22
vmovaps 2848(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm23
vmovaps 3104(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm24
vmovaps 3360(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm25
vmovaps 3616(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm26
vmovaps 3872(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm27
vmovdqa32 16(%rdi){uint8}, %zmm9
vpsrld $4, %zmm9, %zmm9
vpandd %zmm7, %zmm9, %zmm9
vcvtfxpntdq2ps $0, %zmm9, %zmm9
vcvtfxpntdq2ps $0, 12(%rcx){1to16}, %zmm10
vmulps %zmm10, %zmm9, %zmm9
vmovaps 48(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm12
vmovaps 304(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm13
vmovaps 560(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm14
vmovaps 816(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm15
vmovaps 1072(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm16
vmovaps 1328(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm17
vmovaps 1584(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm18
vmovaps 1840(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm19
vmovaps 2096(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm20
vmovaps 2352(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm21
vmovaps 2608(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm22
vmovaps 2864(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm23
vmovaps 3120(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm24
vmovaps 3376(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm25
vmovaps 3632(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm26
vmovaps 3888(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm27
vmovdqa32 32(%rdi){uint8}, %zmm9
vpsrld $0, %zmm9, %zmm9
vpandd %zmm7, %zmm9, %zmm9
vcvtfxpntdq2ps $0, %zmm9, %zmm9
vcvtfxpntdq2ps $0, 16(%rcx){1to16}, %zmm10
vmulps %zmm10, %zmm9, %zmm9
vmovaps 64(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm12
vmovaps 320(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm13
vmovaps 576(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm14
vmovaps 832(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm15
vmovaps 1088(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm16
vmovaps 1344(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm17
vmovaps 1600(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm18
vmovaps 1856(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm19
vmovaps 2112(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm20
vmovaps 2368(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm21
vmovaps 2624(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm22
vmovaps 2880(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm23
vmovaps 3136(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm24
vmovaps 3392(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm25
vmovaps 3648(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm26
vmovaps 3904(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm27
vmovdqa32 48(%rdi){uint8}, %zmm9
vpsrld $0, %zmm9, %zmm9
vpandd %zmm7, %zmm9, %zmm9
vcvtfxpntdq2ps $0, %zmm9, %zmm9
vcvtfxpntdq2ps $0, 20(%rcx){1to16}, %zmm10
vmulps %zmm10, %zmm9, %zmm9
vmovaps 80(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm12
vmovaps 336(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm13
vmovaps 592(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm14
vmovaps 848(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm15
vmovaps 1104(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm16
vmovaps 1360(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm17
vmovaps 1616(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm18
vmovaps 1872(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm19
vmovaps 2128(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm20
vmovaps 2384(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm21
vmovaps 2640(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm22
vmovaps 2896(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm23
vmovaps 3152(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm24
vmovaps 3408(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm25
vmovaps 3664(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm26
vmovaps 3920(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm27
vmovdqa32 32(%rdi){uint8}, %zmm9
vpsrld $4, %zmm9, %zmm9
vpandd %zmm7, %zmm9, %zmm9
vcvtfxpntdq2ps $0, %zmm9, %zmm9
vcvtfxpntdq2ps $0, 24(%rcx){1to16}, %zmm10
vmulps %zmm10, %zmm9, %zmm9
vmovaps 96(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm12
vmovaps 352(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm13
vmovaps 608(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm14
vmovaps 864(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm15
vmovaps 1120(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm16
vmovaps 1376(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm17
vmovaps 1632(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm18
vmovaps 1888(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm19
vmovaps 2144(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm20
vmovaps 2400(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm21
vmovaps 2656(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm22
vmovaps 2912(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm23
vmovaps 3168(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm24
vmovaps 3424(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm25
vmovaps 3680(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm26
vmovaps 3936(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm27
vmovdqa32 48(%rdi){uint8}, %zmm9
vpsrld $4, %zmm9, %zmm9
vpandd %zmm7, %zmm9, %zmm9
vcvtfxpntdq2ps $0, %zmm9, %zmm9
vcvtfxpntdq2ps $0, 28(%rcx){1to16}, %zmm10
vmulps %zmm10, %zmm9, %zmm9
vmovaps 112(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm12
vmovaps 368(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm13
vmovaps 624(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm14
vmovaps 880(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm15
vmovaps 1136(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm16
vmovaps 1392(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm17
vmovaps 1648(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm18
vmovaps 1904(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm19
vmovaps 2160(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm20
vmovaps 2416(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm21
vmovaps 2672(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm22
vmovaps 2928(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm23
vmovaps 3184(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm24
vmovaps 3440(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm25
vmovaps 3696(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm26
vmovaps 3952(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm27
vmovdqa32 64(%rdi){uint8}, %zmm9
vpsrld $0, %zmm9, %zmm9
vpandd %zmm7, %zmm9, %zmm9
vcvtfxpntdq2ps $0, %zmm9, %zmm9
vcvtfxpntdq2ps $0, 32(%rcx){1to16}, %zmm10
vmulps %zmm10, %zmm9, %zmm9
vmovaps 128(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm12
vmovaps 384(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm13
vmovaps 640(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm14
vmovaps 896(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm15
vmovaps 1152(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm16
vmovaps 1408(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm17
vmovaps 1664(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm18
vmovaps 1920(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm19
vmovaps 2176(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm20
vmovaps 2432(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm21
vmovaps 2688(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm22
vmovaps 2944(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm23
vmovaps 3200(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm24
vmovaps 3456(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm25
vmovaps 3712(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm26
vmovaps 3968(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm27
vmovdqa32 80(%rdi){uint8}, %zmm9
vpsrld $0, %zmm9, %zmm9
vpandd %zmm7, %zmm9, %zmm9
vcvtfxpntdq2ps $0, %zmm9, %zmm9
vcvtfxpntdq2ps $0, 36(%rcx){1to16}, %zmm10
vmulps %zmm10, %zmm9, %zmm9
vmovaps 144(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm12
vmovaps 400(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm13
vmovaps 656(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm14
vmovaps 912(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm15
vmovaps 1168(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm16
vmovaps 1424(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm17
vmovaps 1680(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm18
vmovaps 1936(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm19
vmovaps 2192(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm20
vmovaps 2448(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm21
vmovaps 2704(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm22
vmovaps 2960(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm23
vmovaps 3216(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm24
vmovaps 3472(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm25
vmovaps 3728(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm26
vmovaps 3984(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm27
vmovdqa32 64(%rdi){uint8}, %zmm9
vpsrld $4, %zmm9, %zmm9
vpandd %zmm7, %zmm9, %zmm9
vcvtfxpntdq2ps $0, %zmm9, %zmm9
vcvtfxpntdq2ps $0, 40(%rcx){1to16}, %zmm10
vmulps %zmm10, %zmm9, %zmm9
vmovaps 160(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm12
vmovaps 416(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm13
vmovaps 672(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm14
vmovaps 928(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm15
vmovaps 1184(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm16
vmovaps 1440(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm17
vmovaps 1696(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm18
vmovaps 1952(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm19
vmovaps 2208(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm20
vmovaps 2464(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm21
vmovaps 2720(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm22
vmovaps 2976(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm23
vmovaps 3232(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm24
vmovaps 3488(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm25
vmovaps 3744(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm26
vmovaps 4000(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm27
vmovdqa32 80(%rdi){uint8}, %zmm9
vpsrld $4, %zmm9, %zmm9
vpandd %zmm7, %zmm9, %zmm9
vcvtfxpntdq2ps $0, %zmm9, %zmm9
vcvtfxpntdq2ps $0, 44(%rcx){1to16}, %zmm10
vmulps %zmm10, %zmm9, %zmm9
vmovaps 176(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm12
vmovaps 432(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm13
vmovaps 688(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm14
vmovaps 944(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm15
vmovaps 1200(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm16
vmovaps 1456(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm17
vmovaps 1712(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm18
vmovaps 1968(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm19
vmovaps 2224(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm20
vmovaps 2480(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm21
vmovaps 2736(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm22
vmovaps 2992(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm23
vmovaps 3248(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm24
vmovaps 3504(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm25
vmovaps 3760(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm26
vmovaps 4016(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm27
vmovdqa32 96(%rdi){uint8}, %zmm9
vpsrld $0, %zmm9, %zmm9
vpandd %zmm7, %zmm9, %zmm9
vcvtfxpntdq2ps $0, %zmm9, %zmm9
vcvtfxpntdq2ps $0, 48(%rcx){1to16}, %zmm10
vmulps %zmm10, %zmm9, %zmm9
vmovaps 192(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm12
vmovaps 448(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm13
vmovaps 704(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm14
vmovaps 960(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm15
vmovaps 1216(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm16
vmovaps 1472(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm17
vmovaps 1728(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm18
vmovaps 1984(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm19
vmovaps 2240(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm20
vmovaps 2496(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm21
vmovaps 2752(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm22
vmovaps 3008(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm23
vmovaps 3264(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm24
vmovaps 3520(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm25
vmovaps 3776(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm26
vmovaps 4032(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm27
vmovdqa32 112(%rdi){uint8}, %zmm9
vpsrld $0, %zmm9, %zmm9
vpandd %zmm7, %zmm9, %zmm9
vcvtfxpntdq2ps $0, %zmm9, %zmm9
vcvtfxpntdq2ps $0, 52(%rcx){1to16}, %zmm10
vmulps %zmm10, %zmm9, %zmm9
vmovaps 208(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm12
vmovaps 464(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm13
vmovaps 720(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm14
vmovaps 976(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm15
vmovaps 1232(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm16
vmovaps 1488(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm17
vmovaps 1744(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm18
vmovaps 2000(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm19
vmovaps 2256(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm20
vmovaps 2512(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm21
vmovaps 2768(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm22
vmovaps 3024(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm23
vmovaps 3280(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm24
vmovaps 3536(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm25
vmovaps 3792(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm26
vmovaps 4048(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm27
vmovdqa32 96(%rdi){uint8}, %zmm9
vpsrld $4, %zmm9, %zmm9
vpandd %zmm7, %zmm9, %zmm9
vcvtfxpntdq2ps $0, %zmm9, %zmm9
vcvtfxpntdq2ps $0, 56(%rcx){1to16}, %zmm10
vmulps %zmm10, %zmm9, %zmm9
vmovaps 224(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm12
vmovaps 480(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm13
vmovaps 736(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm14
vmovaps 992(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm15
vmovaps 1248(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm16
vmovaps 1504(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm17
vmovaps 1760(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm18
vmovaps 2016(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm19
vmovaps 2272(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm20
vmovaps 2528(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm21
vmovaps 2784(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm22
vmovaps 3040(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm23
vmovaps 3296(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm24
vmovaps 3552(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm25
vmovaps 3808(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm26
vmovaps 4064(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm27
vmovdqa32 112(%rdi){uint8}, %zmm9
vpsrld $4, %zmm9, %zmm9
vpandd %zmm7, %zmm9, %zmm9
vcvtfxpntdq2ps $0, %zmm9, %zmm9
vcvtfxpntdq2ps $0, 60(%rcx){1to16}, %zmm10
vmulps %zmm10, %zmm9, %zmm9
vmovaps 240(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm12
vmovaps 496(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm13
vmovaps 752(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm14
vmovaps 1008(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm15
vmovaps 1264(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm16
vmovaps 1520(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm17
vmovaps 1776(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm18
vmovaps 2032(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm19
vmovaps 2288(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm20
vmovaps 2544(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm21
vmovaps 2800(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm22
vmovaps 3056(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm23
vmovaps 3312(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm24
vmovaps 3568(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm25
vmovaps 3824(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm26
vmovaps 4080(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm27
vcvtfxpntps2dq $0,%zmm12,%zmm12
vmovdqa32 %zmm12,0(%r8)
vcvtfxpntps2dq $0,%zmm13,%zmm13
vmovdqa32 %zmm13,64(%r8)
vcvtfxpntps2dq $0,%zmm14,%zmm14
vmovdqa32 %zmm14,128(%r8)
vcvtfxpntps2dq $0,%zmm15,%zmm15
vmovdqa32 %zmm15,192(%r8)
vcvtfxpntps2dq $0,%zmm16,%zmm16
vmovdqa32 %zmm16,256(%r8)
vcvtfxpntps2dq $0,%zmm17,%zmm17
vmovdqa32 %zmm17,320(%r8)
vcvtfxpntps2dq $0,%zmm18,%zmm18
vmovdqa32 %zmm18,384(%r8)
vcvtfxpntps2dq $0,%zmm19,%zmm19
vmovdqa32 %zmm19,448(%r8)
vcvtfxpntps2dq $0,%zmm20,%zmm20
vmovdqa32 %zmm20,512(%r8)
vcvtfxpntps2dq $0,%zmm21,%zmm21
vmovdqa32 %zmm21,576(%r8)
vcvtfxpntps2dq $0,%zmm22,%zmm22
vmovdqa32 %zmm22,640(%r8)
vcvtfxpntps2dq $0,%zmm23,%zmm23
vmovdqa32 %zmm23,704(%r8)
vcvtfxpntps2dq $0,%zmm24,%zmm24
vmovdqa32 %zmm24,768(%r8)
vcvtfxpntps2dq $0,%zmm25,%zmm25
vmovdqa32 %zmm25,832(%r8)
vcvtfxpntps2dq $0,%zmm26,%zmm26
vmovdqa32 %zmm26,896(%r8)
vcvtfxpntps2dq $0,%zmm27,%zmm27
vmovdqa32 %zmm27,960(%r8)
ret
.size ggml_knc_q4_wide_native,.-ggml_knc_q4_wide_native
.p2align 4
.globl ggml_knc_q5_wide_native
.type ggml_knc_q5_wide_native,@function
ggml_knc_q5_wide_native:
movq 8(%rsp),%r10
cmpq $1,%r10
jbe .Lskip5
vprefetch0 176(%r9)
.Lskip5:
vpxord %zmm12,%zmm12,%zmm12
vpxord %zmm13,%zmm13,%zmm13
vpxord %zmm14,%zmm14,%zmm14
vpxord %zmm15,%zmm15,%zmm15
vpxord %zmm16,%zmm16,%zmm16
vpxord %zmm17,%zmm17,%zmm17
vpxord %zmm18,%zmm18,%zmm18
vpxord %zmm19,%zmm19,%zmm19
vpxord %zmm20,%zmm20,%zmm20
vpxord %zmm21,%zmm21,%zmm21
vpxord %zmm22,%zmm22,%zmm22
vpxord %zmm23,%zmm23,%zmm23
vpxord %zmm24,%zmm24,%zmm24
vpxord %zmm25,%zmm25,%zmm25
vpxord %zmm26,%zmm26,%zmm26
vpxord %zmm27,%zmm27,%zmm27
vpbroadcastd .Lmask15(%rip), %zmm7
vpbroadcastd .Lmask1(%rip), %zmm5
vmovdqa32 0(%rdi){uint8}, %zmm9
vpsrld $0, %zmm9, %zmm9
vpandd %zmm7, %zmm9, %zmm9
vmovdqa32 0(%rsi){uint8}, %zmm10
vpsrld $0, %zmm10, %zmm10
vpandd %zmm5, %zmm10, %zmm10
vpslld $4, %zmm10, %zmm10
vpord %zmm10, %zmm9, %zmm9
vcvtfxpntdq2ps $0, %zmm9, %zmm9
vcvtfxpntdq2ps $0, 0(%rcx){1to16}, %zmm10
vmulps %zmm10, %zmm9, %zmm9
vmovaps 0(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm12
vmovaps 256(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm13
vmovaps 512(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm14
vmovaps 768(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm15
vmovaps 1024(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm16
vmovaps 1280(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm17
vmovaps 1536(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm18
vmovaps 1792(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm19
vmovaps 2048(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm20
vmovaps 2304(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm21
vmovaps 2560(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm22
vmovaps 2816(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm23
vmovaps 3072(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm24
vmovaps 3328(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm25
vmovaps 3584(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm26
vmovaps 3840(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm27
vmovdqa32 16(%rdi){uint8}, %zmm9
vpsrld $0, %zmm9, %zmm9
vpandd %zmm7, %zmm9, %zmm9
vmovdqa32 16(%rsi){uint8}, %zmm10
vpsrld $0, %zmm10, %zmm10
vpandd %zmm5, %zmm10, %zmm10
vpslld $4, %zmm10, %zmm10
vpord %zmm10, %zmm9, %zmm9
vcvtfxpntdq2ps $0, %zmm9, %zmm9
vcvtfxpntdq2ps $0, 0(%rcx){1to16}, %zmm10
vmulps %zmm10, %zmm9, %zmm9
vmovaps 16(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm12
vmovaps 272(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm13
vmovaps 528(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm14
vmovaps 784(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm15
vmovaps 1040(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm16
vmovaps 1296(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm17
vmovaps 1552(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm18
vmovaps 1808(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm19
vmovaps 2064(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm20
vmovaps 2320(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm21
vmovaps 2576(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm22
vmovaps 2832(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm23
vmovaps 3088(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm24
vmovaps 3344(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm25
vmovaps 3600(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm26
vmovaps 3856(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm27
vmovdqa32 0(%rdi){uint8}, %zmm9
vpsrld $4, %zmm9, %zmm9
vpandd %zmm7, %zmm9, %zmm9
vmovdqa32 0(%rsi){uint8}, %zmm10
vpsrld $1, %zmm10, %zmm10
vpandd %zmm5, %zmm10, %zmm10
vpslld $4, %zmm10, %zmm10
vpord %zmm10, %zmm9, %zmm9
vcvtfxpntdq2ps $0, %zmm9, %zmm9
vcvtfxpntdq2ps $0, 4(%rcx){1to16}, %zmm10
vmulps %zmm10, %zmm9, %zmm9
vmovaps 32(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm12
vmovaps 288(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm13
vmovaps 544(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm14
vmovaps 800(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm15
vmovaps 1056(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm16
vmovaps 1312(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm17
vmovaps 1568(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm18
vmovaps 1824(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm19
vmovaps 2080(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm20
vmovaps 2336(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm21
vmovaps 2592(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm22
vmovaps 2848(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm23
vmovaps 3104(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm24
vmovaps 3360(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm25
vmovaps 3616(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm26
vmovaps 3872(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm27
vmovdqa32 16(%rdi){uint8}, %zmm9
vpsrld $4, %zmm9, %zmm9
vpandd %zmm7, %zmm9, %zmm9
vmovdqa32 16(%rsi){uint8}, %zmm10
vpsrld $1, %zmm10, %zmm10
vpandd %zmm5, %zmm10, %zmm10
vpslld $4, %zmm10, %zmm10
vpord %zmm10, %zmm9, %zmm9
vcvtfxpntdq2ps $0, %zmm9, %zmm9
vcvtfxpntdq2ps $0, 4(%rcx){1to16}, %zmm10
vmulps %zmm10, %zmm9, %zmm9
vmovaps 48(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm12
vmovaps 304(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm13
vmovaps 560(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm14
vmovaps 816(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm15
vmovaps 1072(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm16
vmovaps 1328(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm17
vmovaps 1584(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm18
vmovaps 1840(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm19
vmovaps 2096(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm20
vmovaps 2352(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm21
vmovaps 2608(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm22
vmovaps 2864(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm23
vmovaps 3120(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm24
vmovaps 3376(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm25
vmovaps 3632(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm26
vmovaps 3888(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm27
vmovdqa32 32(%rdi){uint8}, %zmm9
vpsrld $0, %zmm9, %zmm9
vpandd %zmm7, %zmm9, %zmm9
vmovdqa32 0(%rsi){uint8}, %zmm10
vpsrld $2, %zmm10, %zmm10
vpandd %zmm5, %zmm10, %zmm10
vpslld $4, %zmm10, %zmm10
vpord %zmm10, %zmm9, %zmm9
vcvtfxpntdq2ps $0, %zmm9, %zmm9
vcvtfxpntdq2ps $0, 8(%rcx){1to16}, %zmm10
vmulps %zmm10, %zmm9, %zmm9
vmovaps 64(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm12
vmovaps 320(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm13
vmovaps 576(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm14
vmovaps 832(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm15
vmovaps 1088(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm16
vmovaps 1344(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm17
vmovaps 1600(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm18
vmovaps 1856(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm19
vmovaps 2112(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm20
vmovaps 2368(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm21
vmovaps 2624(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm22
vmovaps 2880(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm23
vmovaps 3136(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm24
vmovaps 3392(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm25
vmovaps 3648(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm26
vmovaps 3904(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm27
vmovdqa32 48(%rdi){uint8}, %zmm9
vpsrld $0, %zmm9, %zmm9
vpandd %zmm7, %zmm9, %zmm9
vmovdqa32 16(%rsi){uint8}, %zmm10
vpsrld $2, %zmm10, %zmm10
vpandd %zmm5, %zmm10, %zmm10
vpslld $4, %zmm10, %zmm10
vpord %zmm10, %zmm9, %zmm9
vcvtfxpntdq2ps $0, %zmm9, %zmm9
vcvtfxpntdq2ps $0, 8(%rcx){1to16}, %zmm10
vmulps %zmm10, %zmm9, %zmm9
vmovaps 80(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm12
vmovaps 336(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm13
vmovaps 592(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm14
vmovaps 848(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm15
vmovaps 1104(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm16
vmovaps 1360(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm17
vmovaps 1616(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm18
vmovaps 1872(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm19
vmovaps 2128(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm20
vmovaps 2384(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm21
vmovaps 2640(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm22
vmovaps 2896(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm23
vmovaps 3152(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm24
vmovaps 3408(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm25
vmovaps 3664(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm26
vmovaps 3920(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm27
vmovdqa32 32(%rdi){uint8}, %zmm9
vpsrld $4, %zmm9, %zmm9
vpandd %zmm7, %zmm9, %zmm9
vmovdqa32 0(%rsi){uint8}, %zmm10
vpsrld $3, %zmm10, %zmm10
vpandd %zmm5, %zmm10, %zmm10
vpslld $4, %zmm10, %zmm10
vpord %zmm10, %zmm9, %zmm9
vcvtfxpntdq2ps $0, %zmm9, %zmm9
vcvtfxpntdq2ps $0, 12(%rcx){1to16}, %zmm10
vmulps %zmm10, %zmm9, %zmm9
vmovaps 96(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm12
vmovaps 352(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm13
vmovaps 608(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm14
vmovaps 864(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm15
vmovaps 1120(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm16
vmovaps 1376(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm17
vmovaps 1632(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm18
vmovaps 1888(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm19
vmovaps 2144(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm20
vmovaps 2400(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm21
vmovaps 2656(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm22
vmovaps 2912(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm23
vmovaps 3168(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm24
vmovaps 3424(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm25
vmovaps 3680(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm26
vmovaps 3936(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm27
vmovdqa32 48(%rdi){uint8}, %zmm9
vpsrld $4, %zmm9, %zmm9
vpandd %zmm7, %zmm9, %zmm9
vmovdqa32 16(%rsi){uint8}, %zmm10
vpsrld $3, %zmm10, %zmm10
vpandd %zmm5, %zmm10, %zmm10
vpslld $4, %zmm10, %zmm10
vpord %zmm10, %zmm9, %zmm9
vcvtfxpntdq2ps $0, %zmm9, %zmm9
vcvtfxpntdq2ps $0, 12(%rcx){1to16}, %zmm10
vmulps %zmm10, %zmm9, %zmm9
vmovaps 112(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm12
vmovaps 368(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm13
vmovaps 624(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm14
vmovaps 880(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm15
vmovaps 1136(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm16
vmovaps 1392(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm17
vmovaps 1648(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm18
vmovaps 1904(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm19
vmovaps 2160(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm20
vmovaps 2416(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm21
vmovaps 2672(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm22
vmovaps 2928(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm23
vmovaps 3184(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm24
vmovaps 3440(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm25
vmovaps 3696(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm26
vmovaps 3952(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm27
vmovdqa32 64(%rdi){uint8}, %zmm9
vpsrld $0, %zmm9, %zmm9
vpandd %zmm7, %zmm9, %zmm9
vmovdqa32 0(%rsi){uint8}, %zmm10
vpsrld $4, %zmm10, %zmm10
vpandd %zmm5, %zmm10, %zmm10
vpslld $4, %zmm10, %zmm10
vpord %zmm10, %zmm9, %zmm9
vcvtfxpntdq2ps $0, %zmm9, %zmm9
vcvtfxpntdq2ps $0, 16(%rcx){1to16}, %zmm10
vmulps %zmm10, %zmm9, %zmm9
vmovaps 128(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm12
vmovaps 384(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm13
vmovaps 640(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm14
vmovaps 896(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm15
vmovaps 1152(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm16
vmovaps 1408(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm17
vmovaps 1664(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm18
vmovaps 1920(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm19
vmovaps 2176(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm20
vmovaps 2432(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm21
vmovaps 2688(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm22
vmovaps 2944(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm23
vmovaps 3200(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm24
vmovaps 3456(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm25
vmovaps 3712(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm26
vmovaps 3968(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm27
vmovdqa32 80(%rdi){uint8}, %zmm9
vpsrld $0, %zmm9, %zmm9
vpandd %zmm7, %zmm9, %zmm9
vmovdqa32 16(%rsi){uint8}, %zmm10
vpsrld $4, %zmm10, %zmm10
vpandd %zmm5, %zmm10, %zmm10
vpslld $4, %zmm10, %zmm10
vpord %zmm10, %zmm9, %zmm9
vcvtfxpntdq2ps $0, %zmm9, %zmm9
vcvtfxpntdq2ps $0, 16(%rcx){1to16}, %zmm10
vmulps %zmm10, %zmm9, %zmm9
vmovaps 144(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm12
vmovaps 400(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm13
vmovaps 656(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm14
vmovaps 912(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm15
vmovaps 1168(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm16
vmovaps 1424(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm17
vmovaps 1680(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm18
vmovaps 1936(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm19
vmovaps 2192(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm20
vmovaps 2448(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm21
vmovaps 2704(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm22
vmovaps 2960(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm23
vmovaps 3216(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm24
vmovaps 3472(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm25
vmovaps 3728(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm26
vmovaps 3984(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm27
vmovdqa32 64(%rdi){uint8}, %zmm9
vpsrld $4, %zmm9, %zmm9
vpandd %zmm7, %zmm9, %zmm9
vmovdqa32 0(%rsi){uint8}, %zmm10
vpsrld $5, %zmm10, %zmm10
vpandd %zmm5, %zmm10, %zmm10
vpslld $4, %zmm10, %zmm10
vpord %zmm10, %zmm9, %zmm9
vcvtfxpntdq2ps $0, %zmm9, %zmm9
vcvtfxpntdq2ps $0, 20(%rcx){1to16}, %zmm10
vmulps %zmm10, %zmm9, %zmm9
vmovaps 160(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm12
vmovaps 416(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm13
vmovaps 672(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm14
vmovaps 928(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm15
vmovaps 1184(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm16
vmovaps 1440(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm17
vmovaps 1696(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm18
vmovaps 1952(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm19
vmovaps 2208(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm20
vmovaps 2464(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm21
vmovaps 2720(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm22
vmovaps 2976(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm23
vmovaps 3232(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm24
vmovaps 3488(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm25
vmovaps 3744(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm26
vmovaps 4000(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm27
vmovdqa32 80(%rdi){uint8}, %zmm9
vpsrld $4, %zmm9, %zmm9
vpandd %zmm7, %zmm9, %zmm9
vmovdqa32 16(%rsi){uint8}, %zmm10
vpsrld $5, %zmm10, %zmm10
vpandd %zmm5, %zmm10, %zmm10
vpslld $4, %zmm10, %zmm10
vpord %zmm10, %zmm9, %zmm9
vcvtfxpntdq2ps $0, %zmm9, %zmm9
vcvtfxpntdq2ps $0, 20(%rcx){1to16}, %zmm10
vmulps %zmm10, %zmm9, %zmm9
vmovaps 176(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm12
vmovaps 432(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm13
vmovaps 688(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm14
vmovaps 944(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm15
vmovaps 1200(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm16
vmovaps 1456(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm17
vmovaps 1712(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm18
vmovaps 1968(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm19
vmovaps 2224(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm20
vmovaps 2480(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm21
vmovaps 2736(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm22
vmovaps 2992(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm23
vmovaps 3248(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm24
vmovaps 3504(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm25
vmovaps 3760(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm26
vmovaps 4016(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm27
vmovdqa32 96(%rdi){uint8}, %zmm9
vpsrld $0, %zmm9, %zmm9
vpandd %zmm7, %zmm9, %zmm9
vmovdqa32 0(%rsi){uint8}, %zmm10
vpsrld $6, %zmm10, %zmm10
vpandd %zmm5, %zmm10, %zmm10
vpslld $4, %zmm10, %zmm10
vpord %zmm10, %zmm9, %zmm9
vcvtfxpntdq2ps $0, %zmm9, %zmm9
vcvtfxpntdq2ps $0, 24(%rcx){1to16}, %zmm10
vmulps %zmm10, %zmm9, %zmm9
vmovaps 192(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm12
vmovaps 448(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm13
vmovaps 704(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm14
vmovaps 960(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm15
vmovaps 1216(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm16
vmovaps 1472(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm17
vmovaps 1728(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm18
vmovaps 1984(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm19
vmovaps 2240(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm20
vmovaps 2496(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm21
vmovaps 2752(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm22
vmovaps 3008(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm23
vmovaps 3264(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm24
vmovaps 3520(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm25
vmovaps 3776(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm26
vmovaps 4032(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm27
vmovdqa32 112(%rdi){uint8}, %zmm9
vpsrld $0, %zmm9, %zmm9
vpandd %zmm7, %zmm9, %zmm9
vmovdqa32 16(%rsi){uint8}, %zmm10
vpsrld $6, %zmm10, %zmm10
vpandd %zmm5, %zmm10, %zmm10
vpslld $4, %zmm10, %zmm10
vpord %zmm10, %zmm9, %zmm9
vcvtfxpntdq2ps $0, %zmm9, %zmm9
vcvtfxpntdq2ps $0, 24(%rcx){1to16}, %zmm10
vmulps %zmm10, %zmm9, %zmm9
vmovaps 208(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm12
vmovaps 464(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm13
vmovaps 720(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm14
vmovaps 976(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm15
vmovaps 1232(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm16
vmovaps 1488(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm17
vmovaps 1744(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm18
vmovaps 2000(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm19
vmovaps 2256(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm20
vmovaps 2512(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm21
vmovaps 2768(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm22
vmovaps 3024(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm23
vmovaps 3280(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm24
vmovaps 3536(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm25
vmovaps 3792(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm26
vmovaps 4048(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm27
vmovdqa32 96(%rdi){uint8}, %zmm9
vpsrld $4, %zmm9, %zmm9
vpandd %zmm7, %zmm9, %zmm9
vmovdqa32 0(%rsi){uint8}, %zmm10
vpsrld $7, %zmm10, %zmm10
vpandd %zmm5, %zmm10, %zmm10
vpslld $4, %zmm10, %zmm10
vpord %zmm10, %zmm9, %zmm9
vcvtfxpntdq2ps $0, %zmm9, %zmm9
vcvtfxpntdq2ps $0, 28(%rcx){1to16}, %zmm10
vmulps %zmm10, %zmm9, %zmm9
vmovaps 224(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm12
vmovaps 480(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm13
vmovaps 736(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm14
vmovaps 992(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm15
vmovaps 1248(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm16
vmovaps 1504(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm17
vmovaps 1760(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm18
vmovaps 2016(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm19
vmovaps 2272(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm20
vmovaps 2528(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm21
vmovaps 2784(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm22
vmovaps 3040(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm23
vmovaps 3296(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm24
vmovaps 3552(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm25
vmovaps 3808(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm26
vmovaps 4064(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm27
vmovdqa32 112(%rdi){uint8}, %zmm9
vpsrld $4, %zmm9, %zmm9
vpandd %zmm7, %zmm9, %zmm9
vmovdqa32 16(%rsi){uint8}, %zmm10
vpsrld $7, %zmm10, %zmm10
vpandd %zmm5, %zmm10, %zmm10
vpslld $4, %zmm10, %zmm10
vpord %zmm10, %zmm9, %zmm9
vcvtfxpntdq2ps $0, %zmm9, %zmm9
vcvtfxpntdq2ps $0, 28(%rcx){1to16}, %zmm10
vmulps %zmm10, %zmm9, %zmm9
vmovaps 240(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm12
vmovaps 496(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm13
vmovaps 752(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm14
vmovaps 1008(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm15
vmovaps 1264(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm16
vmovaps 1520(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm17
vmovaps 1776(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm18
vmovaps 2032(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm19
vmovaps 2288(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm20
vmovaps 2544(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm21
vmovaps 2800(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm22
vmovaps 3056(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm23
vmovaps 3312(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm24
vmovaps 3568(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm25
vmovaps 3824(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm26
vmovaps 4080(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm27
vcvtfxpntps2dq $0,%zmm12,%zmm12
vmovdqa32 %zmm12,0(%r8)
vcvtfxpntps2dq $0,%zmm13,%zmm13
vmovdqa32 %zmm13,64(%r8)
vcvtfxpntps2dq $0,%zmm14,%zmm14
vmovdqa32 %zmm14,128(%r8)
vcvtfxpntps2dq $0,%zmm15,%zmm15
vmovdqa32 %zmm15,192(%r8)
vcvtfxpntps2dq $0,%zmm16,%zmm16
vmovdqa32 %zmm16,256(%r8)
vcvtfxpntps2dq $0,%zmm17,%zmm17
vmovdqa32 %zmm17,320(%r8)
vcvtfxpntps2dq $0,%zmm18,%zmm18
vmovdqa32 %zmm18,384(%r8)
vcvtfxpntps2dq $0,%zmm19,%zmm19
vmovdqa32 %zmm19,448(%r8)
vcvtfxpntps2dq $0,%zmm20,%zmm20
vmovdqa32 %zmm20,512(%r8)
vcvtfxpntps2dq $0,%zmm21,%zmm21
vmovdqa32 %zmm21,576(%r8)
vcvtfxpntps2dq $0,%zmm22,%zmm22
vmovdqa32 %zmm22,640(%r8)
vcvtfxpntps2dq $0,%zmm23,%zmm23
vmovdqa32 %zmm23,704(%r8)
vcvtfxpntps2dq $0,%zmm24,%zmm24
vmovdqa32 %zmm24,768(%r8)
vcvtfxpntps2dq $0,%zmm25,%zmm25
vmovdqa32 %zmm25,832(%r8)
vcvtfxpntps2dq $0,%zmm26,%zmm26
vmovdqa32 %zmm26,896(%r8)
vcvtfxpntps2dq $0,%zmm27,%zmm27
vmovdqa32 %zmm27,960(%r8)
ret
.size ggml_knc_q5_wide_native,.-ggml_knc_q5_wide_native
.p2align 4
.globl ggml_knc_q6_wide_native
.type ggml_knc_q6_wide_native,@function
ggml_knc_q6_wide_native:
movq 8(%rsp),%r10
cmpq $1,%r10
jbe .Lskip6
vprefetch0 210(%r9)
.Lskip6:
vpxord %zmm12,%zmm12,%zmm12
vpxord %zmm13,%zmm13,%zmm13
vpxord %zmm14,%zmm14,%zmm14
vpxord %zmm15,%zmm15,%zmm15
vpxord %zmm16,%zmm16,%zmm16
vpxord %zmm17,%zmm17,%zmm17
vpxord %zmm18,%zmm18,%zmm18
vpxord %zmm19,%zmm19,%zmm19
vpxord %zmm20,%zmm20,%zmm20
vpxord %zmm21,%zmm21,%zmm21
vpxord %zmm22,%zmm22,%zmm22
vpxord %zmm23,%zmm23,%zmm23
vpxord %zmm24,%zmm24,%zmm24
vpxord %zmm25,%zmm25,%zmm25
vpxord %zmm26,%zmm26,%zmm26
vpxord %zmm27,%zmm27,%zmm27
vpbroadcastd .Lmask1(%rip), %zmm4
vpbroadcastd .Lmask3(%rip), %zmm5
vpbroadcastd .Lmask4(%rip), %zmm6
vpbroadcastd .Lmask15(%rip), %zmm7
vpbroadcastd .Lmask32(%rip), %zmm8
vmovdqa32 0(%rdi){uint8}, %zmm9
vpsrld $0, %zmm9, %zmm9
vpandd %zmm7, %zmm9, %zmm9
vmovdqa32 0(%rsi){uint8}, %zmm10
vpsrld $0, %zmm10, %zmm10
vpandd %zmm5, %zmm10, %zmm10
vpslld $4, %zmm10, %zmm10
vpord %zmm10, %zmm9, %zmm9
vpsubd %zmm8, %zmm9, %zmm9
vcvtfxpntdq2ps $0, %zmm9, %zmm9
vcvtfxpntdq2ps $0, 0(%rcx){1to16}, %zmm10
vmulps %zmm10, %zmm9, %zmm9
vmovaps 0(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm12
vmovaps 256(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm13
vmovaps 512(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm14
vmovaps 768(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm15
vmovaps 1024(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm16
vmovaps 1280(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm17
vmovaps 1536(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm18
vmovaps 1792(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm19
vmovaps 2048(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm20
vmovaps 2304(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm21
vmovaps 2560(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm22
vmovaps 2816(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm23
vmovaps 3072(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm24
vmovaps 3328(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm25
vmovaps 3584(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm26
vmovaps 3840(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm27
vmovdqa32 16(%rdi){uint8}, %zmm9
vpsrld $0, %zmm9, %zmm9
vpandd %zmm7, %zmm9, %zmm9
vmovdqa32 16(%rsi){uint8}, %zmm10
vpsrld $0, %zmm10, %zmm10
vpandd %zmm5, %zmm10, %zmm10
vpslld $4, %zmm10, %zmm10
vpord %zmm10, %zmm9, %zmm9
vpsubd %zmm8, %zmm9, %zmm9
vcvtfxpntdq2ps $0, %zmm9, %zmm9
vcvtfxpntdq2ps $0, 4(%rcx){1to16}, %zmm10
vmulps %zmm10, %zmm9, %zmm9
vmovaps 16(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm12
vmovaps 272(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm13
vmovaps 528(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm14
vmovaps 784(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm15
vmovaps 1040(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm16
vmovaps 1296(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm17
vmovaps 1552(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm18
vmovaps 1808(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm19
vmovaps 2064(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm20
vmovaps 2320(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm21
vmovaps 2576(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm22
vmovaps 2832(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm23
vmovaps 3088(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm24
vmovaps 3344(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm25
vmovaps 3600(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm26
vmovaps 3856(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm27
vmovdqa32 32(%rdi){uint8}, %zmm9
vpsrld $0, %zmm9, %zmm9
vpandd %zmm7, %zmm9, %zmm9
vmovdqa32 0(%rsi){uint8}, %zmm10
vpsrld $2, %zmm10, %zmm10
vpandd %zmm5, %zmm10, %zmm10
vpslld $4, %zmm10, %zmm10
vpord %zmm10, %zmm9, %zmm9
vpsubd %zmm8, %zmm9, %zmm9
vcvtfxpntdq2ps $0, %zmm9, %zmm9
vcvtfxpntdq2ps $0, 8(%rcx){1to16}, %zmm10
vmulps %zmm10, %zmm9, %zmm9
vmovaps 32(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm12
vmovaps 288(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm13
vmovaps 544(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm14
vmovaps 800(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm15
vmovaps 1056(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm16
vmovaps 1312(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm17
vmovaps 1568(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm18
vmovaps 1824(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm19
vmovaps 2080(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm20
vmovaps 2336(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm21
vmovaps 2592(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm22
vmovaps 2848(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm23
vmovaps 3104(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm24
vmovaps 3360(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm25
vmovaps 3616(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm26
vmovaps 3872(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm27
vmovdqa32 48(%rdi){uint8}, %zmm9
vpsrld $0, %zmm9, %zmm9
vpandd %zmm7, %zmm9, %zmm9
vmovdqa32 16(%rsi){uint8}, %zmm10
vpsrld $2, %zmm10, %zmm10
vpandd %zmm5, %zmm10, %zmm10
vpslld $4, %zmm10, %zmm10
vpord %zmm10, %zmm9, %zmm9
vpsubd %zmm8, %zmm9, %zmm9
vcvtfxpntdq2ps $0, %zmm9, %zmm9
vcvtfxpntdq2ps $0, 12(%rcx){1to16}, %zmm10
vmulps %zmm10, %zmm9, %zmm9
vmovaps 48(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm12
vmovaps 304(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm13
vmovaps 560(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm14
vmovaps 816(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm15
vmovaps 1072(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm16
vmovaps 1328(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm17
vmovaps 1584(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm18
vmovaps 1840(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm19
vmovaps 2096(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm20
vmovaps 2352(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm21
vmovaps 2608(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm22
vmovaps 2864(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm23
vmovaps 3120(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm24
vmovaps 3376(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm25
vmovaps 3632(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm26
vmovaps 3888(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm27
vmovdqa32 0(%rdi){uint8}, %zmm9
vpsrld $4, %zmm9, %zmm9
vpandd %zmm7, %zmm9, %zmm9
vmovdqa32 0(%rsi){uint8}, %zmm10
vpsrld $4, %zmm10, %zmm10
vpandd %zmm5, %zmm10, %zmm10
vpslld $4, %zmm10, %zmm10
vpord %zmm10, %zmm9, %zmm9
vpsubd %zmm8, %zmm9, %zmm9
vcvtfxpntdq2ps $0, %zmm9, %zmm9
vcvtfxpntdq2ps $0, 16(%rcx){1to16}, %zmm10
vmulps %zmm10, %zmm9, %zmm9
vmovaps 64(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm12
vmovaps 320(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm13
vmovaps 576(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm14
vmovaps 832(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm15
vmovaps 1088(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm16
vmovaps 1344(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm17
vmovaps 1600(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm18
vmovaps 1856(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm19
vmovaps 2112(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm20
vmovaps 2368(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm21
vmovaps 2624(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm22
vmovaps 2880(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm23
vmovaps 3136(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm24
vmovaps 3392(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm25
vmovaps 3648(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm26
vmovaps 3904(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm27
vmovdqa32 16(%rdi){uint8}, %zmm9
vpsrld $4, %zmm9, %zmm9
vpandd %zmm7, %zmm9, %zmm9
vmovdqa32 16(%rsi){uint8}, %zmm10
vpsrld $4, %zmm10, %zmm10
vpandd %zmm5, %zmm10, %zmm10
vpslld $4, %zmm10, %zmm10
vpord %zmm10, %zmm9, %zmm9
vpsubd %zmm8, %zmm9, %zmm9
vcvtfxpntdq2ps $0, %zmm9, %zmm9
vcvtfxpntdq2ps $0, 20(%rcx){1to16}, %zmm10
vmulps %zmm10, %zmm9, %zmm9
vmovaps 80(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm12
vmovaps 336(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm13
vmovaps 592(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm14
vmovaps 848(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm15
vmovaps 1104(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm16
vmovaps 1360(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm17
vmovaps 1616(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm18
vmovaps 1872(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm19
vmovaps 2128(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm20
vmovaps 2384(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm21
vmovaps 2640(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm22
vmovaps 2896(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm23
vmovaps 3152(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm24
vmovaps 3408(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm25
vmovaps 3664(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm26
vmovaps 3920(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm27
vmovdqa32 32(%rdi){uint8}, %zmm9
vpsrld $4, %zmm9, %zmm9
vpandd %zmm7, %zmm9, %zmm9
vmovdqa32 0(%rsi){uint8}, %zmm10
vpsrld $6, %zmm10, %zmm10
vpandd %zmm5, %zmm10, %zmm10
vpslld $4, %zmm10, %zmm10
vpord %zmm10, %zmm9, %zmm9
vpsubd %zmm8, %zmm9, %zmm9
vcvtfxpntdq2ps $0, %zmm9, %zmm9
vcvtfxpntdq2ps $0, 24(%rcx){1to16}, %zmm10
vmulps %zmm10, %zmm9, %zmm9
vmovaps 96(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm12
vmovaps 352(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm13
vmovaps 608(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm14
vmovaps 864(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm15
vmovaps 1120(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm16
vmovaps 1376(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm17
vmovaps 1632(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm18
vmovaps 1888(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm19
vmovaps 2144(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm20
vmovaps 2400(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm21
vmovaps 2656(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm22
vmovaps 2912(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm23
vmovaps 3168(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm24
vmovaps 3424(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm25
vmovaps 3680(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm26
vmovaps 3936(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm27
vmovdqa32 48(%rdi){uint8}, %zmm9
vpsrld $4, %zmm9, %zmm9
vpandd %zmm7, %zmm9, %zmm9
vmovdqa32 16(%rsi){uint8}, %zmm10
vpsrld $6, %zmm10, %zmm10
vpandd %zmm5, %zmm10, %zmm10
vpslld $4, %zmm10, %zmm10
vpord %zmm10, %zmm9, %zmm9
vpsubd %zmm8, %zmm9, %zmm9
vcvtfxpntdq2ps $0, %zmm9, %zmm9
vcvtfxpntdq2ps $0, 28(%rcx){1to16}, %zmm10
vmulps %zmm10, %zmm9, %zmm9
vmovaps 112(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm12
vmovaps 368(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm13
vmovaps 624(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm14
vmovaps 880(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm15
vmovaps 1136(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm16
vmovaps 1392(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm17
vmovaps 1648(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm18
vmovaps 1904(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm19
vmovaps 2160(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm20
vmovaps 2416(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm21
vmovaps 2672(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm22
vmovaps 2928(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm23
vmovaps 3184(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm24
vmovaps 3440(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm25
vmovaps 3696(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm26
vmovaps 3952(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm27
vmovdqa32 64(%rdi){uint8}, %zmm9
vpsrld $0, %zmm9, %zmm9
vpandd %zmm7, %zmm9, %zmm9
vmovdqa32 32(%rsi){uint8}, %zmm10
vpsrld $0, %zmm10, %zmm10
vpandd %zmm5, %zmm10, %zmm10
vpslld $4, %zmm10, %zmm10
vpord %zmm10, %zmm9, %zmm9
vpsubd %zmm8, %zmm9, %zmm9
vcvtfxpntdq2ps $0, %zmm9, %zmm9
vcvtfxpntdq2ps $0, 32(%rcx){1to16}, %zmm10
vmulps %zmm10, %zmm9, %zmm9
vmovaps 128(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm12
vmovaps 384(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm13
vmovaps 640(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm14
vmovaps 896(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm15
vmovaps 1152(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm16
vmovaps 1408(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm17
vmovaps 1664(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm18
vmovaps 1920(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm19
vmovaps 2176(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm20
vmovaps 2432(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm21
vmovaps 2688(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm22
vmovaps 2944(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm23
vmovaps 3200(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm24
vmovaps 3456(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm25
vmovaps 3712(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm26
vmovaps 3968(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm27
vmovdqa32 80(%rdi){uint8}, %zmm9
vpsrld $0, %zmm9, %zmm9
vpandd %zmm7, %zmm9, %zmm9
vmovdqa32 48(%rsi){uint8}, %zmm10
vpsrld $0, %zmm10, %zmm10
vpandd %zmm5, %zmm10, %zmm10
vpslld $4, %zmm10, %zmm10
vpord %zmm10, %zmm9, %zmm9
vpsubd %zmm8, %zmm9, %zmm9
vcvtfxpntdq2ps $0, %zmm9, %zmm9
vcvtfxpntdq2ps $0, 36(%rcx){1to16}, %zmm10
vmulps %zmm10, %zmm9, %zmm9
vmovaps 144(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm12
vmovaps 400(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm13
vmovaps 656(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm14
vmovaps 912(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm15
vmovaps 1168(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm16
vmovaps 1424(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm17
vmovaps 1680(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm18
vmovaps 1936(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm19
vmovaps 2192(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm20
vmovaps 2448(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm21
vmovaps 2704(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm22
vmovaps 2960(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm23
vmovaps 3216(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm24
vmovaps 3472(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm25
vmovaps 3728(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm26
vmovaps 3984(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm27
vmovdqa32 96(%rdi){uint8}, %zmm9
vpsrld $0, %zmm9, %zmm9
vpandd %zmm7, %zmm9, %zmm9
vmovdqa32 32(%rsi){uint8}, %zmm10
vpsrld $2, %zmm10, %zmm10
vpandd %zmm5, %zmm10, %zmm10
vpslld $4, %zmm10, %zmm10
vpord %zmm10, %zmm9, %zmm9
vpsubd %zmm8, %zmm9, %zmm9
vcvtfxpntdq2ps $0, %zmm9, %zmm9
vcvtfxpntdq2ps $0, 40(%rcx){1to16}, %zmm10
vmulps %zmm10, %zmm9, %zmm9
vmovaps 160(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm12
vmovaps 416(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm13
vmovaps 672(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm14
vmovaps 928(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm15
vmovaps 1184(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm16
vmovaps 1440(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm17
vmovaps 1696(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm18
vmovaps 1952(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm19
vmovaps 2208(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm20
vmovaps 2464(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm21
vmovaps 2720(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm22
vmovaps 2976(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm23
vmovaps 3232(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm24
vmovaps 3488(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm25
vmovaps 3744(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm26
vmovaps 4000(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm27
vmovdqa32 112(%rdi){uint8}, %zmm9
vpsrld $0, %zmm9, %zmm9
vpandd %zmm7, %zmm9, %zmm9
vmovdqa32 48(%rsi){uint8}, %zmm10
vpsrld $2, %zmm10, %zmm10
vpandd %zmm5, %zmm10, %zmm10
vpslld $4, %zmm10, %zmm10
vpord %zmm10, %zmm9, %zmm9
vpsubd %zmm8, %zmm9, %zmm9
vcvtfxpntdq2ps $0, %zmm9, %zmm9
vcvtfxpntdq2ps $0, 44(%rcx){1to16}, %zmm10
vmulps %zmm10, %zmm9, %zmm9
vmovaps 176(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm12
vmovaps 432(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm13
vmovaps 688(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm14
vmovaps 944(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm15
vmovaps 1200(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm16
vmovaps 1456(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm17
vmovaps 1712(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm18
vmovaps 1968(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm19
vmovaps 2224(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm20
vmovaps 2480(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm21
vmovaps 2736(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm22
vmovaps 2992(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm23
vmovaps 3248(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm24
vmovaps 3504(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm25
vmovaps 3760(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm26
vmovaps 4016(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm27
vmovdqa32 64(%rdi){uint8}, %zmm9
vpsrld $4, %zmm9, %zmm9
vpandd %zmm7, %zmm9, %zmm9
vmovdqa32 32(%rsi){uint8}, %zmm10
vpsrld $4, %zmm10, %zmm10
vpandd %zmm5, %zmm10, %zmm10
vpslld $4, %zmm10, %zmm10
vpord %zmm10, %zmm9, %zmm9
vpsubd %zmm8, %zmm9, %zmm9
vcvtfxpntdq2ps $0, %zmm9, %zmm9
vcvtfxpntdq2ps $0, 48(%rcx){1to16}, %zmm10
vmulps %zmm10, %zmm9, %zmm9
vmovaps 192(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm12
vmovaps 448(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm13
vmovaps 704(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm14
vmovaps 960(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm15
vmovaps 1216(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm16
vmovaps 1472(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm17
vmovaps 1728(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm18
vmovaps 1984(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm19
vmovaps 2240(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm20
vmovaps 2496(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm21
vmovaps 2752(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm22
vmovaps 3008(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm23
vmovaps 3264(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm24
vmovaps 3520(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm25
vmovaps 3776(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm26
vmovaps 4032(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm27
vmovdqa32 80(%rdi){uint8}, %zmm9
vpsrld $4, %zmm9, %zmm9
vpandd %zmm7, %zmm9, %zmm9
vmovdqa32 48(%rsi){uint8}, %zmm10
vpsrld $4, %zmm10, %zmm10
vpandd %zmm5, %zmm10, %zmm10
vpslld $4, %zmm10, %zmm10
vpord %zmm10, %zmm9, %zmm9
vpsubd %zmm8, %zmm9, %zmm9
vcvtfxpntdq2ps $0, %zmm9, %zmm9
vcvtfxpntdq2ps $0, 52(%rcx){1to16}, %zmm10
vmulps %zmm10, %zmm9, %zmm9
vmovaps 208(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm12
vmovaps 464(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm13
vmovaps 720(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm14
vmovaps 976(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm15
vmovaps 1232(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm16
vmovaps 1488(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm17
vmovaps 1744(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm18
vmovaps 2000(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm19
vmovaps 2256(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm20
vmovaps 2512(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm21
vmovaps 2768(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm22
vmovaps 3024(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm23
vmovaps 3280(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm24
vmovaps 3536(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm25
vmovaps 3792(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm26
vmovaps 4048(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm27
vmovdqa32 96(%rdi){uint8}, %zmm9
vpsrld $4, %zmm9, %zmm9
vpandd %zmm7, %zmm9, %zmm9
vmovdqa32 32(%rsi){uint8}, %zmm10
vpsrld $6, %zmm10, %zmm10
vpandd %zmm5, %zmm10, %zmm10
vpslld $4, %zmm10, %zmm10
vpord %zmm10, %zmm9, %zmm9
vpsubd %zmm8, %zmm9, %zmm9
vcvtfxpntdq2ps $0, %zmm9, %zmm9
vcvtfxpntdq2ps $0, 56(%rcx){1to16}, %zmm10
vmulps %zmm10, %zmm9, %zmm9
vmovaps 224(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm12
vmovaps 480(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm13
vmovaps 736(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm14
vmovaps 992(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm15
vmovaps 1248(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm16
vmovaps 1504(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm17
vmovaps 1760(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm18
vmovaps 2016(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm19
vmovaps 2272(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm20
vmovaps 2528(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm21
vmovaps 2784(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm22
vmovaps 3040(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm23
vmovaps 3296(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm24
vmovaps 3552(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm25
vmovaps 3808(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm26
vmovaps 4064(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm27
vmovdqa32 112(%rdi){uint8}, %zmm9
vpsrld $4, %zmm9, %zmm9
vpandd %zmm7, %zmm9, %zmm9
vmovdqa32 48(%rsi){uint8}, %zmm10
vpsrld $6, %zmm10, %zmm10
vpandd %zmm5, %zmm10, %zmm10
vpslld $4, %zmm10, %zmm10
vpord %zmm10, %zmm9, %zmm9
vpsubd %zmm8, %zmm9, %zmm9
vcvtfxpntdq2ps $0, %zmm9, %zmm9
vcvtfxpntdq2ps $0, 60(%rcx){1to16}, %zmm10
vmulps %zmm10, %zmm9, %zmm9
vmovaps 240(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm12
vmovaps 496(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm13
vmovaps 752(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm14
vmovaps 1008(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm15
vmovaps 1264(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm16
vmovaps 1520(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm17
vmovaps 1776(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm18
vmovaps 2032(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm19
vmovaps 2288(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm20
vmovaps 2544(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm21
vmovaps 2800(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm22
vmovaps 3056(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm23
vmovaps 3312(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm24
vmovaps 3568(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm25
vmovaps 3824(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm26
vmovaps 4080(%rdx){sint8},%zmm11
vfmadd231ps %zmm11,%zmm9,%zmm27
vcvtfxpntps2dq $0,%zmm12,%zmm12
vmovdqa32 %zmm12,0(%r8)
vcvtfxpntps2dq $0,%zmm13,%zmm13
vmovdqa32 %zmm13,64(%r8)
vcvtfxpntps2dq $0,%zmm14,%zmm14
vmovdqa32 %zmm14,128(%r8)
vcvtfxpntps2dq $0,%zmm15,%zmm15
vmovdqa32 %zmm15,192(%r8)
vcvtfxpntps2dq $0,%zmm16,%zmm16
vmovdqa32 %zmm16,256(%r8)
vcvtfxpntps2dq $0,%zmm17,%zmm17
vmovdqa32 %zmm17,320(%r8)
vcvtfxpntps2dq $0,%zmm18,%zmm18
vmovdqa32 %zmm18,384(%r8)
vcvtfxpntps2dq $0,%zmm19,%zmm19
vmovdqa32 %zmm19,448(%r8)
vcvtfxpntps2dq $0,%zmm20,%zmm20
vmovdqa32 %zmm20,512(%r8)
vcvtfxpntps2dq $0,%zmm21,%zmm21
vmovdqa32 %zmm21,576(%r8)
vcvtfxpntps2dq $0,%zmm22,%zmm22
vmovdqa32 %zmm22,640(%r8)
vcvtfxpntps2dq $0,%zmm23,%zmm23
vmovdqa32 %zmm23,704(%r8)
vcvtfxpntps2dq $0,%zmm24,%zmm24
vmovdqa32 %zmm24,768(%r8)
vcvtfxpntps2dq $0,%zmm25,%zmm25
vmovdqa32 %zmm25,832(%r8)
vcvtfxpntps2dq $0,%zmm26,%zmm26
vmovdqa32 %zmm26,896(%r8)
vcvtfxpntps2dq $0,%zmm27,%zmm27
vmovdqa32 %zmm27,960(%r8)
ret
.size ggml_knc_q6_wide_native,.-ggml_knc_q6_wide_native
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
