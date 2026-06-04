[bits 64]
[org 0x00100000]

global start

start: 
cli

mov rax, 0x0

halt:
hlt
jmp halt