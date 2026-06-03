# Mapa Pamięci i Układ ISO - OS Bootloader

## 📦 Struktura ISO 9660 (Dual Boot: BIOS + UEFI)

```
┌──────────────────────────────────────────────────────────────┐
│                    ISO 9660 File System                      │
├──────────────────────────────────────────────────────────────┤
│ Sektor 0-15      │ System Area (informacje o systemie)       │
├──────────────────────────────────────────────────────────────┤
│ Sektor 16        │ Primary Volume Descriptor (PVD)          │
├──────────────────────────────────────────────────────────────┤
│ Sektor 17-18     │ Reserved / Path Table                    │
├──────────────────────────────────────────────────────────────┤
│ Sektor 19        │ El Torito Boot Catalog                   │
├──────────────────────────────────────────────────────────────┤
│ Sektor 20-21     │ boot.bin (BIOS Bootloader)              │
├──────────────────────────────────────────────────────────────┤
│ Sektor 22-49     │ Reserved / Pliki systemowe               │
├──────────────────────────────────────────────────────────────┤
│ Sektor 50-74     │ uefiboot.bin (UEFI Bootloader)          │
├──────────────────────────────────────────────────────────────┤
│ Sektor 75+       │ Kernel + Dane                            │
└──────────────────────────────────────────────────────────────┘
```

## 🔢 Tabela Sektorów ISO

| Sektor | Bajty (Hex) | Rozmiar | Zawartość | Opis |
|--------|-------------|---------|-----------|------|
| **0-15** | 0x0000-0x7FFF | 32 KB | System Area | Informacje bootowania |
| **16** | 0x8000-0x87FF | 2 KB | **PVD** | Primary Volume Descriptor |
| **17-18** | 0x8800-0x8FFF | 4 KB | Reserved | Miejsce na metadane |
| **19** | 0x9000-0x97FF | 2 KB | **El Torito** | Boot Catalog dla BIOS |
| **20-21** | 0x9800-0x9FFF | 4 KB | **boot.bin** | BIOS Bootloader (512 B) |
| **22-49** | 0xA000-0x187FF | 180 KB | Reserved | Przyszłe dane |
| **50-74** | 0x18800-0x25FFF | 100 KB | **uefiboot.bin** | UEFI Bootloader |
| **75+** | 0x26000+ | ∞ | **Kernel** | Kernel i pliki OS |

## 💾 Mapa Pamięci RAM - Tryb BIOS (Legacy Boot)

### Faza 1: Bootloader BIOS (16-bit Real Mode)

```
Adres (Hex)    Zawartość                        Rozmiar
──────────────────────────────────────────────────────────
0x00000-0x003FF  Tablica przerwań (IVT)          1 KB
0x00400-0x004FF  BIOS Data Area                  256 B
0x00500-0x07BFF  Dostępna pamięć                 30 KB
0x07C00-0x07DFF  boot.bin w pamięci (512 B)     512 B ⭐
0x07E00-0x8FFFF  Dostępna pamięć                36 KB
0x90000-0x9FFFF  Stack dla bootloadera          60 KB
0xA0000-0xFFFFF  Video Memory + ROM              384 KB
```

**Sekwencja:**
1. BIOS ładuje boot.bin na **0x7C00**
2. Boot.asm przejmuje kontrolę
3. Boot.asm ustawia stack na **0x90000**
4. Boot.asm przechodzi do 32-bit, następnie 64-bit

## 🎯 Mapa Pamięci RAM - Tryb 64-bit (Po Bootloaderze)

### Faza 2: Po włączeniu paging i Long Mode

```
Adres Wirtualny      Adres Fizyczny    Rozmiar    Zawartość
────────────────────────────────────────────────────────────
0x0000000000000000   0x00000000        1 MB       Bootloader + IVT
├─────────────────────────────────────────────┤
0x0000000000100000   0x00100000        ∞          ⭐ KERNEL BASE
├─────────────────────────────────────────────┤
0x0000000000200000   0x00200000        256 KB     Code (.text)
├─────────────────────────────────────────────┤
0x0000000000240000   0x00240000        64 KB      Data (.data)
├─────────────────────────────────────────────┤
0x0000000000250000   0x00250000        64 KB      BSS (.bss)
├─────────────────────────────────────────────┤
0x0000000000260000   0x00260000        ∞          Heap (dynamiczna)
├─────────────────────────────────────────────┤
0x0000000090000000   0x90000000        512 KB     Stack (kernel stack)
└─────────────────────────────────────────────┘
```

## ⭐ REKOMENDOWANA KONFIGURACJA KERNELA

### Opcja 1: Tradycyjny Layout (ZALECANE)

```
Kernel Base: 0x00100000 (1 MB)
Stack: 0x90000 (ustawiany przez boot.asm)
Heap: od 0x00260000
```

