//+------------------------------------------------------------------+
//|                                             StealthRegistry.mqh |
//|                                     Copyright 2026, Jules (Mimic)|
//|                                     Part of Project Merkava      |
//|                                          Version 1.05            |
//|                    (Fix: Custom PRNG, Entropy & CSV Encoding)    |
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

   // PRNG State (Custom Generator)
   ulong          m_prng_state;

   // Helper: Generate Random String
   string GetRandomString(int len)
   {
      string chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
      string res = "";
      for(int i=0; i<len; i++) {
         res += StringSubstr(chars, (int)(NextRandom() % StringLen(chars)), 1);
      }
      return res;
   }

   // --- CUSTOM PRNG (Linear Congruential Generator) ---
   // Replaces MathRand() entirely to avoid MT5 environment issues.
   void SeedPRNG()
   {
       // High Entropy Mix: Microseconds + Time + Ticks + Account Login + Ticket Count
       ulong t_micro = GetMicrosecondCount();
       ulong t_time  = (ulong)TimeCurrent();
       ulong t_tick  = GetTickCount();
       ulong t_login = (ulong)AccountInfoInteger(ACCOUNT_LOGIN);

       // Simple mixing function
       m_prng_state = t_micro ^ (t_time << 10) ^ (t_tick << 20) ^ t_login ^ (ulong)m_ticket_count;

       // Warm up
       for(int i=0; i<10; i++) NextRandom();
   }

   ulong NextRandom()
   {
       // LCG Parameters (Numerical Recipes)
       m_prng_state = m_prng_state * 1664525 + 1013904223;
       return m_prng_state;
   }

   // Helper: Load Registry from File
   void LoadRegistry()
   {
      m_ticket_count = 0;
      ArrayResize(m_active_tickets, 0);

      // Ensure folders exist before trying to open
      CreateFolders();

      // Use FILE_COMMON logic implicitly via standard open
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
       FolderCreate("Merkava_Stealth");
       FolderCreate("Merkava_Stealth\\Registry");
       FolderCreate("Merkava_Stealth\\Logs");
   }

   // Helper: Append to Audit Log (Safe Encoding)
   void LogAudit(string action, ulong ticket, ulong magic, string comment)
   {
       string filename = m_logs_path + "Stealth_Audit_" + TimeToString(TimeCurrent(), TIME_DATE) + ".csv";
       StringReplace(filename, ":", "");

       // Explicitly use FILE_ANSI (Default) but ensure clean write.
       // Note: To fix "unknown characters", ensure we write simple ASCII strings.
       int handle = FileOpen(filename, FILE_READ|FILE_WRITE|FILE_CSV|FILE_ANSI, ",");

       if(handle == INVALID_HANDLE) {
           handle = FileOpen(filename, FILE_WRITE|FILE_CSV|FILE_ANSI, ",");
           if(handle != INVALID_HANDLE) {
               FileWrite(handle, "Time", "Action", "Ticket", "MagicNumber", "Comment");
           } else {
               Print("StealthRegistry: Failed to create log file: ", filename, " Error: ", GetLastError());
               return;
           }
       } else {
           FileSeek(handle, 0, SEEK_END);
           if(FileTell(handle) == 0) {
                FileWrite(handle, "Time", "Action", "Ticket", "MagicNumber", "Comment");
           }
       }

       if(handle != INVALID_HANDLE) {
           FileWrite(handle,
                     TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS),
                     action,
                     IntegerToString(ticket),
                     IntegerToString(magic),
                     comment); // Comment might have special chars, but GetRandomComment is pure ASCII

           FileFlush(handle);
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
       m_prng_state = 123456789; // Default safety seed
   }
   ~CStealthRegistry() {}

   // Initialize
   void Init()
   {
       CreateFolders();
       LoadRegistry();
       SeedPRNG(); // Initialize Custom PRNG
   }

   // Core: Register a new Ticket
   void RegisterTicket(ulong ticket, ulong magic, string comment)
   {
       m_ticket_count++;
       ArrayResize(m_active_tickets, m_ticket_count);
       m_active_tickets[m_ticket_count-1] = ticket;

       SaveRegistry();
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
           for(int j=index; j<m_ticket_count-1; j++) {
               m_active_tickets[j] = m_active_tickets[j+1];
           }
           m_ticket_count--;
           ArrayResize(m_active_tickets, m_ticket_count);

           SaveRegistry();
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

   // Helper: Get Random Magic (Humanized: 10k-999k) using CUSTOM PRNG
   ulong GetRandomMagic()
   {
       // Always re-mix state slightly before generation to ensure divergence even if called fast
       SeedPRNG();

       ulong rnd = NextRandom(); // Get 64-bit random

       // Range: 10,000 to 999,999
       int min_val = 10000;
       int max_val = 999999;
       int range = max_val - min_val + 1;

       ulong result = min_val + (rnd % range);
       return result;
   }

   // Helper: Get Random Comment (ASCII Only)
   string GetRandomComment()
   {
       string comments[] = {"manual", "t1", "test", "news", "", "scalp", "intraday", "swing", "buy", "sell"};
       int idx = (int)(NextRandom() % ArraySize(comments));

       if((NextRandom() % 10) < 3) return GetRandomString(4 + (int)(NextRandom()%4));

       return comments[idx];
   }
};
#endif
