def vbl equs "call comm_WaitForVblank"

comm_WhiteFlash:
	call snd_Update
	vbl
		xor a ; white
		ldh [rBGP], a
		ldh [rOBP0], a
		ldh [rOBP1], a
	rept 3
	call snd_Update
	vbl
	endr
		ld a, BG_PAL
		ldh [rBGP], a
		ld a, OBJ1_PAL
		ldh [rOBP0], a
		ld a, OBJ2_PAL
		ldh [rOBP1], a
	call snd_Update
	; jp comm_WaitForVblank
	; ret

; vbl
comm_WaitForVblank:
	scf
	halt
	jr c, comm_WaitForVblank
	ret

; rand
comm_Rand:
	; Galois linear feedback shift register
	; https://wiki.nesdev.org/w/index.php?title=Random_number_generator
	ld16_h d, e, seed
	ld b, 8
	.loop:
		sla e
		rl d
		jr nc, :+
			ld a, e
			xor $39
			ld e, a
		:
		djnz .loop
	st16_h seed, d, e
	ld a, e
	ret