**Zalety:**
- ✅ Zgodny z boot.asm (wskazuje RSP na 0x90000)
- ✅ Standard dla x86-64 kerneli
- ✅ 1 MB marginesu dla bootloadera
- ✅ Łatwe debugowanie

**Boot Sequence:**

```asm
; boot.asm (ostatnia linia):
long_mode:
    mov rsp, 0x90000
    ; ... setup ...
    
    ; Ładowanie kernela z dysku na 0x00100000
    mov rax, 0x00100000      ; Adres kernela
    jmp rax                  ; START KERNELA!

; kernel.asm (entry point):
[bits 64]
[org 0x00100000]

global _start
_start:
    ; RSP już ustawiony na 0x90000 (przez boot.asm)
    ; Kernel przejmuje całą kontrolę
    mov rax, 0x0
    ; ... kernel code ...
```

### Opcja 2: Higher-Half Kernel (Zaawansowany)

```
Kernel Virtual: 0xFFFFFFFF80100000
Kernel Physical: 0x00100000
(Identity mapping + higher-half)
```

**Zalety:**
- ✅ Typowy dla nowoczesnych kerneli (Linux)
- ⚠️ Wymaga bardziej zaawansowanego paging
- ⚠️ Przydatny później w projekcie

## 🔗 Boot Sequence - Krok po Kroku

```
1. BIOS sprawdza El Torito Boot Catalog (sektor 19)
   ↓
2. BIOS ładuje boot.bin (sektor 20) na 0x7C00
   ↓
3. boot.asm inicjalizuje system:
   ✓ Włącza A20 (dostęp do pełnej pamięci)
   ✓ Ładuje GDT
   ✓ Włącza 32-bit Protected Mode
   ✓ Włącza paging
   ✓ Włącza 64-bit Long Mode
   ↓
4. boot.asm ustawia rejestry:
   ✓ RSP = 0x90000 (stack)
   ✓ CR3 = pml4_table (paging)
   ✓ Segmenty danych i kodu
   ↓
5. boot.asm ładuje kernel z dysku na 0x00100000
   ↓
6. boot.asm skacze: jmp 0x00100000
   ↓
7. Kernel przejmuje kontrolę nad systemem
```

## 📊 Układ El Torito Boot Catalog (Sektor 19)

```
Offset  Rozmiar  Zawartość           Wartość
─────────────────────────────────────────────────
0x00    1 B      Typ                 0x01 (Validation Header)
0x01    1 B      Platforma           0x00 (x86)
0x02    2 B      Liczba wpisów       0x0001
0x04    4 B      Manufacturer ID     "LISA"
0x08    20 B     Reserved            0x00

0x20    1 B      Typ                 0x88 (Boot Entry)
0x21    1 B      Media Type          0x00 (1.44 MB floppy emul.)
0x22    2 B      Load Segment        0x07C0 (ładuje na 0x7C00)
0x24    1 B      System Type         0x00
0x25    1 B      Reserved            0x00
0x26    2 B      Liczba sektorów     0x0004 (4 sektory = 8 KB)
0x28    4 B      Sektor boot.bin     20 (ISO_BOOT_IMAGE_SECTOR)
0x2C    4 B      Reserved            0x00000000
```

## 🔧 Kompilacja i Budowanie

```bash
# Assemblowanie boot.asm (BIOS bootloader)
nasm boot.asm -f bin -o boot.bin

# Assemblowanie uefiboot.asm (UEFI bootloader)
nasm uefiboot.asm -f bin -o uefiboot.bin

# Assemblowanie iso_builder.asm (builder ISO)
nasm iso_builder.asm -f bin -o iso_builder.bin

# Tworzenie ISO (będzie obsługiwane przez iso_builder.asm)
# lub używając mkisofs/xorriso
mkisofs -R -b boot.bin -c boot.cat -o os.iso /ścieżka/do/plików
```

## 📝 Podsumowanie Pamięci

| Adres | Rozmiar | Przeznaczenie | Notatka |
|-------|---------|---------------|---------|
| 0x00000 | 1 KB | IVT + BIOS Data | Zarządzane przez BIOS |
| 0x07C00 | 512 B | boot.bin | Bootloader w pamięci |
| 0x90000 | 60 KB | Stack | Zarządzany przez boot.asm |
| **0x100000** | **∞** | **Kernel** | **⭐ START KERNELA** |
| 0x200000 | 256 KB | Kod kernela | .text segment |
| 0x240000 | 64 KB | Dane kernela | .data segment |
| 0x250000 | 64 KB | BSS | Niezainicjalizowane dane |
| 0x260000 | ∞ | Heap | Dynamiczna alokacja |

---

**Wersja**: 1.0  
**Data**: 2026-06-03  
**Język**: Polski  
**Projekt**: Custom OS Bootloader
