; bools
	def SIGNPOST_BOOL_BUBBLE		= %0000_0001
	def signpost_bool_test_bubble	equs "bit 0, a"
	def signpost_bool_set_bubble	equs "ldh a, [signpost_bools]\nset 0, a\nldh [signpost_bools], a"
	def signpost_bool_clear_bubble	equs "ldh a, [signpost_bools]\nres 0, a\nldh [signpost_bools], a"
	def SIGNPOST_BOOL_ACTIVE		= %0000_0010
	def signpost_bool_test_active	equs "bit 1, a"
	def signpost_bool_set_active	equs "ldh a, [signpost_bools]\nset 1, a\nldh [signpost_bools], a"
	def signpost_bool_clear_active	equs "ldh a, [signpost_bools]\nres 1, a\nldh [signpost_bools], a"

def BUBBLE_TILE_1 = $60
def BUBBLE_TILE_2 = $62

; careful with these
rsset LOCAL
def signpost_y rb 1
def signpost_x rb 1
def signpost_text_addr rb 2
def signpost_bools rb 1

def SIGNPOST_WIDTH = 16
def SIGNPOST_HEIGHT = 16

; params:
	; d - index into IOBJ array
signpost_Update:
	ld h, high(IOBJ)
	ld l, d
	inc hl

	; the gameboy processor is retarded and I don't have any index registers.
	; my solution is just to increment hl itself and copy all the obj's vals into temp vals
	; y
		ld a, [hl+]
		ldh [signpost_y], a
	; x
		ld a, [hl+]
		ldh [signpost_x], a
	; width and height
		inc hl
	; addr
		ld a, [hl+]
		sla a
		push hl
		ld hl, txt_signposts
		ld b, 0
		ld c, a
		add hl, bc
		hl_goto_hl
		st16_h signpost_text_addr, h, l
		pop hl
	; bools
		ld a, [hl]
		ldh [signpost_bools], a
		push hl
		; don't show bubble if textbos is open
		ldh a, [txtbox_y]
		cp SCRN_Y
		jr nc, :+
			signpost_bool_clear_bubble
		:

	ldh a, [signpost_bools]
	signpost_bool_test_bubble
	jr z, :+
		call signpost_DisplayBubble
		if_btn pressed, a
			signpost_bool_set_active
			ld16_h h, l, signpost_text_addr
			call txt_DisplayTextbox
			; no other A action can happen this frame (manually release button)
				ldh a, [buttons_pressed]
				and PADF_A ^ $ff
				ldh [buttons_pressed], a
	:

	; player nearby?
	ldh a, [plr_y]
	ld h, a
	ldh a, [plr_x]
	ld l, a
		def PLR_BUBBLE_DIST = 4
		; u
			ldh a, [signpost_y]
			sub PLR_HEIGHT + PLR_BUBBLE_DIST
			cp h
			jr nc, .no
		; d
			add 8 + PLR_BUBBLE_DIST*2 + PLR_HEIGHT
			cp h
			jr c, .no
		; l
			ldh a, [signpost_x]
			sub PLR_WIDTH + PLR_BUBBLE_DIST
			cp l
			jr nc, .no
		; r
			add SIGNPOST_WIDTH + PLR_BUBBLE_DIST*2 + PLR_WIDTH
			cp l
			jr c, .no
	; yes:
		signpost_bool_set_bubble
		jr .detect_plr_pos_end
	.no:
		signpost_bool_clear_bubble

	; player far enough away to close bubble?
		def PLR_BUBBLE_CLOSE_DIST = 12
		; u
			ldh a, [signpost_y]
			sub PLR_HEIGHT + PLR_BUBBLE_CLOSE_DIST
			cp h
			jr nc, .too_far
		; d
			add 8 + PLR_BUBBLE_CLOSE_DIST*2 + PLR_HEIGHT
			cp h
			jr c, .too_far
		; l
			ldh a, [signpost_x]
			sub PLR_WIDTH + PLR_BUBBLE_CLOSE_DIST
			cp l
			jr nc, .too_far
		; r
			add SIGNPOST_WIDTH + PLR_BUBBLE_CLOSE_DIST*2 + PLR_WIDTH
			cp l
			jr c, .detect_plr_pos_end
	.too_far:
		ldh a, [signpost_bools]
		signpost_bool_test_active
		call nz, txt_HideTextbox
		signpost_bool_clear_active
	.detect_plr_pos_end:
	ldh a, [signpost_bools]
	pop hl
	ld [hl], a

	ret

signpost_DisplayBubble:
	; de = next free space in OAM shadow ram
	; hl = that +4
		ld16_h h, l, oam_free_addr
		ld d, h
		ld e, l
		ld bc, 4
		add hl, bc
	; y
		; bob every 16 frames
			ldh a, [frame_ctr]
			swap a
			and 1
			ld c, a
		ldh a, [scroll_y]
		ld b, a
		ldh a, [signpost_y]
		sub b
		; sub 16
		add c ; bob anim
		add 4
		ld [de], a
		inc de
		ld [hl+], a
	; x
		ldh a, [scroll_x]
		ld b, a
		ldh a, [signpost_x]
		sub b
		add 8
		ld [de], a
		inc de
		add 8
		ld [hl+], a
	; tile
		ld a, BUBBLE_TILE_1
		ld [de], a
		inc de
		ld a, BUBBLE_TILE_2
		ld [hl+], a
	; attr
		xor a
		ld [de], a
		ld [hl+], a
	st16_h oam_free_addr, h, l
	ret