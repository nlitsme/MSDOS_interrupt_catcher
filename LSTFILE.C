#include <stdio.h>
#include <stdlib.h>
#include <stdarg.h>
#include <fcntl.h>
#include <io.h>

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

//  0 : string                     "%D"
//  1 : string + CX                "cx=%Rcx  %D"
//  2 : string + AL                "al=%Ral  %D"
//  3 : BX + CX + DSDX             "bx=%Rbx cx=%Rcx dsdx=%Rds:%Rdx"
//  4 : DL                         "dl=%Rdl"
//  5 : BX                         "bx=%Rbx"
//  6 : BX + AL + CXDX + SIDI      "bx=%Rbx al=%Ral cxdx=%Rcx%Rdx sidi=%Rsi%Rdi"
//  7 : BX + CXDX + AL             "bx=%Rbx cxdx=%Rcx%Rdx al=%Ral"
//  8 : string + AL + CX
//  9 : string + BX + CX + DX
// 10 : AL
// 11 : AL + DX
// 12 : AL + DSDX

//  new format:
//  %Rxx    xx = al,ah,bl,bh,cl,ch,dl,dh, ax,bx,cx,dx,si,di,bp,sp,ip,ds,es,cs,ss
//  %D      data
//  %S      Lascii string
//  %s      asciiZ string
//  %l      long
//  %L      long (NW order)
//  %w      word
//  %W      word (NW order)
//  %b      byte

struct name_tab {
  int num;
  char *name;
  char *format;
} intnametab[]={
  0x2102, "stdout",                "%D",
  0x2104, "stdaux",                "%D",
  0x2105, "prn",                   "%D",
  0x2106, "con",                   "%D",
  0x2109, "stdout",                "%D",
  0x210e, "setdrv",                "drive=%Rdl",
  0x210f, "FCB open",              "%D",
  0x2111, "FCB findfirst",         "%D",
  0x2112, "FCB findnext",          "%D",
  0x2113, "FCB delete",            "%D",
  0x2116, "FCB create",            "%D",
  0x2117, "FCB rename",            "%D", // 2 FCBname
  0x2119, "getdrv",                "",
  0x2123, "FCB getsize",           "%D",
  0x2125, "set vector",            "int %Ral = %Rds:%Rdx",
  0x2129, "parse",                 "%D",
  0x2131, "tsr",                   "err %Ral resident paragraphs %Rdx",
  0x2135, "get vector",            "int %Ral",
  0x2139, "mkdir",                 "%D",
  0x213a, "rmdir",                 "%D",
  0x213b, "chdir",                 "%D",
  0x213c, "creat",                 "attrib=%Rcx %D",
  0x213d, "open",                  "mode=%Ral, %D",
  0x213e, "close",                 "handle=%Rbx",
  0x213f, "read",                  "handle=%Rbx, buf=%Rds:%Rdx len=%Rcx",
  0x2140, "write",                 "handle=%Rbx, buf=%Rds:%Rdx len=%Rcx",
  0x2141, "unlink",                "%D",
  0x2142, "lseek",                 "from=%Ral handle=%Rbx offset=%Rcx%Rdx",
  0x2143, "fattr",                 "fn=%Ral, attrib=%Rcx  %D",
  0x2147, "getcwd",                "drive=%Rdl",
  0x214b, "exec",                  "subfn=%Ral, %D",  // no parameter block yet!
  0x214c, "exit",                  "err %Ral",
  0x214e, "findfirst",             "attrib=%Rcx %D",
  0x214f, "findnext",              "%D",
  0x2156, "rename",                "%D",  // 2 strings
  0x215a, "creattmp",              "attrib=%Rcx %D", ,
  0x215b, "creatnew",              "attrib=%Rcx %D", ,
  0x215c, "lock",                  "fn=%Ral handle=%Rbx offset=%Rcx%Rdx len=%Rsi%Rdi",
  0x2160, "get truename",          "%D",
  0x216c, "extended open/create",  "al=%Ral mode=%Rbl flags=%Rbh attr=%Rcx action=%Rdx %D",
  0x21e0, "(e0)NWprinter",         "%D",                  // expand
  0x21e1, "(e1)NWMessage",         "%D",                  // expand
  0x21e2, "(e2)NWDirectory",       "%D",                  // expand
  0x21e3, "(e3)NWConnect",         "%D",                  // expand
  0x21ef, "(ef)NWWorkstation",     "fn=%Ral",             // expand
  0x21f0, "(f0)NWWSConnection",    "fn=%Ral connid=%Rdl", // expand
  0x21f1, "(f1)NWAttach",          "fn=%Ral connid=%Rdl", // expand
  0x21f2, "(f2)NWReq",             "ncpfn=%Ral, %D",      // expand
  0x2f11, "Qualify",               "%D",
  0x2fae, "Network",               "%D",
  -1, NULL, -1
};

