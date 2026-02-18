//+------------------------------------------------------------------+
//|                                             StealthRegistry.mqh |
//|                                     Copyright 2026, Jules (Mimic)|
//|                                     Part of Project Merkava      |
//|                                          Version 1.03            |
//|                    (Fix: Humanized Magic Numbers 10k-999k)       |
//+------------------------------------------------------------------+
#ifndef STEALTH_REGISTRY_MQH
#define STEALTH_REGISTRY_MQH

#property copyright "Jules (Mimic)"
#property strict

//+------------------------------------------------------------------+
//| CStealthRegistry                                                 |
//| Manages the "Secret Book" of active tickets and handles audit logging. |
//+------------------------------------------------------------------+
class CStealthRegistry
{
private:
   string         m_root_path;      // Root folder
   string         m_registry_path;  // Path to ActiveTickets.csv
   string         m_logs_path;      // Path to Audit Logs folder
   ulong          m_active_tickets[]; // In-memory cache of active tickets
   int            m_ticket_count;

   // Helper: Generate Random String
   string GetRandomString(int len)
   {
      string chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
      string res = "";
      for(int i=0; i<len; i++) {
         res += StringSubstr(chars, MathRand() % StringLen(chars), 1);
      }
      return res;
   }

   // Helper: Load Registry from File
   void LoadRegistry()
   {
      m_ticket_count = 0;
      ArrayResize(m_active_tickets, 0);

      // Ensure folders exist before trying to open
      CreateFolders();

      int handle = FileOpen(m_registry_path, FILE_READ|FILE_CSV|FILE_ANSI, ",");
      if(handle == INVALID_HANDLE) {
          // If file doesn't exist, create it (empty)
          handle = FileOpen(m_registry_path, FILE_WRITE|FILE_CSV|FILE_ANSI, ",");
          if(handle != INVALID_HANDLE) FileClose(handle);
          return;
      }

      while(!FileIsEnding(handle)) {
          string str = FileReadString(handle);
          if(str == "") continue;
          ulong ticket = StringToInteger(str);
          if(ticket > 0) {
              m_ticket_count++;
              ArrayResize(m_active_tickets, m_ticket_count);
              m_active_tickets[m_ticket_count-1] = ticket;
          }
      }
      FileClose(handle);
      PrintFormat("StealthRegistry: Loaded %d tickets from %s", m_ticket_count, m_registry_path);
   }

   // Helper: Save Registry to File
   void SaveRegistry()
   {
      int handle = FileOpen(m_registry_path, FILE_WRITE|FILE_CSV|FILE_ANSI, ",");
      if(handle == INVALID_HANDLE) {
          Print("StealthRegistry: Failed to save registry! Error: ", GetLastError());
          return;
      }

      for(int i=0; i<m_ticket_count; i++) {
          FileWrite(handle, IntegerToString(m_active_tickets[i]));
      }
      FileClose(handle);
   }

   // Helper: Create Folders
   void CreateFolders()
   {
       // MQL5/Files/ is root
       // Note: FolderCreate returns false if folder exists, so we ignore that specific error.
       // Check if exists first? MQL5 FolderCreate handles it gracefully mostly but returns false if exists.
       FolderCreate("Merkava_Stealth");
       FolderCreate("Merkava_Stealth\\Registry");
       FolderCreate("Merkava_Stealth\\Logs");
   }

