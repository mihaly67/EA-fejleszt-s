//+------------------------------------------------------------------+
//|                                     StealthRegistry_v1_08.mqh    |
//|                                     Copyright 2026, Jules (Mimic)|
//|                                     Part of Project Merkava      |
//|                                          Version 1.08            |
//|                    (Fix: Log File Creation & Robust Folder Logic)|
//+------------------------------------------------------------------+
#ifndef STEALTH_REGISTRY_V1_08_MQH
#define STEALTH_REGISTRY_V1_08_MQH

#property copyright "Jules (Mimic)"
#property strict

//+------------------------------------------------------------------+
//| CStealthPRNG                                                     |
//| Custom Linear Congruential Generator (LCG) for high entropy.     |
//| Replaces standard MathRand() to avoid clumping artifacts.        |
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

   // Returns a pseudo-random integer in range [0, 32767]
   int Rand()
   {
      // LCG Parameters (Numerical Recipes)
      m_seed = m_seed * 1664525 + 1013904223;
      return (int)((m_seed >> 16) & 0x7FFF);
   }

   // Returns a pseudo-random integer in range [min, max]
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
//| CStealthRegistry                                                 |
//| Manages the "Secret Book" of active tickets and handles audit logging. |
//| v1.08: Improved Log File Creation Logic (Fixes Missing CSVs)     |
//+------------------------------------------------------------------+
class CStealthRegistry
{
private:
   string         m_root_path;      // Root folder: Merkava_Stealth\
   string         m_registry_path;  // File: Merkava_Stealth\Registry\ActiveTickets.csv
   string         m_logs_folder;    // Folder: Merkava_Stealth\Logs\
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
          // If file doesn't exist, try to create it (empty)
          handle = FileOpen(m_registry_path, FILE_WRITE|FILE_CSV|FILE_ANSI, ",");
          if(handle != INVALID_HANDLE) FileClose(handle);
          else Print("StealthRegistry ERROR: Could not create registry file: ", m_registry_path, " Error: ", GetLastError());
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
      if(m_ticket_count > 0) PrintFormat("StealthRegistry: Loaded %d tickets from %s", m_ticket_count, m_registry_path);
   }

   // Helper: Save Registry to File
   void SaveRegistry()
   {
      CreateFolders(); // Ensure folder exists before save

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

   // Helper: Create Folders (Robust)
   bool CreateFolders()
   {
       // MQL5/Files/ is root
       bool res = true;
       ResetLastError();

       // 1. Root Folder
       if(!FolderCreate("Merkava_Stealth")) {
           if(GetLastError() != 4119 && GetLastError() != 0) { // 4119 = Exists
               Print("StealthRegistry: FolderCreate root failed. Error=", GetLastError());
               res = false;
           }
       }

       // 2. Registry Folder
       if(!FolderCreate("Merkava_Stealth\\Registry")) {
           if(GetLastError() != 4119 && GetLastError() != 0) {
               Print("StealthRegistry: FolderCreate Registry failed. Error=", GetLastError());
               res = false;
           }
       }

       // 3. Logs Folder
       if(!FolderCreate("Merkava_Stealth\\Logs")) {
           if(GetLastError() != 4119 && GetLastError() != 0) {
               Print("StealthRegistry: FolderCreate Logs failed. Error=", GetLastError());
               res = false;
           }
       }

       return res;
   }

public:
   // Helper: Append to Audit Log (Public for Test Script access)
   // v1.08 Fix: Ensures file is created properly even if previous attempts failed.
   void LogAudit(string action, ulong ticket, ulong magic, string comment)
   {
       // Ensure folder exists
       CreateFolders();

       string date_str = TimeToString(TimeCurrent(), TIME_DATE);
       StringReplace(date_str, ".", ""); // YYYYMMDD format

       // Construct filename: MQL5/Files/Merkava_Stealth/Logs/Stealth_Audit_YYYYMMDD.csv
       string filename = m_logs_folder + "Stealth_Audit_" + date_str + ".csv";

       int handle = INVALID_HANDLE;

       // Try to open for READ|WRITE (Append mode requires seeking)
       // Note: FILE_READ|FILE_WRITE requires the file to exist in some implementations,
       // but in MQL5 usually creates it if missing IF FILE_WRITE is present.
       // To be safe, we check existence or handle error.

       if(FileIsExist(filename)) {
           handle = FileOpen(filename, FILE_READ|FILE_WRITE|FILE_CSV|FILE_ANSI, ",");
       } else {
           // Create new file
           handle = FileOpen(filename, FILE_WRITE|FILE_CSV|FILE_ANSI, ",");
           if(handle != INVALID_HANDLE) {
               // Write Header for new file
               FileWrite(handle, "Time", "Action", "Ticket", "MagicNumber", "Comment");
           }
       }

       if(handle == INVALID_HANDLE) {
           Print("StealthRegistry ERROR: Failed to open log file: ", filename, " Error: ", GetLastError());

           // FALLBACK: Write to root if folder path is broken
           string fallback = "Merkava_Fallback_Log_" + date_str + ".csv";
           int h2 = FileOpen(fallback, FILE_READ|FILE_WRITE|FILE_CSV|FILE_ANSI, ",");
           if(h2 == INVALID_HANDLE) h2 = FileOpen(fallback, FILE_WRITE|FILE_CSV|FILE_ANSI, ","); // Create if missing

           if(h2 != INVALID_HANDLE) {
                FileSeek(h2, 0, SEEK_END);
                if(FileTell(h2) == 0) FileWrite(h2, "Time", "Action", "Ticket", "MagicNumber", "Comment", "ORIGINAL_PATH_FAILED");

                FileWrite(h2, TimeToString(TimeCurrent(), TIME_SECONDS), action, IntegerToString(ticket), IntegerToString(magic), comment, filename);
                FileClose(h2);
                Print("StealthRegistry: Wrote to fallback log: ", fallback);
           }
           return;
       }

       // File Opened successfully. Move to end.
       FileSeek(handle, 0, SEEK_END);

       // Double check if empty (created but header missing?)
       if(FileTell(handle) == 0) {
            FileWrite(handle, "Time", "Action", "Ticket", "MagicNumber", "Comment");
       }

       // Write Log Entry
       FileWrite(handle,
                 TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS),
                 action,
                 IntegerToString(ticket),
                 IntegerToString(magic),
                 comment);

       FileFlush(handle); // Ensure data hits disk
       FileClose(handle);
   }

   CStealthRegistry()
   {
       // Use double backslashes for safe path construction
       m_root_path = "Merkava_Stealth\\";
       m_registry_path = "Merkava_Stealth\\Registry\\ActiveTickets.csv";
       m_logs_folder = "Merkava_Stealth\\Logs\\";
       m_ticket_count = 0;
   }
   ~CStealthRegistry() {}

   // Initialize (Load existing tickets)
   void Init()
   {
       CreateFolders(); // Explicitly create structure
       LoadRegistry();

       // High Entropy Seed for Custom PRNG
       ulong seed = GetMicrosecondCount() ^ (ulong)TimeCurrent() ^ GetTickCount();
       if(AccountInfoInteger(ACCOUNT_LOGIN) > 0) seed ^= AccountInfoInteger(ACCOUNT_LOGIN);
       seed ^= (ulong)m_ticket_count;

       m_prng.Seed(seed);
       PrintFormat("StealthRegistry v1.08: Initialized with High-Entropy Seed (%I64u)", seed);
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

           // Audit Log
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

   // Helper: Get Random Magic (Humanized Range: 10,000 - 999,999) with Custom LCG
   ulong GetRandomMagic()
   {
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
