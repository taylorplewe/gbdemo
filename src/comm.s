comm_WhiteFlash:
	call WaitForVblank
		xor a ; white
		ldh [rBGP], a
		ldh [rOBP0], a
		ldh [rOBP1], a
	rept 3
	call WaitForVblank
	endr
		ld a, BG_PAL
		ldh [rBGP], a
		ld a, OBJ1_PAL
		ldh [rOBP0], a
		ld a, OBJ2_PAL
		ldh [rOBP1], a
	jp WaitForVblank
	; ret