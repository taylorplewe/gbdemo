macro invert_a
	cpl
	inc a
endm

macro djnz
	if _NARG == 1
		dec b
		jr nz, \1
	else
		dec \1
		jr nz, \2
	endc
endm

macro ld16_h
	ldh a, [\3]
	ld \1, a
	ldh a, [\3 + 1]
	ld \2, a
endm

macro st16_h
	if _NARG == 3
		ld a, \2
		ldh [\1], a
		ld a, \3
		ldh [\1 + 1], a
	else
		ld a, high(\2)
		ldh [\1], a
		ld a, low(\2)
		ldh [\1 + 1], a
	endc
endm

macro hl_goto_hl
	ld a, [hl+]
	ld h, [hl]
	ld l, a
endm

macro if_z_h
	ldh a, [\1]
	and a
	if _NARG == 1
		jr nz, :+
	else
		jr nz, \2
	endc
endm

macro if_nz_h
	ldh a, [\1]
	and a
	if _NARG == 1
		jr z, :+
	else
		jr z, \2
	endc
endm

macro if_bool_h
	ldh a, [\1]
	bit \2, a
	if _NARG == 2
		jr z, :+
	else
		\3
	endc
endm

macro memcpy
	ld hl, \1
	ld de, \2
	ld bc, \3
	call _memcpy
endm
_memcpy:
	ld a, [hl+]
	ld [de], a
	inc de
	dec bc
	ld a, b
	or c
	jr nz, _memcpy
	ret

macro memset8
	ld de, \1
	ld b, (\3)/8
	ld hl, sp-2
	st16_h sp_buff, h, l
	ld hl, (\2) + (\3)
	call _memset8
endm
_memset8:
	ld sp, hl
	.loop:
		push de
		push de
		push de
		push de
		djnz .loop
	ld16_h h, l, sp_buff
	ld sp, hl
	ret

def push_all equs "push af\npush bc\npush de\npush hl\n"
def pop_all equs "pop hl\npop de\npop bc\npop af\n"