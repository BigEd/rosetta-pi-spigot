;for pasmo assembler
;it is for CP/M 2.2 for Tiki-100 KM/M and Amstrad CPC6128
;it uses Tiki-100 timer or Amstrad CPC firmware
;it calculates pi-number using the next C-algorithm
;https://crypto.stanford.edu/pbc/notes/pi/code.html

;#include <stdio.h>
;#define N 2800
;main() {
;   long r[N + 1], i, k, b, c;
;   c = 0;
;   for (i = 0; i < N; i++)
;      r[i] = 2000;
;   for (k = N; k > 0; k -= 14) {
;      d = 0;
;      i = k;
;      for(;;) {
;         d += r[i]*10000;
;         b = i*2 - 1;
;         r[i] = d%b;
;         d /= b;
;         i--;
;         if (i == 0) break;
;         d *= i;
;      }
;      printf("%.4d", (int)(c + d/10000));
;      c = d%10000;
;   }
;}

;the time of the calculation is quadratic, so if T is the time to calculate N digits
;then 4*T is required to calculate 2*N digits

BIOS_OUTPUT equ 1
TIKI100 equ 0
AMSTRADCPC equ 1

if TIKI100 + AMSTRADCPC > 1
show ERROR
endif

;Tiki-100
TIKI100_TIMER_LO equ $FF8C
TIKI100_TIMER_HI equ $FF8E
;Amstrad CPC
ENTER_FIRMWARE equ $BE9B
KL_TIME_PLEASE equ $BD0D

BDOS equ 5

;N equ 3500   ;1000 digits
;N equ 2800  ;800 digits
N equ 8500/2*7   ;8500 digits

div macro
     local t1,t2
     sla e
     rl d
     ADC   HL, HL
     jr c,t1

     LD    A,L
     ADD   A,C
     LD    A,H
     ADC   A,B
     JR    NC,t2
t1
     ADD   HL,BC
     INC   E
t2
endm

divz macro
	adc a,a
 adc hl,hl
 add hl,bc
 jr c, $+4
 sbc hl,bc
endm

divx macro
	ld a,d
	add a,a
 adc hl,hl
 add hl,bc
 jr c, $+4
 sbc hl,bc
rept 7
        divz
endm
	adc a,a
	ld d,a

	ld a,e
	add a,a
 adc hl,hl
 add hl,bc
 jr c, $+4
 sbc hl,bc
rept 7
	divz
endm
	adc a,a
	ld e,a
endm

div32x16 macro  ; BCDE = HLDE/BC, HL = HLDE%BC
     local OPT,DIV320,exitdiv ;may work wrong if BC>$7fff - fixed!
     ;DEC   BC
     dec c
     LD    A, B
     or a
;     jp z,div32x8
     jp m,longdiv0

     CPL
     LD    B, A
     LD    A, C
     CPL
     LD    C, A

     ADD   A, L
     LD    A, B
     ADC   A, H
     JP    NC, DIV320

longdiv
     PUSH  DE
OPT equ 1         ;3 limits HL to 0x1f'ff'ff'ff

rept OPT
     ADD HL,HL
endm
     EX    DE, HL
     LD    HL, 0

rept 16-OPT
     div
endm
     EX    DE, HL
     EX    (SP), HL
     EX    DE, HL

rept 16
     div
endm
     POP   BC
     jp exitdiv

longdiv0
     CPL
     LD    B, A
     LD    A, C
     CPL
     LD    C, A
     jp longdiv

;div32x8
;     jp exitdiv

DIV320
     divx
     LD    BC, 0
exitdiv
     endm

      ORG 0100h
start    proc
         local lf0,loop,l4,loop2,m1,l1

if BIOS_OUTPUT
   ld hl,(1) ;BIOS base table
   ld de,9   ;conout offset
   add hl,de
   ld (PRS+1),hl