struct textID {
  int id;
  char *name;
};

struct textID int21f1[]={
  0x00, "Attach to FileServer",    // DL=conn
  0x01, "Detach from FileServer",  // DL=conn
  0x02, "Logout from FileServer",  // DL=conn
  -1,NULL
};

struct textID int21f0[]={
  0x00, "Set Preferred Connection ID",   // to DL
  0x01, "Get Preferred Connection ID",   // -> AL
  0x02, "Get Default Connection ID",     // -> AL
  0x03, "Get LPT Capture Status",        // -> AL, AH=flag
  0x04, "Set Primary Connection ID",     // to DL
  0x05, "Get Primary Connection ID",     // -> AL
  -1,NULL
};

struct textID int21ef[]={
  0x00, "Get Drive Handle Table",        // -> ESSI
  0x01, "Get Drive Flag Table",          // -> ESSI
  0x02, "Get Drive Connection Table",    // -> ESSI
  0x03, "Get Connection Table",          // -> ESSI
  0x04, "Get File Server Nametable",     // -> ESSI
  -1,NULL
};

struct textID NCPnames[]={
  0x01, "File Set Lock",
  0x02, "File Release Lock",
  0x03, "Log File(old)",
  0x04, "Lock File Set(old)",
  0x05, "Release File",
  0x06, "Release File Set",
  0x07, "Clear File",
  0x08, "Clear File Set",
  0x09, "Log Logical Record(old)",
  0x0a, "Lock Logical Record Set(old)",
  0x0b, "Clear Logical Record",
  0x0c, "Release Logical Record",
  0x0d, "Release Logical Record Set",
  0x0e, "Clear Logical Record Set",
  0x0f, "Allocate Resource",
  0x10, "Deallocate Resource",
  0x12, "Get Volume Info with Number",
  0x13, "Get Station Number",
  0x14, "Get File Server Date And Time",
  0x18, "End Of Job",
  0x19, "Logout",
  0x1a, "Log Physical Record(old)",
  0x1b, "Lock Physical Record Set(old)",
  0x1c, "Release Physical Record",
  0x1d, "Release Physical Record Set",
  0x1e, "Clear Physical Record",
  0x1f, "Clear Physical Record Set",
  0x21, "Negotiate Buffer Size",
  0x24, "Clear Record",
  0x3c, "Dup Handle",
  0x3d, "Commit File",
  0x3e, "File Search Initialize",
  0x3f, "File Search Continue",
  0x40, "Search For A File",
  0x41, "Open File OLD",
  0x42, "Close File",
  0x43, "Create File",
  0x44, "Erase File",
  0x45, "Rename File",
  0x46, "Set File Attributes",
  0x47, "Get Current File Size",
  0x48, "Read File",
  0x49, "Write File",
  0x4a, "Server File Copy",
  0x4b, "Set File Time Date Stamp",
  0x4c, "Open File",
  0x4d, "Create New File",
  0x4e, "Allow Task Access To File",
  0x4f, "Set File Extended Attributes",
  0x54, "Open Create File",
  0x55, "Get Sparse File Bit Map",
  0x61, "Get Big Packet NCP Max Packet Size",
  0x62, "Data Echo",
  0x63, "Native: Next Big Write",
  0x64, "Native: Big Read",
  0x65, "Packet Burst Connection",
  0x66, "Native: Big ReRead",
  0x67, "Native: Big Write",
  0x69, "Log File(new)",
  0x6a, "Lock File Set(new)",
  0x6b, "Log Logical Record(new)",
  0x6c, "Lock Logical Record Set(new)",
  0x6d, "Log Physical Record(new)",
  0x6e, "Lock Physical Record Set(new)",
  0x70, "Clear And Get Wait Lock Comp",
  0x72, "Time Sync Request (4.x only)",
  -1, NULL
};
struct textID NCP11fns[]={
  0x00, "Write To A Spool File",
  0x01, "Close Spool File",
  0x02, "Set Spool File Flags",
  0x03, "Spool A Disk File",
  0x04, "Get Spool Queue Entry",
  0x05, "Remove Entry From Spool Queue",
  0x06, "Get Printer Status",
  0x09, "Specify Capture File",
  0x0a, "Get Printer Queue",
-1, NULL
};

