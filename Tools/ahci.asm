bits 64
section .text

; --- DEKLARACJE GLOBALNE (Widoczne dla kernela) ---
global find_ahci_controller
global init_ahci_controller
global check_ahci_ports
global pci_read_config_dword

; ==============================================================================
; FUNKCJA: find_ahci_controller
; Skanuje magistralę PCI w poszukiwaniu kontrolera dysków SATA AHCI.
; ==============================================================================
find_ahci_controller:
    push rbx
    push rcx
    push rdx

    mov bh, 0               ; BH = Bus (Magistrala)
.loop_bus:
    mov bl, 0               ; BL = Device (Urządzenie)
.loop_dev:
    mov ch, 0               ; CH = Function (Funkcja)
.loop_func:

    ; Krok 1: Sprawdź Vendor ID (Offset 0x00)
    mov cl, 0x00
    call pci_read_config_dword
    cmp ax, 0xFFFF          ; 0xFFFF = brak urządzenia
    je .next_func

    ; Krok 2: Odczytaj klasę urządzenia (Offset 0x08)
    mov cl, 0x08
    call pci_read_config_dword

    ; Wyższe 24 bity to: Class (bajt 3), Subclass (bajt 2), ProgIF (bajt 1)
    shr eax, 8              ; Odrzucamy Revision ID
    
    ; Sprawdzamy, czy to AHCI (Class=0x01, Subclass=0x06, ProgIF=0x01)
    cmp eax, 0x010601
    je .found_ahci

.next_func:
    inc ch                  
    cmp ch, 8
    jne .loop_func

    inc bl                  
    cmp bl, 32
    jne .loop_dev

    inc bh                  
    cmp bh, 32              
    jne .loop_bus

    ; Jeśli pętla się skończyła i nic nie znaleziono
    pop rdx
    pop rcx
    pop rbx
    stc                     ; Flaga Carry = błąd
    ret

.found_ahci:
    ; W specyfikacji AHCI adres rejestrów pamięci (MMIO) zawsze znajduje się w BAR5.
    ; Rejestr BAR5 w przestrzeni konfiguracyjnej PCI ma offset 0x24.
    mov cl, 0x24
    call pci_read_config_dword
    mov rdx, rax            ; Zachowaj dolną część adresu w RDX
    
    ; Sprawdź bity 1-2 w BAR5, czy adres jest 64-bitowy
    and al, 0x06
    cmp al, 0x04            ; Czy UEFI zmapowało AHCI w 64 bitach?
    jne .bar_32bit

.bar_64bit:
    ; Pobierz wyższe 32 bity adresu z BAR6 (Offset 0x28)
    mov cl, 0x28
    call pci_read_config_dword
    shl rax, 32             
    and rdx, 0xFFFFFFF0     ; Wyczyść bity konfiguracyjne dolnej części
    or rdx, rax             ; Połącz w pełny adres 64-bitowy
    jmp .done

.bar_32bit:
    and rdx, 0xFFFFFFF0     ; Wyczyść bity konfiguracyjne dla 32-bit BAR

.done:
    mov rax, rdx            ; RAX zawiera teraz poprawny adres MMIO dla AHCI
    pop rdx
    pop rcx
    pop rbx
    clc                     ; Sukces (Carry = 0)
    ret


; ==============================================================================
; FUNKCJA: init_ahci_controller
; Włącza tryb AHCI w kontrolerze (ustawia bit AE w rejestrze GHC).
; Wejście: RAX = 64-bitowy adres MMIO kontrolera AHCI
; ==============================================================================
init_ahci_controller:
    push rax
    push rbx

    ; Rejestr GHC (Global Host Control) znajduje się pod offsetem 0x04
    ; Ustawiamy bit 31 (AE - AHCI Enable)
    mov ebx, [rax + 0x04]
    or ebx, 0x80000000      
    mov [rax + 0x04], ebx

    pop rbx
    pop rax
    ret


; ==============================================================================
; FUNKCJA: check_ahci_ports
; Przeszukuje porty SATA i zwraca maskę bitową podłączonych dysków HDD/SSD.
; Wejście: RAX = 64-bitowy adres MMIO kontrolera AHCI
; Zwraca:  EBX = Maska bitowa podłączonych dysków
; ==============================================================================
check_ahci_ports:
    push rsi
    push rcx
    push rdx

    ; Odczyt rejestru PI (Ports Implemented) pod offsetem 0x0C
    mov edx, [rax + 0x0C]   
    
    xor ebx, ebx            ; Wyczyszczenie maski wynikowej
    mov ecx, 0              ; Licznik pętli (porty 0-31)

.port_loop:
    bt edx, ecx             ; Czy port fizycznie istnieje?
    jnc .next_port          

    ; Oblicz adres rejestrów portu: Baza + 0x100 + (Port * 0x80)
    mov rsi, rcx
    shl rsi, 7              ; Mnożenie przez 128 (0x80)
    add rsi, 0x100
    add rsi, rax            

    ; Odczyt rejestru SSTS (Serial ATA Status) pod offsetem 0x28
    mov eax, [rsi + 0x28]
    and eax, 0x0F
    cmp eax, 0x03           ; Czy wykryto urządzenie i nawiązano stabilne połączenie?
    jne .next_port          

    ; Odczyt rejestru SIG (Signature) pod offsetem 0x24
    mov eax, [rsi + 0x24]
    cmp eax, 0x00000101     ; Czy sygnatura odpowiada dyskowi SATA HDD/SSD?
    jne .next_port

    bts ebx, ecx            ; Zaznacz dysk w masce bitowej

.next_port:
    inc ecx
    cmp ecx, 32             ; Maksymalnie 32 porty w specyfikacji AHCI
    jl .port_loop

    pop rdx
    pop rcx
    pop rsi
    ret


; ==============================================================================
; FUNKCJA POMOCNICZA: pci_read_config_dword
; Odczytuje 32-bitowy rejestr konfiguracyjny PCI przez porty we/wy.
; Wejście: BH = Bus, BL = Device, CH = Function, CL = Offset
; Zwraca:  EAX = Odczytana wartość
; ==============================================================================
pci_read_config_dword:
    push rbx
    push rcx
    push rdx

    xor eax, eax            
    mov eax, 0x80000000     ; Bit 31 = 1 (Enable)

    movzx edx, bh
    shl edx, 16
    or eax, edx             

    movzx edx, bl
    and dl, 0x1F            
    shl edx, 11
    or eax, edx             

    movzx edx, ch
    and dl, 0x07            
    shl edx, 8
    or eax, edx             

    movzx edx, cl
    and dl, 0xFC            ; Wyrównanie offsetu do dworda (4 bajty)
    or eax, edx             

    mov dx, 0xCF8
    out dx, eax             

    mov dx, 0xCFC
    in eax, dx              

    pop rdx
    pop rcx
    pop rbx
    ret