endif

    ld hl,0f6d0h  ;48 bytes for stack and 6 first bytes of BDOS area
    ld de,(6)
    add hl,de
    ld de,0
    ex de,hl
    ld bc,7
    call div32x16r
    ld a,e
    and 0fch
    ld l,a
    ld h,d
    push hl
    ld (maxnum),hl
    ld de,msg1
    ld c,9
    call BDOS

    pop hl
    call PR0000

    ld de,msg2
    ld c,9
    call BDOS

    call getnum
    push hl
    ld de,msg4
    ld c,9
    call BDOS
    pop hl

    ld a,l
    and 0fch
    cp l
    jr z,l1

    add a,4
    ld l,a
    push hl
    call PR0000
    ld de,msg3
    ld c,9
    call BDOS
    pop hl

l1  ld d,h
    ld e,l
    add hl,hl
    add hl,de
    add hl,hl
    add hl,de
    srl h
    rr l
    push hl

if TIKI100
    ld hl,(TIKI100_TIMER_LO)
    ld (time),hl
    ld hl,(TIKI100_TIMER_HI)
    ld (time+2),hl
endif
if AMSTRADCPC
    call ENTER_FIRMWARE
    dw KL_TIME_PLEASE
    ld (time),hl
    ld (time+2),de
endif
        ;ld e,12  ;clear screen
        ;ld c,2
        ;call BDOS

    pop bc      ;fill r-array
         ;di         ;no interrupts
         push bc
         ld de,2000
         ld hl,ra

lf0      ld (hl),e
         inc l
         ld (hl),d
         inc hl
         dec bc
         ld a,c
         or b
         jr nz,lf0

         ld (cv),bc
         pop hl          ;k <- N
         ld (kv),hl
loop     ld hl,0          ;d <- 0
         push hl
         push hl
         ld hl,(kv)          ;i <-k
         add hl,hl        ;keeps 2*i
         ld a,l
         ld iyl,a
         ld a,h
         ld iyh,a
loop2    ld c,iyl
         ld b,iyh
         ld hl,ra
         add hl,bc
         ld (m1+1),hl

         ld c,(hl)      ;r[i]
         inc l          ;r is at even addr
         ld b,(hl)
         ld h,high(m10000)
         ld l,c
         ld e,(hl)
         ld l,b
         ld a,(hl)
         ld l,c
         inc h
         add a,(hl)
         ld d,a
         ld l,b
         ld a,(hl)
         ld l,c
         inc h
         adc a,(hl)
         ld c,a
         ld l,b
         ld a,(hl)
         adc a,0
         ld b,a

         pop hl       ; d <- d + r[i]*10000
         add hl,de
         ex de,hl
         pop hl
         adc hl,bc
         ld b,iyh
         ld c,iyl
         dec bc
         dec c
         ld iyh,b   ;i <- i - 1
         ld iyl,c
         inc c

         push hl
         push de
         div32x16
m1       ld (0),hl      ;r[i] <- d%b, d <- d/b
         ld a,iyl
         or iyh
         jr z,l4

         add hl,de
         jr nc,lnc

         inc bc
lnc      ex de,hl
         pop hl
         xor a       ;sets CY=0
         sbc hl,de
         ex de,hl
         pop hl
         sbc hl,bc
         srl h
         rr l
         rr d
         rr e

         push hl
         push de
         jp loop2

l4       pop hl
         pop hl
         ld h,b
         ld l,c
         ld bc,10000
         call div32x16r
         ld bc,(cv)
         ld (cv),hl     ;c <- d%10000
         ld h,b
         ld l,c

         add hl,de   ;c + d/10000
         call PR0000
         ld hl,(kv)      ;k <- k - 14
         ld de,-14
         add hl,de
         ld a,h
         or l
         jr z,showtimer

         ld (kv),hl
         jp loop

showtimer
        LD  e,' '
        ld c,2
        call BDOS

if TIKI100
    ld hl,(TIKI100_TIMER_LO)
    ld de,(TIKI100_TIMER_HI)
endif
if AMSTRADCPC
    call ENTER_FIRMWARE
    dw KL_TIME_PLEASE
