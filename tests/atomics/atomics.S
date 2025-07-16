.section .text.init
.globl _start

_start:
  # ----------------------------------------------------------------
  # Test Setup
  # ----------------------------------------------------------------
  # Load addresses of test variables into registers.
  la a0, test_val_1     # Address for general AMO tests
  la a1, test_val_2     # Address for lr/sc test
  la a2, test_val_3     # Address for min/max signed tests
  la a3, test_val_4     # Address for min/max unsigned tests

  # Initialize test values in memory
  li t0, 0x00000001
  sw t0, 0(a0)
  li t0, 0x00000008
  sw t0, 0(a1)
  li t0, 0x00000004       # Initial value for signed min/max
  sw t0, 0(a2)
  li t0, 0xFFFFFFF0       # Initial value for signed min/max (negative)
  sw t0, 4(a2)
  li t0, 0x000000FF       # Initial value for unsigned min/max
  sw t0, 0(a3)
  li t0, 0xFFFFFF00       # Initial value for unsigned min/max (large unsigned)
  sw t0, 4(a3)


  # ----------------------------------------------------------------
  # Test 1: AMOSWAP.W
  # ----------------------------------------------------------------
  # Atomically swap the value in memory with a new value.
  # Initial memory (a0): 0x00000001
  li t1, 0x00000002      # New value to swap
  amoswap.w t2, t1, (a0) # t2 = old_val, mem(a0) = t1
  # Verify: t2 should hold the old value (1)
  li t0, 0x00000001
  bne t2, t0, fail
  # Verify: Memory should now hold the new value (2)
  lw t3, 0(a0)
  li t0, 0x00000002
  bne t3, t0, fail

  # ----------------------------------------------------------------
  # Test 2: AMOADD.W
  # ----------------------------------------------------------------
  # Atomically add a value to the memory location.
  # Initial memory (a0): 0x00000002
  li t1, 0x00000003      # Value to add
  amoadd.w t2, t1, (a0)  # t2 = old_val, mem(a0) = old_val + t1
  # Verify: t2 should hold the old value (2)
  li t0, 0x00000002
  bne t2, t0, fail
  # Verify: Memory should hold the new value (2 + 3 = 5)
  lw t3, 0(a0)
  li t0, 0x00000005
  bne t3, t0, fail

  # ----------------------------------------------------------------
  # Test 3: AMOXOR.W
  # ----------------------------------------------------------------
  # Atomically XOR a value with the memory location.
  # Initial memory (a0): 0x00000005 (binary 0101)
  li t1, 0x0000000C      # Value to XOR (binary 1100)
  amoxor.w t2, t1, (a0)  # t2 = old_val, mem(a0) = old_val ^ t1
  # Verify: t2 should hold the old value (5)
  li t0, 0x00000005
  bne t2, t0, fail
  # Verify: Memory should hold the new value (5 ^ 12 = 9) (0101 ^ 1100 = 1001)
  lw t3, 0(a0)
  li t0, 0x00000009
  bne t3, t0, fail

  # ----------------------------------------------------------------
  # Test 4: AMOAND.W
  # ----------------------------------------------------------------
  # Atomically AND a value with the memory location.
  # Initial memory (a0): 0x00000009 (binary 1001)
  li t1, 0x00000003      # Value to AND (binary 0011)
  amoand.w t2, t1, (a0)  # t2 = old_val, mem(a0) = old_val & t1
  # Verify: t2 should hold the old value (9)
  li t0, 0x00000009
  bne t2, t0, fail
  # Verify: Memory should hold the new value (9 & 3 = 1) (1001 & 0011 = 0001)
  lw t3, 0(a0)
  li t0, 0x00000001
  bne t3, t0, fail

  # ----------------------------------------------------------------
  # Test 5: AMOOR.W
  # ----------------------------------------------------------------
  # Atomically OR a value with the memory location.
  # Initial memory (a0): 0x00000001 (binary 0001)
  li t1, 0x0000000A      # Value to OR (binary 1010)
  amoor.w t2, t1, (a0)   # t2 = old_val, mem(a0) = old_val | t1
  # Verify: t2 should hold the old value (1)
  li t0, 0x00000001
  bne t2, t0, fail
  # Verify: Memory should hold the new value (1 | 10 = 11) (0001 | 1010 = 1011)
  lw t3, 0(a0)
  li t0, 0x0000000B
  bne t3, t0, fail

  # ----------------------------------------------------------------
  # Test 6: LR.W and SC.W (Successful)
  # ----------------------------------------------------------------
  # Load-Reserved and Store-Conditional.
  # Initial memory (a1): 0x00000008
  lr.w t1, (a1)          # Load and reserve address a1
  addi t1, t1, 1         # Increment the value
  sc.w t2, t1, (a1)      # Attempt to store back. Should succeed.
  # Verify: t2 should be 0 for success
  bnez t2, fail
  # Verify: Memory should hold the new value (8 + 1 = 9)
  lw t3, 0(a1)
  li t0, 0x00000009
  bne t3, t0, fail

  # ----------------------------------------------------------------
  # Test 7: AMOMIN.W (Signed Minimum)
  # ----------------------------------------------------------------
  # Initial memory (a2): 4
  li t1, -1              # New value is smaller
  amomin.w t2, t1, (a2)  # t2 = 4, mem(a2) = min(4, -1) = -1
  li t0, 4
  bne t2, t0, fail
  lw t3, 0(a2)
  li t0, -1
  bne t3, t0, fail

  # ----------------------------------------------------------------
  # Test 8: AMOMAX.W (Signed Maximum)
  # ----------------------------------------------------------------
  # Initial memory (a2+4): -16 (0xFFFFFFF0)
  li t1, 10              # New value is larger
  addi t4, a2, 4         # CORRECT: AMO does not support imm offset, so calculate address first
  amomax.w t2, t1, (t4)  # t2 = -16, mem(a2+4) = max(-16, 10) = 10
  li t0, -16
  bne t2, t0, fail
  lw t3, 0(t4)           # Verify using the calculated address
  li t0, 10
  bne t3, t0, fail

  # ----------------------------------------------------------------
  # Test 9: AMOMINU.W (Unsigned Minimum)
  # ----------------------------------------------------------------
  # Initial memory (a3): 255 (0x000000FF)
  li t1, 200             # New value is smaller
  amominu.w t2, t1, (a3) # t2 = 255, mem(a3) = min(255, 200) = 200
  li t0, 255
  bne t2, t0, fail
  lw t3, 0(a3)
  li t0, 200
  bne t3, t0, fail

  # ----------------------------------------------------------------
  # Test 10: AMOMAXU.W (Unsigned Maximum)
  # ----------------------------------------------------------------
  # Initial memory (a3+4): 0xFFFFFF00 (large unsigned)
  li t1, 0x0000FFFF      # New value is smaller
  addi t4, a3, 4         # CORRECT: AMO does not support imm offset, so calculate address first
  amomaxu.w t2, t1, (t4) # t2 = 0xFFFFFF00, mem(a3+4) = max(0xFFFFFF00, 0x0000FFFF) = 0xFFFFFF00
  li t0, 0xFFFFFF00
  bne t2, t0, fail
  lw t3, 0(t4)           # Verify using the calculated address
  li t0, 0xFFFFFF00
  bne t3, t0, fail


  # ----------------------------------------------------------------
  # All tests passed. Jump to the pass label.
  # ----------------------------------------------------------------
  j pass

# ----------------------------------------------------------------
# Test Outcome Labels
# ----------------------------------------------------------------
pass:
  # Infinite loop to indicate success
  j pass

fail:
  # Infinite loop to indicate failure
  # In a real test environment, this might write to a host device.
  j fail

# ----------------------------------------------------------------
# Data Section
# ----------------------------------------------------------------
.section .data
.align 4
test_val_1: .word 0
test_val_2: .word 0
test_val_3: .word 0, 0
test_val_4: .word 0, 0
