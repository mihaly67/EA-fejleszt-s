//+------------------------------------------------------------------+
//|                                             Test_StealthLogs.mq5 |
//|                                    Copyright 2026, Jules (Mimic) |
//|                                      Script to verify CSV Logging|
//+------------------------------------------------------------------+
#property copyright "Jules (Mimic)"
#property link      "https://github.com/MimicProject"
#property version   "1.00"
#property script_show_inputs

#include "../Indicators/StealthRegistry_v1_06.mqh"

CStealthRegistry registry;

void OnStart()
{
   Print("🧪 STARTING STEALTH LOG TEST...");

   // 1. Initialize (creates folders)
   registry.Init();

   // 2. Generate Dummy Data
   ulong ticket = 123456;
   ulong magic = 999888;
   string comment = ""; // Broker Comment (Empty)
   string tag = "Test_Strategy_L1"; // Internal Tag

   // 3. Write to Audit Log
   Print("📝 Attempting to write to log...");
   registry.LogAudit("TEST_ENTRY", ticket, magic, comment, tag);

   Print("✅ TEST COMPLETE. Check MQL5/Files/Merkava_Stealth/Logs/ for today's file.");
}
