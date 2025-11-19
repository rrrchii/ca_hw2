.section .text

clz:
    beq   a0, x0, zero      # if (x == 0) return 32

    li    t0, 0             # n = 0
    
    srli  t1, a0, 16
    bne   t1, x0, chk8
    addi  t0, t0, 16
    slli  a0, a0, 16        # if ((x >> 16) == 0) { n += 16; x <<= 16; }

chk8:
    srli  t1, a0, 24
    bne   t1, x0, chk4
    addi  t0, t0, 8
    slli  a0, a0, 8          # if ((x >> 24) == 0) { n += 8; x <<= 8; }

chk4:
    srli  t1, a0, 28
    bne   t1, x0, chk2
    addi  t0, t0, 4
    slli  a0, a0, 4          # if ((x >> 28) == 0) { n += 4; x <<= 4; }

chk2:
    srli  t1, a0, 30
    bne   t1, x0, chk1
    addi  t0, t0, 2
    slli  a0, a0, 2           # if ((x >> 30) == 0) { n += 2; x <<= 2; }

chk1:
    srli  t1, a0, 31
    bne   t1, x0, ret
    addi  t0, t0, 1           # if ((x >> 31) == 0) { n += 1; }

ret:
    mv    a0, t0               # return n
    ret

zero:
    li    a0, 32
    ret

    
.globl uf8_decode
.type uf8_decode,%function
.align 2
uf8_decode:
    andi  t0, a0, 0x0F     # t0 is mantissa
    srli  t1, a0, 4        # t1 is exponent
    
    li    t2, 15
    sub   t2, t2, t1       # t2 = 15 - exponent
    
    li    t3, 0x7FFF
    srl   t3, t3, t2
    slli  t3, t3, 4        # t3 is offset
    
    sll   t0, t0, t1       # mantissa << exponent
    add   a0, t0, t3       # fl = (mantissa << exponent) + offset    
    
    ret
.size uf8_decode,.-uf8_decode


.globl uf8_encode
.type uf8_encode,%function
.align 2
uf8_encode:
    addi  sp, sp, -4
    sw    ra, 0(sp)        # because it will call CLZ in this function
    
    li    t4, 16           # t4 = 16
    bltu  a0, t4, fast_return    # if( value < 16 ) return value;
    
    mv    t5, a0           # t5 = value use t5 input clz
    jal   ra, clz
    mv    t0, a0           # t0 = lz
    li    t1, 31
    sub   t1, t1, t0       # t1 = msb
    
    li    t2, 0            # exponent = 0
    li    t3, 0            # overflow = 0
    
    li    t4, 5            # t6 = 5
    blt   t1, t4, after_adjust_down
    addi  t2, t1, -4       # exponent = msb - 4
    
    li    t4, 15           # t6 = 15
    bleu  t2, t4, exp_ok   # if(exp > 15)
    li    t2, 15           # exp = 15
    
exp_ok:   
    li     t4, 0            # t4 = counter e = 0
    
build_overflow:
    bgeu   t4, t2, adjust_overflow
    slli   t3, t3, 1       # overflow <<= 1
    addi   t3, t3, 16      # (overflow << 1) + 16
    addi   t4, t4, 1       # e ++
    j      build_overflow
    
adjust_overflow:

adjust_down:
    beq    t2, x0, after_adjust_down     # exp > 0
    bgeu   t5, t3, after_adjust_down     # value < overflow
    addi   t3, t3, -16                   # overflow - 16
    srli   t3, t3, 1                     # (overflow - 16) >> 1
    addi   t2, t2, -1                    # exp --
    j      adjust_down

after_adjust_down:
    li     t6, 15
    li     t4, 0
    
adjust_up:
    bgeu   t2, t6, after_estimate_overflow
    slli   t4, t3, 1                     # next_overflow = (overflow << 1)
    addi   t4, t4, 16                    # next_overflow = (overflow << 1) + 16
    blt    t5, t4, after_estimate_overflow
    mv     t3, t4                        # overflow = next_overflow
    addi   t2, t2, 1                     # exp ++
    j      adjust_up

after_estimate_overflow:
    
ret_val:
    sub    t5, t5, t3
    srl    t5, t5, t2                    # t5 is mantissa
    
    slli   a0, t2, 4
    or     a0, a0, t5
    
fast_return:
    lw ra, 0(sp)
    addi sp, sp, 4
    jr ra
.size uf8_encode,.-uf8_encode