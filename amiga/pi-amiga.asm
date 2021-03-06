;for vasm assembler
;it calculates pi-number using the next C-algorithm
;https://crypto.stanford.edu/pbc/notes/pi/code.html

;#include <stdio.h>
;#define N 2800
;main() {
;   long r[N + 1], i, k, b, c;
;   c = 0;
;   for (i = 1; i <= N; i++)   ;it is the fixed line!, the original was (i = 0; i < N; ...
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

;the time of the calculation is quadratic, so if T is time to calculate N digits
;then 4*T is required to calculate 2*N digits
;main loop count is 7*(4+D)*D/16, D - number of digits

;So r[0] is never used.  The program for 680x0 uses r[0] and doesn't use r[N] - so it optimizes the memory usage by 2 bytes

;litwr has written this for 680x0
;tricky provided some help
;MMS gave some support
;Thorham and meynaf helped a lot

     mc68000
     ;mc68020

OldOpenLibrary	= -408
CloseLibrary	= -414
Output = -60
Input = -54
Write = -48
Read = -42
AllocMem = -198
FreeMem = -210
VBlankFrequency = 530

MULUopt = 0   ;1 is much slower for 68000, for 68020 it is the same for FS-UAE and maybe a bit faster with the real iron

;N = 7*D/2 ;D digits, e.g., N = 350 for 100 digits

div32x16o macro    ;D7=D6/D4, D6=D6%D4
     ;clr.l d7
     moveq.l #0,d7
     swap d6
     cmp d4,d6
     bcs .div32\@

     move d6,d7
     divu d4,d7
     swap d7
     move d7,d6

.div32\@
     swap d6
     divu d4,d6
     move d6,d7
     clr d6
     swap d6
endm

div32x16 macro    ;D7=D6/D4, D6=D6%D4
     ;clr.l d7
     moveq.l #0,d7
     divu d4,d6
     bvc .div32no\@

     swap d6
     move d6,d7
     divu d4,d7
     swap d7
     move d7,d6
     swap d6
     divu d4,d6
.div32no\@
     move d6,d7
     clr d6
     swap d6
endm


start    lea  libname(pc),a1         ;open the dos library
         move.l  4,a5
         move.l a5,a6
         jsr     OldOpenLibrary(a6)
         move.l  d0,a6
         jsr     Output(a6)          ;get stdout
         move.l  d0,cout
         move.l  d0,d1                   ;call Write(stdout,buff,size)
         move.l  #msg1,d2
         moveq   #msg4-msg1,d3
         jsr     Write(a6)
         clr.l d0
         sub.l #endmark,d0
         add.l #start+$10000,d0
         divu #7,d0
         ext.l d0
         and.b #$fc,d0
         move.l d0,maxn

.l20     move.l cout(pc),d1
         move.l  #msg4,d2
         moveq   #msg5-msg4,d3
         jsr     Write(a6)
         move.l maxn(pc),d5
         bsr PR0000
         move.l cout(pc),d1
         move.l  #msg5,d2
         moveq   #msg3-msg5,d3
         jsr     Write(a6)
         bsr getnum
         cmp maxn+2(pc),d5    ;680x0 are Big Endian
         bhi .l20

         or d5,d5
         beq .l20

         move d5,d1
         addq #3,d5
         and #$fffc,d5
         cmp.b #10,(a0)
         bne .l21

         cmp d1,d5
         beq .l7

.l21     move d5,a4
         bsr PR0000
         move a4,d5
         move.l  cout(pc),d1
         move.l  #msg3,d2
         moveq   #msg2-msg3+1,d3
         jsr     Write(a6)
.l7      lsr d5
         mulu #7,d5
         move.l d5,a4

         move.l a4,d2
         move.l d2,d0
         lsl.l d0
         move.l d0,a2
         exg.l a5,a6
         clr.l d1      ;any kind of memory
         jsr AllocMem(a6)
         exg.l a5,a6
         move.l d0,a2

  if __VASM&28
         bsr gettime
         move.l d5,time
  else
         move.l $6c,rasterie+2
         move.l #rasteri,$6c
  endif
         lsr #1,d2
         subq #1,d2
         move.l #2000*65537,d0
         move.l a2,a0
.fill    move.l d0,(a0)+
         dbra d2,.fill

         clr cv
         move a4,kv

.l0      clr.l d5       ;d <- 0
         clr.l d4
         move kv(pc),d4
         add.l d4,d4     ;i <-k*2
         move.l a2,a3
         adda.l d4,a3
         subq.l #1,d4     ;b <- 2*i-1
  ifeq MULUopt
         move #10000,d1   ;removed with MULU optimization
  endif
         bra .l4

.l2      sub.l d6,d5
         sub.l d7,d5
         lsr.l d5
.l4
  if MULUopt
         moveq.l #0,d0  ;MULU optimization
  endif
         move -(a3),d0      ; r[i]
  if MULUopt
         move.l d0,d1   ;MULU optimization
         lsl.l #3,d0
         sub.l d0,d1
         add.l d0,d0
         sub.l d0,d1
         sub.l d0,d1
         lsl.l #8,d1
         sub.l d1,d0
  else
         mulu d1,d0       ;r[i]*10000, removed with MULU optimization
  endif
         add.l d0,d5       ;d += d + r[i]*10000
         move.l d5,d6
  if __VASM&28              ;68020?
         divul.l d4,d7:d6
         move d7,(a3)     ;r[i] <- d%b
  else
         div32x16
         move d6,(a3)     ;r[i] <- d%b
  endif
         subq #2,d4    ;i <- i - 1
         bcc .l2       ;the main loop
  if MULUopt
         divu #10000,d5  ;MULU optimization
  else
         divu d1,d5      ;removed with MULU optimization
  endif
         add cv(pc),d5    ;c + d/10000
         swap d5      ;c <- d%10000
         move d5,cv
         clr d5
         swap d5
         bsr PR0000
         sub.w #14,kv
         bne .l0

         moveq   #1,d3
         move.l  cout(pc),d1
         move.l  #msg3,d2
         jsr     Write(a6)  ;space

  if __VASM&28              ;68020?
         bsr gettime
         sub.l time(pc),d5
  else
         move.l rasterie+2,$6c
         move.l time(pc),d5
  endif

         move.l d5,d3
         lsl.l d5
         cmp.b #50,VBlankFrequency(a5)
         beq .l8

         lsl.l d5      ;60 Hz
         add.l d3,d5
         divu #3,d5
         swap d5
         lsr #2,d5
         swap d5
         negx.l d5
         neg.l d5

.l8      lea string(pc),a3
         move #10,d4
         move.l d5,d6
         div32x16
         move.b d6,(a3)+
         divu d4,d7
         swap d7
         move.b d7,(a3)+
         clr d7
         swap d7
         move.b #'.'-'0',(a3)+
.l12     tst d7
         beq .l11

         divu d4,d7
         swap d7
         move.b d7,(a3)+
         clr d7
         swap d7
         bra .l12

.l11     add.b #'0',-(a3)
         moveq   #1,d3
         move.l  cout(pc),d1
         move.l  a3,d2
         jsr     Write(a6)
         cmp.l #string,a3
         bne .l11

         ;moveq   #1,d3
         move.l  cout(pc),d1
         move.l  #msg2,d2
         jsr     Write(a6)  ;newline

         move.l a6,a1
         move.l a5,a6
         jsr CloseLibrary(a6)
         move.l a2,a1
         move.l a4,d0
         lsl.l d0
         jmp FreeMem(a6)
         ;rts

PR0000     ;prints d5
       lea string(pc),a0
       bsr .l1
       moveq   #4,d3
       move.l  cout(pc),d1
       move.l  #string,d2
       jmp     Write(a6)             ;call Write(stdout,buff,size)

.l1    divu #1000,d5
       bsr .l0
       clr d5
       swap d5

       divu #100,d5
       bsr .l0
       clr d5
       swap d5

       divu #10,d5
       bsr .l0
       swap d5

.l0    eori.b #'0',d5
       move.b d5,(a0)+
eos    rts

getnum   jsr Input(a6)          ;get stdin
         move.l #string,d2     ;set by previous call
         move.l d0,d1
         moveq.l #5,d3     ;+ newline
         jsr Read(a6)
         subq #1,d0
         beq getnum

         move.l d2,a0
         clr.l d5
.l1      clr d6
         move.b (a0)+,d6
         sub.b #'0',d6
         add d6,d5
         subq #1,d0
         beq eos

         mulu #10,d5
         bra .l1

  if __VASM&28              ;68020?
gettime clr d5          ;returns D5
        move.b $bfea01,d5
        swap d5
        move.b $bfe901,d5
        lsl #8,d5
        move.b $bfe801,d5
        rts
  else
rasteri      btst #6,$dff01e   ;blitter?
             bne rasterie

             addq.l #1,(time)
rasterie     jmp $ffff00
  endif

cv  dc.w 0
kv  dc.w 0
time dc.l 0
cout dc.l 0
maxn dc.w 0

string = msg1
libname  dc.b "dos.library",0
msg1  dc.b 'number ',182,' calculator v4 '
  if __VASM&28              ;68020?
      dc.b '(68020)'
  else
      dc.b '(68000)'
  endif
msg4  dc.b 10,'number of digits (up to '
msg5 dc.b ')? '
msg3  dc.b ' digits will be printed'
msg2  dc.b 10
msg6  dc.b 'no fast memory',10
endmark
      end     start

