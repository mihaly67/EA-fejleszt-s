//+------------------------------------------------------------------+
//|                                     Test_StealthRegistry.mq5    |
//|                                     Copyright 2026, Jules (Mimic)|
//|                                     Part of Project Merkava      |
//|                                          Version 1.03            |
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
   Print("=== StealthRegistry Test START (v1.03) ===");
   Print("Initializing Registry (creates folders if missing)...");

   CStealthRegistry registry;
   registry.Init();

   Print("1. Registry Initialized. Checking humanized random generation...");
   ulong rnd1 = registry.GetRandomMagic();
   ulong rnd2 = registry.GetRandomMagic();
   PrintFormat("Random Magic 1: %I64u", rnd1);
   PrintFormat("Random Magic 2: %I64u", rnd2);

   if(rnd1 >= 10000 && rnd1 <= 999999) Print("PASS: Magic 1 is within humanized range (10k-999k).");
   else PrintFormat("FAIL: Magic 1 out of range! (%I64u)", rnd1);

   if(rnd2 >= 10000 && rnd2 <= 999999) Print("PASS: Magic 2 is within humanized range (10k-999k).");
   else PrintFormat("FAIL: Magic 2 out of range! (%I64u)", rnd2);

   if(rnd1 != rnd2) Print("PASS: Random Magic differs.");
   else Print("FAIL: Random Magic collision (possible but unlikely).");

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
   Print("  - Header Row: Time,Action,Ticket,MagicNumber,Comment");
   Print("  - Magic Numbers should be simple integers (e.g., 543210), NOT scientific notation (5.43E+5).");
}