struct textID NCP15fns[]={
  0x00, "Send Broadcast Message(old)",
  0x01, "Get Broadcast Message(old)",
  0x02, "Disable Station Broadcasts",
  0x03, "Enable Station Broadcasts",
  0x04, "Send Personal Message",
  0x05, "Get Personal Message",
  0x06, "Open Message Pipe",
  0x07, "Close Message Pipe",
  0x08, "Check Pipe Status",
  0x09, "Broadcast to Console",
  0x0a, "Send Broadcast Message(new)",
  0x0b, "Get Broadcast Message(new)",
-1, NULL
};

struct textID NCP16fns[]={
  0x00, "Set Directory Handle",
  0x01, "Get Directory Path",
  0x02, "Scan Directory Information",
  0x03, "Get Effective Directory Rights(old)",
  0x04, "Modify Maximum Rights Mask",
  0x05, "Get Volume Number",
  0x06, "Get Volume Name",
  0x0a, "Create Directory",
  0x0b, "Delete Directory",
  0x0c, "Scan Directory For Trustees",
  0x0d, "Add Trustee to Directory",
  0x0e, "Delete Trustee From Directory",
  0x0f, "Rename Directory",
  0x10, "Purge Erased Files(old)",
  0x11, "Restore Erased File",
  0x12, "Allocate Permanent Directory Handle",
  0x13, "Allocate Temporary Directory Handle",
  0x14, "Deallocate Directory Handle",
  0x15, "Get Volume Info With Handle",
  0x16, "Allocate Special Temporary Directory Handle",
  0x17, "Save Directory Handle",
  0x18, "Restore Directory Handle",
  0x19, "Set Directory Information",
  0x1a, "Get Path From Directory Entry",
  0x1b, "Scan Salvageable Files(old)",
  0x1c, "Recover Salvageable File(old)",
  0x1d, "Purge Salvageable File(old)",
  0x1e, "Scan Dir Entry",
  0x1f, "Get Dir Entry",
  0x20, "Scan Volume For Restrictions",
  0x21, "Add User Disk Space Restriction",
  0x22, "Clear Volume Restrictions",
  0x23, "Get Dir Restrictions",
  0x24, "Set Dir Space Restriction",
  0x25, "Set Directory Entry Information",
  0x26, "Scan File or Dir for Extended Trustees",
  0x27, "Add Extended Trustee to File/Dir",
  0x28, "Scan Directory Disk Space",
  0x29, "Get Object Disk Restrictions",
  0x2a, "Get Effective Rights By Dir Entry",
  0x2b, "Delete Extended Trustee From Directory or File",
  0x2c, "Get Volume Usage",
  0x2d, "Get Dir Info",
  0x2e, "Move Entry",
  0x2f, "Get Name Space Buffer Information",
  0x30, "Get Name Space Directory Entry",
  0x31, "Open Data Stream",
  0x32, "Get Object Effective Rights",
  0x33, "Get Extended Volume Info",
-1, NULL
};

