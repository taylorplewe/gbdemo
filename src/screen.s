def MAX_SCROLL_X equ SCRN_VX - SCRN_X
def MAX_SCROLL_Y equ SCRN_VY - SCRN_Y

scr_UpdateScroll:
	; d = targ_y
	; e = targ_x

	; calc target pos
		; x
			ldh a, [plr_x]
			sub (SCRN_X/2) - (PLR_WIDTH/2)
			jr nc, :+
				xor a
			:
			cp MAX_SCROLL_X
			jr c, :+
				ld a, MAX_SCROLL_X
			:
			ld e, a
		; y
			ldh a, [plr_y]
			sub (SCRN_Y/2) - (PLR_HEIGHT/2)
			jr nc, :+
				xor a
			:
			cp MAX_SCROLL_Y
			jr c, :+
				ld a, MAX_SCROLL_Y
			:
			ld d, a
	; use those targ pos's to set scroll
		; y
			ldh a, [scroll_y]
			ld b, a
			ld a, d
			sub b
				ld c, low(scroll_y+1)
				call .shrink_and_add_scroll_diff
		; x
			ldh a, [scroll_x]
			ld b, a
			ld a, e
			sub b
				ld c, low(scroll_x+1)
		; 		call .shrink_and_add_scroll_diff
		; ret

	; params:
		; a - diff to divide
		; hl - scroll_?+1
	.shrink_and_add_scroll_diff:
		ld h, a
		ld l, 0
		; smooth motion
			rept 5
			sra h
			rr l
			endr
		; add 16-bit scroll
			ld a, [c]
			add l
			ld [c], a
			dec c
			ld a, [c]
			adc h
			ld [c], a
		ret

scr_DrawScroll:
	ldh a, [scroll_x]
	ldh [rSCX], a
	ldh a, [scroll_y]
	ldh [rSCY], a
	ret