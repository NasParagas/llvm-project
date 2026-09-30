	.attribute	4, 16
	.attribute	5, "rv64i2p1_m2p0_a2p1_f2p2_d2p2_c2p0_zicsr2p0_zifencei2p0_zmmul1p0_zaamo1p0_zalrsc1p0_zca1p0_zcd1p0"
	.file	"riscv_test.c"
	.option	push
	.option	arch, +a, +c, +d, +f, +m, +zaamo, +zalrsc, +zca, +zcd, +zicsr, +zifencei, +zmmul
	.text
	.globl	main                            # -- Begin function main
	.p2align	1
	.type	main,@function
main:                                   # @main
# %bb.0:                                # %entry
	addi	sp, sp, -32
	sd	ra, 24(sp)                      # 8-byte Folded Spill
	sd	s0, 16(sp)                      # 8-byte Folded Spill
	addi	s0, sp, 32
	sw	zero, 12(sp)
	sw	zero, 8(sp)
	li	a0, 1
	sw	a0, 4(sp)
	j	.LBB0_1
.LBB0_1:                                # %for.cond
                                        # =>This Inner Loop Header: Depth=1
	lw	a0, 4(sp)
	li	a1, 10
	blt	a1, a0, .LBB0_4
	j	.LBB0_2
.LBB0_2:                                # %for.body
                                        #   in Loop: Header=BB0_1 Depth=1
	lw	a0, 4(sp)
	lw	a1, 8(sp)
	addw	a0, a0, a1
	sw	a0, 8(sp)
	j	.LBB0_3
.LBB0_3:                                # %for.inc
                                        #   in Loop: Header=BB0_1 Depth=1
	lw	a0, 4(sp)
	addiw	a0, a0, 1
	sw	a0, 4(sp)
	j	.LBB0_1
.LBB0_4:                                # %for.end
	lw	a1, 8(sp)
	lui	a0, %hi(.L.str)
	addi	a0, a0, %lo(.L.str)
	call	printf
	lw	a0, 12(sp)
	ld	ra, 24(sp)                      # 8-byte Folded Reload
	ld	s0, 16(sp)                      # 8-byte Folded Reload
	addi	sp, sp, 32
	ret
.Lfunc_end0:
	.size	main, .Lfunc_end0-main
                                        # -- End function
	.option	pop
	.type	.L.str,@object                  # @.str
	.section	.rodata.str1.1,"aMS",@progbits,1
.L.str:
	.asciz	"Total = %d\n"
	.size	.L.str, 12

	.ident	"clang version 23.1.2 (https://github.com/NasParagas/llvm-project.git 069ef0e7cb36ee1fcf3bfdad31533fd79ab85b58)"
	.section	".note.GNU-stack","",@progbits
