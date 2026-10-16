/* SPDX-License-Identifier: MIT */
#if !defined(__k1om__) || !defined(__KNC__) || defined(__AVX512F__)
#error Native KNC required
#endif
.text
.p2align 4
.globl knc_f32_tile2x2
.type knc_f32_tile2x2, @function
knc_f32_tile2x2:
xorq %rax,%rax
movq %rdi,%r10
vpxord %zmm0,%zmm0,%zmm0
vpxord %zmm1,%zmm1,%zmm1
vpxord %zmm2,%zmm2,%zmm2
vpxord %zmm3,%zmm3,%zmm3
vpxord %zmm4,%zmm4,%zmm4
vpxord %zmm5,%zmm5,%zmm5
vpxord %zmm6,%zmm6,%zmm6
vpxord %zmm7,%zmm7,%zmm7
vpxord %zmm8,%zmm8,%zmm8
vpxord %zmm9,%zmm9,%zmm9
vpxord %zmm10,%zmm10,%zmm10
vpxord %zmm11,%zmm11,%zmm11
vpxord %zmm12,%zmm12,%zmm12
vpxord %zmm13,%zmm13,%zmm13
vpxord %zmm14,%zmm14,%zmm14
vpxord %zmm15,%zmm15,%zmm15
cmpq $64,%r10
jb .Ltile_tail
.Ltile_main:
vmovaps 0(%rsi,%rax,4),%zmm16
vmovaps 0(%rdx,%rax,4),%zmm17
vmovaps 0(%rcx,%rax,4),%zmm18
vmovaps 0(%r8,%rax,4),%zmm19
vfmadd231ps %zmm16,%zmm18,%zmm0
vfmadd231ps %zmm17,%zmm18,%zmm4
vfmadd231ps %zmm16,%zmm19,%zmm8
vfmadd231ps %zmm17,%zmm19,%zmm12
vmovaps 64(%rsi,%rax,4),%zmm16
vmovaps 64(%rdx,%rax,4),%zmm17
vmovaps 64(%rcx,%rax,4),%zmm18
vmovaps 64(%r8,%rax,4),%zmm19
vfmadd231ps %zmm16,%zmm18,%zmm1
vfmadd231ps %zmm17,%zmm18,%zmm5
vfmadd231ps %zmm16,%zmm19,%zmm9
vfmadd231ps %zmm17,%zmm19,%zmm13
vmovaps 128(%rsi,%rax,4),%zmm16
vmovaps 128(%rdx,%rax,4),%zmm17
vmovaps 128(%rcx,%rax,4),%zmm18
vmovaps 128(%r8,%rax,4),%zmm19
vfmadd231ps %zmm16,%zmm18,%zmm2
vfmadd231ps %zmm17,%zmm18,%zmm6
vfmadd231ps %zmm16,%zmm19,%zmm10
vfmadd231ps %zmm17,%zmm19,%zmm14
vmovaps 192(%rsi,%rax,4),%zmm16
vmovaps 192(%rdx,%rax,4),%zmm17
vmovaps 192(%rcx,%rax,4),%zmm18
vmovaps 192(%r8,%rax,4),%zmm19
vfmadd231ps %zmm16,%zmm18,%zmm3
vfmadd231ps %zmm17,%zmm18,%zmm7
vfmadd231ps %zmm16,%zmm19,%zmm11
vfmadd231ps %zmm17,%zmm19,%zmm15
addq $64,%rax
subq $64,%r10
cmpq $64,%r10
jae .Ltile_main
.Ltile_tail:
cmpq $16,%r10
jb .Ltile_reduce
.Ltile_tail_loop:
vmovaps 0(%rsi,%rax,4),%zmm16
vmovaps 0(%rdx,%rax,4),%zmm17
vmovaps 0(%rcx,%rax,4),%zmm18
vmovaps 0(%r8,%rax,4),%zmm19
vfmadd231ps %zmm16,%zmm18,%zmm0
vfmadd231ps %zmm17,%zmm18,%zmm4
vfmadd231ps %zmm16,%zmm19,%zmm8
vfmadd231ps %zmm17,%zmm19,%zmm12
addq $16,%rax
subq $16,%r10
cmpq $16,%r10
jae .Ltile_tail_loop
.Ltile_reduce:
vaddps %zmm1,%zmm0,%zmm0
vaddps %zmm3,%zmm2,%zmm2
vaddps %zmm2,%zmm0,%zmm0
vmovaps %zmm0,0(%r9)
vaddps %zmm5,%zmm4,%zmm4
vaddps %zmm7,%zmm6,%zmm6
vaddps %zmm6,%zmm4,%zmm4
vmovaps %zmm4,64(%r9)
vaddps %zmm9,%zmm8,%zmm8
vaddps %zmm11,%zmm10,%zmm10
vaddps %zmm10,%zmm8,%zmm8
vmovaps %zmm8,128(%r9)
vaddps %zmm13,%zmm12,%zmm12
vaddps %zmm15,%zmm14,%zmm14
vaddps %zmm14,%zmm12,%zmm12
vmovaps %zmm12,192(%r9)
ret
.size knc_f32_tile2x2,.-knc_f32_tile2x2
.section .note.GNU-stack,"",@progbits
