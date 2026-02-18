//+------------------------------------------------------------------+
//|                                             StealthRegistry.mqh |
//|                                     Copyright 2026, Jules (Mimic)|
//|                                     Part of Project Merkava      |
//|                                          Version 1.06            |
//|                    (Fix: Custom LCG, Deep Randomization & Seeding)|
//|                    (Fix: Added 'StrategyTag' Column, Forced Logging)|
//+------------------------------------------------------------------+
#ifndef STEALTH_REGISTRY_V1_06_MQH
#define STEALTH_REGISTRY_V1_06_MQH

#property copyright "Jules (Mimic)"
#property strict

//+------------------------------------------------------------------+
//| CStealthPRNG (Unchanged v1.05)                                   |
//| Custom Linear Congruential Generator (LCG) for high entropy.     |
//+------------------------------------------------------------------+
class CStealthPRNG
{
private:
   ulong m_seed;

public:
   CStealthPRNG() { m_seed = 123456789; }

   void Seed(ulong seed)
   {
      m_seed = seed;
   }

   int Rand()
   {
      m_seed = m_seed * 1664525 + 1013904223;
      return (int)((m_seed >> 16) & 0x7FFF);
   }

   int RandRange(int min, int max)
   {
      if (min >= max) return min;
      int range = max - min + 1;
      m_seed = m_seed * 1664525 + 1013904223;
      ulong r = (m_seed >> 16);
      return min + (int)(r % range);
   }
};

//+------------------------------------------------------------------+
//| CStealthRegistry v1.06                                           |
//| Manages the "Secret Book" of active tickets and handles audit logging. |
//| Added: StrategyTag column for internal tracking (e.g. _L1).      |
//+------------------------------------------------------------------+
class CStealthRegistry
{
private:
   string         m_root_path;      // Root folder
   string         m_registry_path;  // Path to ActiveTickets.csv
   string         m_logs_path;      // Path to Audit Logs folder
   ulong          m_active_tickets[]; // In-memory cache of active tickets
   int            m_ticket_count;
   CStealthPRNG   m_prng;           // Custom PRNG instance

