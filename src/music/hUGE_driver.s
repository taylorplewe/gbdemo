include "src/music/hUGE.inc"

macro add_a_to_r16
    add low(\1)
    ld low(\1), a
    adc high(\1)
    sub low(\1)
    ld high(\1), a
endm

; thanks PinoBatch!
macro sub_from_r16 ; (high, low, value)
    ld a, \2
    sub \3
    ld \2, a
    sbc a  ; a = -1 if borrow or 0 if not
    add \1
    ld \1, a
endm

macro retMute
    bit \1, a
    ret nz
endm

macro checkMute
    ld a, [mute_channels]
    bit \1, a
    jr nz, \2
endm

; maximum pattern length
def PATTERN_LENGTH = 64

section "Playback variables", wram0[$c400]
; active song descriptor
order_cnt: db
_start_song_descriptor_pointers:
; pointers to the song's current four orders (one per channel)
order1: dw
order2: dw
order3: dw
order4: dw

; pointers to the instrument tables
duty_instruments: dw
wave_instruments: dw
noise_instruments: dw

; misc. pointers
routines: dw
waves: dw
_end_song_descriptor_pointers:

; pointers to the current patterns (sort of a cache)
pattern1: dw
pattern2: dw
pattern3: dw

; how long a row lasts in ticks (1 = one row per call to `hUGE_dosound`, etc. 0 translates to 256)
ticks_per_row: db

hUGE_current_wave:
; iD of the wave currently loaded into wave RAM
current_wave: db
def hUGE_NO_WAVE = 100
    EXPORT hUGE_NO_WAVE

; everything between this and `end_zero` is zero-initialized by `hUGE_init`
start_zero:

mute_channels: db

counter: db
tick: db
row_break: db
next_order: db
row: db
current_order: db

channels:
;;;;;;
;Channel 1
;;;;;;
channel1:
channel_period1: dw
toneporta_target1: dw
channel_note1: db
highmask1: db
vibrato_tremolo_phase1: db
envelope1: db
table1: dw
table_row1: db
ds 5

;;;;;;
;Channel 2
;;;;;;
channel2:
channel_period2: dw
toneporta_target2: dw
channel_note2: db
highmask2: db
vibrato_tremolo_phase2: db
envelope2: db
table2: dw
table_row2: db
ds 5

;;;;;;
;Channel 3
;;;;;;
channel3:
channel_period3: dw
toneporta_target3: dw
channel_note3: db
highmask3: db
vibrato_tremolo_phase3: db
envelope3: db
table3: dw
table_row3: db
ds 5

;;;;;;
;Channel 4
;;;;;;
channel4:
channel_period4: dw
toneporta_target4: dw
channel_note4: db
highmask4: db
step_width4: db
vibrato_tremolo_phase4: db
envelope4: db
table4: dw
table_row4: db
ds 4

end_zero:

section "Sound Driver", rom0

; sets up hUGEDriver to play a song.
; !!! BE SURE THAT `hUGE_dosound` WILL NOT BE CALLED WHILE THIS RUNS !!!
; param: HL = Pointer to the "song descriptor" you wish to load (typically exported by hUGETracker).
; destroys: AF C DE HL
hUGE_init:
    ld a, [hl+] ; tempo
    ld [ticks_per_row], a

    ld a, [hl+]
    ld e, a
    ld a, [hl+]
    ld d, a
    ld a, [de]
    ld [order_cnt], a

    ld c, _end_song_descriptor_pointers - (_start_song_descriptor_pointers)
    ld de, order1

    .copy_song_descriptor_loop:
        ld a, [hl+]
        ld [de], a
        inc de
        dec c
        jr nz, .copy_song_descriptor_loop

    ; zero some ram
    ld c, end_zero - start_zero
    ld hl, start_zero
    xor a
    .fill_loop:
        ld [hl+], a
        dec c
        jr nz, .fill_loop

    ; these two are zero-initialized by the loop above, so these two writes must come after
    ld a, %11110000
    ld [envelope1], a
    ld [envelope2], a

    ; force loading the next wave
    ld a, hUGE_NO_WAVE
    ld [current_wave], a

    ld c, 0
    ; fallthrough (load the pattern pointers)

