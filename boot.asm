[bits 16]
[org 0x7C00] ; pierwszy adress zapisu kodu czytany przez BIOS


start:
cli ;wyczyść interupty oraz wyłącz je
mov ax, 0x00 
mov ds, ax
mov ss, ax
mov sp, 0x7C00
sti ;włącza interupty
lgdt [gdt_descryptor] ;ładuje gdt do rejestru gdtr
mov si, msg

print: 
lodsb ;ładuje bit si:ds oraz używa si
cmp al, 0 
je done
mov ah, 0x0E
int 0x10
jmp print

done: 
cli
hlt ;stop

msg: 
db 'hello world boot',0

gdt_start:       
;Global descyptor table
 dq 0x00000000 ;null deskryptor
 
; code segment deskryptor
gdt_code:
 dw 0xFFFF    ;limit
 dw 0x0000    ;baza lo
 db 0x00      ;baza mid
 db 0x9A      ;Acces byte
 db 0xCF      ;flagi  
 db 0x00      ; baza hi
 ; data segment deskryptor
gdt_data:
 dw 0xFFFF    ;limit
 dw 0x00      ;baza
 db 0x00      ;baza mid
 db 0x92      ;Acces byte
 db 0xCF      ;flagi
 db 0x00      ; baza hi

gdt_end:

gdt_descryptor:
dw gdt_end - gdt_start - 1 ;wielkość gdt -1
dd gdt_start


times 510 - ($-$$) db 0
dw 0xAA55