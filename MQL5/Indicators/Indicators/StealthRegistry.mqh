//+------------------------------------------------------------------+
//|                                             StealthRegistry.mqh |
//|                                     Copyright 2026, Jules (Mimic)|
//|                                     Part of Project Merkava      |
//|                                          Version 1.0             |
//|              (Ticket Registry & Audit Logging Infrastructure)    |
//+------------------------------------------------------------------+
#ifndef STEALTH_REGISTRY_MQH
#define STEALTH_REGISTRY_MQH

#property copyright "Jules (Mimic)"
#property strict

// No explicit MQL5 include needed for basic File functions if using built-ins,
// but FileTxt.mqh is good for object wrapper. Here we use raw functions for simplicity.

//+------------------------------------------------------------------+
//| CStealthRegistry                                                 |
//| Manages the "Secret Book" of active tickets and handles audit logging. |
//+------------------------------------------------------------------+
class CStealthRegistry
{
private:
   string         m_registry_path;  // Path to ActiveTickets.csv
   string         m_logs_path;      // Path to Audit Logs
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

   // Helper: Append to Audit Log
   void LogAudit(string action, ulong ticket, ulong magic, string comment)
   {
       string filename = m_logs_path + "Stealth_Audit_" + TimeToString(TimeCurrent(), TIME_DATE) + ".csv";
       // Replace ':' with nothing in date for filename safety (MT5 usually handles TIME_DATE fine as YYYY.MM.DD)
       StringReplace(filename, ":", "");

       int handle = FileOpen(filename, FILE_READ|FILE_WRITE|FILE_CSV|FILE_ANSI, ",");
       if(handle == INVALID_HANDLE) {
           // Try create
           handle = FileOpen(filename, FILE_WRITE|FILE_CSV|FILE_ANSI, ",");
       }

       if(handle != INVALID_HANDLE) {
           FileSeek(handle, 0, SEEK_END);
           FileWrite(handle, TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS), action, IntegerToString(ticket), IntegerToString(magic), comment);
           FileClose(handle);
       }
   }

public:
   CStealthRegistry()
   {
       m_registry_path = "Merkava_Stealth\\Registry\\ActiveTickets.csv";
       m_logs_path = "Merkava_Stealth\\Logs\\";
       m_ticket_count = 0;
   }
   ~CStealthRegistry() {}

   // Initialize (Load existing tickets)
   void Init()
   {
       // Check if directories exist (MT5 creates them automatically on FileOpen usually, but good practice)
       // MT5 Sandbox handles paths relative to MQL5/Files/
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

   // Helper: Get Random Magic (Full Range ulong)
   ulong GetRandomMagic()
   {
       // Combine multiple rands to cover ulong range partially
       // Note: MathRand is 0..32767 usually.
       ulong r1 = (ulong)MathRand();
       ulong r2 = (ulong)MathRand();
       ulong r3 = (ulong)MathRand();
       ulong r4 = (ulong)MathRand();
       return (r1 << 48) | (r2 << 32) | (r3 << 16) | r4;
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