endif

    ld bc,(time)
    xor a
    sbc hl,bc
    ex de,hl
    ld bc,(time+2)
    sbc hl,bc
if TIKI100
    ld bc,125              ;timer freq, Hz
endif
if AMSTRADCPC
    ld bc,300
endif
    call div32x16r
	PUSH HL
	EX DE,HL
	call PR00000
	LD  e,'.'
        ld c,2
        call BDOS
	POP hl
        push hl     ;*10000/freq
        add hl,hl   ;*5
        add hl,hl
        pop de
        add hl,de
if TIKI100
        add hl,hl  ;*16 -> *80
        add hl,hl
        add hl,hl
        add hl,hl
endif
if AMSTRADCPC
        push hl   ;*20/3 -> *100/3
        add hl,hl
        add hl,hl
        pop de
        add hl,de
        add hl,hl
        add hl,hl
        ex de,hl
        ld hl,0
        ld bc,3
        call div32x16r
        ld a,l
        cp 2
        jr c,$+3
        inc de
        ex de,hl
endif
	jr PR0000
         endp

PR00000 ld de,-10000
	CALL PR0
PR0000  ld de,-1000
	CALL PR0
	ld de,-100
	CALL PR0
	ld de,-10
	CALL PR0
	ld A,L
PRD	add a,$30
        push hl
if BIOS_OUTPUT
        ld c,a
PRS     call 0
else
        ld e,a
        ld c,2
        call BDOS
endif
        pop hl
        ret

PR0	ld A,$FF
	ld B,H
	ld C,L
	inc A
	add HL,DE
	jr C,$-4

	ld H,B
	ld L,C
	JR PRD

div32x16r proc
     local t,t0,t1,t2,t3
     call t
     ld bc,0
     ret
t
     DEC   BC
     LD    A, B
     CPL
     LD    B, A
     LD    A, C
     CPL
     LD    C, A
     call t0
t0
     call t1
t1
     call t2
t2
     call t3
t3
     div
     RET
     endp

cv dw 0
kv dw 0
time dw 0,0

         org ($ + 256) and $ff00
include "mul10000.s"

ra
msg1  db 'number '
if TIKI100
      db 240
endif
if AMSTRADCPC
      db 165
endif
      db ' calculator v1',13,10
      db 'for CP/M 2.2 ('
if TIKI100
      db 'Tiki-100'
endif
if AMSTRADCPC
      db 'Amstrad CPC'
endif
      db ').',13,10,'number of digits (up to $'
msg2  db ')? $'
msg3  db ' digits will be printed'
msg4  db 13,10,'$'
del   db 8,' ',8,'$'
maxnum dw 0
getnum proc
local l0,l1,l5,l8
        ld b,0
        ld hl,0
l0      push hl
        push bc
l00     ld c,6   ;direct console i/o
        ld e,0ffh
        call BDOS
        or a
        jr z, l00

        pop bc
        pop hl

        cp 13
        jr z,l5

        cp 07fh    ;backspace
        jr z,l1

        cp '0'
        jr c,l0

        cp '9'+1
        jr nc,l0

        ld c,a
        ld a,b
        cp 4
        ld a,c
        jr z,l0

        push hl
        inc b

        ld e,a
        sub '0'
        ld c,a
        push bc
        ld c,2   ;conout
        call BDOS
        pop bc
        pop hl
        push hl
        push hl
        add hl,hl
        add hl,hl
        pop de
        add hl,de
        add hl,hl   ;*10
        ld e,c
        ld d,0
        add hl,de
        jr l0

l1      ld a,b
        or a
        jr z,l0

        dec b
        push bc
        ld c,9
        ld de,del
        call BDOS
        pop bc
        pop hl
        jr l0

l5      ld a,b
        or a    ;sets CF=0
        jr z,l0

        push hl
        ld de,(maxnum)
        inc de
        sbc hl,de
        pop hl
        jr nc,l0

l8      pop de
        djnz l8
        retn
endp
   end start
