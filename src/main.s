include "src/hardware.inc"

; c100.c1a0 = shadow OAM
def SHADOW_OAM	= $c100
; c200.c280 = invisible/inanimate objects
	; / 6 = 21 slots
def IOBJ		= $c200
; c2a0.c300 = bullet shells
	; / 16 = 6 slots
def SHELLS		= $c2a0

section "hram", hram
	rsset _HRAM+20 ; make room for DMA transfer code (run_dma) and local vars
	def LOCAL = _HRAM+10 ; 10 bytes for methods' local vars

	; misc
	def on_title rb
	def paused rb
	def lcdc rb
	def seed rw
	def oam_free_addr rw
	def white_flash_ctr rb
	def frame_ctr rb
	def sp_buff rw

	def mask_vram_addr rw
	def mask_vram_buff_addr rw
	
	; input
	def buttons_down rb ; DULRSsBA
	def buttons_pressed rb
	def buttons_released rb

	; screen
	def scroll_x rw
	def scroll_y rw

	; text box
	def txt_bools rb ; defined in text.s
	def txt_src_addr rw ; address to next char to be displayed
	def txt_vram_addr rw ; address to tile position on screen to write to
	def txtbox_y rb ; this is effectively rWY
	def txt_ctr rb ; multipurpose; action depends on bools
	def txt_char_tile rb ; tile index of the char to write to VRAM during vblank

	; player
	def plr_bools rb ; 00f0_000g | facing ←, on ground
	def plr_x rw ; byte 2 = fraction
	def plr_y rw ; byte 2 = fraction
	def plr_state rb
	def plr_state_prev rb
	def plr_frame rw ; byte 2 = fraction
	def plr_speed rb
	def plr_shoot_anim_ctr rb
	def plr_shoot_stop_ctr rb
	def plr_shoot_release_ctr rb
	def plr_elevation rw ; byte 2 = fraction
	def plr_vspeed rw ; byte 2 = fraction
	def plr_crouch_to_jump_ctr rb
	def plr_crouch_from_jump_ctr rb

	; effects
	def shell_state rb
	def shell_x rw ; byte 2 = fraction
	def shell_y rw ; byte 2 = fraction
	def shell_z rw ; byte 2 = fraction
	def shell_xspeed rw ; byte 2 = fraction
	def shell_yspeed rw ; byte 2 = fraction
	def shell_zspeed rw ; byte 2 = fraction
	def shells_next_addr rb ; low
	def dust_x rb
	def dust_y rb
	def dust_frame rb ; aaaaffff | actual frame, fraction

	; sound
	def snd_next_addr rw
	def snd_next_count rb
	def snd_noise_busy_ctr rb

	; print how much hram space is left
	def remaining_hram equ $ffff - _RS
	println "  remaining hram: {u:remaining_hram}"

section "wram", WRAM0
	rsset $c200

section "int_vblank", ROM0[INT_HANDLER_VBLANK]
	jp vblank

section "int_stat", ROM0[INT_HANDLER_STAT]
	jp stat

section "Header", ROM0[$100]
	jp start

	ds $150 - @, 0 ; Make room for the header

	include "src/macros.s"
	include "src/comm.s"
	include "src/input.s"
	include "src/text.s"
	include "src/sfx.s"
	include "src/screen.s"
	include "src/draw.s"
	include "src/plr.s"
	include "src/iobj.s"
	include "src/shells.s"
	include "src/test_room.s"
	include "src/title.s"
	include "src/pause.s"

	; hUGE driver
	include "src/music/hUGE_driver.s"
	include "src/music/hUGE_note_table.inc"

