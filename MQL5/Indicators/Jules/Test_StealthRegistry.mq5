//+------------------------------------------------------------------+
//|                                     Test_StealthRegistry.mq5    |
//|                                     Copyright 2026, Jules (Mimic)|
//|                                     Part of Project Merkava      |
//|                                          Version 1.05            |
//|              (Unit Test for Stealth Registry Infrastructure)     |
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
   Print("Initializing Registry with Custom PRNG (LCG)...");

   CStealthRegistry registry;
   registry.Init();

   Print("1. Registry Initialized. Checking Custom PRNG Variance...");
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

   // Check Variance (Clumping Test - Should be VERY distinct now)
   long diff1 = (long)rnd1 - (long)rnd2;

   if(MathAbs(diff1) > 1000) PrintFormat("PASS: High Variance 1-2 (Diff: %d)", diff1);
   else PrintFormat("WARNING: Variance 1-2 LOW (Diff: %d) - Check PRNG seed!", diff1);

   Print("2. Testing Ticket Registration...");
   ulong fake_ticket = 12345;
   ulong fake_magic = registry.GetRandomMagic();
   string fake_comment = registry.GetRandomComment(); // ASCII Check

   registry.RegisterTicket(fake_ticket, fake_magic, fake_comment);
   PrintFormat("Registered Fake Ticket #%d with Magic %I64u and Comment '%s'", fake_ticket, fake_magic, fake_comment);

   Print("=== StealthRegistry Test END ===");
   Print("PLEASE VERIFY: MQL5/Files/Merkava_Stealth/Logs/Stealth_Audit_YYYY.MM.DD.csv");
   Print("Check for:");
   Print("  - Readable Text (No 'Chinese characters').");
   Print("  - Magic Numbers are diverse integers.");
}
