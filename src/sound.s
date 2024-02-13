snd_Update:
	call hUGE_dosound
	if_nz_h snd_noise_busy_ctr
		dec a
		ldh [snd_noise_busy_ctr], a
	:
	ldh a, [snd_next_count]
	and a
	ret z
	; decrement count to next sound
	dec a
	ldh [snd_next_count], a
	ret nz
	; play next sound
	ld16_h h, l, snd_next_addr
	ld a, [snd_noise_busy_ctr]
	; jp snd_Play ; call
	; ret

; params:
	; hl - address of sound data to play
	; a - frames for noise channel should be busy for
snd_Play:
	ld b, a
	ldh a, [snd_noise_busy_ctr]
	cp b
	jr z, :+
	ret nc
	ld a, b
	ldh [snd_noise_busy_ctr], a
	:

	; initial channel reg
	ld c, [hl]
	inc hl

	; note data
	rept 4
	ld a, [hl+]
	ld [c], a
	inc c
	endr

	; vibrato
	ld a, [hl+]
	ldh [snd_noise_vibrato_xor], a

	; timer to next
	ld a, [hl+]
	and a
	ret z
	ldh [snd_next_count], a
	st16_h snd_next_addr, h, l
	ret

snd_footstep1:
       ;first reg  ;cutoff     ;volume/env  ;freq        ;trig/cut    ;vibrato xor ;frames til next
	db low(rNR41), %00_111000, %0010_0_000, %0011_0_001, %1_1_000000, 0,           0
snd_footstep2:
	db low(rNR41), %00_111000, %0010_0_000, %0011_0_011, %1_1_000000, 0,           0
snd_land:
	db low(rNR41), %00_110110, %1111_0_000, %0011_0_111, %1_1_000000, 0,           6
	db low(rNR41), %00_000000, %0111_0_001, %0011_0_111, %1_0_000000, 0,           0
snd_char:
	db low(rNR41), %00_111110, %0011_0_001, %0000_0_011, %1_1_000000, 0,           0
snd_shoot:
	db low(rNR41), %00_111000, %1111_0_000, %0011_0_011, %1_1_000000, 0,           6
	db low(rNR41), %00_000000, %1111_0_111, %1000_0_001, %1_0_000000, %0100_0_000, 0