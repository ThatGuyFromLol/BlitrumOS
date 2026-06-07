bits 64
section .text

global pci_read_config_dword

; ==============================================================================
; FUNKCJA: pci_read_config_dword
; Przyjmuje parametry w rejestrach (zgodnie z Twoją pętlą szukającą USB):
; BH = Bus (Magistrala)
; BL = Device (Urządzenie)
; CH = Function (Funkcja)
; CL = Offset (Rejestr konfiguracyjny do odczytu)
;
; Zwraca wynik: EAX = 32-bitowa wartość z konfiguracji PCI
; ==============================================================================
pci_read_config_dword:
    push rbx
    push rcx
    push rdx

    ; Musimy zbudować 32-bitowy adres dla portu 0xCF8.
    ; Format adresu:
    ; Bit 31: Enable bit (zawsze 1)
    ; Bity 23-16: Bus
    ; Bity 15-11: Device
    ; Bity 10-8: Function
    ; Bity 7-2: Register Offset
    ; Bity 1-0: Zawsze 00 (wyrównanie do dworda)

    xor eax, eax            ; Czyszczenie EAX

    ; 1. Włącz bit aktywacji (bit 31)
    mov eax, 0x80000000

    ; 2. Dodaj Bus (BH) przesunięte o 16 bitów w lewo
    movzx edx, bh
    shl edx, 16
    or eax, edx

    ; 3. Dodaj Device (BL) przesunięte o 11 bitów w lewo
    movzx edx, bl
    and dl, 0x1F            ; Maksymalnie 32 urządzenia (0-31)
    shl edx, 11
    or eax, edx

    ; 4. Dodaj Function (CH) przesunięte o 8 bitów w lewo
    movzx edx, ch
    and dl, 0x07            ; Maksymalnie 8 funkcji (0-7)
    shl edx, 8
    or eax, edx

    ; 5. Dodaj Register Offset (CL). Maskujemy dolne bity, by wyrównać do 4 bajtów
    movzx edx, cl
    and dl, 0xFC            ; Wyzerowanie bitów 0 i 1 (dostęp 32-bitowy)
    or eax, edx

    ; --- WYSYŁANIE ADRESU ---
    mov dx, 0xCF8           ; Port adresowy PCI
    out dx, eax             ; Wyślij przygotowany adres

    ; --- ODCZYT DANYCH ---
    mov dx, 0xCFC           ; Port danych PCI
    in eax, dx              ; Pobierz 32-bitową wartość do EAX

    pop rdx
    pop rcx
    pop rbx
    ret
