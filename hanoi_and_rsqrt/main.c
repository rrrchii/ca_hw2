#include <stdbool.h>
#include <stdint.h>
#include <string.h>
#include "fast_rsqrt.h"

#define printstr(ptr, length)                   \
    do {                                        \
        asm volatile(                           \
            "add a7, x0, 0x40;"                 \
            "add a0, x0, 0x1;" /* stdout */     \
            "add a1, x0, %0;"                   \
            "mv a2, %1;" /* length character */ \
            "ecall;"                            \
            :                                   \
            : "r"(ptr), "r"(length)             \
            : "a0", "a1", "a2", "a7", "memory");          \
    } while (0)

#define TEST_OUTPUT(msg, length) printstr(msg, length)

#define TEST_LOGGER(msg)                     \
    {                                        \
        char _msg[] = msg;                   \
        TEST_OUTPUT(_msg, sizeof(_msg) - 1); \
    }

extern uint64_t get_cycles(void);
extern uint64_t get_instret(void);

/* Bare metal memcpy implementation */
void *memcpy(void *dest, const void *src, size_t n)
{
    uint8_t *d = (uint8_t *) dest;
    const uint8_t *s = (const uint8_t *) src;
    while (n--)
        *d++ = *s++;
    return dest;
}

/* Software division for RV32I (no M extension) */
static unsigned long udiv(unsigned long dividend, unsigned long divisor)
{
    if (divisor == 0)
        return 0;

    unsigned long quotient = 0;
    unsigned long remainder = 0;

    for (int i = 31; i >= 0; i--) {
        remainder <<= 1;
        remainder |= (dividend >> i) & 1;

        if (remainder >= divisor) {
            remainder -= divisor;
            quotient |= (1UL << i);
        }
    }

    return quotient;
}

static unsigned long umod(unsigned long dividend, unsigned long divisor)
{
    if (divisor == 0)
        return 0;

    unsigned long remainder = 0;

    for (int i = 31; i >= 0; i--) {
        remainder <<= 1;
        remainder |= (dividend >> i) & 1;

        if (remainder >= divisor) {
            remainder -= divisor;
        }
    }

    return remainder;
}

/* Software multiplication for RV32I (no M extension) */
static uint32_t umul(uint32_t a, uint32_t b)
{
    uint32_t result = 0;
    while (b) {
        if (b & 1)
            result += a;
        a <<= 1;
        b >>= 1;
    }
    return result;
}

/* Provide __mulsi3 for GCC */
uint32_t __mulsi3(uint32_t a, uint32_t b)
{
    return umul(a, b);
}

/* Simple integer to hex string conversion */
static void print_hex(unsigned long val)
{
    char buf[20];
    char *p = buf + sizeof(buf) - 1;
    *p = '\n';
    p--;

    if (val == 0) {
        *p = '0';
        p--;
    } else {
        while (val > 0) {
            int digit = val & 0xf;
            *p = (digit < 10) ? ('0' + digit) : ('a' + digit - 10);
            p--;
            val >>= 4;
        }
    }

    p++;
    printstr(p, (buf + sizeof(buf) - p));
}

/* Simple integer to decimal string conversion */
static void print_dec(unsigned long val)
{
    char buf[20];
    char *p = buf + sizeof(buf) - 1;
    *p = '\n';
    p--;

    if (val == 0) {
        *p = '0';
        p--;
    } else {
        while (val > 0) {
            *p = '0' + umod(val, 10);
            p--;
            val = udiv(val, 10);
        }
    }

    p++;
    printstr(p, (buf + sizeof(buf) - p));
}

static void print_dec_without_newline(unsigned long val)
{
    char buf[20];
    char *p = buf + sizeof(buf) - 1;
    char *end = p;

    if (val == 0) {
        *p = '0';
        p--;
    } else {
        while (val > 0) {
            *p = '0' + umod(val, 10);
            p--;
            val = udiv(val, 10);
        }
    }

    p++;
    printstr(p, (end - p + 1));
}
/* Tower of Hanoi */
extern uint32_t tower_of_hanoi_v1(void);

