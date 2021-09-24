; FileIO.ASM      V1.0  -  9 feb 1994
;             special purpose version of catch.asm
;                  by   - Willem Jan Hengeveld
;               email   - willem@dutikos.twi.tudelft.nl
;               phone   - +31-15-617267
;
;  a program to log all calls to interrupts specified on the command line
;
;  Usage: fileio
;
;         fileio u <filename>
;
; 14-2-94 : fixed gettime
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

mcbseg segment at ?
  mcbflag           db ?
  mcbowner          dw ?
  mcblen            dw ?
mcbseg ends

RECSIZE    equ 024h      ; # words in default record
MAXRECSIZE equ 0e0h
MAXINTS    equ 1         ; # int buffers
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
        db 'interrupt$fileIO'
label endsig byte

even      ; for speed
_intcounter label word
     dw   0
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
_oldint  label dword
     dd   0
_video_seg label word
     dw   0b000h
_specialonly label byte    ; commandline flag
     db   0
assume ds:nothing, es:nothing, ss:nothing
;*************************************************************
; convert ax -> ascii string and print at position di on topline of screen
; input: AX, DI
; return:  BX=0a, CX=0, AX=?? DX=0, DI=??  ES=video
;
_display proc near
     mov bx,_video_seg
     mov es,bx
     mov bx,0ah
     mov cx,5
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
     mov ax,7020h
     rep stosw
     ret
_display endp

;*************************************************************
; read microsecond accuracy timer
; input: -
; output: DX:AX = time
;
_gettime proc near
     push bp
     push ds
     mov  bp,sp
     mov  ax,40h
     mov  ds,ax
assume ds:biosseg
     push biosTimerL  ; bp-2
     mov  al,4
     out  43h,al
     in   al,40h
     mov ah,al
     in   al,40h
     push ax          ; bp-4

     push biosTimerL  ; bp-6
     mov  al,4
     out  43h,al
     in   al,40h
     mov ah,al
     in   al,40h
     push ax          ; bp-8

     mov  ax,[bp-02h]
     xor  ax,[bp-06h]        ; timrL2 != timrL1
     jnz  tmr_unequal
     mov  dx,[bp-02h]        ; take first
     mov  ax,[bp-04h]
     jmp  end_tmr
tmr_unequal:
     mov  dx,[bp-06h]        ; take second
     mov  ax,[bp-08h]
end_tmr:
     xchg ah,al
     not  ax
     mov  sp,bp
     pop  ds
     pop  bp
     ret
_gettime endp

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

;*************************************************************
; table with actions for special values
;    0 - normal
;    1 - copy ascii0d from dssi
;    2 - copy asciiz string from dsdx
;    3 - append <DL> to previous
;    4 - copy asciiz string from dssi         (ext open)
;    5 - copy Zstr from essi, Zstr from dsdx  (rename)
;    6 - copy $str from DS:DX
_action  label byte
      db   3, 3, 3, 3, 6, 3, 0, 1, 2, 2, 2, 2, 2, 0, 0, 0
      db   2, 0, 2, 0, 2, 2, 2, 5, 2, 2, 0, 4
;*************************************************************
; table with values for intno & AH which require special action
;
_special label word
      dw  02102h ; 3      ch -> CON  (DL)
      dw  02104h ; 3      ch -> AUX  (DL)
      dw  02105h ; 3      ch -> PRN  (DL)
      dw  02106h ; 3      console io (DL)
      dw  02109h ; 6      $str ->CON  (DS:DX)
      dw  0210eh ; 3      setdrv   (DL)
      dw  02119h ; 0      getdrv   (       -> AL)
      dw  02129h ; 1      parse fn (DS:SI)
      dw  02139h ; 2      mkdir    (DS:DX)
      dw  0213ah ; 2      rmdir    (DS:DX)
      dw  0213bh ; 2      chdir    (DS:DX)
      dw  0213ch ; 2      _create  (DS:DX, attr=CX)   (AX)
      dw  0213dh ; 2      open     (DS:DX, mode=al)   (AX)
      dw  0213eh ; 0      close    (handle=BX)
      dw  0213fh ; 0      read     (handle=BX, CX=nbytes, DS:DX=buf)
      dw  02140h ; 0      write    (handle=BX, CX=nbytes, DS:DX=buf)
      dw  02141h ; 2      delete   (DS:DX)
      dw  02142h ; 0      lseek    (handle=BX, CXDX=offset, AL=origin)
      dw  02143h ; 2      attrib   (DS:DX, AL=get/set, CX=attrib)
      dw  02147h ; 0      getcwd   (drive=DL, buf=DS:SI)
      dw  0214bh ; 2      exec     (DS:DX)
      dw  0214eh ; 2      findfirst(DS:DX, CX=attr)
      dw  0214fh ; 2      findnext (DS:DX)
      dw  02156h ; 5      rename   (DS:DX -> ES:DI)
      dw  0215ah ; 2      mktemp   (DS:DX, attr=CX)
      dw  0215bh ; 2      create   (DS:DX, attr=CX)
      dw  0215ch ; 0      lock     (handle=BX, AL=fn, CXDX=start, SIDI=length)
      dw  0216ch ; 4      extend open (DS:SI, BX=mode, CX=attr, DX=fn)

