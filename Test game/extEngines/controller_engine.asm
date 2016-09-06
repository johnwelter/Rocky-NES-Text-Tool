;
; controller_engine.asm
;
; John Welter
; 2016
;
; controller reader for NES production
;
; includes more options for reading input (keeps track of pressed, released, and held buttons per read)



read_joypad:
    lda joypad1
    sta joypad1_old 	;save last frame's joypad button states
    
	lda #$01
    sta $4016
    lda #$00
    sta $4016
    
    ldx #$08
.loop:    
    lda $4016
    lsr a
    rol joypad1  		;A, B, select, start, up, down, left, right
    dex
    bne .loop
    
    lda joypad1_old 	;what was pressed last frame.  EOR to flip all the bits to find ...
    eor #$FF    		;what was not pressed last frame
    and joypad1 		;what is pressed this frame
    sta joypad1_pressed ;stores off-to-on transitions
	
	lda joypad1_old		;what was pressed last frame.  EOR to flip all the bits to find ...
	eor #$FF			;what was not pressed last frame
	ora joypad1			;or with what is pressed this frame
	eor #$FF			;then flip it
	sta joypad1_released;to find what was released (on-to-off transitions)
	
	lda joypad1_old 	;what was pressed last frame. 
	and joypad1 		;and with what is pressed this frame
	sta joypad1_held	;to find what's held
    rts
