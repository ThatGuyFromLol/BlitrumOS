# 🖥️ Nowatorski Wektorowy OS

> Eksperymentalny system operacyjny x86-64 pisany w czystym NASM Assembly.  
> Projekt hobbystyczny z ambicjami startup — modularny, wektorowy, z hot-swappingiem sterowników w locie.

---

## ✨ Co to jest?

Własny system operacyjny napisany od zera w asemblerze NASM dla architektury x86-64.  
Projekt implementuje kompletny stos — od bootloadera UEFI po silnik GUI z HDR 64-bit ARGB.

**Kluczowe innowacje:**
- 🔄 **AHS-TUS** — sterowniki wymieniane w locie bez restartu (Atomic Hot-Swapping Tagged Update System)
- 🗂️ **TGFS** — własny system plików oparty o tagi z emulacją syscalli Linuxa (ELF64 / PE)
- 🎨 **HDR GUI Engine** — 64-bit ARGB backbuffer z AVX-2 blitterem na HDMI/DisplayPort
- ⚡ **BME-QD Scheduler** — Bit-Matrix Event-Driven Quantum Dispatcher dla wielozadaniowości
- 🌐 **Multicore** — bootstrapping rdzeni AP przez Local APIC SIPI

---

## 🏗️ Architektura
Copy
┌─────────────────────────────────────────────────────┐ │ UEFI GOP Bootloader │ │ (ExitBootServices + mapa pamięci) │ └──────────────────────┬──────────────────────────────┘ │ jmp 0x00100000 ┌──────────────────────▼──────────────────────────────┐ │ Kernel (Kernel.asm) │ │ PMM → IDT → GUI → AHCI → USB → Audio → Scheduler │ └──────────┬──────────────────────────┬───────────────┘ │ │ ┌────────▼────────┐ ┌──────────▼────────────┐ │ AHS-TUS │ │ TGFS + VFS │ │ (wektor tabela)│ │ (Tag File System) │ └────────┬────────┘ └──────────┬─────────────┘ │ │ ┌────────▼──────────────────────────▼─────────────┐ │ HDR GUI Engine │ │ gui_hdr.asm (skalar) / simd_argb-64 (AVX-2) │ │ gui_men.asm (widgety) │ └──────────────────────────────────────────────────┘

---

## 📁 Struktura katalogów
Copy
os/ ├── Bootloders/ │ ├── uefi_boot.asm # Bootloader UEFI GOP (HDMI/DisplayPort) │ └── Legacy_boot.asm # Bootloader Legacy BIOS (Real Mode → Long Mode) │ ├── Kernel/ │ └── Kernel.asm # Główny punkt wejścia OS │ ├── Tools/ │ ├── ppm.asm # PMM — Physical Memory Manager (bitmapa stron 4KB) │ ├── idt.asm # IDT — Interrupt Descriptor Table (32 wyjątki + USB) │ ├── ahci.asm # AHCI — sterownik dysków SATA z DMA read │ ├── usb_controller.asm # xHCI — USB 3.0 controller + BIOS handshake │ ├── usb_interrupts.asm # Ring buffer dla zdarzeń myszy/klawiatury (USB) │ ├── audio_hca.asm # Intel HD Audio — wykrywanie i inicjalizacja │ ├── gui_hdr.asm # HDR GUI Engine — 64-bit ARGB, skalarny │ ├── simd_argb-64.asm # HDR GUI Engine — wersja AVX-2 (alternatywna) │ ├── gui_men.asm # Widget manager — okna, przyciski, tekst │ ├── custom_sceduler.asm # BME-QD Scheduler — wielozadaniowość │ ├── ahs-tus.asm # Hot-swap wektorów sterowników w locie │ ├── tgfs_vfs.asm # TGFS + VFS + Linux syscall emulation layer │ ├── multicore_legacy.asm # SMP — bootstrapping rdzeni AP przez SIPI │ └── pci_(dyski).asm # Wspólna implementacja pci_read_config_dword │ ├── Soureses/ # Dokumentacja i specyfikacje projektu │ ├── MEMORY_LAYOUT.md │ ├── rodemap.md │ └── ... │ ├── build.sh # Skrypt kompilacji (NASM + ld) └── linker.ld # Skrypt linkera GNU ld (binary, baza 0x100000)

---

## 🚀 Budowanie

### Wymagania

