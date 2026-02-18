//+------------------------------------------------------------------+
//|                                     Test_StealthRegistry.mq5    |
//|                                     Copyright 2026, Jules (Mimic)|
//|                                     Part of Project Merkava      |
//|                                          Version 1.05            |
//|              (Unit Test for Stealth Registry v1.05 - CSV FIX)    |
//+------------------------------------------------------------------+
#property copyright "Jules (Mimic)"
#property strict
#property script_show_inputs

#include "../Indicators/StealthRegistry.mqh"

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
{
   Print("=== StealthRegistry Test START (v1.05 - CSV FIX) ===");
   Print("Initializing Registry (creates folders if missing)...");

   CStealthRegistry registry;
   registry.Init();

   Print("1. Registry Initialized. Checking Deep Randomization (Custom LCG & Seed)...");
   ulong rnd1 = registry.GetRandomMagic();
   ulong rnd2 = registry.GetRandomMagic();
   PrintFormat("Random Magic 1: %I64u", rnd1);
   PrintFormat("Random Magic 2: %I64u", rnd2);

   if(rnd1 >= 10000 && rnd1 <= 999999) Print("PASS: Magic 1 in range."); else Print("FAIL: Magic 1 out of range!");

   Print("2. Testing Ticket Registration & LOGGING...");
   ulong fake_ticket = 99999;
   ulong fake_magic = registry.GetRandomMagic();
   string fake_comment = registry.GetRandomComment();

   registry.RegisterTicket(fake_ticket, fake_magic, fake_comment);
   PrintFormat("Registered Fake Ticket #%d with Magic %I64u. CHECK LOGS!", fake_ticket, fake_magic);

   // Manual Log Attempt to verify fallback
   registry.LogAudit("TEST_SCRIPT", fake_ticket, fake_magic, "Manual Test Entry");
   Print("Manual LogAudit called.");

   Print("=== StealthRegistry Test END ===");
   Print("PLEASE VERIFY: MQL5/Files/Merkava_Stealth/Logs/Stealth_Audit_YYYY.MM.DD.csv");
   Print("IF FAILED: Check root MQL5/Files/ for Merkava_Fallback_Log_*.csv");
}