; sets all 4 pattern pointers from a certain index in the respective 4 orders.
; param: C = The index (in increments of 2)
; destroy: AF DE HL
load_patterns:
    ld hl, order1
    ld de, pattern1
    call .load_pattern

    ld hl, order2
    call .load_pattern

    ld hl, order3
    ; call .load_pattern

    ; ld hl, order4
    ; fallthrough

    .load_pattern:
        ld a, [hl+]
        add c
        ld h, [hl]
        ld l, a
        adc h
        sub l
        ld h, a

        ld a, [hl+]
        ld [de], a
        inc de
        ld a, [hl]
        ld [de], a
        inc de
        ret


; reads a pattern's current row.
; param: BC = Pointer to the pattern
; param: [row] = Index of the current row
; return: A = Note ID
; return: B = Instrument (upper nibble) & effect code (lower nibble)
; return: C = Effect parameter
; destroy: HL
get_current_row:
    ld a, [row]
    .row_in_a:
    ld h, a
    ; multiply by 3 for the note value
    add h
    add h

    ld h, 0
    ld l, a
    add hl, bc ; hL now points at the 3rd byte of the note
    ld a, [hl+]
    ld b, [hl]
    inc hl
    ld c, [hl]
    ret

; gets the "period" of a pattern's current note.
; param: HL = Pointer to the pattern pointer
; param: [row] = Index of the current row
; param: DE = Location to write the note's index to, if applicable
; return: HL = Note's period
; return: CF = Set if and only if a "valid" note (i.e. not a "rest")
; return: [DE] = Note's ID, not updated if a "rest"
; return: B = Instrument (upper nibble) & effect code (lower nibble)
; return: C = Effect parameter
; destroy: AF
get_current_note:
    ld a, [hl+]
    ld c, a
    ld b, [hl]

    call get_current_row
    ld hl, 0

    ; if the note we found is greater than LAST_NOTE, then it's not a valid note
    ; and nothing needs to be updated.
    cp LAST_NOTE
    ret nc

    ; store the loaded note value in channel_noteX
    ld [de], a

; gets a note's "period", i.e. what should be written to NRx3 and NRx4.
; param: A = Note ID
; return: HL = Note's period
; return: CF = 1
; destroy: AF
get_note_period:
    add a ; double it to get index into hi/lo table
    add LOW(note_table)
    ld l, a
    adc HIGH(note_table)
    sub l
    ld h, a
    ld a, [hl+]
    ld h, [hl]
    ld l, a

    scf
    ret

; computes the pointer to a member of a channel.
; param: B = Which channel (0 = CH1, 1 = CH2, etc.)
; param: D = Offset within the channel struct
; return: HL = Pointer to the channel's member
; destroy: AF
ptr_to_channel_member:
    ld a, b
    swap a
    add d
    add LOW(channels)
    ld l, a
    adc HIGH(channels)
    sub l
    ld h, a
    ret


; tODO: Make this take HL instead of DE

; updates a channel's fr=ency, and possibly restarts it.
; note that CH4 is *never* restarted by this!
; param: B = Which channel to update (0 = CH1, 1 = CH2, etc.)
; param: (for CH4) E = Note ID
; param: (otherwise) DE = Note period
; destroy: AF C
; destroy: (for CH4) HL
update_channel_freq:
    ld h, 0
    .nonzero_highmask:
        ld c, b
        ld a, [mute_channels]
        dec c
        jr z, .update_channel2
        dec c
        jr z, .update_channel3

    .update_channel1:
        retMute 0

        ld a, e
        ld [channel_period1], a
        ldh [rAUD1LOW], a
        ld a, d
        ld [channel_period1+1], a
        or h
        ldh [rAUD1HIGH], a
        ret

    .update_channel2:
        retMute 1

        ld a, e
        ld [channel_period2], a
        ldh [rAUD2LOW], a
        ld a, d
        ld [channel_period2+1], a
        or h
        ldh [rAUD2HIGH], a
        ret

    .update_channel3:
        retMute 2

        ld a, e
        ld [channel_period3], a
        ldh [rAUD3LOW], a
        ld a, d
        ld [channel_period3+1], a
        or h
        ldh [rAUD3HIGH], a
        ret

