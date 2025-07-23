.section .text.init
.globl _start

_start:
  # ----------------------------------------------------------------
  # Test Setup
  # ----------------------------------------------------------------
  # Define the base address for most test data.
  #.equ BASE_ADDR, 0x81000000
  .equ BASE_ADDR, 0x80010000
  li a4, BASE_ADDR      # Load base address into a register (a4)

  # Define a separate, distant address for the lr/sc test to avoid
  # hardware reservation granule conflicts with other AMO operations.
  #.equ LRSC_ADDR, 0x81001000
  .equ LRSC_ADDR, 0x80011000

  # Define offsets from the base address.
  .equ OFFSET_VAL_1, 0
  .equ OFFSET_VAL_3, 8
  .equ OFFSET_VAL_4, 16

  # Initialize AMO test values at their base address.
  li t0, 0x00000001
  sw t0, OFFSET_VAL_1(a4)       # test_val_1 at 0x81000000

  # Initialize the lr/sc test value at its separate address.
  li t0, 0x00000008
  li a1, LRSC_ADDR              # Load a1 with the correct, isolated address
  sw t0, 0(a1)                  # Store initial value at 0x81001000

  # Initialize the remaining test values at the base address.
  li t0, 0x00000004
  sw t0, OFFSET_VAL_3(a4)       # test_val_3[0] at 0x81000008
  li t0, 0xFFFFFFF0
  sw t0, (OFFSET_VAL_3 + 4)(a4) # test_val_3[1] at 0x8100000C
  li t0, 0x000000FF
  sw t0, OFFSET_VAL_4(a4)       # test_val_4[0] at 0x81000010
  li t0, 0xFFFFFF00
  sw t0, (OFFSET_VAL_4 + 4)(a4) # test_val_4[1] at 0x81000014

  # Load the final, absolute addresses for the tests into registers.
  addi a0, a4, OFFSET_VAL_1 # Address for general AMO tests
  # a1 is already correctly loaded with LRSC_ADDR. The buggy line that overwrote it is now removed.
  addi a2, a4, OFFSET_VAL_3 # Address for min/max signed tests
  addi a3, a4, OFFSET_VAL_4 # Address for min/max unsigned tests

  # ----------------------------------------------------------------
  # Test 1: AMOSWAP.W
  # ----------------------------------------------------------------
  li t1, 0x00000002
  amoswap.w t2, t1, (a0)
  li t0, 0x00000001
  bne t2, t0, fail
  lw t3, 0(a0)
  li t0, 0x00000002
  bne t3, t0, fail

  # ----------------------------------------------------------------
  # Test 2: AMOADD.W
  # ----------------------------------------------------------------
  li t1, 0x00000003
  amoadd.w t2, t1, (a0)
  li t0, 0x00000002
  bne t2, t0, fail
  lw t3, 0(a0)
  li t0, 0x00000005
  bne t3, t0, fail

  # ----------------------------------------------------------------
  # Test 3: AMOXOR.W
  # ----------------------------------------------------------------
  li t1, 0x0000000C
  amoxor.w t2, t1, (a0)
  li t0, 0x00000005
  bne t2, t0, fail
  lw t3, 0(a0)
  li t0, 0x00000009
  bne t3, t0, fail

  # ----------------------------------------------------------------
  # Test 4: AMOAND.W
  # ----------------------------------------------------------------
  li t1, 0x00000003
  amoand.w t2, t1, (a0)
  li t0, 0x00000009
  bne t2, t0, fail
  lw t3, 0(a0)
  li t0, 0x00000001
  bne t3, t0, fail

  # ----------------------------------------------------------------
  # Test 5: AMOOR.W
  # ----------------------------------------------------------------
  li t1, 0x0000000A
  amoor.w t2, t1, (a0)
  li t0, 0x00000001
  bne t2, t0, fail
  lw t3, 0(a0)
  li t0, 0x0000000B
  bne t3, t0, fail

  # ----------------------------------------------------------------
  # Test 6: LR.W and SC.W (Successful)
  # ----------------------------------------------------------------
  # a1 now correctly holds LRSC_ADDR (0x81001000)
  lr.w t1, (a1)
  addi t1, t1, 1
  sc.w t2, t1, (a1)
  bnez t2, fail         # This should now pass, as t2 will be 0
  lw t3, 0(a1)
  li t0, 0x00000009
  bne t3, t0, fail

  # ----------------------------------------------------------------
  # Test 7: AMOMIN.W (Signed Minimum)
  # ----------------------------------------------------------------
  li t1, -1
  amomin.w t2, t1, (a2)
  li t0, 4
  bne t2, t0, fail
  lw t3, 0(a2)
  li t0, -1
  bne t3, t0, fail

  # ----------------------------------------------------------------
  # Test 8: AMOMAX.W (Signed Maximum)
  # ----------------------------------------------------------------
  li t1, 10
  addi t4, a2, 4
  amomax.w t2, t1, (t4)
  li t0, -16
  bne t2, t0, fail
  lw t3, 0(t4)
  li t0, 10
  bne t3, t0, fail

  # ----------------------------------------------------------------
  # Test 9: AMOMINU.W (Unsigned Minimum)
  # ----------------------------------------------------------------
  li t1, 200
  amominu.w t2, t1, (a3)
  li t0, 255
  bne t2, t0, fail
  lw t3, 0(a3)
  li t0, 200
  bne t3, t0, fail

  # ----------------------------------------------------------------
  # Test 10: AMOMAXU.W (Unsigned Maximum)
  # ----------------------------------------------------------------
  li t1, 0x0000FFFF
  addi t4, a3, 4
  amomaxu.w t2, t1, (t4)
  li t0, 0xFFFFFF00
  bne t2, t0, fail
  lw t3, 0(t4)
  li t0, 0xFFFFFF00
  bne t3, t0, fail

  # ----------------------------------------------------------------
  # All tests passed.
  # ----------------------------------------------------------------
  j pass

# ----------------------------------------------------------------
# Test Outcome Labels
# ----------------------------------------------------------------
pass:
  j pass

fail:
  j fail
