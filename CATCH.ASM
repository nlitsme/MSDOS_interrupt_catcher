; Catch interrupt V2.1  - 10 jan 1994
;                  by   - Willem Jan Hengeveld
;               email   - willem@dutikos.twi.tudelft.nl
;               phone   - +31-15-617267
;
;  a program to log all calls to interrupts specified on the command line
;
;  Usage: catch [s]i <intno> ...
;            S = only store 'specials'
;         catch u <filename>
;         a maximum of 10 interrupts can be monitored at one time
;
;  history:
;   V1.0 - 10-1-1994
;   V2.0 - 14-2-1994
;           fixed gettime, & other bugs
;   V2.1 - 17-2-1994
;           added novell support
;   24-3-94: fixed findnext storage -> used to store data
;   24-3-94: fixed rename, new name used essi instead of esdi
;
; Plans:
;   - for 'findnext' : add counter option:
;       count # invokations of call
;
;   - convert to bigger memory model
;   - think of a better way to implement specialactions
;   - allow for return values to be stored
;   - I am not sure if time calculation is correct -> check
;   - allow interrupt list to be edited when installed
;   - no check is made to see if catch is already installed
;   - put version number in signature to check for correct version
;   - add more special actions
;   - construct all the 'catchX' routines with 1 macro, or maybe add them
;     dynamicly at runtime
;   - option to display current status
;   - clean up commandline processor
;   - add 021f2, store CX bytes from DSSI, with 'n' command line option to enable
;     21e0, 21e1, 21e2, 21e3, 21f2 : DSSI, CX bytes
;
;   - add exclusion list: certain CS/IP/AX values can be excluded from
;     logging
;   - reduce storage: 1 word specifies which registers have to be stored
;     bits0-7=ax cx dx bx sp bp si di   (modrm order)
;     bits8-d=es cs ss ds ip sw
;   - make code reentrant so hardware interrupts will be logged properly
;   - change order of registers to match modrm order (this might come in
;     handy when processing instructions
;   - single step option (for instance when scrolllock is on)
;   - start/stop logging with some hotkey
;   - stay on top option: check if address in int table matches my entry point
;     if not try to find out who changed it.
;   - trap int2125 to allways stay on top
;   - flexible changing of MAXINTS
;   - may be it is possible to find out what caused int:
;     - check instruction at CS:[IP-2] == INT xx
;     - check PIC to see if hw int occurred
;          out 20,0a  in al,20   -> read isr
;          out 20,0b  in al,20   -> read irr
;
;   - REGSPEC ::=  <word> <values for each bit set in word> [....]
;                  followed by more records if bit F is set
;       word, bits 0-7 = intel words
;             bits 8-B = intel segs
;             bits c-d = IP, SW
;             bit  e   = NOT
;             bit  f   = OR next record
;       if REGSPEC is an expression it is true if there is one record for which
;       all values match
;       if REGSPEC is a storage spec, bit F&E mean nothing
;   - storage list:
;       byte  intno
;       byte  byteregflag       - intel byte regs
;       byte  ? dup(?)          - values for the specified byte registers
;       REGSPEC                 - storage spec
;
;   - bit vector om aan te geven welke bytes van de stack wel & niet gestored
;     moeten worden, altijd: len, int, n, time, CSIP,
;     bits 0-7 : AL AH BL BH CL CH DL DH
;     bits 8-f : DS SI ES DI SS SP BP flag
;   - change _checkspecial from linear search to binary search
;
; 17-2-1994 : make special flag structure to copy or not copy certain specials
;        f : fileio
;        n : novell stuff
;        ..
;
; - change catches to all start at seg:0, containing all per irq info.
;     SS -> stack
;     DS -> global data
;     ES -> local data
; catchseg segment
;   org 0
;    push  bp
;    mov   bp, cs
;    jmp  ?
; intnr label byte
;    db   ?
; intidx label byte
;    db   ?
; oldint label dword
;    dw   ?
;    dw   ?
; counter label word
;    dw   ?
; catchseg ends
;
; catchint:
;    push all
;    mov  es,bp
;    mov  bp,sp
;    add  bp,8   -> space for reclen:1, intno:1, intcnt:2, time:4
;    push cs
;    pop  ds
; assume es:catchseg, ds:code
;
;  TF=1 -> generate INT01 after each instruction
;  IF=1 -> interrupts disabled
;
; on_stack on_entry
;  TF  IF    TF  IF
;   0   0     0   0
;   0   0     0   1
;   0   0     1   0
;   0   0     1   1
;   0   1     0   0
;   0   1     0   1
;   0   1     1   0
;   0   1     1   1
;   1   0     0   0
;   1   0     0   1
;   1   0     1   0
;   1   0     1   1
;   1   1     0   0
;   1   1     0   1
;   1   1     1   0
;   1   1     1   1
;   *   *     0   0  invoked by INT xx or INTO xx or INT3
;   *   *     1   *  invoked by CALL/JMP
;
; future improvements:
;   add ptr to start of buffer for better future compatibility
;
.286
biosseg segment at 040h
org 0
  rs232portlist     dw 4 dup(?)           ; 0000
  lptaddr           dw 4 dup(?)           ; 0008
  hardwareinst      dw ?                  ; 0010
  post_status       db ?                  ; 0012
  basememsize       dw ?                  ; 0013
  scratch_1         dw ?                  ; 0015
  keystatus         dw ?                  ; 0017
  scratch_2         db ?                  ; 0019
  nextkeyptr        dw ?                  ; 001a
  nextfreeptr       dw ?                  ; 001c
  keybuffer         dw 010h dup(?)        ; 001e
  driverecalstat    db ?                  ; 003e
  drivemotorstat    db ?                  ; 003f
  drivemotoroffcnt  db ?                  ; 0040
  drivelastresult   db ?                  ; 0041
  drivecmd          db 7 dup(?)           ; 0042
  currvideomode     db ?                  ; 0049
  videocols         dw ?                  ; 004a
  videopagesize     dw ?                  ; 004c
  curpageofs        dw ?                  ; 004e
  cursorpos         dw 08h dup(?)         ; 0050
  cursortype        dw ?                  ; 0060
  currentpage       db ?                  ; 0062
  crtportaddr       dw ?                  ; 0063
  crtmodeselect     db ?                  ; 0065
  crtcgapallette    db ?                  ; 0066
  postresetreentry  dd ?                  ; 0067
  postlastirq       db ?                  ; 006b
  biosTimerL        dw ?                  ; 006c
  biosTimerH        dw ?                  ; 006e
  biostimeroverflow db ?                  ; 0070
  ctrlbreakflag     db ?                  ; 0071
biosseg ends

videoseg segment at ?
videoseg ends

mcbseg segment at ?
  mcbflag           db ?
  mcbowner          dw ?
  mcblen            dw ?
mcbseg ends

RECSIZE    equ 024h      ; # words in default record
MAXRECSIZE equ 0e0h
MAXINTS    equ 10        ; # int buffers
MAXRECDATA equ MAXRECSIZE - RECSIZE   ; # bytes that may be appended to a record

code  segment para 'CODE'
  assume  cs:code, ds:code, es:code, ss:code

psp_int20       db 2 dup(?)
psp_nextseg     dw ?
psp_unused1     db ?
psp_cpmcall5    db ?
psp_seg1len     dw ?
psp_cpmcall5_2  db 2 dup(?)
psp_int22vec    dd ?
psp_int23vec    dd ?
psp_int24vec    dd ?
psp_parentseg   dw ?
psp_jobfiletab  db 20 dup(?)
psp_envseg      dw ?
psp_savsssp     dd ?           ; on last int21 call
psp_njft        dw ?
psp_jftptr      dd ?
psp_prevpsp     dd ?
psp_unused2     db 4 dup(?)
psp_dosver      dw ?
psp_unused3     db 26 dup(?)
psp_fcb1        db 16 dup(?)
psp_fcb2        db 16 dup(?)
psp_unused4     db 4 dup(?)
psp_cmdlen      db ?
psp_cmdline     db 126 dup(?)

org 0100h

start:
     jmp  _init

label signature byte
        db 'interrupt$catch'
label endsig byte

even      ; for speed
_intcounter label word
     dw   MAXINTS dup(0)
_nentries label word
     dw   0
_maxbuf  label word
     dw   0
_lastentry label dword
     dw   0
     dw   0
_buffer  label dword
     dw   0
     dw   0
_oldint label dword
     dd   0
_oldinttab  label dword
     dd   MAXINTS dup(0)
_catchtab label word      ; this should contain a list of _catch0 .. _catchN
     dw   _catch0, _catch1, _catch2, _catch3
     dw   _catch4, _catch5, _catch6, _catch7
     dw   _catch8, _catch9
_intnrs  label byte
     db   MAXINTS dup(0)
_curint label byte         ; _intnrs [ _curintno ]
     db   0
_curintno label byte       ; index into _intnrs tab of _curint
     db   0
_nints label word          ; # entries in _intnrs table
     dw   0
_video_seg label word
     dw   0b000h
_specialflag label byte    ; commandline flags
     db   0
_active label byte         ; 1 if processing interrupt
     db   0
_skipped_ints label word   ; # ints not processed
     dw   0

FLAGCHAR   equ 01h
FLAGFILERW equ 02h
FLAGNOVELL equ 04h
FLAGDIRECT equ 08h
FLAGFILEOC equ 10h
FLAGFCB    equ 20h
FLAGDISK   equ 40h
FLAGALL    equ (FLAGCHAR or FLAGFILEOC or FLAGFILERW or FLAGNOVELL or FLAGDIRECT or FLAGFCB)

assume ds:nothing, es:nothing, ss:nothing
;*************************************************************
; print AX as decimal value directly to video buffer, offset DI, CX positions
; input: AX, DI
; return:  BX=0a, CX=0, AX=?? DX=0, DI=??  ES=videoseg
;
_displaydec proc near
assume ds:code
     mov bx,_video_seg
     mov es,bx
assume es:videoseg
     mov bx,0ah
     std
convloop:
     xor dx,dx
     div  bx
     xchg dx,ax
     mov  ah,070h
     add  al,'0'
     stosw
     xchg dx,ax
     test ax,ax
     je   fillup
     loop convloop
     ret
 fillup:
     dec cx
     mov ax,7020h
     rep stosw
     ret
_displaydec endp

;*************************************************************
; print AX as hex (CX digits) on screen, offset DI
; input: AX, DI
; return:  BX=0a, CX=0, AX=?? DX=0, DI=??  ES=videoseg
;
_displayhex proc near
assume ds:code
     mov bx,_video_seg
     mov es,bx
assume es:videoseg
     mov bx,010h
     std
hexconvloop:
     xor dx,dx
     div  bx
     xchg dx,ax
     mov  ah,079h          ; highlited with underscore
     add  al,'0'
     cmp  al,'9'
     jle  notabcdef
     add  al,'@'-'9'
notabcdef:
     stosw
     xchg dx,ax
     test ax,ax
     je   hexfillup
     loop hexconvloop
     ret
hexfillup:
     dec cx
     mov ax,0720h
     rep stosw
     ret
_displayhex endp

;*************************************************************
; read microsecond accuracy timer
; input: -
; output: DX:AX = time
;
;  bug : when timer has just gone through zero it hasn't generated an
;        int yet ??
;        or maybe I should just substract 0100 from low word of timer value
;  cause:
;    when reading the time, I do it twice, to see if an interrupt has
;    gone in between, but ints don't happen so biostimer isn't incremented
;
;-----------------------------------------------------------------------
; read microsecond accuracy timer
; input: -
; output: DX:AX = time
;
;-----------------------------------------------------------------------
assume cs:code
_gettime proc near
     push ds
     push bx
     push cx
     pushf
     cli

     mov  ax,040h
     mov  ds, ax
assume ds:biosseg
     mov  dx,biosTimerL

     mov  al,4
     out  43h,al
     in   al,40h
     mov ah,al
     in   al,40h
     mov  cx,ax

     mov  al,0ah           ; (a=ports.lst  b=hardware.txt)
     out  020h,al
     in   al,020h          ; get IRR
     mov  bl,al

     mov  al,4
     out  43h,al
     in   al,40h
     mov ah,al
     in   al,40h

     test bl,1
     jz   takefirst          ; no int pending
     inc  dx
     mov  cx,ax
takefirst:
     xchg ch,cl
     not  cx
     mov  ax,cx

     popf
     pop  cx
     pop  bx
     pop  ds
     ret
_gettime endp
assume cs:code,ds:nothing,es:nothing

;*************************************************************
; first word: intno, AH value
; secondword: class, action
;   action
;    0 - no extra copy
;    1 - copy ascii0d from dssi
;    2 - copy asciiz string from dsdx
;    3 - append DL to previous
;    4 - copy asciiz string from dssi         (ext open)
;    5 - copy Zstr from esdi, Zstr from dsdx  (rename)
;    6 - copy $str from DS:DX
;    7 - copy Lstr from dssi, Lstr from dsbx [0d]
;    8 - copy CX bytes from DS:SI (novell)
;    9 - copy novell packet : ds:si -> [len:word] [data:len]
;   10 - (1), but only if AL==23
;    b - copy 12 bytes from dsdx  (fcb)
;    c - copy 24 bytes from dsdx  (fcb rename)
;   ff - not special
;  class
;   1 - char i/o
;   2 - file i/o
;   4 - novell
;   8 - directory
;  10 - open/exec
;  20 - fcb fns
;  40 - disk fns
; table with values for intno & AH which require special action
;
_special label word
      dw  02102h, 0103h    ;  ch -> CON  (DL)
      dw  02104h, 0103h    ;  ch -> AUX  (DL)
      dw  02105h, 0103h    ;  ch -> PRN  (DL)
      dw  02106h, 0103h    ;  console io (DL)
      dw  02109h, 0106h    ;  $str ->CON  (DS:DX)
      dw  0210eh, 4003h    ;  setdrv   (DL)
      dw  0210fh, 200bh   ; FCB  open file
      dw  02111h, 200bh   ; FCB  find first
      dw  02112h, 200bh   ; FCB  find next
      dw  02113h, 200bh   ; FCB  delete file
      dw  02116h, 200bh   ; FCB  create file
      dw  02117h, 200ch   ; FCB  rename file
      dw  02119h, 4000h    ;  getdrv   (       -> AL)
      dw  02123h, 200bh   ; FCB  get file size
      dw  02129h, 0801h    ;  parse fn (DS:SI)
      dw  02131h, 1000h    ;  tsr_exit(code)
      dw  02139h, 0802h    ;  mkdir    (DS:DX)
      dw  0213ah, 0802h    ;  rmdir    (DS:DX)
      dw  0213bh, 0802h    ;  chdir    (DS:DX)
      dw  0213ch, 1002h    ;  _create  (DS:DX, attr=CX)   (AX)
      dw  0213dh, 1002h    ;  open     (DS:DX, mode=al)   (AX)
      dw  0213eh, 0200h    ;  close    (handle=BX)
      dw  0213fh, 0200h    ;  read     (handle=BX, CX=nbytes, DS:DX=buf)
      dw  02140h, 0200h    ;  write    (handle=BX, CX=nbytes, DS:DX=buf)
      dw  02141h, 1002h    ;  delete   (DS:DX)
      dw  02142h, 0200h    ;  lseek    (handle=BX, CXDX=offset, AL=origin)
      dw  02143h, 0202h    ;  attrib   (DS:DX, AL=get/set, CX=attrib)
      dw  02147h, 0800h    ;  getcwd   (drive=DL, buf=DS:SI)
      dw  0214bh, 1002h    ;  exec     (DS:DX)
      dw  0214ch, 1000h    ;  exit(code)
      dw  0214eh, 0802h    ;  findfirst(DS:DX, CX=attr)
      dw  0214fh, 0200h    ;  findnext nothing
      dw  02156h, 1005h    ;  rename   (DS:DX -> ES:DI)
      dw  0215ah, 1002h    ;  mktemp   (DS:DX, attr=CX)
      dw  0215bh, 1002h    ;  create   (DS:DX, attr=CX)
      dw  0215ch, 0200h    ;  lock     (handle=BX, AL=fn, CXDX=start, SIDI=length)
      dw  02160h, 1004h    ;  cvtfilename (DS:SI)
      dw  0216ch, 1004h    ;  extend open (DS:SI, BX=mode, CX=attr, DX=fn)
      dw  021e0h, 0409h   ; novell
      dw  021e1h, 0409h   ; novell
      dw  021e2h, 0409h   ; novell
      dw  021e3h, 0409h   ; novell
      dw  021efh, 0400h   ; novell
      dw  021f0h, 0400h   ; novell
      dw  021f1h, 0400h   ; novell
      dw  021f2h, 0408h   ; novell
      dw  02f11h, 0210h   ;  DS:SI  - qualify name
      dw  02faeh, 0207h   ;  DS:BX, DS:SI

NSPECIALS equ ($ - _special)/4

;*************************************************************
;  checks if AX contains special int function  CX and DI are destroyed
;  input: AX
;  output: AH=class, AL=action  (0000=notspecial)
;
_checkspecial proc near
assume ds:code
      mov cx, NSPECIALS
      mov di, offset _special
      push cs
      pop  es
assume es:code
checkloop:
      scasw
      jz   foundspecial
      scasw                 ; skip class/action word
      loop checkloop
return0:
      xor ax, ax
      ret
foundspecial:
      mov ax,[di]
      ret
_checkspecial endp

;*************************************************************
; movestring - copies string ds:si -> es:di, adjust length of record
; maximum length=CX,  terminating char=AL or 0
; input: DS:SI, AL, CX
; output: CX,  SI=si+CX, DI=lastentry, AH=al
movestring proc near
assume ds:nothing, es:nothing
     cld
     mov  ah,al
     les  di, _buffer
movestrloop:
     lodsb
     stosb
     or   al,al
     jz   end_of_string
     cmp  al,ah
     jz   end_of_string
     loop   movestrloop

end_of_string:
     mov  cx,di
     sub  cx, word ptr _buffer
     mov  word ptr _buffer, di
     mov  di,word ptr _lastentry
     add  es:[di], cl             ; adjust record length
     push cs
     pop  ds
assume ds:code
     ret
movestring endp

;*************************************************************
; movememory - copies string ds:si -> es:di, adjust length of record
; length=CX
; input: DS:SI, CX
; output: CX,  SI=si+CX, DI=lastentry
movememory proc near
assume ds:nothing, es:nothing
     cld
     les  di, _buffer
     rep  movsb

     mov  cx,di
     sub  cx, word ptr _buffer    ; get copied length
     mov  word ptr _buffer, di
     mov  di,word ptr _lastentry
     add  es:[di], cl             ; adjust record length
     push cs
     pop  ds
assume ds:code
     ret
movememory endp

copyregdata proc near
assume ds:code, es:nothing
     push  ds
     inc  _nentries
     les  di, dword ptr _buffer
     mov  word ptr _lastentry, di
     mov  word ptr _lastentry+2, es
     push ss
     pop  ds
assume ds:nothing, es:nothing
     mov  cx,RECSIZE              ; move bytes because SP might be odd
     rep  movsb                   ; mov [sp=ffff] .. causes GPI
     mov  word ptr _buffer, di
     pop  ds
assume ds:code, es:nothing
     ret
copyregdata endp

assume ds:nothing, es:nothing, ss:nothing
;
; - change frame to:
; pushf
; push oldint.seg
; push oldint.off
;
_catch0 proc near
     push  bp
     dec   _active
     jl    skip_catch0
     xchg  bp,ax
     mov  _curintno, 0
     mov   al, _intnrs[0]
     mov  _curint,al
     mov   ax, word ptr _oldinttab[0*4]
     mov  word ptr _oldint, ax
     mov   ax, word ptr _oldinttab[0*4+2]
     mov  word ptr _oldint+2, ax
     xchg  bp,ax
     jmp  _catchint
skip_catch0:
     inc   _active
     inc   _skipped_ints
     mov bp,sp
     mov bp,[bp+6]     ; restore flags (important)
     and bp, 0fcffh    ; clear TF,IF
     push bp
     popf
     pop bp
     jmp   _oldinttab[0]
_catch0 endp

_catch1 proc near
     push  bp
     dec   _active
     jl    skip_catch1
     xchg  bp,ax
     mov  _curintno, 1
     mov   al, _intnrs[1]
     mov  _curint,al
     mov   ax, word ptr _oldinttab[1*4]
     mov  word ptr _oldint, ax
     mov   ax, word ptr _oldinttab[1*4+2]
     mov  word ptr _oldint+2, ax
     xchg  bp,ax
     jmp  _catchint
skip_catch1:
     inc   _active
     inc   _skipped_ints
     mov bp,sp
     mov bp,[bp+6]     ; restore flags (important)
     and bp, 0fcffh    ; clear TF,IF
     push bp
     popf
     pop bp
     jmp   _oldinttab[1]
_catch1 endp

_catch2 proc near
     push  bp
     dec   _active
     jl    skip_catch2
     xchg  bp,ax
     mov  _curintno, 2
     mov   al, _intnrs[2]
     mov  _curint,al
     mov   ax, word ptr _oldinttab[2*4]
     mov  word ptr _oldint, ax
     mov   ax, word ptr _oldinttab[2*4+2]
     mov  word ptr _oldint+2, ax
     xchg  bp,ax
     jmp  _catchint
skip_catch2:
     inc   _active
     inc   _skipped_ints
     mov bp,sp
     mov bp,[bp+6]     ; restore flags (important)
     and bp, 0fcffh    ; clear TF,IF
     push bp
     popf
     pop bp
     jmp   _oldinttab[2]
_catch2 endp

_catch3 proc near
     push  bp
     dec   _active
     jl    skip_catch3
     xchg  bp,ax
     mov  _curintno, 3
     mov   al, _intnrs[3]
     mov  _curint,al
     mov   ax, word ptr _oldinttab[3*4]
     mov  word ptr _oldint, ax
     mov   ax, word ptr _oldinttab[3*4+2]
     mov  word ptr _oldint+2, ax
     xchg  bp,ax
     jmp  _catchint
skip_catch3:
     inc   _active
     inc   _skipped_ints
     mov bp,sp
     mov bp,[bp+6]     ; restore flags (important)
     and bp, 0fcffh    ; clear TF,IF
     push bp
     popf
     pop bp
     jmp   _oldinttab[3]
_catch3 endp

_catch4 proc near
     push  bp
     dec   _active
     jl    skip_catch4
     xchg  bp,ax
     mov  _curintno, 4
     mov   al, _intnrs[4]
     mov  _curint,al
     mov   ax, word ptr _oldinttab[4*4]
     mov  word ptr _oldint, ax
     mov   ax, word ptr _oldinttab[4*4+2]
     mov  word ptr _oldint+2, ax
     xchg  bp,ax
     jmp  _catchint
skip_catch4:
     inc   _active
     inc   _skipped_ints
     mov bp,sp
     mov bp,[bp+6]     ; restore flags (important)
     and bp, 0fcffh    ; clear TF,IF
     push bp
     popf
     pop bp
     jmp   _oldinttab[4]
_catch4 endp

_catch5 proc near
     push  bp
     dec   _active
     jl    skip_catch5
     xchg  bp,ax
     mov  _curintno, 5
     mov   al, _intnrs[5]
     mov  _curint,al
     mov   ax, word ptr _oldinttab[5*4]
     mov  word ptr _oldint, ax
     mov   ax, word ptr _oldinttab[5*4+2]
     mov  word ptr _oldint+2, ax
     xchg  bp,ax
     jmp  _catchint
skip_catch5:
     inc   _active
     inc   _skipped_ints
     mov bp,sp
     mov bp,[bp+6]     ; restore flags (important)
     and bp, 0fcffh    ; clear TF,IF
     push bp
     popf
     pop bp
     jmp   _oldinttab[5]
_catch5 endp

_catch6 proc near
     push  bp
     dec   _active
     jl    skip_catch6
     xchg  bp,ax
     mov  _curintno, 6
     mov   al, _intnrs[6]
     mov  _curint,al
     mov   ax, word ptr _oldinttab[6*4]
     mov  word ptr _oldint, ax
     mov   ax, word ptr _oldinttab[6*4+2]
     mov  word ptr _oldint+2, ax
     xchg  bp,ax
     jmp  _catchint
skip_catch6:
     inc   _active
     inc   _skipped_ints
     mov bp,sp
     mov bp,[bp+6]     ; restore flags (important)
     and bp, 0fcffh    ; clear TF,IF
     push bp
     popf
     pop bp
     jmp   _oldinttab[6]
_catch6 endp

_catch7 proc near
     push  bp
     dec   _active
     jl    skip_catch7
     xchg  bp,ax
     mov  _curintno, 7
     mov   al, _intnrs[7]
     mov  _curint,al
     mov   ax, word ptr _oldinttab[7*4]
     mov  word ptr _oldint, ax
     mov   ax, word ptr _oldinttab[7*4+2]
     mov  word ptr _oldint+2, ax
     xchg  bp,ax
     jmp  _catchint
skip_catch7:
     inc   _active
     inc   _skipped_ints
     mov bp,sp
     mov bp,[bp+6]     ; restore flags (important)
     and bp, 0fcffh    ; clear TF,IF
     push bp
     popf
     pop bp
     jmp   _oldinttab[7]
_catch7 endp

_catch8 proc near
     push  bp
     dec   _active
     jl    skip_catch8
     xchg  bp,ax
     mov  _curintno, 8
     mov   al, _intnrs[8]
     mov  _curint,al
     mov   ax, word ptr _oldinttab[8*4]
     mov  word ptr _oldint, ax
     mov   ax, word ptr _oldinttab[8*4+2]
     mov  word ptr _oldint+2, ax
     xchg  bp,ax
     jmp  _catchint
skip_catch8:
     inc   _active
     inc   _skipped_ints
     mov bp,sp
     mov bp,[bp+6]     ; restore flags (important)
     and bp, 0fcffh    ; clear TF,IF
     push bp
     popf
     pop bp
     jmp   _oldinttab[8]
_catch8 endp

_catch9 proc near
     push  bp
     dec   _active
     jl    skip_catch9
     xchg  bp,ax
     mov  _curintno, 9
     mov   al, _intnrs[9]
     mov  _curint,al
     mov   ax, word ptr _oldinttab[9*4]
     mov  word ptr _oldint, ax
     mov   ax, word ptr _oldinttab[9*4+2]
     mov  word ptr _oldint+2, ax
     xchg  bp,ax
     jmp  _catchint
skip_catch9:
     inc   _active
     inc   _skipped_ints
     mov bp,sp
     mov bp,[bp+6]     ; restore flags (important)
     and bp, 0fcffh    ; clear TF,IF
     push bp
     popf
     pop bp
     jmp   _oldinttab[9]
_catch9 endp

;_catch9 proc near
;     push  bp
;     xchg  bp,ax
;     mov  _curintno, 9
;     mov   al, _intnrs[9]
;     mov  _curint,al
;     mov   ax, word ptr _oldinttab[9*4]
;     mov  word ptr _oldint, ax
;     mov   ax, word ptr _oldinttab[9*4+2]
;     mov  word ptr _oldint+2, ax
;     xchg  bp,ax
;     jmp  _catchint
;_catch9 endp
;*************************************************************
; store processor status in buffer, display counter, ...
;
_catchint proc near
assume ds:nothing, es:nothing, ss:nothing

                        ; bp-02  flags 22
                        ; bp-04  CS    20
                        ; bp-06  IP    1e
;    push bp            ; bp-08  BP    1c  - done in 'catch xx' entrypoint

;    mov  bp, word ptr _buffer
;    cmp  bp, word ptr _maxbuf
;    jb   process_int
;    jmp  buf_full
; process_int:
     mov  bp,sp
     add  bp,8
     push bp            ; bp-0a  SP   1a
     push ss            ; bp-0c  SS   18
     push di            ; bp-0e  DI   16
     push es            ; bp-10  ES   14
     push si            ; bp-12  SI   12
     push ds            ; bp-14  DS   10
     push dx            ; bp-16  DX   0e
     push cx            ; bp-18  CX   0c
     push bx            ; bp-1a  BX   0a
     push ax            ; bp-1c  AX   08
     mov ax,cs
     mov ds,ax
assume ds:code
     mov  ax, word ptr _buffer
     cmp  ax, word ptr _maxbuf
     jb   process_int
     jmp  buf_full
process_int:

     call _gettime
     push dx            ; bp-1e  timH 06
     push ax            ; bp-20  timL 04
     mov  bl, _curintno
     xor  bh,bh
     shl  bx,1
     push _intcounter[bx]   ; bp-22  n    02
     mov  ah, _curint
     mov  al, RECSIZE   ;    length of record
     push ax            ; bp-24  int  00
     mov  si,sp
;     mov  byte ptr ss:[si], RECSIZE

     mov ah,[bp-23h]     ; intno
     mov al,[bp-1bh]     ; AH
     call _checkspecial
     cmp  _specialflag,0  ; no specials on cmdline -> copy all
     je   do_copy
     or   ax,ax           ; int-ah is not special -> don't copy
     je   skip_copy
     and  ah, _specialflag ; mask type
     jz   skip_copy

; all regs are copied into buffer
;  AL has to have special action value
do_copy:
     xor bx,bx
     mov bl,al
     shl bx,1
     jmp  _copyfunction[bx]
skip_copy:
     jmp end_of_copy

_copyfunction label word
     dw copy0, copy1, copy2, copy3
     dw copy4, copy5, copy6, copy7
     dw copy8, copy9, end_of_copy, copy0b
     dw copy0c, end_of_copy, end_of_copy, end_of_copy
     dw copy10, end_of_copy, end_of_copy, end_of_copy
;
; at end of movestring & copyregdata, DS is set to CS
; SS:SI -> points to start of register record on stack
;

copy0:    ; only copy registers
     call copyregdata
     jmp  end_of_copy

copy1:    ; append dssi [bp-14] string to buffer
     call copyregdata
     mov  si,[bp-12h]
     mov  ds,[bp-14h]
     mov  cx,MAXRECDATA
     mov  al,0dh
     call movestring
     jmp  end_of_copy

copy2:    ; append dsdx string to buffer
     call copyregdata
     mov  ds,[bp-14h]
     mov  si,[bp-16h]
     mov  cx,MAXRECDATA
     mov  al,0
     call movestring
     jmp  end_of_copy

copy3:    ; add DL to previous record
     mov ah,[bp-23h]     ; intno
     mov al,[bp-1bh]     ; AH
     les di, _lastentry
     cmp ah,es:[di+1]       ; check if lastentry was the same
     jne copyanyway
     cmp al,es:[di+9]
     jne copyanyway
     mov al,[bp-16h]     ; DL register
     mov cl,es:[di]
     mov ch,0
     cmp cx,MAXRECSIZE   ; maximum length in one record
     jge copyanyway
     inc  byte ptr es:[di]
     les di, _buffer
     stosb
     mov  word ptr _buffer, di
     jmp end_of_copy
copyanyway:
     call copyregdata
     jmp end_of_copy

copy4:    ; append dssi Zstring to buffer
     call copyregdata
     mov  si,[bp-12h]
     mov  ds,[bp-14h]
     mov  cx,MAXRECDATA
     mov  al,0
     call movestring
     jmp  end_of_copy

copy5:    ; append esdi, dsdx Zstring to buffer
     call copyregdata
     mov  si,[bp-0eh]    ; copy esdi string
     mov  ds,[bp-10h]
     mov  cx,MAXRECDATA
     mov  al,0
     call movestring

     mov  ds,[bp-14h]    ; copy dsdx string
     mov  si,[bp-16h]
     mov  cx,MAXRECDATA
     mov  al,0
     call movestring
     jmp  end_of_copy

copy6:    ; append $string from DS:DX (output console string)
     call copyregdata
     mov  ds,[bp-14h]    ; copy dsdx string
     mov  si,[bp-16h]
     mov  cx,MAXRECDATA
     mov  al,'$'
     call movestring
     jmp  end_of_copy

copy7:    ; append dssi, dsbx string to buffer if int2fae
     call copyregdata
     mov  si,[bp-12h]    ; copy dssi string
     mov  ds,[bp-14h]
     mov  cl,ds:[si]
     xor  ch,ch
     mov  al,0
     call movestring

     mov  ds,[bp-14h]    ; copy dsbx string
     mov  si,[bp-1ah]
     inc  si             ; skip one byte
     mov  cl,ds:[si]
     xor  ch,ch
     mov  al,0dh
     call movestring
     jmp  end_of_copy

copy8:   ; copy CX bytes from ds:si
     call copyregdata
     mov ds,[bp-14h]
     mov si,[bp-12h]
     mov cx,[bp-18h]
     xor ch,ch
     call movememory
     jmp end_of_copy

copy9:   ; copy novell packet from ds:si
     call copyregdata
     mov ds,[bp-14h]
     mov si,[bp-12h]
     mov cx,ds:[si]
     xor ch,ch
     add si,2
     call movememory
     jmp end_of_copy

copy10:   ; append dssi string to buffer  if int2f1123
     call copyregdata
     cmp  byte ptr [bp-1ch],023h
     jne  nocopy
     mov  ds,[bp-14h]
     mov  si,[bp-12h]
     mov  cx,MAXRECDATA
     mov  al,0
     call movestring
     jmp  end_of_copy

copy0b:    ; append 12 bytes from dsdx
     call copyregdata
     mov  ds,[bp-14h]    ; copy dsdx string
     mov  si,[bp-16h]
     mov  cx, 12
     mov  al,0
     call movestring
     jmp  end_of_copy

copy0c:    ; append 24 bytes from dsdx
     call copyregdata
     mov  ds,[bp-14h]    ; copy dsdx string
     mov  si,[bp-16h]
     mov  cx, 24
     mov  al,0
     call movestring
     jmp  end_of_copy

nocopy:
     jmp  end_of_copy

end_of_copy:
     add  sp,8          ; remove local data
buf_full:
assume ds:code
     mov  bl, _curintno
     xor  bh,bh
     shl  bx,1
     inc  _intcounter[bx]
     mov  ax, _intcounter[bx]
     shl  bx,3
     mov  di,bx
     add  di,0eh
     mov  cx,5
     call _displaydec
     mov  al,_curint
     xor  ah,ah
     mov  cx,3
     call _displayhex
     mov  ax, _skipped_ints
     mov  cx,3
     mov  di,086h
     call _displaydec
;IIxxxxx IIxxxxx IIxxxxx IIxxxxx IIxxxxx IIxxxxx IIxxxxx IIxxxxx sss bbbbb nnnnn
     mov  ax, word ptr _buffer
     sub  ax, offset endofresidentcode
     mov  di, 092h
     mov  cx,6
     call _displaydec
     mov  ax, _nentries
     mov  di, 09eh
     mov  cx,6
     call _displaydec
     pop  ax
     pop  bx
     pop  cx
     pop  dx
     pop  ds
     pop  si
     pop  es
     pop  di
     pop  ss
     pop  bp
assume ds:nothing
     inc _active
     mov bp,sp
     mov bp,[bp+6]     ; restore flags (important)
     and bp,0fcffh     ; clear trace flag - (only nescesary when called by INT)
     push bp
     popf
     pop bp
     jmp _oldint
_catchint endp

;  this is where the buffer starts
;
endofresidentcode:

;*************************************************************
; initializes timer chip for usec timing
; input: -
; output: AL=0
;
_inittimer proc near
     mov al,34h
     out 43h,al
     mov al,0
     out 40h,al
     out 40h,al
     ret
_inittimer endp

;*************************************************************
; restore timer chip to normal mode
; input: -
; output: AL=0
;
_restoretimer proc near
     mov al,36h
     out 43h,al
     mov al,0
     out 40h,al
     out 40h,al
     ret
_restoretimer endp

prteoln proc near
     push ax
     push dx
     mov al,02h
     mov dl,0dh
     int 21h
     mov al,02h
     mov dl,0ah
     int 21h
     pop dx
     pop ax
     ret
prteoln endp

prthexw proc near
    push ax
    mov  al,ah
    call prthexb
    pop  ax
    call prthexb
    ret
prthexw endp

prthexb proc near
    aam  010h
    push ax
    mov  al,ah
    call prthexn
    pop  ax
    call prthexn
    ret
prthexb endp

prthexn proc near
    push dx
    mov ah,2
    add al,'0'
    cmp al,'9'
    jle outdigit
    add al,7
outdigit:
    mov dl,al
    int 021h
    pop dx
    ret
prthexn endp

;*************************************************************
; positions SI to next non space character, returns c=1 on endofline
;
_skipcmdspaces proc near
     or   cx,cx
     je   ret_eolskip
     cmp  byte ptr [si],' '
     jne  found_nonspace
     inc  si
     dec  cx
     jmp _skipcmdspaces
found_nonspace:
     clc
     ret
ret_eolskip:
     stc
     ret
_skipcmdspaces endp

;*************************************************************
; gets char pointed to by SI, if CX>0
;
_getcmdchar proc near
     or   cx, cx
     je   ret_eol
     lodsb
     dec cx
     clc
     ret

ret_eol:
     stc
     ret
_getcmdchar endp

;***********************************************************************
; translate cmdline data(DS:SI, l=CX) to hex number in AX
;
_gethex proc near
        push dx
        xor  dx,dx
        call _skipcmdspaces
        jb   gh_eol
gethexloop:
        mov  al,[si]
        call atoh
        jb   endgethex
        shl  dx,4
        or   dl,al
        inc  si
        loop gethexloop
endgethex:
        mov ax,dx
        pop dx
        clc
        ret
gh_eol:
        pop dx
        stc
        ret
_gethex endp

atoh proc near
        cmp al,'0'
        jl  isnothex
        cmp al,'9'
        ja  notdigit
        sub al,'0'
        clc
        ret
notdigit:
        cmp al,'A'
        jl isnothex
        cmp al,'F'
        ja isnotupperhex
        sub al,'A'-0ah
        clc
        ret
isnotupperhex:
        cmp al,'a'
        jl isnothex
        cmp al,'f'
        ja isnothex
        sub al,'a'-0ah
        clc
        ret
isnothex:
        stc
        ret
atoh endp

;*************************************************************
; install handler for interrupt in AL
;  - buffer and maxbuf are both 0 while installing ->
;    the catch routine is called but skipped due to full buffer
_install_handler proc near
     mov  di, _nints
     cmp  di,MAXINTS
     jae  cantinstall
     mov  _intnrs[di], al
     mov  ah,035h
     int  21h
     shl  di,1
     shl  di,1
     mov  word ptr _oldinttab[di], bx
     mov  word ptr _oldinttab[di+2], es
     mov  ah, 025h
     shr  di,1
     mov  dx, _catchtab[di]
     int  021h
     inc  _nints
     clc
     ret
cantinstall:
     stc
     ret
_install_handler endp

; checks for signature in segment ES:
check_sig proc near
        push si
        push di
        push cx
        mov  di,offset signature
        mov  si,di
        mov  cx,offset endsig-signature
        cld
        repe cmpsb              ; check for signature
        pop  cx
        pop  di
        pop  si
        ret
check_sig endp

;*************************************************************
; locate previously loaded catch by scanning through MCB's
;
_locate_catch proc near
     mov ah,052h
     int 21h
     mov bx,es:[bx-2]             ; get 1st mcb from dosvars

loc_loop:
     mov es,bx
assume es:mcbseg
     cmp  mcbflag,'M'
     je   testmcb
     cmp  mcbflag,'Z'    ; loop until invalid MCB encountered
     je   testmcb        ; this way UMB's are included in search
     jmp   signotfound
testmcb:
     add bx,word ptr es:mcblen
     inc bx
     mov ax,word ptr es:mcbowner  ; segment of owner of MCB
     mov dx,cs
     cmp ax,dx                    ; don't find myself
     je  loc_loop
     mov es,ax
assume es:nothing

     call check_sig
     jne  loc_loop

     clc
     ret
signotfound:
     stc
     ret
_locate_catch endp

calc_videoseg proc near
     mov ah, 0fh
     int 10h
     cmp al, 7
     je  nochange
     mov _video_seg,0b800h
nochange:
     ret
calc_videoseg endp

_commandchars label word
     dw  'I',  offset _install
     dw  'U',  offset _uninstall
     dw  'N',  offset _novellflag
     dw  'F',  offset _filerwflag
     dw  'O',  offset _fileocflag
     dw  'C',  offset _charflag
     dw  'D',  offset _dirflag
     dw  'A',  offset _allflag
     dw  'B',  offset _fcbflag
     dw  'S',  offset _diskflag
NCOMMANDS = ($ - _commandchars)/4

;*************************************************************
;  lookup cmdchar in AL in _cmdchar, return address in AX
;
_lookupcmd proc near
     push cx
     xor  ah,ah
     mov cx, NCOMMANDS
     mov di,offset _commandchars
cmdloop:
     scasw
     jz  foundcmd
     scasw
     loop cmdloop
     pop cx
     stc
     ret
foundcmd:
     mov ax,[di]
     pop cx
     clc
     ret
_lookupcmd endp

;*************************************************************
; startup
;
_init proc near
     call  calc_videoseg
     cld
     mov  si, offset psp_cmdline
     mov  cl, psp_cmdlen
     mov  ch, 0
     mov  di,si
     add  di,cx
     xor  al,al
     stosb               ; put 0 at end of command line
next_cmd:
     call _skipcmdspaces
     jb   unknowncmd
     call _getcmdchar
     and  al,0dfh        ; upper case
     call  _lookupcmd
     jb   unknowncmd
     jmp  ax

unknowncmd:
     mov  dx, offset txt_help
     jmp  exit_err

_novellflag:
     or  _specialflag, FLAGNOVELL
     jmp  next_cmd
_filerwflag:
     or  _specialflag, FLAGFILERW
     jmp  next_cmd
_fileocflag:
     or  _specialflag, FLAGFILEOC
     jmp  next_cmd
_charflag:
     or  _specialflag, FLAGCHAR
     jmp  next_cmd
_dirflag:
     or  _specialflag, FLAGDIRECT
     jmp  next_cmd
_fcbflag:
     or  _specialflag, FLAGFCB
     jmp  next_cmd
_diskflag:
     or  _specialflag, FLAGDISK
     jmp  next_cmd
_allflag:
     or  _specialflag, FLAGALL
     jmp  next_cmd

_install:
     mov  _maxbuf,0ff00h
     mov  word ptr _buffer, offset endofresidentcode
     mov  word ptr _buffer+2, cs
     call _locate_catch      ; ES now points to catch PSP
     mov  dx,offset txt_found
     jb   installloop
     jmp  exit_err
installloop:
     call _gethex
     jb   go_tsr             ; no more digits -> tsr
     call _install_handler   ; installs handler for INT [num]
     jnb  installloop
go_tsr:
     cmp  _nints,0
     je   _err_noints
     call _inittimer
     mov  dx, 01000h
     mov  ax,3100h
     inc  _active            ; activate int handlers
     int  21h
_err_noints:
     mov dx, offset msg_noints
     jmp exit_err

_uninstall:
     call _locate_catch      ; ES now points to catch PSP
     mov  dx,offset txt_notfound
     jnb  save_buffer
     jmp  exit_err
;
; first save buffer, restoring vectors might crash machine in some cases
;

save_buffer:
     call _skipcmdspaces    ; skip to file name
     jb   endsave_buf
     mov dx,si
     xor cx,cx              ; attributes
     mov ax,03c00h          ; create file
     int 21h
     mov bx,ax
     mov  dx, offset endofresidentcode
     lds cx,es:_buffer      ; cx=length, ds:dx=buffer
     sub  cx,dx
     mov ax,04000h
     int 21h                ; write file
     mov ax,03e00h          ; close file
     int 21h
endsave_buf:

     mov  di,es:_nints
rmvloop:
     or   di,di
     jz   endrmv
     dec  di
     mov  dx,es
     mov  al,es:_intnrs[di]
     mov  ah, 035h       ; es:bx
     int  21h
; make sure vector still pointing to catch
     mov  ax,es
     mov  es,dx
     shl  di,1
;  ax:bx = intvector,  dx:catchX = catch orig entry point
     cmp  ax,dx
     jne  vecchanged
     cmp  es:_catchtab[di],bx
     jne  vecchanged
     shl  di,1
     mov  dx,word ptr es:_oldinttab[di]
     mov  ds,word ptr es:_oldinttab[di+2]
     shr  di,2
     mov  al,es:_intnrs[di]
     mov  ah,025h
     int  21h
     mov  es:_intnrs[di],0ffh        ; mark as restored
     jmp rmvloop

vecchanged:
; here I should try to locate the vector in memory
; and change it. --- risky
     mov  dx, offset _msg_cantrestore
     mov  ah,09h
     push cs
     pop  ds
     int  21h
     shr  di,1
     mov  al,es:_intnrs[di]
     call prthexb
     call prteoln
     inc  dontuninstall
     jmp rmvloop
endrmv:
     mov dx,offset _msg_notremoved
     cmp dontuninstall,0
     je  releasemem
     jmp exit_err

releasemem:
     mov ax,04900h      ; free psp es:0000
     int 21h
     mov es,es:psp_envseg
     mov ax,04900h      ; free environment
     int 21h
     mov ax,4c00h
     int 21h

exit_err:
     mov   ah,9
     int   21h
     mov   ax,4c01h
     int   21h

do_help:
     mov  ah,9
     mov  dx,offset txt_help
     int  21h
     mov  ax,4c00h
     int 21h
_init endp

dontuninstall label byte       ; flag, set when uninstall not possible
        db  0
txt_notfound label byte
        db  'Catch not found.', 0dh, 0ah, '$'
txt_found label byte
        db  'Catch already running.', 0dh, 0ah, '$'
msg_noints label byte
        db  'No interrupts specified after I', 0dh, 0ah, '$'
_msg_cantrestore label byte
        db  'Cant restore vector $'
_msg_notremoved label byte
        db  'Catch is still resident!', 0dh, 0ah, '$'
_msg_eoln label byte
        db  0dh, 0ah, '$'
txt_help label byte
        db  'CATCH V2.1 - 1994 willem jan hengeveld', 0dh, 0ah
        db  'Usage: catch [ACFND]I intno_list ...', 0dh, 0ah
        db  '       C - include char i/o functions', 0dh, 0ah
        db  '       F - include file i/o functions', 0dh, 0ah
        db  '       N - include novell functions', 0dh, 0ah
        db  '       D - include directory functions', 0dh, 0ah
        db  '       O - include file open/close functions', 0dh, 0ah
        db  '       A - include all specials', 0dh, 0ah
        db  '       B - include FCB functions', 0dh, 0ah
        db  '       S - include set/getdrv', 0dh, 0ah
        db  '   or  catch U filename', 0dh, 0ah, '$'
code ends
        end start
