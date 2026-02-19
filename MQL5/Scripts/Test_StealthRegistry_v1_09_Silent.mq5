//+------------------------------------------------------------------+
//|                                Test_StealthRegistry_v1_09_Silent.mq5 |
//|                                     Copyright 2026, Jules (Mimic)|
//|                                     Part of Project Merkava      |
//|                                          Version 1.09            |
//|              (Unit Test for Stealth Registry v1.08 - SILENT)     |
//|              (Strict Stealth: Empty Comments Only)               |
//+------------------------------------------------------------------+
#property copyright "Jules (Mimic)"
#property strict
#property script_show_inputs

// Note: Using corrected include path
#include "../Indicators/StealthRegistry_v1_08.mqh"

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
{
   Print("=== StealthRegistry Test START (v1.09 - SILENT) ===");
   Print("Initializing Registry...");

   CStealthRegistry registry;
   registry.Init();

   Print("1. Registry Initialized. Checking Deep Randomization...");
   ulong rnd1 = registry.GetRandomMagic();
   PrintFormat("Random Magic 1: %I64u", rnd1);

   Print("2. Testing Ticket Registration & LOGGING (SILENT MODE)...");
   ulong fake_ticket = 66666;
   ulong fake_magic = registry.GetRandomMagic();
   string fake_comment = ""; // STRICT STEALTH: Empty comment

   registry.RegisterTicket(fake_ticket, fake_magic, fake_comment);
   PrintFormat("Registered Ticket #%d with Magic %I64u and EMPTY comment.", fake_ticket, fake_magic);

   // Manual Log Attempt (Silent Message)
   Print("3. Forcing explicit LogAudit call...");
   registry.LogAudit("MANUAL_SILENT", fake_ticket, fake_magic, ""); // Empty

   Print("=== StealthRegistry Test END ===");
   Print("PLEASE VERIFY FILE EXISTENCE:");
   string date_str = TimeToString(TimeCurrent(), TIME_DATE);
   StringReplace(date_str, ".", "");
   PrintFormat("EXPECTED LOG: Merkava_Stealth/Logs/Stealth_Audit_%s.csv", date_str);
}
