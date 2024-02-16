; bools
	def TXT_BOOLS_DOWN		= %0000_0001
	def TXT_BOOLS_PRINTCHR	= %0000_0010
	def TXT_BOOLS_PREPCHR	= %0000_0100
	def TXT_BOOLS_ARROW		= %0000_1000
	def TXT_BOOLS_CLEAR		= %0001_0000
	def TXT_BOOLS_END		= %0010_0000
	def TXT_BITN_DOWN		= 0
	def TXT_BITN_PRINTCHR	= 1
	def TXT_BITN_PREPCHR	= 2
	def TXT_BITN_ARROW		= 3
	def TXT_BITN_CLEAR		= 4
	def TXT_BITN_END		= 5
	def if_txt_down			equs "if_bool_h txt_bools, 0"
	def if_txt_printchr 	equs "if_bool_h txt_bools, 1"
	def if_txt_prepchr		equs "if_bool_h txt_bools, 2"
	def if_txt_arrow		equs "if_bool_h txt_bools, 3"
	def if_txt_clear		equs "if_bool_h txt_bools, 4"
	def if_txt_end			equs "if_bool_h txt_bools, 5"
	def txt_clr_down		equs "ldh a, [txt_bools]\nres 0, a\nldh [txt_bools], a"
	def txt_clr_printchr	equs "ldh a, [txt_bools]\nres 1, a\nldh [txt_bools], a"
	def txt_clr_prepchr		equs "ldh a, [txt_bools]\nres 2, a\nldh [txt_bools], a"
	def txt_clr_arrow		equs "ldh a, [txt_bools]\nres 3, a\nldh [txt_bools], a"
	def txt_clr_clear		equs "ldh a, [txt_bools]\nres 4, a\nldh [txt_bools], a"
	def txt_clr_end			equs "ldh a, [txt_bools]\nres 5, a\nldh [txt_bools], a"
	def txt_set_down		equs "ldh a, [txt_bools]\nset 0, a\nldh [txt_bools], a"
	def txt_set_printchr	equs "ldh a, [txt_bools]\nset 1, a\nldh [txt_bools], a"
	def txt_set_prepchr		equs "ldh a, [txt_bools]\nset 2, a\nldh [txt_bools], a"
	def txt_set_arrow		equs "ldh a, [txt_bools]\nset 3, a\nldh [txt_bools], a"
	def txt_set_clear		equs "ldh a, [txt_bools]\nset 4, a\nldh [txt_bools], a"
	def txt_set_end			equs "ldh a, [txt_bools]\nset 5, a\nldh [txt_bools], a"
;

	def TXT_LINE1_VRAM_ADDR = $9c21
	def TXT_LINE2_VRAM_ADDR = $9c61
	def txt_vram_addr_set_line1 equs "st16_h txt_vram_addr, high(TXT_LINE1_VRAM_ADDR), low(TXT_LINE1_VRAM_ADDR)"
	def txt_vram_addr_set_line2 equs "st16_h txt_vram_addr, high(TXT_LINE2_VRAM_ADDR), low(TXT_LINE2_VRAM_ADDR)"

	def ascii_to_tile_offs = 128
	def convert_ascii_to_tile equs "add {ascii_to_tile_offs}"

	def TXTBOX_SLIDE_SPD = 4
	def TXTBOX_MIN_Y = SCRN_Y - 40
	def TXTBOX_FIRST_CHAR_WAIT = 32
	def TXTBOX_CHAR_WAIT = 2
	def TXTBOX_PAUSE_WAIT = 32
	def TXTBOX_ANIM_WAIT = 20

	def TXT_ARROW_DOWN_TILE = $a5
	def TXT_ARROW_UP_TILE = $a6
	def TXT_END_TILE = $aa

txt_Update:
	; counter
	if_nz_h txt_ctr
		dec a
		ldh [txt_ctr], a
	:

	call txt_UpdateTxtboxPos
	call txt_UpdateArrow
	call txt_UpdateEnd
	call txt_PrepChar

	ret

txt_signposts:
	dw benji, dawg
	
benji:
	; db "this is 18 letters"
	db "Voyager 1, _o\ncosmic voyager, >embarked year of\nour Lord _1977, >journeyed\nvast... >unveiled Jupiter,\nSaturn, beyond. >Signals still\ndance, >a testament to\nits wonder >romance with the\nstars... ", 0
dawg:
	db "Press A to jump_\nPress B to shoot >Hold B to run >(This sign cost us\n$2,000) ", 0

txt_UpdateTxtboxPos:
	; is textbox moving?
	ldh a, [txtbox_y]
	ld b, a
	cp SCRN_Y
	ret z
	cp TXTBOX_MIN_Y
	ret z
	; yes
	if_txt_down
		ld a, b
		add TXTBOX_SLIDE_SPD
		ldh [txtbox_y], a
		ret
	: ; else
		ld a, b
		sub TXTBOX_SLIDE_SPD
		ldh [txtbox_y], a
		ret

txt_UpdateEnd:
	if_txt_end, ret z
	; press A?
	if_btn pressed, a
		jp txt_HideTextbox
	:
	ldh a, [txt_ctr]
	and a
	ret nz
	; alternate
	ldh a, [txt_char_tile]
	cp TXT_END_TILE
	jr nz, :+
		ld a, " " + ascii_to_tile_offs
		jr :++
	:
		ld a, TXT_END_TILE
	:
	ldh [txt_char_tile], a
	jr txt_AnimAdvance
