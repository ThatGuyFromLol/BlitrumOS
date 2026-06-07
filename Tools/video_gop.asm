bits 64
section .text

; --- DEKLARACJE GLOBALNE (Widoczne dla kernela) ---
global video_init
global video_clear_screen
global video_put_pixel
global video_draw_rect

section .data
; Zmienne przechowujące parametry ekranu odebrane z UEFI GOP
fb_address:    dq 0         ; 64-bitowy fizyczny adres bufora pamięci wideo
fb_width:      dd 0         ; Szerokość ekranu w pikselach (np. 1920)
fb_height:     dd 0         ; Wysokość ekranu w pikselach (np. 1080)
fb_pps:        dd 0         ; Pixels Per Scan Line (Fizyczna szerokość linii w pamięci)

section .text

; ==============================================================================
; FUNKCJA: video_init
; Rejestruje dane bufora ramki graficznej przekazane z bootloadera UEFI.
; Argumenty wejściowe (zgodnie z Microsoft x64 ABI):
;   RCX = Fizyczny adres Framebuffera (64-bit)
;   RDX = Szerokość ekranu (Width, 32-bit)
;   R8D = Wysokość ekranu (Height, 32-bit)
;   R9D = Pixels Per Scan Line (32-bit)
; ==============================================================================
video_init:
    push rax
    
    mov [fb_address], rcx
    mov [fb_width], edx
    mov [fb_height], r8d
    mov [fb_pps], r9d
    
    pop rax
    ret


; ==============================================================================
; FUNKCJA: video_clear_screen
; Czyszcząca cały ekran (wypełnia wybranym kolorem).
; Argument wejściowy:
;   ECX = Kolor w formacie 32-bit (0x00RRGGBB)
; ==============================================================================
video_clear_screen:
    push rax
    push rcx
    push rdi
    push r8
    push rdx

    mov rdi, [fb_address]    ; Pobierz adres pamięci ekranu
    test rdi, rdi            ; Sprawdź czy bufor został zainicjalizowany
    jz .exit

    ; Obliczamy łączną liczbę pikseli: Height * PixelsPerScanLine
    mov eax, [fb_height]
    mov edx, [fb_pps]
    mul edx                  ; RAX = EAX * EDX
    mov r8, rax              ; R8 = Liczba pikseli do zamalowania

    mov eax, ecx             ; Przenieś kolor do EAX
    mov rcx, r8              ; Licznik dla instrukcji rep
    
    ; rep stosd masowo zapisuje 4-bajtowe dwordy z EAX pod adres RDI
    rep stosd

.exit:
    pop rdx
    pop r8
    pop rdi
    pop rcx
    pop rax
    ret


; ==============================================================================
; FUNKCJA: video_put_pixel
; Rysuje pojedynczy piksel na współrzędnych X, Y.
; Argumenty wejściowe:
;   ECX = Współrzędna X (Kolumna)
;   EDX = Współrzędna Y (Wiersz)
;   R8D = Kolor piksela (0x00RRGGBB)
; ==============================================================================
video_put_pixel:
    push rax
    push rbx
    push rdx
    push rdi

    ; Zabezpieczenie przed wyjściem poza ekran
    cmp ecx, [fb_width]
    jae .out_of_bounds
    cmp edx, [fb_height]
    jae .out_of_bounds

    ; Oblicz adres piksela: Adres = Baza + (Y * PixelsPerScanLine + X) * 4
    mov eax, edx             ; EAX = Y
    mov ebx, [fb_pps]        ; EBX = PixelsPerScanLine
    mul ebx                  ; EAX = Y * PixelsPerScanLine
    add eax, ecx             ; EAX = (Y * PixelsPerScanLine) + X
    shl rax, 2               ; Mnożenie przez 4 (piksel = 4 bajty)

    mov rdi, [fb_address]    
    add rdi, rax             ; RDI = Dokładny adres piksela w pamięci

    ; Zapisz kolor do pamięci wideo
    mov [rdi], r8d

.out_of_bounds:
    pop rdi
    pop rdx
    pop rbx
    pop rax
    ret


; ==============================================================================
; FUNKCJA: video_draw_rect
; Rysuje wypełniony prostokąt. Przydatne do testowania obrazu na HDMI/DisplayPort.
; Argumenty wejściowe:
;   ECX = Start X
;   EDX = Start Y
;   R8D = Szerokość prostokąta (Width)
;   R9D = Wysokość prostokąta (Height)
;   Na stosie (Stack): Kolor (0x00RRGGBB) przekazany jako 5. parametr (będzie pod [rsp + 40])
; ==============================================================================
video_draw_rect:
    push rax
    push rbx
    push rcx
    push rdx
    push rsi
    push rdi
    push r12
    push r13
    push r14

    ; Pobieramy 5. parametr ze stosu (kolor) zgodnie z ABI
    mov r14d, [rsp + 80]     ; 80 to przesunięcie po uwzględnieniu instrukcji push

    mov r12d, ecx            ; R12D = Aktualny X
    mov r13d, edx            ; R13D = Aktualny Y
    
    add r8d, ecx             ; R8D = Koniec X (Start X + Szerokość)
    add r9d, edx             ; R9D = Koniec Y (Start Y + Wysokość)

.y_loop:
    cmp r13d, r9d            ; Czy narysowaliśmy wszystkie linie pionowe?
    jae .done
    
    mov r12d, ecx            ; Resetuj X do pozycji startowej dla nowej linii

.x_loop:
    cmp r12d, r8d            ; Czy narysowaliśmy całą linię poziomą?
    jae .next_y

    ; Rysuj piksel na pozycji (R12D, R13D) z kolorem R14D
    push rcx
    push rdx
    push r8
    push r9
    
    mov ecx, r12d
    mov edx, r13d
    mov r8d, r14d
    call video_put_pixel
    
    pop r9
    pop r8
    pop rdx
    pop rcx

    inc r12d                 ; Następny X
    jmp .x_loop

.next_y:
    inc r13d                 ; Następny Y
    jmp .y_loop

.done:
    pop r14
    pop r13
    pop r12
    pop rdi
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    pop rax
    ret