play_note_routines:
    jr play_ch1_note
    jr play_ch2_note
    jr play_ch3_note
    ret

play_ch1_note:
    ld a, [mute_channels]
    retMute 0

    ; play a note on channel 1 (square wave)
    ld hl, channel_period1
    ld a, [hl+]
    ldh [rAUD1LOW], a

    ; get the highmask and apply it.
    ld a, [highmask1]
    or [hl]
    ldh [rAUD1HIGH], a
    ret

play_ch2_note:
    ld a, [mute_channels]
    retMute 1

    ; play a note on channel 2 (square wave)
    ld hl, channel_period2
    ld a, [hl+]
    ldh [rAUD2LOW], a

    ; get the highmask and apply it.
    ld a, [highmask2]
    or [hl]
    ldh [rAUD2HIGH], a
    ret

play_ch3_note:
    ld a, [mute_channels]
    retMute 2

    ; triggering CH3 while it's reading a byte corrupts wave RAM.
    ; to avoid this, we kill the wave channel (0 → NR30), then re-enable it.
    ; this way, CH3 will be paused when we trigger it by writing to NR34.
    ; tODO: what if `highmask3` bit 7 is not set, though?

    ldh a, [rAUDTERM]
    push af
    and %10111011
    ldh [rAUDTERM], a

    xor a
    ldh [rAUD3ENA], a
    cpl
    ldh [rAUD3ENA], a

    ; play a note on channel 3 (waveform)
    ld hl, channel_period3
    ld a, [hl+]
    ldh [rAUD3LOW], a

    ; get the highmask and apply it.
    ld a, [highmask3]
    or [hl]
    ldh [rAUD3HIGH], a

    pop af
    ldh [rAUDTERM], a

    ret

; executes a row of a table.
; param: BC = Pointer to which table to run
; param: [HL] = Which row the table is on
; param: E = Which channel to run the table on
do_table:
    ; increment the current row
    ld a, [hl]
    inc [hl]
    push hl

    ; grab the cell values, return if no note.
    ; save BC for doing effects.
    call get_current_row.row_in_a
    pop hl ; tODO: don't trash HL in the first place
    push bc

    ld d, a

    ; if there's a jump, change the current row
    ld a, b
    and $F0
    bit 7, d
    jr z, .no_steal
        res 7, d
        set 0, a
    .no_steal:
        swap a
        jr z, .no_jump
        dec a
        ld [hl], a

    .no_jump:
        ld a, d
        ; if there's no note, don't update channel fr=encies
        cp NO_NOTE
        jr z, .no_note2

    sub 36 ; bring the number back in the range of -36, +35

    ld b, e
    ld e, a
    ld d, 4
    call ptr_to_channel_member
    ld a, e
    add [hl]
    inc hl
    ld d, [hl]

    ; a = note index
    ; b = channel
    ; d = highmask
    ; pushed = instrument/effect

    ; if ch4, don't get note period (update_channel_freq gets the poly for us)
    ld e, a
    inc b
    bit 2, b
    ld c, d
    jr nz, .is_ch4

    call get_note_period
    ld d, h
    ld e, l
    .is_ch4:
        ld h, c
        res 7, h
        dec b
        call update_channel_freq.nonzero_highmask

    .no_note:
        ld e, b
    .no_note2:
        pop bc

    ld d, 1
    jr do_effect.no_set_offset

