/**
 * @file irq_handler.S
 */
/* Embedded Xinu, Copyright (C) 2013.  All rights reserved. */

#include <arm.h>  /* Needed for ARM_MODE_SYS definition.  */

.globl irq_handler

/**
 * Entry point for Xinu's interrupt handler (ARM version).  Note: we don't
 * actually use the IRQ mode provided by the ARM; instead we switch the
 * processor to SYS mode and use the SYS mode stack instead.  This makes the ARM
 * more similar to other CPUs and removes special cases in the context switch
 * code.  However, a caveat with this method is that the IRQ handler will use
 * the stack of the currently running thread (the one that was interrupted).
 * This requires that the stack size of any thread that executes with interrupts
 * enabled be set to at least the stack space needed by the thread itself plus
 * the maximum stack space needed by any IRQ handler.
 */
irq_handler:
	.func irq_handler

	/* Correct LR_irq; this is a quirk of how the ARM processor calls the
	 * IRQ handler.  */
	sub lr, lr, #4

	/* [Store Return State Decrement Before] */
	/* Store the return state on the SYS mode stack.  This includes
	 * SPSR_irq, which is the CPSR from SYS mode before we were interrupted,
	 * and LR_irq, which is the address to which we must return to continue
	 * execution of the interrupted thread.  */
	srsdb #ARM_MODE_SYS!

	/* [Change Program State Interrupt Disable] */
	/* Change to SYS mode, with IRQs and FIQs still disabled.  */
	cpsid if, #ARM_MODE_SYS

	/* Save on the SYS mode stack any registers that may be clobbered,
	 * namely the SYS mode LR and all other caller-save general purpose
	 * registers.  Also save r4 so we can use it to store the amount we
	 * decremented the stack pointer by to align it to an 8-byte boundary
	 * (see comment below).  */
	push {r0-r12, lr}
	/* Provide cause of interrupt as arg2 to xtrap */
	mov r1, #ARM_EXCEPTION_IRQ

        /* All exception handlers pick up here */
common_handler:
	/* Provide stacked state as arg1 to xtrap */
	mov r0, sp

	/* According to the document "Procedure Call Standard for the ARM
	 * Architecture", the stack pointer is 4-byte aligned at all times, but
	 * it must be 8-byte aligned when calling an externally visible
	 * function.  This is important because this code is reached from an IRQ
	 * and therefore the stack currently may only be 4-byte aligned.  If
	 * this is the case, the stack must be padded to an 8-byte boundary
	 * before calling dispatch().  */
	and r4, sp, #4
	sub sp, sp, r4

	/* Execute a data memory barrier, as per the BCM2835 documentation.  */
	dmb

	/* Call the C interrupt dispatching code. */
	bl xtrap

	/* Execute a data memory barrier, as per the BCM2835 documentation.  */
	dmb

	/* Restore the original stack alignment (see note about 8-byte alignment
	 * above).  */
	add sp, sp, r4

	/* Restore the above-mentioned registers from the SYS mode stack. */
	pop {r0-r12, lr}

	/* [Return From Exception Increment After] */
	/* Load the original SYS-mode CPSR and PC that were saved on the SYS
	 * mode stack.  */
	rfeia sp!
	.endfunc

.globl undef_handler
undef_handler:
	.func irq_handler
	sub lr, lr, #4
	srsdb #ARM_MODE_SYS!
	cpsid if, #ARM_MODE_SYS
	push {r0-r12, lr}
	mov r1, #ARM_EXCEPTION_UNDEFINED
	b   common_handler
	.endfunc

.globl swi_handler
swi_handler:
	.func swi_handler
	sub lr, lr, #4
	srsdb #ARM_MODE_SYS!
	cpsid if, #ARM_MODE_SYS
	push {r0-r12, lr}
	mov r1, #ARM_EXCEPTION_SWI
	b   common_handler
	.endfunc

.globl prefetch_handler
prefetch_handler:
	.func prefetch_handler
	sub lr, lr, #4
	srsdb #ARM_MODE_SYS!
	cpsid if, #ARM_MODE_SYS
	push {r0-r12, lr}
	mov r1, #ARM_EXCEPTION_PREFETCH
	b   common_handler
	.endfunc

.globl abort_handler
abort_handler:
	.func abort_handler
	sub lr, lr, #8           /* Note: Data Abort is -8, not like others */
	srsdb #ARM_MODE_SYS!
	cpsid if, #ARM_MODE_SYS
	push {r0-r12, lr}
	mov r1, #ARM_EXCEPTION_ABORT
	b   common_handler
	.endfunc

.globl fiq_handler
fiq_handler:
	.func fiq_handler
	sub lr, lr, #4
	srsdb #ARM_MODE_SYS!
	cpsid if, #ARM_MODE_SYS
	push {r0-r12, lr}
	mov r1, #ARM_EXCEPTION_FIQ
	b   common_handler
	.endfunc

