#include <stdio.h>
#include <stdlib.h>
#include <stdarg.h>
#include <fcntl.h>
#include <io.h>
/*
   change intnametab to an external list, in the same format
   as the storage list in catch.asm
*/
#define MAXRECSIZE 0x100

typedef unsigned int word;
typedef unsigned char byte;
struct int_rec {
  byte reclen;
  byte intno;
  int n;
  long time;
  word AX;
  word BX;
  word CX;
  word DX;
  word DS;
  word SI;
  word ES;
  word DI;
  word SS;
  word SP;
  word BP;
  word IP;
  word CS;
  word flags;
};

struct name_tab {
  int num;
  char *name;
};

#define N_INTFNNAMES (sizeof(intnametab)/sizeof(struct name_tab))
#pragma warn -pin
struct name_tab intnametab[]={
  0x1000, "Set video mode",
  0x1001, "Set cursor type",
  0x1002, "Set cursor position",
  0x1003, "Read cursor position",
  0x1004, "Read light pen",
  0x1005, "Select active display page",
  0x1006, "Scroll active page up",
  0x1007, "Scroll active page down",
  0x1008, "Read character and attribute at cursor",
  0x1009, "Write character and attribute at cursor",
  0x100a, "Write character at current cursor",
  0x100b, "Set color palette",
  0x100c, "Write graphics pixel at coordinate",
  0x100d, "Read graphics pixel at coordinate",
  0x100e, "Write text in teletype mode",
  0x100f, "Get current video state",
  0x1010, "Set/get palette registers (EGA/VGA)",
  0x1011, "Character generator routine (EGA/VGA)",
  0x1012, "Video subsystem configuration (EGA/VGA)",
  0x1013, "Write string (BIOS after 1/10/86)",
  0x1014, "Load LCD char font (convertible)",
  0x1015, "Return physical display parms (convertible)",
  0x101a, "Video Display Combination (VGA)",
  0x101b, "Video BIOS Functionality/State Information (MCGA/VGA)",
  0x101c, "Save/Restore Video State  (VGA only)",
  0x10fe, "Get DESQView/TopView Virtual Screen Regen Buffer",
  0x10ff, "Update DESQView/TopView Virtual Screen Regen Buffer",
  0x1300, "Reset disk system",
  0x1301, "Get disk status",
  0x1302, "Read disk sectors",
  0x1303, "Write disk sectors",
  0x1304, "Verify disk sectors",
  0x1305, "Format disk track",
  0x1306, "Format track and set bad sector flag",
  0x1307, "Format the drive starting at track",
  0x1308, "Get current drive parameters",
  0x1309, "Initialize 2 fixed disk base tables",
  0x130a, "Read long sector",
  0x130b, "Write long sector",
  0x130c, "Seek to cylinder",
  0x130d, "Alternate disk reset",
  0x130e, "Read sector buffer",
  0x130f, "Write sector buffer",
  0x1310, "Test for drive ready",
  0x1311, "Recalibrate drive",
  0x1312, "Controller ram diagnostic",
  0x1313, "Drive diagnostic",
  0x1314, "Controller internal diagnostic",
  0x1315, "Read disk type/DASD type",
  0x1316, "Disk change line status",
  0x1317, "Set dasd type for format",
  0x1318, "Set media type for format",
  0x1319, "Park fixed disk heads",
  0x131a, "Format ESDI drive unit",
  0x1400, "Initialize serial port parameters",
  0x1401, "Send character in AL",
  0x1402, "Receive character in AL",
  0x1403, "Get Serial port status",
  0x1404, "Extended initialize",
  0x1405, "Extended communication port control",
  0x1500, "Turn cassette motor on",
  0x1501, "Turn cassette motor off",
  0x1502, "Read blocks from cassette",
  0x1503, "Write blocks to cassette",
  0x150f, "PS/2 format periodic interrupt",
  0x1520, "PRINT.COM Critical region flag",
  0x1521, "PS/2 power on self test",
  0x1540, "Read / modify profiles",
  0x1541, "Wait on external event",
  0x1542, "Request system power off",
  0x1543, "Read system status",
  0x1544, "(De)activate internal modem power",
  0x154f, "Keyboard intercept",
  0x1580, "Device open",
  0x1581, "Device close",
  0x1582, "Program termination",
  0x1583, "Event wait",
  0x1584, "Joy-Stick support",
  0x1585, "System request key pressed",
  0x1586, "Elapsed time wait",
  0x1587, "Move block to/from extended memory",
  0x1588, "Extended memory size determination",
  0x1589, "Switch processor to protected mode",
  0x1590, "Device busy",
  0x1591, "Interrupt complete",
  0x15c0, "Return system configuration parameters",
  0x15c1, "Return extended BIOS data address",
  0x15c2, "Pointing device BIOS interface",
  0x15c3, "Enable/Disable watchdog timer",
  0x15c4, "Programmable option select",
  0x1600, "Wait for keystroke and read",
  0x1601, "Get keystroke status",
  0x1602, "Get shift status",
  0x1603, "Set keyboard typematic rate",
  0x1604, "Keyboard click adjustment",
  0x1605, "Keyboard buffer write",
  0x1610, "Wait for keystroke and read",
  0x1611, "Get keystroke status",
  0x1612, "Get shift status",
  0x1700, "Print character",
  0x1701, "Initialize printer port",
  0x1702, "Read printer port status",
  0x1a00, "Read system clock counter",
  0x1a01, "Set system clock counter",
  0x1a02, "Read real time clock time",
  0x1a03, "Set real time clock time",
  0x1a04, "Read real time clock date",
  0x1a05, "Set real time clock date",
  0x1a06, "Set real time clock alarm",
  0x1a07, "Reset real time clock alarm",
  0x1a08, "Set RTC activated power on mode",
  0x1a09, "Read RTC alarm time and status",
  0x1a0a, "Read system day counter",
  0x1a0b, "Set system day counter",
  0x1a80, "Set up sound multiplexer",
  0x2100, "terminate program",
  0x2101, "read character from standard input, with echo",
  0x2102, "write character to standard output",
  0x2103, "read character from stdaux",
  0x2104, "write character to stdaux",
  0x2105, "write character to printer",
  0x2106, "direct console i/o",
  0x2107, "direct character input, without echo",
  0x2108, "character input without echo",
  0x2109, "write string to standard output",
  0x210a, "buffered input",
  0x210b, "get stdin status",
  0x210c, "flush buffer and read standard input",
  0x210d, "disk reset",
  0x210e, "select default drive",
  0x210f, "open file using fcb",
  0x2110, "close file using fcb",
  0x2111, "find first matching file using fcb",
  0x2112, "find next matching file using fcb",
  0x2113, "delete file using fcb",
  0x2114, "sequential read from fcb file",
  0x2115, "sequential write to fcb file",
  0x2116, "create or truncate file using fcb",
  0x2117, "rename file using fcb",
  0x2118, "null function for cp/m compatibility",
  0x2119, "get current default drive",
  0x211a, "set disk transfer area address",
  0x211b, "get allocation information for default drive",
  0x211c, "get allocation information for specific drive",
  0x211d, "null function for cp/m compatibility",
  0x211e, "null function for cp/m compatibility",
  0x211f, "get drive parameter block for default drive",
  0x2120, "null function for cp/m compatibility",
  0x2121, "read random record from fcb file",
  0x2122, "write random record to fcb file",
  0x2123, "get file size for fcb",
  0x2124, "set random record number for fcb",
  0x2125, "set interrupt vector",
  0x2126, "create new program segment prefix",
  0x2127, "random block read from fcb file",
  0x2128, "random block write to fcb file",
  0x2129, "parse filename into fcb",
  0x212a, "get system date",
  0x212b, "set system date",
  0x212c, "get system time",
  0x212d, "set system time",
  0x212e, "set verify flag",
  0x212f, "get disk transfer area address",
  0x2130, "get dos version",
  0x2131, "terminate and stay resident",
  0x2132, "get dos drive parameter block for specific drive",
  0x2133, "get/set break checking",
  0x2134, "get address of indos flag",
  0x2135, "get interrupt vector",
  0x2136, "get free disk space",
  0x2137, "get/set switchchar",
  0x2138, "get/set country-specific information",
  0x2139, "'mkdir' - create subdirectory",
  0x213a, "'rmdir' - remove subdirectory",
  0x213b, "'chdir' - set current directory",
  0x213c, "'creat' - create or truncate file",
  0x213d, "'open' - open existing file",
  0x213e, "'close' - close file",
  0x213f, "'read' - read from file or device",
  0x2140, "'write' - write to file or device",
  0x2141, "'unlink' - delete file",
  0x2142, "'lseek' - set current file position",
  0x2143, "get/set fileattributes",
  0x2144, "device ioctl",
  0x2145, "'dup' - duplicate file handle",
  0x2146, "'dup2', 'forcedup' - force duplicate file handle",
  0x2147, "'cwd' - get current directory",
  0x2148, "allocate memory",
  0x2149, "free memory",
  0x214a, "resize memory block",
  0x214b, "load/execute programs",
  0x214c, "'exit' - terminate with return code",
  0x214d, "get return code (errorlevel)",
  0x214e, "'findfirst' - find first matching file",
  0x214f, "'findnext' - find next matching file",
  0x2150, "set current process id (set psp address)",
  0x2151, "get current process id (get psp address)",
  0x2152, "'sysvars' - get list of lists",
  0x2153, "translate bios parameter block to drive param block",
  0x2154, "get verify flag",
  0x2155, "create child psp",
  0x2156, "'rename' - rename file",
  0x2157, "get/set file dat/time/attribs",
  0x2158, "get/set memory alloc strategy",
  0x2159, "get extended error information",
  0x215a, "create temporary file",
  0x215b, "create new file",
  0x215c, "record locking",
  0x215d, "share/network stuff",
  0x215e, "network stuff",
  0x215f, "network stuff",
  0x2160, "'truename' - canonicalize filename or path",
  0x2161, "unused",
  0x2162, "get current psp address",
  0x2163, "fareast double byte chars",
  0x2164, "set device driver lookahead flag",
  0x2165, "get extended country information/char handling",
  0x2166, "get/set global code page table",
  0x2167, "set handle count",
  0x2168, "'fflush' - commit file",
  0x2169, "get/set disk serial number",
  0x216a, "commit file",
  0x216b, "null function",
  0x216c, "extended open/create",
  0x216d, "find first rom program",
  0x216e, "find next rom program",
  0x216f, "get/set rom scan start address",
  0x21e0, "(e0)NWprinter",
  0x21e1, "(e1)NWMessage",
  0x21e2, "(e2)NWDirectory",
  0x21e3, "(e3)NWConnect",
  0x21ef, "(ef)NWWorkstation",
  0x21f0, "(f0)NWWSConnection",
  0x21f1, "(f1)NWAttach",
  0x21f2, "(f2)NWReq",
  0x2a00, "Network installation query",
  0x2a01, "Execute NETBIOS request with no error retry",
  0x2a02, "Set network printer mode",
  0x2a03, "Check if direct I/O allowed",
  0x2a04, "Execute NETBIOS request",
  0x2a05, "Get network resource information",
  0x2a06, "Network print stream control",
  0x2a80, "begin dos critical section",
  0x2a80, "Begin DOS critical section",
  0x2a81, "end dos critical section",
  0x2a81, "End DOS critical section",
  0x2a82, "end dos critical sections 0 through 7",
  0x2a82, "End DOS critical sections 0 through 7",
  0x2a84, "keyboard busy loop",
  0x2a84, "Keyboard busy loop",
  0x2a87, "begin/end background printing",
  0x2a87, "Critical section",
  0x2f00, "PRINT.COM",
  0x2f01, "PRINT.COM",
  0x2f02, "PC LAN",
  0x2f05, "Critical Error handler",
  0x2f06, "ASSIGN",
  0x2f08, "DRIVER.SYS",
  0x2f10, "SHARE",
  0x2f11, "Network redirector",
  0x2f12, "internal dos",
  0x2f13, "set DISK irq handler",
  0x2f14, "NLSFUNC",
  0x2f15, "GRAPHICS.COM/CDROM",
  0x2f16, "MS Windows",
  0x2f17, "MS Windows OldAp",
  0x2f19, "SHELLB",
  0x2f1a, "ANSI.SYS",
  0x2f1b, "XMA2EMS.SYS",
  0x2f2e, "Error Translation Tables",
  0x2f40, "MS Windows/OS2",
  0x2f43, "HIMEM.SYS",
  0x2f48, "DOSKEY",
  0x2fb7, "APPEND",
  0x2fd2, "QRAM",
  0x3300, "Mouse Reset/Get Mouse Installed Flag",
  0x3301, "Show Mouse Cursor",
  0x3302, "Hide Mouse Cursor",
  0x3303, "Get Mouse Position and Button Status",
  0x3304, "Set Mouse Cursor Position",
  0x3305, "Get Mouse Button Press Information",
  0x3306, "Get Mouse Button Release Information",
  0x3307, "Set Mouse Horizontal Min/Max Position",
  0x3308, "Set Mouse Vertical Min/Max Position",
  0x3309, "Set Mouse Graphics Cursor",
  0x330a, "Set Mouse Text Cursor",
  0x330b, "Read Mouse Motion Counters",
  0x330c, "Set Mouse User Defined Subroutine and Input Mask",
  0x330d, "Mouse Light Pen Emulation On",
  0x330e, "Mouse Light Pen Emulation Off",
  0x330f, "Set Mouse Mickey Pixel Ratio",
  0x3310, "Mouse Conditional OFF",
  0x3313, "Set Mouse Double Speed Threshold",
  0x3314, "Swap interrupt subroutines",
  0x3315, "Get mouse driver state and memory requirements",
  0x3316, "Save mouse driver state",
  0x3317, "Restore mouse driver state",
  0x3318, "Set alternate subroutine call mask and address",
  0x3319, "Get user alternate interrupt address",
  0x331a, "Set mouse sensitivity",
  0x331b, "Get mouse sensitivity",
  0x331c, "Set mouse interrupt rate",
  0x331d, "Set mouse CRT page",
  0x331e, "Get mouse CRT page",
  0x331f, "Disable mouse driver",
  0x3320, "Enable mouse driver",
  0x3321, "Reset mouse software",
  0x3322, "Set language for messages",
  0x3323, "Get language number",
  0x3324, "Get driver version, mouse type & ~IRQ~ number",
  0x6740, "Get EMM Status",
  0x6741, "Get Page Frame Base Address",
  0x6742, "Get Page Counts",
  0x6743, "Get Handle and Allocate Pages",
  0x6744, "Map Logical Page Into Physical Page Window",
  0x6745, "Release Handle and Memory Pages",
  0x6746, "Get EMM Version",
  0x6747, "Save Page Map Context",
  0x6748, "Restore Page Map Context",
  0x6749, "Get I/O Port Addresses",
  0x674a, "Get Logical to Physical Page Mapping",
  0x674b, "Get Handle Count",
  0x674c, "Get Page Count for Handle",
  0x674d, "Get Page Count for All Handles",
  0x674e, "Get/Set Page Map Context",
  0x674f, "Get/Set Partial Page Map",
  0x6750, "Map/Unmap Multiple Handle Pages",
  0x6751, "Reallocate Pages",
  0x6752, "Get/Set Handle Attributes",
  0x6753, "Get/Set Handle Name",
  0x6754, "Get Handle Directory",
  0x6755, "Alter Page Map and Jump",
  0x6756, "Alter Page Map and Call",
  0x6757, "Move/Exchange Memory Region",
  0x6758, "Get Mappable Physical Address Array",
  0x6759, "Get Expanded Memory Hardware Information",
  0x675a, "Allocate Standard/Raw Pages",
  0x675b, "Alternate Map Register Set DMA Registers",
  0x675c, "Prepare Expanded Memory for Warm Boot",
  0x675d, "Enable/Disable OS Functions",
  0x6760, "Get Physical Window Array"
};
#pragma warn +pin

