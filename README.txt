Rocky's NES text tool and engine

version 1.1


UPDATES (8-29-16):

	-fixed some bugs and flow
	-added wait for wait for input
	-added speed changes
	-added pauses

INCLUDED:

	-the text tool
	-sample game to test with
	-text engine assembly file

INITIAL TEST:

	-open the "Test game" folder
	-open TextTest.nes
	-press up to initialize start the flow of text
	-press down to cancel and disable teh flow of text

---------------------------------------------------------------------------------------------

EDITOR USE:

	opening the text editor creates a new text file. press "Add" under the list 
	window to create a new block of text data. text data consists of a label and 
	a string of text. 

	Labels and strings are limited in input. labels can only contain numbers, letters, and the character '_'. 
	strings can contain the text characters availible in the first three lines of the text.chr file:

	0123456789abcdef
	ghijklmnopqrstuv
	wxyz.?!,:'"%~$-*

	some capital letters are acceptable for opcodes:

	
	'N' - line break
	'R' - reset text box
	'L' - loop text from beggining
	'W' - wait for input (resets box after)
	' ' - a space is also an opcode that the engine will recongnize. 
	
	There are also "additive" codes which require a certain amount of digits after the code is called to export correctly.
	
	'SXXX' - sets the over all speed of the text to XXX frames.
	'PXXX' - adds XXX to the frames needed to print the next character, creating a pause.

	currently, you can input values up to 999, but it wil be converted to one bye in HEX, so values over 255 will just flip over.

	when you've made all the text data's you want, you can save the data as an 
	XML for later use (with the Save option), or as an .i or .asm file for the engine
	(with the Export option).

	the .i/.asm data can be ".include"-ed in your game's main asm file.


---------------------------------------------------------------------------------------------

BASIC ENGINE USE:

	after including the data and the engine in your main asm file, you'll need to add some vaiables into your 
	zero page:

		txtPtr		  .rs 2
		txtChrCount	  .rs 1
		txtLnBrkOff	  .rs 1
		txtLinCount	  .rs 1
		txtFrmCount	  .rs 1
		txtLoc		  .rs 2
		txtResetFlag      .rs 1
		txtDisableFlag    .rs 1
		txtResetInit      .rs 1
		txtCurrentTxt     .rs 2
		txtTemp		  .rs 1
		txtStart	  .rs 2
		txtSpeed	  .rs 1
		txtDefaultSpeed   .rs 1
		txtMaxChr	  .rs 1
		txtMaxLin	  .rs 1
		txtInputTileLoc	  .rs 2
		txtPauseFlag	  .rs 1
		txtPrepareUnpause .rs 1

	And some declarations:

		TXTFAST	   = $03
		TXTMED	   = $06
		TXTSLOW	   = $09
		TXTPAUSETILE = $3B 		;;tile used for input wait
		TXTENDTILE = $3D		;;tile used for end wait (not yet implemented)
		TXTNORMALTILE = $53		;;tile replaced by pause tiles

	...which of cousre can be any value you would like! but these are the defaults for the test project.


	For version 1.0, all txt code is called in the NMI, like so:
	
		  JSR TxtReset
  		  JSR TxtDefaultProcess
  		  LDA txtPrepareUnpause
  		  CMP #$01
  		  BNE UnpauseDone
  
  		  JSR TxtUnpause
  		  LDA #$00
  		  STA txtPrepareUnpause
  
	UnpauseDone:

		  ;; and so on

	if the text box is resetting, the first code follows through. if not, it goes ahead to the next
	process. I'm aware this isn't the best way to do this, but it works for now. 


---------------------------------------------------------------------------------------------

ENGINE FUNCTIONS:

	
	TxtDefaultProcess : basic frame based print out
	TxtEnable	  : enables text engine to start printing
	TxtDisable	  : disables text, resets box, re-loads current text
	TxtPause	  : writes the tile passed in A to the input tile location, sets the pause flag
	TxtUnpause	  : writes the usual tile back to the input tile location, turns off pause flag
	TxtLoad		  : loads text data block from passed in values (A - high byte, X- Low byte)
	TxtSetStart	  : sets the start location of printed text
	TxtSetMaxLin	  : sets the max line count before a default box reset (from A)
	TxtSetMaxChr	  : sets the max character count before a default line break (from A)
	TxtSetLoc	  : sets location of printhead (from A and X)
	TxtSetSpeed	  : sets speed of text (passed in from A). if the passed in speed is Zero, resets to default speed
	TxtSetInputTileLoc: sets screen location for the input tile
	TxtParse	  : parses current byte of data block
	TxtPrint	  : prints current byte of data block from background table
	TxtNext		  : goes to next consecutive space on screen to print to
	TxtSpace	  : adds a space (a call to TxtNext)
	LineBreak	  : break line (currentnly double spaced)
	LineBreakHead (used by reset only, really- needs work) : used in reset. Currently based on 16 char lines.
	TxtIncPtr	  : increments pointer in data block to the next byte
	PrepareReset	  : prepares to reset the text block
	TxtReset	  : resets text block (based on 3 16 chr lines)

some functions have been left out of here since they are only used by other code, such as teh calls for increments to line and character counts.
---------------------------------------------------------------------------------------------

This is still most definitely a work in progress. Please send any and all feedback to:

johnwelter@me.com

Thanks!

	-John Welter





