#include <stdio.h>
#include <stdint.h>
#include "system.h"   /* provides the ADD32() custom-instruction macro */

int main(void)
{
    printf("Nios V/g custom-instruction 32-bit adder test\n");
    printf("----------------------------------------------\n");

    struct { uint32_t a, b; } tests[] = {
        { 123456u,      654321u     },
        { 0u,           0u          },
        { 0xFFFFFFFFu,  1u          },  /* wraps around to 0 */
        { 2000000000u,  2000000000u },  /* wraps past 2^32   */
        { 0xDEADBEEFu,  0x00000001u },
    };

    int n = (int)(sizeof(tests) / sizeof(tests[0]));
    int pass = 1;

    for (int i = 0; i < n; i++) {
        uint32_t a  = tests[i].a;
        uint32_t b  = tests[i].b;
        uint32_t hw = (uint32_t) ADD32(a, b);  /* hardware custom instruction */
        uint32_t sw = a + b;                   /* software reference          */

        printf("ADD32(%10u, %10u) = %10u  [sw=%10u]  %s\n",
               a, b, hw, sw, (hw == sw) ? "OK" : "MISMATCH");

        if (hw != sw) pass = 0;
    }

    printf("----------------------------------------------\n");
    printf("%s\n", pass ? "ALL TESTS PASSED" : "TEST FAILED");

    while (1) { /* idle */ }
    return 0;
}
