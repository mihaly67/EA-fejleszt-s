//+------------------------------------------------------------------+
//|                                     Test_StealthRegistry_v1_08.mq5 |
//|                                     Copyright 2026, Jules (Mimic)|
//|                                     Part of Project Merkava      |
//|                                          Version 1.08            |
//|              (Unit Test for Stealth Registry v1.08 - LOG FIX)    |
//+------------------------------------------------------------------+
#property copyright "Jules (Mimic)"
#property strict
#property script_show_inputs

// Note: Path assumes this script is in MQL5/Scripts/
// and Registry is in MQL5/Indicators/Indicators/
#include "../Indicators/Indicators/StealthRegistry_v1_08.mqh"

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
{
   Print("=== StealthRegistry Test START (v1.08 - LOG FIX) ===");
   Print("Initializing Registry (creates folders if missing)...");

   CStealthRegistry registry;
   registry.Init();

   Print("1. Registry Initialized. Checking Deep Randomization...");
   ulong rnd1 = registry.GetRandomMagic();
   ulong rnd2 = registry.GetRandomMagic();
   PrintFormat("Random Magic 1: %I64u", rnd1);
   PrintFormat("Random Magic 2: %I64u", rnd2);

   if(rnd1 >= 10000 && rnd1 <= 999999) Print("PASS: Magic 1 in range."); else Print("FAIL: Magic 1 out of range!");

   Print("2. Testing Ticket Registration & LOGGING...");
   ulong fake_ticket = 88888; // Distinct from v1.05 test
   ulong fake_magic = registry.GetRandomMagic();
   string fake_comment = "TEST_v1.08_LOG_FIX";

   registry.RegisterTicket(fake_ticket, fake_magic, fake_comment);
   PrintFormat("Registered Fake Ticket #%d with Magic %I64u.", fake_ticket, fake_magic);

   // Manual Log Attempt
   Print("3. Forcing explicit LogAudit call...");
   registry.LogAudit("TEST_SCRIPT_MANUAL", fake_ticket, fake_magic, "Manual Test Entry v1.08");

   Print("=== StealthRegistry Test END ===");
   Print("PLEASE VERIFY FILE EXISTENCE:");
   string date_str = TimeToString(TimeCurrent(), TIME_DATE);
   StringReplace(date_str, ".", "");
   PrintFormat("EXPECTED LOG: MQL5/Files/Merkava_Stealth/Logs/Stealth_Audit_%s.csv", date_str);
}
