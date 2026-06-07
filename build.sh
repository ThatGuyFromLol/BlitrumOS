#!/bin/bash
# ==============================================================================
#      ZAUTOMATYZOWANY SKRYPT KOMPILACJI I LINKOWANIA EKOSYSTEMU OS v1.1
# ==============================================================================
echo "===================================================================="
echo "    URUCHAMIANIE PROCESU BUDOWANIA: NOWATORSKI WEKTOROWY OS"
echo "===================================================================="

# 1. Kompilacja jądra i wszystkich modularnych podsystemów przez NASM
# Flaga elf64 generuje nowoczesne pliki obiektowe 64-bitowe.
nasm -f elf64 kernel.asm -o kernel.o
nasm -f elf64 idt.asm -o idt.o
nasm -f elf64 pmm.asm -o pmm.o
nasm -f elf64 gui_vector_core.asm -o gui_vector_core.o
nasm -f elf64 ahci_disk.asm -o ahci_disk.o
nasm -f elf64 usb3.asm -o usb3.o
nasm -f elf64 usb_interrupts.asm -o usb_interrupts.o
nasm -f elf64 audio_hda.asm -o audio_hda.o
nasm -f elf64 scheduler_custom.asm -o scheduler_custom.o
nasm -f elf64 tgfs_vfs.asm -o tgfs_vfs.o
nasm -f elf64 smp_legacy.asm -o smp_legacy.o
nasm -f elf64 elf_loader.asm -o elf_loader.o
nasm -f elf64 sys_update.asm -o sys_update.o

echo "-> Wszystkie moduły niskopoziomowe skompilowane pomyślnie do plików .o"

# 2. Konsolidacja binarna i budowanie ostatecznego pliku jądra przy użyciu linker.ld
# Łączymy wszystkie sterowniki, w tym nowo dodane przerwania USB, w jeden plik.
ld -T linker.ld kernel.o idt.o pmm.o gui_vector_core.o ahci_disk.o usb3.o usb_interrupts.o audio_hda.o scheduler_custom.o tgfs_vfs.o smp_legacy.o elf_loader.o sys_update.o -o kernel.bin [INDEX]

echo "--------------------------------------------------------------------"
echo "  [SUKCES] Wygenerowano spójny, czysty plik jądra systemu: kernel.bin"
echo "===================================================================="
echo "Instrukcja: Umieść plik kernel.bin na partycji ESP obok bootloadera."
