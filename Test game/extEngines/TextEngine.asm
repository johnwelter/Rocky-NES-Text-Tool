;
; TextEngine.asm
;
; John Welter
; 2016
; 
; dynamic text engine for NES game production
; 
;
;


TxtProcess:

	LDA txtDisableFlag	;check if disabled
	CMP #$00			
	BNE TxtDefaultDone	;if so, skip all of this.

	LDA txtPauseFlag	;check if paused
	CMP #$00
	BEQ .notPaused		;if so, 
	
	LDA txtPrepareUnpause	;check if A was pressed to prepare unpause
	CMP #$01
	BNE .unpauseDone		;if so
  
	JSR TxtUnpause			;use this frame to unpause
	LDA #$00
	STA txtPrepareUnpause

.unpauseDone:	

	JMP TxtDefaultDone		;finish this frame
	

.notPaused:
	
	LDA txtResetFlag	;else if not paused, check if resetting
	CMP #$00
	BEQ .notResetting	;if so,
	
	JSR TxtReset		;do a frame of reset
	JMP TxtDefaultDone	;finish this frame
	
.notResetting:			
	
	;;check if on a print frame
	DEC txtFrmCount
	LDA txtFrmCount
	CMP #$00
	BNE TxtDefaultDone
	
	JSR TxtParse

ResetFrame:

	LDA txtFrmCount
	CLC
	ADC txtSpeed
	STA txtFrmCount
	
TxtDefaultDone:
	
	RTS


;--------------------------------------

TxtEnable:

	;enables text

	LDA #$00
	STA txtDisableFlag
	RTS
	
;--------------------------------------

TxtDisable:

	;disables text
	;resets text block
	;reloads text from current text variable

	LDA #$01
	STA txtDisablePrepareFlag
	JSR PrepareReset
	LDA txtCurrentTxt+1
	LDX txtCurrentTxt
	JSR TxtLoad
	RTS
	
;--------------------------------------
;--------------------------------------

TxtPause:

	;
	; input- A = input wait tile
	; 
	; set PPU input location from Input Tile Location variable
	;
	; print tile at location
	;
	; set pause flag 

	TAY
	
	LDA $2002
	LDA txtInputTileLoc+1
	STA $2006
	LDA txtInputTileLoc
	STA $2006
	
	TYA
	STA $2007
	
	LDA #$01
	STA txtPauseFlag
	RTS
	
;--------------------------------------

TxtUnpause:

	; set PPU input location from Input Tile Location variable
	;
	; resets input tile location to it's original form (from #TXTNORMALTILE)
	;
	; resets pause flag

	LDA $2002
	LDA txtInputTileLoc+1
	STA $2006
	LDA txtInputTileLoc
	STA $2006
	
	LDA #TXTNORMALTILE
	STA $2007

	LDA #$00
	STA txtPauseFlag
	RTS
	
;--------------------------------------

TxtLoad:

	;
	; input- A = high byte of text data, X = low byte of text data
	; sets text pointer and current text variables to passed in values
	;
	; sets text speed to default
	; resets frame count

	STA txtPtr+1
	STA txtCurrentTxt+1
	STX txtPtr
	STX txtCurrentTxt

	LDA txtDefaultSpeed
	JSR TxtSetSpeed
	STA txtFrmCount

	RTS
	
	
;--------------------------------------
TxtSetStart:

	; input- A = high byte of location, X = low byte of location
	;
	; sets start of text box to passed in values	
	
	STA txtStart+1
	STX txtStart
	RTS

TxtSetMaxLin:

	; input- A = max line count
	; sets max line count
	
	STA txtMaxLin
	RTS

TxtSetMaxChr:

	; input- A = max character count
	; sets max character count

	STA txtMaxChr
	RTS
	
TxtSetLoc:

	; input - A = high byte of printhead location, X = low byte of printhead location
	;
	; sets printhead location

	STA txtLoc+1
	STX txtLoc
	RTS
	
TxtSetSpeed:

	; input A = speed to change to
	;
	; if the input is 0
	;	reset speed to default
	; else
	;	set speed

	CMP #$00
	BNE .nonDefault
	LDA txtDefaultSpeed

.nonDefault:

	STA txtSpeed
	RTS
	