;*************************************************************
;  checks if AX contains special int function  CX and DI are destroyed
;  input: AX
;  output: AX=??, CX=??, DI=??
;
_checkspecial proc near
      mov cx, offset _special - offset _action
      mov di, 0
checkloop:
      cmp  _special[di], ax
      jz   foundspecial
      inc  di
      inc  di
      loop checkloop
return0:
      mov  ax, 0ffh            ; code for no special
      ret
foundspecial:
      shr  di,1
      mov  al, _action[di]
      xor  ah, ah
      ret
_checkspecial endp

;*************************************************************
; movestring - copies string ds:si -> es:di, adjust length of record
; maximum length=CX,  terminating char=AL  or 0
; input: DS:SI, AL, CX
; output: CX,  SI=si+CX, DI=lastentry, AH=al
movestring proc near
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
     mov di,word ptr _lastentry
     add  es:[di], cl             ; adjust record length
     ret
movestring endp
;*************************************************************
; store processor status in buffer, display counter, ...
;
_catchint proc near
assume ds:nothing, es:nothing, ss:nothing

                        ; bp-02  flags 22
                        ; bp-04  CS    20
                        ; bp-06  IP    1e
     push bp            ; bp-08  BP    1c  - done in 'catch xx' entrypoint

;     mov  bp, word ptr _buffer
;     cmp  bp, word ptr _maxbuf
;     jb   process_int
;     jmp  buf_full
;process_int:
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
     mov  ax, word ptr _buffer
     cmp  ax, word ptr _maxbuf
     jb   process_int
     jmp  buf_full
process_int:
     call _gettime
     push dx            ; bp-1e  timH 06
     push ax            ; bp-20  timL 04
     push _intcounter   ; bp-22  n    02
     mov  ax, 2100h
     push ax            ; bp-24  int  00
     mov  si,sp
     mov  byte ptr ss:[si], RECSIZE
;    mov ah,[bp-23h]     ; intno
     mov al,[bp-1bh]     ; AH
     call _checkspecial
     cmp  al,0ffh
     je   skip_copy
     cmp  al,3
     jne  normal_copy
     jmp   append_to_prev
skip_copy:
     jmp   end_of_copy
; all regs are copied into buffer
;  AL has to have special action value
normal_copy:
     inc  _nentries
     les  di, dword ptr _buffer
     mov  word ptr _lastentry, di
     mov  word ptr _lastentry+2, es
     push ss
     pop  ds
     mov  cx,RECSIZE              ; move bytes because SP might be odd
     rep  movsb                   ; mov [sp=ffff] .. causes GPI
     mov  word ptr _buffer, di

; process further copy specifications

     cmp  al,0
     je   go_endoc

checkal1:
     cmp  al,1
     jne  checkal2

; append dssi EOLstring to buffer
     mov  si,[bp-12h]
     mov  ds,[bp-14h]
     mov  cx,MAXRECDATA
     mov  al,0dh
     call movestring
go_endoc:
     jmp  end_of_copy

checkal2:
     cmp  al,2
     jne  checkal4

; append dsdx Zstring to buffer
     mov  ds,[bp-14h]
     mov  si,[bp-16h]
     mov  cx,MAXRECDATA
     mov  al,0
     call movestring
     jmp  end_of_copy

checkal4:
     cmp  al,4
     jne  checkal5

; append dssi Zstring to buffer
     mov  si,[bp-12h]
     mov  ds,[bp-14h]
     mov  cx,MAXRECDATA
     mov  al,0
     call movestring
     jmp  end_of_copy

checkal5:
     cmp  al,5
     jne  checkal6

; append essi, dsdx Zstring to buffer if int2fae
     mov  si,[bp-12h]    ; copy essi string
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

checkal6:
     cmp  al,6
     jne  checkal7

; append $string from DS:DX (output console string)
     mov  ds,[bp-14h]    ; copy dsdx string
     mov  si,[bp-16h]
     mov  cx,MAXRECDATA
     mov  al,'$'
     call movestring
     jmp  end_of_copy

checkal7:
     jmp  end_of_copy


go_copy:
     mov  al,0           ; no further action
     jmp normal_copy