   // Helper: Generate Random String
   string GetRandomString(int len)
   {
      string chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
      string res = "";
      for(int i=0; i<len; i++) {
         res += StringSubstr(chars, m_prng.Rand() % StringLen(chars), 1);
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
          else Print("StealthRegistry ERROR: Could not create registry file: ", m_registry_path, " Error=", GetLastError());
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
      // Force rewrite
      int handle = FileOpen(m_registry_path, FILE_WRITE|FILE_CSV|FILE_ANSI, ",");
      if(handle == INVALID_HANDLE) {
          Print("StealthRegistry ERROR: Failed to save registry! Path: ", m_registry_path, " Error: ", GetLastError());
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

       // FIX: Reset Last Error before creating
       ResetLastError();
       if(!FolderCreate("Merkava_Stealth")) {
           if(GetLastError() != 4119) Print("StealthRegistry: FolderCreate root failed. Error=", GetLastError()); // 4119 = Exists
       }

       ResetLastError();
       if(!FolderCreate("Merkava_Stealth\\Registry")) {
           if(GetLastError() != 4119) Print("StealthRegistry: FolderCreate Registry failed. Error=", GetLastError());
       }

       ResetLastError();
       if(!FolderCreate("Merkava_Stealth\\Logs")) {
           if(GetLastError() != 4119) Print("StealthRegistry: FolderCreate Logs failed. Error=", GetLastError());
       }
   }

public:
   // Helper: Append to Audit Log (Public for Test Script access)
   // v1.06: Added 'tag' parameter for internal strategy label
   void LogAudit(string action, ulong ticket, ulong magic, string comment, string tag)
   {
       // FIX: Ensure filename uses backslashes correctly
       string date_part = TimeToString(TimeCurrent(), TIME_DATE);
       StringReplace(date_part, ".", ""); // Remove dots from date part for filename safety on all OS

       string filename = m_logs_path + "Stealth_Audit_" + date_part + ".csv";

       // We use READ|WRITE to seek. If it doesn't exist, we must create it.
       // Try opening with shared write access to handle rapid events
       int handle = FileOpen(filename, FILE_READ|FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_SHARE_READ|FILE_SHARE_WRITE, ",");

       if(handle == INVALID_HANDLE) {
           // Try to create it explicitly if open failed (e.g. didn't exist)
           handle = FileOpen(filename, FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_SHARE_READ|FILE_SHARE_WRITE, ",");

           if(handle != INVALID_HANDLE) {
               // New file -> Write Header immediately (Added StrategyTag)
               FileWrite(handle, "Time", "Action", "Ticket", "MagicNumber", "Comment", "StrategyTag");
           } else {
               Print("StealthRegistry ERROR: Failed to create log file: ", filename, " Error: ", GetLastError());

               // FALLBACK: Write to root if folder path is broken
               string fallback = "Merkava_Fallback_Log_" + date_part + ".csv";
               int h2 = FileOpen(fallback, FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_SHARE_READ|FILE_SHARE_WRITE, ",");
               if(h2 != INVALID_HANDLE) {
                    FileWrite(h2, "Time", "Action", "Ticket", "MagicNumber", "Comment", "StrategyTag", "ORIGINAL_PATH_FAILED");
                    FileWrite(h2, TimeToString(TimeCurrent(), TIME_SECONDS), action, IntegerToString(ticket), IntegerToString(magic), comment, tag, filename);
                    FileClose(h2);
                    Print("StealthRegistry: Wrote to fallback log: ", fallback);
               }
               return;
           }
       } else {
           // File Opened successfully (likely existed). Move to end.
           FileSeek(handle, 0, SEEK_END);

           // Double check if empty (created but empty?)
           if(FileTell(handle) == 0) {
                FileWrite(handle, "Time", "Action", "Ticket", "MagicNumber", "Comment", "StrategyTag");
           }
       }

       if(handle != INVALID_HANDLE) {
           // Write Log Entry
           // Use IntegerToString explicitly to avoid scientific notation
           FileWrite(handle,
                     TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS),
                     action,
                     IntegerToString(ticket),
                     IntegerToString(magic),
                     comment,
                     tag); // New column

           FileFlush(handle); // Ensure data hits disk
           FileClose(handle);
       }
   }

   CStealthRegistry()
   {
       // FIX: Use double backslashes for safe path construction
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

       // High Entropy Seed for Custom PRNG
       // XOR Mix: Microseconds ^ Time ^ Ticks ^ Account ^ TicketCount
       ulong seed = GetMicrosecondCount() ^ (ulong)TimeCurrent() ^ GetTickCount();
       if(AccountInfoInteger(ACCOUNT_LOGIN) > 0) seed ^= AccountInfoInteger(ACCOUNT_LOGIN);
       seed ^= (ulong)m_ticket_count;

       m_prng.Seed(seed);
       PrintFormat("StealthRegistry v1.06: Initialized with High-Entropy Seed (%I64u)", seed);
   }

   // Core: Register a new Ticket
   // v1.06: Added 'tag' for Strategy Layer (e.g. _L1)
   void RegisterTicket(ulong ticket, ulong magic, string comment, string tag)
   {
       // Add to memory
       m_ticket_count++;
       ArrayResize(m_active_tickets, m_ticket_count);
       m_active_tickets[m_ticket_count-1] = ticket;

       // Save to File
       SaveRegistry();

       // Audit Log with Tag
       LogAudit("REGISTER", ticket, magic, comment, tag);
       PrintFormat("StealthRegistry: Registered Ticket #%I64u (Magic: %I64u, Tag: %s)", ticket, magic, tag);
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
           LogAudit("UNREGISTER", ticket, 0, "Closed/Removed", "N/A");
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

   // Helper: Get Random Magic (Humanized Range: 10,000 - 999,999) with Custom LCG
   ulong GetRandomMagic()
   {
       // Use Custom PRNG instead of MathRand
       // Range: 10,000 to 999,999
       int min_val = 10000;
       int max_val = 999999;

       ulong result = (ulong)m_prng.RandRange(min_val, max_val);
       return result;
   }

   // Helper: Get Random Comment
   string GetRandomComment()
   {
       string comments[] = {"manual", "t1", "test", "news", "", "scalp", "intraday", "swing", "buy", "sell"};
       int idx = m_prng.Rand() % ArraySize(comments);

       // 30% chance of random garbage string
       if(m_prng.Rand() % 10 < 3) return GetRandomString(4 + (m_prng.Rand()%4));

       return comments[idx];
   }
};
#endif
