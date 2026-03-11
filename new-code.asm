[bits 16]
[org 0x7C00]

start:
    jmp 0:init          ; Wymuszenie CS=0 (kluczowe na starych płytach)

init:
    cli
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00 

    ; Odblokowanie A20 (Fast A20)
    in al, 0x92
    or al, 2
    out 0x92, al

    ; Ładowanie GDT
    lgdt [gdt_descriptor]

    ; Przełączenie na Protected Mode
    mov eax, cr0
    or eax, 1
    mov cr0, eax

    ; Daleki skok, aby wyczyścić kolejkę instrukcji i ustawić CS
    jmp 0x08:protected_mode

[bits 32]
protected_mode:
    ; Ustawienie rejestrów danych (selektor 0x10)
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    mov esp, 0x90000

    ; Wypisanie "AA" na zielonym tle (0x2F)
    ; Adres 0xB8000 to początek pamięci tekstowej VGA
    mov dword [0xB8000], 0x2F412F41 

    jmp $               ; Nieskończona pętla (bezpieczniejsza niż hlt)

; --- DANE GDT NA KOŃCU (bezpieczne miejsce) ---
align 16                ; Wyrównanie dla starych procesorów
gdt_start:
    dq 0x0              ; Null descriptor
gdt_code:               ; Kod: base=0, limit=0xfffff, flags=0xcf, access=0x9a
    dw 0xFFFF, 0x0000
    db 0x00, 0x9A, 0xCF, 0x00
gdt_data:               ; Dane: base=0, limit=0xfffff, flags=0xcf, access=0x92
    dw 0xFFFF, 0x0000
    db 0x00, 0x92, 0xCF, 0x00
gdt_end:

gdt_descriptor:
    dw gdt_end - gdt_start - 1
    dd gdt_start

times 510 - ($-$$) db 0
dw 0xAA55
