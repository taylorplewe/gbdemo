include "src/hardware.inc"

; c100.c1a0 = shadow OAM
def SHADOW_OAM	= $c100
; c200.c280 = invisible/inanimate objects
	; / 6 = 21 slots
def IOBJ		= $c200
; c280.c300 = bullet shells
	; / 16 = 8 slots
def SHELLS		= $c280

section "hram", hram
	rsset _HRAM+20 ; make room for DMA transfer code (run_dma) and local vars
	def LOCAL = _HRAM+10 ; 10 bytes for methods' local vars

	; misc
	def on_title rb 1
	def lcdc rb 1
	def oam_free_addr rb 2
	def white_flash_ctr rb 1
	def frame_ctr rb 1
	def sp_buff rw 1

	def mask_vram_addr rb 2
	def mask_vram_buff_addr rb 2
	
	; input
	def buttons_down rb 1 ; DULRSsBA
	def buttons_pressed rb 1
	def buttons_released rb 1

	; screen
	def scroll_x rb 2
	def scroll_y rb 2

	; text box
	def txt_bools rb 1 ; defined in text.s
	def txt_src_addr rb 2 ; address to next char to be displayed
	def txt_vram_addr rb 2 ; address to tile position on screen to write to
	def txtbox_y rb 1 ; this is effectively rWY
	def txt_ctr rb 1 ; multipurpose; action depends on bools
	def txt_char_tile rb 1 ; tile index of the char to write to VRAM during vblank

	; player
	def plr_bools rb 1 ; 00f0_000g | facing ←, on ground
	def plr_x rb 2 ; byte 2 = fraction
	def plr_y rb 2 ; byte 2 = fraction
	def plr_state rb 1
	def plr_state_prev rb 1
	def plr_frame rb 2 ; byte 2 = fraction
	def plr_speed rb 1
	def plr_shoot_anim_ctr rb 1
	def plr_shoot_stop_ctr rb 1
	def plr_shoot_release_ctr rb 1
	def plr_elevation rb 2 ; byte 2 = fraction
	def plr_vspeed rb 2 ; byte 2 = fraction
	def plr_crouch_to_jump_ctr rb 1
	def plr_crouch_from_jump_ctr rb 1

	; effects
	def shell_x rw 1 ; byte 2 = fraction
	def shell_y rw 1 ; byte 2 = fraction
	def shell_z rw 1 ; byte 2 = fraction
	def shell_xspeed rw 1 ; byte 2 = fraction
	def shell_yspeed rw 1 ; byte 2 = fraction
	def shell_zspeed rw 1 ; byte 2 = fraction
	def dust_x rb 1
	def dust_y rb 1
	def dust_frame rb 1 ; aaaaffff | actual frame, fraction

	; sound
	def snd_next_addr rw 1
	def snd_next_count rb 1
	def snd_noise_busy_ctr rb 1

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
	include "src/sound.s"
	include "src/screen.s"
	include "src/draw.s"
	include "src/plr.s"
	include "src/iobj.s"
	include "src/shells.s"
	include "src/test_room.s"
	include "src/title.s"

	; hUGE tracker/driver
	include "huge-driver/driver.s"
	include "huge-driver/hUGE_note_table.inc"

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
	call draw_FadeToPal
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

	; enable interrupts
	ld a, IEF_VBLANK | IEF_STAT
	ldh [rIE], a

	; turn the LCD on
	ld a, LCDCF_ON | LCDCF_BGON | LCDCF_WINON | LCDCF_OBJON | LCDCF_OBJ16 | LCDCF_BLK21 | LCDCF_WIN9C00
	ldh [rLCDC], a
	ldh [lcdc], a
	
	ei
	call draw_FadeToPal

forever:
	ld hl, frame_ctr
	inc [hl]

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

	call GetInput

	call scr_UpdateScroll
	call iobj_UpdateAll
	call shells_UpdateAll
	call plr_Update
	call txt_Update
	call snd_Update

	call plr_Draw
	call draw_Dust
	
	; wait for vblank interrupt
	vbl
	jr forever

vblank:
	di
	push_all

	ldh a, [on_title]
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
	include "caves.s"