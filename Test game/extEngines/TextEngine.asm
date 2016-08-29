TxtDefaultProcess:


	;;check if text is resetting
	LDA txtPauseFlag
	CMP #$00
	BNE TxtDefaultDone
	
	LDA txtResetFlag
	CMP #$00
	BNE TxtDefaultDone
	
	LDA txtDisableFlag
	CMP #$00
	BNE TxtDefaultDone
	
	;;check if on a print frame
	DEC txtFrmCount
	LDA txtFrmCount
	;;CMP #TXTFAST
	;;CMP #TXTSLOW
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

	LDA #$00
	STA txtDisableFlag
	RTS
	
;--------------------------------------

TxtDisable:

	LDA #$01
	STA txtDisableFlag
	JSR PrepareReset
	LDA txtCurrentTxt+1
	LDX txtCurrentTxt
	JSR TxtLoad
	RTS
	
;--------------------------------------
;--------------------------------------

TxtPause:

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

	;;pass in values: A- high, X- low

	STA txtPtr+1
	STA txtCurrentTxt+1
	STX txtPtr
	STX txtCurrentTxt

	LDA txtDefaultSpeed
	JSR TxtSetSpeed
	STA txtFrmCount

	RTS
	
	;;load text file from label
	;;set txtptr to first 
	
;--------------------------------------
TxtSetStart:

	STA txtStart+1
	STX txtStart
	RTS

TxtSetMaxLin:

	STA txtMaxLin
	RTS

TxtSetMaxChr:

	STA txtMaxChr
	RTS
	
TxtSetLoc:

	STA txtLoc+1
	STX txtLoc
	RTS
	
TxtSetSpeed:

	CMP #$00
	BNE .nonDefault
	LDA txtDefaultSpeed

.nonDefault:
	STA txtSpeed
	RTS
	
TxtSetInputTileLoc:

	STA txtInputTileLoc+1
	STX txtInputTileLoc
	RTS
	
;--------------------------------------	

TxtParse:

	;;read charfrom data
	;;if char, load to print
	;;else, do one of the other things (reset, line break, space, etc)
	
	LDY #$00
	
	
	LDA [txtPtr], y
	CMP #$30
	BCC .print
	

.opcode:

	CMP #$FF
	BEQ .close
	CMP #$FE
	BEQ .wait
	CMP #$FD
	BEQ .loop
	CMP #$FC
	BEQ .reset
	CMP #$FB
	BEQ .lnBreak
	CMP #$FA
	BEQ .space
	CMP #$F9
	BEQ .speed ;sets new speed
	CMP #$F8
	BEQ .pause ;adds to frame count
	JMP .update_pointer

.print:

	JSR TxtPrint
	JSR TxtNext
	;INC txtChrCount
	JSR TxtIncChrCount
	JMP .update_pointer
	
.loop:
	
	JSR PrepareReset
	LDA txtCurrentTxt+1
	LDX txtCurrentTxt
	JSR TxtLoad
	JMP .end
	
.wait

	LDA #TXTPAUSETILE
	JSR TxtPause
	JMP .update_pointer
	
.close:	
	
	JSR TxtDisable
	JMP .end
	
.space:
	
	JSR TxtIncPtr
	JSR TxtSpace
	;INC txtChrCount
	JSR TxtIncChrCount
	LDA txtPauseFlag	;;check if pause flag was set during IncChrCount
	CMP #$01			
	BEQ .end			;;if so, skip second parse
	JSR TxtParse
	JMP .end
	
.lnBreak:

	JSR TxtIncPtr
	JSR LineBreak
	JSR TxtParse
	JMP .end
	
.reset:

	JSR PrepareReset
	JMP .update_pointer

.speed:

	JSR TxtIncPtr
	LDA [txtPtr], y
	JSR TxtSetSpeed
	JSR TxtIncPtr
	JSR TxtParse
	JMP .end

.pause

	;;txtTemp used to hold addable value needed whenever
	JSR TxtIncPtr
	LDA [txtPtr], y
	STA txtTemp
	LDA txtFrmCount
	CLC
	ADC txtTemp
	STA txtFrmCount

.update_pointer:

	JSR TxtIncPtr

.end:

	RTS
	
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


TxtIncChrCount:

	INC txtChrCount
	LDA txtChrCount
	CMP txtMaxChr
	BNE IncChrDone
	JSR TxtIncLinCount

IncChrDone:

	RTS

TxtIncLinCount:

	INC txtLinCount
	LDA #00
	STA txtChrCount
	
	LDA txtLinCount
	CMP txtMaxLin
	BNE IncLinDone
	
	JSR PrepareReset
	LDA #TXTPAUSETILE
	JSR TxtPause

IncLinDone:

	RTS
	
;--------------------------------------
TxtPrint:

	;;print current char in txtPtr
	
	TAY
	
	LDA $2002
	LDA txtLoc+1
	STA $2006
	LDA txtLoc
	STA $2006
	
	TYA
	STA $2007
	
	RTS
	
;--------------------------------------
TxtNext:

	;;increments screen location of printing
	INC txtLoc
	LDA txtLoc
	CMP #$00
	BNE NextDone
	INC txtLoc+1
	
NextDone:

	RTS
	
TxtSpace:

   ;;insert a space
   JSR TxtNext
   
   RTS
  

LineBreak:
	
	;;subtract current offest from #$40, store into text linebreak offset 
	LDA #$40
	SEC
	SBC txtChrCount
	STA txtLnBrkOff
	
	LDA txtLoc
	CLC
	;ADC #$30
	ADC txtLnBrkOff
	STA txtLoc
	LDA txtLoc+1
	ADC #$00
	STA txtLoc+1
	
	JSR TxtIncLinCount
	
	RTS
	
LineBreakHead:


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

	INC txtPtr
	LDA txtPtr
	CMP #$00
	BNE .end
	INC txtPtr+1
.end:
	RTS
	
;--------------------------------------
PrepareReset:

	;;prepare text box for reset, assumes default 16char x 3line block
	LDA txtStart+1
	STA txtLoc+1
	LDA txtStart
	STA txtLoc
	
	LDA #$03
	STA txtResetFlag
	LDA #$01
	StA txtResetInit
	RTS

;--------------------------------------
TxtReset:

	LDA txtPauseFlag
	CMP #$00
	BNE ResDone
	;;resets 1 line per frame, assumes default 16char x 3line block
	LDA txtResetInit
	CMP #$01
	BNE ResDone
	
	LDA $2002
	LDA txtLoc+1
	STA $2006
	LDA txtLoc
	STA $2006
	
	LDX #$00

TxtResetLoop:

	LDA #$53
	STA $2007
	INX
	CPX txtMaxChr
	BNE TxtResetLoop
	
	JSR LineBreakHead
	
	DEC txtResetFlag
	LDA txtResetFlag
	CMP #$00
	BNE ResDone
	
ResTop:

	LDA txtStart+1
	STA txtLoc+1
	LDA txtStart
	STA txtLoc
	
	LDA #$00
	STA txtResetInit
	
	LDA #00
	STA txtChrCount
	LDA #$00
	STA txtLinCount

	
ResDone:

	RTS