append_to_prev:
     mov ah,[bp-23h]     ; intno
     mov al,[bp-1bh]     ; AH
     les di, _lastentry
     cmp ah,es:[di+1]       ; check if lastentry was the same
     jne go_copy
     cmp al,es:[di+9]
     jne go_copy
     mov al,[bp-16h]     ; DL register
     mov cl,es:[di]
     mov ch,0
     cmp cx,MAXRECSIZE   ; maximum length in one record
     jge go_copy
     inc  byte ptr es:[di]
     les di, _buffer
     stosb
     mov  word ptr _buffer, di

end_of_copy:
     add  sp,8
buf_full:
     inc  _intcounter
     mov  ax, _intcounter
     mov  di,010h
     call _display
     mov  ax, word ptr _buffer
     mov  di, 092h
     call _display
     mov  ax, _nentries
     mov  di, 09eh
     call _display
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
     mov bp,sp
     mov bp,[bp+6]     ; restore flags (important)
     push bp
     popf
     pop bp
     jmp _oldint
_catchint endp

;*************************************************************
; install catch in memory
;
_tsr  proc near
     call _inittimer
     mov  _maxbuf,0ff00h
     mov  word ptr _buffer, offset endofresidentcode
     mov  word ptr _buffer+2, cs
     mov  dx, 01000h
     mov  ax,3100h
     int  21h
_tsr  endp
;  this is where the buffer starts
;
endofresidentcode:

;*************************************************************
; positions SI to next non space character, returns c=1 on endofline
;
_skipcmdspaces proc near
     or   cx,cx
     je   ret_eolskip
     mov  al, ' '
     push es
     push ds
     pop  es
     xchg  di,si
     repz scasb
     xchg  di,si
     pop  es
     jz  ret_eolskip
     dec  si
     inc  cx
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

_gethexbyte proc near
        call _skipcmdspaces
        jb   gh_eol
        lodsb
        dec   cx
        call atoh
        mov ah,al
        lodsb
        dec   cx
        call atoh
        aad  010h
        clc
        ret
atoh:
        cmp al,'9'
        jle atohend
        add al,9
atohend:
        and al,0fh
        ret

gh_eol:
        stc
        ret
_gethexbyte endp

;*************************************************************
; install handler for interrupt in AL
;  - buffer and maxbuf are both 0 while installing ->
;    the catch routine is called but skipped due to full buffer
_install_handler proc near
     mov  ax,03521h
     int  21h
     mov  word ptr _oldint, bx
     mov  word ptr _oldint+2, es
     mov  ax, 02521h
     mov  dx, offset _catchint     ; assumed: DS=CS
     int  21h
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
     cmp  mcbflag,'Z'
     je   signotfound
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
     jc   do_install
     call _getcmdchar
     and  al,0dfh        ; upper case
     cmp  al,'U'
     je   do_uninstall
do_install:
     cmp  al,'I'
     je   chkinstall
     jmp  do_help
chkinstall:
     call _locate_catch      ; ES now points to catch PSP
     mov  dx,offset txt_found
     jb   installloop
     jmp  exit_err
installloop:
     call _install_handler   ; installs handler for INT [num]
go_tsr:
     jmp  _tsr
do_uninstall:
     call _locate_catch      ; ES now points to catch PSP
     mov  dx,offset txt_notfound
     jb    exit_err
     push  es
     push  ds

     mov  dx,es
     mov  ax, 03521h
     int  21h
; make sure vector still pointing to catch
     mov  ax,es
     mov  es,dx
     cmp  ax,dx
     jne  vecchanged
     cmp  bx, offset _catchint
     jne  vecchanged
     mov  dx,word ptr es:_oldint
     mov  ds,word ptr es:_oldint+2
     mov  ax,02521h
     int  21h

vecchanged:
; here we should try to locate the vector in memory
; and change it. --- risky


endrmv:
;  now all ints have been restored, we can write buffer to a file
        pop   ds
        pop   es
        call _skipcmdspaces    ; skip to file name
        jb   releasemem
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
txt_notfound label byte
        db  'Catch not found.', 0dh, 0ah, '$'
txt_found label byte
        db  'Catch already running.', 0dh, 0ah, '$'
txt_help label byte
        db  'FILEIO V1.0 - 1994 willem jan hengeveld', 0dh, 0ah
        db  'Usage: fileio [I][U file]', 0dh, 0ah
        db  '       U - uninstall', 0dh, 0ah
        db  '       I - install', 0dh, 0ah, '$'
code ends

;        public _buffer:dword
;        public _maxints:word
;        public _intcounter:word
;        public _old21:dword
;        public _catch21
;        public _inittimer
;        public _restoretimer
        end start
