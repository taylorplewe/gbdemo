; button test macros
; params
;	\1 - register to test on
	macro buttons_test_d
		bit 7, \1
	endm
	macro buttons_test_u
		bit 6, \1
	endm
	macro buttons_test_l
		bit 5, \1
	endm
	macro buttons_test_r
		bit 4, \1
	endm
	macro buttons_test_st
		bit 3, \1
	endm
	macro buttons_test_se
		bit 2, \1
	endm
	macro buttons_test_b
		bit 1, \1
	endm
	macro buttons_test_a
		bit 0, \1
	endm
; button test macros end

	macro if_btn
		ldh a, [buttons_\1]
		buttons_test_\2 a
		if _NARG == 2
			jr z, :+
		else
			jr z, \3
		endc
	endm

GetInput:
	; get dpad
		ld a, P1F_GET_DPAD ; select dpad
		call GetLowerNibble
		swap a
		and $f0
		ld b, a
	; get action buttons
		ld a, P1F_GET_BTN ; select action
		call GetLowerNibble
		and $0f
		or b
	xor $ff ; flip bits so 1 = button is pressed
	; calc buttons_pressed
		ld b, a
		ldh a, [buttons_down]
		 ld c, a
		xor b
		 ld d, a
		and b
		ldh [buttons_pressed], a
		ld a, d
		and c
		ldh [buttons_released], a

	ld a, b
	ldh [buttons_down], a
	; release keys?
		ld a, P1F_GET_NONE
		ldh [rP1], a
	ret

GetLowerNibble:
	ldh [rP1], a
	; NOTE: commented out all the following "burn" lines and it works fine?
	; nop ; wait a few cycles for the P1 register to update
	; ld a, [rP1] ; read
	; ld a, [rP1] ; read
	ldh a, [rP1] ; read
	ret