   // Helper: Append to Audit Log
   void LogAudit(string action, ulong ticket, ulong magic, string comment)
   {
       string filename = m_logs_path + "Stealth_Audit_" + TimeToString(TimeCurrent(), TIME_DATE) + ".csv";
       // Replace ':' with nothing just in case
       StringReplace(filename, ":", "");

       // We use READ|WRITE to seek. If it doesn't exist, we must create it.
       int handle = FileOpen(filename, FILE_READ|FILE_WRITE|FILE_CSV|FILE_ANSI, ",");

       if(handle == INVALID_HANDLE) {
           // Try to create it explicitly if open failed (e.g. didn't exist)
           handle = FileOpen(filename, FILE_WRITE|FILE_CSV|FILE_ANSI, ",");

           if(handle != INVALID_HANDLE) {
               // New file -> Write Header immediately
               FileWrite(handle, "Time", "Action", "Ticket", "MagicNumber", "Comment");
           } else {
               Print("StealthRegistry: Failed to create log file: ", filename, " Error: ", GetLastError());
               return;
           }
       } else {
           // File Opened successfully (likely existed). Move to end.
           FileSeek(handle, 0, SEEK_END);

           // Double check if empty (created but empty?)
           if(FileTell(handle) == 0) {
                FileWrite(handle, "Time", "Action", "Ticket", "MagicNumber", "Comment");
           }
       }

       if(handle != INVALID_HANDLE) {
           // Write Log Entry
           // Use IntegerToString explicitly to avoid scientific notation for large numbers (though now smaller)
           FileWrite(handle,
                     TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS),
                     action,
                     IntegerToString(ticket),
                     IntegerToString(magic),
                     comment);

           FileFlush(handle); // Ensure data hits disk
           FileClose(handle);
       }
   }

public:
   CStealthRegistry()
   {
       m_root_path = "Merkava_Stealth\\";
       m_registry_path = "Merkava_Stealth\\Registry\\ActiveTickets.csv";
       m_logs_path = "Merkava_Stealth\\Logs\\";
       m_ticket_count = 0;
   }
   ~CStealthRegistry() {}

   // Initialize (Load existing tickets)
   void Init()
   {
       CreateFolders(); // Explicitly create structure
       LoadRegistry();
       MathSrand(GetTickCount());
   }

   // Core: Register a new Ticket
   void RegisterTicket(ulong ticket, ulong magic, string comment)
   {
       // Add to memory
       m_ticket_count++;
       ArrayResize(m_active_tickets, m_ticket_count);
       m_active_tickets[m_ticket_count-1] = ticket;

       // Save to File
       SaveRegistry();

       // Audit Log
       LogAudit("REGISTER", ticket, magic, comment);
       PrintFormat("StealthRegistry: Registered Ticket #%I64u (Magic: %I64u)", ticket, magic);
   }

   // Core: Unregister (Close) a Ticket
   void UnregisterTicket(ulong ticket)
   {
       int index = -1;
       for(int i=0; i<m_ticket_count; i++) {
           if(m_active_tickets[i] == ticket) {
               index = i;
               break;
           }
       }

       if(index != -1) {
           // Remove from array (shift left)
           for(int j=index; j<m_ticket_count-1; j++) {
               m_active_tickets[j] = m_active_tickets[j+1];
           }
           m_ticket_count--;
           ArrayResize(m_active_tickets, m_ticket_count);

           // Save to File
           SaveRegistry();

           // Audit Log - Magic is 0 on unregister as we don't track it here (could fetch from history if needed)
           LogAudit("UNREGISTER", ticket, 0, "Closed/Removed");
           PrintFormat("StealthRegistry: Unregistered Ticket #%I64u", ticket);
       }
   }

   // Core: Check if Ticket is Ours
   bool IsMyTicket(ulong ticket)
   {
       for(int i=0; i<m_ticket_count; i++) {
           if(m_active_tickets[i] == ticket) return true;
       }
       return false;
   }

   // Helper: Get Random Magic (Humanized Range: 10,000 - 999,999)
   ulong GetRandomMagic()
   {
       // Generate a random number between 10000 and 999999
       // MathRand() returns 0..32767. We need bigger range.
       // r1 * 32768 + r2 gives range approx 0..10^9

       int min_val = 10000;
       int max_val = 999999;
       int range = max_val - min_val + 1;

       ulong r1 = (ulong)MathRand();
       ulong r2 = (ulong)MathRand();
       ulong combined = (r1 << 15) | r2; // Combine to get approx 30 bits

       ulong result = min_val + (combined % range);
       return result;
   }

   // Helper: Get Random Comment
   string GetRandomComment()
   {
       string comments[] = {"manual", "t1", "test", "news", "", "scalp", "intraday", "swing", "buy", "sell"};
       int idx = MathRand() % ArraySize(comments);

       // 30% chance of random garbage string
       if(MathRand() % 10 < 3) return GetRandomString(4 + (MathRand()%4));

       return comments[idx];
   }
};
#endif
