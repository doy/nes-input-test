.MEMORYMAP
SLOTSIZE     $2000
DEFAULTSLOT  0
SLOT 0       $C000
SLOT 1       $E000
.ENDME

.ROMBANKMAP
BANKSTOTAL  2
BANKSIZE    $2000
BANKS       2
.ENDRO


  .bank 0
  .org $0000
RESET:
  SEI          ; disable IRQs
  CLD          ; disable decimal mode
  LDX #$40
  STX $4017.W    ; disable APU frame IRQ
  LDX #$FF
  TXS          ; Set up stack
  INX          ; now X = 0
  STX $2000.W    ; disable NMI
  STX $2001.W    ; disable rendering
  STX $4010.W    ; disable DMC IRQs

vblankwait1:       ; First wait for vblank to make sure PPU is ready
  BIT $2002
  BPL vblankwait1

clrmem:
  LDA #$00
  STA $0000, x
  STA $0100, x
  STA $0200, x
  STA $0400, x
  STA $0500, x
  STA $0600, x
  STA $0700, x
  LDA #$FE
  STA $0300, x
  INX
  BNE clrmem

vblankwait2:      ; Second wait for vblank, PPU is ready after this
  BIT $2002
  BPL vblankwait2

  LDA #%10000000   ;intensify blues
  STA $2001

Forever:
  JMP Forever     ;jump back to Forever, infinite loop

NMI:
  RTI


  .bank 1 slot 1
  .orga $FFFA    ;first of the three vectors starts here
  .dw NMI        ;when an NMI happens (once per frame if enabled) the 
                   ;processor will jump to the label NMI:
  .dw RESET      ;when the processor first turns on or is reset, it will jump
                   ;to the label RESET:
  .dw 0          ;external interrupt IRQ is not used in this tutorial
