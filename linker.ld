#!/bin/bash
# ==============================================================================
#   ZAUTOMATYZOWANY SKRYPT KOMPILACJI DLA TWOJEJ STRUKTURY FOLDERÓW
# ==============================================================================
echo "===================================================================="
echo "    URUCHAMIANIE PROCESU BUDOWANIA: NOWATORSKI WEKTOROWY OS"
echo "===================================================================="

# --- KROK 1: KOMPILACJA SEKCJI BOOTLOADERÓW ---
echo "-> Kompilacja plików rozruchowych..."
nasm -f bin Bootlodery/Legacy_boot.asm -o legacy_boot.bin
nasm -f elf64 Bootlodery/uefi_boot.asm -o uefi_boot.o

# --- KROK 2: KOMPILACJA GŁÓWNEGO JĄDRA ---
echo "-> Kompilacja serca systemu..."
nasm -f elf64 Kernel/kernel.asm -o kernel.o

# --- KROK 3: KOMPILACJA PLIKÓW Z FOLDERU TOOLS (Dwa zrzuty ekranu) ---
echo "-> Kompilacja modułów i sterowników z folderu Tools..."
nasm -f elf64 Tools/idt.asm -o idt.o
nasm -f elf64 Tools/ppm.asm -o pmm.o

# Logika graficzna i wektorowa
nasm -f elf64 Tools/gui_hdr.asm -o gui_hdr.o
nasm -f elf64 Tools/gui_men.asm -o gui_men.o
nasm -f elf64 Tools/video_gop.asm -o video_gop.o
nasm -f elf64 Tools/simd_argb-64.asm -o simd_argb-64.o

# Moduły sprzętowe i obsługa magistrali
nasm -f elf64 Tools/usb_interrupts.asm -o usb_interrupts.o
nasm -f elf64 Tools/multicore_legacy.asm -o multicore_legacy.o
nasm -f elf64 Tools/ahci.asm -o ahci.o
nasm -f elf64 Tools/audio_hca.asm -o audio_hca.o
nasm -f elf64 Tools/"pci_(dyski).asm" -o pci_dyski.o

# PAMIĘTAJ: Zmień w Tools nazwę z "USB controller.asm" na "usb_controller.asm"
nasm -f elf64 Tools/usb_controller.asm -o usb_controller.o

# Innowacyjne warstwy logiczne (Scheduler, aktualizacje w locie i system plików)
nasm -f elf64 Tools/custom_sceduler.asm -o custom_sceduler.o
nasm -f elf64 Tools/ahs-tus.asm -o ahs-tus.o
nasm -f elf64 Tools/tgfs_vfs.asm -o tgfs_vfs.o

# Jeśli plik od loadera (elf_loader.asm) leży w Tools, odkomentuj linię poniżej:
# nasm -f elf64 Tools/elf_loader.asm -o elf_loader.o

echo "-> Wszystkie moduły ze wszystkich folderów skompilowane pomyślnie."

# --- KROK 4: KONSOLIDACJA (LINKOWANIE) SYSTEMU ---
# Używamy dokładnej nazwy Twojego pliku konfiguracyjnego linkera: linker.dl
echo "-> Linkowanie i generowanie obrazu jądra..."
ld -T linker.dl kernel.o idt.o pmm.o gui_hdr.o gui_men.o video_gop.o simd_argb-64.o usb_interrupts.o multicore_legacy.o ahci.o audio_hca.o pci_dyski.o usb_controller.o custom_sceduler.o ahs-tus.o tgfs_vfs.o -o kernel.bin

echo "--------------------------------------------------------------------"
echo "  [SUKCES] Cały system operacyjny został zbudowany do: kernel.bin"
echo "===================================================================="
