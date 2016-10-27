;;;;;;;;;;;;;;;
;	NES UtilEngine
;
;	common code program
;	
;	John Welter
;	2016
;
;	for all that recurring code that keeps popping up, like PPU latch resets and what not
;
;;;;;;;;;;;;;;;


SetPPU:

  PHA
  LDA $2002
  PLA
  STA $2006 ;input A = high byte of draw location
  STX $2006 ;input X = low byte of draw location

  RTS
  
  
