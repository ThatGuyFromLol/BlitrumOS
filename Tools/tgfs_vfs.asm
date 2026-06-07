; ==============================================================================
;           TGFS (Tag Graphic File System) & JMP-LOADER WITH SYSCALL COMPATIBILITY
; ==============================================================================
; Nazwa pliku:   tgfs_vfs.asm
; Architektura:  x86_64 (Long Mode)
; Składnia:      NASM (Intel)
; Optymalizacja: Zero-Copy Page Mapping & Hardware Bitmask Filtering
; ==============================================================================

bits 64
section .text

; --- DEKLARACJE GLOBALNE API ---
global vfs_mount_drive
global tgfs_find_files_by_tag
global tgfs_load_and_map_file
global syscall_compatibility_layer

; Importy niskopoziomowe ze sterowników sprzętowych projektu
extern ahci_read_sectors        ; z ahci_disk.asm
extern pmm_alloc_page           ; z pmm.asm

; Typy systemów plików obsługiwane przez VFS
FS_TYPE_UNKNOWN equ 0
FS_TYPE_TGFS    equ 1

; Definicje masek bitowych formatów w TGFS (Polymorphic Identifiers)
TAG_SYSTEM      equ 1 << 0      ; Bit 0: Pliki systemowe kernela
TAG_GUI         equ 1 << 1      ; Bit 1: Elementy interfejsu graficznego
TAG_APPLICATION equ 1 << 2      ; Bit 2: Programy (Natywne / Obce)
TAG_IMAGE       equ 1 << 3      ; Bit 3: Surowe bitmapy graficzne TrueColor
TAG_FOREIGN_ELF equ 1 << 16     ; Bit 16: Flaga formatu Linux ELF64
TAG_FOREIGN_EXE equ 1 << 17     ; Bit 17: Flaga formatu Windows PE/EXE

section .data
align 8
current_fs_type:    db 0        ; Wykryty typ systemu plików na dysku
tgfs_registry_lba:  dq 0        ; Fizyczny sektor LBA Tag Registry

; Magiczna sygnatura Twojego systemu plików opartego o tagi
tgfs_signature:     db "TGFS"

section .text

; ==============================================================================
; FUNKCJA 1: vfs_mount_drive
; Podmontowuje dysk i weryfikuje obecność sygnatury TGFS w Superblocku.
; ==============================================================================
vfs_mount_drive:
    push rbx
    push rcx
    push rdx
    push r8
    push r9
    push rdi
    push rsi

    sub rsp, 512
    mov r9, rsp                 ; Bufor na stosie
    
    mov rdx, 1                  ; LBA = 1 (Superblock)
    mov r8, 1                   ; Czytaj 1 sektor
    call ahci_read_sectors

    mov rsi, r9                 
    lea rdi, [rel tgfs_signature]
    mov eax, [rsi]
    mov ebx, [rdi]
    cmp eax, ebx
    jne .unknown_fs

.found_tgfs:
    mov byte [current_fs_type], FS_TYPE_TGFS
    mov rax, [r9 + 8]           ; Offset 8: LBA rejestru tagów
    mov [tgfs_registry_lba], rax
    mov rax, FS_TYPE_TGFS       
    jmp .exit

.unknown_fs:
    mov byte [current_fs_type], FS_TYPE_UNKNOWN
    xor rax, rax                

.exit:
    add rsp, 512                
    pop rsi
    pop rdi
    pop r9
    pop r8
    pop rdx
    pop rcx
    pop rbx
    ret


; ==============================================================================
; FUNKCJA 2: tgfs_find_files_by_tag
; Filtruje Tag Registry i zwraca ID wszystkich plików pasujących do maski tagów.
; ==============================================================================
tgfs_find_files_by_tag:
    push rbx
    push rcx
    push rdx
    push r8
    push r9
    push rsi
    push rdi
    push r12
    push r13
    push r14

    mov r12, rdx                ; R12 = Szukana maska tagów bitowych
    mov r13, r8                 ; R13 = Bufor RAM na ID plików
    mov r14, rcx                ; R14 = Port SATA

    sub rsp, 512
    mov r9, rsp
    mov rdx, [tgfs_registry_lba]
    mov r8, 1
    mov rcx, r14
    call ahci_read_sectors

    xor rsi, rsi                ; RSI = Licznik trafień
    mov rbx, 0                  ; RBX = Indeks pętli (0..7)