; performs an effect on a given channel.
; param: E = Channel ID (0 = CH1, 1 = CH2, etc.)
; param: B = Effect type (upper 4 bits ignored)
; param: C = Effect parameters (depend on FX type)
; destroy: AF BC DE HL
do_effect:
    ; return immediately if effect is 000
    ld d, 0
    .no_set_offset:
        ld a, b
        and $0F
        or c
        ret z

    ; strip the instrument bits off leaving only effect code
    ld a, b
    and $0F
    ; multiply by 2 to get offset into table
    add a

    add LOW(.jump)
    ld l, a
    adc HIGH(.jump)
    sub l
    ld h, a

    ld a, [hl+]
    ld h, [hl]
    ld l, a
    bit 0, d
    jr z, .no_offset
    inc hl
    .no_offset:
        ld b, e
        ld a, [tick]
        or a ; we can return right off the bat if it's tick zero
        jp hl

    .jump:
        ; jump table for effect
        dw 0                               ;0xy
        dw 0                               ;1xy
        dw 0                               ;2xy
        dw 0                               ;3xy
        dw 0                               ;4xy
        dw 0                               ;5xy ; global
        dw 0                               ;6xy
        dw 0                               ;7xy
        dw fx_set_pan                      ;8xy ; global
        dw 0                               ;9xy
        dw 0                               ;Axy
        dw fx_pos_jump                     ;Bxy ; global
        dw 0                               ;Cxy
        dw fx_pattern_break                ;Dxy ; global
        dw 0                               ;Exy
        dw 0                               ;Fxy ; global

; processes (global) effect 8, "set pan".
; param: B = Current channel ID (0 = CH1, 1 = CH2, etc.)
; param: C = Value to write to NR51
; param: ZF = Set if and only if on tick 0
; destroy: A
fx_set_pan:
    ret nz

    ; pretty simple. The editor can create the correct value here without a bunch
    ; of bit shifting manually.
    ld a, c
    ldh [rAUDTERM], a
    ret

update_ch3_waveform:
    ld [hl], a
    ; get pointer to new wave
    swap a
    ld hl, waves
    add [hl]
    inc hl
    ld h, [hl]
    ld l, a
    adc h
    sub l
    ld h, a

    ldh a, [rAUDTERM]
    push af
    and %10111011
    ldh [rAUDTERM], a

    xor a
    ldh [rAUD3ENA], a

for OFS, 16
    ld a, [hl+]
    ldh [_AUD3WAVERAM + OFS], a
endr

    ld a, %10000000
    ldh [rAUD3ENA], a

    pop af
    ldh [rAUDTERM], a

    ret

hUGE_set_position:
; processes (global) effect B, "position jump".
; param: C = ID of the order to jump to
; destroy: A
fx_pos_jump:
    ret nz

    ld hl, row_break

    or [hl] ; a = 0 since we know we're on tick 0
    jr nz, .already_broken
    ld [hl], 1
    .already_broken:
        inc hl
        ld [hl], c
        ret


; processes (global) effect D, "pattern break".
; param: C = ID of the next order's row to start on
; destroy: A
fx_pattern_break:
    ret nz

    ld a, c
    ld [row_break], a
    ret


; computes the pointer to an instrument.
; param: B = The instrument's ID
; param: HL = Instrument pointer table
; return: HL = Pointer to the instrument
; return: ZF = Set if and only if there was no instrument (ID == 0)
; destroy: AF
setup_instrument_pointer:
    ld a, b
    and %11110000
    swap a
    ret z ; if there's no instrument, then return early.

    dec a ; instrument 0 is "no instrument"
    .finish:
        ; multiply by 6
        add a
        ld e, a
        add a
        add e

        add_a_to_r16 hl

        rla ; reset the Z flag
        ret