TxtSetInputTileLoc:

	; input- A = high byte of input tile location, X = low byte of input tile location
	;
	; sets input tile location

	STA txtInputTileLoc+1
	STX txtInputTileLoc
	RTS
	
;--------------------------------------	

TxtParse:

	;;read charfrom data
	;;if char, load to print
	;;else, do one of the other commands
	
	LDY #$00
	
	
	LDA [txtPtr], y			;get byte from text pointer
	CMP #$30				;if below 0x30, it's a character
	BCC .print				;	jump to print
	

.opcode:					;else, it's an opcode

	CMP #$FF				;FF - end of text data
	BEQ .close
	CMP #$FE				;FE - wait for input 
	BEQ .wait
	CMP #$FD				;FD - loop from beginning
	BEQ .loop
	CMP #$FC				;FC - reset text box
	BEQ .reset
	CMP #$FB				;FB - line break
	BEQ .lnBreak
	CMP #$FA				;FA - insert space
	BEQ .space
	CMP #$F9				;F9 - set speed
	BEQ .speed
	CMP #$F8				;F8 - pause the text for extra frames (adds to frame count one time)
	BEQ .pause
	JMP .update_pointer		;else, update the pointer

.print:

	; prints character to screen
	; incriments printhead
	; incriments character count
	; update pointer
	
	JSR TxtPrint
	JSR TxtNext
	;INC txtChrCount
	JSR TxtIncChrCount
	JMP .update_pointer
	
.loop:
	
	; reset text block
	; reload current text
	; finish
	
	JSR PrepareReset
	LDA txtCurrentTxt+1
	LDX txtCurrentTxt
	JSR TxtLoad
	JMP .end
	
.wait
	
	; pause to wait for input
	; update pointer
	
	LDA #TXTPAUSETILE	;load tile to indicate input wait
	JSR TxtPause
	JMP .update_pointer
	
.close:	
	
	; disable text 
	; finish
	
	JSR TxtDisable
	JMP .end
	
.space:

	; increment pointer to next byte
	; insert space
	; increment the character count
	; if not paused
	; 	parse again
	; else
	; 	finish
	
	JSR TxtIncPtr
	JSR TxtSpace
	JSR TxtIncChrCount
	LDA txtPauseFlag	;;check if pause flag was set during IncChrCount
	CMP #$01			
	BEQ .end			;;if so, skip second parse
	JSR TxtParse
	JMP .end
	
.lnBreak:

	; increment pointer to next byte
	; break line
	; parse again

	JSR TxtIncPtr
	JSR LineBreak
	JSR TxtParse
	JMP .end
	
.reset:

	; prepare reset
	; update pointer
	
	JSR PrepareReset
	JMP .update_pointer

.speed:

	; increment pointer to next byte
	; read byte for new speed
	; set the speed
	; increment pointer again
	; reparse
	; finish

	JSR TxtIncPtr
	LDA [txtPtr], y
	JSR TxtSetSpeed
	JSR TxtIncPtr
	JSR TxtParse
	JMP .end

.pause

	; increment pointer to next byte
	; read byte for pause frames
	; add to frame count 
	
	JSR TxtIncPtr
	LDA [txtPtr], y
	STA txtTemp			; txtTemp used to hold addable value needed whenever
	LDA txtFrmCount		; adds extra frames to frame count
	CLC
	ADC txtTemp
	STA txtFrmCount

.update_pointer:

	; increment pointer to next byte
	
	JSR TxtIncPtr

.end:

	; finish
	
	RTS
	
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;Increments for Character count and Line count

TxtIncChrCount:

	; Increments character count from characters and spaces

	INC txtChrCount		; increment character count
	LDA txtChrCount		
	CMP txtMaxChr		; if not equal to max characters, 
	BNE IncChrDone		; 	finish
						; else
	JSR LineBreak		; break line

IncChrDone:

	RTS					; finish
		
TxtIncLinCount:

	INC txtLinCount		; increment line count
	LDA #$00				; set character count to 0
	STA txtChrCount
	
	LDA txtLinCount		
	CMP txtMaxLin		; if line count is not maxed out,
	BNE IncLinDone		; 	finish
						; else
	JSR PrepareReset	; prepare to reset block
	LDA #TXTPAUSETILE
	JSR TxtPause		;wait for input