#define N_INTNAMES (sizeof(interruptlist)/sizeof(struct name_tab))
#pragma warn -pin
struct name_tab interruptlist[]={
  0x00, "Divide by zero",
  0x01, "Single step",
  0x02, "Non-maskable  (NMI)",
  0x03, "Breakpoint",
  0x04, "Overflow trap",
  0x05, "BOUND range exceeded/printscreen",
  0x06, "Invalid opcode",
  0x07, "Coprocessor not available",
  0x08, "CPU Double fault/timer",
  0x09, "Copr. seg overrun/keyboard",
  0x0A, "Invalid task state segment/2nd 8259/EGA",
  0x0B, "Segment not present/COM2/COM4",
  0x0C, "Stack exception/COM1/COM3",
  0x0D, "General protection ex./XT HD/LPT2",
  0x0E, "Page fault/FD",
  0x0F, "Reserved/LPT1",
  0x10, "video/Coprocessor error",
  0x11, "Equipment",
  0x12, "memory size",
  0x13, "disk services",
  0x14, "serial port",
  0x15, "system services",
  0x16, "keyboard services",
  0x17, "parallel printer",
  0x18, "ROM BASIC loader",
  0x19, "bootstrap loader",
  0x1a, "time of day",
  0x1b, "ctrl-break handler",
  0x1c, "clock tick handler",
  0x1d, "6845 video parameter pointer",
  0x1e, "DRIVPARM table",
  0x1f, "CHARACTER table",
  0x20, "Exit program",
  0x21, "DOS functions",
  0x22, "Termination address",
  0x23, "BREAK handler",
  0x24, "Critical Error Handler",
  0x25, "Absolute Disk read",
  0x26, "Absolute Disk Write",
  0x27, "Terminate & Stay Resident",
  0x28, "DOS IDLE",
  0x29, "Fast console output",
  0x2A, "NETBIOS",
  0x2E, "exec command",
  0x2F, "multiplexer",
  0x31, "DOS Protected Mode Interface",
  0x33, "mouse support",
  0x3F, "overlay manager",
  0x40, "hard disk",
  0x41, "HD0 parameters",
  0x42, "relocated video handler",
  0x43, "user font table",
  0x44, "graph charmap",
  0x46, "HD1 parameters",
  0x48, "PCjr cordless keyboard translation",
  0x49, "PCjr non-keyboard scancode translation table",
  0x4A, "user alarm",
  0x50, "periodic alarm from timer",
  0x59, "GSS Computer Graphics Interface",
  0x5A, "cluster adapter BIOS entry point",
  0x5B, "cluster adapter boot",
  0x5C, "NETBIOS interface, TOPS interface",
  0x67, "LIM/EMS specification",
  0x68, "APPC",
  0x6C, "DOS 3.2 real time clock update",
  0x70, "real time clock",
  0x71, "software redirected to IRQ2",
  0x74, "mouse interrupt",
  0x75, "coprocessor",
  0x76, "AT HD"
};
#pragma warn +pin