```bash
# Ubuntu / Debian
sudo apt install nasm binutils

# Arch Linux
sudo pacman -S nasm binutils
Copy
Kompilacja
bash build.sh
Copy
Wynik: plik kernel.bin gotowy do wgrania na partycję ESP obok bootloadera.

Testowanie w QEMU
qemu-system-x86_64 \
  -bios /usr/share/ovmf/OVMF.fd \
  -drive format=raw,file=kernel.bin \
  -m 512M \
  -serial stdio
Copy
🧠 Mapa pamięci RAM
Adres fizyczny	Rozmiar	Przeznaczenie
0x00000000	1 MB	IVT, BIOS, bootloader
0x00100000	~256 KB	Kernel (punkt wejścia)
0x00200000	128 KB	Bitmapa PMM
0x00400000	16 KB	Bufory DMA AHCI
0x00800000	8 MB	Obszar ładowania TGFS
0x01000000	~16 MB	HDR Backbuffer (64-bit ARGB)
0x02000000+	wolne	Strony zarządzane przez PMM
⚙️ Moduły systemowe
🔄 AHS-TUS — Atomic Hot-Swapping Tagged Update System
Tabela 64 wektorów w RAM. Każdy sterownik rejestruje się przez update_register_vector(id, fn_ptr). Wymiana sterownika w locie = jeden zapis do tablicy. Brak restartu.

🗂️ TGFS — Tag Graphic File System
Własny system plików oparty o bitmaskowe identyfikatory plików zamiast nazw. Obsługuje natywne binaria, ELF64 (Linux) i PE (Windows). Warstwa syscall_compatibility_layer emuluje sys_write, sys_mmap i inne.

🎨 HDR GUI Engine
Dwie ścieżki renderowania:

gui_hdr.asm — 64-bit ARGB, jedna instrukcja = jeden piksel, domyślna
simd_argb-64.asm — AVX-2, 8 pikseli na raz, wymaga OSXSAVE + XCR0
Konwersja 64→32 bit w gui_refresh_screen działa w locie podczas blittingu na HDMI/DP.

⚡ BME-QD Scheduler
64-bitowa maska zdarzeń. scheduler_trigger_event(task_id) budzi wątek przez ustawienie bitu. Zero narzutu dla uśpionych wątków — CPU stoi na hlt.

🌐 Multicore (SMP)
Trampolina kopiowana pod 0x8000. BSP wysyła INIT + 2× SIPI przez Local APIC. Każdy rdzeń AP dostaje własny 4KB stos i ląduje w ap_kernel_main.

🐛 Stan naprawczych bugfixów (v0.1 → v0.2)
Plik	Naprawione błędy
linker.ld	Był skryptem bash — teraz poprawny GNU ld
Kernel.asm	Odczyt framebuffera PRZED przełączeniem stosu
uefi_boot.asm	UTF-16 string syntax, ExitBootServices
Legacy_boot.asm	Zbędny cli, błędny komentarz
ahci.asm	global ahci_read_sectors, extern pci_read_config_dword
usb_controller.asm	Usunięcie duplikatu pci_read_config_dword
multicore_legacy.asm	: MULTICORE syntax, duplikat _start
gui_hdr.asm	Błąd ekstrakcji kanału zielonego (bh zamiast bl)
gui_men.asm	Trzy kopie kodu scalone w jedną, conflict z gui_draw_window
tgfs_vfs.asm	Brakujący ret w syscall fallback
idt.asm	Tylko 3 wektory → teraz wszystkie 32 wyjątki + USB 0x28
ppm.asm	Argumenty PMM zapisywane przed rep stosq
build.sh	Literówka Bootlodery/, linker.dl, brak set -e
🗺️ Roadmapa
 UEFI GOP bootloader
 Long Mode (64-bit)
 PMM — Physical Memory Manager
 IDT — obsługa wyjątków
 AHCI — odczyt dysków SATA
 USB 3.0 xHCI + przerwania
 Intel HD Audio
 HDR 64-bit GUI Engine
 Widget Manager
 BME-QD Scheduler
 AHS-TUS Hot-Swap
 TGFS File System
 SMP Multicore boot
 Pełna emulacja syscalli Linux (write, mmap, read, open)
 Integracja schedulera z rdzeniami AP
 Shell tekstowy
 Sieć (Ethernet / PCIe NIC)
 Format paczek aplikacji
📄 Licencja
Projekt hobbystyczny — kod publiczny, używaj i ucz się swobodnie.
Jeśli coś zbudujesz na bazie tego projektu — daj znać! 🚀

Projekt rozwijany solo, od zera, w czystym NASM. Każda linia kodu pisana ręcznie.