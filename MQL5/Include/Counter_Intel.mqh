//+------------------------------------------------------------------+
//|                                                Counter_Intel.mqh |
//|                                                   Copyright 2026 |
//|                                                     Merakva SWAT |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Merkava SWAT"
#property link      "https://github.com/merkava-swat"
#property strict

// WinAPI Imports
#import "ntdll.dll"
   int NtSystemDebugControl(int Command, long InputBuffer, int InputBufferLength, long OutputBuffer, int OutputBufferLength, int &ReturnLength);
#import

#import "kernel32.dll"
   int IsDebuggerPresent();
   int GlobalMemoryStatusEx(uchar &buffer[]);
   int GetDiskFreeSpaceExW(string directory, long &freeBytesAvailable, long &totalNumberOfBytes, long &totalNumberOfFreeBytes);
#import

#import "user32.dll"
   int GetCursorPos(int &point[]);
#import

// Constants and Structures
#define STATUS_DEBUGGER_INACTIVE 0xC0000354
#define STATUS_NOT_IMPLEMENTED   0xC0000002
#define STATUS_ACCESS_DENIED     0xC0000022
#define STATUS_SUCCESS           0x00000000

#define SysDbgCheckLowMemory     20 // 0x14

// Struct for GlobalMemoryStatusEx (64 bytes)
struct MEMORYSTATUSEX {
   int dwLength;
   int dwMemoryLoad;
   long ullTotalPhys;
   long ullAvailPhys;
   long ullTotalPageFile;
   long ullAvailPageFile;
   long ullTotalVirtual;
   long ullAvailVirtual;
   long ullAvailExtendedVirtual;
};

//+------------------------------------------------------------------+
//| Class: CCounterIntel                                             |
//| Purpose: Implements Black Ops evasion and detection logic        |
//+------------------------------------------------------------------+
class CCounterIntel {
private:
   bool m_verbose;

   void Log(string message) {
      if(m_verbose) Print("[CounterIntel] ", message);
   }

public:
   CCounterIntel(bool verbose=true) {
      m_verbose = verbose;
   }

   //+------------------------------------------------------------------+
   //| Check: Kernel Debugger (NtSystemDebugControl)                    |
   //+------------------------------------------------------------------+
   bool CheckDebugger_Kernel() {
      // Logic from Black_Ops:
      // Calls NtSystemDebugControl(SysDbgCheckLowMemory).
      // If returns STATUS_DEBUGGER_INACTIVE (0xC0000354), then NO debugger is attached.
      // If returns success or other errors, it might imply debugger presence.

      int returnLength = 0;
      int status = NtSystemDebugControl(SysDbgCheckLowMemory, 0, 0, 0, 0, returnLength);

      Log(StringFormat("NtSystemDebugControl status: 0x%X", status));

      if (status == STATUS_DEBUGGER_INACTIVE || status == STATUS_NOT_IMPLEMENTED) {
         return false; // Safe
      }

      if (status == STATUS_ACCESS_DENIED) {
         // Typical for User Mode without SeDebugPrivilege.
         // Black_Ops says: "if status != STATUS_ACCESS_DENIED { usermode debugger too }"
         // We treat Access Denied as inconclusive/safe in strict environment,
         // but if it actually succeeds (0x0) or fails with other code, it's suspicious.
         return false;
      }

      return true; // Suspicious
   }

   //+------------------------------------------------------------------+
   //| Check: User Mode Debugger (IsDebuggerPresent)                    |
   //+------------------------------------------------------------------+
   bool CheckDebugger_User() {
      int res = IsDebuggerPresent();
      if (res != 0) {
         Log("IsDebuggerPresent caught a debugger!");
         return true;
      }
      return false;
   }

   //+------------------------------------------------------------------+
   //| Check: Sandbox (Mouse Movement)                                  |
   //+------------------------------------------------------------------+
   bool CheckSandbox_Mouse(int sleep_ms = 2000) {
      int p1[2];
      int p2[2];

      if (GetCursorPos(p1) == 0) return false; // Failed to get cursor

      Sleep(sleep_ms);

      if (GetCursorPos(p2) == 0) return false;

      // Check if coordinates are identical
      if (p1[0] == p2[0] && p1[1] == p2[1]) {
         Log(StringFormat("Mouse stationary for %d ms. X:%d Y:%d. Potential Sandbox.", sleep_ms, p1[0], p1[1]));
         return true;
      }

      return false;
   }

   //+------------------------------------------------------------------+
   //| Check: VM Detection (RAM & Disk)                                 |
   //+------------------------------------------------------------------+
   bool CheckVM_Specs() {
      // 1. Check RAM
      // Need to serialize struct to byte array for MQL5 API call compatibility
      uchar buffer[64];
      ArrayInitialize(buffer, 0);

      // Set dwLength (first 4 bytes) to 64
      // Convert int to 4 bytes little-endian
      int dwLength = 64;
      buffer[0] = (uchar)(dwLength & 0xFF);
      buffer[1] = (uchar)((dwLength >> 8) & 0xFF);
      buffer[2] = (uchar)((dwLength >> 16) & 0xFF);
      buffer[3] = (uchar)((dwLength >> 24) & 0xFF);

      if (GlobalMemoryStatusEx(buffer) != 0) {
         // Extract ullTotalPhys (offset 8, 8 bytes)
         long totalPhys = 0;
         for(int i=0; i<8; i++) {
             totalPhys |= ((long)buffer[8+i]) << (i*8);
         }

         // 1 GB = 1073741824 bytes
         if (totalPhys < 1073741824) {
            Log(StringFormat("Low RAM detected: %lld bytes. Potential VM.", totalPhys));
            return true;
         }
      }

      // 2. Check Disk (C:\)
      long freeBytes, totalBytes, totalFree;
      // Note: GetDiskFreeSpaceExW expects wide string. MQL5 string is unicode, so it works.
      if (GetDiskFreeSpaceExW("C:\\", freeBytes, totalBytes, totalFree) != 0) {
         // 80 GB = 85899345920 bytes
         if (totalBytes < 85899345920) {
             Log(StringFormat("Small Disk detected: %lld bytes. Potential VM.", totalBytes));
             return true;
         }
      }

      return false;
   }

   //+------------------------------------------------------------------+
   //| MASTER CHECK                                                     |
   //+------------------------------------------------------------------+
   bool IsCompromised() {
      bool compromised = false;

      if (CheckDebugger_User()) compromised = true;
      if (CheckDebugger_Kernel()) compromised = true;
      if (CheckVM_Specs()) compromised = true;
      // Mouse check is slow (Sleep), call explicitly if needed

      return compromised;
   }
};
