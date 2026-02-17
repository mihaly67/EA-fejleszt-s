//+------------------------------------------------------------------+
//|                                     Test_StealthRegistry.mq5    |
//|                                     Copyright 2026, Jules (Mimic)|
//|                                     Part of Project Merkava      |
//|                                          Version 1.0             |
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
   Print("=== StealthRegistry Test START ===");

   CStealthRegistry registry;
   registry.Init();

   Print("1. Registry Initialized. Checking random generation...");
   ulong rnd1 = registry.GetRandomMagic();
   ulong rnd2 = registry.GetRandomMagic();
   PrintFormat("Random Magic 1: %llu", rnd1);
   PrintFormat("Random Magic 2: %llu", rnd2);

   if(rnd1 != rnd2) Print("PASS: Random Magic differs.");
   else Print("FAIL: Random Magic collision (highly unlikely).");

   Print("2. Testing Ticket Registration...");
   ulong fake_ticket = 12345;
   ulong fake_magic = registry.GetRandomMagic();
   string fake_comment = registry.GetRandomComment();

   registry.RegisterTicket(fake_ticket, fake_magic, fake_comment);
   PrintFormat("Registered Fake Ticket #%d", fake_ticket);

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
   Print("Check MQL5/Files/Merkava_Stealth/Registry/ActiveTickets.csv and Logs/ for output.");
}
