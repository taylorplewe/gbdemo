macro dn ;; (note, instr, effect)
    db (\1 | ((\2 & %00010000) << 3))
    db (((\2 << 4) & $FF) | (\3 >> 8))
    db LOW(\3)
endm

def C_3 = 0
def C#3 = 1
def D_3 = 2
def D#3 = 3
def E_3 = 4
def F_3 = 5
def F#3 = 6
def G_3 = 7
def G#3 = 8
def A_3 = 9
def A#3 = 10
def B_3 = 11
def C_4 = 12
def C#4 = 13
def D_4 = 14
def D#4 = 15
def E_4 = 16
def F_4 = 17
def F#4 = 18
def G_4 = 19
def G#4 = 20
def A_4 = 21
def A#4 = 22
def B_4 = 23
def C_5 = 24
def C#5 = 25
def D_5 = 26
def D#5 = 27
def E_5 = 28
def F_5 = 29
def F#5 = 30
def G_5 = 31
def G#5 = 32
def A_5 = 33
def A#5 = 34
def B_5 = 35
def C_6 = 36
def C#6 = 37
def D_6 = 38
def D#6 = 39
def E_6 = 40
def F_6 = 41
def F#6 = 42
def G_6 = 43
def G#6 = 44
def A_6 = 45
def A#6 = 46
def B_6 = 47
def C_7 = 48
def C#7 = 49
def D_7 = 50
def D#7 = 51
def E_7 = 52
def F_7 = 53
def F#7 = 54
def G_7 = 55
def G#7 = 56
def A_7 = 57
def A#7 = 58
def B_7 = 59
def C_8 = 60
def C#8 = 61
def D_8 = 62
def D#8 = 63
def E_8 = 64
def F_8 = 65
def F#8 = 66
def G_8 = 67
def G#8 = 68
def A_8 = 69
def A#8 = 70
def B_8 = 71
def LAST_NOTE = 72
def ___ = 90 ; the default "no note" value
def NO_NOTE = ___