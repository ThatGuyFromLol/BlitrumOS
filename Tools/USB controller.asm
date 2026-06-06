  ;  ===========================================================================
   ;urządzenia usb (klawiatura + mysz)
  ; ============================================================================
  ; pci bus finder
    find_usb_controllers:
    push ebx
    push ecx
    push edx

    mov bh, 0               ; BH = Bus (zaczynamy od 0)
.loop_bus:
    mov bl, 0               ; BL = Device (zaczynamy od 0)
.loop_dev:
    mov ch, 0               ; CH = Function (zaczynamy od 0)
.loop_func:

    ; Krok 1: Sprawdź czy urządzenie w ogóle istnieje (Offset 0x00: VendorID)
    mov cl, 0x00
    call pci_read_config_dword
    cmp ax, 0xFFFF          ; Dolne 16 bitów EAX to Vendor ID. 0xFFFF oznacza brak sprzętu
    je .next_func

    ; Krok 2: Odczytaj klasę urządzenia (Offset 0x08)
    ; EAX po odczycie zawiera: [Class Code (bajt 3)][Subclass (bajt 2)][ProgIF (bajt 1)][Revision (bajt 0)]
    mov cl, 0x08
    call pci_read_config_dword

    ; Chcemy wyizolować wyższe 24 bity (Class, Subclass, ProgIF)
    shr eax, 8              ; Przesuwamy w prawo o 8 bitów, odrzucamy Revision ID
    
    ; Sprawdzamy czy to USB xHCI:
    ; Class = 0x0C (Serial Bus), Subclass = 0x03 (USB), ProgIF = 0x30 (xHCI)
    ; Po przesunięciu w prawo daje to wartość 0x0C0330
    cmp eax, 0x0C0330
    je .found_xhci

    ; (Opcjonalnie) Możesz tu dodać sprawdzenie dla starszego EHCI (USB 2.0)
    ; cmp eax, 0x0C0320   ; EHCI ProgIF to 0x20
    ; je .found_ehci

.next_func:
    inc ch                  ; Następna funkcja (0-7)
    cmp ch, 8
    jne .loop_func

    inc bl                  ; Następne urządzenie (0-31)
    cmp bl, 32
    jne .loop_dev

    inc bh                  ; Następna magistrala (zwykle wystarczy do 16-32, max 256)
    cmp bh, 32              ; Na większości domowych PC kontrolery są na pierwszych magistralach
    jne .loop_bus

    ; Jeśli pętla się skończyła i nic nie znaleziono
    pop edx
    pop ecx
    pop ebx
    stc                     ; Ustaw flagę Carry (błąd / nie znaleziono)
    ret

.found_xhci:
    ; Znalazłeś xHCI! Teraz musimy pobrać jego fizyczny adres pamięci (BAR0).
    ; Rejestr BAR0 znajduje się pod offsetem 0x10.
    mov cl, 0x10
    call pci_read_config_dword
    
    ; Wyczyść bity konfiguracyjne BAR (bity 0-3 opisują typ pamięci, np. prefetchable itp.)
    and eax, 0xFFFFFFF0     ; EAX zawiera teraz czysty fizyczny adres rejestrów xHCI!

    pop edx
    pop ecx
    pop ebx
    clc                     ; Czyszczenie flagi Carry (sukces)
    ret
    ; xhci handshake
    xhci_bios_handshake:
    push eax
    push ebx
    push ecx
    push edx

    ; 1. Odczytaj rejestr HCCPARAMS1 (Offset 0x10 od adresu bazowego MMIO)
    ; Wyższe 16 bitów tego rejestru (bity 16-31) zawierają wskaźnik do Extended Capabilities (w dwordach)
    mov ecx, [eax + 0x10]
    shr ecx, 16             ; Przesunięcie w prawo, ECX = offset rozszerzeń (w dwordach)
    shl ecx, 2              ; Mnożenie przez 4, aby uzyskać offset w bajtach
    jz .no_extended_caps    ; Jeśli zero, brak rozszerzeń (rzadkość w xHCI)

    ; Teraz EAX + ECX wskazuje na pierwsze Extended Capability w pamięci MMIO.
    ; Musimy przeszukać listę w poszukiwaniu Capability ID = 1 (USB Legacy Support)
    mov edx, eax            ; EDX = baza MMIO
    add edx, ecx            ; EDX = adres pierwszego rozszerzenia

.search_loop:
    mov ebx, [edx]          ; Odczytaj nagłówek rozszerzenia
    mov al, bl              ; Najniższy bajt to Capability ID
    cmp al, 1               ; Czy ID == 1 (USB Legacy Support)?
    je .found_legacy

    ; Jeśli nie, sprawdź następne rozszerzenie
    ; Bajt 1 (bity 8-15) zawiera relatywny offset do następnego rozszerzenia (w dwordach)
    shr ebx, 8
    movzx ebx, bl           ; BL = następny offset
    and ebx, 0xFF
    jz .no_legacy_found     ; Jeśli następny offset to 0, lista się skończyła

    shl ebx, 2              ; Zamiana dwordów na bajty
    add edx, ebx            ; Przejdź do następnego rozszerzenia
    jmp .search_loop

.found_legacy:
    ; EDX wskazuje teraz dokładnie na rejestr USBLEGSUP (Offset 0x00 rozszerzenia Legacy)
    ; Krok A: Ustaw bit 24 (OS Owned Semaphore), nie ruszając innych bitów
    mov eax, [edx]
    or eax, 0x01000000      ; Bit 24 = 1
    mov [edx], eax          ; Zapisz z powrotem do rejestru

.wait_bios:
    ; Krok B: Czekaj w pętli, aż BIOS wyczyści bit 16 (BIOS Owned Semaphore) 
    ; oraz Twój bit 24 (OS Owned) zostanie zaakceptowany.
    mov eax, [edx]
    test eax, 0x00010000    ; Sprawdź bit 16 (BIOS Owned)
    jnz .wait_bios          ; Jeśli wciąż ustawiony, czekaj (wiruj)

    ; Krok C: Dodatkowe upewnienie się. Kontroler ma też rejestr USBLEGCTLSTS 
    ; (zazwyczaj pod offsetem EDX + 4), gdzie należy wyłączyć bity SMI (SMI wywoływane przez BIOS)
    ; aby BIOS nie dostawał przerwań w tle.
    mov eax, [edx + 4]
    and eax, 0xFFFFE000     ; Wyczyszczenie dolnych bitów kontroli SMI (bity 0-14)
    mov [edx + 4], eax

.no_legacy_found:
.no_extended_caps:
    pop edx
    pop ecx
    pop ebx
    pop eax
    ret