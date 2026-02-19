//+------------------------------------------------------------------+
//|                                     Test_StealthRegistry_v1_08.mq5 |
//|                                     Copyright 2026, Jules (Mimic)|
//|                                     Part of Project Merkava      |
//|                                          Version 1.08            |
//|              (Unit Test for Stealth Registry v1.08 - LOG FIX)    |
//|              (Strict Stealth: Generic Comments Only)             |
//+------------------------------------------------------------------+
#property copyright "Jules (Mimic)"
#property strict
#property script_show_inputs

// Note: Using corrected include path from previous fix
#include "../Indicators/StealthRegistry_v1_08.mqh"

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
{
   Print("=== StealthRegistry Test START (v1.08) ===");
   Print("Initializing Registry...");

   CStealthRegistry registry;
   registry.Init();

   Print("1. Registry Initialized. Checking Deep Randomization...");
   ulong rnd1 = registry.GetRandomMagic();
   ulong rnd2 = registry.GetRandomMagic();
   PrintFormat("Random Magic 1: %I64u", rnd1);
   PrintFormat("Random Magic 2: %I64u", rnd2);

   if(rnd1 >= 10000 && rnd1 <= 999999) Print("PASS: Magic 1 in range."); else Print("FAIL: Magic 1 out of range!");

   Print("2. Testing Ticket Registration & LOGGING...");
   ulong fake_ticket = 77777; // Generic ID
   ulong fake_magic = registry.GetRandomMagic();
   string fake_comment = "manual"; // STRICT STEALTH: Generic comment

   registry.RegisterTicket(fake_ticket, fake_magic, fake_comment);
   PrintFormat("Registered Ticket #%d with Magic %I64u.", fake_ticket, fake_magic);

   // Manual Log Attempt (Generic Message)
   Print("3. Forcing explicit LogAudit call...");
   registry.LogAudit("MANUAL_CHECK", fake_ticket, fake_magic, "manual_entry"); // Sanitized

   Print("=== StealthRegistry Test END ===");
   Print("PLEASE VERIFY FILE EXISTENCE:");
   string date_str = TimeToString(TimeCurrent(), TIME_DATE);
   StringReplace(date_str, ".", "");
   PrintFormat("EXPECTED LOG: Merkava_Stealth/Logs/Stealth_Audit_%s.csv", date_str);
}
