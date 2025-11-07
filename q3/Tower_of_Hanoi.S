.text
.globl  tower_of_hanoi_v1
.type tower_of_hanoi_v1,%function
.align 2

# gray code 僅限判斷disk 0 or 1 or 2被移動，沒辦法知道移去哪裡，若disk數量n為基數(偶數)會依照順時針(逆時針)移動
tower_of_hanoi_v1:
    addi    x2, x2, -32  # x2 = sp
    sw      x8, 0(x2)
    sw      x9, 4(x2)
    sw      x18, 8(x2)
    sw      x19, 12(x2)
    sw      x20, 16(x2)

    # Fix disk positions (BLANK 1-3: neutralize x5 effect)
    # BLANK 1: Fix position at x2+20
    # defult pos[0] = 0 smallest plate is at pool A
    sw      x0, 20(x2)

    # BLANK 2: Fix position at x2+24
    # deuflt pos[1] = 0 medium plate is at pool A
    sw      x0, 24(x2)

    # BLANK 3: Fix position at x2+28
    # defult pos[1] = 0 largest plate is at pool A
    sw      x0, 28(x2)

    addi    x8, x0, 1
game_loop:
    # BLANK 4: Check loop termination (2^3 moves)
    addi    x5, x0, 8
    beq     x8, x5, finish_game

    # Gray code formula: gray(n) = n XOR (n >> k)
    # BLANK 5: What is k for Gray code?
    srli    x5, x8, 1

    # BLANK 6: Complete Gray(n) calculation
    xor     x6, x8, x5  # x6 = Gray(n)

    # BLANK 7-8: Calculate previous value and its shift
    addi    x7, x8, -1
    srli    x28, x7, 1

    # BLANK 9: Generate Gray(n-1)
    xor     x7, x7, x28  # x7 = Gray(n-1)

    # BLANK 10: Which bits changed?
    xor     x5, x6, x7   # x5 = 001(disk0 changed), 010(disk1 changed), 100(disk2 changed)

    # Initialize disk number
    addi    x9, x0, 0  # changed disk : disk 0

    # BLANK 11: Mask for testing LSB
    andi    x6, x5, 1  # 010 chk is disk 0 change ? 

    # BLANK 12: Branch if disk 0 moves
    bne     x6, x0, disk_found

    # BLANK 13: Set disk 1
    addi    x9, x0, 1  # changed disk : disk 1

    # BLANK 14: Test second bit with proper mask
    andi    x6, x5, 2  # 010 chk is disk 1 change ? 
    bne     x6, x0, disk_found

    # BLANK 15: Last disk number
    addi    x9, x0, 2  # else changed disk : disk 2

disk_found:
    # BLANK 16: Check impossible pattern (multiple bits)
    andi    x30, x5, 5 # using 101 to chk impossible pattern
    addi    x31, x0, 5 
    beq     x30, x31, pattern_match 
    jal     x0, continue_move
    
pattern_match:
continue_move:
    # BLANK 17: Word-align disk index (multiply by what?)
    slli    x5, x9, 2  #times 4 brcause every word takes 4 byte

    # BLANK 18: Base offset for disk array
    # 先把偏移加上去，因為pos[0]在x2+20的地方
    # 假設要找pos[1] step1. [x5 = 1 * 4] step2. [x5 = 4 + 20] step3. [x5 = sp + 24] 
    addi    x5, x5, 20
    add     x5, x2, x5
    lw      x18, 0(x5)  # 載入該disk的舊柱子 x18 = 0 or 1 or 2

    bne     x9, x0, handle_large  # smallset disk : d = 0

    # BLANK 19: Small disk moves by how many positions?
    #  x19(small disk new position), A -> C, B ->A, C -> B
    addi    x19, x18, 2   # disk0 will take 2 step by 順時針 when it needs to move

    # BLANK 20: Number of pegs
    # x19(disk new position)
    addi    x6, x0, 3
    blt     x19, x6, display_move # if smaller than 3 means correct
    sub     x19, x19, x6  # sub by 3 adjust to correct num range
    jal     x0, display_move 

handle_large:
    # means x9(changed disk) is not the smallest : d = 1 or 2
    # BLANK 21: Load reference disk position
    lw      x6, 20(x2)  # smallest disk position

    # BLANK 22: Sum of all peg indices (0+1+2)
    # ex : smallest disk at peg2, now move medium disk at peg0
    # So 3 - 2 - 0 = 1 -> peg1 , that mean x19(mediem disk new position) is peg1
    addi    x19, x0, 3
    sub     x19, x19, x18  # x18(disk position) maybe 0 or 1 or 2
    sub     x19, x19, x6   # x6(smallest disk position) maybe 0 or 1 or 2