start:
	; Shut down audio circuitry
	xor a
	ldh [rNR52], a

	ld sp, $e000 ; get the stack out of hram
	
	; enable just vblank interrupt for now
	ld a, IEF_VBLANK
	ldh [rIE], a

	ld a, STATF_LYC
	ldh [rSTAT], a
	
	; clear HRAM
	ld b, $ffff - (_HRAM+10)
	ld hl, _HRAM+10
	xor a
	.clear_hram:
		ld [hl+], a
		djnz .clear_hram
	
	memcpy run_dma, _HRAM, run_dma_end - run_dma ; write DMA code to HRAM

	; Do not turn the LCD off outside of VBlank
	ei
	vbl
	di

	; Turn the LCD off
	xor a
	ldh [rLCDC], a

	memcpy tiles, $8000, tiles_end - tiles
	memset8 $a0a0, $9c00, 1024
	memset8 0, SHADOW_OAM, OAM_COUNT * sizeof_OAM_ATTRS
	memset8 0, SHELLS, $80

	; set palettes to all white
	xor a
	ldh [rBGP], a
	ldh [rOBP0], a
	ldh [rOBP1], a

	; text
	ldh [rWY], a ; 0 for title first
	ld a, SCRN_Y
	ldh [txtbox_y], a
	ld a, 7
	ldh [rWX], a

	; turn sound on
	ld a, AUDENA_ON
	ldh [rNR52], a
	ld a, $ff
	ldh [rNR51], a
	ldh [rNR50], a
	
	call title_Init
	; println {@}
	ld hl, on_title
	inc [hl]
	ld a, LCDCF_ON | LCDCF_BGON | LCDCF_WINON | LCDCF_BLK21 | LCDCF_WIN9C00
	ldh [rLCDC], a
	ei
	vbl
	call draw_FadeWhiteToPal
	call title_Update

	vbl
	di
	xor a
	ldh [rLCDC], a
	ldh [on_title], a
	iobj_Clear
	call plr_Init
	call test_room_Init
	ld hl, caves
	call hUGE_init
	ld a, low(SHELLS)
	ldh [shells_next_addr], a

	; enable interrupts
	ld a, IEF_VBLANK | IEF_STAT
	ldh [rIE], a

	; turn the LCD on
	ld a, LCDCF_ON | LCDCF_BGON | LCDCF_WINON | LCDCF_OBJON | LCDCF_OBJ16 | LCDCF_BLK21 | LCDCF_WIN9C00
	ldh [rLCDC], a
	ldh [lcdc], a
	
	ei
	call draw_FadeWhiteToPal

forever:
	ld hl, frame_ctr
	inc [hl]
	; inc seed
		ldh a, [seed+1]
		add 1
		ldh [seed+1], a
		ldh a, [seed]
		adc 0
		ldh [seed], a

	call GetInput

	if_nz_h paused, .no_pause
		ldh a, [buttons_pressed]
		and a
		jr z, :+
			call Unpause
		:
		jr .wai
	.no_pause:

	if_btn pressed, st
		call Pause
		jr .wai
	:

	; turn objs back on
	ldh a, [lcdc]
	or LCDCF_OBJON
	ldh [lcdc], a
	ldh [rLCDC], a

	st16_h mask_vram_addr, $8400
	st16_h mask_vram_buff_addr, MASK_VRAM_BUFF
	st16_h oam_free_addr, SHADOW_OAM
	memset8 0, MASK_VRAM_BUFF, 256
	memset8 0, SHADOW_OAM, OAM_COUNT * sizeof_OAM_ATTRS

	call scr_UpdateScroll
	call iobj_UpdateAll
	call shells_UpdateAll
	call plr_Update
	call txt_Update
	call snd_Update

	call plr_Draw
	call draw_Dust
	
	; wait for vblank interrupt
	.wai:
	vbl
	jp forever

vblank:
	di
	push_all

	ldh a, [on_title]
	and a
	jr nz, .end
	ldh a, [paused]
	and a
	jr nz, .end

	call _HRAM ; OAM DMA (draw sprites)
	call scr_DrawScroll

	; text
	call txt_DrawTxtbox

	; vram buffer
		ld hl, MASK_VRAM_BUFF
		ld de, $8400
		ld b, 4
		.vram_buff:
			rept 16
			ld a, [hl+]
			ld [de], a
			inc de
			endr
			ld a, e
			add 16
			ld e, a
			djnz .vram_buff

	.end:
	pop_all
	ccf ; let comm_WaitForVblank know who's the real slim shady (clear the carry flag)
	reti

stat:
	di
	push_all
	
	ldh a, [lcdc]
	and LCDCF_OBJON ^ $ff
	ldh [lcdc], a
	ldh [rLCDC], a

	pop_all
	reti

run_dma:
    ld a, high(SHADOW_OAM)
    ldh [rDMA], a  ; start DMA transfer (starts right after instruction)
    ld a, 40        ; delay for a total of 4×40 = 160 cycles
	.wait
		dec a           ; 1 cycle
		jr nz, .wait    ; 3 cycles
    ret
run_dma_end:
	; println {@}

section "Tile data", ROM0

tiles:
	incbin "bin/chr.bin"
tiles_end:

letter_a:
	incbin "bin/letter_a.bin"
letter_a_end:

mask_tiles:
	incbin "bin/masks.bin.half"
mask_tiles_end:

shadow_tiles:
	incbin "bin/shadows.bin.half"
shadow_tiles_end:

sng_caves:
	include "src/music/caves.s"

section "bartholomew", romx
bartholomew:
	incbin "bin/bartholomew.chr"
