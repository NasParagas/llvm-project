	.att_syntax
	.file	"x86_test.c"
	.text
	.globl	main                            # -- Begin function main
	.prefalign	4, .Lfunc_end0, nop
	.type	main,@function
main:                                   # @main
	.cfi_startproc
# %bb.0:                                # %entry
	pushq	%rbp
	.cfi_def_cfa_offset 16
	.cfi_offset %rbp, -16
	movq	%rsp, %rbp
	.cfi_def_cfa_register %rbp
	subq	$16, %rsp
	movl	$0, -12(%rbp)
	movl	$0, -8(%rbp)
	movl	$1, -4(%rbp)
.LBB0_1:                                # %for.cond
                                        # =>This Inner Loop Header: Depth=1
	cmpl	$10, -4(%rbp)
	jg	.LBB0_4
# %bb.2:                                # %for.body
                                        #   in Loop: Header=BB0_1 Depth=1
	movl	-4(%rbp), %eax
	addl	-8(%rbp), %eax
	movl	%eax, -8(%rbp)
# %bb.3:                                # %for.inc
                                        #   in Loop: Header=BB0_1 Depth=1
	movl	-4(%rbp), %eax
	addl	$1, %eax
	movl	%eax, -4(%rbp)
	jmp	.LBB0_1
.LBB0_4:                                # %for.end
	movl	-8(%rbp), %esi
	movabsq	$.L.str, %rdi
	movb	$0, %al
	callq	printf@PLT
	movl	-12(%rbp), %eax
	addq	$16, %rsp
	popq	%rbp
	.cfi_def_cfa %rsp, 8
	retq
.Lfunc_end0:
	.size	main, .Lfunc_end0-main
	.cfi_endproc
                                        # -- End function
	.type	.L.str,@object                  # @.str
	.section	.rodata.str1.1,"aMS",@progbits,1
.L.str:
	.asciz	"Total = %d\n"
	.size	.L.str, 12

	.ident	"clang version 23.1.2 (https://github.com/NasParagas/llvm-project.git 069ef0e7cb36ee1fcf3bfdad31533fd79ab85b58)"
	.section	".note.GNU-stack","",@progbits
