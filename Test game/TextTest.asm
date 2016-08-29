  .inesprg 2   ; 2x 16KB PRG code
  .ineschr 0   ; 0x  8KB CHR data
  .inesmap 0   ; mapper 0 = NROM, no bank swapping
  .inesmir 1   ; background mirroring
  

;;;;;;;;;;;;;;;

tile_loader_ptr  .rs 2      ;pointer for the tile loader routine

tile_loader_addy  .rs 2     ;address to the tile data

tile_loader_counter  .rs 2  ;counters for the tile loading

tile_loader_stop  .rs 1     ;how many tiles to load

tile_loader_mark  .rs 2

pointer1  .rs 2                 ;pointer to the background information
pointer2  .rs 2
 
joypad1 .rs 1           ;button states for the current frame
joypad1_old .rs 1       ;last frame's button states
joypad1_pressed .rs 1   ;current frame's off_to_on transitions
joypad1_held	.rs 1	;current frame's held buttons
joypad1_released .rs 1	;current frame's released buttons

sleeping  .rs 1             ;run main program once per frame
updating_background  .rs 1  ;disable the NMI updates while updating the background

PartialEnableFlag	 .rs 1

scoreOnes 		  .rs 1
scoreTens		  .rs 1
scoreHundreds	  .rs 1

txtPtr		  .rs 2
txtChrCount	  .rs 1
txtLnBrkOff	  .rs 1
txtLinCount	  .rs 1
txtFrmCount	  .rs 1
txtLoc		  .rs 2
txtResetFlag  .rs 1
txtDisableFlag .rs 1
txtResetInit  .rs 1
txtCurrentTxt .rs 2
txtTemp		  .rs 1
txtStart	  .rs 2
txtSpeed	  .rs 1
txtDefaultSpeed .rs 1
txtMaxChr	  .rs 1
txtMaxLin	  .rs 1
txtInputTileLoc	.rs 2
txtPauseFlag	.rs 1
txtPrepareUnpause .rs 1

pointer	      .rs 2

;TXTSTARTHI	   = $22
;TXTSTARTLO	   = $A8
;TXTMAXLIN	   = $10
TXTFAST	   = $03
TXTMED	   = $06
TXTSLOW	   = $09
TXTPAUSETILE = $3B 		;;tile used for input wait
TXTENDTILE = $3D		;;tile used fot end wait
TXTNORMALTILE = $53		;;tile replaced by pause tiles

CONTROLLER_A = $80
CONTROLLER_B = $40
CONTROLLER_SELECT = $20
CONTROLLER_START = $10
CONTROLLER_UP = $08
CONTROLLER_DOWN = $04
CONTROLLER_LEFT = $02
CONTROLLER_RIGHT = $01
STATETITLE     = $00  ; displaying title screen
STATEPLAYING   = $01  ; move paddles/ball, check for collisions
STATEGAMEOVER  = $02  ; displaying game over screen
  


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    
  .bank 0
  .org $8000 

;;;;;;;;;;;;;;

RESET:
  SEI          ; disable IRQs
  CLD          ; disable decimal mode
  LDX #$40
  STX $4017    ; disable APU frame IRQ
  LDX #$FF
  TXS          ; Set up stack
  INX          ; now X = 0
  STX $2000    ; disable NMI
  STX $2001    ; disable rendering
  STX $4010    ; disable DMC IRQs

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
  STA $0200, x
  INX
  BNE clrmem
   
vblankwait2:      ; Second wait for vblank, PPU is ready after this
  BIT $2002
  BPL vblankwait2

LoadPalettes:
  LDA $2002             ; read PPU status to reset the high/low latch
  LDA #$3F
  STA $2006             ; write the high byte of $3F00 address
  LDA #$00
  STA $2006             ; write the low byte of $3F00 address
  LDX #$00              ; start out at 0