; ticks the sound engine once.
; destroy: AF BC DE HL
hUGE_dosound:
    ld a, [tick]
    or a
    jp nz, process_effects

    ; note playback
    ld hl, pattern1
    ld de, channel_note1
    call get_current_note

    push af ; save carry for conditonally calling note
    jr nc, .do_setvol1

    ld a, b
    and $0F
    cp 3 ; if toneporta, don't load the channel period
    jr z, .toneporta
    ld a, l
    ld [channel_period1], a
    ld a, h
    ld [channel_period1+1], a
    .toneporta:

        ld hl, duty_instruments
        ld a, [hl+]
        ld h, [hl]
        ld l, a
        call setup_instrument_pointer
        ld a, [highmask1]
        res 7, a ; turn off the "initial" flag
        jr z, .write_mask1

        checkMute 0, .do_setvol1

        ld a, [hl+]
        ldh [rAUD1SWEEP], a
        ld a, [hl+]
        ldh [rAUD1LEN], a
        ld a, [hl+]
        ldh [rAUD1ENV], a
        ld a, [hl+]
        ld [table1], a
        ld a, [hl+]
        ld [table1+1], a
        xor a
        ld [table_row1], a

        ld a, [hl]

    .write_mask1:
        ld [highmask1], a

    .do_setvol1:
        ld e, 0
        call do_effect

        pop af
        call c, play_ch1_note

        ld a, [table1]
        ld c, a
        ld a, [table1+1]
        ld b, a
        or c
        ld hl, table_row1
        ld e, 0
        call nz, do_table

process_ch2:
    ; note playback
    ld hl, pattern2
    ld de, channel_note2
    call get_current_note

    push af ; save carry for conditonally calling note
    jr nc, .do_setvol2

    ld a, b
    and $0F
    cp 3 ; if toneporta, don't load the channel period
    jr z, .toneporta
    ld a, l
    ld [channel_period2], a
    ld a, h
    ld [channel_period2+1], a
    .toneporta:

        ld hl, duty_instruments
        ld a, [hl+]
        ld h, [hl]
        ld l, a
        call setup_instrument_pointer
        ld a, [highmask2]
        res 7, a ; turn off the "initial" flag
        jr z, .write_mask2

        checkMute 1, .do_setvol2

        inc hl

        ld a, [hl+]
        ldh [rAUD2LEN], a
        ld a, [hl+]
        ldh [rAUD2ENV], a
        ld a, [hl+]
        ld [table2], a
        ld a, [hl+]
        ld [table2+1], a
        xor a
        ld [table_row2], a

        ld a, [hl]

    .write_mask2:
        ld [highmask2], a

    .do_setvol2:
        ld e, 1
        call do_effect

        pop af
        call c, play_ch2_note

        ld a, [table2]
        ld c, a
        ld a, [table2+1]
        ld b, a
        or c
        ld hl, table_row2
        ld e, 1
        call nz, do_table

process_ch3:
    ld hl, pattern3
    ld de, channel_note3
    call get_current_note

    push af ; save carry for conditonally calling note
    jp nc, .do_setvol3

    ld a, b
    and $0F
    cp 3 ; if toneporta, don't load the channel period
    jr z, .toneporta
    ld a, l
    ld [channel_period3], a
    ld a, h
    ld [channel_period3+1], a
    .toneporta:

        ld hl, wave_instruments
        ld a, [hl+]
        ld h, [hl]
        ld l, a
        call setup_instrument_pointer
        ld a, [highmask3]
        res 7, a ; turn off the "initial" flag
        jr z, .write_mask3

        checkMute 2, .do_setvol3

        ld a, [hl+]
        ldh [rAUD3LEN], a
        ld a, [hl+]
        ldh [rAUD3LEVEL], a
        ld a, [hl+]
        push hl

        ; check to see if we need to copy the wave
        ld hl, current_wave
        cp [hl]
        jr z, .no_wave_copy
        call update_ch3_waveform

    .no_wave_copy:
        pop hl
        ld a, [hl+]
        ld [table3], a
        ld a, [hl+]
        ld [table3+1], a
        xor a
        ld [table_row3], a

        ld a, [hl]

    .write_mask3:
        ld [highmask3], a

    .do_setvol3:
        ld e, 2
        call do_effect

        pop af
        call c, play_ch3_note

        ld a, [table3]
        ld c, a
        ld a, [table3+1]
        ld b, a
        or c
        ld hl, table_row3
        ld e, 2
        call nz, do_table

        ; no ch4

        ; finally just update the tick/order/row values
        jp tick_time

