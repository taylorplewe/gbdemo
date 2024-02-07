include "src/hardware.inc"

; c100.c1a0 = shadow OAM
def SHADOW_OAM	= $c100
; c200.c300 = invisible/inanimate objects
	; / 6 = 42 slots
def IOBJ		= $c200

section "hram", hram
	rsset _HRAM+20 ; make room for DMA transfer code (run_dma) and local vars
	def LOCAL = _HRAM+10 ; 10 bytes for methods' local vars

	; misc
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

	def dust_x rb 1
	def dust_y rb 1
	def dust_frame rb 1 ; aaaaffff | actual frame, fraction

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
	include "src/screen.s"
	include "src/draw.s"
	include "src/plr.s"
	include "src/iobj.s"
	include "src/test_room.s"

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
	call WaitForVblank
	di

	; Turn the LCD off
	xor a
	ldh [rLCDC], a

	memcpy tiles, $8000, tiles_end - tiles
	memcpy test_room_map, $9800, test_room_map_end - test_room_map
	memset8 $8080, $9c00, 1024

	def BG_PAL		= %11_10_01_00
	def OBJ1_PAL	= %11_10_00_00
	def OBJ2_PAL	= %11_10_01_00

	; set palettes
	ld a, BG_PAL
	ldh [rBGP], a
	ld a, OBJ1_PAL
	ldh [rOBP0], a
	ld a, OBJ2_PAL
	ldh [rOBP1], a

	; text
	ld a, SCRN_Y
	ldh [rWY], a
	ldh [txtbox_y], a
	ld a, 7
	ldh [rWX], a

	iobj_Clear
	call plr_Init
	call test_room_Init

	; enable all interrupts
	ld a, IEF_VBLANK | IEF_STAT
	ldh [rIE], a

	; turn the LCD on
	ld a, LCDCF_ON | LCDCF_BGON | LCDCF_WINON | LCDCF_OBJON | LCDCF_OBJ16 | LCDCF_BLK21 | LCDCF_WIN9C00
	ldh [rLCDC], a
	ldh [lcdc], a
	
	ei

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
	call plr_Update
	call txt_Update

	call plr_Draw
	call draw_Dust
	
	; wait for vblank interrupt
	call WaitForVblank
	jr forever

WaitForVblank:
	scf
	halt
	jr c, WaitForVblank
	ret

vblank:
	di
	push_all

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

	pop_all
	ccf ; let WaitForVBlank know who's the real slim shady (clear the carry flag)
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
	println {@}

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