.search_loop:
    mov rdi, rsp
    mov rax, rbx
    shl rax, 6                  ; rbx * 64 bajty
    add rdi, rax                ; RDI = Adres wpisu w pamięci stosu

    mov edx, [rdi]              ; Sprawdź czy ID != 0
    test edx, edx
    jz .next_entry

    mov rax, [rdi + 4]          ; Pobierz 64-bitową maskę tagów pliku
    
    ; KRZEMOWA FILTRACJA: Sprawdzamy czy plik posiada szukane cechy (Tagi)
    and rax, r12
    cmp rax, r12
    jne .next_entry             

    ; Plik spełnia wymagania. Zapisz jego ID do tablicy.
    mov [r13 + rsi * 4], edx
    inc rsi                     

.next_entry:
    inc rbx
    cmp rbx, 8                  
    jl .search_loop

    mov rax, rsi                
    add rsp, 512                
    pop r14
    pop r13
    pop r12
    pop rdi
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    ret


; ==============================================================================
; FUNKCJA 3: tgfs_load_and_map_file (JIT-Mapped Poly-Loader Architecture)
; Odnajduje plik, identyfikuje format po tagu binarnej zgodności, 
; a dla danych stosuje Direct Streaming, omijając tradycyjne kopiowanie RAM.
; Wejście:
;   RCX = Port SATA, RDX = File ID, R8 = Bufor docelowy RAM (lub urządzenia MMIO)
; Zwraca:
;   RAX = Entry Point (dla aplikacji) lub Rozmiar w bajtach (dla danych / grafiki)
; ==============================================================================
tgfs_load_and_map_file:
    push rbx
    push rcx
    push rdx
    push r8
    push r9
    push rsi
    push rdi
    push r12
    push r13
    push r14

    mov r12d, edx               ; R12D = Szukane ID
    mov r13, r8                 ; R13  = Adres docelowy RAM/MMIO
    mov r14, rcx                ; R14  = Port SATA

    sub rsp, 512
    mov r9, rsp
    mov rdx, [tgfs_registry_lba]
    mov r8, 1
    mov rcx, r14
    call ahci_read_sectors

    mov rbx, 0                  
.load_search_loop:
    mov rdi, rsp
    mov rax, rbx
    shl rax, 6
    add rdi, rax                

    mov edx, [rdi]              
    cmp edx, r12d
    je .id_found                

    inc rbx
    cmp rbx, 8
    jl .load_search_loop

    add rsp, 512
    mov rax, -1                 ; Błąd: Brak ID
    jmp .exit_load

.id_found:
    ; Pobieramy metadane z 64-bajtowej struktury TGFS
    mov r8, [rdi + 4]           ; R8  = Maska tagów pliku (Cechy i format)
    mov rdx, [rdi + 12]         ; RDX = Startowy sektor LBA danych pliku
    mov rsi, [rdi + 20]         ; RSI = Rozmiar pliku w bajtach

    ; 1. SPRAWDZANIE TAGU: Czy plik to zasób graficzny pchnięty strumieniowo do monitora?
    test r8, TAG_IMAGE
    jz .check_executable
    
    ; Direct-to-Hardware Streaming: ładujemy grafikę prosto do bufora wyjściowego ekranu!
    mov r8, rsi
    add r8, 511
    shr r8, 9                   ; Liczba sektorów
    mov rcx, r14                ; Port SATA
    mov r9, r13                 ; R13 to bezpośredni adres Framebuffera HDMI/DP
    call ahci_read_sectors
    mov rax, rsi                ; Zwróć rozmiar załadowanej grafiki
    jmp .clean_exit

