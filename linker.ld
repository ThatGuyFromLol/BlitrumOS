/* ==============================================================================
   ZUNIFIKOWANY SKRYPT KONFIGURACYJNY LINKERA DLA JĄDRA TRYBU LONG MODE
   ============================================================================== */
OUTPUT_FORMAT("binary")         /* Generujemy czysty plik binarny (kernel.bin) */
ENTRY(_start)                   /* Informujemy, że punkt startowy to etykieta _start */

SECTIONS
{
    /* Wymuszamy ulokowanie jądra dokładnie pod adresem fizycznym 0x00100000 */
    . = 0x00100000;

    /* Sekcja kodu maszynowego (.text) */
    .text : ALIGN(4096)
    {
        *(.text)
    }

    /* Sekcja danych zainicjalizowanych oraz stałych (.data / .rodata) */
    .data : ALIGN(4096)
    {
        *(.data)
        *(.rodata)
    }

    /* Sekcja zmiennych oraz stosów systemowych (.bss) */
    .bss : ALIGN(4096)
    {
        *(.bss)
        *(COMMON)
    }
}
