/* SPDX-License-Identifier: MIT. Native KNC only. */
#if !defined(__k1om__) || !defined(__KNC__) || defined(__AVX512F__)
#error Native KNC required
#endif
.text
.p2align 4
.globl knc_f32_pair
.type knc_f32_pair, @function
knc_f32_pair:
xorq %rax, %rax
movq %rdi, %r10
vpxord %zmm0, %zmm0, %zmm0
vpxord %zmm1, %zmm1, %zmm1
vpxord %zmm2, %zmm2, %zmm2
vpxord %zmm3, %zmm3, %zmm3
vpxord %zmm4, %zmm4, %zmm4
vpxord %zmm5, %zmm5, %zmm5
vpxord %zmm6, %zmm6, %zmm6
vpxord %zmm7, %zmm7, %zmm7
cmpq $64, %r10
jb .Lpair_tail
.Lpair_main:
vmovaps 0(%rcx,%rax,4), %zmm10
vmovaps 0(%rsi,%rax,4), %zmm8
vmovaps 0(%rdx,%rax,4), %zmm9
vfmadd231ps %zmm10, %zmm8, %zmm0
vfmadd231ps %zmm10, %zmm9, %zmm4
vmovaps 64(%rcx,%rax,4), %zmm10
vmovaps 64(%rsi,%rax,4), %zmm8
vmovaps 64(%rdx,%rax,4), %zmm9
vfmadd231ps %zmm10, %zmm8, %zmm1
vfmadd231ps %zmm10, %zmm9, %zmm5
vmovaps 128(%rcx,%rax,4), %zmm10
vmovaps 128(%rsi,%rax,4), %zmm8
vmovaps 128(%rdx,%rax,4), %zmm9
vfmadd231ps %zmm10, %zmm8, %zmm2
vfmadd231ps %zmm10, %zmm9, %zmm6
vmovaps 192(%rcx,%rax,4), %zmm10
vmovaps 192(%rsi,%rax,4), %zmm8
vmovaps 192(%rdx,%rax,4), %zmm9
vfmadd231ps %zmm10, %zmm8, %zmm3
vfmadd231ps %zmm10, %zmm9, %zmm7
addq $64, %rax
subq $64, %r10
cmpq $64, %r10
jae .Lpair_main
.Lpair_tail:
cmpq $16, %r10
jb .Lpair_reduce
.Lpair_tail_loop:
vmovaps 0(%rcx,%rax,4), %zmm10
vmovaps 0(%rsi,%rax,4), %zmm8
vmovaps 0(%rdx,%rax,4), %zmm9
vfmadd231ps %zmm10, %zmm8, %zmm0
vfmadd231ps %zmm10, %zmm9, %zmm4
addq $16, %rax
subq $16, %r10
cmpq $16, %r10
jae .Lpair_tail_loop
.Lpair_reduce:
vaddps %zmm1, %zmm0, %zmm0
vaddps %zmm3, %zmm2, %zmm2
vaddps %zmm2, %zmm0, %zmm0
vmovaps %zmm0, (%r8)
vaddps %zmm5, %zmm4, %zmm4
vaddps %zmm7, %zmm6, %zmm6
vaddps %zmm6, %zmm4, %zmm4
vmovaps %zmm4, (%r9)
ret
.size knc_f32_pair, .-knc_f32_pair
.p2align 4
.globl knc_f16_products_pair
.type knc_f16_products_pair, @function
knc_f16_products_pair:
xorq %rax, %rax
testq %rdi, %rdi
jz .Lf16_end
.Lf16_loop:
vmovaps (%rcx,%rax,2){float16}, %zmm0
vmovaps (%rsi,%rax,2){float16}, %zmm1
vmovaps (%rdx,%rax,2){float16}, %zmm2
vmulps %zmm0, %zmm1, %zmm1
vmulps %zmm0, %zmm2, %zmm2
vmovaps %zmm1, (%r8,%rax,4)
vmovaps %zmm2, (%r9,%rax,4)
addq $16, %rax
cmpq %rdi, %rax
jb .Lf16_loop
.Lf16_end:
ret
.size knc_f16_products_pair, .-knc_f16_products_pair
.section .note.GNU-stack,"",@progbits
