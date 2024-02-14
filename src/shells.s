; bullet shell

	; rb state
	; rw x
	; rw y
	; rw z
	; rw xspeed
	; rw yspeed
	; rw zspeed
	def sizeof_SHELL = 13

	def SHELL_BOUNCEABLE_ZSPEED = 2 ; 8-bit
	def SHELL_BOUNCE_UP_ZSPEED = -1 << 8
	def SHELL_STARTING_Z = -8 << 8
	def SHELL_STARTING_ZSPEED = -2 << 8
	def SHELL_TILE = $38

	rsreset
	def SHELL_STATE_EMPTY rb
	def SHELL_STATE_MOVING rb
	def SHELL_STATE_STILL rb

; params:
	; d - x px val
	; e - y px val
println {@}
shells_Create:
	push af
	ldh a, [shells_next_addr]
	ld l, a
	ld h, high(SHELLS)
	; state
		ld a, SHELL_STATE_MOVING
		ld [hl+], a
	; x
		ld a, d
		ld [hl+], a
		xor a
		ld [hl+], a
	; y
		ld a, e
		ld [hl+], a
		xor a
		ld [hl+], a
	; z
		ld a, high(SHELL_STARTING_Z)
		ld [hl+], a
		ld a, low(SHELL_STARTING_Z)
		ld [hl+], a
	; xspeed
		call comm_Rand
		ld b, a
		pop af
		jr c, :+
			; r
			ld a, $ff
			jr :++
		:
			xor a
			; l
		:
		ld [hl+], a
		ld a, b
		ld [hl+], a
	; yspeed
		xor a
		ld [hl+], a
		call comm_Rand
		ld [hl+], a
	; zspeed
		ld a, high(SHELL_STARTING_ZSPEED)
		ld [hl+], a
		ld a, low(SHELL_STARTING_ZSPEED)
		ld [hl+], a

	; increment shells_next_addr
		ldh a, [shells_next_addr]
		add 16
		jr nc, :+
			ld a, low(SHELLS) ; wrap around to first block
		:
		ldh [shells_next_addr], a
	ret

	def SHELL_BOUNCE_UP_SPD = -2
macro shell_Update
	; add xspeed to x
		ld16_h h, l, shell_x
		ld16_h b, c, shell_xspeed
		add hl, bc
		st16_h shell_x, h, l
	; add yspeed to y
		ld16_h h, l, shell_y
		ld16_h b, c, shell_yspeed
		add hl, bc
		st16_h shell_y, h, l
	; add GRAVITY to zspeed
		ld16_h h, l, shell_zspeed
		ld bc, GRAVITY
		add hl, bc
		st16_h shell_zspeed, h, l
	; add zspeed to z
		ld b, h
		ld c, l
		ld16_h h, l, shell_z
		add hl, bc
		st16_h shell_z, h, l
	; is z > 0?
		bit 7, h
		jr nz, .end\@
		; z = 0
		xor a
		ldh [shell_z], a
		ldh [shell_z+1], a
		; is zspeed >= 3?
			ldh a, [shell_zspeed]
			cp SHELL_BOUNCEABLE_ZSPEED
			jr c, .stop\@
			; (bounce):
				; zspeed = -SHELL_BOUNCE_UP_SPD
				ld hl, SHELL_BOUNCE_UP_ZSPEED
				st16_h shell_zspeed, h, l
				; xspeed /= 2 |
				ld16_h h, l, shell_xspeed
				sra h
				rr l
				st16_h shell_xspeed, h, l
				; yspeed /= 2 |- idk about these two
				ld16_h h, l, shell_yspeed
				sra h
				rr l
				st16_h shell_yspeed, h, l
				jr .end\@
		; else
			.stop\@:
				; (stop):
				; state = 2
				ld a, SHELL_STATE_STILL
				ldh [shell_state], a
	.end\@:
endm

macro shell_Draw
	ld16_h h, l, oam_free_addr
	; y
		ldh a, [scroll_y]
		ld b, a
		ldh a, [shell_z]
		ld c, a
		ldh a, [shell_y]
		sub b
		add c
		add 16
		ld [hl+], a
	; x
		ldh a, [scroll_x]
		ld b, a
		ldh a, [shell_x]
		sub b
		add 8
		ld [hl+], a
	; tile
		ld a, SHELL_TILE
		ld [hl+], a
	; attr
		xor a
		ld [hl+], a
	st16_h oam_free_addr, h, l
endm

shells_UpdateAll:
	ld hl, SHELLS
	.loop:
		; state = 0 if empty
			ld a, [hl+]
			and a
			ret z
		; state = 2 if not moving
			ld d, a
			cp 2
		; get all vars
			ldh [shell_state], a
			ld c, low(shell_x)
			ld b, sizeof_SHELL-1
			.get_vars_loop:
				ld a, [hl+]
				ld [c], a
				inc c
				djnz .get_vars_loop
			push hl
			ld a, d
			cp SHELL_STATE_STILL
			jp z, .draw
				shell_Update
			.draw:
				shell_Draw
			pop hl
			dec l
			ld c, low(shell_zspeed+1)
			ld b, sizeof_SHELL
			.store_vars_loop:
				ld a, [c]
				ld [hl-], a
				dec c
				djnz .store_vars_loop
		.next:
			ld a, l
			add 17 ; account for last [hl-]
			and %1111_0000
			ret z
			ld l, a
			jp .loop
	ret

shells_Draw:
	ret