LoadPalettesLoop:
  LDA palette, x        
  STA $2007             ; write to PPU
  INX                   ; X = X + 1
  CPX #$20              ; Compare X to hex $10, decimal 16 - copying 16 bytes = 4 sprites
  BNE LoadPalettesLoop  ; Branch to LoadPalettesLoop if compare was Not Equal to zero
                        ; if compare was equal to 32, keep going down
  LDA #HIGH(backgroundA)
  LDX #LOW(backgroundA)
  JSR SetBackground
  JSR LoadBackground
  
  JSR TxtDisable
  
  LDA #$22
  LDX #$A8
  
  JSR TxtSetStart
  JSR TxtSetLoc
  
  LDA #$23
  LDX #$59
  
  JSR TxtSetInputTileLoc
  
  LDA #$03
  
  JSR TxtSetMaxLin
 
  LDA #$10
  
  JSR TxtSetMaxChr
  
  LDA #TXTFAST
  
  STA txtDefaultSpeed
  JSR TxtSetSpeed
  
  LDA #HIGH(SpeedAndPause)
  LDX #LOW(SpeedAndPause)
  
  JSR TxtLoad
  
  ;LDA #TXTSTARTHI
  ;STA txtLoc+1
  ;LDA #TXTSTARTLO
  ;STA txtLoc
  
  
  LDA #$00
  STA $2003              ; set the low byte (00) of the RAM address  

  LDX #$00
  JSR LoadCompleteBank   ;load the graphics into this "CHR-RAM" program 
  
  LDX #$02
  JSR LoadCompleteBank
  
  ;JSR PartialBankSetUp
              
  LDA #%10010000         ; disable NMI, sprites from Pattern Table 0, background from Pattern Table 1
  STA $2000

  LDA #%00011110         ; disable sprites, enable background, no clipping on left side
  STA $2001

;----------------------------------------------------------------------
;-----------------------START MAIN PROGRAM-----------------------------
;----------------------------------------------------------------------

Forever:
  
  INC sleeping

.loop
  LDA sleeping
  BNE .loop

  JSR read_joypad
  JSR handle_input
  
  
  ;;JSR PartialBankSetUp

  JMP Forever     ;jump back to Forever, infinite loop
  

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; 
;--------THE FUCKIN' NMI ROUTINE, RECOGNIZE BITCH!------------;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

NMI:

  PHA                              ;protect the registers
  TXA
  PHA
  TYA
  PHA

nmi_start:

  LDA #$00
  STA $2003  ; set the low byte (00) of the RAM address
  LDA #$02
  STA $4014  ; set the high byte (02) of the RAM address, start the transfer

  LDA updating_background
  BNE skip_graphics_updates
  
  
  JSR TxtReset
  JSR TxtDefaultProcess
  LDA txtPrepareUnpause
  CMP #$01
  BNE UnpauseDone
  
  JSR TxtUnpause
  LDA #$00
  STA txtPrepareUnpause
  
UnpauseDone:
  
  ;;JSR LoadPartialBank
  ;;JSR DrawScore
   
  LDA #$00        ;no scrolling
  STA $2005
  STA $2005
  STA $2006
  STA $2006

  LDA #%00011110  ;disable sprites,enable background,no clipping
  STA $2001

WakeUp:
  LDA #$00
  STA sleeping

skip_graphics_updates:

  PLA                              ;restore the registers
  TAY 
  PLA
  TAX
  PLA

  RTI             ; return from interrupt

;;;;;;;;;;;;;; 
;this section handles the input from the controllers and runs stuff
handle_input:

ReadUp:
  LDA joypad1_pressed	;Up
  AND #CONTROLLER_UP
  BEQ ReadUpDone
  JSR TxtEnable
  
  RTS

ReadUpDone:

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

ReadDown:
  LDA joypad1_pressed	;Down
  AND #CONTROLLER_DOWN
  BEQ ReadDownDone
  
  LDA txtPauseFlag
  CMP #$00
  BNE ReadDownDone
  JSR TxtDisable
  RTS

ReadDownDone:

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

ReadRight:
  LDA joypad1_pressed	;Right
  AND #CONTROLLER_RIGHT
  BEQ ReadRightDone
  RTS

ReadRightDone:

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