process_effects:
    ; only do effects if not on tick zero
    checkMute 0, .after_effect1

    ld hl, pattern1
    ld a, [hl+]
    ld c, a
    ld b, [hl]
    call get_current_row

    ld a, c
    or a
    jr z, .after_effect1

    ld e, 0
    call do_effect      ; make sure we never return with ret_dont_play_note!!

    ; tODO: Deduplicate this code by moving it into do_table?
    .after_effect1:
        ld a, [table1]
        ld c, a
        ld a, [table1+1]
        ld b, a
        or c
        ld hl, table_row1
        ld e, 0
        call nz, do_table

    .process_ch2:
        checkMute 1, .after_effect2

        ld hl, pattern2
        ld a, [hl+]
        ld c, a
        ld b, [hl]
        call get_current_row

        ld a, c
        or a
        jr z, .after_effect2

        ld e, 1
        call do_effect      ; make sure we never return with ret_dont_play_note!!

    .after_effect2:
        ld a, [table2]
        ld c, a
        ld a, [table2+1]
        ld b, a
        or c
        ld hl, table_row2
        ld e, 1
        call nz, do_table

    .process_ch3:
        checkMute 2, .after_effect3

        ld hl, pattern3
        ld a, [hl+]
        ld c, a
        ld b, [hl]
        call get_current_row

        ld a, c
        or a
        jr z, .after_effect3

        ld e, 2
        call do_effect      ; make sure we never return with ret_dont_play_note!!

    .after_effect3:
        ld a, [table3]
        ld c, a
        ld a, [table3+1]
        ld b, a
        or c
        ld hl, table_row3
        ld e, 2
        call nz, do_table

    ; no ch4

tick_time:
    ld hl, counter
    inc [hl]

    assert counter + 1 == tick
    inc hl ; ld hl, tick
    inc [hl] ; increment tick counter

    ; should we switch to the next row?
    ld a, [ticks_per_row]
    sub [hl]
    ret nz ; nope.
    ld [hl+], a ; reset tick to 0
    ; below code relies on a == 0

    assert tick + 1 == row_break
    ; check if we need to perform a row break or pattern break
    or [hl] ; a == 0, so this is `ld a, [hl]` that also alters flags
    jr z, .no_break

    ; these are offset by one so we can check to see if they've
    ; been modified
    dec a
    ld b, a

    xor a
    ld [hl+], a
    assert row_break + 1 == next_order
    or [hl]     ; a = [next_order], zf = ([next_order] == 0)
    jr z, .neworder
    ld [hl], 0

    dec a
    add a ; multiply order by 2 (they are words)

    jr .update_current_order

    .no_break:
        ; increment row.
        ld a, [row]
        inc a
        cp PATTERN_LENGTH
        jr nz, .noreset

    ld b, 0
    .neworder:
        ; increment order and change loaded patterns
        ld a, [order_cnt]
        ld c, a
        ld a, [current_order]
        add 2
        cp c
        jr nz, .update_current_order
        xor a
    .update_current_order:
        ; call with:
        ; a: The order to load
        ; b: The row for the order to start on
        ld [current_order], a
        ld c, a
        call load_patterns

    ld a, b
    .noreset:
        ld [row], a
        ret

note_table:
include "src/music/hUGE_note_table.inc"
