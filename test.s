.MEMORYMAP
SLOTSIZE     $2000
DEFAULTSLOT  0
SLOT 0       $8000
SLOT 1       $E000
SLOT 2       $6000
SLOT 3       $0000
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
  STA $0300, x
  STA $0400, x
  STA $0500, x
  STA $0600, x
  STA $0700, x
  LDA #$FE
  STA $0200, x    ;move all sprites off screen
  INX
  BNE clrmem

vblankwait2:      ; Second wait for vblank, PPU is ready after this
  BIT $2002
  BPL vblankwait2

LoadPalettes:
  LDA $2002    ; read PPU status to reset the high/low latch
  LDA #$3F
  STA $2006    ; write the high byte of $3F00 address
  LDA #$00
  STA $2006    ; write the low byte of $3F00 address
  LDX #$00
LoadPalettesLoop:
  LDA palette.w, x        ;load palette byte
  STA $2007             ;write to PPU
  INX                   ;set index to next byte
  CPX #$20            
  BNE LoadPalettesLoop  ;if x = $20, 32 bytes copied, all done

  LDA #%10010000   ;intensify blues and enable sprites
  STA $2001

  LDA #%10000000   ; enable NMI interrupts
  STA $2000

loop:
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

turn_blue:
  LDA #%10010000
  STA $2001
  LDA #$00
  STA current_state.w
  RTS

turn_green:
  LDA #%01010000
  STA $2001
  LDA #$01
  STA current_state.w
  RTS

turn_red:
  LDA #%00110000
  STA $2001
  LDA #$02
  STA current_state.w
  RTS

NMI:
  JSR read_controller1

  LDA #$00
  STA $2003
  LDA #$02
  STA $4014

  LDA #$80
  STA $0200
  STA $0203
  LDA #$00
  STA $0201
  LDA #$00
  STA $0202

  ; if A is not pressed, return
  LDA buttons_pressed.w
  AND #%10000000
  CMP #$00
  BEQ loop

  LDY current_state.w
  CPY #$00
  BEQ call_turn_green
  CPY #$01
  BEQ call_turn_red

call_turn_blue:
  JSR turn_blue
  JMP color_set
call_turn_green:
  JSR turn_green
  JMP color_set
call_turn_red:
  JSR turn_red
  JMP color_set

color_set:
  RTI


  .bank 1 slot 1
  .orga $E000
palette:
  .db $0F,$31,$32,$33,$0F,$35,$36,$37,$0F,$39,$3A,$3B,$0F,$3D,$3E,$0F
  .db $0F,$1C,$15,$14,$0F,$02,$38,$3C,$0F,$1C,$15,$14,$0F,$02,$38,$3C

  .orga $FFFA    ;first of the three vectors starts here
  .dw NMI        ;when an NMI happens (once per frame if enabled) the 
                   ;processor will jump to the label NMI:
  .dw RESET      ;when the processor first turns on or is reset, it will jump
                   ;to the label RESET:
  .dw 0          ;external interrupt IRQ is not used in this tutorial


  .bank 1 slot 2
  .org $0000
buttons_pressed: .ds 1, $00
current_state:   .ds 1, $00


  .bank 2 slot 3
  .org $0000
  .incbin "mario.chr"
