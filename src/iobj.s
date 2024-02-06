	rsreset
	def IOBJ_TYPE rb 1
	def IOBJ_Y rb 1
	def IOBJ_X rb 1
	def IOBJ_SIZE rb 1 ; hhhhwwww
	def IOBJ_DATA rb 2 ; type-specific
	def sizeof_IOBJ = _RS
	
	rsset 1
	def IOBJ_TYPE_SIGNPOST rb 1

	def iobj_Clear equs "memset8 0, IOBJ, 256"

iobj_UpdateAll:
	ld hl, IOBJ
	ld de, sizeof_IOBJ
	xor a
	ld b, a
	.loop:
		ld c, [hl] ; get iobj type
		; end?
			cp c
			ret z
		; get update vector and go there
			push_all
			ld d, l ; d is now index into IOBJ
			sla c
			ld hl, iobj_update_vectors
			add hl, bc
			hl_goto_hl
			call iobj_GotoVector
			pop_all
		; next
			add hl, de
			jr .loop

iobj_update_vectors:
	dw 0, signpost_Update

; kinda stupid that I have to do this but here we are
iobj_GotoVector:
	jp hl

	include "src/signpost.s"