int namecmp(const void *key, const void *elem)
{
  if (((struct name_tab *)key)->num < ((struct name_tab *)elem)->num)
    return -1;
  else if (((struct name_tab *)key)->num > ((struct name_tab *)elem)->num)
    return 1;
  else
    return 0;
}

// return name found in <tab>, size of <tab> is <size>
// using binary search -> <tab> must be sorted
char *getstring(struct name_tab *tab, int id, int size)
{
//  int first=0;
//  int last=size-1;
//  int middle;
  struct name_tab *p;
  struct name_tab key;
  key.num=id;

  p=bsearch(&key, tab, size, sizeof(struct name_tab), namecmp);
  if (p)
    return p->name;
  else
    return NULL;
//  while (last!=first)
//  {
//    middle=(last+first)/2;
//    if (tab[middle].num==id) return tab[middle].name;
//    if (tab[middle].num<id)
//      first=middle;
//    else
//      last=middle;
//  }
  return NULL;
}

void printrec(struct int_rec *p)
{
  char *data=(char *)p+sizeof(*p);
  int i;
  char *name;
  int  namehash;
  int outside=1;
  printf("%6d %08lx ", p->n, p->time);
  printf("%04x %04x:%04x %04x:%04x %04x %04x:%04x %04x:%04x ", p->flags,
    p->CS, p->IP, p->SS, p->SP, p->BP, p->DS, p->SI, p->ES, p->DI);
  printf("%04x %04x %04x  %02x %04x",
    p->BX, p->CX, p->DX, p->intno, p->AX);
  namehash=((p->AX>>8)&0xff)|(p->intno<<8);
  name=getstring(intnametab, namehash, N_INTFNNAMES);
  if (name==NULL) name=getstring(interruptlist, p->intno, N_INTNAMES);
  if (name==NULL) name="?";
  printf("%s", name);
  if (p->reclen>sizeof(*p))
  {
    for (i=sizeof(*p) ; i<(int)p->reclen ; i++)
      if (*data<' ')
      {
        if (!outside)
        {
          printf("\" ");
          outside=1;
        }
        printf("%02x ",0xff & (*data++));
      }
      else
      {
        if (outside)
        {
          printf(" \"");
          outside=0;
        }
        putchar(*data++);
      }
    if (!outside) printf("\"");
  }
  putchar('\n');
}

