//+------------------------------------------------------------------+
//|                                            Test_SystemMonitor.mq5|
//|                                                   Copyright 2026 |
//|                                                     Merakva SWAT |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Merkava SWAT"
#property link      "https://github.com/merkava-swat"
#property version   "1.00"
#property script_show_inputs

#include <SystemMonitor.mqh>

void OnStart()
  {
   Print("=== STARTING SYSTEM MONITOR DIAGNOSTIC ===");

   CSystemMonitor monitor(true);

   if(monitor.IsStable()) {
      Print("System Stability: OPTIMAL (PASS)");
   } else {
      Print("System Stability: COMPROMISED/UNSTABLE (FAIL)");
   }

   Print("Checking Input Entropy...");
   if(monitor.CheckInputEntropy(2000)) {
       Print("Input Entropy: LOW (Suspicious)");
   } else {
       Print("Input Entropy: NORMAL (Pass)");
   }

   Print("=== DIAGNOSTIC COMPLETE ===");
  }
