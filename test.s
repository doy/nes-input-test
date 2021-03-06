.MEMORYMAP
DEFAULTSLOT  0
SLOTSIZE     $4000
SLOT 0       $C000
SLOTSIZE     $2000
SLOT 1       $0000 ; location doesn't matter, CHR data isn't in main memory
.ENDME

.ROMBANKMAP
BANKSTOTAL  2
BANKSIZE    $4000
BANKS       1
BANKSIZE    $2000
BANKS       1
.ENDRO


  .enum $0000
buttons_pressed DB
current_state   DB
sprite_x        DB
sprite_y        DB
  .ende


  .bank 0
  .org $0000
; the ppu takes two frames to initialize, so we have some time to do whatever
; initialization of our own that we want to while we wait. we choose here to
; set up cpu flags in the first frame and clear out system ram in the second
; frame (clearing out ram isn't at all necessary, but we can't do anything
; useful at this point anyway, so we may as well in order to make things more
; predictable). clearing out system ram actually takes quite a bit longer than
; a frame (a frame is ~2273 cycles, or ~324-1136 opcodes), but we may as well
; start the process while we wait.
RESET:
  SEI              ; disable IRQs
  CLD              ; disable decimal mode
  LDX #$40
  STX $4017.w      ; disable APU frame IRQ
  LDX #$FF
  TXS              ; Set up stack (grows down from $FF to $00, at $0100-$01FF)
  INX              ; now X = 0
  STX $2000.w      ; disable NMI (we'll enable it later once the ppu is ready)
  STX $2001.w      ; disable rendering (same)
  STX $4010.w      ; disable DMC IRQs

vblankwait1:       ; First wait for vblank to make sure PPU is ready
  BIT $2002        ; bit 7 of $2002 is reset once vblank ends
  BPL vblankwait1  ; and bit 7 is what is checked by BPL

  ; set everything in ram ($0000-$07FF) to $00, except for $0200-$02FF which
  ; is conventionally used to hold sprite attribute data. we set that range
  ; to $FE, since that value as a position moves the sprites offscreen, and
  ; when the sprites are offscreen, it doesn't matter which sprites are
  ; selected or what their attributes are
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
  STA $0200, x
  INX
  BNE clrmem

  ; initialize variables in ram
  LDA #$00
  STA buttons_pressed
  STA current_state
  LDA #$80
  STA sprite_x
  STA sprite_y

  LDA #$32
  STA $0201 ; set the sprite number to display
  LDA #$00
  STA $0202 ; set the sprite attributes (palette, flipping, etc)

  LDA #$33
  STA $0205 ; set the sprite number to display
  LDA #$00
  STA $0206 ; set the sprite attributes (palette, flipping, etc)

  LDA #$34
  STA $0209 ; set the sprite number to display
  LDA #$00
  STA $020A ; set the sprite attributes (palette, flipping, etc)

  LDA #$35
  STA $020D ; set the sprite number to display
  LDA #$00
  STA $020E ; set the sprite attributes (palette, flipping, etc)

vblankwait2:      ; Second wait for vblank, PPU is ready after this
  BIT $2002
  BPL vblankwait2

  ; now that the ppu is ready, we can start initializing it
LoadPalettes:
  LDA $2002    ; read PPU status to reset the high/low latch
  LDA #$3F
  STA $2006    ; write the high byte of $3F00 address
  LDA #$00
  STA $2006    ; write the low byte of $3F00 address
  LDX #$00
LoadPalettesLoop:
  LDA palette.w, x      ;load palette byte
  STA $2007             ;write to PPU
  INX                   ;set index to next byte
  CPX #$20
  BNE LoadPalettesLoop  ;if x = $20, 32 bytes copied, all done

  LDA #%00010000   ; enable sprites
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
  ASL buttons_pressed
  ORA buttons_pressed
  STA buttons_pressed
  INX
  JMP read_controller1_values

end_read_controller1:
  RTS

turn_blue:
  LDA #%10010000
  STA $2001
  LDA #$00
  STA current_state
  RTS

turn_green:
  LDA #%01010000
  STA $2001
  LDA #$01
  STA current_state
  RTS

turn_red:
  LDA #%00110000
  STA $2001
  LDA #$02
  STA current_state
  RTS

NMI:
  JSR read_controller1

handle_up:
  LDA buttons_pressed
  AND #%00001000
  CMP #$00
  BEQ handle_down
  LDY sprite_y
  DEY
  STY sprite_y

handle_down:
  LDA buttons_pressed
  AND #%00000100
  CMP #$00
  BEQ handle_left
  LDY sprite_y
  INY
  STY sprite_y

handle_left:
  LDA buttons_pressed
  AND #%00000010
  CMP #$00
  BEQ handle_right
  LDY sprite_x
  DEY
  STY sprite_x

handle_right:
  LDA buttons_pressed
  AND #%00000001
  CMP #$00
  BEQ handle_a
  LDY sprite_x
  INY
  STY sprite_x

handle_a:
  LDA buttons_pressed
  AND #%10000000
  CMP #$00
  BEQ nmi_return

  LDY current_state
  CPY #$00
  BEQ call_turn_green
  CPY #$01
  BEQ call_turn_red

call_turn_blue:
  JSR turn_blue
  JMP nmi_return
call_turn_green:
  JSR turn_green
  JMP nmi_return
call_turn_red:
  JSR turn_red
  JMP nmi_return

nmi_return:
  ; update the sprite locations
  LDA sprite_y
  STA $0200
  LDA sprite_x
  STA $0203

  LDA sprite_y
  STA $0204
  LDA sprite_x
  ADC #$07 ; XXX why is this #$07 instead of #$08?
  STA $0207

  LDA sprite_y
  ADC #$08
  STA $0208
  LDA sprite_x
  STA $020B

  LDA sprite_y
  ADC #$08
  STA $020C
  LDA sprite_x
  ADC #$08
  STA $020F

  ; load the sprite into the ppu ports (from $0200)
  LDA #$00
  STA $2003
  LDA #$02
  STA $4014

  RTI

palette:
  .db $0F,$31,$32,$33,$0F,$35,$36,$37,$0F,$39,$3A,$3B,$0F,$3D,$3E,$0F
  .db $0F,$1C,$15,$14,$0F,$02,$38,$3C,$0F,$1C,$15,$14,$0F,$02,$38,$3C

  .orga $FFFA    ;first of the three vectors starts here
  .dw NMI        ;when an NMI happens (once per frame if enabled) the 
                   ;processor will jump to the label NMI:
  .dw RESET      ;when the processor first turns on or is reset, it will jump
                   ;to the label RESET:
  .dw 0          ;external interrupt IRQ is not used in this tutorial


  .bank 1 slot 1
  .org $0000
  .incbin "mario.chr"