int usage(char *s, ...)
{
  va_list ap;
  va_start(ap,s);
  vprintf(s,ap);
  va_end(ap);
  printf("Usage: lstcatch [-h] catchfile\n");
  return 1;
}

int main(int argc, char **argv)
{
  char *dmpname=NULL;
  int f;
  char data[MAXRECSIZE];
  struct int_rec *buf;
  long t0;

  while (argc>1)
  {
    if (argv[1][0]=='-')
    switch(argv[1][1])
    {
      case 'h': return usage("Help screen\n");
      default:  return usage("Invalid option: %s\n", argv[1]);
    }
    else if (dmpname==NULL)
      dmpname=argv[1];
    else
      return usage("Too many parameters: %s\n", argv[1]);

    argc--; argv++;
  }
  if (dmpname==NULL)
    return usage("You have to specify catch dumpfile\n");

  f=open(dmpname, O_RDONLY|O_BINARY);
  if (f<0) { perror(dmpname); return 1; }

//  printf("                 time       CS   IP   SS   SP   BP   DS   SI   ES   DI   AX   BX   CX   DX   flag\n");
  printf("                 time   flag  CS   IP   SS   SP   BP   DS   SI   ES   DI   BX   CX   DX  int  AX\n");

  t0=0;
  while (!eof(f))
  {
    read(f,data, sizeof(*buf));
    buf=(struct int_rec *)data;
    if (t0)
      printf("%8lx ", (buf->time)-t0);
    else
      printf("         ");
    t0=buf->time;
    if (buf->reclen>sizeof(*buf))
      read(f, data+sizeof(*buf), buf->reclen-sizeof(*buf));
    printrec(buf);
  }
  return close(f);
}
