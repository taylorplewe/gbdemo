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

; params:
	; c - X px position
	; e - Y px position
; returns:
	; Z - 0 if free, 1 if not
comm_CheckWall:
	push hl
	ld hl, test_room_walls
	; Y
		srl e
		srl e
		srl e
		srl e
		sla e ; /16 pixels, x2 wall bytes per row
		ld d, 0
		add hl, de
	; X
		ld a, c
		push af ; for bit shifting in a min
		bit 7, a
		jr z, :+
			inc hl
		:
	; get that byte!
		ld d, [hl]
	; go to bit
		pop af
		swap a
		and %0000_0111
		jr z, .bit_loop_end
		.bit_loop:
			sla d
			dec a
			jr nz, .bit_loop
		.bit_loop_end:
		; and now is it a 1 or 0?
		ld a, d
		and $80
	pop hl
	ret