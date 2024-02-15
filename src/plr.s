	; plr_bools
		def PLR_BOOLS_FACING_L	= %00100000 ; same as OAMF_XFLIP
		def PLR_BITN_FACING_L	= 5
		def if_plr_facing_l		equs "if_bool_h plr_bools, 5"
		def plr_clear_facing_l	equs "ldh a, [plr_bools]\nres 5, a\nldh [plr_bools], a"
		def plr_set_facing_l	equs "ldh a, [plr_bools]\nset 5, a\nldh [plr_bools], a"
		def PLR_BOOLS_GROUND	= %00000001
		def PLR_BITN_GROUND		= 0
		def if_plr_ground		equs "if_bool_h plr_bools, 0"
		def plr_clear_ground	equs "ldh a, [plr_bools]\nres 0, a\nldh [plr_bools], a"
		def plr_set_ground		equs "ldh a, [plr_bools]\nset 0, a\nldh [plr_bools], a"
		macro plr_bools_test_ground
			ldh a, [plr_bools]
			bit 0, a
		endm
	; plr_x
	; plr_y
	; plr_state
		rsreset
		def PLR_STATE_IDLE rb 1
		def PLR_STATE_WALK rb 1
		def PLR_STATE_RUN rb 1
		def PLR_STATE_SHOOT rb 1
		def PLR_STATE_SHOOT_KICK rb 1
		def PLR_STATE_JUMP rb 1
		def PLR_STATE_FALL rb 1
		def PLR_STATE_CROUCH rb 1

def PLR_WIDTH = 16
def PLR_HEIGHT = 16
def PLR_SHOOT_RELEASE_CTR_RUN_AMT = 8
def PLR_SHOOT_KICK_FRAMES = 8
def PLR_CROUCH_TO_JUMP_CTR_AMT = 4
def PLR_CROUCH_FROM_JUMP_CTR_AMT = 12

macro plr_JumpCheck
	if_btn pressed, a
		ldh a, [txt_bools]
		and TXT_BOOLS_ARROW | TXT_BOOLS_END
		jr nz, :+
		if_plr_ground
		; start little crouching anim ctr
			ld a, PLR_CROUCH_TO_JUMP_CTR_AMT
			ldh [plr_crouch_to_jump_ctr], a
			ld a, PLR_STATE_CROUCH
			ldh [plr_state], a
	:
endm
macro plr_Fall
	ldh a, [plr_bools]
	bit PLR_BITN_GROUND, a
	jr nz, .end\@
	; falling faster than terminal velocity?
		ldh a, [plr_vspeed]
		bit 7, a
		jr nz, :+ ; vspeed is negative so no
			cp high(PLR_TERM_VELO)
			jr c, :+
			ld a, [plr_vspeed+1]
			cp low(PLR_TERM_VELO)
			jr c, :+
			; yes, set vspeed to terminal velocity and do not increase vspeed
			st16_h plr_vspeed, PLR_TERM_VELO
			jr .elev\@
		:
	; increase vertical speed by GRAVITY
			ldh a, [plr_vspeed+1]
			add low(GRAVITY)
			ldh [plr_vspeed+1], a
			ld l, a
			ldh a, [plr_vspeed]
			adc high(GRAVITY)
			ldh [plr_vspeed], a
			ld h, a
		; positive? set state to fall
		bit 7, a
		jr nz, .elev\@
		ld a, PLR_STATE_FALL
		ldh [plr_state], a
	.elev\@:
		ldh a, [plr_elevation+1]
		add l
		ldh [plr_elevation+1], a
		ldh a, [plr_elevation]
		adc h
		ldh [plr_elevation], a
	; landed?
		bit 7, a
		jr nz, .end\@
		; yes
		jp plr_Ground
	.end\@:
endm
macro plr_Shoot
	if_btn released, b
	if_nz_h plr_shoot_release_ctr
		; shoot
		ld a, PLR_STATE_SHOOT_KICK
		ldh [plr_state], a
		ld a, SHOOT_CTR_AMT
		ldh [plr_shoot_anim_ctr], a
		ld a, SHOOT_STOP_CTR_AMT
		ldh [plr_shoot_stop_ctr], a
		ld a, 100
		ld hl, snd_shoot
		call snd_Play
		call comm_WhiteFlash
		; shell effect
		ldh a, [plr_y]
		add 15
		ld e, a
		ldh a, [plr_elevation]
		ld b, a
		ldh a, [plr_x]
		ld d, a
		ldh a, [plr_bools]
		bit 5, a ; facing l (i know this is horrible but it's giving me a hard time)
		jr z, .shell_r
			ld a, d
			add 9
			scf
			jr .shell_create
		.shell_r:
			ld a, d
			add 3
			scf
			ccf
		.shell_create:
		ld d, a
		call shells_Create
	:
endm

plr_Init:
	plr_set_ground
	ret

plr_Update:
	if_nz_h plr_shoot_stop_ctr
		dec a
		ldh [plr_shoot_stop_ctr], a
		jr .mv_end
	:
	
	if_nz_h plr_crouch_to_jump_ctr
		dec a
		ldh [plr_crouch_to_jump_ctr], a
		jr nz, .mv_end
		call plr_Jump
		jr .mv_end
	:
	
	if_nz_h plr_crouch_from_jump_ctr
		dec a
		ldh [plr_crouch_from_jump_ctr], a
		jr .mv
	:

	; initial state = idle
	if_z_h plr_shoot_anim_ctr
	if_plr_ground
		ld a, PLR_STATE_IDLE
		ldh [plr_state], a
	:

	.mv:
	call plr_Move

	; set state to run possibly
	ldh a, [plr_state]
	cp PLR_STATE_WALK
	jr nz, :+
	if_btn down, b
		ldh a, [plr_shoot_release_ctr]
		cp PLR_SHOOT_RELEASE_CTR_RUN_AMT
		jr nc, :+
		ld a, PLR_STATE_RUN
		ldh [plr_state], a
	:

	.mv_end:
	
	plr_Shoot
	plr_Fall
	plr_JumpCheck
	
	; shooting
	if_nz_h plr_shoot_anim_ctr
		dec a
		ldh [plr_shoot_anim_ctr], a
		jr nz, :+
			ld a, PLR_STATE_IDLE
			ldh [plr_state], a
			jr :++
		:
		cp SHOOT_CTR_AMT - PLR_SHOOT_KICK_FRAMES
		jr nz, :+
			ld a, PLR_STATE_SHOOT
				ldh [plr_state], a
	:

	; if animation changed this frame, zero the frame #
	ldh a, [plr_state_prev]
	ld b, a
	ldh a, [plr_state]
	cp b
	ret z
		ldh [plr_state_prev], a
		xor a
		ldh [plr_frame], a
		ldh [plr_frame+1], a
	ret

def PLR_RIGHT_LEEWAY = 4
def PLR_LEFT_LEEWAY = PLR_RIGHT_LEEWAY - 3
def WALK_SPEED = $0081
def RUN_SPEED = $0101
def plr_shoot_release_ctr_AMT = 12
plr_Move:
	rsset LOCAL
	def plr_Move_running rb 1

	macro plr_Move_mv
		ld bc, \1
		ld de, \2
		call .mv
	endm

	; possibly start run ctr
	if_btn pressed, b
		ld a, plr_shoot_release_ctr_AMT
		ldh [plr_shoot_release_ctr], a
	:

	; check input
	ldh a, [buttons_down]
	; running?
		ld c, 0
		ld b, a
		buttons_test_b b
		jr z, :++
			if_nz_h plr_shoot_release_ctr
				dec a
				ldh [plr_shoot_release_ctr], a
			:
			ldh a, [plr_shoot_release_ctr]
			cp PLR_SHOOT_RELEASE_CTR_RUN_AMT
			jr nc, :+
				inc c
		:
	ld a, c
	ldh [plr_Move_running], a
	
	; u
		buttons_test_u b
		jr z, .d
			push bc
			plr_Move_mv plr_y, -WALK_SPEED
			jr nc, :+
			; TL
				ldh a, [plr_x]
				add PLR_LEFT_LEEWAY
				ld c, a
				ld a, h
				add 8
				ld e, a
				call comm_CheckWall
			jr nz, :+
			; TR
				ldh a, [plr_x]
				add 15 - PLR_RIGHT_LEEWAY
				ld c, a
				ld a, h
				add 8
				ld e, a
				call comm_CheckWall
			jr nz, :+
				st16_h plr_y, h, l
			:
			pop bc
			jr .l
	.d:
		buttons_test_d b
		jr z, .l
			push bc
			plr_Move_mv plr_y, WALK_SPEED
			ld a, PLR_HEIGHT
			add h
			jr c, :+
			; BL
				ldh a, [plr_x]
				add PLR_LEFT_LEEWAY
				ld c, a
				ld a, h
				add 15
				ld e, a
				call comm_CheckWall
			jr nz, :+
			; BR
				ldh a, [plr_x]
				add 15 - PLR_RIGHT_LEEWAY
				ld c, a
				ld a, h
				add 15
				ld e, a
				call comm_CheckWall
			jr nz, :+
				ld a, h
				ldh [plr_y], a
				ld a, l
				ldh [plr_y+1], a
			:
			pop bc
	.l:
		ld hl, scroll_x
		buttons_test_l b
		jr z, .r
			plr_set_facing_l
			plr_Move_mv plr_x, -WALK_SPEED
			ret nc
			; TL
				ldh a, [plr_y]
				add 8
				ld e, a
				ld a, h
				add PLR_LEFT_LEEWAY
				ld c, a
				call comm_CheckWall
			jr nz, :+
			; BL
				ldh a, [plr_y]
				add 15
				ld e, a
				ld a, h
				add PLR_LEFT_LEEWAY
				ld c, a
				call comm_CheckWall
			ret nz
				st16_h plr_x, h, l
				ret
	.r:
		buttons_test_r b
		ret z
			; plr_Move_mv plr_x, WALK_SPEED
			plr_clear_facing_l
			plr_Move_mv plr_x, WALK_SPEED
			ld a, PLR_WIDTH
			add h
			ret c
			; TR
				ldh a, [plr_y]
				add 8
				ld e, a
				ld a, h
				add 15 - PLR_RIGHT_LEEWAY
				ld c, a
				call comm_CheckWall
			ret nz
			; BR
				ldh a, [plr_y]
				add 15
				ld e, a
				ld a, h
				add 15 - PLR_RIGHT_LEEWAY
				ld c, a
				call comm_CheckWall
			ret nz
				st16_h plr_x, h, l
	; params:
		; bc - addr of plr pos var to be affected
		; de - walk speed, pos or neg
	; returns:
		; carry - 1 if hitting border, 0 if free
		; h - new pos for plr pos var passed in by bc
	.mv:
		if_plr_ground
		if_z_h plr_crouch_from_jump_ctr
			ld a, PLR_STATE_WALK
			ldh [plr_state], a
		:
		; cancel the shoot anim
			xor a
			ldh [plr_shoot_anim_ctr], a
		; [bc] += de
			; [bc] -> hl
				ld a, [bc]
				ld h, a
				inc bc
				ld a, [bc]
				ld l, a
			; de
				if_nz_h plr_Move_running, :++
					bit 7, d ; negative walk speed?
					jr nz, :+
						ld d, high(RUN_SPEED)
						ld e, low(RUN_SPEED)
						jr :++
					:
						ld d, high(RUN_SPEED * -1)
						ld e, low(RUN_SPEED * -1)
				:
			add hl, de
			; h = target collision check line, -- or |
				; (where plr_x or plr_y would be set to)
		ret

def SHOOT_CTR_AMT = 64
def SHOOT_STOP_CTR_AMT = 16

def PLR_JUMP_VSPEED = -$0400
def PLR_TERM_VELO	= $0400
def GRAVITY			= $0040
plr_Jump:
	; set vspeed to PLR_JUMP_VSPEED
		ld a, high(PLR_JUMP_VSPEED)
		ldh [plr_vspeed], a
		ld a, low(PLR_JUMP_VSPEED)
		ldh [plr_vspeed+1], a
	; update bool and state
		plr_clear_ground
		ld a, PLR_STATE_JUMP
		ldh [plr_state], a
	ret

plr_Ground:
	xor a
	ldh [plr_elevation], a
	ldh [plr_elevation+1], a
	ldh [plr_vspeed], a
	ldh [plr_vspeed+1], a
	plr_set_ground
	; crouch anim
		ld a, PLR_STATE_CROUCH
		ldh [plr_state], a
		ld a, PLR_CROUCH_FROM_JUMP_CTR_AMT
		ldh [plr_crouch_from_jump_ctr], a
	; land sound
		xor a
		ld hl, snd_land
		call snd_Play
	; dust anim
		ldh a, [plr_y]
		add 8 + 16
		ld b, a
		ld c, -3
		if_plr_facing_l
			ld c, -1
		:
		ldh a, [plr_x]
		add 8
		add c
		jp draw_CreateDust ; call
	; ret

plr_Draw:
	rsset LOCAL
	def plr_Draw_anim_spd rb 1
	; e - # tiles per frame

	; go to animation data (.anim:)
		ld hl, plr_tiles
		ldh a, [plr_state]
		sla a ; x2
		ld b, 0
		ld c, a
		add hl, bc
		hl_goto_hl
	; go to frame data (.anim_0:)
		ld a, [hl+]
		ldh [plr_Draw_anim_spd], a
		ld a, [hl+] ; # frames in this anim
		push af
		;ld b, 0
		ldh a, [plr_frame]
		sla a
		ld c, a
		add hl, bc
		hl_goto_hl
	ld16_h b, c, oam_free_addr
	; # tiles in this frame
		ld a, [hl+]
		ld e, a
		ld a, [hl]
	.tile_loop:
		; Y
			ld a, [hl+]
			ld d, a
			ldh a, [plr_y]
			add 16
			add d
			ld [bc], a
			; scroll offset
				ldh a, [scroll_y]
				ld d, a
				ld a, [bc]
				sub d
				ld [bc], a
			; elevation offset
				ldh a, [plr_elevation]
				ld d, a
				ld a, [bc]
				add d
				ld [bc], a
			inc bc
		; X
			ld a, [hl+]
			ld d, a
				; facing L? invert
				if_plr_facing_l
					ld a, d
					sub PLR_WIDTH-11
					invert_a
					ld d, a
				:
			ldh a, [plr_x]
			add 8
			add d
			ld [bc], a
			; scroll offset
				ldh a, [scroll_x]
				ld d, a
				ld a, [bc]
				sub d
				ld [bc], a
			inc bc
		; tile
			ld a, [hl+]
			ld [bc], a
			inc bc
		; attr
			ld a, [hl+]
			ld d, a
			ldh a, [plr_bools] ; facing L?
			xor d
			ld [bc], a
			inc bc
		dec e
		jr nz, .tile_loop
	st16_h oam_free_addr, b, c
	call plr_DrawShadow ; hl is now conveniently pointing at the shadow data
	; update plr_frame
		ld b, 0 ; whether anim frame advanced this frame
		ldh a, [plr_Draw_anim_spd]
		ld l, a
		ldh a, [plr_frame+1]
		add l
		ldh [plr_frame+1], a
		jr nc, :+
			ldh a, [plr_frame]
			inc a
			ldh [plr_frame], a
			inc b
		:
		ld l, a
	; mod plr_frame by # of frames in the anim
		pop af ; get # frames
		cp l
		jr nz, :+
			; ret nc
			; ret
			; jr nc, plr_DrawJumpShadow
		; :
			xor a
			ldh [plr_frame], a
			ld l, a
	:
	ld a, b
	and a
	ret z

; some animations come with sounds e.g. footsteps
plr_AdvanceFrameAndPlaySound:
	; play sound?
	ldh a, [plr_state]
	cp PLR_STATE_WALK
	jr nz, .run
		ld a, l ; frame #
		and a
		jr nz, :+
			; footstep1
			xor a
			ld hl, snd_footstep1
			jp snd_Play
		:
		cp 2
		ret nz
			; footstep2
			xor a
			ld hl, snd_footstep2
			jp snd_Play
	.run:
	cp PLR_STATE_RUN
	ret nz
		ld a, l
		cp 1
		jr nz, :+
			; footstep1
			xor a
			ld hl, snd_footstep1
			jp snd_Play
		:
		cp 4
		ret nz
			; footstep2
			xor a
			ld hl, snd_footstep2
			jp snd_Play

; params:
	; hl - pointer to shadow data for current frame
plr_DrawShadow:
	rsset LOCAL+1 ; plr_Draw
	def plr_DrawShadow_shadow_tiles_ind rb 2
	def plr_DrawShadow_x rb 1
	def plr_DrawShadow_y rb 1

	hl_goto_hl
	if_plr_facing_l
		inc hl
		inc hl
		inc hl ; go to L facing data
	:

	; save tile data index and OAM tile
	ld a, [hl+]
	ldh [plr_DrawShadow_shadow_tiles_ind+1], a
	ld a, [hl+]
	ldh [plr_DrawShadow_shadow_tiles_ind], a
	; we can now clobber hl
	
	; save y and x for later use
		; x
			ld a, [hl]
			ld e, a
			ldh a, [plr_x]
			add e
			ld e, a
			ldh a, [scroll_x]
			ld c, a
			ldh a, [plr_elevation]
			sra a ; /2
			ld l, a
			ld a, e
			sub l
			ld e, a ; draw_Mask param
			add OAM_X_OFS
			sub c
			ldh [plr_DrawShadow_x], a
		; y
			ldh a, [scroll_y]
			ld l, a
			ldh a, [plr_y]
			add PLR_HEIGHT
			ld d, a
			ldh a, [plr_elevation]
			sra a ; /2
			ld b, a
			ld a, d
			sub b
			ld d, a ; draw_Mask param
			add OAM_Y_OFS
			sub l
			ldh [plr_DrawShadow_y], a

	; for each tile in the two tiles:
		; call draw_Mask with the appropriate X and Y params (4 total)
		; go to tile data with plr_DrawShadow_shadow_tiles_ind as the index to shadow_tiles
		; buffer to vram
		; buffer OAM tile

	; first mask
		; y
			ld b, a
		; x
			ldh a, [plr_DrawShadow_x]
			ld c, a
		push bc
		push de
		call draw_Mask
	; first shadow
		; go to tile data address
			ld hl, shadow_tiles
			ld16_h d, e, plr_DrawShadow_shadow_tiles_ind
			add hl, de
			ld16_h d, e, mask_vram_buff_addr
		; write the 8 data bytes with 8 0's
			ld b, 8
			.buff_loop_1:
				; 0
					xor a
					ld [de], a
					inc de
				; data
					ld a, [hl+]
					ld [de], a
					inc de
				djnz .buff_loop_1
			st16_h mask_vram_buff_addr, d, e
		; set OAM sprite to that tile you just created
			ld16_h h, l, oam_free_addr
			; y
				ldh a, [plr_DrawShadow_y]
				ld [hl+], a
			; x
				ldh a, [plr_DrawShadow_x]
				ld [hl+], a
			; tile
				ld a, $42
				ld [hl+], a
			; attr
				xor a
				ld [hl+], a

			st16_h oam_free_addr, h, l

	; second mask
		pop de
		pop bc
		ld a, c
		add 8
		ld c, a
		ld a, e
		add 8
		ld e, a
		call draw_Mask
	; second shadow
		; go to tile data address
			ld hl, shadow_tiles
			ld16_h d, e, plr_DrawShadow_shadow_tiles_ind
			add hl, de
			ld de, 8
			add hl, de
			ld16_h d, e, mask_vram_buff_addr
		; write the 8 data bytes with 8 0's
			ld b, 8
			.buff_loop_2:
				; 0
					xor a
					ld [de], a
					inc de
				; data
					ld a, [hl+]
					ld [de], a
					inc de
				djnz .buff_loop_2
			st16_h mask_vram_buff_addr, d, e
		; set OAM sprite to that tile you just created
			ld16_h h, l, oam_free_addr
			; y
				ldh a, [plr_DrawShadow_y]
				ld [hl+], a
			; x
				ldh a, [plr_DrawShadow_x]
				add 8
				ld [hl+], a
			; tile
				ld a, $46
				ld [hl+], a
			; attr
				xor a
				ld [hl+], a

			st16_h oam_free_addr, h, l
	ret

; tile indeces
	;.stand:
	;	db $18					anim speed
	;	db 1					# of frames in this animation
	;	dw .stand_0				addresses to each frame
	;	.stand_0:
	;		db 2				# of 8x16 tiles in this frame
	;		db 0, 0, $40, 0		Y offset, X offset, tile index, attributes
	;		db 0, 8, $41, 0		''
plr_tiles:
	; by state
	dw .stand, .walk, .run, .shoot, .shoot_kick, .jump, .fall, .crouch

	.stand:
		db 0
		db (.stand_ - @) / 2
		dw .stand_0
		.stand_:
		.stand_0:
			db (.stand_0_ - @) / 4
			db 0, 0, $00, 0
			db 0, 8, $02, 0
			.stand_0_:
			dw .stand_0_sh
	.walk:
		db $18
		db (.walk_ - @) / 2
		dw .walk_0, .stand_0, .walk_2, .stand_0
		.walk_:
		.walk_0:
			db (.walk_0_ - @) / 4
			db 0, 0, $04, 0
			db 0, 8, $06, 0
			.walk_0_:
			dw .walk_0_sh
		.walk_2:
			db (.walk_2_ - @) / 4
			db 0, 0, $08, 0
			db 0, 8, $0a, 0
			.walk_2_:
			dw .walk_2_sh
	.run:
		db $28
		db (.run_ - @) / 2
		dw .run_0, .run_1, .run_2, .run_3, .run_4, .run_5
		.run_:
		.run_0:
			db (.run_0_ - @) / 4
			db 0, 0, $0c, 0
			db 0, 8, $0e, 0
			.run_0_:
			dw .run_0_sh
		.run_1:
			db (.run_1_ - @) / 4
			db 0, 0, $10, 0
			db 0, 8, $12, 0
			.run_1_:
			dw .run_1_sh
		.run_2:
			db (.run_2_ - @) / 4
			db 0, 0, $14, 0
			db 0, 8, $16, 0
			.run_2_:
			dw .run_2_sh
		.run_3:
			db (.run_3_ - @) / 4
			db 0, 0, $18, 0
			db 0, 8, $1a, 0
			.run_3_:
			dw .run_3_sh
		.run_4:
			db (.run_4_ - @) / 4
			db 0, 0, $1c, 0
			db 0, 8, $1e, 0
			.run_4_:
			dw .run_4_sh
		.run_5:
			db (.run_5_ - @) / 4
			db 0, 0, $20, 0
			db 0, 8, $22, 0
			.run_5_:
			dw .run_5_sh
	.shoot:
		db 0
		db (.shoot_ - @) / 2
		dw .shoot_0
		.shoot_:
		.shoot_0:
			db (.shoot_0_ - @) / 4
			db 0, 0, $24, 0
			db 0, 8, $26, 0
			.shoot_0_:
			dw .shoot_0_sh
	.shoot_kick:
		db 0
		db (.shoot_kick_ - @) / 2
		dw .shoot_kick_0
		.shoot_kick_:
		.shoot_kick_0:
			db (.shoot_kick_0_ - @) / 4
			db 0, 0, $34, 0
			db 0, 8, $36, 0
			.shoot_kick_0_:
			dw .shoot_kick_0_sh
	.jump:
		db 0
		db (.jump_ - @) / 2
		dw .jump_0
		.jump_:
		.jump_0:
			db (.jump_0_ - @) / 4
			db 0, 0, $28, 0
			db 0, 8, $2a, 0
			.jump_0_:
			dw .jump_0_sh
	.fall:
		db 0
		db (.fall_ - @) / 2
		dw .fall_0
		.fall_:
		.fall_0:
			db (.fall_0_ - @) / 4
			db 0, 0, $2c, 0
			db 0, 8, $2e, 0
			.fall_0_:
			dw .fall_0_sh
	.crouch:
		db 0
		db (.crouch_ - @) / 2
		dw .crouch_0
		.crouch_:
		.crouch_0:
			db (.crouch_0_ - @) / 4
			db 0, 0, $30, 0
			db 0, 8, $32, 0
			.crouch_0_:
			dw .crouch_0_sh
; shadows
	; stand
		.stand_0_sh:
			dw $0168
			db 3
			dw $01e8
			db 1
	; walk
		.walk_0_sh:
			dw $0158
			db 2
			dw $01d8
			db 1
		.walk_2_sh:
			dw $0148
			db 2
			dw $01c8
			db 1
	; run
		.run_0_sh:
			dw $0008	; tile data index (shadows.bin.half) (8px per tile)
			db 0		; x offset from plr_x
			dw $0088	; L facing tile data index
			db 2		; L facing x offset from plr_x
		.run_1_sh:
			dw $0018
			db 0
			dw $0098
			db 2
		.run_2_sh:
			dw $0028
			db 0
			dw $00a8
			db 2
		.run_3_sh:
			dw $0038
			db 0
			dw $00b8
			db 2
		.run_4_sh:
			dw $0048
			db 0
			dw $00c8
			db 2
		.run_5_sh:
			dw $0058
			db 0
			dw $00d8
			db 2
	; shoot
		.shoot_0_sh:
			dw $0138
			db 2
			dw $01b8
			db 3
	; shoot_kick
		.shoot_kick_0_sh:
			dw $00e8
			db 2
			dw $0068
			db 3
	; jump
		.jump_0_sh:
			dw $128
			db 2
			dw $1a8
			db 1
	; fall
		.fall_0_sh:
			dw $0118
			db 2
			dw $0198
			db 1
	; crouch
		.crouch_0_sh:
			dw $0108
			db 2
			dw $0188
			db 0