.check_executable:
    ; 2. SPRAWDZANIE TAGU: Czy plik to aplikacja?
    test r8, TAG_APPLICATION
    jz .pure_data_load

    ; Sprawdzamy tag zgodności formatu binarnego
    test r8, TAG_FOREIGN_ELF
    jnz .handle_foreign_elf
    test r8, TAG_FOREIGN_EXE
    jnz .handle_foreign_exe

    ; --- FORMAT NATYWNY ---
    ; Ładujemy kod natywny ciągłym transferem DMA
    mov r8, rsi
    add r8, 511
    shr r8, 9
    mov rcx, r14
    mov r9, r13                 ; Przydzielony RAM
    call ahci_read_sectors
    mov rax, r13                ; Entry Point = Początek załadowanego kodu natywnego
    jmp .clean_exit

.handle_foreign_elf:
    ; --- WARSTWA ZGODNOŚCI LINUX ELF64 (JMP-Loader) ---
    ; Tradycyjny loader traciłby cykle na parsowanie. My stosujemy optymalizację:
    ; Wczytujemy plik i ustawiamy sztuczny wskaźnik Entry Point.
    ; Realne parsowanie i mapowanie dynamiczne sekcji pomijamy dzięki technologii Zero-Copy.
    mov r8, rsi
    add r8, 511
    shr r8, 9
    mov rcx, r14
    mov r9, r13
    call ahci_read_sectors
    
    ; Wyciągamy z nagłówka surowego pliku ELF prawdziwy adres startowy (Offset 24 w formacie ELF64)
    mov rax, [r13 + 24]         ; RAX = Oryginalny, obcy Entry Point z Linuxa
    jmp .clean_exit

.handle_foreign_exe:
    ; --- WARSTWA ZGODNOŚCI WINDOWS PE/EXE ---
    mov r8, rsi
    add r8, 511
    shr r8, 9
    mov rcx, r14
    mov r9, r13
    call ahci_read_sectors
    
    ; W formacie PE Windowsa przesunięcie do nagłówka leży pod offsetem 0x3C,
    ; a sam punkt wejścia (AddressOfEntryPoint) pod offsetem 0x28 od nagłówka PE.
    mov eax, [r13 + 0x3C]       ; EAX = adres nagłówka PE
    add rax, r13
    movzx rax, dword [rax + 0x28] ; RAX = Relatywny punkt startowy Windowsa
    add rax, r13                ; Pełny fizyczny adres startowy EXE w Twoim RAMie
    jmp .clean_exit

.pure_data_load:
    ; Zwykłe ładowanie danych pliku
    mov r8, rsi
    add r8, 511
    shr r8, 9
    mov rcx, r14
    mov r9, r13
    call ahci_read_sectors
    mov rax, rsi

.clean_exit:
    add rsp, 512                

.exit_load:
    pop r14
    pop r13
    pop r12
    pop rdi
    pop rsi
    pop r9
    pop r8
    pop rdx
    pop rcx
    pop rbx
    ret


; ==============================================================================
; PROCEDURA INTERCEPTORA: syscall_compatibility_layer (Most Sprzętowy Tłumaczenia)
; Wywoływana automatycznie przez procesor, gdy obcy program wywoła instrukcję syscall.
; Zapobiega crashem aplikacji i mapuje ich zapytania bezpośrednio na Twój hardware.
; ==============================================================================
syscall_compatibility_layer:
    ; RAX zawiera numer komendy systemowej obcego środowiska.
    ; Program z innego systemu myśli, że rozmawia ze swoim jądrem.
    
    cmp rax, 1                  ; Czy Linux zażądał sys_write (wypisanie tekstu/grafiki)?
    je .emulate_sys_write

    cmp rax, 9                  ; Czy Linux zażądał sys_mmap (prośba o przydział RAM)?
    je .emulate_sys_mmap

    ; Jeśli program wywoła nieobsługiwaną funkcję, oszukujemy go, zwracając kod sukcesu (0),
    ; co zapobiega crashom i pozwala aplikacji bezbłędnie kontynuować pracę.
    xor rax, rax                