display_move:
    la      x20, obdata
    add     x5, x20, x18  # x5 = x20(obdata address) + x18(disk position(0/1/2)) related to (A/B/C)

    # BLANK 23: Load byte from obfuscated data
    lbu     x13, 0(x5)  # x13 maybe (0x3c/0x3b/0x3a)

    # BLANK 24: Decode constant (0x6F)
    li      x6, 0x6F
    xor     x13, x13, x6

    # BLANK 25: Final offset adjustment
    addi    x13, x13, -0x12  # after decode x13 get (0x41('A')/0x42('B')/0x43('C'))

    add     x7, x20, x19   # x7 = x20(obdata address) + x19(disk new position(0/1/2)) related to (A/B/C)
    lbu     x16, 0(x7)     
    xor     x16, x16, x6
    addi    x16, x16, -0x12 # after decode x16 get (0x41('A')/0x42('B')/0x43('C'))
    
    # print("Move Disk <d+1> from <A/B/C> to <A/B/C>\n")
    
    # x17=64 x10  x11    x12 
    # write  (1,  str1,  10);
    li       a0, 1  # a0 = 1 : stdout
    la       a1, str1  # a1 : "Move Disk" address
    li       a2, 10  # a2 = 10 : output 10 character
    li       a7, 64  # a7 = 64 : Linux 'write'
    #la      x10, str1  # "Move Disk"
    #addi    x17, x0, 4 # a7 == 4 print_str
    ecall
    
    
    li       a0, 1  
    la       a1, disk
    add      a1, a1, x9  
    li       a2, 1  
    li       a7, 64  
    #addi    x10, x9, 1 # disk + 1 = 1/2/3
    #addi    x17, x0, 1 # a7 == 1 print_int
    ecall
    
    
    li       a0, 1  
    la       a1, str2  
    li       a2, 6  
    li       a7, 64  
    #la      x10, str2  # " from "
    #addi    x17, x0, 4
    ecall
    
    
    li       a0, 1  
    la       a1, peg
    addi     x13, x13, -65  # x13 maybe : 0x41/0x42/0x43
    add      a1, a1, x13
    li       a2, 1  
    li       a7, 64
    #addi    x10, x11, 0  # disk position = A/B/C
    #addi    x17, x0, 11 # a7 == 11 print_char
    ecall
    
    li       a0, 1  
    la       a1, str3  
    li       a2, 4  
    li       a7, 64
    #la      x10, str3  # " to "
    #addi    x17, x0, 4
    ecall
    
    li       a0, 1  
    la       a1, peg
    addi     x16, x16, -65  # x16 maybe : 0x41/0x42/0x43
    add      a1, a1, x16
    li       a2, 1  
    li       a7, 64
    #addi    x10, x12, 0  # disk new position = A/B/C
    #addi    x17, x0, 11
    ecall
    
    li       a0, 1  
    la       a1, newline  
    li       a2, 1  
    li       a7, 64
    #addi    x10, x0, 10  # '\n'
    #addi    x17, x0, 11
    ecall                   

    # BLANK 26: Calculate storage offset
    slli    x5, x9, 2  # x5 = disk(0/1/2) * 4
    addi    x5, x5, 20  # x5(add offset) = x5 + 20
    add     x5, x2, x5  # x5(real position) = sp + x5

    # BLANK 27: Update disk position
    sw      x19, 0(x5) # x19(disk new position) save at 0(x5)

    # BLANK 28-29: Increment counter and loop
    addi    x8, x8, 1 # counter + 1
    jal     x0, game_loop


finish_game:
    # excute 8 times of gameloop will finish game
    lw      x8, 0(x2)
    lw      x9, 4(x2)
    lw      x18, 8(x2)
    lw      x19, 12(x2)
    lw      x20, 16(x2) 
    addi    x2, x2, 32  # release stack
    
    li a0, 0 # return 0 if successful exit
    jr ra
    
    #addi    x17, x0, 10
    #ecall

.data
obdata:     .byte   0x3c, 0x3b, 0x3a
peg:        .byte   0x41, 0x42, 0x43 # ascii code: 'A' 'B' 'C'
disk:       .byte   0x32, 0x33, 0x34 # ascii code: '1' '2' '3'
str1:       .asciz  "Move Disk "
str2:       .asciz  " from "
str3:       .asciz  " to "
newline:    .asciz  "\n "