IncLinDone:

	RTS
	
;--------------------------------------
TxtPrint:

	;;print current char in txtPtr
	
	TAY
	
	LDA $2002		; set PPU input location to print head
	LDA txtLoc+1
	STA $2006
	LDA txtLoc
	STA $2006
	
	TYA				; print tile at the location
	STA $2007
	
	RTS
	
;--------------------------------------
TxtNext:

	;;increments screen location of printing
	
	INC txtLoc
	LDA txtLoc
	CMP #$00		; if the low byte flips over,
	BNE NextDone	
	INC txtLoc+1	; increment the high byte
	
NextDone:

	RTS
	
TxtSpace:

   ;; insert a space by incrementing the printhead an extra space
   JSR TxtNext
   RTS
  

LineBreak:
	
	; subtract current offest from #$40, store into text linebreak offset 
	LDA #$40
	SEC
	SBC txtChrCount ;current offset = 0x40 - character count
	STA txtLnBrkOff
	
	; add offset to printhead location
	LDA txtLoc
	CLC
	ADC txtLnBrkOff
	STA txtLoc
	LDA txtLoc+1
	ADC #$00
	STA txtLoc+1
	
	JSR TxtIncLinCount ; increment line count
	
	RTS
	
LineBreakHead:

	;; used in reset- reset blacks out a line starting from the printhead without 
	;; changing the printhead, so a different line break is necessary to get it to the next line.
	;;[CURRENT]: double spaced, same X offset as head of last line, assuming 16 char lines, from head of last line
	LDA txtLoc
	CLC
	ADC #$40
	STA txtLoc
	LDA txtLoc+1
	ADC #$00
	STA txtLoc+1
	
	RTS
;-------------------------------------

TxtIncPtr:

	INC txtPtr		; increment pointer to next byte
	LDA txtPtr
	CMP #$00
	BNE .end
	INC txtPtr+1	;if low byte flips over, increment high byte
.end:
	RTS
	
;--------------------------------------
PrepareReset:

	;;prepare text box for reset, assumes default 16char x 3line block
	LDA txtStart+1		;sets printhead to beggining of text box
	STA txtLoc+1
	LDA txtStart
	STA txtLoc
	
	LDA #$03			;sets reset flag (to three, since it's decremented)
	STA txtResetFlag
	LDA #$01			;not to sure what this is for anymore- appears to be an initializer for reset (original flag?)
	StA txtResetInit
	RTS

;--------------------------------------
TxtReset:

	;LDA txtPauseFlag ;if it's not paused, continue with the reset
	;CMP #$00
	;BNE ResDone
	;;resets 1 line per frame, assumes default 16char x 3line block
	LDA txtResetInit ;make sure reset is initiated
	CMP #$01
	BNE ResDone
	
	LDA $2002		;set PPU input location to printhead
	LDA txtLoc+1
	STA $2006
	LDA txtLoc
	STA $2006
	
	LDX #$00		

TxtResetLoop:

	LDA #$53			;load text box background tile
	STA $2007			;print to PPU location
	INX				
	CPX txtMaxChr		;if X does not equal the max character count for the line, 
	BNE TxtResetLoop	;loop to continuously print background tiles (automatically increments PPU location)
	
	JSR LineBreakHead 	;else move print head down 
	
	DEC txtResetFlag  	;decremnent reset flag
	LDA txtResetFlag  	;if the flag is not 0, finish for this frame and continue the next
	CMP #$00
	BNE ResDone
						;else
ResTop:					
						
	LDA txtStart+1	  	;set printhead back to the top
	STA txtLoc+1
	LDA txtStart
	STA txtLoc
	
	LDA #$00		  	;disable the reset
	STA txtResetInit
	
	LDA #$00		  	;reset character count
	STA txtChrCount
	LDA #$00		  	;reset line count
	STA txtLinCount
	
	LDA txtDisablePrepareFlag ;if if prepared for disable
	CMP #$00
	BEQ ResDone
	
	STA txtDisableFlag		;disable the text engine
	LDA #$00				
	STA txtDisablePrepareFlag ;reset the preparation flag

	
ResDone:

	RTS
	