struct textID NCP17fns[]={
  0x00, "Login User Object",
  0x01, "Change User Password",
  0x02, "Get User Connection List(old)",
  0x03, "Map Object To Number",
  0x04, "Map Number To Object",
  0x05, "Get Connection Information(new)/Station Logged Info",
  0x08, "Map Number To Group Name",
  0x09, "Get Member Set M of Group G",
  0x0a, "Enter Login Area",
  0x0c, "Verify Network Serial Number",
  0x0d, "Log Network Message",
  0x0e, "Get Disk Utilization for Trustee",
  0x0f, "Scan File Information",
  0x10, "Set File Information",
  0x11, "Get File Server Information",
  0x11, "Recover Erased File(old)",
  0x12, "Get Network Serial Number",
  0x13, "Get Internet Address(old)",
  0x14, "Login Object",
  0x15, "Get Object Connection List(old)",
  0x16, "Get Connection Information(old)",
  0x17, "Get Encryption Key",
  0x18, "Login Object Encrypted",
  0x1a, "Get Internet Address(new)",
  0x1b, "Get Object Connection List(new)",
  0x1c, "Get Connection Information(new)/Station Logged Info",
  0x1d, "Change Connection State",
  0x1e, "Set Watchdog Delay Interval",
  0x1f, "Get Connection List From Object",
  0x32, "Create Bindery Object",
  0x33, "Delete Bindery Object",
  0x34, "Rename Bindery Object",
  0x35, "Get Bindery Object ID",
  0x36, "Get Bindery Object Name",
  0x37, "Scan Bindery Object",
  0x38, "Change Bindery Object Security",
  0x39, "Create Property",
  0x3a, "Delete Property",
  0x3b, "Change Property Security",
  0x3c, "Scan Property",
  0x3d, "Read Property Value",
  0x3e, "Write Property Value",
  0x3f, "Verify Bindery Object Password",
  0x40, "Change Bindery Object Password",
  0x41, "Add Bindery Object to Set",
  0x42, "Delete Bindery Object From Set",
  0x43, "Is Bindery Object In Set",
  0x44, "Close Bindery",
  0x45, "Open Bindery",
  0x46, "Get Bindery Access Level",
  0x47, "Scan Bindery Object Trustee Paths",
  0x48, "Get Bindery Object Access Level",
  0x49, "Is Station A Manager",
  0x4a, "Verify Bindery Object Password Encrypted",
  0x4b, "Change Bindery Object Password Encrypted",
  0x4c, "Get Relations of an Object",
  0x60, "PNW Specific",
  0x64, "Create Queue",
  0x65, "Destroy Queue",
  0x66, "Read Queue Current Status(old)",
  0x67, "Set Queue Current Status(old)",
  0x68, "Create Queue Job And File(old)",
  0x69, "Close File And Start Queue Job(old)",
  0x6a, "Remove Job From Queue(old)",
  0x6b, "Get Queue Job List(old)",
  0x6c, "Read Queue Job Entry(old)",
  0x6d, "Change Queue Job Entry(old)",
  0x6e, "Change Queue Job Position",
  0x6f, "Attach Queue Server To Queue",
  0x70, "Detach Queue Server From Queue",
  0x71, "Service Queue Job And Open File(old)",
  0x72, "Finish Servicing Queue Job(old)",
  0x73, "Abort Servicing Queue Job(old)",
  0x74, "Change To Client Rights(old)",
  0x75, "Restore Queue Server Rights",
  0x76, "Read Queue Server Current Status(old)",
  0x77, "Set Queue Server Current Status",
  0x78, "Get Queue Job File Size(old)",
  0x79, "Create Queue Job And File(new)",
  0x7a, "Read Queue Job Entry(new)",
  0x7b, "Change Queue Job Entry(new)",
  0x7c, "Service Queue Job(new)",
  0x7d, "Read Queue Current Status(new)",
  0x7e, "Set Queue Current Status(new)",
  0x7f, "Close File And Start Queue Job(new)",
  0x80, "Remove Job From Queue(new)",
  0x81, "Get Queue Job List(new)",
  0x82, "Change Queue Job Order/Priority",
  0x83, "Finish Servicing Queue Job(new)",
  0x84, "Abort Servicing Queue Job(new)",
  0x85, "Change To Client Rights(new)",
  0x86, "Read Queue Server Current Status(new)",
  0x87, "Get Queue Job File Size(new)",
  0x88, "Move Queue Job From SrcQ to DstQ",
  0x89, "Get Q Jobs From Form List",
  0x8a, "Service Q Job By Form List",
  0x96, "Get Account Status",
  0x97, "Submit Account Charge",
  0x98, "Submit Account Hold",
  0x99, "Submit Account Note",
  0xc8, "Check Console Privileges",
  0xc9, "Get File Server Description Strings",
  0xca, "Set File Server Date And Time",
  0xcb, "Disable File Server Login",
  0xcc, "Enable File Server Login",
  0xcd, "Get File Server Login Status",
  0xce, "Purge Erased Files(new)",
  0xcf, "Disable Transaction Tracking",
  0xd0, "Enable Transaction Tracking",
  0xd1, "Send Console Broadcast(old)",
  0xd2, "Clear Connection Number(old)",
  0xd3, "Down File Server",
  0xd4, "Get File System Statistics",
  0xd5, "TTS Get Statistics",
  0xd6, "Get Disk Cache Statistics",
  0xd7, "Get Drive Mapping Table",
  0xd8, "Get Physical Disk Statistics",
  0xd9, "Get Disk Channel Statistics",
  0xda, "Get Connection's Task Information(old)",
  0xdb, "Get Connection's Open Files(old)",
  0xdc, "Get Connections Using A File(old)",
  0xdd, "Get Physical Record Locks By Connection And File(old)",
  0xde, "Get Physical Record Locks By File(old)",
  0xdf, "Get Logical Records By Connection(old)",
  0xe0, "Get Logical Record Information(old)",
  0xe1, "Get Connection's Semaphores(old)",
  0xe2, "Get Semaphore Information(old)",
  0xe3, "Get LAN Driver's Configuration Information",
  0xe5, "Get Connection's Usage Statistics",
  0xe6, "Get Bindery Object Disk Space Left",
  0xe7, "Get File Server LAN I/O Statistics",
  0xe8, "Get File Server Misc Information",
  0xe9, "Get Volume Information",
  0xea, "Get Connection's Task Information(new)",
  0xeb, "Get Connection's Open Files(new)",
  0xec, "Get Connections Using A File(new)",
  0xed, "Get Physical Record Locks By Connection And File(new)",
  0xee, "Get Physical Record Locks By File(new)",
  0xef, "Get Logical Records By Connection(new)",
  0xf0, "Get Logical Record Information(new)",
  0xf1, "Get Connection's Semaphores(new)",
  0xf2, "Get Semaphore Information(new)",
  0xf3, "Map Directory Number to Path",
  0xf4, "Convert Path To Dir Entry",
  0xf5, "Get File Server Extended Misc Information",
  0xf6, "Get Volume Extended Information",
  0xfd, "Send Console Broadcast(new)",
  0xfe, "Clear Connection Number(new)",
-1, NULL
};

