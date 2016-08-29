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
	
	lda joypad1_old		;11001001
	eor #$FF			;00110110
	ora joypad1			;00101100
	eor #$FF			;00111110
	sta joypad1_released;11000001
	
	lda joypad1_old 	;11001001
	and joypad1 		;00101100
	sta joypad1_held	;00001000
    
    rts
