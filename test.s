.MEMORYMAP
SLOTSIZE     $2000
DEFAULTSLOT  0
SLOT 0       $8000
SLOT 1       $E000
SLOT 2       $0000
.ENDME

.ROMBANKMAP
BANKSTOTAL  3
BANKSIZE    $2000
BANKS       3
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

loop:
  ; read the controller state
  JSR read_controller1

  ; if A is not pressed, return
  LDA buttons_pressed.w
  AND #%10000000
  CMP #$00
  BEQ loop

  LDY current_state.w
  CPY #$00
  BEQ turn_green
  CPY #$01
  BEQ turn_red

turn_blue:
  LDA #%10000000
  STA $2001
  LDA #$00
  STA current_state.w
  JMP color_set
turn_green:
  LDA #%01000000
  STA $2001
  LDA #$01
  STA current_state.w
  JMP color_set
turn_red:
  LDA #%00100000
  STA $2001
  LDA #$02
  STA current_state.w
  JMP color_set

color_set:
  JMP loop

read_controller1:
  ; latch
  LDA #$01
  STA $4016
  LDA #$00
  STA $4016

  ; clock
  LDX #$00
read_controller1_values:
  CPX #$08
  BPL end_read_controller1

  LDA $4016
  AND #%00000001
  ASL buttons_pressed.w
  ORA buttons_pressed.w
  STA buttons_pressed.w
  INX
  JMP read_controller1_values

end_read_controller1:
  RTS


NMI:
  RTI


  .bank 1 slot 1
  .orga $FFFA    ;first of the three vectors starts here
  .dw NMI        ;when an NMI happens (once per frame if enabled) the 
                   ;processor will jump to the label NMI:
  .dw RESET      ;when the processor first turns on or is reset, it will jump
                   ;to the label RESET:
  .dw 0          ;external interrupt IRQ is not used in this tutorial


  .bank 2 slot 2
  .org $0000
buttons_pressed: .ds 1, $00
current_state:   .ds 1, $00
