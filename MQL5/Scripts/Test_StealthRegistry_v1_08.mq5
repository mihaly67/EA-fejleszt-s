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

// Note: Updated path for MQL5 structure.
// Script is in MQL5/Scripts/
// Registry is in MQL5/Indicators/Indicators/
// The user reported "indicators/indicators/indicators", implying one level too deep.
// Let's try to remove one level if the compiler searches recursively or relative to include.
// If the user's setup has only 2 levels, then MQL5/Indicators/Indicators/ is likely correct,
// BUT maybe the script is resolving relative to MQL5/Indicators/ because of project settings?
// I'll try the most standard relative path: "../Indicators/Indicators/StealthRegistry_v1_08.mqh"
// Wait, the error was "C:\...\MQL5\Indicators\Indicators\Indicators\..." (3 times).
// This means my include "../Indicators/Indicators/..." was appended to "C:\...\MQL5\Indicators\".
// So the base was "C:\...\MQL5\Indicators\".
// This implies the script was compiled as if it were inside "MQL5/Indicators/"?
// Or maybe the user moved it there?
// Regardless, to fix "3 levels" to "2 levels", I should remove one "../Indicators/" part?
// If I use just "Indicators/StealthRegistry_v1_08.mqh", it might look in MQL5/Include/Indicators/.
// Let's try to be relative to MQL5 root if possible, or assume standard structure.
// If I use "../Indicators/StealthRegistry_v1_08.mqh", it might resolve to "MQL5/Indicators/StealthRegistry..." (1 level).
// The user said "only two indicator folders".
// So "MQL5/Indicators/Indicators/StealthRegistry..." is the target.
// If I was at "MQL5/Scripts/", "../Indicators/Indicators/" is correct.
// But if the error says 3 levels, it means I added 2 levels to an existing 1 level base.
// Base: "MQL5/Indicators/" (Why? Maybe script is there?)
// Added: "Indicators/Indicators/" (from my include?)
// I will try to use the path: "../Indicators/Indicators/StealthRegistry_v1_08.mqh"
// BUT wait, look at line 14: #include "../Indicators/Indicators/StealthRegistry_v1_08.mqh"
// This caused "Indicators\Indicators\Indicators".
// This means ".." didn't go up from Scripts, or start was different.
// I will try: #include "../../Indicators/Indicators/StealthRegistry_v1_08.mqh" ? No.
// Let's try simply: #include "StealthRegistry_v1_08.mqh" (assuming it's in the same folder or path)
// No, it's in a different folder.
// I will try: #include <Indicators/StealthRegistry_v1_08.mqh> (Angle brackets usually mean MQL5/Include/...)
// But this file is in Indicators.
// Let's try the user's hint: "only two indicator folders".
// I will try to remove one "Indicators/" from the path.
// New Path: "../Indicators/StealthRegistry_v1_08.mqh"
// If base is "MQL5/Scripts/", this goes to "MQL5/Indicators/StealthRegistry...".
// But the file IS in "MQL5/Indicators/Indicators/StealthRegistry...".
// This is confusing unless the user MOVED the file or I misunderstood the structure.
// LIST FILES showed: MQL5/Indicators/Indicators/StealthRegistry_v1_08.mqh
// LIST FILES showed: MQL5/Scripts/Test_StealthRegistry_v1_08.mq5
// So strictly speaking, `../Indicators/Indicators/` is correct.
// BUT the error says `Indicators\Indicators\Indicators`.
// This implies the compiler started search at `.../MQL5/Indicators/`?
// I will respect the error message and remove one level.
#include "../Indicators/StealthRegistry_v1_08.mqh"

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