struct textID NCP23fns[]={
  0x01, "AFP Create Directory",
  0x02, "AFP Create File",
  0x03, "AFP Delete",
  0x04, "AFP Get Entry ID From Name",
  0x05, "AFP Get File Information",
  0x06, "AFP Get Entry ID From Netware Handle",
  0x07, "AFP Rename",
  0x08, "AFP Open File Fork",
  0x09, "AFP Set File Information",
  0x0a, "AFP Scan File Information",
  0x0b, "AFP Alloc Temporary Dir Handle",
  0x0c, "AFP Get Entry ID From Path Name",
  0x0d, "AFP New Create Directory",
  0x0e, "AFP New Create File",
  0x0f, "AFP New Get File Information",
  0x10, "AFP New Set File Information",
  0x11, "AFP New Scan File Information",
  0x12, "AFP Map MacID To DOS Name",
  0x13, "AFP Get Deleted File Info",
-1, NULL
};

struct textID NCP5afns[]={
  0x01, "Get DM Info",
  0x80, "Move File Data To DM",
  0x81, "DM File Information",
  0x82, "Volume DM Status",
  0x83, "Migrate Stat Info",
  0x84, "DM Support Module Information",
  0x85, "Move File Data From DM",
  0x86, "Get or Set Default Support Module",
-1, NULL
};
struct textID NCP7bfns[]={
  0x01, "Get Cache Information",
  0x02, "Get File Server Information",
  0x03, "Get NetWare File Systems Information",
  0x04, "Get User Information",
  0x05, "Get Packet Burst Information",
  0x06, "Get IPX/SPX Information",
  0x07, "Get Garbage Collection Information",
  0x08, "Get CPU Information",
  0x09, "Get Volume Switch Information",
  0x0a, "Get NLM Loaded List",
  0x0b, "Get NLM Information",
  0x0c, "Get Directory Cache Information",
  0x0d, "Get OS Version Information",
  0x0e, "Get Active Connection List By Type",
  0x0f, "Get NLM's Resource Tag List",
  0x14, "Get Active LAN Board List",
  0x15, "Get LAN Configuration Information",
  0x16, "Get LAN Common Counters Information",
  0x17, "Get LAN Custom Counters Information",
  0x18, "Get LAN Config Strings",
  0x19, "Get LSL Information",
  0x1a, "Get LSL Logical Board Statistics",
  0x1e, "Get Media Manager Object Information",
  0x1f, "Get Media Manager Object List",
  0x20, "Get Media Manager Object Children List",
  0x21, "Get Volume Segment List",
  0x28, "Get Active Protocol Stacks",
  0x29, "Get Protocol Stack Configuration Information",
  0x2a, "Get Protocol Stack Statistics Information",
  0x2b, "Get Protocol Stack Custom Information",
  0x2c, "Get Protocol Stack Numbers By Media Number",
  0x2d, "Get Protocol Stack Numbers By LAN Board Number",
  0x2e, "Get Media Name By Media Number",
  0x2f, "Get Loaded Media Number List",
  0x32, "Get General Router And SAP Information",
  0x33, "Get Network Router Information",
  0x34, "Get Network Routers Information",
  0x35, "Get Known Networks Information",
  0x36, "Get Server Information",
  0x38, "Get Known Servers Information",
  0x3c, "Get Server Set Commands Information",
  0x3d, "Get Server Set Categories",
-1, NULL
};
struct textID NCP68fns[]={
  0x00, "Old Fragger Protocol",
  0x01, "Ping Request",
  0x02, "New Fragger Protocol",
  0x03, "Fragment Close",
  0x04, "Bindery Context",
  0x05, "Monitor Connection",
-1, NULL
};
struct textID NCP20fns[]={
  0x00, "Open Semaphore(old)",
  0x01, "Examine Semaphore(old)",
  0x02, "Wait On Semaphore(old)",
  0x03, "Signal Semaphore(old)",
  0x04, "Close Semaphore(old)",
-1, NULL
};
struct textID NCP22fns[]={
  0x00, "TTS Is Available",
  0x01, "TTS Begin Transaction",
  0x02, "TTS End Transaction",
  0x03, "TTS Abort Transaction",
  0x04, "TTS Transaction Status",
  0x05, "TTS Get Application Thresholds",
  0x06, "TTS Set Application Thresholds",
  0x07, "TTS Get Workstation Thresholds",
  0x08, "TTS Set Workstation Thresholds",
  0x09, "TTS Get Control Flags",
  0x0a, "TTS Set Control Flags",
-1, NULL
};
struct textID NCP56fns[]={
  0x01, "Close Extended Attribute Handle",
  0x02, "Write Extended Attribute",
  0x03, "Read Extended Attribute",
  0x04, "Enumerate Extended Attribute",
  0x05, "Duplicate Extended Attribute",
-1, NULL
};
struct textID NCP57fns[]={
  0x01, "Open Create File or Directory",
  0x02, "Initialize Search",
  0x03, "Search For File Or Directory",
  0x04, "Rename or Move a File or Directory",
  0x05, "Scan File or Dir for Trustees",
  0x06, "Obtain File Or Sub Dir Information",
  0x07, "Modify File Or Sub Dir DOS Information",
  0x08, "Delete File Or Directory",
  0x09, "Set Short Directory Handle",
  0x0a, "Add Trustee Set To File or Directory",
  0x0b, "Delete Trustee Set",
  0x0c, "Allocate Short Directory Handle",
  0x10, "Scan Salvageable Files(new)",
  0x11, "Recover Salvageable File(new)",
  0x12, "Purge Salvageable File(new)",
  0x13, "Get NS Information",
  0x14, "Search For File Or Directory Set",
  0x15, "Get A Directory Path From Handle",
  0x16, "Generate Dir Base And Vol Number",
  0x17, "Query NS Info Format",
  0x18, "Get Name Space Loaded List",
  0x19, "Set NS Information",
  0x1a, "Get Huge NS Information",
  0x1b, "Set Huge NS Information",
  0x1c, "Get Full Path String",
  0x1d, "Get Effective Directory Rights(new)",
  0x1e, "Open Create File",
-1, NULL
};
struct textID NCP58fns[]={
  0x01, "Get Volume Audit Statistics",
  0x02, "Add Audit Property",
  0x03, "Login As Volume Editor",
  0x04, "Change Auditor Password",
  0x05, "Check Audit Access",
  0x06, "Remove Audit Property",
  0x07, "Disable Auditing On Volume",
  0x08, "Enable Auditing On Volume",
  0x09, "Is User Audited",
  0x0a, "Read Auditing Bit Map",
  0x0b, "Read Audit Config Header",
  0x0c, "Read Auditing File",
  0x0d, "Logout As Volume Auditor",
  0x0e, "Reset Auditing File",
  0x0f, "Reset Audit History File",
  0x10, "Write Auditing Bit Map",
  0x11, "Write Audit Config Header",
  0x12, "Change Audit Password 2",
  0x13, "Get Auditing Flags",
  0x14, "Close Old Auditing File",
  0x15, "Delete Old Auditing File",
  0x16, "Check Audit Level Two Access",
-1, NULL
};
struct textID NCP60fns[]={
  0x01, "Get File Server Stats",
  0x02, "Get File Server TTS",
  0x03, "Get File Server Sync",
-1, NULL
};
struct textID NCP6ffns[]={
  0x00, "Open Semaphore(new)",
  0x01, "Examine Semaphore(new)",
  0x02, "Wait On Semaphore(new)",
  0x03, "Signal Semaphore(new)",
  0x04, "Close Semaphore(new)",
-1, NULL
};

