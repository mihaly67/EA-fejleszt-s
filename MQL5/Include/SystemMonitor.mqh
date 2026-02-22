//+------------------------------------------------------------------+
//|                                                SystemMonitor.mqh |
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
// MQL5 int is signed 32-bit. These hex values exceed INT_MAX, so we cast them to int explicitly
#define STATUS_DEBUGGER_INACTIVE (int)0xC0000354
#define STATUS_NOT_IMPLEMENTED   (int)0xC0000002
#define STATUS_ACCESS_DENIED     (int)0xC0000022
#define STATUS_SUCCESS           0x00000000

#define SysDbgCheckLowMemory     20 // 0x14

//+------------------------------------------------------------------+
//| Class: CSystemMonitor (formerly CounterIntel)                    |
//| Purpose: System Integrity & Environment Monitoring               |
//+------------------------------------------------------------------+
class CSystemMonitor {
private:
   bool m_verbose;

   void Log(string message) {
      if(m_verbose) Print("[SystemMonitor] ", message);
   }

public:
   CSystemMonitor(bool verbose=true) {
      m_verbose = verbose;
   }

   //+------------------------------------------------------------------+
   //| Check: Kernel Integrity (NtSystemDebugControl)                   |
   //+------------------------------------------------------------------+
   bool CheckIntegrity_Kernel() {
      int returnLength = 0;
      int status = NtSystemDebugControl(SysDbgCheckLowMemory, 0, 0, 0, 0, returnLength);

      Log(StringFormat("Kernel Integrity Status: 0x%X", status));

      if (status == STATUS_DEBUGGER_INACTIVE || status == STATUS_NOT_IMPLEMENTED) {
         return false; // Safe
      }

      if (status == STATUS_ACCESS_DENIED) {
         return false;
      }

      return true; // Suspicious
   }

   //+------------------------------------------------------------------+
   //| Check: User Environment (IsDebuggerPresent)                      |
   //+------------------------------------------------------------------+
   bool CheckIntegrity_User() {
      int res = IsDebuggerPresent();
      if (res != 0) {
         Log("User Environment Compromised!");
         return true;
      }
      return false;
   }

   //+------------------------------------------------------------------+
   //| Check: Input Entropy (Mouse Movement)                            |
   //+------------------------------------------------------------------+
   bool CheckInputEntropy(int sleep_ms = 2000) {
      int p1[2];
      int p2[2];

      if (GetCursorPos(p1) == 0) return false;
      Sleep(sleep_ms);
      if (GetCursorPos(p2) == 0) return false;

      if (p1[0] == p2[0] && p1[1] == p2[1]) {
         Log(StringFormat("Low Input Entropy detected. X:%d Y:%d.", p1[0], p1[1]));
         return true;
      }

      return false;
   }

   //+------------------------------------------------------------------+
   //| Check: Resource Profile (RAM & Disk)                             |
   //+------------------------------------------------------------------+
   bool CheckResourceProfile() {
      // 1. Check RAM
      uchar buffer[64];
      ArrayInitialize(buffer, 0);
      int dwLength = 64;
      buffer[0] = (uchar)(dwLength & 0xFF);
      buffer[1] = (uchar)((dwLength >> 8) & 0xFF);
      buffer[2] = (uchar)((dwLength >> 16) & 0xFF);
      buffer[3] = (uchar)((dwLength >> 24) & 0xFF);

      if (GlobalMemoryStatusEx(buffer) != 0) {
         long totalPhys = 0;
         for(int i=0; i<8; i++) totalPhys |= ((long)buffer[8+i]) << (i*8);

         if (totalPhys < 1073741824) {
            Log(StringFormat("Low Memory Profile: %lld bytes.", totalPhys));
            return true;
         }
      }

      // 2. Check Disk (C:\)
      long freeBytes, totalBytes, totalFree;
      if (GetDiskFreeSpaceExW("C:\\", freeBytes, totalBytes, totalFree) != 0) {
         if (totalBytes < 85899345920) { // 80GB
             Log(StringFormat("Low Storage Profile: %lld bytes.", totalBytes));
             return true;
         }
      }

      return false;
   }

   //+------------------------------------------------------------------+
   //| MASTER CHECK                                                     |
   //+------------------------------------------------------------------+
   bool IsStable() {
      if (CheckIntegrity_User()) return false;
      if (CheckIntegrity_Kernel()) return false;
      if (CheckResourceProfile()) return false;
      return true;
   }
};
