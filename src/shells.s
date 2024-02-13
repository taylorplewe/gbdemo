; bullet shell

	; rw x
	; rw y
	; rw z
	; rw xspeed
	; rw yspeed
	; rw zspeed
	def sizeof_SHELL = 12

; params:
	; a - y px val
	; b - x px val
shells_Create:
	ret

	def SHELL_BOUNCE_UP_SPD = -2
macro shell_Update
	; add xspeed to x
	; add yspeed to y
	; add GRAVITY to zspeed
	; add zspeed to z
	; is z > 0?
		; z = 0
		; is zspeed >= 3?
			; (bounce):
			; zspeed = -SHELL_BOUNCE_UP_SPD
			; xspeed /= 2 |
			; yspeed /= 2 |- idk about these two
		; else
			; (stop):
			; state = 2
endm

shells_UpdateAll:
	ld hl, SHELLS
	.loop:
		; state = 0 if empty
			ld a, [hl+]
			and a
			ret z
		; state = 2 if not moving
			cp 2
			jp z, .next
		; get all vars
			ld c, low(shell_x)
			ld b, sizeof_SHELL
			.fill_vars_loop:
				ld a, [hl+]
				ld [c], a
				inc c
				djnz .fill_vars_loop
			push hl
			shell_Update
			pop hl
		.next:
			ld a, l
			add 16
			and %1111_0000
			ld l, a
			jr .loop
	ret

	def SHELL_TILE = $38
shells_Draw:
	ret