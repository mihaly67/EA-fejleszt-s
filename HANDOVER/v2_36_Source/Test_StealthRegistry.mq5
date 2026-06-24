//+------------------------------------------------------------------+
//|                                     Test_StealthRegistry.mq5    |
//|                                     Copyright 2026, Jules (Mimic)|
//|                                     Part of Project Merkava      |
//|                                          Version 1.05            |
//|              (Unit Test for Stealth Registry v1.05 - LCG Check)  |
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
   Print("=== StealthRegistry Test START (v1.05) ===");
   Print("Initializing Registry (creates folders if missing)...");

   CStealthRegistry registry;
   registry.Init();

   Print("1. Registry Initialized. Checking Deep Randomization (Custom LCG & Seed)...");
   ulong rnd1 = registry.GetRandomMagic();
   ulong rnd2 = registry.GetRandomMagic();
   ulong rnd3 = registry.GetRandomMagic();
   ulong rnd4 = registry.GetRandomMagic();

   PrintFormat("Random Magic 1: %I64u", rnd1);
   PrintFormat("Random Magic 2: %I64u", rnd2);
   PrintFormat("Random Magic 3: %I64u", rnd3);
   PrintFormat("Random Magic 4: %I64u", rnd4);

   // Check Range
   if(rnd1 >= 10000 && rnd1 <= 999999) Print("PASS: Magic 1 in range."); else Print("FAIL: Magic 1 out of range!");
   if(rnd2 >= 10000 && rnd2 <= 999999) Print("PASS: Magic 2 in range."); else Print("FAIL: Magic 2 out of range!");

   // Check Variance (Clumping Test)
   // We expect significant difference because LCG jumps around the period, unlike linear +1 seeds
   long diff1 = (long)rnd1 - (long)rnd2;
   long diff2 = (long)rnd2 - (long)rnd3;

   // With LCG, diffs should be large and unpredictable.
   // If diff is exactly 1 or very small consistently, something is wrong.
   if(MathAbs(diff1) > 100) PrintFormat("PASS: Variance 1-2 OK (Diff: %d)", diff1);
   else PrintFormat("WARNING: Variance 1-2 LOW (Diff: %d) - Possible clumping or bad luck?", diff1);

   if(MathAbs(diff2) > 100) PrintFormat("PASS: Variance 2-3 OK (Diff: %d)", diff2);
   else PrintFormat("WARNING: Variance 2-3 LOW (Diff: %d) - Possible clumping or bad luck?", diff2);

   Print("2. Testing Ticket Registration...");
   ulong fake_ticket = 12345;
   ulong fake_magic = registry.GetRandomMagic();
   string fake_comment = registry.GetRandomComment();

   registry.RegisterTicket(fake_ticket, fake_magic, fake_comment);
   PrintFormat("Registered Fake Ticket #%d with Magic %I64u and Comment '%s'", fake_ticket, fake_magic, fake_comment);

   Print("3. Testing IsMyTicket...");
   if(registry.IsMyTicket(fake_ticket)) Print("PASS: IsMyTicket(12345) returns TRUE.");
   else Print("FAIL: IsMyTicket(12345) returns FALSE.");

   if(!registry.IsMyTicket(99999)) Print("PASS: IsMyTicket(99999) returns FALSE (Correct).");
   else Print("FAIL: IsMyTicket(99999) returns TRUE (Incorrect).");

   Print("4. Testing Unregistration...");
   registry.UnregisterTicket(fake_ticket);

   if(!registry.IsMyTicket(fake_ticket)) Print("PASS: IsMyTicket(12345) returns FALSE after Unregister.");
   else Print("FAIL: IsMyTicket(12345) still returns TRUE after Unregister.");

   Print("=== StealthRegistry Test END ===");
   Print("PLEASE VERIFY: MQL5/Files/Merkava_Stealth/Logs/Stealth_Audit_YYYY.MM.DD.csv");
   Print("Check for:");
   Print("  - Header Row present.");
   Print("  - Magic Numbers are diverse integers (e.g. 123456, 876543), not clustered.");
}