ReadLeft:
  LDA joypad1_pressed	;Left
  AND #CONTROLLER_LEFT
  BEQ ReadLeftDone
  RTS

ReadLeftDone:

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

ReadA:
  LDA joypad1_pressed
  AND #CONTROLLER_A
  BEQ ReadADone
  
  LDA txtPauseFlag
  CMP #$01
  BNE ReadADone
  
  LDA #$01
  STA txtPrepareUnpause
  
  RTS

ReadADone:

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  RTS

;-----------------------------------

;-------------------------------

;LoadSprite:
;
;	LDA #HIGH(BigSprite)
;	STA pointer1+1
;	LDA #LOW(BigSprite)
;	STA pointer1
	
;	LDA #$02
;	STA pointer2+1
;	LDA #$00
;	STA pointer2
	
	
;	LDX #$00
	
;LoadSpriteLoop:

;	LDY #$00

;.inner:

;	LDA [pointer1], y
;	STA [pointer2], y
;	INY
;	CPY #$00
;	BNE .inner
	
;-------------------------------
SetBackground:

	STA pointer1+1
	STX pointer1
	RTS

LoadBackground:

	;LDA #HIGH(backgroundA)
	;STA pointer1+1
	;LDA #LOW(backgroundA)
	;STA pointer1
	
	LDA $2002             ; read PPU status to reset the high/low latch
	LDA #$20
	STA $2006             ; write the high byte of $2000 address
	LDA #$00
	STA $2006             ; write the low byte of $2000 address
	
	;;set pointer
	;; set counters
	LDY #$00
	LDX #$00
	
	;;start loop

.outerloop:

.innerloop:

	LDA [pointer1], y
	STA $2007
	INY
	CPY #$00
	BNE .innerloop

	INC pointer1+1
	
	INX
	CPX #$04
	BNE .outerloop
	RTS

LoadCompleteBank: 

					;load in the sprite graphics

  LDA GraphicsPointers, X          ;this is all CHR-RAM stuff, not really covered here
  STA tile_loader_ptr             ;again, you wouldn't hard code this in practice
  LDA GraphicsPointers+1, X
  STA tile_loader_ptr+1

  LDY #$00
  LDA $2002
  LDA [tile_loader_ptr],y
  STA $2006
  INC tile_loader_ptr
  LDA [tile_loader_ptr],y
  STA $2006
  INC tile_loader_ptr
  LDX #$00
  LDY #$00
.LoadBank:
  LDA [tile_loader_ptr],y
  STA $2007
  INY
  CPY #$00
  BNE .LoadBank
  INC tile_loader_ptr+1
  INX
  CPX #$10
  BNE .LoadBank

  RTS

;-------------------------------------------------
;PartialBankSetUp:                ;load where to put in the new table
  
  LDX tile_loader_counter+1                  ;load the addresses
  LDA LoaderSpecs,X
  STA tile_loader_addy
  LDA LoaderSpecs+1,X
  STA tile_loader_addy+1

  LDA LoaderSpecs+2, X               ;load the number of entries
  STA tile_loader_stop

  LDA #LOW(REP_DATA)
  STA tile_loader_ptr
  LDA #HIGH(REP_DATA) 
  STA tile_loader_ptr+1

  LDA tile_loader_ptr
  ORA tile_loader_mark
  STA tile_loader_ptr

  LDA tile_loader_ptr+1
  ORA tile_loader_mark+1
  STA tile_loader_ptr+1

  LDA tile_loader_mark
  CLC
  ADC tile_loader_stop
  STA tile_loader_mark
  
  LDA tile_loader_mark+1
  ADC #$00
  STA tile_loader_mark+1

  
  INC tile_loader_counter
  INC tile_loader_counter+1
  INC tile_loader_counter+1
  INC tile_loader_counter+1

  

  LDA tile_loader_counter
  CMP #$05
  BNE .done
  LDA #$00
  STA tile_loader_counter
  STA tile_loader_counter+1
  STA tile_loader_mark
  STA tile_loader_mark+1

.done
  RTS

;-------------------------------------------------

