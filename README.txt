Rocky's NES text tool and engine

version 1.2

UPDATES (10-28-16):

	-initial text box functionality
	-auto text formatting script

UPDATES (8-29-16):

	-fixed some bugs and flow
	-added wait for wait for input
	-added speed changes
	-added pauses
-------------------------------------------------------------------------------------------
CONTENTS:

	EDITOR USE
	BASIC ENGINE USE
	ENGINE FUNCTIONS
	THE AUTO TEXT FORMATTER

INCLUDED:

	-the text tool
	-sample game to test with
	-all source code for the game

INITIAL TEST:

	-open the "Test game" folder
	-open TextTest.nes
	-press up to initialize start the flow of text
	-press down to cancel and disable teh flow of text
	-press A to continue if paused

---------------------------------------------------------------------------------------------
;;;;;;;;;;;;
;EDITOR USE;
;;;;;;;;;;;;

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
;;;;;;;;;;;;;;;;;;
;BASIC ENGINE USE;
;;;;;;;;;;;;;;;;;;

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
		txtDisablePrepareFlag .rs 1
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
		txtBoxWidth       .rs 1
		txtBoxHeight	  .rs 1
		txtBoxLoc	  .rs 2	
		txtBoxTilePtr	  .rs 2
		txtBoxDrawFlag	  .rs 1

	And some declarations:

		TXTFAST	   = $03
		TXTMED	   = $06
		TXTSLOW	   = $09
		TXTPAUSETILE = $3B 		;;tile used for input wait
		TXTENDTILE = $3D		;;tile used for end wait (not yet implemented)
		TXTNORMALTILE = $53		;;tile replaced by pause tiles

	...which of cousre can be any value you would like! but these are the defaults for the test project.


before the game starts, it would be wise to fill in some default values to start with, at least under the current version. here is what the test game uses, as a guide:

	;initializes text engine and variables
  
  	LDA #$16
  	LDX #$09
  	JSR TxtSetBoxDimensions
  
  	LDA #$22
  	LDX #$65
  	JSR TxtSetBoxLocation
  
  	LDA #$22			
  	LDX #$A8
  	
  	JSR TxtSetStart			;sets the text box to start at loaction 22A8 on the screen
  	JSR TxtSetLoc			;sets print head to the same location
  
  	LDA #$23	
  	LDX #$59
  
  	JSR TxtSetInputTileLoc		;sets input tile loaction to 2359 on the screen
  
  	LDA #$03
  
  	JSR TxtSetMaxLin		;sets max line count to 3
 
  	LDA #$10					
  
  	JSR TxtSetMaxChr		;sets max charatcer count per line to 16
  
  	LDA #TXTFAST
  
  	STA txtDefaultSpeed		;sets default speed to fast (3 frames between parses)
  	JSR TxtSetSpeed			;sets current speed to same speed
  
  	LDA #$01
 	STA txtDisableFlag		;;needs to be able to just call the disable function- fixing in
					;;future updates.
  	LDA #HIGH(NumbText)	
  	LDX #LOW(NumbText)	
  
  	JSR TxtLoad

	

	You can easily call the text engine process in the NMI with this call:

	JSR TxtProcess
	



---------------------------------------------------------------------------------------------
;;;;;;;;;;;;;;;;;;
;ENGINE FUNCTIONS;
;;;;;;;;;;;;;;;;;;
	
	TxtProcess 	  : basic frame based print out
	TxtEnable	  : enables text engine to start printing
	TxtDisable	  : disables text, resets box, re-loads current text
	TxtPause	  : writes the tile passed in A to the input tile location, sets the pause flag
	TxtUnpause	  : writes the usual tile back to the input tile location, turns off pause flag
	TxtLoad		  : loads text data block from passed in values (A - high byte, X- Low byte)
	TxtSetStart	  : sets the start location of printed text
	TxtSetMaxLin	  : sets the max line count before a default box reset (from A)
	TxtSetMaxChr	  : sets the max character count before a default line break (from A)
	TxtSetLoc	  : sets location of printhead (from A and X)
	TxtSetSpeed	  : sets speed of text (passed in from A). if the passed in speed is Zero, resets 
			    to default speed
	TxtSetInputTileLoc: sets screen location for the input tile
	TxtParse	  : parses current byte of data block
	TxtPrint	  : prints current byte of data block from background table
	TxtNext		  : goes to next consecutive space on screen to print to
	TxtSpace	  : adds a space (a call to TxtNext)
	LineBreak	  : break line (currentnly double spaced)
	LineBreakHead     : used in reset, since the txtLoc used in reset never leaves the start of the
			    line.
	BoxLnBrkHd: 	  : same as the line break head, but single spaced. Currently a placeholder
	TxtIncPtr	  : increments pointer in data block to the next byte
	PrepareReset	  : prepares to reset the text block
	TxtReset	  : resets text block based on MaxChr and MaxLin
	TxtSetBoxDimensions: sets box width and height (A - W, X - H)
	TxtSetBoxLocation : sets location of box by top left corner(A - HI, X - LO)
	TxtSetTextToBox	  : NOT YET IMPLEMENTED- sets text location, pause tile location, max chr and max 			    lin based on the current box
	TxtPrepareBoxDraw : prepares to draw text box
	TxtBoxDraw	  : draws text box from width and height
	 

some functions have been left out of here since they are only used by other code, such as teh calls for increments to line and character counts.
---------------------------------------------------------------------------------------------'
;;;;;;;;;;;;;;;;;;;;;;;;;
;THE AUTO TEXT FORMATTER;
;;;;;;;;;;;;;;;;;;;;;;;;;

this handy little python script was made after spending an entire day trying to format the internet tough guy copy pasta. Such a task is incredibly tedious (add line breaks, test, add line breaks, test a little further, add line breaks, test a little further, etc etc), so the script makes the work exponentially quicker. 

you can type a short snippit of dialouge, or even an entire speech in to a txt file, throw it into the script, give the dimensions in terms of max character count per line and max line count, and you'll get another txt file with text you can copy directly into the text editor. it not only auto formats line breaks, but also adds pauses after punctuation. after this starting point, it's easy to go in and finess the text as you please!

for an example, here's some input:

Hello? Is there any body in there? Just nod if you can hear me... Is there anyone at home? Come on, now, I hear you're feeling down. Well I can ease your pain, get you on your feet again. Relax, I'll need some information first. Just the basic facts... Can you show me where it hurts?

and the resulting output txt file with a max character count of 16 and a max line count of 3:

hello?P015 is there any body inNthere?P015 just nod if you can hear me.P015.P015.P015 is thereNanyone at home?P015 come on,P010 now,P010 i hear you'reNfeeling down.P015Nwell i can ease your pain,P010 getNyou on your feetagain.P015 relax,P010Ni'll need someNinformationNfirst.P015 just the basic facts.P015.P015.P015Ncan you show me where it hurts?P015W
 


---------------------------------------------------------------------------------------------

This is still most definitely a work in progress. Please send any and all feedback to:

johnwelter@me.com

Thanks!

	-John Welter





