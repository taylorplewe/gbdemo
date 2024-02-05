def WHITE_FLASH_CTR_AMT = 5 ; minus 1 = number of frames that will be all white
comm_WhiteFlash:
	ld a, WHITE_FLASH_CTR_AMT
	ldh [white_flash_ctr], a
	ret

; call during vblank
comm_WhiteFlashDraw:
	ldh a, [white_flash_ctr]
	cp 0
	ret z
	ld b, a
	cp WHITE_FLASH_CTR_AMT - 2
	jr nz, :+
		ld a, %00000000
		ldh [rBGP], a
		ld a, %00000000
		ldh [rOBP0], a
	:
	ld a, b
	dec a
	ldh [white_flash_ctr], a
	ret nz
	.back_to_norm:
		ld a, %11100100
		ldh [rBGP], a
		ld a, %11100000
		ldh [rOBP0], a
		ret