LoadPartialBank:

  LDA $2002
  LDA tile_loader_addy
  STA $2006
  LDA tile_loader_addy+1
  STA $2006
  LDY #$00
.LoadBank:
  LDA [tile_loader_ptr],y
  STA $2007
  INY
  CPY tile_loader_stop
  BNE .LoadBank
  
.done
  RTS

;-------------------------------------------------

IncrementScore:

IncOnes:
  LDA scoreOnes      ; load the lowest digit of the number
  CLC 
  ADC #$01           ; add one
  STA scoreOnes
  CMP #$0A           ; check if it overflowed, now equals 10
  BNE IncDone        ; if there was no overflow, all done
IncTens:
  LDA #$00
  STA scoreOnes      ; wrap digit to 0
  LDA scoreTens      ; load the next digit
  CLC 
  ADC #$01           ; add one, the carry from previous digit
  STA scoreTens
  CMP #$0A           ; check if it overflowed, now equals 10
  BNE IncDone        ; if there was no overflow, all done
IncHundreds:
  LDA #$00
  STA scoreTens      ; wrap digit to 0
  LDA scoreHundreds  ; load the next digit
  CLC 
  ADC #$01           ; add one, the carry from previous digit
  STA scoreHundreds
IncDone:
	
	RTS 
	
DrawScore:
  LDA $2002
  LDA #$20
  STA $2006
  LDA #$9B
  STA $2006          ; start drawing the score at PPU $2020
  
  LDA scoreHundreds  ; get first digit
;  CLC
;  ADC #$30           ; add ascii offset  (this is UNUSED because the tiles for digits start at 0)
  STA $2007          ; draw to background
  LDA scoreTens      ; next digit
;  CLC
;  ADC #$30           ; add ascii offset
  STA $2007
  LDA scoreOnes      ; last digit
;  CLC
;  ADC #$30           ; add ascii offset
  STA $2007
  RTS

;-------------------------------------------------  
	.include "extEngines/TextEngine.asm"
	.include "extEngines/controller_engine.asm"
;-------------------------------------------------


;;;;;;;;;;;;;;  
  
  .bank 1
  .org $A000
  
CHR_Data:

  .db $10,$00                  ;background address in the PPU

  .incbin "chrData/Text.chr"
  
REP_DATA:

  .incbin "chrData/TextRep.chr"
 

  
  
;;;;;;;;;;;;;;;
;--------------------------


;;;;;;;;;;;;
;;;;;;;;;;;;

  .bank 2
  .org $C000
  
Sprite_Data:

	.db $00, $00
	
	.incbin "chrData/CharSprites.chr"

;;;;;;;;;;;;
;;;;;;;;;;;;



;;;;;;;;;;;;
;;;;;;;;;;;;
;;;;;;;;;;;;

  .bank 3
  .org $E000
  
backgroundA:
  .incbin "nameTables/BackgroundBA.bin"
;;.incbin "nameTables/yomiTitle.bin"
  palette:
  .db $37,$30,$10,$0F,  $37,$30,$11,$0F,  $37,$30,$16,$0F,  $37,$30,$2A,$0F   ;;background palette
  .db $37,$30,$2C,$0F,  $37,$30,$26,$0F,  $37,$1C,$15,$14,  $37,$02,$38,$3C   ;;sprite palette
  
  
LoaderSpecs:
  .db $1B,$00,$40
  .db $1B,$40,$40
  .db $1B,$80,$40
  .db $1B,$C0,$40
  .db $1C,$00,$40
  

GraphicsPointers:

	.word Sprite_Data, CHR_Data
	
	.include "textFiles/snp.i"

;;;;;;;;;;;;
;;;;;;;;;;;;


;;;;;;;;;;;;

  .org $FFFA     ;first of the three vectors starts here
  .dw NMI        ;when an NMI happens (once per frame if enabled) the 
                   ;processor will jump to the label NMI:
  .dw RESET      ;when the processor first turns on or is reset, it will jump
                   ;to the label RESET:
  .dw 0          ;external interrupt IRQ is not used in this tutorial

;;;;;;;;;;;;
;;;;;;;;;;;;