txt_UpdateArrow:
	if_txt_arrow, ret z
	; press A?
	if_btn pressed, a
		; new page
			txt_set_prepchr
			ld a, TXTBOX_CHAR_WAIT
			ldh [txt_ctr], a
		jr txt_PrepClear
	:
	ldh a, [txt_ctr]
	and a
	ret nz
	; change to other frame
	; NOTE: this is a shortcut and needs to be updated if the arrow tile indeces change!!!!
	ldh a, [txt_char_tile]
	xor %11 ; 5 to 6, 6 to 5
	ldh [txt_char_tile], a
txt_AnimAdvance:
	; counter
		ld a, TXTBOX_ANIM_WAIT
		ldh [txt_ctr], a
	txt_set_printchr
	ret
txt_PrepClear:
	; no more arrow, yes clear
		ldh a, [txt_bools]
		set TXT_BITN_CLEAR, a
		and (TXT_BOOLS_ARROW | TXT_BOOLS_END) ^ $ff
		ldh [txt_bools], a
	; vram
		st16_h txt_vram_addr, TXT_LINE1_VRAM_ADDR
	ret

txt_PrepChar:
	if_txt_prepchr, ret z
	ldh a, [txt_ctr]
	and a ; set flags on a
	ret nz
	ld b, TXTBOX_CHAR_WAIT ; amount of frames to wait befor the char after this
	; get the character currently pointed to by txt_src_addr
		ld16_h h, l, txt_src_addr
		ld a, [hl+]
		ld c, a
		st16_h txt_src_addr, h, l
		ld a, c ; get char back
	; special char?
		; pause
			cp "_"
			jr nz, :+
				ld b, TXTBOX_PAUSE_WAIT
				jr .prep_for_next
			:
		; 0 (end of string)
			and a
			jr nz, :+
				; don't wait for next char, end on
					ldh a, [txt_bools]
					set TXT_BITN_END, a
					res TXT_BITN_PREPCHR, a
					ldh [txt_bools], a
				ld b, TXTBOX_ANIM_WAIT ; start anim
				ld a, TXT_END_TILE
				jr .to_print
			:
		; \n (newline)
			cp "\n"
			jr nz, :+
				txt_vram_addr_set_line2
				inc hl
				jr txt_PrepChar
			:
		; > (more text, show arrow)
			cp ">"
			jr nz, :+
				; don't wait for next char, arrow on
					ldh a, [txt_bools]
					set TXT_BITN_ARROW, a
					res TXT_BITN_PREPCHR, a
					ldh [txt_bools], a
				ld b, TXTBOX_ANIM_WAIT ; start anim
				ld a, TXT_ARROW_UP_TILE
				jr .to_print
			:
	; tell vblank to write this char
	convert_ascii_to_tile
	; regular character, play sound
	push_all
	xor a
	ld hl, snd_char
	call snd_Play
	pop_all
	.to_print:
		ldh [txt_char_tile], a
		txt_set_printchr
	.prep_for_next:
	; reset counter
		ld a, b
		ldh [txt_ctr], a
	ret
; params:
	; hl - pointer to first char of text to be displayed
txt_DisplayTextbox:
	; set src
		st16_h txt_src_addr, h, l
	txt_vram_addr_set_line1
	; prep first char
		ld a, TXTBOX_FIRST_CHAR_WAIT
		ldh [txt_ctr], a
	; update state
		ldh a, [txt_bools]
		set TXT_BITN_PREPCHR, a
		res TXT_BITN_DOWN, a
		ldh [txt_bools], a
	; do first move
		ldh a, [txtbox_y]
		sub TXTBOX_SLIDE_SPD
		ldh [txtbox_y], a
	ret
txt_HideTextbox:
	ldh a, [txtbox_y]
	cp TXTBOX_MIN_Y
	ret nz
	call txt_PrepClear
	; set state accordingly
		ldh a, [txt_bools]
		set TXT_BITN_DOWN, a
		res TXT_BITN_PREPCHR, a
		ldh [txt_bools], a
	ldh a, [txtbox_y]
	add TXTBOX_SLIDE_SPD
	ldh [txtbox_y], a
	ret
txt_DrawTxtbox:
	ldh a, [txtbox_y]
	ldh [rWY], a
	ldh [rLYC], a

	; print char
	ldh a, [txt_bools]
	bit TXT_BITN_PRINTCHR, a
	jr z, .clear
	ld16_h h, l, txt_vram_addr	; get vram addr
	ldh a, [txt_char_tile]		; get tile
	ld [hl+], a					; write tile to vram
	; don't update vram addr if animated icon (arrow, square)
	if_txt_prepchr
		st16_h txt_vram_addr, h, l
	:
	txt_clr_printchr

	.clear:
	; if_txt_clear
		ldh a, [txt_bools]
		bit TXT_BITN_CLEAR, a
		ret z
	; txt_clr_clear
		res TXT_BITN_CLEAR, a
		ldh [txt_bools], a
	ld16_h h, l, txt_vram_addr
	.clr_loop_prep:
	ld a, " " + ascii_to_tile_offs
	ld b, SCRN_X_B - 2
	.clr_loop:
		ld [hl+], a
		djnz .clr_loop
	ld a, low(TXT_LINE2_VRAM_ADDR)
	cp l
	ret z ; =
	ret c ; <
	ld l, low(TXT_LINE2_VRAM_ADDR)
	jr .clr_loop_prep