struct ncpFuns {
  int fn;
  void (*dump)(int fn, byte *pkt, int len);
  struct textID *namelist;
  int  subfn_ofs;
} ncp[]={
  0x11,  NCP_len_sf_pkt,  NCP11fns, 2,
  0x15,  NCP_len_sf_pkt,  NCP15fns, 2,
  0x16,  NCP_len_sf_pkt,  NCP16fns, 2,
  0x17,  NCPBind,         NCP17fns, 2,
  0x20,  NCP_sf_pkt,      NCP20fns, 0,
  0x22,  NCP_sf_pkt,      NCP22fns, 0,
  0x23,  NCP_len_sf_pkt,  NCP23fns, 2,
  0x56,  NCP_sf_pkt,      NCP56fns, 0,
  0x57,  NCP_sf_pkt,      NCP57fns, 0,
  0x58,  NCP_sf_pkt,      NCP58fns, 0,
  0x5a,  NCP_len_sf_pkt,  NCP5afns, 2,
  0x60,  NCP_sf_pkt,      NCP60fns, 0,
  0x68,  NCPfrag,         NCP68fns, 0,
  0x6f,  NCP_sf_pkt,      NCP6ffns, 0,
  0x7b,  NCP_len_sf_pkt,  NCP7bfns, 2,
  -1,    NULL
};