static void test_tower_of_hanoi_v1(void)
{
    uint32_t ret =  tower_of_hanoi_v1();
}

/* Fast Rsqrt */
void fast_rsqrt_error(uint32_t input, uint32_t output, uint32_t expected, const char *expect_str)
{
    TEST_LOGGER("  Input:");
    print_dec_without_newline(input);
    TEST_LOGGER("  Output:");
    print_dec_without_newline(output);
    TEST_LOGGER("  Expected:");
    print_dec_without_newline(expected);

    // error percentage calculation
    // error_percentage = (output - expected) / expected * 100;
    uint32_t error = (output > expected) ? (output - expected) : (expected - output); // absolute value
    error = udiv(error, expected);
    uint32_t error_percentage = umul(error, 100);
    TEST_LOGGER("  Error : ");
    print_dec_without_newline(error_percentage);
    TEST_LOGGER(" % ");
    TEST_LOGGER(" \n ");

}

static void test_fast_rsqrt(void)
{
    uint64_t start_cycles, end_cycles, cycles_elapsed;
    uint64_t start_instret, end_instret, instret_elapsed;

    /* Test data */
    uint32_t inputs[] = {1, 4, 9, 25, 64, 144, 256};
    char *s_expect_values[] = {
        "1.0",
        "0.5",
        "0.333",
        "0.2",
        "0.125",
        "0.083",
        "0.0625"
    };

    uint32_t expect_values[] = {
        65536,
        32768,
        21845,
        13107,
        8192,
        5461,
        4096
    };

    for (int i = 0; i < sizeof(inputs) / sizeof(inputs[0]); i++) {
        start_cycles = get_cycles();
        start_instret = get_instret();

        uint32_t result = fast_rsqrt(inputs[i]); // fast_rsqrt is in fast_rsqrt.c

        end_cycles = get_cycles();
        end_instret = get_instret();
        cycles_elapsed = end_cycles - start_cycles;
        instret_elapsed = end_instret - start_instret;

        TEST_LOGGER(" Cycles: ");
        print_dec_without_newline((unsigned long) cycles_elapsed);
        TEST_LOGGER("  Instructions: ");
        print_dec((unsigned long) instret_elapsed);

        fast_rsqrt_error(inputs[i], result, expect_values[i], s_expect_values[i]);
    }
    TEST_LOGGER("\n=== Fast Rsqrt Test Completed ===\n");
}

int main(void)
{
    uint64_t start_cycles, end_cycles, cycles_elapsed;
    uint64_t start_instret, end_instret, instret_elapsed;

    /* Test1 : Tower of Hanoi */
    TEST_LOGGER("Test1 : Tower of Hanoi\n");
    start_cycles = get_cycles();
    start_instret = get_instret();

    test_tower_of_hanoi_v1();

    end_cycles = get_cycles();
    end_instret = get_instret();
    cycles_elapsed = end_cycles - start_cycles;
    instret_elapsed = end_instret - start_instret;

    TEST_LOGGER("  Cycles: ");
    print_dec((unsigned long) cycles_elapsed);
    TEST_LOGGER("  Instructions: ");
    print_dec((unsigned long) instret_elapsed);

    /* Test2 : Fast Rsqrt */
    TEST_LOGGER("Test2 : Fast Rsqrt\n");
    start_cycles = get_cycles();
    start_instret = get_instret();

    test_fast_rsqrt();

    end_cycles = get_cycles();
    end_instret = get_instret();
    
    cycles_elapsed = end_cycles - start_cycles;
    instret_elapsed = end_instret - start_instret;

    TEST_LOGGER(" Total Cycles: ");
    print_dec((unsigned long) cycles_elapsed);
    TEST_LOGGER(" Total Instructions: ");
    print_dec((unsigned long) instret_elapsed);

    TEST_LOGGER("\n=== All Tests Completed ===\n");

    return 0;
}