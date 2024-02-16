; idk which one of these I want
; txt_title_allcaps: db "TAYLOR PLEWE"
; txt_title_alllower: db "taylor plewe"
txt_title_titlecase: db "Taylor Plewe"
txt_title_titlecase_dark: db $db,$dc,$dd,$de,$df,$e0,$a0,$fb,$de,$fc,$fd,$fc
def TITLE_TEXT_VRAM_ADDR = $9d24

title_Init:
	ld hl, txt_title_titlecase_dark
	ld de, TITLE_TEXT_VRAM_ADDR
	ld b, 12
	.draw_letters_loop:
		ld a, [hl+]
		; convert_ascii_to_tile
		ld [de], a
		inc de
		djnz .draw_letters_loop
	ret

def NUM_SHINY_LETTERS = 3
title_Update:
	ld b, 46
	call .wait

	; shine
	ld b, 12 + NUM_SHINY_LETTERS
	ld c, 1
	ld hl, txt_title_titlecase
	ld de, TITLE_TEXT_VRAM_ADDR
	.shine_loop:
		vbl
		push_all

		; shine
		rept NUM_SHINY_LETTERS
		ld a, [hl-]
		convert_ascii_to_tile
		ld [de], a
		ld a, 12
		cp c
		jr c, :+
			dec de
		:
		dec c
		jr z, .shine_loop_next
		endr

		; dark letter behind the 3 shiny ones
		ld bc, 12
		add hl, bc
		ld a, [hl]
		ld [de], a

		.shine_loop_next:
		pop_all
		inc hl
		inc c
		ld a, 12
		cp c
		jr c, :+
			inc de
		:
		djnz .shine_loop

	ld b, 30
	call .wait

	jp draw_FadeToWhite

	.wait:
		vbl
		djnz .wait
	ret