struct RegisterTab {
  char *name;
  int  offset;
  int  size;
}=registerNameList[] {
   "ax", 0, 2,
   "bx", 2, 2,
   "cx", 4, 2,
   "dx", 6, 2,
   "ds", 8, 2,
   "si",10, 2,
   "es",12, 2,
   "di",14, 2,
   "ss",16, 2,
   "sp",18, 2,
   "bp",20, 2,
   "ip",22, 2,
   "cs",24, 2,
   "al", 0, 1,
   "ah", 1, 1,
   "bl", 2, 1,
   "bh", 3, 1,
   "cl", 4, 1,
   "ch", 5, 1,
   "dl", 6, 1,
   "dh", 7, 1,
   NULL,-1,-1
};

// returns printed value of register in <s>
char *LookupRegister(char *s, struct int_rec *r)
{
  struct RegisterTab *rt;
  static char   buf[20];
  byte   *dp;     // data ptr
  char   *bp      // buf ptr
  for (rt=registerNameList; rt->name ; rt++)
  {
    if (strcmp(rt->name, s)==0)
    {
      dp=((byte *)&(r->AX))+rt->offset;   // offset in recstruct
      bp=&buf[2*rt->size];                // offset in text buffer
      *bp--=0;                            // terminating 0
      for (i=0 ; i<rt->size ; i++)
      {
        *bp--=htoa(*dp);
        *bp--=htoa((*dp++)>>4);
      }
      return buf;
    }
  }
  return NULL;
}

void PrintString(byte *p, int n)
{
  int outside=TRUE;
  int i;

  for (i=0 ; i<n ; i++)
    if (*p<' ')
    {
      if (!outside)
      {
        printf("\" ");
        outside=TRUE;
      }
      printf("%02x ",*p++);
    }
    else
    {
      if (outside)
      {
        printf("  \"");
        outside=FALSE;
      }
      putchar(*p++);
    }
  if (!outside) printf("\"");
}
struct name_tab *GetNameEntry(struct name_tab *tab, int n)
{
  while (tab->name)
  {
    if (tab->num==n)
      return tab;
    tab++;
  }
  return NULL;
}

char *getFCBname(char far *fcbfn)
{
  static char fn[13];
  int i;
  char *p;  char *q;
  p=fn;  q=p;
  for (i=0 ; i<8 ; i++)
  {
    *p=fcbfn[i];
    if (*p>0x20 && *p<0x7f && *p!='.')
      q=++p;  // remember end of name
  }
  *q++='.';

  p=q;
  for (i=0 ; i<3 ; i++)
  {
    *p=fcbfn[i];
    if (*p>0x20 && *p<0x7f && *p!='.')
      q=++p;  // remember end of name
  }
  *q++=0;
  return fn;
}

enum {
  PRT_NONE,
  PRT_CHARACTER,
  PRT_REGISTER,
  PRT_DATA
};

int  rprintf(char *fmt, struct int_rec *rec)
{
  char *p=fmt;
  char regName[5];
  int  percentDetected=FALSE;
  int  gettingRegisterName=FALSE;
  int  regNameIdx=0;
  int  printAction=PRT_NONE;
  char *regVal;

  while (*p)
  {
// process character
    printAction=PRT_NONE;
    if (percentDetected)
    {
      switch(*p)
      {
        case 'R':
          gettingRegisterName=TRUE;
          regNameIdx=0;
          break;
        case 'D':
          printAction=PRT_DATA;
          break;
        default:
          printf("!!! Invalid format character %c !!!\n", *p);
      }
      percentDetected=FALSE;
    }
    else if (gettingRegisterName)
    {
      regName[regNameIdx++]=*p;  regName[regNameIdx]=0;
      regVal=LookupRegister(regName, rec);
      if (regVal)
      {
        gettingRegisterName=FALSE;
        printAction=PRT_REGISTER;
      }
    }
    else if (*p=='%')
      percentDetected=TRUE;
    else
      printAction=PRT_CHARACTER;

// output actions
    switch (printAction)
    {
      case PRT_NONE:
        break;
      case PRT_CHARACTER:
        putchar(*p);
        break;
      case PRT_REGISTER:
        fputs(regVal, stdout);
        break;
      case PRT_DATA:
        PrintString(&rec[1], rec->reclen-sizeof(struct int_rec));
        break;
      default:
        printf("!!! error: invalid printAction %d !!!\n", printAction);
    }
    p++;
  }
}

void printrec(struct int_rec *rec)
{

  int i;
  char *name;
  int  namehash;

  struct name_tab *nameEntry;

  printf("%08lx ", rec->time);
  printf("%04x:%04x ", rec->CS, rec->IP);

  namehash=((rec->AX>>8)&0xff)|(rec->intno<<8);
  nameEntry=GetNameEntry(intnametab, namehash);
  if (nameEntry==NULL)
  {
    printf("???(%04x)", namehash);
    PrintString(&rec[1], rec->reclen-sizeof(struct int_rec));
  }
  else
  {
    printf("%s ", name);
    rprintf(nameEntry->format, rec);
  }
  putchar('\n');
}

void usage(char *s, ...)
{
  va_list ap;
  va_start(ap,s);
  vprintf(s,ap);
  va_end(ap);
  printf("Usage: lstfile [-h] catchfile\n");
}

int main(int argc, char **argv)
{
  char *dmpname=NULL;
  int f;
  char data[MAXRECSIZE];
  struct int_rec *buf;
  long t0;
  int printtime=0;

  while (argc>1)
  {
    if (argv[1][0]=='-')
    switch(argv[1][1])
    {
      case 'h':
          usage("Help screen\n");
          return 0;
      case 't':
          printtime++;
          break;
      default:
          usage("Invalid option: %s\n", argv[1]);
          return 1;
    }
    else if (dmpname==NULL)
      dmpname=argv[1];
    else
    {
      usage("Too many parameters: %s\n", argv[1]);
      return 1;
    }

    argc--; argv++;
  }
  if (dmpname==NULL)
  {
      usage("You have to specify catch dumpfile\n");
      return 1;
  }
  f=open(dmpname, O_RDONLY|O_BINARY);
  if (f<0)
  {
    perror(dmpname);
    return 1;
  }

  printf("                 time       CS   IP   data\n");
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
  close(f);
  return 0;
}
